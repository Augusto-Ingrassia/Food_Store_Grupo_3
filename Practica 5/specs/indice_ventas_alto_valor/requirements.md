# Requisitos — indice_ventas_alto_valor

## Contexto

La tabla `detalle_pedido` registra cada línea de los pedidos del food store.
Una alerta de ventas inusualmente altas se ejecuta en tiempo real cada vez que
ingresa un pedido nuevo. Actualmente esa alerta realiza un **Parallel Seq Scan**
completo sobre `detalle_pedido`, lo que la hace costosa conforme crece la tabla.

Consulta afectada:

```sql
SELECT pedido_id, producto_id, cantidad, subtotal
FROM   detalle_pedido
WHERE  subtotal > 15000
  AND  eliminado = FALSE
ORDER  BY subtotal DESC;
```

## Requisitos funcionales

### RF-1 — Índice parcial sobre `subtotal`

El sistema DEBE disponer de un índice que soporte la consulta anterior de forma
eficiente. El índice DEBE:

1. Cubrir la columna `subtotal` con capacidad para búsquedas por rango
   (`subtotal > valor`).
2. Estar restringido a las filas con `eliminado = FALSE` (índice parcial) para
   alinear con el patrón de soft-delete del proyecto.
3. Permitir que el motor resuelva el `ORDER BY subtotal DESC` sin un paso de
   ordenamiento separado.

### RF-2 — Sin ruptura de contratos existentes

El nuevo índice DEBE ser compatible con:

- Las restricciones de `schema.sql` (columnas `subtotal`, `eliminado`).
- El trigger `trg_subtotal`, que mantiene `subtotal` automáticamente; el índice
  se actualiza por el motor en cada INSERT/UPDATE sin intervención manual.
- El mecanismo de soft-delete: filas con `eliminado = TRUE` quedan fuera del
  índice, reduciendo su tamaño.

### RF-3 — Integración en `schema.sql`

La sentencia `CREATE INDEX` DEBE agregarse en `schema.sql`, junto a los índices
ya existentes (`idx_producto_categoria`, `idx_pedido_usuario`,
`idx_producto_nombre_vigente`), con un comentario que explique su propósito.

## Requisitos no funcionales

### RNF-1 — Cambio de plan de ejecución

Después de aplicar el índice y ejecutar `ANALYZE detalle_pedido`, el plan
producido por `EXPLAIN (ANALYZE, BUFFERS)` sobre la consulta afectada DEBE
mostrar **Index Scan** o **Index Only Scan** en lugar de Parallel Seq Scan.

### RNF-2 — Reducción de tiempo de lectura

El tiempo de ejecución (ms) de la consulta afectada DEBE reducirse al menos a
la **mitad** respecto al tiempo medido con Seq Scan.

### RNF-3 — Mantenimiento automatico

El índice DEBE mantenerse automáticamente por PostgreSQL en cada operación DML
sobre `detalle_pedido`. No se requiere intervención manual.

## Criterio de aceptación

| # | Condición | Verificación |
|---|-----------|--------------|
| CA-1 | Plan muestra Index Scan o Index Only Scan | `EXPLAIN (ANALYZE, BUFFERS)` sobre la consulta afectada |
| CA-2 | Tiempo de ejecución ≤ 50 % del baseline con Seq Scan | Comparar `Execution Time` antes y después |
| CA-3 | `schema.sql` contiene el `CREATE INDEX` con índice parcial `WHERE eliminado = FALSE` | Revisión del archivo |
| CA-4 | Los datos existentes no se ven afectados | `SELECT COUNT(*) FROM detalle_pedido WHERE eliminado = FALSE` igual antes y después |
