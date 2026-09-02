-- Productos mas vendidos
SELECT pr.id, pr.nombre, SUM(dp.cantidad) AS unidades
FROM   detalle_pedido dp
JOIN   producto pr ON pr.id = dp.producto_id
WHERE  dp.eliminado = FALSE
GROUP  BY pr.id, pr.nombre ORDER  BY unidades desc LIMIT  5;

-- Facturacion por mes y categoria
SELECT c.nombre AS categoria, date_trunc('month', ped.fecha) AS mes, SUM(dp.subtotal) AS facturado FROM   detalle_pedido dp
JOIN   pedido   ped ON ped.id = dp.pedido_id AND ped.eliminado = FALSE
JOIN   producto pr  ON pr.id  = dp.producto_id
JOIN   categoria c  ON c.id   = pr.categoria_id
WHERE  dp.eliminado = FALSE
GROUP  BY c.nombre, date_trunc('month', ped.fecha)
ORDER  BY mes, facturado DESC;

-- Usuarios por gasto
SELECT u.id, u.nombre || ' ' || u.apellido AS usuario, SUM(ped.total) AS gasto, RANK() OVER (ORDER BY SUM(ped.total) DESC) AS puesto FROM   pedido ped
JOIN   usuario u ON u.id = ped.usuario_id
WHERE  ped.eliminado = FALSE
GROUP  BY u.id, u.nombre, u.apellido
ORDER  BY puesto;

-- Pedidos mayores al promedio
SELECT id, total FROM pedido 
WHERE  eliminado = false AND  total > (SELECT AVG(total) FROM pedido WHERE eliminado = FALSE)
ORDER  BY total DESC;

-- Productos con 0 ventas
SELECT pr.id, pr.nombre FROM   producto pr
LEFT   JOIN detalle_pedido dp
       ON dp.producto_id = pr.id AND dp.eliminado = FALSE
WHERE  pr.eliminado = false AND  dp.id IS NULL
ORDER  BY pr.id;
