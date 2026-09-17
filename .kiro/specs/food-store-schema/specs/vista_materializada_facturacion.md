# spec: vista_materializada_facturacion
Objetivo: Precalcular y almacenar la facturación agregada por categoría y mes para acelerar reportes analíticos costosos.

Consulta original afectada:
  SELECT 
      c.nombre AS categoria,
      DATE_TRUNC('month', p.fecha)::date AS mes,
      SUM(dp.subtotal) AS total_facturado,
      COUNT(DISTINCT p.id) AS cantidad_pedidos
  FROM detalle_pedido dp
  JOIN pedido p ON dp.pedido_id = p.id
  JOIN producto prod ON dp.producto_id = prod.id
  JOIN categoria c ON prod.categoria_id = c.id
  WHERE dp.eliminado = FALSE 
    AND p.eliminado = FALSE 
    AND prod.eliminado = FALSE 
    AND c.eliminado = FALSE
  GROUP BY c.nombre, DATE_TRUNC('month', p.fecha)::date;

Requisitos de la Vista Materializada:
  - Nombre: mv_facturacion_categoria_mes
  - Crear con la cláusula: WITH DATA
  - Crear un índice único: UNIQUE INDEX sobre (categoria, mes) para habilitar REFRESH MATERIALIZED VIEW CONCURRENTLY a futuro.

Criterio de aceptación: 
  - La vista materializada y su índice único deben crearse correctamente en la base de datos.
  - La consulta a la vista materializada debe reducir significativamente el tiempo de ejecución con respecto a la consulta analítica original.