-- 1. Auditoría de pedidos cancelados en efectivo
EXPLAIN ANALYZE 
SELECT id, fecha, total, usuario_id 
FROM pedido 
WHERE estado = 'CANCELADO' 
  AND forma_pago = 'EFECTIVO' 
  AND eliminado = FALSE
ORDER BY fecha DESC;

-- 2. Listado de ventas de alto valor
EXPLAIN ANALYZE 
SELECT pedido_id, producto_id, cantidad, subtotal 
FROM detalle_pedido 
WHERE subtotal > 15000 
  AND eliminado = FALSE
ORDER BY subtotal DESC;

-- 3. Mejores clientes por método de pago
EXPLAIN ANALYZE 
SELECT u.nombre, u.apellido, u.mail, SUM(p.total) AS total_gastado
FROM usuario u
JOIN pedido p ON u.id = p.usuario_id
WHERE p.forma_pago = 'TARJETA'
  AND p.eliminado = FALSE
GROUP BY u.id, u.nombre, u.apellido, u.mail
HAVING SUM(p.total) > 100000
ORDER BY total_gastado DESC;
