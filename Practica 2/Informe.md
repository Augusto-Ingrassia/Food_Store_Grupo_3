ESCENARIO: Lectura no repetible.

REPRODUCCION:
A: BEGIN TRANSACTION ISOLATION LEVEL READ COMMITTED;

A: SELECT precio FROM producto WHERE id = 1; 

B: BEGIN; UPDATE producto SET precio = 150 WHERE id = 1; COMMIT;

A: SELECT precio FROM producto WHERE id = 1; 


QUE SE OBSERVO: De la misma consulta en la sesion A me dio distintos resultados debido a los cambios en la sesion B (Primero dio 2000 y luego 150)

EXPLICACION DE LA IA:"En el nivel READ COMMITTED, cada consulta ejecutada dentro de una transacción ve una nueva instantánea de los datos (snapshot). Para evitar esto se debe subir el nivel de aislamiento a REPEATABLE READ".

VERIFICACION: Se repitio pero poniendo el comando SET TRANSACTION ISOLATION LEVEL REPEATABLE READ; en la sesion A y esta vez el numero en la sesion A no cambio

ESCENARIO: lectura fantasma.

REPRODUCCION:
A:BEGIN ISOLATION LEVEL READ COMMITTED;

A:SELECT COUNT(*) FROM producto;

B:BEGIN;
INSERT INTO pedido (forma_pago, usuario_id, total) VALUES ('TARJETA', 1, 8000.00);
COMMIT;

A:SELECT COUNT(*) FROM producto;

QUE SE OBSERVO: La primera vez el count dio 3 y luego de añadir un pedido desde la sesion B el count dio 4

EXPLICACION DE LA IA:Ocurre cuando un SELECT de agregación o rango ve filas nuevas ("fantasmas") porque otra sesión hizo INSERT y COMMIT en medio de la transacción. En READ COMMITTED, PostgreSQL toma un snapshot nuevo en cada consulta. Se evita subiendo el aislamiento a REPEATABLE READ o SERIALIZABLE, congelando la foto de datos desde la primera lectura.

VERIFICACION: se repitio pero poniendo el comando BEGIN ISOLATION LEVEL REPEATABLE READ; y esta vez no aumento el numero en la sesion A

ESCENARIO: Espera por bloqueo

REPRODUCCION: 
A:BEGIN;

A:SELECT stock FROM producto WHERE id = 1 FOR UPDATE;

B:BEGIN;

B:SELECT stock FROM producto WHERE id = 1 FOR UPDATE;

A:COMMIT;

B:COMMIT;

QUE SE OBSERVO: Que la consulta en la sesion B se quedo trabada hasta que se realizo en commit en la sesion A

EXPLICACION DE LA IA:Ocurre por exclusión mutua cuando dos transacciones intentan modificar o bloquear la misma fila al mismo tiempo. La primera transacción adquiere un bloqueo exclusivo a nivel de fila (RowExclusiveLock), obligando a la segunda sesión a entrar en estado de espera (lock wait) hasta que la primera libere el recurso con COMMIT o ROLLBACK. 

VERIFICACION:Durante la espera de la Sesión B, se ejecutó SELECT pid, locktype, mode, granted FROM pg_locks; desde una tercera pestaña. Se constató que el bloqueo solicitado por la Sesión B figuraba como granted = false, pasando inmediatamente a granted = true al ejecutar COMMIT en la Sesión A.

