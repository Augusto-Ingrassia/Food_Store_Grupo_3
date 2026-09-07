-- Productos más vendidos (volumen de alimentos)
EXPLAIN ANALYZE SELECT prod.nombre AS producto, SUM(dp.cantidad) AS unidades_vendidas
FROM producto prod
JOIN detalle_pedido dp ON prod.id = dp.producto_id
JOIN pedido p ON dp.pedido_id = p.id
WHERE p.estado IN ('CONFIRMADO', 'TERMINADO')
GROUP BY prod.nombre
ORDER BY unidades_vendidas DESC;

-- Volumen de artículos según forma de pago
EXPLAIN ANALYZE SELECT p.forma_pago, SUM(dp.cantidad) AS total_articulos
FROM pedido p
JOIN detalle_pedido dp ON p.id = dp.pedido_id
JOIN producto prod ON dp.producto_id = prod.id
GROUP BY p.forma_pago
ORDER BY total_articulos DESC;