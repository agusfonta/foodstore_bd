-- =============================================================================
-- PARTE B — VISTAS PARA LOS REPORTES DEL SISTEMA (entregable)
-- Archivo: db/views.sql — NO BORRA ni reemplaza los archivos previos:
--   db/vistas_reportes_prompt_opencode.sql (versión OpenCode, completa)
--   db/vistas_reportes_prompt_propio.sql   (versión estudiante, manual)
-- Este archivo consolida las 3 vistas DEFINITIVAS validadas, tomando como base
-- la versión OpenCode (más completa en columnas) porque la verificación de
-- equivalencia demostró que ambas devuelven el mismo conjunto de filas sobre
-- las columnas comunes (ver docs/bitacora_verificacion_vistas_parteB.md).
-- Base: foodstore, PostgreSQL 17. Ejecutar sobre foodstore_desarrollo.
-- Protocolo previo (no ejecutar vistas sobre foodstore original):
--   createdb -U postgres -h localhost -p 5432 -T foodstore foodstore_desarrollo
--   pg_dump -U postgres -h localhost -p 5432 -d foodstore_desarrollo --schema-only -F c -v -f ".\backups\respaldo_esquema_views.backup"
-- =============================================================================
-- REGLA DE SEGURIDAD GLOBAL: ninguna vista expone clientes.contrasenia,
-- clientes.rol, ni columnas de auditoría (created_at, updated_at, deleted_at).
-- La Vista 2 implementa el criterio de seguridad de la teoría: expone usuario
-- sin contraseña para poder otorgar SELECT sobre la vista sin dar acceso
-- a la tabla base clientes.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- VISTA 1: productos vigentes con su categoría
-- Columnas: producto_id, producto_nombre, precio, stock, disponible,
--           categoria_id, categoria_nombre
-- Filtro vigencia (doble borrado lógico del proyecto):
--   p.eliminado = FALSE AND p.deleted_at IS NULL
--   AND c.eliminado = FALSE AND c.deleted_at IS NULL
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_productos_vigentes_con_categoria AS
SELECT
    p.id          AS producto_id,
    p.nombre      AS producto_nombre,
    p.precio      AS precio,
    p.stock       AS stock,
    p.disponible  AS disponible,
    c.id          AS categoria_id,
    c.nombre      AS categoria_nombre
FROM productos p
JOIN categorias c ON c.id = p.categoria_id
WHERE p.eliminado = FALSE
  AND p.deleted_at IS NULL
  AND c.eliminado = FALSE
  AND c.deleted_at IS NULL;

-- -----------------------------------------------------------------------------
-- VISTA 2: pedidos con los datos del usuario (CRITERIO DE SEGURIDAD)
-- Columnas: pedido_id, fecha, estado, total, forma_pago,
--           cliente_id, cliente_nombre, cliente_apellido, cliente_mail, cliente_celular
-- Filtro vigencia:
--   pe.eliminado = FALSE AND pe.deleted_at IS NULL
--   AND cl.eliminado = FALSE AND cl.deleted_at IS NULL
-- SEGURIDAD: cl.contrasenia EXCLUIDA deliberadamente. También se excluyen
-- cl.rol y columnas de auditoría. Permite GRANT SELECT ON esta vista
-- a rol_reportes sin dar SELECT sobre clientes.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_pedidos_con_cliente AS
SELECT
    pe.id               AS pedido_id,
    pe.fecha            AS fecha,
    pe.estado           AS estado,
    pe.total            AS total,
    pe.forma_pago       AS forma_pago,
    cl.id               AS cliente_id,
    cl.nombre           AS cliente_nombre,
    cl.apellido         AS cliente_apellido,
    cl.mail             AS cliente_mail,
    cl.celular          AS cliente_celular
    -- cl.contrasenia, cl.rol y auditoría excluidos por seguridad
FROM pedidos pe
JOIN clientes cl ON cl.id = pe.cliente_id
WHERE pe.eliminado = FALSE
  AND pe.deleted_at IS NULL
  AND cl.eliminado = FALSE
  AND cl.deleted_at IS NULL;

-- -----------------------------------------------------------------------------
-- VISTA 3: detalle de un pedido con el nombre del producto
-- Columnas: pedido_id, detalle_id, producto_id, producto_nombre,
--           cantidad, precio_unitario, subtotal
-- Filtro vigencia: detalle_pedido no tiene eliminado/deleted_at (tabla
-- histórica, no se filtra). Vigencia solo sobre producto asociado:
--   pr.eliminado = FALSE AND pr.deleted_at IS NULL
-- NOTA: para histórico completo (productos dados de baja después),
-- quitar el WHERE sobre pr.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_detalle_pedido_con_producto AS
SELECT
    dp.pedido_id        AS pedido_id,
    dp.id               AS detalle_id,
    pr.id               AS producto_id,
    pr.nombre           AS producto_nombre,
    dp.cantidad         AS cantidad,
    dp.precio_unitario  AS precio_unitario,
    dp.subtotal         AS subtotal
FROM detalle_pedido dp
JOIN productos pr ON pr.id = dp.producto_id
WHERE pr.eliminado = FALSE
  AND pr.deleted_at IS NULL;

-- -----------------------------------------------------------------------------
-- Patrón de seguridad de la teoría (ejecutar como admin, no como reporte):
-- REVOKE SELECT ON clientes FROM rol_reportes;
-- REVOKE SELECT ON pedidos FROM rol_reportes;
-- GRANT SELECT ON v_pedidos_con_cliente TO rol_reportes;
-- GRANT SELECT ON v_productos_vigentes_con_categoria TO rol_reportes;
-- GRANT SELECT ON v_detalle_pedido_con_producto TO rol_reportes;
-- -----------------------------------------------------------------------------
