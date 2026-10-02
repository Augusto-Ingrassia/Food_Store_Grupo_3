# Práctica 7 — Diseño y Justificación: Modelo IAM de Food Store

## 1. Principio rector

Todo el modelo se construye sobre el **principio de mínimo privilegio**: un rol
recibe exactamente los permisos que necesita para cumplir su función y ninguno
adicional. La separación entre roles de grupo (sin `LOGIN`) y roles de login
permite reasignar responsabilidades sin tocar los permisos individuales.

---

## 2. Roles de Grupo

### 2.1 `rol_app_lectura`

**Permisos otorgados**

| Objeto | Privilegio |
|---|---|
| `categoria` | `SELECT` |
| `producto` | `SELECT` |
| `v_categorias_vigentes` | `SELECT` |
| `v_productos_vigentes` | `SELECT` |
| `v_productos_categoria` | `SELECT` |

**Justificación**  
Los clientes que navegan la tienda necesitan ver el catálogo de alimentos
(productos y sus categorías) sin poder alterarlo bajo ninguna circunstancia.
Restringir el acceso a `usuario`, `pedido` y `detalle_pedido` impide que una
vulnerabilidad en la capa de lectura exponga datos transaccionales o personales.

**Objetos explícitamente excluidos**: `usuario`, `pedido`, `detalle_pedido`,
`v_pedidos_resumen`, `v_pedido_detalle`, `mv_facturacion_categoria_mes`.

---

### 2.2 `rol_app_escritura`

**Permisos otorgados**

| Objeto | Privilegio |
|---|---|
| `pedido` | `INSERT`, `UPDATE` |
| `detalle_pedido` | `INSERT`, `UPDATE` |
| `pedido_id_seq` | `USAGE` (para identity columns) |
| `detalle_pedido_id_seq` | `USAGE` |
| `sp_crear_pedido` | `EXECUTE` |

**Justificación**  
El backend de la tienda debe poder registrar las compras de los clientes usando
`sp_crear_pedido`, que es el único punto de entrada transaccional validado. No se
otorga `DELETE` en ninguna tabla porque el proyecto implementa soft-delete
(`eliminado = FALSE`); borrar físicamente filas es innecesario y riesgoso. No se
otorga acceso a `producto.precio` para escritura, preservando la integridad del
catálogo de precios.

**Objetos explícitamente excluidos**: `DELETE` en cualquier tabla, `UPDATE` sobre
`producto`, `usuario`.

---

### 2.3 `rol_soporte`

**Permisos otorgados**

| Objeto | Privilegio |
|---|---|
| `v_pedidos_usuario_segura` | `SELECT` |
| `pedido` | `SELECT` |
| `pedido.estado` (columna) | `UPDATE` |

**Justificación**  
El equipo de atención al cliente necesita gestionar reclamos operativos: consultar
el estado de un pedido e identificar al usuario que lo realizó. La vista
`v_pedidos_usuario_segura` expone `nombre` y `mail` del usuario pero excluye
explícitamente `contrasena`, garantizando que el soporte nunca vea credenciales.
El `UPDATE` se limita a la columna `estado` de `pedido` porque el soporte solo
necesita avanzar el ciclo de vida del envío, no modificar montos ni datos
personales.

**Decisión de diseño sobre `contrasena`**: en lugar de un `GRANT SELECT` sobre
toda la tabla `usuario`, se canaliza el acceso a través de `v_pedidos_usuario_segura`,
que proyecta solo las columnas seguras. Esto es más robusto que un `REVOKE` sobre
columnas individuales, ya que una futura adición de columnas sensibles quedaría
automáticamente fuera del alcance de la vista.

**Objetos explícitamente excluidos**: `usuario` (tabla base), `detalle_pedido`,
`mv_facturacion_categoria_mes`, `DELETE` en cualquier tabla.

---

### 2.4 `rol_reportes`

**Permisos otorgados**

| Objeto | Privilegio |
|---|---|
| `categoria` | `SELECT` |
| `producto` | `SELECT` |
| `usuario` | `SELECT` |
| `pedido` | `SELECT` |
| `detalle_pedido` | `SELECT` |
| `v_pedidos_resumen` | `SELECT` |
| `v_pedido_detalle` | `SELECT` |
| `v_productos_vigentes` | `SELECT` |
| `v_categorias_vigentes` | `SELECT` |
| `v_productos_categoria` | `SELECT` |
| `v_pedidos_usuario_segura` | `SELECT` |
| `v_detalle_pedido_producto` | `SELECT` |
| `mv_facturacion_categoria_mes` | `SELECT` |

**Justificación**  
Las herramientas de inteligencia de negocios (BI) necesitan procesar métricas
masivas (facturación por categoría y mes, volumen de pedidos, etc.) sin riesgo de
bloquear ni sobreescribir los datos transaccionales. Otorgar solo `SELECT` sobre
todo el esquema operativo satisface este requisito. El acceso a `mv_facturacion_categoria_mes`
permite que las consultas analíticas más costosas se resuelvan sobre la vista
materializada en lugar de recalcular sobre las tablas base, reduciendo la carga.

**Nota sobre `usuario.contrasena`**: aunque se concede `SELECT` sobre la tabla
`usuario`, las herramientas de BI deben acceder únicamente a través de las vistas
que excluyen esa columna. En un entorno productivo se reforzaría esta restricción
con Row Level Security o proyectando explícitamente las columnas en la vista.

