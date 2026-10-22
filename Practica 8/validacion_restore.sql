-- =============================================================
-- validacion_restore.sql - Validacion minima (TP Unidad 6, Parte 4)
-- Uso: psql -h localhost -p 5432 -U postgres -d foodstore_restore_test -f validacion_restore.sql
-- Solo lectura. Lo usan backup_foodstore.ps1 (filas antes del respaldo)
-- y restore_test.ps1 (filas despues de restaurar). Cada fila devuelve
-- "control | valor" para que los scripts puedan compararlas.
--
-- Diferencias con la consulta del enunciado:
--   * El enunciado cuenta la tabla "cliente"; en Food Store los clientes
--     estan en la tabla "usuario".
--   * No se filtra eliminado = FALSE a proposito: el respaldo tiene que
--     conservar tambien las filas con baja logica.
-- =============================================================

\echo '== 1. Filas por tabla (se comparan con las registradas antes del respaldo) =='
SELECT 'categoria' AS tabla, COUNT(*) AS filas FROM categoria
UNION ALL SELECT 'usuario', COUNT(*) FROM usuario
UNION ALL SELECT 'producto', COUNT(*) FROM producto
UNION ALL SELECT 'pedido', COUNT(*) FROM pedido
UNION ALL SELECT 'detalle_pedido', COUNT(*) FROM detalle_pedido;

\echo '== 2. Restricciones logicas (deben dar 0) =='
SELECT 'productos_invalidos' AS control, COUNT(*) AS cantidad
FROM producto
WHERE precio < 0 OR stock < 0;

SELECT 'detalles_invalidos' AS control, COUNT(*) AS cantidad
FROM detalle_pedido
WHERE cantidad <= 0 OR precio_unitario < 0;
