## Descripción del Proyecto
Diseño e implementación de una base de datos relacional para la gestión de pedidos de un negocio de comidas. El proyecto demuestra el modelado conceptual, lógico y físico, junto con el uso avanzado de SQL (DDL, DML, vistas, procedimientos almacenados, triggers y control transaccional) enfocado en garantizar la integridad de los datos.

## Requisitos
* **Motor de BD:** PostgreSQL 16 o superior.
* **Herramientas recomendadas:** pgAdmin o psql.

## Orden de Ejecución de los Scripts
Para recrear la base de datos y probar el sistema correctamente, es necesario ejecutar los scripts en el siguiente orden sobre una base de datos vacía:

1. **`schema.sql`**: Contiene el DDL. Crea los tipos enumerados, las tablas con sus respectivas restricciones y los índices.
3. **`data.sql`**: Inserta los datos de ejemplo necesarios para realizar las pruebas.
3. **`objects.sql`**: Define la lógica del servidor. Crea las vistas, las funciones, los triggers y el procedimiento almacenado transaccional.
4. **`queries.sql`**: Contiene las consultas SQL resueltas para cada Historia de Usuario.
5. **`transacciones.sql`**: Incluye los scripts utilizados para probar y evidenciar escenarios de transacciones y el manejo de concurrencia.
