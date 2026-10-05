-- Operación 1: Lectura de prueba
SELECT id, nombre, precio FROM producto LIMIT 5;

-- Operación 2: Inserción
INSERT INTO categoria (nombre, descripcion) 
VALUES ('Postres', 'Línea de postres fríos para Food Store');

-- Operación 3: Actualización
UPDATE producto 
SET precio = precio * 1.05 
WHERE id = 10;

-- Operación 4: Intento de inicio de sesión fallido
-- (Simulando el uso de la función vista en la Clase 2)
SELECT fn_autenticar('admin_falso', 'clave_incorrecta_123');