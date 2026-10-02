-- =============================================================================
-- Práctica 7 — Modelo de Identidades y Accesos (IAM)
-- Base de datos: Food Store  |  Motor: PostgreSQL 16+
-- Principio rector: mínimo privilegio
--
-- Orden de ejecución: después de schema.sql, objects.sql y views.sql.
-- El script es idempotente: puede ejecutarse varias veces sin errores.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- SECCIÓN 0: Revocar permisos por defecto del rol PUBLIC
-- Impide que cualquier usuario conectado herede acceso implícito al esquema.
-- -----------------------------------------------------------------------------

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL TABLES    IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL PROCEDURES IN SCHEMA public FROM PUBLIC;


-- =============================================================================
-- SECCIÓN 1: Roles de Grupo (NOLOGIN)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1.1 rol_app_lectura
-- Lectura del catálogo público (productos y categorías).
-- -----------------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rol_app_lectura') THEN
        CREATE ROLE rol_app_lectura NOLOGIN;
    END IF;
END $$;

-- Acceso al esquema
GRANT USAGE ON SCHEMA public TO rol_app_lectura;

-- Tablas base del catálogo
GRANT SELECT ON TABLE categoria TO rol_app_lectura;
GRANT SELECT ON TABLE producto  TO rol_app_lectura;

-- Vistas públicas del catálogo
-- GRANT SELECT ON TABLE v_categorias_vigentes  TO rol_app_lectura; -- BORRAR/COMENTAR
-- GRANT SELECT ON TABLE v_productos_vigentes   TO rol_app_lectura; -- BORRAR/COMENTAR
GRANT SELECT ON TABLE v_productos_categoria  TO rol_app_lectura;


-- -----------------------------------------------------------------------------
-- 1.2 rol_app_escritura
-- Escritura transaccional a través del procedimiento almacenado.
-- No incluye DELETE; el soft-delete lo maneja la aplicación vía UPDATE.
-- -----------------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rol_app_escritura') THEN
        CREATE ROLE rol_app_escritura NOLOGIN;
    END IF;
END $$;

GRANT USAGE ON SCHEMA public TO rol_app_escritura;

-- Tablas transaccionales
GRANT INSERT, UPDATE ON TABLE pedido          TO rol_app_escritura;
GRANT INSERT, UPDATE ON TABLE detalle_pedido  TO rol_app_escritura;

-- Secuencias de las identity columns (necesarias para INSERT)
GRANT USAGE ON SEQUENCE pedido_id_seq         TO rol_app_escritura;
GRANT USAGE ON SEQUENCE detalle_pedido_id_seq TO rol_app_escritura;

-- Procedimiento almacenado: único punto de entrada validado para crear pedidos
-- GRANT EXECUTE ON PROCEDURE sp_crear_pedido(BIGINT, forma_pago, JSONB) TO rol_app_escritura;


-- -----------------------------------------------------------------------------
-- 1.3 rol_soporte
-- Gestión operativa: consulta de pedidos/usuarios y cambio de estado de envío.
-- El acceso a datos de usuario se canaliza por v_pedidos_usuario_segura,
-- que excluye la columna contrasena.
-- -----------------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rol_soporte') THEN
        CREATE ROLE rol_soporte NOLOGIN;
    END IF;
END $$;

GRANT USAGE ON SCHEMA public TO rol_soporte;

-- Lectura segura de pedidos con datos de usuario (sin contrasena)
GRANT SELECT ON TABLE v_pedidos_usuario_segura TO rol_soporte;

-- Lectura directa de pedidos para filtros operativos
GRANT SELECT ON TABLE pedido TO rol_soporte;

-- Modificación exclusiva de la columna estado (ciclo de vida del envío)
GRANT UPDATE (estado) ON TABLE pedido TO rol_soporte;


-- -----------------------------------------------------------------------------
-- 1.4 rol_reportes
-- Lectura analítica de todo el esquema operativo para herramientas de BI.
-- Sin ningún permiso de escritura.
-- -----------------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rol_reportes') THEN
        CREATE ROLE rol_reportes NOLOGIN;
    END IF;
END $$;

GRANT USAGE ON SCHEMA public TO rol_reportes;

-- Tablas base
GRANT SELECT ON TABLE categoria      TO rol_reportes;
GRANT SELECT ON TABLE producto       TO rol_reportes;
GRANT SELECT ON TABLE usuario        TO rol_reportes;
GRANT SELECT ON TABLE pedido         TO rol_reportes;
GRANT SELECT ON TABLE detalle_pedido TO rol_reportes;

-- Vistas operativas
-- GRANT SELECT ON TABLE v_categorias_vigentes    TO rol_reportes; -- BORRAR/COMENTAR
-- GRANT SELECT ON TABLE v_productos_vigentes     TO rol_reportes; -- BORRAR/COMENTAR
GRANT SELECT ON TABLE v_productos_categoria    TO rol_reportes;
-- GRANT SELECT ON TABLE v_pedidos_resumen        TO rol_reportes; -- BORRAR/COMENTAR
-- GRANT SELECT ON TABLE v_pedido_detalle         TO rol_reportes; -- BORRAR/COMENTAR
GRANT SELECT ON TABLE v_pedidos_usuario_segura TO rol_reportes;
GRANT SELECT ON TABLE v_detalle_pedido_producto TO rol_reportes;

