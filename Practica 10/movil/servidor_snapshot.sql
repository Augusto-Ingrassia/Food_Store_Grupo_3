-- Consigna 2.a — Instantánea del servidor para la tablet (PostgreSQL de PRUEBAS, nunca producción)
-- Correr parado en la carpeta movil/ (\copy escribe el CSV en el directorio actual):
--   $env:PGCLIENTENCODING = "UTF8"
--   psql -U postgres -d food_store_pruebas -f servidor_snapshot.sql

-- La vista NO filtra eliminado = FALSE a propósito: los productos dados de baja viajan como
-- "lápidas" (eliminado = t) para que la tablet sepa que tiene que ocultarlos. Si se filtraran,
-- la tablet nunca se enteraría de la baja y seguiría ofreciendo el producto.
-- Solo viajan columnas del catálogo: nada de usuarios, pedidos ni datos internos.
CREATE OR REPLACE VIEW v_snapshot_movil AS
SELECT p.id,
       p.nombre,
       ROUND(p.precio * 100)::INTEGER          AS precio_centavos, -- la tablet trabaja en centavos enteros
       p.stock,
       p.disponible,
       p.eliminado,
       to_char(now(), 'YYYY-MM-DD HH24:MI:SS') AS fecha_copia
FROM producto p;

\copy (SELECT * FROM v_snapshot_movil ORDER BY id) TO 'servidor_snapshot.csv' CSV HEADER

-- Fecha de la copia exportada (anotarla en el informe)
SELECT MAX(fecha_copia) AS fecha_de_la_copia, COUNT(*) AS productos_exportados
FROM v_snapshot_movil;
