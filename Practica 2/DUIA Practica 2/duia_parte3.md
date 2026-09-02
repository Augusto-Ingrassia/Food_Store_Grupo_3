Herramienta: Kiro (modelo Auto)

SCRIPT 1
Prompt: Analizar un UPDATE sin cláusula WHERE que afecta toda la tabla, explicar el problema y generar una versión corregida que filtre solo las funciones cuya película tiene estado 'retirada'.

Qué generó la IA: Explicación del error (ausencia de WHERE produce una actualización masiva e irreversible sobre todas las filas) y versión corregida con WHERE pelicula_id IN (SELECT id FROM pelicula WHERE estado = 'retirada').

Qué se aceptó/modificó: Se aceptó la explicación y la versión corregida sin modificaciones.

Verificación: Se leyó el código generado para confirmar que la explicación sobre la falta del WHERE fuera precisa y que la consulta corregida restringiera correctamente el alcance del UPDATE.

SCRIPT 2
Prompt: Analizar un DELETE con NOT IN sobre una subconsulta que puede devolver NULLs, explicar por qué no borra nada en ese caso y generar una versión corregida usando NOT EXISTS.

Qué generó la IA: Explicación del comportamiento de NOT IN con NULLs (cualquier comparación con NULL produce UNKNOWN, haciendo que la condición nunca sea verdadera y el DELETE no elimine ninguna fila) y versión corregida con NOT EXISTS (SELECT 1 FROM producto p WHERE p.categoria_id = c.id).

Qué se aceptó/modificó: Se aceptó la explicación y la versión corregida sin modificaciones.

Verificación: Se leyó el código generado para confirmar que la explicación del comportamiento de NULL con NOT IN fuera técnicamente correcta y que la versión con NOT EXISTS resolviera el problema de forma segura.