-- Vista materializada de facturación
GRANT SELECT ON TABLE mv_facturacion_categoria_mes TO rol_reportes;


-- -----------------------------------------------------------------------------
-- 1.5 rol_auditor_seguridad  (aporte del equipo)
-- Lectura de objetos de auditoría/logs para investigación de incidentes.
-- Sin acceso a ninguna tabla de negocio.
-- Nota: el esquema de auditoría aún no existe; el rol queda preparado.
--       Cuando se cree el objeto audit.v_auditoria_accesos, ejecutar:
--         GRANT USAGE ON SCHEMA audit TO rol_auditor_seguridad;
--         GRANT SELECT ON ALL TABLES IN SCHEMA audit TO rol_auditor_seguridad;
-- -----------------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rol_auditor_seguridad') THEN
        CREATE ROLE rol_auditor_seguridad NOLOGIN;
    END IF;
END $$;

-- Sin permisos en el esquema public (aislamiento total respecto al negocio).
-- Los permisos se otorgarán sobre el esquema audit cuando sea creado.


-- =============================================================================
-- SECCIÓN 2: Roles de Login (usuarios del sistema)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 2.1 app_web
-- Usuario técnico de la API web. Hereda lectura + escritura del catálogo.
-- ATENCIÓN: cambiar la contraseña antes de desplegar en producción.
-- -----------------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_web') THEN
        CREATE ROLE app_web LOGIN PASSWORD 'cambiar_en_produccion_app_web';
    END IF;
END $$;

-- Herencia de roles de grupo
GRANT rol_app_lectura  TO app_web;
GRANT rol_app_escritura TO app_web;

-- Acceso explícito al esquema (los roles de grupo ya lo tienen, pero se replica
-- por claridad en caso de que se revoque la membresía individualmente)
GRANT USAGE ON SCHEMA public TO app_web;


-- -----------------------------------------------------------------------------
-- 2.2 admin_datos
-- DBA: crea objetos, gestiona usuarios y aplica parches de esquema.
-- Sin SUPERUSER para preservar la pista de auditoría del motor.
-- ATENCIÓN: cambiar la contraseña antes de desplegar en producción.
-- -----------------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'admin_datos') THEN
        CREATE ROLE admin_datos LOGIN PASSWORD 'cambiar_en_produccion_admin'
            CREATEDB CREATEROLE;
    END IF;
END $$;

GRANT USAGE  ON SCHEMA public TO admin_datos;
GRANT CREATE ON SCHEMA public TO admin_datos;

-- Acceso completo a todos los objetos actuales del esquema
GRANT ALL PRIVILEGES ON ALL TABLES    IN SCHEMA public TO admin_datos;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO admin_datos;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO admin_datos;
GRANT ALL PRIVILEGES ON ALL PROCEDURES IN SCHEMA public TO admin_datos;

-- =============================================================================
-- SECCIÓN: Privilegios por defecto (ALTER DEFAULT PRIVILEGES)
-- Asegura que las tablas futuras creadas por admin_datos hereden permisos.
-- =============================================================================
ALTER DEFAULT PRIVILEGES FOR ROLE admin_datos IN SCHEMA public
GRANT SELECT ON TABLES TO rol_reportes;

ALTER DEFAULT PRIVILEGES FOR ROLE admin_datos IN SCHEMA public
GRANT SELECT ON TABLES TO rol_app_lectura;

-- =============================================================================
-- SECCIÓN 3: Verificación
-- =============================================================================

-- Ejecutar estas consultas para confirmar que los roles fueron creados
-- y los permisos están correctamente asignados.

/*
-- Listar todos los roles creados por este script:
SELECT rolname, rolcanlogin, rolcreaterole, rolcreatedb, rolinherit
FROM   pg_roles
WHERE  rolname IN (
    'rol_app_lectura', 'rol_app_escritura', 'rol_soporte',
    'rol_reportes', 'rol_auditor_seguridad', 'app_web', 'admin_datos'
)
ORDER BY rolname;

-- Verificar membresías de app_web:
SELECT r.rolname AS rol_grupo
FROM   pg_auth_members m
JOIN   pg_roles r ON r.oid = m.roleid
JOIN   pg_roles u ON u.oid = m.member
WHERE  u.rolname = 'app_web';

-- Verificar permisos de tabla para rol_app_lectura:
SELECT table_name, privilege_type
FROM   information_schema.role_table_grants
WHERE  grantee = 'rol_app_lectura'
ORDER BY table_name;

-- Verificar permisos de tabla para rol_reportes:
SELECT table_name, privilege_type
FROM   information_schema.role_table_grants
WHERE  grantee = 'rol_reportes'
ORDER BY table_name;

-- Verificar permisos de procedimiento para rol_app_escritura:
SELECT routine_name, privilege_type
FROM   information_schema.role_routine_grants
WHERE  grantee = 'rol_app_escritura';
*/
