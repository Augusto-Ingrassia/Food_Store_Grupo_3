-- =============================================================================
-- Práctica 7 — Parte C: Simulacro de incidente de acceso indebido
-- Base de datos: Food Store  |  Motor: PostgreSQL 16+
--
-- IMPORTANTE: ejecutar SOLO contra la base de desarrollo propia.
--
-- Ejecución (psql, conectado como postgres a la base de Food Store):
--   psql -h localhost -U postgres -d <base_food_store> -f simulacro_incidente.sql
--
-- Precondiciones: schema.sql, objects.sql, views.sql, data.sql y roles.sql
-- ya aplicados. El script no corta ante errores (ON_ERROR_STOP desactivado)
-- porque los errores de permisos del paso 4 son justamente lo que se prueba.
--
-- Secuencia simulada (consigna Parte C, punto 1):
--   1. Varios intentos fallidos de login contra fn_autenticar.
--   2. Un login exitoso.
--   3. Lectura masiva de la tabla usuario.
--   4. Intento de escalamiento hacia admin_datos.
-- =============================================================================

\set ON_ERROR_STOP off


-- =============================================================================
-- SECCIÓN 0: Precondiciones (ejecutadas como postgres)
-- =============================================================================

-- 0.1 Auditoría activa. Se usa log_statement = 'all' porque con 'mod'
--     (valor de la Parte B) los SELECT —intentos de login y lectura masiva—
--     no quedarían registrados. log_line_prefix agrega quién/desde dónde.
ALTER SYSTEM SET log_connections    = on;
ALTER SYSTEM SET log_disconnections = on;
ALTER SYSTEM SET log_statement      = 'all';
ALTER SYSTEM SET log_line_prefix    = '%m [%p] %q%u@%d %r ';
SELECT pg_reload_conf();
SELECT pg_sleep(1);

-- 0.2 Reconstrucción de fn_autenticar (Clase 2). No estaba en el repositorio.
--     SECURITY DEFINER: quien la invoca no necesita SELECT sobre usuario.
--     search_path fijo: evita que se secuestre la resolución de nombres.
--     Los intentos fallidos se registran con RAISE LOG (quedan en el log
--     del servidor aunque log_statement no los capture).
--     Nota: los datos de ejemplo guardan contrasena en texto plano, por eso
--     la comparación es directa. En producción se compararía contra un hash
--     (pgcrypto: contrasena = crypt(p_contrasena, contrasena)).
CREATE OR REPLACE FUNCTION fn_autenticar(p_mail VARCHAR, p_contrasena VARCHAR)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_ok BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1
        FROM   usuario
        WHERE  mail = p_mail
          AND  contrasena = p_contrasena
          AND  eliminado = FALSE
    ) INTO v_ok;

    IF NOT v_ok THEN
        RAISE LOG 'fn_autenticar: intento fallido para %', p_mail;
    END IF;

    RETURN v_ok;
END;
$$;

REVOKE ALL     ON FUNCTION fn_autenticar(VARCHAR, VARCHAR) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_autenticar(VARCHAR, VARCHAR) TO app_web;

-- 0.3 Credencial comprometida simulada: login de bajo privilegio, miembro
--     únicamente de rol_reportes (solo lectura). Rol temporal, se elimina
--     en la Sección 2.
DROP ROLE IF EXISTS analista_bi;
CREATE ROLE analista_bi LOGIN PASSWORD 'Simulacro_2026' IN ROLE rol_reportes;
GRANT EXECUTE ON FUNCTION fn_autenticar(VARCHAR, VARCHAR) TO analista_bi;


-- =============================================================================
-- SECCIÓN 1: Secuencia del incidente (sesión del "atacante" como analista_bi)
-- =============================================================================

\setenv PGPASSWORD 'Simulacro_2026'
\c - analista_bi

SELECT current_user, session_user;

-- 1.1 Intentos fallidos de inicio de sesión (fuerza bruta sobre una cuenta ADMIN)
SELECT fn_autenticar('admin@foodstore.com', 'admin123');
SELECT fn_autenticar('admin@foodstore.com', '123456');
SELECT fn_autenticar('admin@foodstore.com', 'foodstore');
SELECT fn_autenticar('admin@foodstore.com', 'password');
SELECT fn_autenticar('admin@foodstore.com', 'admin2026');

-- 1.2 Inicio de sesión exitoso
SELECT fn_autenticar('admin@foodstore.com', 'adminpass');

-- 1.3 Lectura masiva de la tabla usuario
SELECT * FROM usuario;

-- 1.4 Intentos de escalamiento hacia admin_datos (todos deben FALLAR)
-- a) Auto-otorgarse membresía en admin_datos
GRANT admin_datos TO analista_bi;
-- b) Otorgar admin_datos al rol de grupo de bajo privilegio
GRANT admin_datos TO rol_reportes;
-- c) Asumir la identidad de admin_datos
SET ROLE admin_datos;
-- d) Operación reservada a admin_datos: crear objetos en el esquema
CREATE TABLE public.copia_usuario AS SELECT * FROM usuario;


-- =============================================================================
-- SECCIÓN 2: Verificación del escalamiento y limpieza (como postgres)
-- =============================================================================

\setenv PGPASSWORD
\c - postgres

-- 2.1 Consigna Parte C, punto 2: ¿el escalamiento falló?
--     Resultado esperado: es_miembro_admin_datos = false en ambas filas
--     y copia_usuario_existe = false.
SELECT r.rolname AS rol,
       pg_has_role(r.rolname, 'admin_datos', 'MEMBER') AS es_miembro_admin_datos
FROM   pg_roles r
WHERE  r.rolname IN ('analista_bi', 'rol_reportes');

SELECT to_regclass('public.copia_usuario') IS NOT NULL AS copia_usuario_existe;

-- 2.2 Archivo de log donde quedó registrada la secuencia
SELECT pg_current_logfile() AS archivo_log;

-- 2.3 Limpieza del rol temporal
REVOKE EXECUTE ON FUNCTION fn_autenticar(VARCHAR, VARCHAR) FROM analista_bi;
DROP OWNED BY analista_bi;
DROP ROLE analista_bi;
