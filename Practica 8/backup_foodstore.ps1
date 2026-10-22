# Uso: .\backup_foodstore.ps1 [-Servidor localhost] [-Puerto 5432] [-Base food_store]
# La contraseña NO va en el script: se toma de la variable PGPASSWORD o de pgpass.conf.
param(
    [string]$Servidor = "localhost",
    [int]$Puerto = 5432,
    [string]$Base = "food_store"
)

# Configuración de nombres y formatos (rutas relativas a la carpeta del script)
$fecha_hora = Get-Date -Format "yyyyMMdd_HHmmss"
$backup_dir = "$PSScriptRoot\backups"
$log_dir = "$PSScriptRoot\logs"
$backup_name = "foodstore_$fecha_hora"
$backup_file = "$backup_dir\$backup_name.dump"
$conteo_file = "$backup_dir\$backup_name.conteo.txt"
$log_file = "$log_dir\backup_log.txt"

# Crear las carpetas si no existen
if (!(Test-Path -Path $backup_dir)) { New-Item -ItemType Directory -Path $backup_dir | Out-Null }
if (!(Test-Path -Path $log_dir)) { New-Item -ItemType Directory -Path $log_dir | Out-Null }

# Registrar inicio en el log
$mensaje_inicio = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Iniciando respaldo custom de la base $Base (${Servidor}:${Puerto})..."
Add-Content -Path $log_file -Value $mensaje_inicio
Write-Host $mensaje_inicio

# Registrar las filas de cada tabla antes del respaldo: restore_test.ps1 las compara
# con la base restaurada (Parte 4)
psql -h $Servidor -p $Puerto -U postgres -d $Base -X -A -t -F "|" -v ON_ERROR_STOP=1 -f "$PSScriptRoot\validacion_restore.sql" -o $conteo_file

# Ejecutar el respaldo de referencia sin contraseña en el script
if ($LASTEXITCODE -eq 0) {
    pg_dump -h $Servidor -p $Puerto -U postgres -d $Base -Fc -f $backup_file
}

# Verificar si el comando falló
if ($LASTEXITCODE -eq 0) {
    $tamano = (Get-Item $backup_file).Length
    $mensaje_exito = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - EXITO: Respaldo guardado en backups\$backup_name.dump ($tamano bytes)"
    Add-Content -Path $log_file -Value $mensaje_exito
    Write-Host $mensaje_exito -ForegroundColor Green
} else {
    $codigo = $LASTEXITCODE
    # pg_dump crea el archivo antes de conectarse: si falla deja un .dump vacío
    # que después parece un respaldo válido. Se borra junto con el conteo.
    Remove-Item $backup_file, $conteo_file -ErrorAction SilentlyContinue
    $mensaje_error = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - ERROR: fallo el respaldo (codigo $codigo). No se dejo ningun .dump."
    Add-Content -Path $log_file -Value $mensaje_error
    Write-Host $mensaje_error -ForegroundColor Red
    exit 1
}
