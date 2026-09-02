-- HU-CAT-01: Listar categorías vigentes
SELECT id, nombre, descripcion
FROM   categoria
WHERE  eliminado = FALSE
ORDER  BY id;

-- HU-CAT-02: Crear categoría
INSERT INTO categoria(nombre, descripcion)
VALUES ('Empanadas', 'Variedad de empanadas')
RETURNING id;

-- HU-CAT-03: Editar categoría
UPDATE categoria
SET    nombre = 'Pizzas y Empanadas', descripcion = 'Catálogo ampliado'
WHERE  id = 1 AND eliminado = FALSE;

-- HU-CAT-04: Eliminar categoría (baja lógica)
UPDATE categoria
SET    eliminado = TRUE
WHERE  id = 2 AND eliminado = FALSE;

-- HU-PROD-01: Listar productos
SELECT p.id, p.nombre, p.precio, p.stock, c.nombre AS categoria
FROM   producto p
JOIN   categoria c ON c.id = p.categoria_id
WHERE  p.eliminado = FALSE
ORDER  BY p.id;

-- HU-PROD-02: Crear producto
INSERT INTO producto(nombre, descripcion, precio, stock, imagen, disponible, categoria_id)
SELECT 'Fugazzeta', 'Pizza de cebolla', 1800.00, 10, NULL, TRUE, c.id
FROM   categoria c
WHERE  c.id = 1 AND c.eliminado = FALSE
RETURNING id;

-- HU-PROD-03: Editar producto
UPDATE producto
SET    precio = COALESCE(2000.00, precio),
       stock  = COALESCE(NULL,    stock)
WHERE  id = 1 AND eliminado = FALSE;

-- HU-PROD-04: Eliminar producto (baja lógica)
UPDATE producto
SET    eliminado = TRUE
WHERE  id = 1 AND eliminado = FALSE;

-- HU-USR-01: Listar usuarios
SELECT id, nombre, apellido, mail, rol
FROM   usuario
WHERE  eliminado = FALSE
ORDER  BY id;

-- HU-USR-02: Crear usuario
INSERT INTO usuario(nombre, apellido, mail, celular, contrasena)
VALUES ('Juan', 'Pérez', 'juan2@x.com', '2611234567', 'hash')
RETURNING id;

-- HU-USR-03: Editar usuario
UPDATE usuario
SET    celular = '2617654321'
WHERE  id = 1 AND eliminado = FALSE;

-- HU-USR-04: Eliminar usuario (baja lógica)
UPDATE usuario
SET    eliminado = TRUE
WHERE  id = 1 AND eliminado = FALSE;

-- HU-PED-01: Listar pedidos
SELECT id, usuario, fecha, estado, forma_pago, total
FROM   v_pedidos_resumen
ORDER  BY id;

-- HU-PED-03: Actualizar estado / forma de pago
UPDATE pedido
SET    estado = 'CONFIRMADO', forma_pago = 'TARJETA'
WHERE  id = 1 AND eliminado = FALSE;

-- HU-PED-04: Eliminar pedido (baja lógica)
BEGIN;
  UPDATE detalle_pedido SET eliminado = TRUE WHERE pedido_id = 1;
  UPDATE pedido         SET eliminado = TRUE WHERE id = 1;
COMMIT;


-- A) Top 5 productos más vendidos (por cantidad)
SELECT pr.id, pr.nombre, SUM(dp.cantidad) AS unidades
FROM   detalle_pedido dp
JOIN   producto pr ON pr.id = dp.producto_id
WHERE  dp.eliminado = FALSE
GROUP  BY pr.id, pr.nombre
ORDER  BY unidades DESC
LIMIT  5;
 
-- B) Facturación por categoría y por mes
SELECT c.nombre AS categoria,
       date_trunc('month', ped.fecha) AS mes,
       SUM(dp.subtotal) AS facturado
FROM   detalle_pedido dp
JOIN   pedido   ped ON ped.id = dp.pedido_id AND ped.eliminado = FALSE
JOIN   producto pr  ON pr.id  = dp.producto_id
JOIN   categoria c  ON c.id   = pr.categoria_id
WHERE  dp.eliminado = FALSE
GROUP  BY c.nombre, date_trunc('month', ped.fecha)
ORDER  BY mes, facturado DESC;
 
-- C) Ranking de usuarios por gasto acumulado (función de ventana)
SELECT u.id, u.nombre || ' ' || u.apellido AS usuario,
       SUM(ped.total) AS gasto,
       RANK() OVER (ORDER BY SUM(ped.total) DESC) AS puesto
FROM   pedido ped
JOIN   usuario u ON u.id = ped.usuario_id
WHERE  ped.eliminado = FALSE
GROUP  BY u.id, u.nombre, u.apellido
ORDER  BY puesto;
 
-- D) Pedidos cuyo total supera el promedio general (subconsulta)
SELECT id, total
FROM   pedido
WHERE  eliminado = FALSE
  AND  total > (SELECT AVG(total) FROM pedido WHERE eliminado = FALSE)
ORDER  BY total DESC;
 
-- E) Productos sin ventas (LEFT JOIN + IS NULL)
SELECT pr.id, pr.nombre
FROM   producto pr
LEFT   JOIN detalle_pedido dp
       ON dp.producto_id = pr.id AND dp.eliminado = FALSE
WHERE  pr.eliminado = FALSE
  AND  dp.id IS NULL
ORDER  BY pr.id;