PRAGMA foreign_keys = ON;

-- Borrado previo para crear la base desde cero (orden inverso por las claves foráneas)
DROP TABLE IF EXISTS item_borrador;
DROP TABLE IF EXISTS cola_sync;
DROP TABLE IF EXISTS pedido_borrador;
DROP TABLE IF EXISTS producto_cache;

CREATE TABLE producto_cache (
    id INTEGER PRIMARY KEY,
    nombre TEXT NOT NULL,
    precio_centavos INTEGER NOT NULL CHECK(precio_centavos >= 0),
    stock_visto INTEGER NOT NULL,
    disponible INTEGER NOT NULL CHECK(disponible IN (0, 1)),
    eliminado INTEGER NOT NULL CHECK(eliminado IN (0, 1)),
    fecha_copia TEXT NOT NULL
) STRICT;

CREATE TABLE pedido_borrador (
    id_local TEXT PRIMARY KEY, -- Usamos TEXT para guardar el UUID
    usuario TEXT NOT NULL,
    forma_pago TEXT NOT NULL CHECK(forma_pago IN ('EFECTIVO', 'TARJETA', 'TRANSFERENCIA')),
    fecha TEXT NOT NULL
) STRICT;

CREATE TABLE item_borrador (
    id_local TEXT NOT NULL,
    producto_id INTEGER NOT NULL,
    cantidad INTEGER NOT NULL CHECK(cantidad > 0),
    precio_centavos_visto INTEGER NOT NULL,
    FOREIGN KEY(id_local) REFERENCES pedido_borrador(id_local),
    FOREIGN KEY(producto_id) REFERENCES producto_cache(id)
) STRICT;

CREATE TABLE cola_sync (
    solicitud_uuid TEXT PRIMARY KEY,
    id_local TEXT NOT NULL,
    estado TEXT NOT NULL CHECK(estado IN ('PENDIENTE', 'CONFLICTO', 'RECHAZADO', 'SIMULADO_APROBADO')),
    motivo TEXT
) STRICT;