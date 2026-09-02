# Documento de Requisitos

## Introducción

Este documento describe los requisitos del esquema relacional para el sistema **Food Store**, una base de datos PostgreSQL que gestiona el catálogo de productos, usuarios, pedidos y sus detalles para una tienda de alimentos. El esquema debe garantizar integridad de datos, trazabilidad histórica mediante borrado lógico y soporte para objetos de base de datos (vistas, funciones, triggers y procedimientos almacenados) que automatizan la lógica de negocio.

---

## Glosario

- **Sistema**: El motor de base de datos PostgreSQL que ejecuta el esquema de Food Store.
- **Categoria**: Entidad que agrupa productos bajo una clasificación temática (ej. Pizzas, Bebidas).
- **Producto**: Artículo disponible para la venta, asociado a una Categoria.
- **Usuario**: Persona registrada en el sistema con rol ADMIN o USUARIO.
- **Pedido**: Orden de compra generada por un Usuario, compuesta por uno o más ítems.
- **Detalle_Pedido**: Línea de un Pedido que referencia un Producto con cantidad, precio unitario y subtotal.
- **Borrado_Lógico**: Patrón de baja de datos que utiliza la columna `eliminado = TRUE` en lugar de ejecutar `DELETE`.
- **ENUM**: Tipo de dato de PostgreSQL que restringe un campo a un conjunto cerrado de valores literales.
- **IDENTITY**: Mecanismo de PostgreSQL (`GENERATED ALWAYS AS IDENTITY`) que genera valores de clave primaria de forma automática.
- **Trigger**: Función de base de datos que se ejecuta automáticamente ante eventos DML (INSERT, UPDATE, DELETE) sobre una tabla.
- **sp_crear_pedido**: Procedimiento almacenado que encapsula la creación transaccional de un Pedido con sus Detalle_Pedido.

---

## Requisitos

### Requisito 1: Tipos Enumerados (ENUM)

**Historia de usuario:** Como administrador del sistema, quiero que los campos de estado de pedido, forma de pago y rol de usuario estén restringidos a valores predefinidos, para evitar el ingreso de texto libre incorrecto y garantizar la consistencia de los datos.

#### Criterios de Aceptación

1. THE Sistema SHALL definir el tipo `rol` como ENUM con los valores `'ADMIN'` y `'USUARIO'`.
2. THE Sistema SHALL definir el tipo `estado_pedido` como ENUM con los valores `'PENDIENTE'`, `'CONFIRMADO'`, `'TERMINADO'` y `'CANCELADO'`.
3. THE Sistema SHALL definir el tipo `forma_pago` como ENUM con los valores `'TARJETA'`, `'TRANSFERENCIA'` y `'EFECTIVO'`.
4. IF se intenta insertar un valor fuera del conjunto definido en cualquier ENUM, THEN THE Sistema SHALL rechazar la operación con un error de tipo de datos.

---

### Requisito 2: Tabla Categoria

**Historia de usuario:** Como administrador, quiero registrar categorías de productos con nombre y descripción, para clasificar el catálogo de la tienda.

#### Criterios de Aceptación

1. THE Sistema SHALL crear la tabla `categoria` con las columnas: `id`, `nombre`, `descripcion`, `eliminado` y `created_at`.
2. THE Sistema SHALL generar el `id` de `categoria` automáticamente mediante `GENERATED ALWAYS AS IDENTITY`.
3. THE Sistema SHALL definir `nombre` en `categoria` como `VARCHAR(80) NOT NULL UNIQUE`.
4. THE Sistema SHALL definir `eliminado` en `categoria` como `BOOLEAN NOT NULL DEFAULT FALSE`.
5. THE Sistema SHALL definir `created_at` en `categoria` como `TIMESTAMPTZ NOT NULL DEFAULT now()`.
6. WHEN se ejecuta una consulta sobre `categoria` con el filtro `eliminado = FALSE`, THE Sistema SHALL retornar únicamente las filas no eliminadas.

---

### Requisito 3: Tabla Producto

**Historia de usuario:** Como administrador, quiero registrar productos con precio, stock e imagen, asociados a una categoría existente, para mantener el catálogo de la tienda actualizado.

#### Criterios de Aceptación

