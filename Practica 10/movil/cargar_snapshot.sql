-- Consigna 2.a — Importar la instantánea del servidor y recargar el catálogo de la tablet (SQLite)
--   sqlite3 foodstore_movil.db ".read cargar_snapshot.sql"
-- (En DB Browser: Archivo > Importar > Tabla desde CSV sobre snapshot_servidor, y después correr desde el INSERT)
PRAGMA foreign_keys = ON;

-- Copia cruda del CSV. Sin STRICT: .import inserta texto y la afinidad INTEGER lo convierte.
-- Los booleanos quedan como 't' / 'f', tal como los exporta psql.
CREATE TABLE IF NOT EXISTS snapshot_servidor (
    id INTEGER PRIMARY KEY,
    nombre TEXT NOT NULL,
    precio_centavos INTEGER NOT NULL,
    stock INTEGER NOT NULL,
    disponible TEXT NOT NULL,
    eliminado TEXT NOT NULL,
    fecha_copia TEXT NOT NULL
);

-- Cada instantánea reemplaza a la anterior
DELETE FROM snapshot_servidor;
.import --csv --skip 1 servidor_snapshot.csv snapshot_servidor

-- Upsert y no DELETE + INSERT: item_borrador apunta a producto_cache, así que una baja
-- no borra la fila, solo la marca (eliminado = 1) y deja de aparecer en el catálogo.
INSERT INTO producto_cache (id, nombre, precio_centavos, stock_visto, disponible, eliminado, fecha_copia)
SELECT id,
       nombre,
       CAST(precio_centavos AS INTEGER),
       CAST(stock AS INTEGER),
       disponible = 't',
       eliminado = 't',
       fecha_copia
FROM snapshot_servidor
WHERE true -- requerido por SQLite para usar ON CONFLICT después de un SELECT
ON CONFLICT(id) DO UPDATE SET
    nombre          = excluded.nombre,
    precio_centavos = excluded.precio_centavos,
    stock_visto     = excluded.stock_visto,
    disponible      = excluded.disponible,
    eliminado       = excluded.eliminado,
    fecha_copia     = excluded.fecha_copia;

-- Fecha de la copia con la que quedó el catálogo
SELECT MAX(fecha_copia) AS fecha_de_la_copia, COUNT(*) AS productos_en_cache FROM producto_cache;
