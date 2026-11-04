
CREATE MATERIALIZED VIEW mv_top_categorias_dia 
AS SELECT
c.nombre AS categoria, 
ped.fecha::date AS fecha, 
SUM(dp.subtotal) AS total_vendido 
FROM detalle_pedido dp 
JOIN productos pr ON pr.id = dp.producto_id 
JOIN categorias c ON c.id = pr.categoria_id 
JOIN pedidos ped ON ped.id = dp.pedido_id 
WHERE ped.eliminado = FALSE 
    GROUP BY c.nombre, ped.fecha::date;


CREATE UNIQUE INDEX ux_mv_top_cat_dia ON mv_top_categorias_dia (categoria, fecha); 


REFRESH MATERIALIZED VIEW CONCURRENTLY mv_top_categorias_dia;
