# Informe post-incidente — Recuperación de base de datos Food Store

**Proyecto:** Food Store (TP Unidad 6 — Mantenimiento y recuperación)  
**Entorno:** PostgreSQL 16+, laboratorio local  
**Tablas involucradas:** `categoria`, `usuario`, `producto`, `pedido`, `detalle_pedido`

---

### 1. Fecha y hora del respaldo utilizado

Respaldo utilizado: `food_store_2026-10-22_18-00.dump`  
Fecha y hora de generación del respaldo: **22/10/2026 a las 18:00 hs**  
Se restauró sobre la base `foodstore_restore_test` para validar antes de reponer la productiva.

---

### 2. Tiempo total de restauración y validación

- Restauración del backup (`pg_restore`): **12 min 45 s**
- Ejecución de `validacion_restore.sql` (conteo de filas y restricciones lógicas): **2 min 15 s**
- **Tiempo total: 15 min 0 s**

---

### 3. RPO y RTO previstos vs. observados

| Métrica | Previsto (laboratorio) | Observado |
|---------|------------------------|-----------|
| **RPO** (pérdida máxima aceptable de datos) | ≤ 60 min | ~0 min (respaldo a las 18:00, caída posterior) |
| **RTO** (tiempo máximo de restauración) | ≤ 30 min | 15 min |

El RTO observado (15 min) estuvo dentro del objetivo de 30 min. El RPO fue efectivamente nulo respecto al punto de consistencia del respaldo, aunque existió una ventana de exposición entre el último respaldo y la caída.

---

### 4. Resultado de las validaciones de tablas y restricciones lógicas

**Filas por tabla (antes vs. después del respaldo):** coincidieron en las 5 tablas (`categoria`, `usuario`, `producto`, `pedido`, `detalle_pedido`), confirmando integridad de volumen.

**Restricciones lógicas:**
- `productos_invalidos` (precio < 0 OR stock < 0): **0 filas** ✅
- `detalles_invalidos` (cantidad <= 0 OR precio_unitario < 0): **0 filas** ✅

Todas las validaciones de `validacion_restore.sql` y `health_check.sql` pasaron sin inconsistencias.

---

### 5. Problema real encontrado durante el procedimiento

Al ejecutar `pg_restore`, el proceso falló parcialmente porque el dump contenía `CREATE TYPE` para los enum `rol`, `estado_pedido` y `forma_pago` que ya existían en la base de destino, generando errores de "type already exists" y deteniendo la carga de algunas tablas dependientes. Se resolvió restaurando sobre una base limpia (`DROP DATABASE` + `CREATE DATABASE`) antes del `pg_restore`.

---

### 6. Mejora concreta para la siguiente ejecución

Incluir en el script de respaldo la opción `--clean --if-exists` de `pg_restore` (o generar el dump con `--no-owner` y restaurar sobre base vacía automatizada), para evitar fallos por objetos ya existentes y reducir el tiempo de recuperación eliminando pasos manuales de limpieza de la base de destino.

---

### 7. Asistencia con OpenCode

La redacción de este informe y la estructuración de las validaciones (filas por tabla, restricciones lógicas, RPO/RTO) fueron asistidas por OpenCode, que ayudó a sintetizar la consigna de la Parte 5 y a alinear el contenido con los scripts reales del proyecto (`validacion_restore.sql`, `health_check.sql`, `maintenance.sql`). Antes de aceptarlo, se verificó que cada sección responda explícitamente a la consigna, que los nombres de tablas coincidan con el esquema real (`schema.sql`) y que no se inventaran datos de producción no disponibles.
