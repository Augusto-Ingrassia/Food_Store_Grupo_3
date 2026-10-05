-- =============================================================================
-- Práctica 7 — Parte D: Creación / actualización de usuario_anon
-- Base de datos: Food Store  |  Motor: PostgreSQL 16+
--
-- Ejecución (psql, conectado como postgres o admin_datos):
--   psql -h localhost -U postgres -d food_store -f sql/parteD_usuario_anon.sql
--
-- Qué hace:
--   Regenera usuario_anon a partir de usuario con datos sintéticos
--   DETERMINISTAS: cada valor falso se calcula solo a partir del id, sin
--   random(). Correr el script dos veces produce exactamente la misma tabla,
--   y el usuario id 3 siempre es usuario_3@ejemplo.com (mismo criterio que se
--   usó para anonimizar el log del simulacro en la Parte C).
--
-- Criterio por columna:
--   id          -> se conserva (seudónimo técnico; permite joins con pedido).
--   nombre      -> 'Usuario_<id>'            (sustitución determinista)
--   apellido    -> 'Anon_<id>'               (sustitución determinista)
--   mail        -> 'usuario_<id>@ejemplo.com'(sustitución determinista, único)
--   celular     -> '000-<id con 7 dígitos>'  (se respeta si era NULL)
--   contrasena  -> NO se copia               (supresión: no hay uso analítico)
--   rol         -> se conserva               (dato de negocio, necesario)
--   eliminado   -> se conserva               (necesario para el soft-delete)
--   created_at  -> mes_alta (DATE, día 1)    (generalización: se pierde el
--                                             día y la hora exactos)
--
-- Es idempotente: usuario_anon es un derivado 100 % regenerable de usuario,
-- por eso se borra y se vuelve a crear (si existía una versión de la Clase 2
-- con otra estructura, queda reemplazada por esta).
-- =============================================================================

-- (Compatible con psql y DBeaver: si algo falla, la transacción se revierte sola.)

BEGIN;

DROP TABLE IF EXISTS usuario_anon;

CREATE TABLE usuario_anon (
    id         BIGINT       PRIMARY KEY,
    nombre     VARCHAR(80)  NOT NULL,
    apellido   VARCHAR(80)  NOT NULL,
    mail       VARCHAR(120) NOT NULL UNIQUE,
    celular    VARCHAR(30),
    rol        rol          NOT NULL,
    eliminado  BOOLEAN      NOT NULL,
    mes_alta   DATE         NOT NULL
);

COMMENT ON TABLE usuario_anon IS
  'Copia anonimizada de usuario (Parte D). Datos sintéticos deterministas por id. '
  'Regenerar con sql/parteD_usuario_anon.sql. No contiene contraseñas.';

-- La zona horaria se fija explícitamente: así el mes de alta no depende del
-- TimeZone de la sesión que ejecute el script (un alta del 31/10 a las 22 h
-- en Argentina es 01/11 en UTC).
INSERT INTO usuario_anon (id, nombre, apellido, mail, celular, rol, eliminado, mes_alta)
SELECT
    u.id,
    'Usuario_' || u.id,
    'Anon_'    || u.id,
    'usuario_' || u.id || '@ejemplo.com',
    CASE WHEN u.celular IS NULL THEN NULL
         ELSE '000-' || lpad(u.id::text, 7, '0')
    END,
    u.rol,
    u.eliminado,
    date_trunc('month', u.created_at AT TIME ZONE 'America/Argentina/Buenos_Aires')::date
FROM usuario u;


-- -----------------------------------------------------------------------------
-- Controles automáticos: si alguno falla, la transacción se revierte.
-- -----------------------------------------------------------------------------
DO $$
DECLARE
    v_real   BIGINT;
    v_anon   BIGINT;
    v_fugas  BIGINT;
BEGIN
    SELECT count(*) INTO v_real FROM usuario;
    SELECT count(*) INTO v_anon FROM usuario_anon;
    IF v_real <> v_anon THEN
        RAISE EXCEPTION 'usuario_anon tiene % filas y usuario tiene %', v_anon, v_real;
    END IF;

    -- Ningún dato identificable real puede aparecer en la copia anonimizada.
    SELECT count(*) INTO v_fugas
    FROM usuario_anon a
    WHERE EXISTS (SELECT 1 FROM usuario u
                  WHERE u.mail     = a.mail
                     OR u.celular  = a.celular
                     OR (u.nombre = a.nombre AND u.apellido = a.apellido));
    IF v_fugas > 0 THEN
        RAISE EXCEPTION 'Se detectaron % filas con datos reales en usuario_anon', v_fugas;
    END IF;

    RAISE NOTICE 'usuario_anon OK: % filas, 0 datos reales detectados', v_anon;
END $$;


-- -----------------------------------------------------------------------------
-- Permisos (mínimo privilegio, coherente con roles.sql)
-- -----------------------------------------------------------------------------
-- Nadie la lee por defecto. rol_reportes la recibe porque es justamente el rol
-- que en la Parte C pudo leer la tabla usuario completa (contraseñas incluidas):
-- usuario_anon es la alternativa segura para análisis y BI.
REVOKE ALL ON TABLE usuario_anon FROM PUBLIC;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rol_reportes') THEN
        GRANT SELECT ON TABLE usuario_anon TO rol_reportes;
    END IF;
    -- Si la tabla la creó admin_datos, su ALTER DEFAULT PRIVILEGES le habría
    -- dado SELECT a rol_app_lectura (catálogo público). Se quita explícitamente.
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rol_app_lectura') THEN
        REVOKE ALL ON TABLE usuario_anon FROM rol_app_lectura;
    END IF;
END $$;

COMMIT;

-- Vista rápida del resultado
SELECT * FROM usuario_anon ORDER BY id LIMIT 5;
