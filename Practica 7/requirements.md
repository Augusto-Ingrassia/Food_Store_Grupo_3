# Práctica 7 — Requerimientos: Modelo de Identidades y Accesos (IAM)

## Objetivo General

Definir el modelo de identidades y accesos para la base de datos de Food Store
aplicando estrictamente el **principio de mínimo privilegio**: cada rol o usuario
recibe únicamente los permisos indispensables para cumplir su función, y ninguno más.

---

## Roles Requeridos

### Roles de Grupo (sin capacidad de login)

| Rol | Propósito |
|---|---|
| `rol_app_lectura` | Lectura de tablas públicas (catálogo) |
| `rol_app_escritura` | Escritura transaccional (pedidos, detalles) |
| `rol_soporte` | Gestión operativa de pedidos y usuarios |
| `rol_reportes` | Lectura analítica de todo el esquema operativo |

### Roles de Login (usuarios del sistema)

| Usuario | Hereda | Propósito |
|---|---|---|
| `app_web` | `rol_app_lectura`, `rol_app_escritura` | Usuario técnico de la API web |
| `admin_datos` | — (DBA directo) | Administrador de estructura y políticas |

### Roles Adicionales (aporte del equipo)

| Rol | Propósito |
|---|---|
| `rol_auditor_seguridad` | Lectura de logs e historial de eventos para investigación de incidentes |

---

## Requerimientos Funcionales

### RF-01 — rol_app_lectura
- Debe poder ejecutar `SELECT` sobre las tablas `producto` y `categoria`.
- Debe poder ejecutar `SELECT` sobre las vistas públicas del catálogo:
  `v_productos_vigentes`, `v_categorias_vigentes`, `v_productos_categoria`.
- No debe tener acceso a `usuario`, `pedido` ni `detalle_pedido`.

### RF-02 — rol_app_escritura
- Debe poder ejecutar `INSERT` y `UPDATE` sobre `pedido` y `detalle_pedido`.
- Debe poder ejecutar el procedimiento almacenado `sp_crear_pedido`.
- No debe poder ejecutar `DELETE` en ninguna tabla.
- No debe poder modificar precios en `producto`.

### RF-03 — rol_soporte
- Debe poder ejecutar `SELECT` sobre `usuario` y `pedido` (sin ver `contrasena`).
- Debe poder ejecutar `UPDATE` en la columna `estado` de `pedido` únicamente.
- No debe tener acceso a `detalle_pedido` ni a datos de facturación.

### RF-04 — rol_reportes
- Debe poder ejecutar `SELECT` sobre todas las tablas del esquema operativo.
- Debe poder consultar la vista materializada `mv_facturacion_categoria_mes`.
- No debe tener permisos de escritura en ninguna tabla.

### RF-05 — app_web
- Debe poder conectarse a la base de datos.
- Hereda `rol_app_lectura` y `rol_app_escritura`.
- No debe tener permisos de superusuario ni de creación de objetos.

### RF-06 — admin_datos
- Debe poder conectarse a la base de datos.
- Debe tener capacidad de crear y modificar objetos (`CREATEDB`, `CREATEROLE`).
- No debe compartirse su contraseña con usuarios de la aplicación.

### RF-07 — rol_auditor_seguridad
- Debe poder ejecutar `SELECT` sobre tablas o vistas de auditoría/logs.
- No debe tener acceso a tablas de negocio (`pedido`, `producto`, `usuario`, etc.).
- No debe poder borrar registros de auditoría bajo ninguna circunstancia.

---

## Requerimientos No Funcionales

- **RNF-01**: Todas las contraseñas deben definirse con `PASSWORD` en el script;
  en producción se reemplazarán por secretos gestionados externamente.
- **RNF-02**: Ningún rol de grupo debe tener atributo `LOGIN`.
- **RNF-03**: El script debe ser idempotente: usar `IF NOT EXISTS` o `DROP … IF EXISTS`
  antes de cada `CREATE`.
- **RNF-04**: Los permisos se otorgan sobre el esquema `public` por ser el único
  esquema operativo existente en la base de datos.
