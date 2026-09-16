# Diseño — indice_ventas_alto_valor

## Análisis de la consulta

```sql
SELECT pedido_id, producto_id, cantidad, subtotal
FROM   detalle_pedido
WHERE  subtotal > 15000        -- filtro de rango sobre subtotal
  AND  eliminado = FALSE       -- soft-delete
ORDER  BY subtotal DESC;       -- ordenamiento sobre la misma columna
```

Columnas relevantes:

| Rol | Columna | Tipo |
|-----|---------|------|
| Filtro de rango | `subtotal` | `NUMERIC(12,2)` |
| Predicado constante | `eliminado` | `BOOLEAN` |
| Ordenamiento | `subtotal` | mismo |
| Proyección | `pedido_id`, `producto_id`, `cantidad` | BIGINT / INTEGER |

## Decisiones de diseño

### 1. Índice B-tree sobre `subtotal`

PostgreSQL usa B-tree por defecto y es el tipo correcto para:
- Comparaciones de rango (`>`, `<`, `BETWEEN`).
- Ordenamiento alineado con `ORDER BY subtotal DESC` (el índice puede
  recorrerse en sentido inverso sin sort adicional).

No se usa GIN ni BRIN porque el acceso es por rango selectivo, no por
igualdad masiva ni por correlación física.

### 2. Índice parcial `WHERE eliminado = FALSE`

El patrón de soft-delete del proyecto garantiza que **todas** las consultas
operativas filtran `eliminado = FALSE`. Restringir el índice a ese subconjunto:

- Reduce el tamaño del índice (las filas eliminadas no ocupan espacio en él).
- Permite que el planner use el índice directamente sin verificar la condición
  en un segundo filtro, porque el predicado del índice implica el de la
  consulta.
- Es coherente con `idx_producto_nombre_vigente`, el índice parcial ya
  existente en el proyecto.

### 3. Índice no cubriente (no INCLUDE)

La consulta proyecta `pedido_id`, `producto_id` y `cantidad`, que no están en
el índice. Por lo tanto el resultado será **Index Scan** (no Index Only Scan)
salvo que se agreguen esas columnas con `INCLUDE`. Se elige **no** usar
`INCLUDE` por ahora porque:

- La selectividad del filtro (`subtotal > 15000`) será baja (pocos registros
  pasan el umbral), lo que hace que el heap fetch sea barato.
- Agregar tres columnas más al índice aumenta su costo de escritura en cada
  INSERT/UPDATE, y el trigger `trg_subtotal` ya genera escrituras frecuentes.

Si en el futuro el heap fetch se vuelve un cuello de botella, se puede
evolucionar a un índice cubriente con `INCLUDE (pedido_id, producto_id, cantidad)`.

### 4. Nombre del índice

`idx_detalle_subtotal_vigente`

Sigue la convención `idx_<tabla>_<columna>_<calificador>` del proyecto.

## Definición final del índice

```sql
-- Índice parcial para acelerar la alerta de ventas inusualmente altas.
-- Cubre búsquedas por rango sobre subtotal filtrando solo filas vigentes,
-- alineado con el patrón de soft-delete del proyecto.
CREATE INDEX idx_detalle_subtotal_vigente
    ON detalle_pedido (subtotal DESC)
    WHERE eliminado = FALSE;
```

Puntos clave de la sintaxis:

- `subtotal DESC`: ordena el índice de mayor a menor, de modo que el
  `ORDER BY subtotal DESC` de la consulta puede resolverse leyendo el índice
  en orden directo, sin pasos adicionales de sort.
- `WHERE eliminado = FALSE`: predicado parcial.

## Plan de ejecución esperado

```
Index Scan using idx_detalle_subtotal_vigente on detalle_pedido
  Index Cond: (subtotal > 15000.00)
```

El planner no necesita verificar `eliminado = FALSE` como filtro adicional
porque el predicado parcial del índice lo garantiza.

## Dónde se agrega

`schema.sql`, después del bloque de índices existente (líneas que contienen
`idx_producto_categoria`, `idx_pedido_usuario`, `idx_producto_nombre_vigente`).

## Verificación

```sql
-- 1. Actualizar estadísticas
ANALYZE detalle_pedido;

-- 2. Ver el plan
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT pedido_id, producto_id, cantidad, subtotal
FROM   detalle_pedido
WHERE  subtotal > 15000
  AND  eliminado = FALSE
ORDER  BY subtotal DESC;

-- 3. Confirmar que no se perdieron filas
SELECT COUNT(*) FROM detalle_pedido WHERE eliminado = FALSE;
```

El plan resultante DEBE contener `Index Scan` o `Index Only Scan` y el campo
`Execution Time` DEBE ser ≤ 50 % del valor baseline medido antes de crear el índice.
