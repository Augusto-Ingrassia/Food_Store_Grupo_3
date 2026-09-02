Herramienta: OpenCode.  

Para qué se usó: Generar script de carga masiva de 50.000 productos, 20.000 usuarios y 200.000 pedidos.  

Prompt/spec: Actúa como un experto en PostgreSQL. Necesito un script SQL para generar datos de prueba masivos que cumpla exactamente con la estructura de mi base de datos.

Usá generate_series y evitá usar PL/pgSQL si no es estrictamente necesario. No modifiques la estructura de ninguna tabla.


Necesito que el script realice las siguientes inserciones en este orden:


Usuarios: Insertá 20.000 filas en la tabla usuario. Asegurate de que el campo mail sea verdaderamente único (podés concatenar el número de la serie al string del correo).


Productos: Insertá 50.000 filas en la tabla producto. El precio debe ser aleatorio entre 500 y 5000, y el stock debe ser aleatorio entre 0 y 200. Distribuí el categoria_id de forma pareja o aleatoria usando los IDs de categorías que ya existen (asumí que las categorías van del ID 1 al 10).


Pedidos: Insertá 200.000 filas en la tabla pedido. Asignales un usuario_id aleatorio (del 1 al 20000) y una forma_pago aleatoria usando el ENUM correspondiente.


Detalle de Pedido: Insertá al menos un detalle para cada uno de los 200.000 pedidos.
CRÍTICO: La tabla detalle_pedido tiene una restricción UNIQUE (pedido_id, producto_id). Asegurate de que la lógica de generación aleatoria no intente insertar el mismo producto dos veces para un mismo pedido. Además, respetá que el subtotal sea igual a cantidad * precio_unitario.  

Se aceptó / se descartó por qué: Se aceptó porque cumplió con las restricciones lógicas de la base (UNIQUE y FK), generó los rangos numéricos correctamente sin usar PL/pgSQL y se ejecutó exitosamente bajo el protocolo de seguridad en una transacción.