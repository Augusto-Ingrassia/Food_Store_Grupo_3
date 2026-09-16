# Documento de Requisitos

## Introducción

Esta funcionalidad agrega un índice compuesto a la tabla `pedido` para optimizar el reporte de auditoría de pedidos cancelados pagados en efectivo. Actualmente la consulta de cierre de caja incurre en un `Seq Scan` seguido de un `Sort` explícito en memoria. El índice debe permitir que PostgreSQL 16+ use un `Index Scan` o `Bitmap Heap Scan`, eliminando el nodo `Sort` y reduciendo el tiempo de ejecución de forma perceptible. El proyecto es de SQL puro; no existe código de aplicación.

---

## Glosario

- **Sistema_BD**: El motor PostgreSQL 16+ que gestiona la base de datos de la tienda de comida.
- **Índice_Pedido_Cancelado**: El índice compuesto creado sobre la tabla `pedido` para soportar el reporte de auditoría.
- **Reporte_Auditoria**: La consulta `SELECT id, fecha, total, usuario_id FROM pedido WHERE estado = 'CANCELADO' AND forma_pago = 'EFECTIVO' AND eliminado = FALSE ORDER BY fecha DESC` ejecutada diariamente al cierre de caja.
- **Plan_Ejecucion**: La salida de `EXPLAIN (ANALYZE, BUFFERS)` para la consulta `Reporte_Auditoria`.
- **Seq_Scan**: Nodo en el `Plan_Ejecucion` que indica lectura secuencial completa de la tabla.
- **Sort_Memoria**: Nodo `Sort` en el `Plan_Ejecucion` que indica ordenamiento en memoria fuera del índice.
- **estado_pedido**: Tipo enum definido en `schema.sql` con valores `PENDIENTE`, `CONFIRMADO`, `TERMINADO`, `CANCELADO`.
- **forma_pago**: Tipo enum definido en `schema.sql` con valores `TARJETA`, `TRANSFERENCIA`, `EFECTIVO`.
- **eliminado**: Columna `BOOLEAN DEFAULT FALSE` presente en todas las tablas; habilita el soft-delete.

---

## Requisitos

### Requisito 1: Creación del índice compuesto

**Historia de usuario:** Como DBA del proyecto, quiero un índice compuesto sobre `pedido(estado, forma_pago, eliminado, fecha DESC)` para que la consulta de auditoría de cierre de caja deje de realizar un `Seq Scan` y un `Sort` explícito.

#### Criterios de aceptación

1. THE `Sistema_BD` SHALL contener un índice denominado `idx_pedido_cancelado_efectivo` definido sobre las columnas `(estado, forma_pago, eliminado, fecha DESC)` de la tabla `pedido`.
2. WHEN el índice `idx_pedido_cancelado_efectivo` no existe en la base de datos, THE `Sistema_BD` SHALL crear el índice mediante la sentencia `CREATE INDEX IF NOT EXISTS idx_pedido_cancelado_efectivo ON pedido (estado, forma_pago, eliminado, fecha DESC)` sin bloquear la tabla durante la creación.
3. THE `Sistema_BD` SHALL crear el índice usando el método de acceso B-Tree, que es el único compatible con el operador de igualdad sobre tipos enum y con la dirección de ordenamiento `DESC` sobre `fecha`.
4. WHEN el índice `idx_pedido_cancelado_efectivo` ya existe y se ejecuta la sentencia de creación, THE `Sistema_BD` SHALL omitir la operación sin devolver un error, preservando el índice existente.

---

### Requisito 2: Eliminación del Seq Scan en el Reporte de Auditoría

**Historia de usuario:** Como analista de cierre de caja, quiero que el `Reporte_Auditoria` use un acceso por índice para que el tiempo de ejecución baje de forma perceptible respecto al `Seq Scan` previo.

#### Criterios de aceptación

1. WHEN el `Reporte_Auditoria` se ejecuta con el índice `idx_pedido_cancelado_efectivo` presente, THE `Plan_Ejecucion` SHALL contener el nodo `Index Scan` o `Bitmap Heap Scan` sobre `idx_pedido_cancelado_efectivo`, y SHALL NOT contener el nodo `Seq Scan` sobre la tabla `pedido`.
2. WHEN el `Reporte_Auditoria` se ejecuta con el índice `idx_pedido_cancelado_efectivo` presente y las estadísticas de la tabla están actualizadas, THE `Plan_Ejecucion` SHALL NOT contener un nodo `Sort` sobre la columna `fecha`, dado que el índice ya provee las filas en orden `DESC` por `fecha`.
3. WHILE la tabla `pedido` contiene al menos 1 fila con `estado = 'CANCELADO'`, `forma_pago = 'EFECTIVO'` y `eliminado = FALSE`, THE `Reporte_Auditoria` SHALL devolver exactamente las filas que satisfacen esas tres condiciones, ordenadas de mayor a menor por `fecha`.
4. IF la tabla `pedido` no contiene ninguna fila con `estado = 'CANCELADO'`, `forma_pago = 'EFECTIVO'` y `eliminado = FALSE`, THEN THE `Reporte_Auditoria` SHALL devolver un resultado vacío sin error.

---

### Requisito 3: Compatibilidad con soft-delete y tipos enum

**Historia de usuario:** Como desarrollador del proyecto, quiero que el índice respete los patrones del esquema existente para que no se rompa la consistencia con el resto del código.

#### Criterios de aceptación

1. THE `Índice_Pedido_Cancelado` SHALL incluir la columna `eliminado` como columna de filtro en el índice, de modo que las consultas con `eliminado = FALSE` puedan beneficiarse del acceso por índice sin necesidad de un filtro adicional fuera del mismo.
2. THE `Índice_Pedido_Cancelado` SHALL referenciar los valores de `estado` y `forma_pago` mediante los tipos enum `estado_pedido` y `forma_pago` definidos en `schema.sql`, sin usar cadenas de texto literales en la definición del índice.
3. WHEN se ejecuta `EXPLAIN (ANALYZE, BUFFERS)` sobre el `Reporte_Auditoria` tras la creación del índice, THE `Plan_Ejecucion` SHALL mostrar `Index Cond` que incluya las columnas `estado`, `forma_pago` y `eliminado` como condiciones de filtro aplicadas dentro del índice.

---

### Requisito 4: Ubicación y convención del objeto en schema.sql

**Historia de usuario:** Como integrante del equipo, quiero que el índice se agregue en `schema.sql` siguiendo las convenciones del proyecto para que el orden de ejecución de los scripts se mantenga correcto.

#### Criterios de aceptación

1. THE `Sistema_BD` SHALL registrar la sentencia `CREATE INDEX IF NOT EXISTS idx_pedido_cancelado_efectivo` en el archivo `schema.sql`, después de la definición de la tabla `pedido` y antes del final del archivo.
2. THE `Sistema_BD` SHALL ejecutar `schema.sql` sin errores sobre una base de datos vacía que tenga los tipos enum `estado_pedido` y `forma_pago` ya creados en la misma sesión.
3. WHEN `schema.sql` se ejecuta por segunda vez sobre una base de datos que ya contiene el índice `idx_pedido_cancelado_efectivo`, THE `Sistema_BD` SHALL completar la ejecución sin errores gracias a la cláusula `IF NOT EXISTS`.
