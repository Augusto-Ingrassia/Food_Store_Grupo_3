-- Vista: v_productos_categoria
-- Objetivo: Simplificar el acceso a los productos vigentes junto con la información de su categoría.
-- Spec: specs/vista_productos_categoria.md (.kiro/specs/food-store-schema/specs/vista_productos_categoria.md)
-- Nota: el spec indica p.precio_unitario, pero la tabla producto expone la columna "precio"
-- (ver schema.sql). Se mapea p.precio AS precio_unitario para respetar la interfaz del spec
-- sin romper contra el esquema real.
CREATE OR REPLACE VIEW v_productos_categoria AS
SELECT
    p.id AS producto_id,
    p.nombre AS producto_nombre,
    p.precio AS precio_unitario,
    c.nombre AS categoria_nombre
FROM producto p
JOIN categoria c ON c.id = p.categoria_id
WHERE p.eliminado = FALSE AND c.eliminado = FALSE;

-- Vista: v_pedidos_usuario_segura
-- Objetivo: Ocultar credenciales sensibles de los usuarios en los reportes de pedidos.
-- Spec: specs/vista_pedidos_usuario_segura.md (.kiro/specs/food-store-schema/specs/vista_pedidos_usuario_segura.md)
-- Nota: el spec indica u.email, pero la tabla usuario expone la columna "mail"
-- (ver schema.sql). Se mapea u.mail AS email para respetar la interfaz del spec
-- sin romper contra el esquema real. No se expone u.contrasena por seguridad.
CREATE OR REPLACE VIEW v_pedidos_usuario_segura AS
SELECT
    p.id AS pedido_id,
    p.fecha,
    p.estado,
    p.total,
    u.id AS usuario_id,
    u.nombre AS usuario_nombre,
    u.mail AS email
FROM pedido p
JOIN usuario u ON u.id = p.usuario_id
WHERE p.eliminado = FALSE AND u.eliminado = FALSE;

-- Vista: v_detalle_pedido_producto
-- Objetivo: Exponer el detalle de cada pedido incluyendo el nombre del producto asociado.
-- Spec: specs/vista_detalle_pedido_producto.md (.kiro/specs/food-store-schema/specs/vista_detalle_pedido_producto.md)
CREATE OR REPLACE VIEW v_detalle_pedido_producto AS
SELECT
    dp.id AS detalle_id,
    dp.pedido_id,
    prod.nombre AS producto_nombre,
    dp.cantidad,
    dp.precio_unitario,
    dp.subtotal
FROM detalle_pedido dp
JOIN producto prod ON prod.id = dp.producto_id
WHERE dp.eliminado = FALSE AND prod.eliminado = FALSE;

-- Vista materializada: mv_facturacion_categoria_mes
-- Objetivo: Precalcular y almacenar la facturación agregada por categoría y mes
-- para acelerar reportes analíticos costosos.
-- Spec: specs/vista_materializada_facturacion.md (.kiro/specs/food-store-schema/specs/vista_materializada_facturacion.md)
DROP MATERIALIZED VIEW IF EXISTS mv_facturacion_categoria_mes;
CREATE MATERIALIZED VIEW mv_facturacion_categoria_mes AS
SELECT
    c.nombre AS categoria,
    DATE_TRUNC('month', p.fecha)::date AS mes,
    SUM(dp.subtotal) AS total_facturado,
    COUNT(DISTINCT p.id) AS cantidad_pedidos
FROM detalle_pedido dp
JOIN pedido p ON dp.pedido_id = p.id
JOIN producto prod ON dp.producto_id = prod.id
JOIN categoria c ON prod.categoria_id = c.id
WHERE dp.eliminado = FALSE
  AND p.eliminado = FALSE
  AND prod.eliminado = FALSE
  AND c.eliminado = FALSE
GROUP BY c.nombre, DATE_TRUNC('month', p.fecha)::date
WITH DATA;

-- Índice único para habilitar REFRESH MATERIALIZED VIEW CONCURRENTLY a futuro.
CREATE UNIQUE INDEX uq_mv_facturacion_categoria_mes
ON mv_facturacion_categoria_mes (categoria, mes);