1. THE Sistema SHALL crear la tabla `producto` con las columnas: `id`, `nombre`, `precio`, `descripcion`, `stock`, `imagen`, `disponible`, `categoria_id`, `eliminado` y `created_at`.
2. THE Sistema SHALL generar el `id` de `producto` automáticamente mediante `GENERATED ALWAYS AS IDENTITY`.
3. THE Sistema SHALL definir `precio` en `producto` como `NUMERIC(10,2) NOT NULL` con restricción `CHECK (precio >= 0)`.
4. THE Sistema SHALL definir `stock` en `producto` como `INTEGER NOT NULL DEFAULT 0` con restricción `CHECK (stock >= 0)`.
5. THE Sistema SHALL definir `disponible` en `producto` como `BOOLEAN NOT NULL DEFAULT TRUE`.
6. THE Sistema SHALL definir `categoria_id` en `producto` como clave foránea que referencia `categoria(id)` con `NOT NULL`.
7. IF se intenta insertar un `precio` menor a 0 en `producto`, THEN THE Sistema SHALL rechazar la operación con un error de restricción CHECK.
8. IF se intenta insertar un `stock` menor a 0 en `producto`, THEN THE Sistema SHALL rechazar la operación con un error de restricción CHECK.
9. WHEN se ejecuta una consulta sobre `producto` con el filtro `eliminado = FALSE`, THE Sistema SHALL retornar únicamente los productos no eliminados.

---

### Requisito 4: Tabla Usuario

**Historia de usuario:** Como administrador, quiero registrar usuarios con nombre, apellido, correo electrónico único y rol, para controlar el acceso al sistema.

#### Criterios de Aceptación

1. THE Sistema SHALL crear la tabla `usuario` con las columnas: `id`, `nombre`, `apellido`, `mail`, `celular`, `contrasena`, `rol`, `eliminado` y `created_at`.
2. THE Sistema SHALL generar el `id` de `usuario` automáticamente mediante `GENERATED ALWAYS AS IDENTITY`.
3. THE Sistema SHALL definir `mail` en `usuario` como `VARCHAR(120) NOT NULL UNIQUE`.
4. THE Sistema SHALL definir `contrasena` en `usuario` como `VARCHAR(255) NOT NULL`.
5. THE Sistema SHALL definir `rol` en `usuario` con el tipo ENUM `rol` y valor por defecto `'USUARIO'`.
6. IF se intenta insertar un `mail` duplicado en `usuario`, THEN THE Sistema SHALL rechazar la operación con un error de violación de restricción UNIQUE.
7. WHEN se ejecuta una consulta sobre `usuario` con el filtro `eliminado = FALSE`, THE Sistema SHALL retornar únicamente los usuarios no eliminados.

---

### Requisito 5: Tabla Pedido

**Historia de usuario:** Como usuario registrado, quiero crear pedidos asociados a mi cuenta con una forma de pago definida, para poder comprar productos de la tienda.

#### Criterios de Aceptación

1. THE Sistema SHALL crear la tabla `pedido` con las columnas: `id`, `fecha`, `estado`, `total`, `forma_pago`, `usuario_id`, `eliminado` y `created_at`.
2. THE Sistema SHALL generar el `id` de `pedido` automáticamente mediante `GENERATED ALWAYS AS IDENTITY`.
3. THE Sistema SHALL definir `estado` en `pedido` con el tipo ENUM `estado_pedido` y valor por defecto `'PENDIENTE'`.
4. THE Sistema SHALL definir `total` en `pedido` como `NUMERIC(12,2) NOT NULL DEFAULT 0` con restricción `CHECK (total >= 0)`.
5. THE Sistema SHALL definir `usuario_id` en `pedido` como clave foránea que referencia `usuario(id)` con `NOT NULL`.
6. THE Sistema SHALL definir `forma_pago` en `pedido` con el tipo ENUM `forma_pago` y valor `NOT NULL`.
7. IF se intenta insertar un `total` menor a 0 en `pedido`, THEN THE Sistema SHALL rechazar la operación con un error de restricción CHECK.

---

### Requisito 6: Tabla Detalle_Pedido

**Historia de usuario:** Como sistema, quiero registrar cada ítem de un pedido con cantidad, precio unitario y subtotal, para poder calcular el total del pedido y mantener el historial de compras.

#### Criterios de Aceptación

