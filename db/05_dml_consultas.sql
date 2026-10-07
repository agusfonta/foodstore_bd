-- Facturación por categoría y mes 
SELECT c.nombre AS categoria,
      DATE_TRUNC('month', p.fecha) AS mes,
      SUM(dp.subtotal) AS total_facturado
FROM detalle_pedido dp
JOIN pedidos p        ON dp.pedido_id = p.id
JOIN productos pr     ON dp.producto_id = pr.id
JOIN categorias c     ON pr.categoria_id = c.id
WHERE p.estado IN ('CONFIRMADO', 'TERMINADO')
  AND p.eliminado = FALSE AND pr.eliminado = FALSE AND c.eliminado = FALSE
GROUP BY c.nombre, DATE_TRUNC('month', p.fecha)
ORDER BY mes DESC, total_facturado DESC;


-- Historial completo de compras de un cliente

SELECT id, fecha, estado, forma_pago, total
FROM pedidos
WHERE cliente_id = 5 AND eliminado = FALSE
ORDER BY fecha DESC;


-- Ranking de clientes por gasto 
SELECT cl.id, cl.nombre || ' ' || cl.apellido AS cliente, cl.mail,
      COUNT(p.id) AS cantidad_pedidos, SUM(p.total) AS total_gastado
FROM pedidos p
JOIN clientes cl ON p.cliente_id = cl.id
WHERE p.estado IN ('CONFIRMADO', 'TERMINADO')
  AND p.eliminado = FALSE AND cl.eliminado = FALSE
GROUP BY cl.id, cl.nombre, cl.apellido, cl.mail
ORDER BY total_gastado DESC, cantidad_pedidos DESC;



-- Ranking de productos dentro de cada categoría por precio 
SELECT p.id AS producto_id, p.nombre, c.nombre AS categoria, p.precio,
      RANK() OVER (PARTITION BY p.categoria_id ORDER BY p.precio DESC, p.id ASC) AS ranking
FROM productos p
JOIN categorias c ON c.id = p.categoria_id
WHERE p.eliminado = FALSE AND c.eliminado = FALSE
ORDER BY p.categoria_id, ranking;

-- Productos más caros que el promedio de su categoría 
SELECT p.id, p.nombre, p.precio, c.nombre AS categoria
FROM productos p
JOIN categorias c ON c.id = p.categoria_id
WHERE p.eliminado = FALSE AND c.eliminado = FALSE
  AND p.precio > (SELECT AVG(p2.precio)
                  FROM productos p2
                  WHERE p2.categoria_id = p.categoria_id AND p2.eliminado = FALSE)
ORDER BY p.id;

-- Detalle completo de un pedido 

SELECT dp.pedido_id, p.fecha, pr.nombre AS producto, dp.cantidad, dp.precio_unitario, dp.subtotal
FROM detalle_pedido dp
JOIN pedidos p   ON p.id = dp.pedido_id
JOIN productos pr ON pr.id = dp.producto_id
WHERE dp.pedido_id = 1;

-- Pedidos de un cliente filtrando por estado 
SELECT id, fecha, estado, forma_pago, total
FROM pedidos
WHERE cliente_id = 3 AND estado IN ('CONFIRMADO', 'TERMINADO') AND eliminado = FALSE
ORDER BY fecha DESC;


--  Reporte de cobranza por forma de pago

SELECT forma_pago, estado, COUNT(*) AS cantidad_pedidos, SUM(total) AS monto
FROM pedidos
WHERE eliminado = FALSE
GROUP BY forma_pago, estado
ORDER BY monto DESC;

-- Productos disponibles por categoría 
SELECT pr.id, pr.nombre, pr.precio, c.nombre AS categoria
FROM productos pr
JOIN categorias c ON c.id = pr.categoria_id
WHERE pr.eliminado = FALSE AND pr.disponible = TRUE AND c.eliminado = FALSE
ORDER BY c.nombre, pr.nombre;


-- Top productos más vendidos 

SELECT pr.id, pr.nombre, SUM(dp.cantidad) AS unidades_vendidas, SUM(dp.subtotal) AS ingresos
FROM detalle_pedido dp
JOIN pedidos p    ON p.id = dp.pedido_id
JOIN productos pr ON pr.id = dp.producto_id
WHERE p.estado IN ('CONFIRMADO', 'TERMINADO') AND p.eliminado = FALSE AND pr.eliminado = FALSE
GROUP BY pr.id, pr.nombre
ORDER BY unidades_vendidas DESC
LIMIT 10;

-- Ranking de productos con mas volumen de venta

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



-- =============================================================================
-- TPI «Food Store» - Primera entrega parcial - Objetivo 5 de la consigna:
-- "DML y consultas: uso de JOIN, funciones de agregacion, subconsultas,
--  GROUP BY/HAVING y funciones de ventana."
-- Las consultas de arriba cubren JOIN, SUM/COUNT/AVG, GROUP BY, subconsulta
-- correlacionada y RANK() OVER. Se agregan abajo las que faltaban: HAVING,
-- subconsultas con EXISTS, mas funciones de ventana y sentencias DML
-- (INSERT / UPDATE) probadas dentro de BEGIN ... ROLLBACK.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- GROUP BY + HAVING: clientes recurrentes (3 o mas pedidos CONFIRMADO/TERMINADO)
-- HAVING filtra GRUPOS ya agregados (WHERE filtra filas antes de agrupar).
-- -----------------------------------------------------------------------------
SELECT cl.id, cl.nombre || ' ' || cl.apellido AS cliente,
       COUNT(*) AS pedidos, SUM(p.total) AS total_gastado
