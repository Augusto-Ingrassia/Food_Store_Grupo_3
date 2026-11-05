# Food Store Móvil - Proyecto de Sincronización (TP8)

Este directorio contiene la simulación de la base de datos para la tablet offline (SQLite) y su sincronización con el servidor (PostgreSQL).

## Orden de ejecución para levantar el entorno desde cero:

1. **Crear la base de datos de la tablet:**
   Abrir terminal en la carpeta `movil/` y ejecutar:
   `sqlite3 foodstore_movil.db < schema_sqlite.sql`

2. **Correr las pruebas iniciales:**
   Ejecutar las pruebas locales para validar FKs y restricciones:
   `sqlite3 foodstore_movil.db < pruebas_sqlite.sql`

3. **Extraer el catálogo del servidor (PostgreSQL):**
   Conectarse a PostgreSQL y exportar la instantánea:
   `\copy (SELECT * FROM v_snapshot_movil) TO 'servidor_snapshot.csv' CSV HEADER`

4. **Importar la instantánea a la tablet (SQLite):**
   Dentro de `sqlite3 foodstore_movil.db`:
   `.import --csv --skip 1 servidor_snapshot.csv snapshot_servidor`

5. **Simular los casos y correr el semáforo:**
   Insertar los casos (C2 a C6) en la base SQLite y ejecutar el motor de resolución:
   `sqlite3 foodstore_movil.db < semaforo.sql`