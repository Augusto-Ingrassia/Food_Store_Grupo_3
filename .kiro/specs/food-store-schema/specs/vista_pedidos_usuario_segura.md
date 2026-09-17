# spec: vista_pedidos_usuario_segura
Objetivo: Ocultar credenciales sensibles de los usuarios en los reportes de pedidos por motivos de seguridad.
Columnas a exponer:
  - p.id AS pedido_id
  - p.fecha
  - p.estado
  - p.total
  - u.id AS usuario_id
  - u.nombre AS usuario_nombre
  - u.email
Columna a ocultar: u.contrasena (por seguridad)
Filtro de vigencia: p.eliminado = FALSE AND u.eliminado = FALSE
Criterio de aceptación: Debe permitir hacer SELECT sobre los datos del usuario omitiendo la columna contraseña.