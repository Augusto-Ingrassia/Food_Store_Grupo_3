# =============================================================
# restore_test.ps1 - Simulacro de restauracion (TP Unidad 6, Parte 4)
# Uso: .\restore_test.ps1 [-Servidor localhost] [-Puerto 5432]
# Restaura el ultimo respaldo de backups\ en foodstore_restore_test,
# corre validacion_restore.sql y mide el RTO y la antiguedad del respaldo.
# No se conecta a la base principal: compara contra el conteo que
# backup_foodstore.ps1 guardo junto al .dump.
# La contraseña NO va en el script: se toma de PGPASSWORD o de pgpass.conf.
# =============================================================
param(
    [string]$Servidor = "localhost",
    [int]$Puerto = 5432
)

$base_restore = "foodstore_restore_test"
$backup_dir = "$PSScriptRoot\backups"
$log_dir = "$PSScriptRoot\logs"
$log_file = "$log_dir\restore_test_log.txt"
$conexion = @("-h", $Servidor, "-p", $Puerto, "-U", "postgres")

if (!(Test-Path -Path $log_dir)) { New-Item -ItemType Directory -Path $log_dir | Out-Null }

function Registrar($mensaje, $color = "White") {
    $linea = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $mensaje"
    Add-Content -Path $log_file -Value $linea
    Write-Host $linea -ForegroundColor $color
}

function Fallar($mensaje) {
    Registrar "ERROR: $mensaje" "Red"
    exit 1
}

# Convierte las lineas "control|valor" de validacion_restore.sql en un diccionario
function Leer-Controles($lineas) {
    $controles = [ordered]@{}
    foreach ($linea in $lineas) {
        if ($linea -match '^(\w+)\|(\d+)$') { $controles[$Matches[1]] = [long]$Matches[2] }
    }
    return $controles
}

Registrar "=== Simulacro de restauracion en $base_restore (${Servidor}:${Puerto}) ==="

# 1. Ultimo respaldo valido. El nombre lleva la fecha, asi que ordenar por nombre
#    es ordenar por antiguedad. Se descartan los .dump vacios de respaldos fallidos.
$respaldo = Get-ChildItem "$backup_dir\foodstore_????????_??????.dump" -ErrorAction SilentlyContinue |
    Where-Object { $_.Length -gt 0 } | Sort-Object Name | Select-Object -Last 1
if (-not $respaldo) { Fallar "no hay respaldos validos en backups\" }

# La fecha sale del nombre (foodstore_yyyyMMdd_HHmmss.dump) y no de la fecha del
# archivo, que cambia al copiarlo o al clonar el repositorio.
$fecha_respaldo = [datetime]::ParseExact($respaldo.BaseName.Substring(10), "yyyyMMdd_HHmmss", $null)
Registrar "Respaldo elegido: $($respaldo.Name) ($($respaldo.Length) bytes, generado $($fecha_respaldo.ToString('yyyy-MM-dd HH:mm:ss')))"

$conteo_file = "$backup_dir\$($respaldo.BaseName).conteo.txt"
if (!(Test-Path $conteo_file)) { Fallar "falta $($respaldo.BaseName).conteo.txt con las filas previas al respaldo" }
$referencia = Leer-Controles (Get-Content $conteo_file)

# 2. Si quedo la base de prueba de una corrida anterior se elimina. Solo se toca
#    foodstore_restore_test, nunca la base principal. Va antes del cronometro.
dropdb @conexion --if-exists $base_restore
if ($LASTEXITCODE -ne 0) { Fallar "no se pudo eliminar la $base_restore anterior" }

# 3. Cronometro: arranca inmediatamente antes de crear la base de prueba
$inicio = Get-Date
$cronometro = [System.Diagnostics.Stopwatch]::StartNew()

createdb @conexion $base_restore
if ($LASTEXITCODE -ne 0) { Fallar "createdb fallo" }

pg_restore @conexion -d $base_restore --no-owner --no-privileges $respaldo.FullName
if ($LASTEXITCODE -ne 0) { Fallar "pg_restore termino con errores" }
Registrar ("Restauracion terminada a los {0:N2} s" -f $cronometro.Elapsed.TotalSeconds)

# 4. Validaciones minimas sobre la base restaurada
$salida = psql @conexion -d $base_restore -X -A -t -F "|" -v ON_ERROR_STOP=1 -f "$PSScriptRoot\validacion_restore.sql"
if ($LASTEXITCODE -ne 0) { Fallar "no se pudo ejecutar validacion_restore.sql" }
$restaurada = Leer-Controles $salida

$todo_ok = $restaurada.Count -eq $referencia.Count
foreach ($control in $referencia.Keys) {
    $valor = $restaurada[$control]
    if ($control -like "*_invalidos") {
        $ok = $valor -eq 0
        $detalle = "$valor (esperado 0)"
    } else {
        $ok = $valor -eq $referencia[$control]
        $detalle = "$valor filas (antes del respaldo: $($referencia[$control]))"
    }
    if (-not $ok) { $todo_ok = $false }
    Registrar ("{0} {1}: {2}" -f $(if ($ok) { "OK   " } else { "FALLA" }), $control, $detalle)
}

# 5. El cronometro se detiene cuando las validaciones terminan correctamente
$cronometro.Stop()
if (-not $todo_ok) { Fallar "la base restaurada no coincide con el respaldo" }

$antiguedad = $inicio - $fecha_respaldo
Registrar ("RTO observado: {0:N2} s (createdb + pg_restore + validaciones)" -f $cronometro.Elapsed.TotalSeconds) "Green"
Registrar ("Antiguedad del respaldo al iniciar el simulacro (RPO observado): {0}d {1:hh}h {1:mm}m {1:ss}s" -f $antiguedad.Days, $antiguedad) "Green"
Registrar "EXITO: $base_restore restaurada y validada" "Green"
