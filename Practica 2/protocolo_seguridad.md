Protocolo de Seguridad - Food Store
1. Copia
Nunca se ejecutarán los scripts sobre los datos reales; siempre se trabajará sobre una base de desarrollo temporal.
Comando a utilizar: 
createdb -U postgres -T food_store_base food_store_copia  

2. Transacción
Todo script que modifique datos se ejecutará primero dentro de un bloque transaccional para inspeccionar las filas afectadas y posibles errores antes de confirmar.
Comandos a utilizar:  
SQLBEGIN;
ROLLBACK; 

3. Respaldo
Se ejecutará un backup independiente de la copia de trabajo antes de aplicar cambios estructurales grandes (ALTER, DROP) para poder revertir sin depender de la transacción.
Comando a utilizar: 
pg_dump -U postgres -d food_store_copia > respaldo_esquema.sql