**Objetos explícitamente excluidos**: todo permiso de escritura (`INSERT`,
`UPDATE`, `DELETE`) en cualquier tabla.

---

## 3. Roles de Login

### 3.1 `app_web`

**Atributos**: `LOGIN`, sin `SUPERUSER`, sin `CREATEDB`, sin `CREATEROLE`.

**Membresías**: `rol_app_lectura`, `rol_app_escritura`.

**Justificación**  
Es el usuario técnico que utiliza la API de la aplicación para interactuar con la
base en nombre de los clientes. La combinación de lectura y escritura le permite
mostrar el catálogo y registrar pedidos. La ausencia de privilegios administrativos
limita el daño en caso de compromiso de credenciales.

---

### 3.2 `admin_datos`

**Atributos**: `LOGIN`, `CREATEDB`, `CREATEROLE`, sin `SUPERUSER`.

**Membresías**: ninguna (opera directamente).

**Justificación**  
Es la credencial reservada para el DBA que debe aplicar parches de esquema,
crear nuevos usuarios y gestionar políticas. Se evita `SUPERUSER` para conservar
una capa de auditoría: incluso el DBA queda sujeto a los controles del motor.
Sus credenciales no deben compartirse con la aplicación ni almacenarse en el
código fuente.

---

## 4. Rol Adicional — Aporte del Equipo

### 4.1 `rol_auditor_seguridad`

**Permisos otorgados**

| Objeto | Privilegio |
|---|---|
| `v_auditoria_accesos` (futura) | `SELECT` |

**Justificación**  
El equipo de seguridad informática requiere investigar incidentes sin tener acceso
a los datos de negocio ni permisos para borrar la evidencia. En la base de datos
actual no existe un esquema de logs dedicado; el rol se define anticipando su
creación futura (tabla `auditoria` o vistas sobre `pg_stat_activity`,
`pg_stat_user_tables`, etc.). Al momento de implementarse, se otorgará `SELECT`
exclusivamente sobre los objetos de auditoría, manteniendo el aislamiento total
respecto a `producto`, `usuario`, `pedido` y demás tablas de negocio.

**Objetos explícitamente excluidos**: todas las tablas y vistas de negocio,
`DELETE` sobre cualquier objeto de auditoría.

---

## 5. Diagrama de herencia de roles

```
                        ┌─────────────┐
                        │  admin_datos │  (LOGIN, CREATEDB, CREATEROLE)
                        └─────────────┘

      ┌──────────────────┐        ┌──────────────────┐
      │   rol_app_lectura │        │ rol_app_escritura │
      └────────┬─────────┘        └────────┬──────────┘
               │                           │
               └──────────┬────────────────┘
                           │
                     ┌─────▼─────┐
                     │  app_web  │  (LOGIN)
                     └───────────┘

      ┌──────────────┐    ┌──────────────┐    ┌────────────────────┐
      │  rol_soporte │    │ rol_reportes │    │rol_auditor_seguridad│
      └──────────────┘    └──────────────┘    └────────────────────┘
         (sin LOGIN)          (sin LOGIN)            (sin LOGIN)
```

---

## 6. Matriz de permisos resumida

| Tabla / Vista | rol_app_lectura | rol_app_escritura | rol_soporte | rol_reportes | rol_auditor_seguridad |
|---|:---:|:---:|:---:|:---:|:---:|
| `categoria` | SELECT | — | — | SELECT | — |
| `producto` | SELECT | — | — | SELECT | — |
| `usuario` | — | — | — | SELECT | — |
| `pedido` | — | INSERT, UPDATE | SELECT | SELECT | — |
| `pedido.estado` | — | — | UPDATE | — | — |
| `detalle_pedido` | — | INSERT, UPDATE | — | SELECT | — |
| `sp_crear_pedido` | — | EXECUTE | — | — | — |
| Vistas catálogo | SELECT | — | — | SELECT | — |
| `v_pedidos_usuario_segura` | — | — | SELECT | SELECT | — |
| `v_pedidos_resumen` | — | — | — | SELECT | — |
| `mv_facturacion_categoria_mes` | — | — | — | SELECT | — |
| Objetos de auditoría | — | — | — | — | SELECT |

---

## 7. Consideraciones de seguridad adicionales

- **Contraseñas**: definidas en el script como valores de ejemplo. En producción
  deben rotarse y gestionarse con un vault (ej. HashiCorp Vault, AWS Secrets Manager).
- **`REVOKE` inicial**: el script revoca todos los permisos por defecto del rol
  `PUBLIC` sobre el esquema `public` antes de otorgar los permisos específicos,
  evitando que cualquier usuario conectado herede acceso implícito.
- **Secuencias de identity columns**: `app_web` necesita `USAGE` sobre las
  secuencias de `pedido` y `detalle_pedido` para que los `INSERT` con `GENERATED ALWAYS AS IDENTITY` funcionen correctamente.
- **Futuro esquema de auditoría**: se recomienda crear un esquema separado
  (`audit`) para los objetos de logs, de modo que `rol_auditor_seguridad` reciba
  `USAGE` sobre ese esquema exclusivamente, sin ningún acceso al esquema `public`.
