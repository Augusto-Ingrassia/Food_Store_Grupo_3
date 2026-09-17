# spec: vista_detalle_pedido_producto
Objetivo: Exponer el detalle de cada pedido incluyendo el nombre del producto asociado.
Columnas a exponer:
  - dp.id AS detalle_id
  - dp.pedido_id
  - prod.nombre AS producto_nombre
  - dp.cantidad
  - dp.precio_unitario
  - dp.subtotal
Filtro de vigencia: dp.eliminado = FALSE AND prod.eliminado = FALSE
Criterio de aceptación: Muestra el detalle del pedido uniendo detalle_pedido y producto sin requerir un JOIN explícito en la consulta final.