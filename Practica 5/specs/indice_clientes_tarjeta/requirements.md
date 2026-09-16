# Requerimientos — indice_clientes_tarjeta

## Contexto

La consulta de mejores clientes que pagan con tarjeta se ejecuta mensualmente para
generar listas de promociones. Con 200.000 filas en `pedido`, el plan actual realiza
un **Seq Scan** que recorre toda la tabla y descarta ~133.000 filas, seguido de un
**HashAggregate** que derrama a disco (Batches: 5, Disk Usage: 200 kB).
El tiempo de ejecución medido en Práctica 5 es de **204 ms**.

Consulta afectada (Consulta 3, `Practica 5/query.sql`):

```sql
SELECT u.nombre, u.apellido, u.mail, SUM(p.total) AS total_gastado
FROM   usuario u
JOIN   pedido  p ON u.id = p.usuario_id
WHERE  p.forma_pago = 'TARJETA'
  AND  p.eliminado  = FALSE
GROUP  BY u.id, u.nombre, u.apellido, u.mail
HAVING SUM(p.total) > 100000
ORDER  BY total_gastado DESC;
```

## Requerimientos funcionales

### RF-1 — Creación del índice compuesto parcial

Se debe crear un índice **B-Tree parcial** sobre la tabla `pedido` que cubra
exactamente las columnas que la consulta necesita leer:

| Orden | Columna      | Motivo                                         |
|-------|--------------|------------------------------------------------|
| 1     | `forma_pago` | Predicado de igualdad — filtro principal       |
| 2     | `usuario_id` | Columna de JOIN con `usuario`                  |
| 3     | `total`      | Columna proyectada para `SUM()`                |

La condición `WHERE eliminado = FALSE` se expresa como **predicado parcial** del
índice, lo que excluye los registros borrados y mantiene el índice más compacto.

Nombre del índice: `idx_pedido_tarjeta_vigente`.

```sql
CREATE INDEX idx_pedido_tarjeta_vigente
    ON pedido (forma_pago, usuario_id, total)
    WHERE eliminado = FALSE;
```

**Justificación de la elección parcial frente a incluir `eliminado` como columna:**

- Un índice parcial con `WHERE eliminado = FALSE` es físicamente más pequeño
  porque nunca indexa las filas eliminadas (soft-delete patrón del proyecto).
- PostgreSQL puede hacer un **Index Only Scan** si la visibilidad de las páginas
  del heap está actualizada (VACUUM reciente), evitando accesos al heap.
- Un índice completo con cuatro columnas (`forma_pago, eliminado, usuario_id, total`)
  ocuparía más espacio y no aportaría beneficio adicional.

### RF-2 — El índice no debe interferir con las escrituras existentes

- `pedido.total` es mantenido automáticamente por los triggers `trg_total_ins` y
  `trg_total_upd`. El índice se actualiza de forma transparente por PostgreSQL en
  cada `UPDATE` que cambia `total`; no se requiere ningún cambio en esos triggers.
- `sp_crear_pedido` sigue siendo el único punto de creación de pedidos. El índice
  no modifica ese procedimiento.

### RF-3 — El script de Práctica 5 debe poder ejecutar EXPLAIN ANALYZE antes y después

El archivo `Practica 5/informe_mediciones_consulta3.md` tiene la sección "Despues"
vacía. Como parte de esta tarea se completará dicha sección con el plan obtenido
tras crear el índice, siguiendo el mismo formato que la sección "Antes".

### RF-4 — Compatibilidad con el orden de ejecución del proyecto

El índice debe crearse en `schema.sql`, después de la definición de la tabla
`pedido` y a continuación de los índices ya existentes, respetando el orden
de ejecución documentado en `AGENTS.md`:

```
schema.sql → objects.sql → data.sql → queries.sql → transacciones.sql
```

## Requerimientos no funcionales

### RNF-1 — Sin Seq Scan sobre `pedido` para la consulta afectada

Tras aplicar el índice, `EXPLAIN ANALYZE` debe mostrar
`Bitmap Index Scan` o `Index Scan` (o `Index Only Scan`) sobre
`idx_pedido_tarjeta_vigente`; nunca `Seq Scan on pedido` para esta consulta.

### RNF-2 — Reducción del spill a disco del HashAggregate

Con menos filas entrando al paso de agregación (solo las de `forma_pago = 'TARJETA'`
y `eliminado = FALSE`), el `HashAggregate` debe operar en memoria o con Batches = 1.

### RNF-3 — Consistencia de nombrado

El nombre del índice sigue la convención ya usada en el proyecto:
`idx_<tabla>_<descripción_corta>`.

### RNF-4 — Sin cambio en la lógica de negocio

No se modifica ninguna vista, función, trigger ni procedimiento almacenado.
Solo se agrega el índice y se documenta su efecto.
