# Diseño — indice_clientes_tarjeta

## Estado actual de la tabla `pedido`

```
pedido (200.000 filas aprox.)
┌─────────────┬───────────────┬──────────────────────────────┐
│ Columna     │ Tipo          │ Índices existentes           │
├─────────────┼───────────────┼──────────────────────────────┤
│ id          │ BIGINT PK     │ PK (B-Tree automático)       │
│ fecha       │ DATE          │ —                            │
│ estado      │ estado_pedido │ —                            │
│ total       │ NUMERIC(12,2) │ —                            │
│ forma_pago  │ forma_pago    │ —   ← filtro sin índice      │
│ usuario_id  │ BIGINT FK     │ idx_pedido_usuario (B-Tree)  │
│ eliminado   │ BOOLEAN       │ —   ← filtro sin índice      │
│ created_at  │ TIMESTAMPTZ   │ —                            │
└─────────────┴───────────────┴──────────────────────────────┘
```

## Plan de ejecución actual (baseline)

```
Sort  (cost=6433..6450)  (actual time=179..179 ms)
  ->  HashAggregate  Batches: 5  Memory: 8241 kB  Disk: 200 kB
        ->  Hash Join
              ->  Seq Scan on pedido          ← PROBLEMA
                    Filter: eliminado=FALSE AND forma_pago='TARJETA'
                    Rows Removed: 133.403 de 200.000
              ->  Hash on usuario (20.000 filas)
Execution Time: 204 ms
```

El Seq Scan lee las 200.000 páginas del heap de `pedido` para retener solo
~66.600 filas (≈ 33 %). El HashAggregate luego derrama a disco porque procesa
19.313 grupos distintos.

## Diseño del índice

### Tipo de índice

B-Tree (predeterminado en PostgreSQL). Es el único tipo que soporta predicados
de igualdad, rangos, y puede ser usado para Index Only Scan en consultas de
agregación.

### Estrategia: índice parcial cubriente

Un **índice parcial cubriente** combina dos técnicas:

1. **Parcial** (`WHERE eliminado = FALSE`): excluye las filas soft-deleted del
   índice. En tablas con patrón soft-delete esto reduce el tamaño del índice y
   el overhead de mantenimiento en UPDATEs que solo cambian `eliminado`.

2. **Cubriente** (columnas `forma_pago, usuario_id, total`): incluye todas las
   columnas que la consulta necesita leer. PostgreSQL puede responder con un
   **Index Only Scan** sin tocar el heap si la visibility map está actualizada
   (lo que ocurre después de un VACUUM, que PostgreSQL ejecuta automáticamente).

### Orden de columnas en el índice

```
idx_pedido_tarjeta_vigente (forma_pago, usuario_id, total)
WHERE eliminado = FALSE
```

| Posición | Columna      | Razón de orden                                       |
|----------|--------------|------------------------------------------------------|
| 1        | `forma_pago` | Predicado de igualdad (`= 'TARJETA'`). Colocarlo     |
|          |              | primero hace que PostgreSQL salte directamente a la  |
|          |              | subsección del índice para ese valor del enum.       |
| 2        | `usuario_id` | Columna del JOIN. Al estar contigua a `forma_pago`   |
|          |              | dentro del mismo valor de pago, los IDs de usuario   |
|          |              | para clientes con tarjeta quedan agrupados.          |
| 3        | `total`      | Solo necesaria para la proyección `SUM(total)`.      |
|          |              | No participa en ningún predicado ni en el JOIN, por  |
|          |              | lo que va al final.                                  |

### Alternativas descartadas

| Alternativa                                        | Motivo de descarte                          |
|----------------------------------------------------|---------------------------------------------|
| Índice simple en `forma_pago`                      | No cubre `usuario_id` ni `total`;           |
|                                                    | el planner igual haría Bitmap Heap Scan.    |
| Índice en `(forma_pago, eliminado, usuario_id, total)` | `eliminado` como columna ocupa espacio     |
|                                                    | extra y no aporta selectividad adicional    |
|                                                    | frente al predicado parcial.                |
| Índice en `usuario_id` (ya existe `idx_pedido_usuario`) | No filtra por `forma_pago`; el planner    |
|                                                    | no lo usaría para esta consulta.            |

## Plan de ejecución esperado después del índice

```
Sort  (actual time=~X ms)
  ->  HashAggregate  Batches: 1  Memory: ~YkB  (sin spill)
        ->  Hash Join  (o Nested Loop si el optimizador lo prefiere)
              ->  Bitmap Heap Scan on pedido
                    Recheck: (ninguno, Index Only Scan posible)
                    ->  Bitmap Index Scan on idx_pedido_tarjeta_vigente
                          Index Cond: forma_pago = 'TARJETA'
              ->  Hash on usuario
```

- El Seq Scan desaparece.
- Solo ~66.600 filas entran al HashAggregate (vs. todas las del heap antes).
- Con menos grupos activos, el HashAggregate probablemente opere en Batches = 1.

## Impacto en escrituras

| Operación       | Efecto                                                     |
|-----------------|------------------------------------------------------------|
| INSERT pedido   | PostgreSQL inserta una entrada en el índice solo si        |
|                 | `eliminado = FALSE` (valor por defecto). Overhead mínimo.  |
| UPDATE total    | `fn_recalcular_total()` hace UPDATE de `pedido.total`;     |
| (vía trigger)   | PostgreSQL actualiza la entrada del índice afectada.       |
|                 | No hay cambio en la lógica de negocio.                     |
| DELETE lógico   | Un UPDATE que cambia `eliminado` de FALSE → TRUE           |
| (soft-delete)   | elimina la entrada del índice parcial automáticamente.     |

## Ubicación en `schema.sql`

El índice se agrega a continuación de los índices existentes, antes del bloque
de constraints adicionales:

```sql
-- Índice para soportar el historial de pedidos por usuario
CREATE INDEX idx_pedido_usuario ON pedido(usuario_id);

-- [NUEVO] Índice parcial cubriente para la consulta de mejores clientes con tarjeta
CREATE INDEX idx_pedido_tarjeta_vigente
    ON pedido (forma_pago, usuario_id, total)
    WHERE eliminado = FALSE;
```
