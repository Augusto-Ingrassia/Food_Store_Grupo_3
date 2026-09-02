-- 1. Insertar Categorías
INSERT INTO categoria (nombre, descripcion) VALUES
('Pizzas y Empanadas', 'Catálogo ampliado'),
('Bebidas', 'Gaseosas, cervezas y aguas'),
('Postres', 'Helados y tortas');

-- 2. Insertar Productos
-- Nota: categoria_id 1 corresponde a "Pizzas y Empanadas", 2 a "Bebidas"
INSERT INTO producto (nombre, descripcion, precio, stock, imagen, disponible, categoria_id) VALUES
('Fugazzeta', 'Pizza de cebolla y queso', 1800.00, 10, NULL, TRUE, 1),
('Muzzarella', 'Clásica de muzzarella', 1500.00, 15, NULL, TRUE, 1),
('Empanada de Carne', 'Frita o al horno', 400.00, 30, NULL, TRUE, 1),
('Coca Cola 1.5L', 'Línea clásica', 800.00, 20, NULL, TRUE, 2);

-- 3. Insertar Usuarios
INSERT INTO usuario (nombre, apellido, mail, celular, contrasena, rol) VALUES
('Juan', 'Pérez', 'juan@x.com', '2611234567', 'hash123', 'USUARIO'),
('Ana', 'Garis', 'ana.garis@mail.com', '2619876543', 'hash456', 'USUARIO'),
('Admin', 'Principal', 'admin@foodstore.com', '111111111', 'adminpass', 'ADMIN');

-- 4. Insertar Pedidos y Detalles usando el Procedimiento Almacenado
-- Esto no solo carga datos, sino que te sirve para probar que la lógica del procedimiento sp_crear_pedido y los triggers funcionan correctamente.

-- Pedido 1: Juan Pérez (id 1) compra 2 Fugazzetas y 1 Coca Cola pagando en EFECTIVO
CALL sp_crear_pedido(
     1, 
     'EFECTIVO',
     '[{"producto_id":1,"cantidad":2}, {"producto_id":4,"cantidad":1}]'::jsonb
);

-- Pedido 2: Ana Garis (id 2) compra 1 Muzzarella y 6 Empanadas pagando con TARJETA
CALL sp_crear_pedido(
     2, 
     'TARJETA',
     '[{"producto_id":2,"cantidad":1}, {"producto_id":3,"cantidad":6}]'::jsonb
);

SELECT * FROM v_pedidos_resumen;