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




