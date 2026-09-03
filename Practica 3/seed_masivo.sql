BEGIN;

-- 1. Poblar Categoria (Inserta 5 categorías iniciales si la tabla está vacía)
INSERT INTO categoria (nombre, descripcion)
VALUES 
    ('Comida Rápida', 'Hamburguesas, papas y combos'),
    ('Bebidas', 'Gaseosas, jugos y aguas'),
    ('Postres', 'Helados, tortas y dulces'),
    ('Pizzas y Empanadas', 'Pizzas variadas y empanadas artesanales'),
    ('Ensaladas', 'Opciones saludables y frescas')
ON CONFLICT (nombre) DO NOTHING;

-- 2. Insertar 50.000 productos respetando la restricción (stock > 0 cuando disponible = TRUE)
INSERT INTO producto (nombre, precio, descripcion, stock, disponible, categoria_id, eliminado)
SELECT 
    'Producto Masivo ' || g AS nombre,
    ROUND((500 + (random() * 4500))::numeric, 2) AS precio,
    'Descripción del producto masivo número ' || g AS descripcion,
    floor(1 + (random() * 200))::int AS stock, -- Stock entre 1 y 200 para cumplir CHECK
    TRUE AS disponible,
    (g % 5) + 1 AS categoria_id, -- Distribuidos entre las 5 categorías existentes
    FALSE AS eliminado
FROM generate_series(1, 50000) AS g;

-- 3. Insertar 20.000 usuarios usando el ENUM 'ADMIN' / 'USUARIO' y columnas exactas
INSERT INTO usuario (nombre, apellido, mail, celular, contrasena, rol, eliminado)
SELECT 
    'Nombre_' || g AS nombre,
    'Apellido_' || g AS apellido,
    'usuario_' || g || '@foodstore.com' AS mail,
    '+54911' || floor(10000000 + (random() * 89999999))::text AS celular,
    'hash_seguro_contrasena_' || g AS contrasena,
    (CASE WHEN g % 50 = 0 THEN 'ADMIN' ELSE 'USUARIO' END)::rol AS rol,
    FALSE AS eliminado
FROM generate_series(1, 20000) AS g;

-- 4. Insertar 200.000 pedidos respetando ENUMs 'estado_pedido' y 'forma_pago'
INSERT INTO pedido (fecha, estado, total, forma_pago, usuario_id, eliminado)
SELECT 
    CURRENT_DATE - (floor(random() * 365)::int) AS fecha,
    (ARRAY['PENDIENTE', 'CONFIRMADO', 'TERMINADO', 'CANCELADO'])[floor(1 + (random() * 4))::int]::estado_pedido AS estado,
    0.00 AS total, -- Se puede actualizar con los subtotales luego
    (ARRAY['TARJETA', 'TRANSFERENCIA', 'EFECTIVO'])[floor(1 + (random() * 3))::int]::forma_pago AS forma_pago,
    floor(1 + (random() * 19999))::int AS usuario_id,
    FALSE AS eliminado
FROM generate_series(1, 200000) AS g;

-- 5. Insertar detalles de pedido (1 a 3 items por pedido)
INSERT INTO detalle_pedido (cantidad, precio_unitario, subtotal, pedido_id, producto_id, eliminado)
SELECT 
    cant AS cantidad,
    prec AS precio_unitario,
    ROUND((cant * prec)::numeric, 2) AS subtotal,
    p.id AS pedido_id,
    floor(1 + (random() * 49999))::int AS producto_id,
    FALSE AS eliminado
FROM pedido p
CROSS JOIN LATERAL (
    SELECT 
        floor(1 + (random() * 5))::int AS cant,
        ROUND((500 + (random() * 4500))::numeric, 2) AS prec
) calc
CROSS JOIN LATERAL generate_series(1, floor(1 + (random() * 2))::int)
ON CONFLICT (pedido_id, producto_id) DO NOTHING; -- Evita duplicados en la restricción UNIQUE

COMMIT;

-- Actualización del optimizador para planes EXPLAIN reales
ANALYZE categoria;
ANALYZE producto;
ANALYZE usuario;
ANALYZE pedido;
ANALYZE detalle_pedido;