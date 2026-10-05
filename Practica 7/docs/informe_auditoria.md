# Informe de Auditoría - Parte B

## 1. Configuración de parámetros de auditoría
Para activar la auditoría nativa en PostgreSQL y cumplir con los requisitos, se modificó el archivo `postgresql.conf` ajustando los siguientes parámetros:
*   `log_connections = on`: Para registrar cada vez que un usuario inicia una sesión.
*   `log_disconnections = on`: Para registrar el fin de la sesión y calcular el tiempo que estuvo conectado.
*   `log_statement = 'mod'`: Se configuró en 'mod' para que registre todas las sentencias de modificación de datos (INSERT, UPDATE, DELETE, TRUNCATE) además de las sentencias DDL. También se registran las funciones ejecutadas si modifican el estado.

## 2. Análisis del fragmento de log (Punto 3)
Observando el archivo `log_auditoria_prueba.txt`, la auditoría nativa nos brinda la siguiente información útil:
*   **Cuándo:** El timestamp exacto de cada evento (`2026-10-04 20:45:21 -03`).
*   **Quién:** El rol de base de datos que ejecuta la acción (`app_web`).
*   **Desde dónde:** El origen de la conexión y a qué base (`database=food_store host=[local]`).
*   **Qué:** La sentencia SQL cruda que se envió al motor (`statement: UPDATE producto...`).

**Lo que queda fuera del alcance (limitaciones nativas):**
Este mecanismo nativo no nos permite saber el detalle fino a nivel de filas. Por ejemplo, en el UPDATE, sabemos qué instrucción se envió, pero el log no registra si esa consulta afectó a cero, una o mil filas, ni cuáles eran los valores anteriores (before/after) de los registros modificados. Para lograr esa granularidad fila por fila se necesitaría implementar una extensión dedicada como `pgaudit`.

## 3. Sensibilidad y protección del archivo de log (Punto 4)
Sí, el archivo de log es en sí mismo un activo altamente sensible porque contiene detalles de la infraestructura, nombres de usuarios, direcciones IP y, potencialmente, datos personales o confidenciales escritos en texto plano dentro de las sentencias SQL registradas (por ejemplo, correos o parámetros de funciones). 

Por lo tanto, a nivel de sistema operativo, el log solo debe poder ser leído por el usuario administrador del servicio (como `postgres` o `root`) con permisos restrictivos (ej. `600`). Dentro del motor, solo los roles de máxima jerarquía o un rol específico de auditoría (asignado con permisos como `pg_read_server_files`) deberían tener capacidad para consultarlo mediante funciones del sistema.