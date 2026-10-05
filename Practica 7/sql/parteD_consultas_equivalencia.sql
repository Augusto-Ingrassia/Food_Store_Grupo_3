-- =============================================================================
-- Práctica 7 — Parte D: Consultas de agregación y verificación de equivalencia
-- Base de datos: Food Store  |  Motor: PostgreSQL 16+
--
-- Ejecución (después de parteD_usuario_anon.sql):
--   psql -h localhost -U postgres -d food_store -f sql/parteD_consultas_equivalencia.sql
--
-- Agregación pedida: cantidad de usuarios (no eliminados) por rol y por mes
-- de alta. Ambas consultas devuelven las mismas columnas, con el mismo formato
-- y el mismo orden: rol | mes_alta ('YYYY-MM') | cantidad_usuarios.
-- Solo SELECT: el script no modifica datos.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- D.1 Consulta sobre la tabla ANONIMIZADA (usuario_anon)
-- Generada por OpenCode (Build · Muse Spark 1.3), copiada tal cual.
-- Validación: filtra eliminado = FALSE y no lee datos personales.
-- -----------------------------------------------------------------------------
-- >>> D.1  usuario_anon: usuarios por rol y mes de alta
SELECT rol, TO_CHAR(mes_alta, 'YYYY-MM') AS mes_alta, COUNT(*) AS cantidad_usuarios
FROM usuario_anon
WHERE eliminado = FALSE
GROUP BY rol, mes_alta
ORDER BY mes_alta, rol;


-- -----------------------------------------------------------------------------
-- D.2 Consulta equivalente sobre la tabla REAL (usuario)
-- Generada por OpenCode (misma sesión), copiada tal cual.
-- Validación: solo lee rol, created_at y eliminado; convierte a la zona
-- America/Argentina/Buenos_Aires ANTES de truncar al mes (igual que
-- usuario_anon), y filtra eliminado = FALSE.
-- -----------------------------------------------------------------------------
-- >>> D.2  usuario (real): usuarios por rol y mes de alta
SELECT rol, TO_CHAR(DATE_TRUNC('month', created_at AT TIME ZONE 'America/Argentina/Buenos_Aires'), 'YYYY-MM') AS mes_alta, COUNT(*) AS cantidad_usuarios
FROM usuario
WHERE eliminado = FALSE
GROUP BY rol, DATE_TRUNC('month', created_at AT TIME ZONE 'America/Argentina/Buenos_Aires')
ORDER BY mes_alta, rol;


-- -----------------------------------------------------------------------------
-- D.3 Resultados uno junto al otro
-- FULL OUTER JOIN: si un grupo existiera en una sola de las tablas, aparece
-- con NULL del otro lado y coincide = 'NO'.
-- -----------------------------------------------------------------------------
-- >>> D.3  Comparación lado a lado
WITH anon AS (
    SELECT rol, to_char(mes_alta, 'YYYY-MM') AS mes_alta, count(*) AS cantidad
    FROM usuario_anon
    WHERE eliminado = FALSE
    GROUP BY rol, mes_alta
),
real AS (
    SELECT rol,
           to_char(date_trunc('month', created_at AT TIME ZONE 'America/Argentina/Buenos_Aires'),
                   'YYYY-MM') AS mes_alta,
           count(*) AS cantidad
    FROM usuario
    WHERE eliminado = FALSE
    GROUP BY 1, 2
)
SELECT
    coalesce(a.rol, r.rol)                 AS rol,
    coalesce(a.mes_alta, r.mes_alta)       AS mes_alta,
    a.cantidad                             AS cantidad_usuario_anon,
    r.cantidad                             AS cantidad_usuario_real,
    CASE WHEN a.cantidad IS NOT DISTINCT FROM r.cantidad
         THEN 'SI' ELSE 'NO' END           AS coincide
FROM anon a
FULL OUTER JOIN real r
       ON r.rol = a.rol AND r.mes_alta = a.mes_alta
ORDER BY 2, 1;


-- -----------------------------------------------------------------------------
-- D.4 Verificación automática: diferencia simétrica (EXCEPT en ambos sentidos)
-- Debe devolver 0 en las dos columnas. Más fuerte que comparar a ojo:
-- detecta tanto conteos distintos como grupos que faltan o sobran.
-- -----------------------------------------------------------------------------
-- >>> D.4  Diferencia simétrica (esperado: 0 y 0)
WITH anon AS (
    SELECT rol, to_char(mes_alta, 'YYYY-MM') AS mes_alta, count(*) AS cantidad
    FROM usuario_anon WHERE eliminado = FALSE GROUP BY 1, 2
),
real AS (
    SELECT rol,
           to_char(date_trunc('month', created_at AT TIME ZONE 'America/Argentina/Buenos_Aires'),
                   'YYYY-MM') AS mes_alta,
           count(*) AS cantidad
    FROM usuario WHERE eliminado = FALSE GROUP BY 1, 2
)
SELECT
    (SELECT count(*) FROM (SELECT * FROM anon EXCEPT SELECT * FROM real) x) AS filas_solo_en_anon,
    (SELECT count(*) FROM (SELECT * FROM real EXCEPT SELECT * FROM anon) y) AS filas_solo_en_real,
    (SELECT sum(cantidad) FROM anon)                                         AS total_anon,
    (SELECT sum(cantidad) FROM real)                                         AS total_real;


-- -----------------------------------------------------------------------------
-- D.5 Control negativo (opcional, no modifica nada)
-- Demuestra que la verificación D.4 sí detecta una anonimización que
-- distorsiona: se simula una versión NO determinista que corre el mes de alta
-- al azar entre 0 y 11 meses hacia atrás (error típico: "aleatorizar fechas
-- para que sea más anónimo"). Con setseed el resultado es reproducible.
-- Esperado: filas distintas de 0 en ambas columnas.
-- -----------------------------------------------------------------------------
-- >>> D.5  Control negativo: anonimización con fechas aleatorias
SELECT setseed(0.42);
WITH anon_mal AS (
    SELECT rol,
           to_char(mes_alta - make_interval(months => floor(random() * 12)::int),
                   'YYYY-MM') AS mes_alta
    FROM usuario_anon WHERE eliminado = FALSE
),
anon AS (
    SELECT rol, mes_alta, count(*) AS cantidad FROM anon_mal GROUP BY 1, 2
),
real AS (
    SELECT rol,
           to_char(date_trunc('month', created_at AT TIME ZONE 'America/Argentina/Buenos_Aires'),
                   'YYYY-MM') AS mes_alta,
           count(*) AS cantidad
    FROM usuario WHERE eliminado = FALSE GROUP BY 1, 2
)
SELECT
    (SELECT count(*) FROM (SELECT * FROM anon EXCEPT SELECT * FROM real) x) AS filas_solo_en_anon,
    (SELECT count(*) FROM (SELECT * FROM real EXCEPT SELECT * FROM anon) y) AS filas_solo_en_real,
    (SELECT sum(cantidad) FROM anon)                                         AS total_anon,
    (SELECT sum(cantidad) FROM real)                                         AS total_real;