FROM pedidos p
JOIN clientes cl ON cl.id = p.cliente_id
WHERE p.estado IN ('CONFIRMADO', 'TERMINADO')
  AND p.eliminado = FALSE AND cl.eliminado = FALSE
GROUP BY cl.id, cl.nombre, cl.apellido
HAVING COUNT(*) >= 3
ORDER BY total_gastado DESC
LIMIT 20;

-- -----------------------------------------------------------------------------
-- HAVING con agregado en la condicion: categorias cuyo ticket promedio por
-- renglon supera el promedio global de renglones (subconsulta escalar en HAVING)
-- -----------------------------------------------------------------------------
SELECT c.nombre AS categoria, ROUND(AVG(dp.subtotal), 2) AS subtotal_promedio
FROM detalle_pedido dp
JOIN productos  pr ON pr.id = dp.producto_id
JOIN categorias c  ON c.id  = pr.categoria_id
WHERE pr.eliminado = FALSE AND c.eliminado = FALSE
GROUP BY c.nombre
HAVING AVG(dp.subtotal) > (SELECT AVG(subtotal) FROM detalle_pedido)
ORDER BY subtotal_promedio DESC;

-- -----------------------------------------------------------------------------
-- Subconsulta con NOT EXISTS: productos vigentes que nunca se vendieron.
-- (Se usa NOT EXISTS y no NOT IN: NOT IN devuelve 0 filas si la subconsulta
--  tiene algun NULL, ver docs/informes/ejercicio_lectura_critica.md.)
-- -----------------------------------------------------------------------------
SELECT pr.id, pr.nombre, pr.stock
FROM productos pr
WHERE pr.eliminado = FALSE
  AND NOT EXISTS (SELECT 1 FROM detalle_pedido dp WHERE dp.producto_id = pr.id)
ORDER BY pr.id
LIMIT 20;

-- -----------------------------------------------------------------------------
-- Funcion de ventana LAG + SUM() OVER: facturacion mensual, variacion contra el
-- mes anterior y acumulado del periodo.
-- -----------------------------------------------------------------------------
WITH mensual AS (
    SELECT DATE_TRUNC('month', fecha) AS mes, SUM(total) AS facturado
    FROM pedidos
    WHERE estado IN ('CONFIRMADO', 'TERMINADO') AND eliminado = FALSE
    GROUP BY DATE_TRUNC('month', fecha)
)
SELECT mes,
       facturado,
       LAG(facturado) OVER (ORDER BY mes)                       AS mes_anterior,
       facturado - LAG(facturado) OVER (ORDER BY mes)           AS variacion,
       SUM(facturado) OVER (ORDER BY mes)                       AS acumulado
FROM mensual
ORDER BY mes;

-- -----------------------------------------------------------------------------
-- Funcion de ventana ROW_NUMBER() OVER (PARTITION BY ...): ultimo pedido vigente
-- de cada cliente (top-1 por grupo).
-- -----------------------------------------------------------------------------
SELECT cliente_id, id AS ultimo_pedido_id, fecha, estado, total
FROM (
    SELECT p.*, ROW_NUMBER() OVER (PARTITION BY p.cliente_id ORDER BY p.fecha DESC, p.id DESC) AS rn
    FROM pedidos p
    WHERE p.eliminado = FALSE
) t
WHERE rn = 1
ORDER BY cliente_id
LIMIT 20;

-- -----------------------------------------------------------------------------
-- DML: INSERT / UPDATE (probar SIEMPRE dentro de BEGIN ... ROLLBACK, ver
-- protocolo_seguridad.md). Las altas de pedidos NO se hacen con INSERT directo
-- sino con CALL sp_crear_pedido(...) (script 08), que mantiene stock y total.
-- -----------------------------------------------------------------------------
BEGIN;

-- INSERT con RETURNING: alta de un producto en una categoria existente
INSERT INTO productos (nombre, precio, stock, disponible, categoria_id)
SELECT 'Producto de prueba DML', 99.90, 10, TRUE, MIN(id) FROM categorias WHERE eliminado = FALSE
RETURNING id, nombre, precio, categoria_id;

-- UPDATE con subconsulta: aumento del 10 % a los productos vigentes de una categoria.
-- El historial no se altera: detalle_pedido.precio_unitario guarda el precio de cada venta.
UPDATE productos
SET precio = ROUND(precio * 1.10, 2), updated_at = CURRENT_TIMESTAMP
WHERE categoria_id = (SELECT MIN(id) FROM categorias WHERE eliminado = FALSE)
  AND eliminado = FALSE;
-- Revisar la cantidad de filas informada antes de decidir COMMIT.

-- UPDATE ... FROM: dejar no disponibles los productos sin stock
UPDATE productos pr
SET disponible = FALSE, updated_at = CURRENT_TIMESTAMP
FROM categorias c
WHERE c.id = pr.categoria_id AND c.eliminado = FALSE
  AND pr.stock = 0 AND pr.disponible = TRUE;

ROLLBACK;   -- cambiar por COMMIT solo tras verificar el impacto
