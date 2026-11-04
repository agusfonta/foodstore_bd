-- =========================================================
-- U4 · Parte 2 — Mediciones (5.2.a y 5.2.d) y auditoría de sincronía (5.2.e)
-- Se corre después de tp_desnormalizacion_top_categorias.sql (que crea mv_top_categorias_dia).
-- Solo lee datos. Se toma del informe docs/informes/informe_u4_fnbc_desnormalizacion.pdf.
-- =========================================================

-- ANTES (5.2.a): consulta sobre las tablas normalizadas
EXPLAIN ANALYZE
SELECT c.nombre AS categoria, SUM(dp.subtotal) AS total_vendido
FROM detalle_pedido dp
JOIN productos pr ON pr.id = dp.producto_id
JOIN categorias c ON c.id = pr.categoria_id
JOIN pedidos ped ON ped.id = dp.pedido_id
WHERE ped.fecha::date = NOW()::date
  AND ped.eliminado = FALSE
GROUP BY c.nombre
ORDER BY total_vendido DESC
LIMIT 5;

-- DESPUÉS (5.2.d): misma consulta leyendo la vista materializada
EXPLAIN ANALYZE
SELECT categoria, total_vendido
FROM mv_top_categorias_dia
WHERE fecha = CURRENT_DATE
ORDER BY total_vendido DESC
LIMIT 5;

-- AUDITORÍA (5.2.e): debe devolver 0 filas si la vista no se desincronizó
SELECT mv.categoria, mv.fecha,
       mv.total_vendido AS total_almacenado,
       real.total_real,
       (mv.total_vendido - real.total_real) AS diferencia
FROM mv_top_categorias_dia mv
JOIN (
    SELECT c.nombre AS categoria, ped.fecha::date AS fecha, SUM(dp.subtotal) AS total_real
    FROM detalle_pedido dp
    JOIN productos pr ON pr.id = dp.producto_id
    JOIN categorias c ON c.id = pr.categoria_id
    JOIN pedidos ped ON ped.id = dp.pedido_id
    WHERE ped.eliminado = FALSE
    GROUP BY c.nombre, ped.fecha::date
) real ON real.categoria = mv.categoria AND real.fecha = mv.fecha
WHERE mv.total_vendido <> real.total_real;
