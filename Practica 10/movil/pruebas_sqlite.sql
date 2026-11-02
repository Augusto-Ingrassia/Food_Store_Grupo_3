-- foreign_keys es por conexión: hay que activarlo en cada sesión, no alcanza con schema_sqlite.sql
PRAGMA foreign_keys = ON;

-- 0. Limpieza de datos de prueba (permite volver a correr el script)
DELETE FROM item_borrador WHERE id_local IN ('pedido-uuid-1', 'pedido-uuid-2');
DELETE FROM cola_sync WHERE solicitud_uuid = 'sync-uuid-1';
DELETE FROM pedido_borrador WHERE id_local IN ('pedido-uuid-1', 'pedido-uuid-2');
DELETE FROM producto_cache WHERE id = 1;

INSERT INTO producto_cache (id, nombre, precio_centavos, stock_visto, disponible, eliminado, fecha_copia)
VALUES (1, 'Hamburguesa Simple', 500000, 20, 1, 0, '2026-11-02 10:00:00');

-- 1. Transacciones completas (BEGIN ... COMMIT y ROLLBACK)
BEGIN;
INSERT INTO pedido_borrador (id_local, usuario, forma_pago, fecha)
VALUES ('pedido-uuid-1', 'augusto', 'EFECTIVO', '2026-11-02 10:30:00');

INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('pedido-uuid-1', 1, 2, 500000);

INSERT INTO cola_sync (solicitud_uuid, id_local, estado, motivo)
VALUES ('sync-uuid-1', 'pedido-uuid-1', 'PENDIENTE', NULL);
COMMIT;

BEGIN;
INSERT INTO pedido_borrador (id_local, usuario, forma_pago, fecha)
VALUES ('pedido-uuid-2', 'franco', 'TARJETA', '2026-11-02 11:00:00');

INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('pedido-uuid-2', 1, 1, 500000);
ROLLBACK;

-- Verificación: solo existe pedido-uuid-1 (el borrador 2 se deshizo)
SELECT id_local, usuario, forma_pago FROM pedido_borrador;


-- 2. Caso C1: Consulta del catálogo disponible offline
SELECT id, nombre, precio_centavos
FROM producto_cache
WHERE disponible = 1 AND eliminado = 0;


-- 3. Caso C7: Errores que no dejan filas nuevas
-- Falla por CHECK(cantidad > 0)
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('pedido-uuid-1', 1, 0, 500000);

-- Falla por FOREIGN KEY: el producto 999 no existe en producto_cache
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('pedido-uuid-1', 999, 1, 500000);

-- Verificación: sigue habiendo un solo ítem
SELECT COUNT(*) AS items FROM item_borrador;