1. THE Sistema SHALL crear la tabla `detalle_pedido` con las columnas: `id`, `cantidad`, `precio_unitario`, `subtotal`, `pedido_id`, `producto_id`, `eliminado` y `created_at`.
2. THE Sistema SHALL generar el `id` de `detalle_pedido` automáticamente mediante `GENERATED ALWAYS AS IDENTITY`.
3. THE Sistema SHALL definir `cantidad` en `detalle_pedido` como `INTEGER NOT NULL` con restricción `CHECK (cantidad > 0)`.
4. THE Sistema SHALL definir `precio_unitario` en `detalle_pedido` como `NUMERIC(10,2) NOT NULL` con restricción `CHECK (precio_unitario >= 0)`.
5. THE Sistema SHALL definir `subtotal` en `detalle_pedido` como `NUMERIC(12,2) NOT NULL` con restricción `CHECK (subtotal >= 0)`.
6. THE Sistema SHALL definir `pedido_id` en `detalle_pedido` como clave foránea que referencia `pedido(id)` con `ON DELETE RESTRICT`.
7. THE Sistema SHALL definir `producto_id` en `detalle_pedido` como clave foránea que referencia `producto(id)` con `NOT NULL`.
8. THE Sistema SHALL definir una restricción UNIQUE sobre la combinación `(pedido_id, producto_id)` en `detalle_pedido`.
9. IF se intenta insertar una `cantidad` menor o igual a 0 en `detalle_pedido`, THEN THE Sistema SHALL rechazar la operación con un error de restricción CHECK.

---

### Requisito 7: Borrado Lógico

**Historia de usuario:** Como administrador, quiero que ningún registro se elimine físicamente de la base de datos, para mantener la trazabilidad histórica completa del sistema.

#### Criterios de Aceptación

1. THE Sistema SHALL incluir una columna `eliminado BOOLEAN NOT NULL DEFAULT FALSE` en cada una de las tablas: `categoria`, `producto`, `usuario`, `pedido` y `detalle_pedido`.
2. WHEN se realiza una baja de registro, THE Sistema SHALL actualizar `eliminado = TRUE` en la fila correspondiente en lugar de ejecutar `DELETE`.
3. WHILE `eliminado = FALSE`, THE Sistema SHALL considerar el registro como activo y visible en las consultas operacionales.
4. WHILE `eliminado = TRUE`, THE Sistema SHALL excluir el registro de todas las vistas y consultas que filtren por registros activos.

---

### Requisito 8: Generación Automática de Claves Primarias

**Historia de usuario:** Como desarrollador, quiero que todas las claves primarias sean generadas automáticamente por el motor de base de datos, para evitar conflictos de IDs y simplificar las operaciones de inserción.

#### Criterios de Aceptación

1. THE Sistema SHALL definir la columna `id` de cada tabla (`categoria`, `producto`, `usuario`, `pedido`, `detalle_pedido`) como `BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY`.
2. IF se intenta insertar un valor explícito para `id` en cualquier tabla con `GENERATED ALWAYS AS IDENTITY`, THEN THE Sistema SHALL rechazar la operación con un error de identidad.

---

### Requisito 9: Índices de Rendimiento

**Historia de usuario:** Como desarrollador, quiero que las consultas frecuentes (listado de productos por categoría e historial de pedidos por usuario) cuenten con índices, para garantizar tiempos de respuesta aceptables con volúmenes de datos crecientes.

#### Criterios de Aceptación

1. THE Sistema SHALL crear un índice sobre la columna `categoria_id` en la tabla `producto` para soportar el listado de productos por categoría.
2. THE Sistema SHALL crear un índice sobre la columna `usuario_id` en la tabla `pedido` para soportar el historial de pedidos por usuario.
3. THE Sistema SHALL crear un índice parcial sobre la columna `nombre` en la tabla `producto` con la condición `WHERE eliminado = FALSE` para optimizar búsquedas sobre productos vigentes.

---

### Requisito 10: Vistas de Consulta

**Historia de usuario:** Como desarrollador, quiero contar con vistas predefinidas que simplifiquen el acceso a los datos más consultados, para no repetir joins y filtros en cada consulta.

#### Criterios de Aceptación

