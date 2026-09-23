-- =========================================================
-- FOODSTORE - Benchmark: Consulta original vs Vista Materializada
-- =========================================================
-- OBJETIVO: Medir y comparar el tiempo de ejecución del reporte
--   "Facturación por categoría y mes" en sus dos formas:
--     A) Consulta original (recorre las 4 tablas en tiempo real)
--     B) Consulta sobre la vista materializada (lectura de snapshot)
--
-- CÓMO EJECUTAR:
--   psql -U postgres -d foodstore_desarrollo -f benchmark_vista_materializada.sql
--   (o pegar bloque por bloque en DBeaver / pgAdmin y anotar los tiempos)
--
-- REQUISITOS PREVIOS:
--   1. Base foodstore_desarrollo cargada con carga_masiva.sql
--   2. Vista mv_facturacion_categoria_mes ya creada (vista_materializada.sql)
--      Si aún no existe, ejecutar primero vista_materializada.sql
-- =========================================================

-- =========================================================
-- PASO 0: Verificaciones previas
-- =========================================================

-- Confirmar base de datos correcta (debe decir foodstore_desarrollo):
SELECT current_database() AS base_activa;

-- Confirmar que la vista materializada existe:
SELECT matviewname, ispopulated
FROM pg_matviews
WHERE matviewname = 'mv_facturacion_categoria_mes';

-- Confirmar volumen de datos (referencia para interpretar tiempos):
SELECT
    (SELECT COUNT(*) FROM detalle_pedido) AS filas_detalle_pedido,
    (SELECT COUNT(*) FROM pedidos)        AS filas_pedidos,
    (SELECT COUNT(*) FROM productos)      AS filas_productos,
    (SELECT COUNT(*) FROM categorias)     AS filas_categorias;

-- =========================================================
-- PASO 1: Limpiar caché del planificador entre mediciones
-- =========================================================
-- DISCARD ALL descarta planes cacheados y buffers de sesión,
-- garantizando que cada medición parta en condiciones iguales.

DISCARD ALL;

-- =========================================================
-- PASO 2: EXPLAIN ANALYZE — Consulta ORIGINAL (sin materializar)
-- =========================================================
-- BUFFERS: muestra hits de caché de páginas (shared hit/read).
-- ANALYZE:  ejecuta realmente la consulta y mide tiempos reales.
-- Repetir 3 veces y quedarse con la mediana de "Execution Time".

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT
    c.nombre                        AS categoria,
    DATE_TRUNC('month', p.fecha)    AS mes,
    SUM(dp.subtotal)                AS total_facturado,
    COUNT(DISTINCT p.id)            AS cantidad_pedidos,
    COUNT(DISTINCT dp.producto_id)  AS cantidad_productos_distintos
FROM detalle_pedido dp
JOIN pedidos    p  ON dp.pedido_id   = p.id
JOIN productos  pr ON dp.producto_id = pr.id
JOIN categorias c  ON pr.categoria_id = c.id
WHERE p.estado    IN ('CONFIRMADO', 'TERMINADO')
  AND p.eliminado  = FALSE
  AND pr.eliminado = FALSE
  AND c.eliminado  = FALSE
GROUP BY c.nombre, DATE_TRUNC('month', p.fecha)
ORDER BY mes DESC, total_facturado DESC;

-- → Anotar el valor de "Execution Time: X ms" (última línea del plan)

-- =========================================================
-- PASO 3: Limpiar caché nuevamente antes de la segunda medición
-- =========================================================

DISCARD ALL;

-- =========================================================
-- PASO 4: EXPLAIN ANALYZE — Consulta sobre la VISTA MATERIALIZADA
-- =========================================================

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT
    categoria,
    mes,
    total_facturado,
    cantidad_pedidos,
    cantidad_productos_distintos
FROM mv_facturacion_categoria_mes
ORDER BY mes DESC, total_facturado DESC;

-- → Anotar el valor de "Execution Time: X ms"

-- =========================================================
-- PASO 5: Medición con \timing (alternativa en psql interactivo)
-- =========================================================
-- Si ejecutás en psql, activá el cronómetro nativo:
--
--   \timing on
--
-- Luego pegá cada consulta individualmente:
--
-- -- Consulta ORIGINAL:
-- SELECT c.nombre AS categoria,
--        DATE_TRUNC('month', p.fecha) AS mes,
--        SUM(dp.subtotal) AS total_facturado,
--        COUNT(DISTINCT p.id) AS cantidad_pedidos,
--        COUNT(DISTINCT dp.producto_id) AS cantidad_productos_distintos
-- FROM detalle_pedido dp
-- JOIN pedidos    p  ON dp.pedido_id   = p.id
-- JOIN productos  pr ON dp.producto_id = pr.id
-- JOIN categorias c  ON pr.categoria_id = c.id
-- WHERE p.estado    IN ('CONFIRMADO', 'TERMINADO')
--   AND p.eliminado  = FALSE AND pr.eliminado = FALSE AND c.eliminado = FALSE
-- GROUP BY c.nombre, DATE_TRUNC('month', p.fecha)
-- ORDER BY mes DESC, total_facturado DESC;
--
-- -- Consulta sobre la VISTA MATERIALIZADA:
-- SELECT * FROM mv_facturacion_categoria_mes
-- ORDER BY mes DESC, total_facturado DESC;

-- =========================================================
-- PASO 6: Comparación rápida de planes (sin ejecutar)
-- =========================================================
-- EXPLAIN sin ANALYZE para ver el plan estimado y el costo total
-- sin pagar el tiempo de ejecución:

EXPLAIN
SELECT
    c.nombre AS categoria,
    DATE_TRUNC('month', p.fecha) AS mes,
    SUM(dp.subtotal) AS total_facturado
FROM detalle_pedido dp
JOIN pedidos    p  ON dp.pedido_id   = p.id
JOIN productos  pr ON dp.producto_id = pr.id
JOIN categorias c  ON pr.categoria_id = c.id
WHERE p.estado IN ('CONFIRMADO', 'TERMINADO')
  AND p.eliminado = FALSE AND pr.eliminado = FALSE AND c.eliminado = FALSE
GROUP BY c.nombre, DATE_TRUNC('month', p.fecha)
ORDER BY mes DESC, total_facturado DESC;

-- → Anotar "cost=X..Y" del nodo raíz (cost estimado total)

EXPLAIN
SELECT categoria, mes, total_facturado
FROM mv_facturacion_categoria_mes
ORDER BY mes DESC, total_facturado DESC;

-- → Anotar "cost=X..Y" del nodo raíz (debería ser órdenes de magnitud menor)

-- =========================================================
-- PASO 7 (opcional): Forzar lectura desde disco (cold cache)
-- =========================================================
-- Para simular una consulta "en frío" (sin páginas en shared_buffers),
-- ejecutar desde PowerShell como administrador antes de medir:
--
--   net stop postgresql-x64-17
--   net start postgresql-x64-17
--
-- Luego reconectar y ejecutar los pasos 2 y 4 nuevamente.
-- Esto elimina el efecto del caché de páginas de PostgreSQL.
-- =========================================================
