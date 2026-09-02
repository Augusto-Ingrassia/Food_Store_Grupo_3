Herramienta: opencode (Gemini 3.6 flash)

ESCENARIO 1
prompt:por qué si ejecuto SELECT precio FROM producto WHERE id = 1 dentro de una transacción en READ COMMITTED, el valor cambia si otra sesión hace un UPDATE y COMMIT en medio

Que genero: Explicación del comportamiento de READ COMMITTED y la indicación de utilizar SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;

Que se acepto: se acepto la explicacion sin modificaciones 

Verificacion: Se ejecutó la secuencia en DBeaver configurando REPEATABLE READ en la Sesión A, comprobando que el precio se mantuvo,tras el COMMIT de la Sesión B.

ESCENARIO 2

prompt: en tabla pedido. Ejecuté SELECT COUNT(*) FROM pedido WHERE total >= 5000; en la Sesión A. Luego la Sesión B hizo un INSERT de un pedido y tiró COMMIT. Al reejecutar el COUNT en Sesión A, el valor aumentó, porque?

Que genero: Identificación de la anomalía como "Lectura Fantasma" (Phantom Read) y la recomendación de elevar el nivel de aislamiento a REPEATABLE READ o SERIALIZABLE

Que se acepto: se acepto la identificacion sin modificaciones 

Verificacion: Se repitió la prueba en DBeaver con BEGIN ISOLATION LEVEL REPEATABLE READ; en Sesión A; el resultado del COUNT(*) no cambió tras el INSERT de la Sesión B.

ESCENARIO 3

Prompt: Si ejecuto un UPDATE producto SET stock = stock - 1 WHERE id = 1; en dos sesiones concurrentes al mismo tiempo dentro de transacciones abiertas, la segunda sesión se queda colgada. porque pasa esto?

que genero: Explicación sobre la exclusión mutua generada por el bloqueo exclusivo de fila (RowExclusiveLock) y la consulta a pg_locks para auditar bloqueos en espera.

Que se acepto: se acepto la explicacion sin modificaciones 

Se ejecutó la consulta sobre pg_locks en una tercera pestaña de DBeaver, verificando que la solicitud de la Sesión B figuraba con granted = false hasta el COMMIT de la Sesión A.