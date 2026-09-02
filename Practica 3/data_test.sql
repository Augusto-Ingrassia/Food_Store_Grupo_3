BEGIN;

-- ============================================================
-- SCRIPT DE GENERACIÓN DE DATOS DE PRUEBA MASIVOS
-- PostgreSQL — usa generate_series, sin PL/pgSQL
-- Respeta TODOS los constraints del DDL original.
-- ============================================================
-- IMPORTANTE: Ejecutá una sola vez.
-- Para regenerar, primero:
--   TRUNCATE detalle_pedido, pedido, producto, usuario
--     RESTART IDENTITY CASCADE;


-- ─── 1. USUARIOS — 20.000 ──────────────────────────────────
-- mail es UNIQUE por construcción: 'user1@test.com', 'user2@test.com', ...
-- Solo el usuario 1 tiene rol ADMIN; el resto USUARIO (DEFAULT).
INSERT INTO usuario (nombre, apellido, mail, celular, contrasena, rol)
SELECT
    'Nombre'   || s,
    'Apellido' || s,
    'user'     || s || '@test.com',
    '+54911'   || lpad(s::text, 7, '0'),
    md5(s::text || random()::text),
    CASE WHEN s = 1 THEN 'ADMIN'::rol ELSE 'USUARIO'::rol END
FROM generate_series(1, 20000) s;


-- ─── 2. PRODUCTOS — 50.000 ─────────────────────────────────
-- precio:  [500, 5000)
-- stock:   0 .. 200
-- categoria_id: 1 .. 10 (distribución pareja)
-- CHECK chk_producto_stock_si_disponible:
--   si stock = 0  →  disponible = FALSE (garantizado con CASE)
INSERT INTO producto (nombre, precio, descripcion, stock, imagen, disponible, categoria_id)
WITH datos AS (
    SELECT
        s,
        floor(random() * 201)::integer                          AS stock,
        round((500 + random() * 4500)::numeric, 2)              AS precio
    FROM generate_series(1, 50000) s
)
SELECT
    'Producto '  || s,
    precio,
    'Descripcion del producto ' || s,
    stock,
    'img_' || s || '.jpg',
    CASE WHEN stock = 0 THEN FALSE ELSE (random() > 0.1) END,
    (random() * 9 + 1)::integer
FROM datos;


-- ─── 3. PEDIDOS — 200.000 ──────────────────────────────────
-- usuario_id: 1 .. 20 000 (random)
-- forma_pago: TARJETA / TRANSFERENCIA / EFECTIVO (aleatorio)
-- estado:     PENDIENTE / CONFIRMADO / TERMINADO / CANCELADO
-- total:      se inserta en 0 (DEFAULT); se actualiza al final.
INSERT INTO pedido (fecha, estado, forma_pago, usuario_id)
SELECT
    (CURRENT_DATE - (random() * 365)::integer)::date,
    (ARRAY['PENDIENTE','CONFIRMADO','TERMINADO','CANCELADO']
        ::estado_pedido[])[floor(random() * 4 + 1)::integer],
    (ARRAY['TARJETA','TRANSFERENCIA','EFECTIVO']
        ::forma_pago[])[floor(random() * 3 + 1)::integer],
    floor(random() * 20000 + 1)::integer
FROM generate_series(1, 200000) s;


-- ─── 4. DETALLE_PEDIDO — 200.000 (1 ítem por pedido) ───────
-- UNIQUE(pedido_id, producto_id):
--   cada pedido_id aparece UNA sola vez en generate_series,
--   por lo que es IMPOSIBLE generar un duplicado.
-- subtotal = cantidad × precio_unitario (calculado inline).
-- precio_unitario > 0  (rango [500, 5000))
-- cantidad > 0         (rango [1, 10])
INSERT INTO detalle_pedido (cantidad, precio_unitario, subtotal, pedido_id, producto_id)
WITH base AS (
    SELECT
        s                                               AS pedido_id,
        floor(random() * 50000 + 1)::integer                 AS producto_id,
        floor(random() * 10 + 1)::integer               AS cantidad,
        round((500 + random() * 4500)::numeric, 2)      AS precio_unitario
    FROM generate_series(1, 200000) s
)
SELECT
    cantidad,
    precio_unitario,
    round(cantidad * precio_unitario, 2),
    pedido_id,
    producto_id
FROM base;


-- ─── 5. ACTUALIZAR TOTALES DE CADA PEDIDO ──────────────────
UPDATE pedido p
SET total = sub.suma
FROM (
    SELECT pedido_id, SUM(subtotal) AS suma
    FROM detalle_pedido
    GROUP BY pedido_id
) sub
WHERE p.id = sub.pedido_id;


-- ─── VERIFICACIÓN (opcional) ────────────────────────────────
-- SELECT 'usuarios'       AS tabla, COUNT(*) AS filas FROM usuario
-- UNION ALL SELECT 'productos',             COUNT(*) FROM producto
-- UNION ALL SELECT 'pedidos',               COUNT(*) FROM pedido
-- UNION ALL SELECT 'detalle_pedido',        COUNT(*) FROM detalle_pedido;

COMMIT;