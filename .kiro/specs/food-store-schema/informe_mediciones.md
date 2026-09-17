# Informe de mediciones — mv_facturacion_categoria_mes

Fecha: 2026-09-17
Entorno: PostgreSQL 17.10 temporal (localhost:54399, DB food_store_test), datos de `data.sql` (3 categorías, 4 productos, 3 usuarios, 2 pedidos, 4 detalles).
Spec: `vista_materializada_facturacion.md`

## 1. Consulta analítica original (sin materializar)

```sql
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
GROUP BY c.nombre, DATE_TRUNC('month', p.fecha)::date;
```

Plan (`EXPLAIN ANALYZE`):
```
GroupAggregate (actual time=0.190..0.193 rows=2 loops=1)
  -> Sort + Hash Join x3 + Seq Scan x4 (detalle_pedido, pedido, producto, categoria)
Planning Time: 2.714 ms
Execution Time: 0.314 ms
```

## 2. Consulta sobre la vista materializada

```sql
SELECT * FROM mv_facturacion_categoria_mes;
```

Plan (`EXPLAIN ANALYZE`):
```
Seq Scan on mv_facturacion_categoria_mes (actual time=0.010..0.010 rows=2 loops=1)
Planning Time: 0.487 ms
Execution Time: 0.018 ms
```

Resultado:
```
Bebidas            | 2026-09-01 |  800.00 | 1
Pizzas y Empanadas | 2026-09-01 | 7500.00 | 2
```

## 3. Comparativa

| Consulta | Planning | Execution |
|---|---|---|
| Analítica original | 2.714 ms | 0.314 ms |
| `mv_facturacion_categoria_mes` | 0.487 ms | 0.018 ms |

La vista materializada evita los 3 `Hash Join`, el `Sort` y el `GroupAggregate`: ~17x más rápida en ejecución (0.314 ms → 0.018 ms) con este volumen de prueba. Índice único `uq_mv_facturacion_categoria_mes ON (categoria, mes)` verificado, habilita `REFRESH MATERIALIZED VIEW CONCURRENTLY` a futuro.
