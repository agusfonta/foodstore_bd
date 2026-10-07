-- =============================================================================
-- VISTAS DE REPORTES - foodstore (PostgreSQL 17)
-- Archivo: vistas_reportes_prompt_propio.sql
-- SEGURIDAD: ninguna vista expone clientes.contrasenia ni datos sensibles.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- VISTA 1: v_productos_vigentes
-- Productos vigentes con el nombre de su categoría (también vigente).
-- Filtro: doble borrado lógico en productos y categorias.
-- -----------------------------------------------------------------------------

CREATE OR REPLACE VIEW v_productos_vigentes AS
SELECT
    p.id        AS id,
    p.nombre    AS nombre,
    p.precio    AS precio,
    p.stock     AS stock,
    c.nombre    AS categoria
FROM productos p
JOIN categorias c ON c.id = p.categoria_id
WHERE p.eliminado  = FALSE
  AND p.deleted_at IS NULL
  AND c.eliminado  = FALSE
  AND c.deleted_at IS NULL;


-- -----------------------------------------------------------------------------
-- VISTA 2: v_pedidos_clientes
-- Pedidos vigentes con datos identificatorios del cliente (sin contrasenia).
-- Filtro: borrado lógico en pedidos y clientes.
-- SEGURIDAD: cl.contrasenia excluida deliberadamente.
-- -----------------------------------------------------------------------------

CREATE OR REPLACE VIEW v_pedidos_clientes AS
SELECT
    pe.id          AS id,
    pe.fecha       AS fecha,
    pe.estado      AS estado,
    pe.total       AS total,
    pe.forma_pago  AS forma_pago,
    cl.nombre      AS nombre,
    cl.apellido    AS apellido,
    cl.mail        AS mail,
    cl.celular     AS celular
FROM pedidos pe
JOIN clientes cl ON cl.id = pe.cliente_id
WHERE pe.eliminado  = FALSE
  AND pe.deleted_at IS NULL
  AND cl.eliminado  = FALSE
  AND cl.deleted_at IS NULL;


-- -----------------------------------------------------------------------------
-- VISTA 3: v_detalle_pedido
-- Líneas de detalle con nombre del producto asociado.
-- detalle_pedido no tiene borrado lógico; el filtro de vigencia aplica
-- solo sobre el producto. Para ver histórico completo (incluyendo productos
-- dados de baja), quitar el WHERE sobre pr.
-- -----------------------------------------------------------------------------

CREATE OR REPLACE VIEW v_detalle_pedido AS
SELECT
    dp.pedido_id        AS pedido_id,
    dp.producto_id      AS producto_id,
    pr.nombre           AS producto,
    dp.cantidad         AS cantidad,
    dp.precio_unitario  AS precio_unitario,
    dp.subtotal         AS subtotal
FROM detalle_pedido dp
JOIN productos pr ON pr.id = dp.producto_id
WHERE pr.eliminado  = FALSE
  AND pr.deleted_at IS NULL;
