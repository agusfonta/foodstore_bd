-- =============================================================================
-- FOODSTORE — Esquema de Roles y Permisos de Mínimo Privilegio
-- TP Unidad 5 — Parte A
-- Motor: PostgreSQL 16+
-- =============================================================================
-- PROTOCOLO DE SEGURIDAD (ver protocolo_seguridad.md):
--   1. Ejecutar SIEMPRE sobre la copia de trabajo:
--        createdb -U postgres -T foodstore foodstore_desarrollo
--        \c foodstore_desarrollo
--   2. Primera ejecución dentro de BEGIN/ROLLBACK para revisar sin confirmar.
--   3. pg_dump antes de cualquier DDL sobre la copia.
--
-- Este script es parcialmente idempotente: los CREATE ROLE usan
-- "IF NOT EXISTS" (PostgreSQL 9.6+). Los GRANT son seguros de re-ejecutar.
-- Los REVOKE también son idempotentes (no fallan si el privilegio no existe).
--
-- Orden de ejecución: correr primero parcial1_01_ddl_schema.sql,
-- parcial1_06_vistas.sql y parcial1_07_vista_materializada.sql para que los
-- objetos referenciados existan.
-- =============================================================================

-- =============================================================================
-- SECCIÓN 1 — ROLES DE GRUPO (NOLOGIN)
-- Definen QUÉ se puede hacer. No tienen contraseña ni permiso de conexión.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- rol_app_lectura
-- Habilita la lectura del catálogo de productos y pedidos propios a través
-- de vistas. Los visitantes y clientes del sitio web usan este rol
-- indirectamente vía app_web.
-- -----------------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rol_app_lectura') THEN
        CREATE ROLE rol_app_lectura NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE;
    END IF;
END
$$;

-- -----------------------------------------------------------------------------
-- rol_app_escritura
-- Habilita la creación y actualización operativa de pedidos durante el flujo
-- de compra. No permite borrado físico: el sistema usa borrado lógico.
-- -----------------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rol_app_escritura') THEN
        CREATE ROLE rol_app_escritura NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE;
    END IF;
END
$$;

-- -----------------------------------------------------------------------------
-- rol_soporte
-- Habilita al personal de atención al cliente a consultar datos básicos de
-- clientes (sin contraseña) y el historial/detalle de pedidos.
-- -----------------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rol_soporte') THEN
        CREATE ROLE rol_soporte NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE;
    END IF;
END
$$;

-- -----------------------------------------------------------------------------
-- rol_reportes
-- Habilita la lectura de vistas analíticas y la vista materializada de
-- facturación para la generación de reportes gerenciales.
-- -----------------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rol_reportes') THEN
        CREATE ROLE rol_reportes NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE;
    END IF;
END
$$;


-- =============================================================================
-- SECCIÓN 2 — ROLES DE LOGIN
-- Definen QUIÉN se conecta. Heredan permisos de los roles de grupo.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- app_web
-- Identidad de la aplicación web en la base de datos. CONNECTION LIMIT 10
-- evita que un bug o ataque de denegación de servicio agote el pool.
-- La contraseña se cifra con SCRAM-SHA-256 (método configurado en pg_hba.conf).
-- NOTA: cambiar 'cambiar_esta_password_app' por una contraseña segura antes
-- de aplicar en producción.
-- -----------------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_web') THEN
        CREATE ROLE app_web WITH
            LOGIN
            PASSWORD 'cambiar_esta_password_app'
            CONNECTION LIMIT 100
            NOSUPERUSER
            NOCREATEDB
            NOCREATEROLE;
    END IF;
END
$$;

-- -----------------------------------------------------------------------------
-- admin_datos
-- Identidad administrativa para mantenimiento del esquema, creación de objetos
-- y gestión de roles. CREATEDB y CREATEROLE son necesarios para su función;
-- SUPERUSER está explícitamente excluido (saltearía todos los controles de ACL).
-- NOTA: cambiar 'cambiar_esta_password_admin' por una contraseña segura.
-- -----------------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'admin_datos') THEN
        CREATE ROLE admin_datos WITH
            LOGIN
            PASSWORD 'cambiar_esta_password_admin'
            CREATEDB
            CREATEROLE
            NOSUPERUSER;
    END IF;
END
$$;


-- =============================================================================
-- SECCIÓN 3 — ACCESO AL ESQUEMA (prerequisito universal)
-- Sin USAGE sobre el esquema, ningún rol puede resolver nombres de objetos
-- aunque tenga SELECT sobre ellos.
-- =============================================================================

GRANT USAGE ON SCHEMA public TO
    rol_app_lectura,
    rol_app_escritura,
    rol_soporte,
    rol_reportes;


-- =============================================================================
-- SECCIÓN 4 — PRIVILEGIOS DE rol_app_lectura
-- Catálogo de productos y consulta de pedidos propios.
-- Solo a través de vistas: no se otorga SELECT directo sobre tablas base.
-- =============================================================================

-- Catálogo vigente (productos + categoría, filtrado por borrado lógico)
GRANT SELECT ON v_productos_vigentes_con_categoria TO rol_app_lectura;

-- Pedidos con datos del cliente (excluye contrasenia por diseño de la vista)
GRANT SELECT ON v_pedidos_con_cliente TO rol_app_lectura;


-- =============================================================================
-- SECCIÓN 5 — PRIVILEGIOS DE rol_app_escritura
-- Flujo de compra: crear y actualizar pedidos y sus detalles.
-- =============================================================================

-- Tabla pedidos: lectura (verificar estado), creación y actualización
GRANT SELECT, INSERT, UPDATE ON pedidos TO rol_app_escritura;

