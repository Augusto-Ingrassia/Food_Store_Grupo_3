-- =============================================================================
-- Práctica 9 (TP Unidad 7) — Parte 2: reconstrucción en PostgreSQL de los
-- 5 pedidos migrados a MongoDB.
--
-- Procedencia: los pedidos 1 a 5 salen de la base del equipo poblada con
-- Practica 3/seed_masivo.sql (datos generados con random(), no reproducibles).
-- Esta base local no tiene esos datos, así que se cargan los mismos 5 pedidos
-- con los valores registrados en la migración (consultas_mongodb.js), sin
-- alterar identificadores, cantidades, precios ni estados.
--
-- Ejecución, contra una base vacía:
--   createdb food_store_nosql
--   psql -d food_store_nosql -f ../schema.sql
--   psql -d food_store_nosql -f ../objects.sql
--   psql -d food_store_nosql -f reconstruccion_pedidos_pg.sql
--
-- Se usa OVERRIDING SYSTEM VALUE porque las PK son GENERATED ALWAYS y la
-- consigna exige conservar los identificadores de origen.
-- subtotal y total NO se cargan a mano: los calculan trg_subtotal y
-- trg_total_ins, igual que en Food Store.
-- =============================================================================

BEGIN;

-- Categorías (mismos id y nombres que el seed masivo)
INSERT INTO categoria (id, nombre) OVERRIDING SYSTEM VALUE VALUES
    (1, 'Comida Rápida'),
    (2, 'Bebidas'),
    (3, 'Postres'),
    (4, 'Pizzas y Empanadas'),
    (5, 'Ensaladas');

-- Productos de las líneas migradas. El precio de catálogo actual no se migró
-- (el documento guarda el precio histórico de la línea); se usa ese mismo
-- valor solo para cumplir el NOT NULL. stock = 1 por el CHECK de disponible.
INSERT INTO producto (id, nombre, precio, stock, categoria_id) OVERRIDING SYSTEM VALUE VALUES
    (1,     'Producto Masivo 1',     7500.00, 1, 2),
    (7470,  'Producto Masivo 7470',   993.26, 1, 1),
    (38264, 'Producto Masivo 38264',  993.26, 1, 5),
    (43068, 'Producto Masivo 43068',  993.26, 1, 4),
    (46542, 'Producto Masivo 46542',  993.26, 1, 3),
    (49690, 'Producto Masivo 49690',  993.26, 1, 1);

-- Clientes (datos sintéticos del seed; contrasena no se migró)
INSERT INTO usuario (id, nombre, apellido, mail, celular, contrasena) OVERRIDING SYSTEM VALUE VALUES
    (5366,  'Nombre_5366',  'Apellido_5366',  'usuario_5366@foodstore.com',  '5491161547980', 'no_migrada'),
    (7636,  'Nombre_7636',  'Apellido_7636',  'usuario_7636@foodstore.com',  '5491196349901', 'no_migrada'),
    (10130, 'Nombre_10130', 'Apellido_10130', 'usuario_10130@foodstore.com', '5491158917253', 'no_migrada'),
    (16226, 'Nombre_16226', 'Apellido_16226', 'usuario_16226@foodstore.com', '5491173853782', 'no_migrada'),
    (17023, 'Nombre_17023', 'Apellido_17023', 'usuario_17023@foodstore.com', '5491165953644', 'no_migrada');

-- Pedidos (total = 0, tal como figura en la migración)
INSERT INTO pedido (id, fecha, estado, total, forma_pago, usuario_id) OVERRIDING SYSTEM VALUE VALUES
    (1, '2026-06-13', 'TERMINADO',  0, 'TRANSFERENCIA', 10130),
    (2, '2026-08-14', 'TERMINADO',  0, 'TARJETA',        7636),
    (3, '2026-04-03', 'CANCELADO',  0, 'TARJETA',       16226),
    (4, '2026-03-10', 'PENDIENTE',  0, 'EFECTIVO',       5366),
    (5, '2025-09-25', 'CONFIRMADO', 0, 'EFECTIVO',      17023);

-- Detalles: el subtotal lo recalcula trg_subtotal (cantidad * precio_unitario)
INSERT INTO detalle_pedido (id, cantidad, precio_unitario, subtotal, pedido_id, producto_id) OVERRIDING SYSTEM VALUE VALUES
    (1,      2,  993.26, 0, 1, 43068),
    (200001, 2, 7500.00, 0, 1, 1),
    (2,      2,  993.26, 0, 2, 38264),
    (200002, 2, 7500.00, 0, 2, 1),
    (3,      2,  993.26, 0, 3, 49690),
    (200003, 2, 7500.00, 0, 3, 1),
    (4,      2,  993.26, 0, 4, 7470),
    (200004, 2, 7500.00, 0, 4, 1),
    (5,      2,  993.26, 0, 5, 46542),
    (200005, 2, 7500.00, 0, 5, 1);

COMMIT;
