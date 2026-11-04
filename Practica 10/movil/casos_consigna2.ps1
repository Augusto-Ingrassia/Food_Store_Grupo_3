# Consigna 2.c — Los casos C2 a C6, cada uno con su propia instantánea nueva del servidor
# Uso, parado en movil/ (la contraseña no va en el script):
#   $env:PGPASSWORD = "<contraseña de postgres>"
#   powershell -ExecutionPolicy Bypass -File casos_consigna2.ps1
# Si sqlite3 no está en el PATH: -Sqlite "C:\ruta\a\sqlite3.exe"
#
# ATENCIÓN: borra y vuelve a crear la base de PRUEBAS food_store_pruebas y la base de la tablet.
# Nunca apuntarlo a la base real (food_store).
param(
    [string]$Sqlite = "sqlite3",
    [string]$PgUser = "postgres",
    [string]$Db     = "food_store_pruebas"
)

if ($Db -notlike "*pruebas*") { throw "Solo se corre sobre una base de PRUEBAS (el nombre tiene que contener 'pruebas')" }

Set-Location $PSScriptRoot
$OutputEncoding = [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
$env:PGCLIENTENCODING = "UTF8"
$raiz = Resolve-Path "$PSScriptRoot\..\.."

function Titulo([string]$texto) { Write-Host "`n===== $texto" -ForegroundColor Cyan }
function Servidor([string]$sql) { $sql | psql -X -U $PgUser -h localhost -d $Db }
function Tablet([string]$sql)   { "PRAGMA foreign_keys = ON;`n$sql" | & $Sqlite -header -column foodstore_movil.db }

# Cada caso exporta una instantánea nueva (2.a) y la carga en la tablet antes de correr el semáforo (2.b)
function NuevaInstantanea {
    Start-Sleep -Seconds 1 # para que cada instantánea tenga su propia fecha de copia
    psql -X -q -U $PgUser -h localhost -d $Db -f servidor_snapshot.sql
    Tablet ".read cargar_snapshot.sql"
}
function Semaforo { Tablet ".read semaforo.sql" }

$verificacion = @"
SELECT (SELECT COUNT(*) FROM pedido)         AS pedidos,
       (SELECT COUNT(*) FROM detalle_pedido) AS detalles,
       (SELECT SUM(stock) FROM producto)     AS stock_total,
       (SELECT string_agg(id || ':' || stock, '  ' ORDER BY id) FROM producto) AS stock_por_producto;
"@

# ---------------------------------------------------------------------------
Titulo "Preparación: copia de pruebas del servidor y tablet desde cero"
dropdb --if-exists -U $PgUser -h localhost $Db
createdb -U $PgUser -h localhost $Db
foreach ($f in "schema.sql", "objects.sql", "data.sql") {
    psql -X -q -v ON_ERROR_STOP=1 -U $PgUser -h localhost -d $Db -f "$raiz\$f" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Falló $f" }
}
Tablet ".read schema_sqlite.sql"

Titulo "PostgreSQL ANTES de los casos"
Servidor $verificacion

Titulo "Instantánea inicial: la tablet carga el catálogo antes de salir a la feria"
NuevaInstantanea

# ---------------------------------------------------------------------------
Titulo "C2 · Borrador de 1 Muzzarella; después el servidor sube el precio"
Tablet @"
BEGIN;
INSERT INTO pedido_borrador (id_local, usuario, forma_pago, fecha)
VALUES ('a0000000-0000-4000-8000-0000000000c2', 'juan', 'EFECTIVO', datetime('now', 'localtime'));
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
SELECT 'a0000000-0000-4000-8000-0000000000c2', id, 1, precio_centavos FROM producto_cache WHERE id = 2;
INSERT INTO cola_sync (solicitud_uuid, id_local, estado)
VALUES ('b0000000-0000-4000-8000-0000000000c2', 'a0000000-0000-4000-8000-0000000000c2', 'PENDIENTE');
COMMIT;
"@
Servidor "UPDATE producto SET precio = 1700.00 WHERE id = 2 AND eliminado = FALSE;"
NuevaInstantanea
Semaforo # esperado: CONFLICTO

Titulo "C2 · El cliente acepta el precio nuevo: borrador actualizado y solicitud NUEVA"
Tablet @"
BEGIN;
UPDATE item_borrador
SET precio_centavos_visto = (SELECT s.precio_centavos FROM snapshot_servidor s WHERE s.id = item_borrador.producto_id)
WHERE id_local = 'a0000000-0000-4000-8000-0000000000c2';
INSERT INTO cola_sync (solicitud_uuid, id_local, estado)
VALUES ('b0000000-0000-4000-8000-00000000c2b2', 'a0000000-0000-4000-8000-0000000000c2', 'PENDIENTE');
COMMIT;
"@
Semaforo # esperado: la solicitud nueva da SIMULADO_APROBADO; la de CONFLICTO no se reevalúa

# ---------------------------------------------------------------------------
Titulo "C3 · Borrador por 999 Empanadas de Carne (más de las que quedan)"
# La tablet no lo impide: stock_visto es solo una foto, decide el servidor
Tablet @"
BEGIN;
INSERT INTO pedido_borrador (id_local, usuario, forma_pago, fecha)
VALUES ('a0000000-0000-4000-8000-0000000000c3', 'ana', 'TARJETA', datetime('now', 'localtime'));
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
SELECT 'a0000000-0000-4000-8000-0000000000c3', id, 999, precio_centavos FROM producto_cache WHERE id = 3;
INSERT INTO cola_sync (solicitud_uuid, id_local, estado)
VALUES ('b0000000-0000-4000-8000-0000000000c3', 'a0000000-0000-4000-8000-0000000000c3', 'PENDIENTE');
COMMIT;
"@
NuevaInstantanea
Semaforo # esperado: RECHAZADO por stock

# ---------------------------------------------------------------------------
Titulo "C4 · Borrador de 2 Coca Cola 1.5L; después el servidor la da de baja (baja lógica)"
Tablet @"
BEGIN;
INSERT INTO pedido_borrador (id_local, usuario, forma_pago, fecha)
VALUES ('a0000000-0000-4000-8000-0000000000c4', 'juan', 'TRANSFERENCIA', datetime('now', 'localtime'));
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
SELECT 'a0000000-0000-4000-8000-0000000000c4', id, 2, precio_centavos FROM producto_cache WHERE id = 4;
INSERT INTO cola_sync (solicitud_uuid, id_local, estado)
VALUES ('b0000000-0000-4000-8000-0000000000c4', 'a0000000-0000-4000-8000-0000000000c4', 'PENDIENTE');
COMMIT;
"@
Servidor "UPDATE producto SET eliminado = TRUE WHERE id = 4 AND eliminado = FALSE;"
NuevaInstantanea
Semaforo # esperado: RECHAZADO por baja

Titulo "C4 · Catálogo recargado: la Coca Cola ya no aparece..."
Tablet "SELECT id, nombre, precio_centavos, stock_visto FROM producto_cache WHERE disponible = 1 AND eliminado = 0 ORDER BY id;"
Titulo "C4 · ...pero la fila queda, porque el borrador la referencia"
Tablet "SELECT p.id, p.nombre, p.eliminado, i.id_local FROM producto_cache p JOIN item_borrador i ON i.producto_id = p.id WHERE p.id = 4;"

# ---------------------------------------------------------------------------
Titulo "C5 · Borrador de 1 Fugazzeta, producto que el servidor no toca"
Tablet @"
BEGIN;
INSERT INTO pedido_borrador (id_local, usuario, forma_pago, fecha)
VALUES ('a0000000-0000-4000-8000-0000000000c5', 'ana', 'EFECTIVO', datetime('now', 'localtime'));
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
SELECT 'a0000000-0000-4000-8000-0000000000c5', id, 1, precio_centavos FROM producto_cache WHERE id = 1;
INSERT INTO cola_sync (solicitud_uuid, id_local, estado)
VALUES ('b0000000-0000-4000-8000-0000000000c5', 'a0000000-0000-4000-8000-0000000000c5', 'PENDIENTE');
COMMIT;
"@
NuevaInstantanea
Semaforo # esperado: SIMULADO_APROBADO (no es una venta)

# ---------------------------------------------------------------------------
Titulo "C6 · La tablet reenvía la solicitud de C5 con el mismo UUID"
Tablet @"
INSERT INTO cola_sync (solicitud_uuid, id_local, estado)
VALUES ('b0000000-0000-4000-8000-0000000000c5', 'a0000000-0000-4000-8000-0000000000c5', 'PENDIENTE');
"@ # esperado: UNIQUE constraint failed: cola_sync.solicitud_uuid
Tablet "SELECT COUNT(*) AS solicitudes_con_ese_uuid FROM cola_sync WHERE solicitud_uuid = 'b0000000-0000-4000-8000-0000000000c5';"
Titulo "C6 · Repetir la simulación no reevalúa nada"
Semaforo # esperado: solicitudes_evaluadas = 0

# ---------------------------------------------------------------------------
Titulo "PostgreSQL DESPUÉS de los casos: pedidos y stock tienen que dar igual que ANTES"
Servidor $verificacion
