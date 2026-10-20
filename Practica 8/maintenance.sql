-- =============================================================
-- maintenance.sql - Revision de mantenimiento semanal (TP Unidad 6, Parte 3)
-- Uso: psql -h localhost -p 5432 -U postgres -d food_store -f maintenance.sql
-- Compatible con PostgreSQL 16+.
--
-- Criterio: NO se usa VACUUM FULL (bloquea la tabla con ACCESS EXCLUSIVE
-- y reescribe todo). La unica accion es VACUUM (ANALYZE) comun, que no
-- bloquea lecturas ni escrituras, y SOLO sobre las tablas que la
-- observacion del paso 2 marca como necesitadas.
-- =============================================================

\echo '== 1. Configuracion de autovacuum =='
SELECT name, setting, unit
FROM pg_settings
WHERE name IN ('autovacuum',
               'autovacuum_naptime',
               'autovacuum_vacuum_threshold',
               'autovacuum_vacuum_scale_factor',
               'autovacuum_analyze_threshold',
               'autovacuum_analyze_scale_factor',
               'track_counts')
ORDER BY name;

-- Umbral de disparo de autovacuum por tabla:
--   threshold + scale_factor * n_live_tup
-- Si las tuplas muertas superan ese valor y autovacuum no corrio,
-- hay un problema (autovacuum apagado, atrasado o bloqueado).

\echo '== 2. Observacion previa: estado de cada tabla =='
CREATE TEMP VIEW v_estado_mant AS
SELECT relname,
       n_live_tup,
       n_dead_tup,
       round(100.0 * n_dead_tup / NULLIF(n_live_tup + n_dead_tup, 0), 2) AS pct_muertas,
       n_mod_since_analyze,
       GREATEST(last_vacuum,  last_autovacuum)  AS ultimo_vacuum,   -- GREATEST ignora NULLs
       GREATEST(last_analyze, last_autoanalyze) AS ultimo_analyze,
       -- Necesita mantenimiento si:
       --   a) >10% de tuplas muertas (espacio no reutilizado), o
       --   b) >10% de filas modificadas desde el ultimo ANALYZE (estadisticas viejas), o
       --   c) nunca fue analizada (el planificador estima a ciegas).
       (    n_dead_tup          > 0.10 * GREATEST(n_live_tup, 1)
         OR n_mod_since_analyze > 0.10 * GREATEST(n_live_tup, 1)
         OR (last_analyze IS NULL AND last_autoanalyze IS NULL)
       ) AS necesita_mant
FROM pg_stat_user_tables;

SELECT * FROM v_estado_mant ORDER BY necesita_mant DESC, n_dead_tup DESC;

\echo '== 3. Accion: VACUUM (ANALYZE) solo sobre tablas marcadas =='
-- \gexec ejecuta cada fila resultante como un comando. Si ninguna tabla
-- cumple el criterio, no se ejecuta nada (mantenimiento no necesario).
SELECT format('VACUUM (ANALYZE) %I', relname)
FROM v_estado_mant
WHERE necesita_mant
\gexec

\echo '== 4. Verificacion posterior =='
SELECT relname, n_live_tup, n_dead_tup, n_mod_since_analyze,
       last_vacuum, last_analyze
FROM pg_stat_user_tables
ORDER BY relname;
