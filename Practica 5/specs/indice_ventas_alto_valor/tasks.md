# Tareas — indice_ventas_alto_valor

## T-1 — Medir baseline antes del índice

- [ ] Conectarse a la base de datos con la carga de datos de `data.sql` aplicada.
- [ ] Ejecutar `ANALYZE detalle_pedido;` para asegurar estadísticas actualizadas.
- [ ] Ejecutar la consulta con `EXPLAIN (ANALYZE, BUFFERS)` y anotar:
  - Tipo de nodo del plan (esperado: `Parallel Seq Scan`).
  - Valor de `Execution Time` (ms).
  - Valor de `Buffers: shared hit` y `read`.
- [ ] Guardar el plan completo como comentario en `Practica 5/` o como bloque
  de referencia en el archivo donde se registren los resultados.

> Esta medición es el baseline contra el que se valida CA-2.

---

## T-2 — Agregar el índice en `schema.sql`

- [ ] Abrir `schema.sql`.
- [ ] Localizar el bloque de índices existentes (buscar `idx_producto_nombre_vigente`).
- [ ] Añadir a continuación el siguiente bloque:

```sql
-- Índice parcial para acelerar la alerta de ventas inusualmente altas.
-- Cubre búsquedas por rango sobre subtotal filtrando solo filas vigentes,
-- alineado con el patrón de soft-delete del proyecto.
CREATE INDEX idx_detalle_subtotal_vigente
    ON detalle_pedido (subtotal DESC)
    WHERE eliminado = FALSE;
```

- [ ] Guardar el archivo.

---

## T-3 — Aplicar el índice en la base de datos

Dos opciones según el estado de la base:

**Opción A — Base ya inicializada** (forma más rápida, sin recrear todo):

```sql
-- Ejecutar directamente en psql o pgAdmin
CREATE INDEX idx_detalle_subtotal_vigente
    ON detalle_pedido (subtotal DESC)
    WHERE eliminado = FALSE;

ANALYZE detalle_pedido;
```

**Opción B — Reset completo** (para garantizar reproducibilidad total):

```
1. DROP DATABASE food_store; CREATE DATABASE food_store;
2. \i schema.sql
3. \i objects.sql
4. \i data.sql
```

- [ ] Confirmar con `\d detalle_pedido` que el índice aparece en la lista.

---

## T-4 — Verificar el cambio de plan (CA-1)

- [ ] Ejecutar:

```sql
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT pedido_id, producto_id, cantidad, subtotal
FROM   detalle_pedido
WHERE  subtotal > 15000
  AND  eliminado = FALSE
ORDER  BY subtotal DESC;
```

- [ ] Confirmar que el plan muestra `Index Scan using idx_detalle_subtotal_vigente`
  o `Index Only Scan`.
- [ ] Si el planner sigue eligiendo Seq Scan (puede ocurrir con tablas pequeñas
  por el overhead de setup del índice), forzar la verificación con:

```sql
SET enable_seqscan = OFF;
EXPLAIN (ANALYZE, BUFFERS) ...misma consulta...;
RESET enable_seqscan;
```

  En producción con volumen real el planner elegirá el índice automáticamente.

---

## T-5 — Verificar reducción de tiempo (CA-2)

- [ ] Comparar el `Execution Time` medido en T-4 con el baseline de T-1.
- [ ] Calcular: `(tiempo_nuevo / tiempo_baseline) * 100`. El resultado DEBE
  ser ≤ 50 %.
- [ ] Documentar ambos valores (antes / después) en un comentario de la sección
  de resultados o en `Practica 5/` si corresponde.

---

## T-6 — Verificar integridad de datos (CA-4)

- [ ] Ejecutar antes y después de aplicar el índice:

```sql
SELECT COUNT(*) FROM detalle_pedido WHERE eliminado = FALSE;
```

- [ ] Confirmar que el conteo es idéntico en ambas mediciones.
- [ ] Ejecutar `SELECT * FROM v_pedidos_resumen;` y confirmar que los totales
  no cambiaron (los triggers siguen funcionando correctamente).

---

## T-7 — Revisar impacto en escrituras (opcional, buenas prácticas)

- [ ] Llamar a `sp_crear_pedido(...)` con un pedido de prueba y confirmar que:
  - El pedido se inserta correctamente.
  - El trigger `trg_subtotal` actualiza `subtotal`.
  - El índice `idx_detalle_subtotal_vigente` aparece en `\d detalle_pedido`
    sin errores.
- [ ] Verificar con `EXPLAIN (ANALYZE)` sobre la inserción que no hay
  degradación notable en el tiempo de escritura.

---

## Checklist de criterios de aceptación

| CA | Descripción | Tarea | Estado |
|----|-------------|-------|--------|
| CA-1 | Plan usa Index Scan o Index Only Scan | T-4 | ⬜ |
| CA-2 | Tiempo ≤ 50 % del baseline | T-5 | ⬜ |
| CA-3 | `schema.sql` contiene el `CREATE INDEX` parcial | T-2 | ⬜ |
| CA-4 | Conteo de filas vigentes idéntico antes y después | T-6 | ⬜ |