-- Tabla detalle_pedido: lectura, creación y actualización de renglones
GRANT SELECT, INSERT, UPDATE ON detalle_pedido TO rol_app_escritura;

-- Tabla productos: lectura de datos del producto y actualización de stock
-- (sp_crear_pedido hace SELECT ... FOR UPDATE y UPDATE sobre stock)
GRANT SELECT, UPDATE ON productos TO rol_app_escritura;

-- Tabla clientes: solo lectura de id y eliminado para validar existencia
-- (permiso a nivel de columna: ni contrasenia ni datos personales)
GRANT SELECT (id, eliminado) ON clientes TO rol_app_escritura;

-- Secuencias: necesarias para que INSERT genere IDs (GENERATED ALWAYS AS IDENTITY)
GRANT USAGE ON SEQUENCE pedidos_id_seq        TO rol_app_escritura;
GRANT USAGE ON SEQUENCE detalle_pedido_id_seq TO rol_app_escritura;

-- Procedimientos del flujo de compra
GRANT EXECUTE ON PROCEDURE sp_crear_pedido(BIGINT, forma_pago, JSONB, BIGINT) TO rol_app_escritura;
GRANT EXECUTE ON PROCEDURE sp_cambiar_estado_pedido(BIGINT, estado_pedido)     TO rol_app_escritura;

-- REVOKE explícito de operaciones destructivas
-- (defensa en profundidad: aunque rol_soporte es NOLOGIN y no tiene estos
-- permisos, se revoca formalmente para coherencia con el principio de
-- mínimo privilegio y auditoría futura)
REVOKE DELETE, TRUNCATE ON pedidos        FROM rol_app_escritura;
REVOKE DELETE, TRUNCATE ON detalle_pedido FROM rol_app_escritura;
REVOKE DELETE, TRUNCATE ON clientes        FROM rol_soporte;


-- =============================================================================
-- SECCIÓN 6 — PRIVILEGIOS DE rol_soporte
-- Atención al cliente: datos básicos de clientes (sin contrasenia) y pedidos.
-- =============================================================================

-- Permiso A NIVEL DE COLUMNA sobre clientes:
-- soporte puede leer identificación básica, pero NUNCA la contraseña.
-- Este es el ejemplo de permiso por columna requerido por la consigna.
GRANT SELECT (id, nombre, apellido, mail, celular, rol)
    ON clientes TO rol_soporte;

-- Vista de pedidos con datos del cliente (la vista ya excluye contrasenia)
GRANT SELECT ON v_pedidos_con_cliente        TO rol_soporte;

-- Vista de detalle de pedido para asistir consultas sobre líneas de compra
GRANT SELECT ON v_detalle_pedido_con_producto TO rol_soporte;


-- =============================================================================
-- SECCIÓN 7 — PRIVILEGIOS DE rol_reportes
-- Lectura analítica y gerencial. Solo vistas y vista materializada,
-- nunca tablas base directamente.
-- =============================================================================

-- Vista materializada de facturación por categoría y mes (reporte ejecutivo)
GRANT SELECT ON mv_facturacion_categoria_mes          TO rol_reportes;

-- Vistas operativas disponibles para análisis
GRANT SELECT ON v_productos_vigentes_con_categoria    TO rol_reportes;
GRANT SELECT ON v_detalle_pedido_con_producto         TO rol_reportes;

-- Función analítica de ranking de productos por categoría
GRANT EXECUTE ON FUNCTION fn_ranking_productos_categoria(INTEGER) TO rol_reportes;


-- =============================================================================
-- SECCIÓN 8 — MEMBRESÍAS (jerarquía de roles)
-- Los roles de login heredan los permisos de los roles de grupo.
-- =============================================================================

-- app_web = lectura de catálogo + escritura de pedidos
GRANT rol_app_lectura   TO app_web;
GRANT rol_app_escritura TO app_web;

-- admin_datos no hereda roles de aplicación:
-- su función es administrar el esquema, no operar la tienda.


-- =============================================================================
-- SECCIÓN 9 — ALTER DEFAULT PRIVILEGES
-- Las tablas futuras creadas por admin_datos en public heredan SELECT
-- automáticamente para rol_reportes. Evita olvidar el GRANT manual.
-- =============================================================================

ALTER DEFAULT PRIVILEGES FOR ROLE admin_datos IN SCHEMA public
    GRANT SELECT ON TABLES TO rol_reportes;


-- =============================================================================
-- SECCIÓN 10 — VERIFICACIÓN (ejecutar separado para revisar el estado)
-- =============================================================================

-- Ver todos los roles del servidor:
-- \du

-- Ver qué privilegios tiene cada rol sobre las tablas del esquema:
-- SELECT grantee, table_name, privilege_type
-- FROM information_schema.role_table_grants
-- WHERE table_schema = 'public'
-- ORDER BY grantee, table_name, privilege_type;

-- Ver membresías:
-- SELECT r.rolname AS rol, m.rolname AS miembro
-- FROM pg_roles r
-- JOIN pg_auth_members am ON am.roleid = r.oid
-- JOIN pg_roles m ON m.oid = am.member
-- WHERE r.rolname IN ('rol_app_lectura','rol_app_escritura','rol_soporte','rol_reportes')
-- ORDER BY 1, 2;

-- Ver permisos a nivel de columna (solo aparecen en column_privileges):
-- SELECT grantee, table_name, column_name, privilege_type
-- FROM information_schema.role_column_grants
-- WHERE table_schema = 'public' AND grantee = 'rol_soporte'
-- ORDER BY table_name, column_name;
