-- =========================================================
-- ÍNDICES PARA OPTIMIZAR CONSULTAS DE FACTURACIÓN Y RANKING
-- =========================================================

-- 1. Facturación por categoría y mes
-- ---------------------------------------------------------
-- Filtros en pedidos: estado + eliminado + fecha (para DATE_TRUNC)
CREATE INDEX idx_pedidos_estado_eliminado_fecha 
ON pedidos (estado, eliminado, fecha DESC)
WHERE estado IN ('CONFIRMADO', 'TERMINADO') AND eliminado = FALSE;

-- Join detalle_pedido -> pedidos (pedido_id) + filtro eliminado
CREATE INDEX idx_detalle_pedido_pedido_eliminado 
ON detalle_pedido (pedido_id)
INCLUDE (producto_id, subtotal);

-- Join productos -> categorias + filtros eliminado
CREATE INDEX idx_productos_categoria_eliminado 
ON productos (categoria_id, eliminado)
WHERE eliminado = FALSE;

-- Categorías no eliminadas
CREATE INDEX idx_categorias_eliminado_nombre 
ON categorias (eliminado, nombre)
WHERE eliminado = FALSE;

-- 2. Ranking de usuarios por gastos
-- ---------------------------------------------------------
-- Filtros en pedidos + join clientes
CREATE INDEX idx_pedidos_cliente_estado_eliminado_total 
ON pedidos (cliente_id, estado, eliminado, total)
WHERE estado IN ('CONFIRMADO', 'TERMINADO') AND eliminado = FALSE;

-- Clientes no eliminados
CREATE INDEX idx_clientes_eliminado_id_nombre_mail 
ON clientes (eliminado, id, nombre, apellido, mail)
WHERE eliminado = FALSE;

-- =========================================================
-- CONSULTAS OPTIMIZADAS (MISMA LÓGICA, MISMOS RESULTADOS)
-- =========================================================

-- 1. Facturación por categoría y mes
SELECT 
    c.nombre AS categoria,
    DATE_TRUNC('month', p.fecha) AS mes,
    SUM(dp.subtotal) AS total_facturado
FROM detalle_pedido dp
JOIN pedidos p ON dp.pedido_id = p.id
JOIN productos pr ON dp.producto_id = pr.id
JOIN categorias c ON pr.categoria_id = c.id
WHERE p.estado IN ('CONFIRMADO', 'TERMINADO')
  AND p.eliminado = FALSE
  AND pr.eliminado = FALSE
  AND c.eliminado = FALSE
GROUP BY c.nombre, DATE_TRUNC('month', p.fecha)
ORDER BY mes DESC, total_facturado DESC;

-- 2. Ranking de usuarios por gastos
SELECT 
    cl.id AS cliente_id,
    cl.nombre || ' ' || cl.apellido AS cliente,
    cl.mail,
    COUNT(p.id) AS cantidad_pedidos,
    SUM(p.total) AS total_gastado
FROM pedidos p
JOIN clientes cl ON p.cliente_id = cl.id
WHERE p.estado IN ('CONFIRMADO', 'TERMINADO')
  AND p.eliminado = FALSE
  AND cl.eliminado = FALSE
GROUP BY cl.id, cl.nombre, cl.apellido, cl.mail
ORDER BY total_gastado DESC, cantidad_pedidos DESC;