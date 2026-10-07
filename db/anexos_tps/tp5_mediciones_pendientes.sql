-- =====================================================================
-- TP 5 - Mediciones pendientes para completar el informe
-- Correr en DBeaver sobre la COPIA de trabajo (nunca producción).
-- Cada bloque BEGIN ... ROLLBACK deja la base como estaba.
-- Anotar siempre el "Execution Time" y usar la MEDIANA de las repeticiones.
-- =====================================================================

-- 0) Qué índices existen hoy (para saber desde dónde se mide)
SELECT tablename, indexname, indexdef
FROM pg_indexes
WHERE tablename IN ('pedidos', 'detalle_pedido', 'productos')
ORDER BY tablename, indexname;

VACUUM ANALYZE pedidos;
VACUUM ANALYZE detalle_pedido;
VACUUM ANALYZE productos;


-- =====================================================================
-- 1) CONSULTA 1 - Medición de control: ¿los índices cambian algo?
--    Ejecutar cada EXPLAIN 3 veces seguidas (Ctrl+Enter) y anotar la mediana.
-- =====================================================================

-- 1.a) SIN los índices propuestos (se borran dentro de la transacción)
BEGIN;
DROP INDEX IF EXISTS idx_pedidos_volumen_venta;
DROP INDEX IF EXISTS idx_detalle_pedido_agg_ventas;

EXPLAIN ANALYZE
SELECT pr.id, pr.nombre,
       SUM(dp.cantidad) AS unidades_vendidas,
       SUM(dp.subtotal) AS total_vendido
FROM detalle_pedido dp
JOIN pedidos p    ON p.id = dp.pedido_id
JOIN productos pr ON pr.id = dp.producto_id
WHERE p.estado IN ('CONFIRMADO', 'TERMINADO')
  AND p.eliminado = FALSE
  AND pr.eliminado = FALSE
GROUP BY pr.id, pr.nombre
ORDER BY total_vendido DESC;
ROLLBACK;

-- 1.b) CON los índices propuestos (se crean dentro de la transacción)
BEGIN;
CREATE INDEX IF NOT EXISTS idx_pedidos_volumen_venta
  ON pedidos (estado, eliminado)
  WHERE estado IN ('CONFIRMADO', 'TERMINADO') AND eliminado = FALSE;
CREATE INDEX IF NOT EXISTS idx_detalle_pedido_agg_ventas
  ON detalle_pedido (pedido_id, producto_id) INCLUDE (cantidad, subtotal);
ANALYZE pedidos;
ANALYZE detalle_pedido;

EXPLAIN ANALYZE
SELECT pr.id, pr.nombre,
       SUM(dp.cantidad) AS unidades_vendidas,
       SUM(dp.subtotal) AS total_vendido
FROM detalle_pedido dp
JOIN pedidos p    ON p.id = dp.pedido_id
JOIN productos pr ON pr.id = dp.producto_id
WHERE p.estado IN ('CONFIRMADO', 'TERMINADO')
  AND p.eliminado = FALSE
  AND pr.eliminado = FALSE
GROUP BY pr.id, pr.nombre
ORDER BY total_vendido DESC;
-- Mirar si en el plan aparece "Index" sobre pedidos o detalle_pedido.
-- Si sigue diciendo "Parallel Seq Scan", el índice no se usa.
ROLLBACK;


-- =====================================================================
-- 2) CONSULTA 3 - Variante covering completa (INCLUDE con id)
-- =====================================================================
BEGIN;
DROP INDEX IF EXISTS idx_pedidos_historial_cliente;
CREATE INDEX idx_pedidos_historial_cliente
  ON pedidos (cliente_id, fecha DESC)
  INCLUDE (id, estado, forma_pago, total)
  WHERE eliminado = FALSE;
ANALYZE pedidos;

EXPLAIN ANALYZE
SELECT id, fecha, estado, forma_pago, total
FROM pedidos
WHERE cliente_id = 5 AND eliminado = FALSE
ORDER BY fecha DESC;
-- Esperado: Index Only Scan ... Heap Fetches: 0, sin nodo Sort.
-- Si Heap Fetches > 0: correr VACUUM pedidos (fuera de la transacción) y repetir.
ROLLBACK;   -- cambiar por COMMIT si se decide quedarse con esta variante


-- =====================================================================
-- 3) IMPACTO EN INSERCIÓN - lote de 50.000 filas en detalle_pedido
--    Ejecutar el bloque 3.a 5 veces y el 3.b 5 veces. Anotar la mediana del
--    Execution Time del EXPLAIN ANALYZE del INSERT (el que se mide).
--    EXPLAIN ANALYZE sobre un INSERT lo ejecuta de verdad; el ROLLBACK lo deshace.
-- =====================================================================

-- 3.a) SIN idx_detalle_pedido_agg_ventas
BEGIN;
DROP INDEX IF EXISTS idx_detalle_pedido_agg_ventas;

-- 10.000 pedidos nuevos (padres de la FK, no se miden)
INSERT INTO pedidos (cliente_id, estado, forma_pago, total, fecha)
SELECT 1 + (gs % 20000), 'CONFIRMADO', 'TARJETA', 0, now()
FROM generate_series(1, 10000) AS gs;

-- MEDIDO: 50.000 detalles (5 por pedido)
EXPLAIN ANALYZE
INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, precio_unitario, subtotal)
SELECT p.id, 1 + (((p.id * 7) + g) % 50000), 2, 50.00, 100.00
FROM pedidos p
CROSS JOIN LATERAL generate_series(1, 5) AS g
WHERE p.id > (SELECT max(id) FROM pedidos) - 10000;
ROLLBACK;

-- 3.b) CON idx_detalle_pedido_agg_ventas
BEGIN;
CREATE INDEX IF NOT EXISTS idx_detalle_pedido_agg_ventas
  ON detalle_pedido (pedido_id, producto_id) INCLUDE (cantidad, subtotal);

INSERT INTO pedidos (cliente_id, estado, forma_pago, total, fecha)
SELECT 1 + (gs % 20000), 'CONFIRMADO', 'TARJETA', 0, now()
FROM generate_series(1, 10000) AS gs;

EXPLAIN ANALYZE
INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, precio_unitario, subtotal)
SELECT p.id, 1 + (((p.id * 7) + g) % 50000), 2, 50.00, 100.00
FROM pedidos p
CROSS JOIN LATERAL generate_series(1, 5) AS g
WHERE p.id > (SELECT max(id) FROM pedidos) - 10000;
ROLLBACK;


-- =====================================================================
-- 4) DECISIÓN FINAL (ejecutar solo después de completar el informe)
--    Índices descartados: el planner no los usa y cuestan en cada INSERT.
-- =====================================================================
-- DROP INDEX IF EXISTS idx_detalle_pedido_agg_ventas;
-- DROP INDEX IF EXISTS idx_pedidos_volumen_venta;
