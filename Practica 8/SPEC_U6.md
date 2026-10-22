# Especificación y Plan de Mantenimiento - Base de Datos Food Store

## 1. Reglas de Seguridad y Condiciones de Trabajo
Para garantizar la integridad de los datos durante el mantenimiento y las pruebas, se establecen las siguientes directivas:
* **Protección de Producción:** La base principal `foodstore` no se eliminará ni se reemplazará durante ningún simulacro o prueba.
* **Entornos Descartables:** Las pruebas de restauración y cualquier acción potencialmente destructiva se ejecutarán únicamente sobre bases de datos descartables, específicamente en `foodstore_restore_test`.
* **Gestión de Credenciales:** Las contraseñas no se escribirán bajo ninguna circunstancia en los scripts de automatización ni se entregarán en el repositorio.
* **Compatibilidad:** Todo el procedimiento debe ejecutarse sobre el motor PostgreSQL 16 o superior.
* **Formato de Respaldo:** Los respaldos se realizarán exclusivamente en formato *custom* para permitir el uso de `pg_restore`.

## 2. Plan de Mantenimiento y Automatización
El siguiente cronograma define las tareas que se automatizarán, su frecuencia de ejecución y el criterio técnico que confirma el éxito de cada operación.

| Tarea a automatizar | Frecuencia propuesta | Evidencia de finalización correcta |
| :--- | :--- | :--- |
| **Respaldo de foodstore** | Diaria | Generación de un `Archivo.dump` válido que incluya fecha y hora en su nombre, junto con su respectivo archivo de log. |
| **Chequeo de salud** | Diaria | Ejecución exitosa y salida de resultados del script `health_check.sql`. |
| **Revisión de mantenimiento** | Semanal | Reporte del estado de las tuplas muertas, autovacuum y estadísticas de las tablas a través de `maintenance.sql`. |
| **Restauración de prueba** | Semanal | Base de datos `foodstore_restore_test` restaurada y con las validaciones lógicas y de integridad ejecutadas correctamente. |

## 3. Revisión de Código y Asistencia (OpenCode)
* Esta especificación actuará como base para generar la primera versión de los scripts utilizando OpenCode. 
* Cualquier código, comando o script autogenerado quedará estrictamente subordinado a revisión y prueba humana antes de ser considerado apto e integrado al procedimiento final.

## 4. Objetivos de Recuperación del Laboratorio
* **RPO previsto: ≤ 24 h.** Con un respaldo diario, en el peor caso se pierde lo registrado desde el último `.dump`.
* **RTO previsto: ≤ 10 min.** Se mide desde la creación de `foodstore_restore_test` hasta que las validaciones terminan correctamente.
* **Restauración válida:** las filas por tabla coinciden con las registradas antes del respaldo (`backups/*.conteo.txt`, generado por `backup_foodstore.ps1`) y los controles de productos y detalles inválidos de `validacion_restore.sql` devuelven 0.
* **Automatización:** `backup_foodstore.ps1` y `restore_test.ps1` terminan con código 1 ante cualquier falla, para que el programador de tareas pueda detectarla. La contraseña se toma de `PGPASSWORD` o de `pgpass.conf`.
* **Nombre de la base:** en el entorno del equipo la base principal se llama `food_store` (el enunciado la nombra `foodstore`). `backup_foodstore.ps1` permite cambiarla con `-Base`.