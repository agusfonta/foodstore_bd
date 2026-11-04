-- =============================================================================
-- VISTAS DE REPORTES - Base de datos foodstore (PostgreSQL 17)
-- =============================================================================
-- REGLA DE SEGURIDAD GLOBAL: ninguna vista expone clientes.contrasenia,
-- clientes.rol, ni columnas de auditoría interna (created_at, updated_at,
-- deleted_at) de ninguna tabla.
-- =============================================================================


-- =============================================================================
-- VISTA 1: v_productos_vigentes_con_categoria
-- Objetivo: productos vigentes (no eliminados lógicamente) junto con el nombre
--           de su categoría, también vigente.
-- Filtro de vigencia: doble borrado lógico del proyecto → eliminado = FALSE
--                     AND deleted_at IS NULL en ambas tablas.
-- =============================================================================

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
-- Vigencia producto: se excluyen registros marcados como eliminados
-- o con fecha de borrado lógico registrada.
WHERE p.eliminado = FALSE
  AND p.deleted_at IS NULL
-- Vigencia categoría: ídem para la categoría asociada.
  AND c.eliminado = FALSE
  AND c.deleted_at IS NULL;


-- =============================================================================
-- VISTA 2: v_pedidos_con_cliente
-- Objetivo: pedidos vigentes con los datos identificatorios del cliente,
--           para uso en reportes y dashboards.
-- Filtro de vigencia: pedido vigente Y cliente vigente.
-- SEGURIDAD: se omiten clientes.contrasenia, clientes.rol y todas las
--            columnas de auditoría (created_at, updated_at, deleted_at).
-- =============================================================================

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
    -- NOTA DE SEGURIDAD: cl.contrasenia, cl.rol, cl.created_at,
    -- cl.updated_at y cl.deleted_at se excluyen deliberadamente.
FROM pedidos pe
JOIN clientes cl ON cl.id = pe.cliente_id
-- Vigencia pedido.
WHERE pe.eliminado = FALSE
  AND pe.deleted_at IS NULL
-- Vigencia cliente.
  AND cl.eliminado = FALSE
  AND cl.deleted_at IS NULL;


-- =============================================================================
-- VISTA 3: v_detalle_pedido_con_producto
-- Objetivo: líneas de detalle de pedido con el nombre del producto asociado,
--           para desglosar el contenido de cada pedido.
-- Filtro de vigencia: detalle_pedido no tiene columnas eliminado/deleted_at;
--                     es una tabla histórica y no se filtra directamente.
--                     Se aplica vigencia únicamente sobre el producto asociado.
-- NOTA: si se necesita ver el historial completo incluyendo productos
--       dados de baja posteriormente, quitar la cláusula WHERE sobre pr.
-- =============================================================================

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
-- Vigencia producto: se muestran solo detalles cuyo producto sigue vigente.
-- Si se requiere el historial completo (incluyendo productos luego dados de
-- baja), comentar o eliminar las dos líneas siguientes.
WHERE pr.eliminado = FALSE
  AND pr.deleted_at IS NULL;


-- =============================================================================
-- SELECTS DE VERIFICACIÓN
-- =============================================================================

-- Verificación vista 1: primeras 20 filas de productos vigentes con categoría.
SELECT
    producto_id,
    producto_nombre,
    precio,
    stock,
    disponible,
    categoria_id,
    categoria_nombre
FROM v_productos_vigentes_con_categoria
ORDER BY categoria_nombre, producto_nombre
LIMIT 20;

-- Verificación vista 2: primeros 20 pedidos con datos de cliente.
SELECT
    pedido_id,
    fecha,
    estado,
    total,
    forma_pago,
    cliente_id,
    cliente_nombre,
    cliente_apellido,
    cliente_mail,
    cliente_celular
FROM v_pedidos_con_cliente
ORDER BY fecha DESC
LIMIT 20;

-- Verificación vista 3: primeras 20 líneas de detalle con nombre de producto.
SELECT
    pedido_id,
    detalle_id,
    producto_id,
    producto_nombre,
    cantidad,
    precio_unitario,
    subtotal
FROM v_detalle_pedido_con_producto
ORDER BY pedido_id, detalle_id
LIMIT 20;