1. THE Sistema SHALL crear la vista `v_categorias_vigentes` que retorne `id`, `nombre` y `descripcion` de categorías donde `eliminado = FALSE`.
2. THE Sistema SHALL crear la vista `v_productos_vigentes` que retorne `id`, `nombre`, `precio`, `stock` y el nombre de la categoría para productos donde tanto `producto.eliminado = FALSE` como `categoria.eliminado = FALSE`.
3. THE Sistema SHALL crear la vista `v_pedidos_resumen` que retorne `id`, nombre completo del usuario, `fecha`, `estado`, `forma_pago` y `total` para pedidos donde `eliminado = FALSE`.
4. THE Sistema SHALL crear la vista `v_pedido_detalle` que retorne `pedido_id`, nombre del producto, `cantidad`, `precio_unitario` y `subtotal` para detalles donde `eliminado = FALSE`.
5. WHEN se consulta cualquiera de las vistas, THE Sistema SHALL retornar únicamente registros activos (`eliminado = FALSE`).

---

### Requisito 11: Automatización del Subtotal y Total mediante Triggers

**Historia de usuario:** Como sistema, quiero que el subtotal de cada línea de pedido y el total del pedido se calculen y actualicen automáticamente, para eliminar errores de cálculo manual.

#### Criterios de Aceptación

1. THE Sistema SHALL crear la función `fn_set_subtotal()` que, antes de cada `INSERT` o `UPDATE` en `detalle_pedido`, calcule `subtotal = cantidad * precio_unitario`.
2. WHEN `precio_unitario` no es proporcionado en un `INSERT` sobre `detalle_pedido`, THE Sistema SHALL obtener el precio vigente del `producto` correspondiente y asignarlo a `precio_unitario` antes de persistir la fila.
3. THE Sistema SHALL crear la función `fn_recalcular_total()` que, después de cada `INSERT` o `UPDATE` en `detalle_pedido`, actualice el campo `total` del `pedido` correspondiente sumando todos los subtotales activos.
4. THE Sistema SHALL crear el trigger `trg_subtotal` como `BEFORE INSERT OR UPDATE` sobre `detalle_pedido` que ejecute `fn_set_subtotal()` para cada fila.
5. THE Sistema SHALL crear los triggers `trg_total_ins` y `trg_total_upd` como `AFTER INSERT` y `AFTER UPDATE` sobre `detalle_pedido`, respectivamente, que ejecuten `fn_recalcular_total()` por sentencia.
6. WHEN se inserta un nuevo `detalle_pedido` para un pedido existente, THE Sistema SHALL reflejar el nuevo total en la columna `total` del `pedido` correspondiente dentro de la misma transacción.

---

### Requisito 12: Procedimiento Almacenado de Creación de Pedido

**Historia de usuario:** Como desarrollador, quiero un procedimiento almacenado que encapsule la creación de un pedido con sus detalles de forma transaccional, para garantizar que el stock se descuente correctamente y no se produzcan sobreventas concurrentes.

#### Criterios de Aceptación

1. THE Sistema SHALL crear el procedimiento `sp_crear_pedido` que reciba `p_usuario_id BIGINT`, `p_forma_pago forma_pago` y `p_items JSONB` como parámetros.
2. WHEN `sp_crear_pedido` es invocado con un `p_usuario_id` que no existe o tiene `eliminado = TRUE`, THE Sistema SHALL lanzar una excepción con el mensaje `'Usuario % inexistente o eliminado'`.
3. WHEN `sp_crear_pedido` es invocado con un `producto_id` en `p_items` que no existe, tiene `eliminado = TRUE` o `disponible = FALSE`, THE Sistema SHALL lanzar una excepción descriptiva y revertir toda la transacción.
4. WHEN `sp_crear_pedido` es invocado y el `stock` de un producto es menor a la `cantidad` solicitada, THE Sistema SHALL lanzar una excepción indicando el déficit de stock y revertir toda la transacción.
5. WHEN `sp_crear_pedido` finaliza exitosamente, THE Sistema SHALL haber descontado el stock de cada producto en la cantidad indicada dentro de la misma transacción.
6. THE Sistema SHALL utilizar `SELECT ... FOR UPDATE` sobre la fila de `producto` durante la ejecución de `sp_crear_pedido` para prevenir condiciones de carrera en escenarios de concurrencia.
7. IF cualquier inserción o validación dentro de `sp_crear_pedido` falla, THEN THE Sistema SHALL revertir automáticamente todas las operaciones realizadas en esa invocación.
