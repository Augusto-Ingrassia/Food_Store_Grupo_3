-- =============================================================
-- health_check.sql - Chequeo de salud diario (TP Unidad 6, Parte 3)
-- Uso: psql -h localhost -p 5432 -U postgres -d food_store -f health_check.sql
-- Solo lectura: no modifica datos. Compatible con PostgreSQL 16+.
-- Se usa current_database() para no depender del nombre de la base.
-- =============================================================

\echo '== 1. Tamano de la base =='
SELECT current_database()                             AS base,
       pg_size_pretty(pg_database_size(current_database())) AS tamano;

\echo '== 2. Actividad de conexiones y transacciones =='
SELECT numbackends                                    AS conexiones_activas,
       (SELECT setting::int FROM pg_settings WHERE name = 'max_connections') AS max_conexiones,
       xact_commit,
       xact_rollback,
       round(100.0 * blks_hit / NULLIF(blks_hit + blks_read, 0), 2) AS cache_hit_pct,
       deadlocks
FROM pg_stat_database
WHERE datname = current_database();

\echo '== 2b. Conexiones por estado =='
SELECT COALESCE(state, 'sin estado') AS estado, COUNT(*) AS cantidad
FROM pg_stat_activity
WHERE datname = current_database()
GROUP BY state
ORDER BY cantidad DESC;

\echo '== 3. Estado de tablas (tuplas vivas/muertas, vacuum, analyze) =='
SELECT relname                                         AS tabla,
       n_live_tup,
       n_dead_tup,
       round(100.0 * n_dead_tup / NULLIF(n_live_tup + n_dead_tup, 0), 2) AS pct_muertas,
       n_mod_since_analyze,
       last_vacuum,
       last_autovacuum,
       last_analyze,
       last_autoanalyze,
       pg_size_pretty(pg_total_relation_size(relid)) AS tamano_total
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC;

\echo '== 4. Consultas activas (no idle) =='
SELECT pid,
       usename,
       state,
       wait_event_type,
       now() - query_start AS duracion,
       left(query, 120)    AS consulta
FROM pg_stat_activity
WHERE datname = current_database()
  AND state <> 'idle'
  AND pid <> pg_backend_pid()          -- excluye esta misma sesion
ORDER BY duracion DESC NULLS LAST;

\echo '== 5. Bloqueos: sesiones esperando a otra =='
SELECT pid,
       pg_blocking_pids(pid) AS bloqueado_por,
       now() - query_start   AS esperando,
       left(query, 120)      AS consulta
FROM pg_stat_activity
WHERE datname = current_database()
  AND cardinality(pg_blocking_pids(pid)) > 0;
