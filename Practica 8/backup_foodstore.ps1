# Configuración de nombres y formatos
$fecha_hora = Get-Date -Format "yyyyMMdd_HHmmss"
$backup_dir = "backups"
$log_dir = "logs"
$backup_file = "$backup_dir\foodstore_$fecha_hora.dump"
$log_file = "$log_dir\backup_log.txt"

# Crear las carpetas si no existen
if (!(Test-Path -Path $backup_dir)) { New-Item -ItemType Directory -Path $backup_dir | Out-Null }
if (!(Test-Path -Path $log_dir)) { New-Item -ItemType Directory -Path $log_dir | Out-Null }

# Registrar inicio en el log
$mensaje_inicio = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Iniciando respaldo custom de la base foodstore..."
Add-Content -Path $log_file -Value $mensaje_inicio
Write-Host $mensaje_inicio

# Ejecutar el respaldo de referencia sin contraseña en el script
pg_dump -h localhost -p 5432 -U postgres -d food_store -Fc -f $backup_file

# Verificar si el comando falló
if ($LASTEXITCODE -eq 0) {
    $mensaje_exito = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - EXITO: Respaldo guardado en $backup_file"
    Add-Content -Path $log_file -Value $mensaje_exito
    Write-Host $mensaje_exito -ForegroundColor Green
} else {
    $mensaje_error = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - ERROR: pg_dump fallo al generar el respaldo."
    Add-Content -Path $log_file -Value $mensaje_error
    Write-Host $mensaje_error -ForegroundColor Red
    exit 1
}