# Tareas de implementación — indice_clientes_tarjeta

## Tarea 1 — Agregar el índice en `schema.sql`

**Archivo:** `schema.sql`

Localizar el bloque de índices existentes (después de `idx_pedido_usuario`) e
insertar el nuevo índice a continuación:

```sql
-- Índice parcial cubriente para la consulta de mejores clientes con tarjeta
-- Soporta: RF-1, RNF-1, RNF-2
CREATE INDEX idx_pedido_tarjeta_vigente
    ON pedido (forma_pago, usuario_id, total)
    WHERE eliminado = FALSE;
```

**Criterio de completitud:**
- El bloque de índices en `schema.sql` queda así (en orden):
  1. `idx_producto_categoria`
  2. `idx_pedido_usuario`
  3. `idx_pedido_tarjeta_vigente`  ← nuevo
  4. `idx_producto_nombre_vigente`
- El archivo sigue siendo ejecutable desde cero sobre una BD vacía.

---

## Tarea 2 — Verificar el plan de ejecución con EXPLAIN ANALYZE

**Archivo:** `Practica 5/query.sql`

Agregar al final del archivo el bloque que primero crea el índice (para que el
archivo sea auto-suficiente como demo) y luego ejecuta `EXPLAIN ANALYZE`:

```sql
-- ============================================================
-- Creación del índice (ejecutar una sola vez; skip si ya existe)
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_pedido_tarjeta_vigente
    ON pedido (forma_pago, usuario_id, total)
    WHERE eliminado = FALSE;

-- ============================================================
-- Consulta 3 (DESPUÉS del índice) — Mejores clientes por tarjeta
-- ============================================================
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT u.nombre, u.apellido, u.mail, SUM(p.total) AS total_gastado
FROM   usuario u
JOIN   pedido  p ON u.id = p.usuario_id
WHERE  p.forma_pago = 'TARJETA'
  AND  p.eliminado  = FALSE
GROUP  BY u.id, u.nombre, u.apellido, u.mail
HAVING SUM(p.total) > 100000
ORDER  BY total_gastado DESC;
```

**Criterio de completitud:**
- Al ejecutar sobre la BD con datos de `data.sql` + `Practica 3/seed_masivo.sql`,
  el plan **no** contiene `Seq Scan on pedido`.
- El plan contiene `Bitmap Index Scan on idx_pedido_tarjeta_vigente`
  o `Index Scan on idx_pedido_tarjeta_vigente` (o `Index Only Scan`).

---

## Tarea 3 — Completar el informe de mediciones (sección "Despues")

**Archivo:** `Practica 5/informe_mediciones_consulta3.md`

Tras ejecutar la Tarea 2, copiar la salida de `EXPLAIN ANALYZE` y completar la
sección "Despues" del informe con:

1. El plan de ejecución completo (en bloque de código).
2. Una tabla comparativa Antes / Después con las métricas clave:

| Métrica                   | Antes         | Después       |
|---------------------------|---------------|---------------|
| Tipo de acceso a `pedido` | Seq Scan      | Index/Bitmap  |
| Filas leídas del heap     | 200.000       | ~66.600       |
| HashAggregate Batches     | 5             | 1             |
| Disk Usage (aggregate)    | 200 kB        | 0 kB          |
| Execution Time            | 204 ms        | < X ms        |

3. Una explicación de por qué el índice parcial cubriente es efectivo para este
   patrón de consulta (2-3 oraciones, en español).

**Criterio de completitud:**
- La sección "Despues" en el `.md` ya no está vacía.
- La tabla comparativa refleja los valores reales obtenidos al ejecutar la consulta.

---

## Tarea 4 — Verificar integridad del orden de ejecución

Confirmar que, al ejecutar los scripts en el orden correcto sobre una BD vacía:

```
schema.sql → objects.sql → data.sql → queries.sql → transacciones.sql
```

No se produce ningún error relacionado con el nuevo índice. En particular:
- `schema.sql` termina sin errores (el índice se crea sobre una tabla ya definida).
- `data.sql` inserta pedidos normalmente (los triggers siguen funcionando).
- `SELECT * FROM v_pedidos_resumen;` devuelve al menos 2 filas con totales no nulos.

**Criterio de completitud:**
- Los cuatro scripts se ejecutan sin errores.
- `v_pedidos_resumen` devuelve al menos 2 pedidos con `total > 0`.
