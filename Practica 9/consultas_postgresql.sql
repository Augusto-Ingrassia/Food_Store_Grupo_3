-- =============================================================================
-- Práctica 9 (TP Unidad 7) — Parte 2, Consigna 5
-- Consultas en PostgreSQL equivalentes a los apartados b) y c) de MongoDB.
-- Base: food_store_nosql (ver reconstruccion_pedidos_pg.sql).
--
-- Filtro p.id IN (1,2,3,4,5): delimita el subconjunto migrado. En la base
-- completa del equipo (200.000 pedidos del seed masivo) estas consultas sin
-- ese filtro devolverían miles de pedidos y no serían comparables con la
-- colección de MongoDB, que solo tiene los 5 migrados.
-- =============================================================================

-- b) Pedidos en un estado existente en los datos migrados: TERMINADO
SELECT p.id, p.estado
FROM   pedido p
WHERE  p.estado = 'TERMINADO'
  AND  p.eliminado = FALSE
  AND  p.id IN (1, 2, 3, 4, 5)
ORDER  BY p.id;

-- c) Pedidos que contienen un producto determinado: producto_id = 43068
SELECT DISTINCT p.id
FROM   pedido p
JOIN   detalle_pedido d ON d.pedido_id = p.id
WHERE  d.producto_id = 43068
  AND  d.eliminado = FALSE
  AND  p.eliminado = FALSE
  AND  p.id IN (1, 2, 3, 4, 5)
ORDER  BY p.id;

-- c') Mismo criterio con el producto presente en todos los pedidos (id 1)
SELECT DISTINCT p.id
FROM   pedido p
JOIN   detalle_pedido d ON d.pedido_id = p.id
WHERE  d.producto_id = 1
  AND  d.eliminado = FALSE
  AND  p.eliminado = FALSE
  AND  p.id IN (1, 2, 3, 4, 5)
ORDER  BY p.id;

-- Control de coherencia usado para explicar la diferencia del apartado d):
-- total del pedido (mantenido por trg_total_ins) frente a la suma de sus líneas.
SELECT p.id, p.total, SUM(d.subtotal) AS suma_subtotales
FROM   pedido p
JOIN   detalle_pedido d ON d.pedido_id = p.id AND d.eliminado = FALSE
WHERE  p.id IN (1, 2, 3, 4, 5)
GROUP  BY p.id, p.total
ORDER  BY p.id;

-- d) Equivalente del apartado d) con el mismo umbral (15000)
SELECT p.id, p.total
FROM   pedido p
WHERE  p.total > 15000
  AND  p.eliminado = FALSE
  AND  p.id IN (1, 2, 3, 4, 5)
ORDER  BY p.id;
