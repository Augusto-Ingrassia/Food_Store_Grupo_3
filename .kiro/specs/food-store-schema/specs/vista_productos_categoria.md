# spec: vista_productos_categoria
Objetivo: Simplificar el acceso a los productos vigentes junto con la información de su categoría.
Columnas a exponer:
  - p.id AS producto_id
  - p.nombre AS producto_nombre
  - p.precio_unitario
  - c.nombre AS categoria_nombre
Filtro de vigencia: p.eliminado = FALSE AND c.eliminado = FALSE
Criterio de aceptación: La vista no debe exponer productos o categorías marcados como eliminados.