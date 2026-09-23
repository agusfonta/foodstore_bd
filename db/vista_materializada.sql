-- =========================================================
-- FOODSTORE - PostgreSQL
-- Vista Materializada: Facturación por Categoría y Mes
-- =========================================================
-- Reporte elegido: facturación por categoría y mes.
--
-- ¿Por qué es costoso sin materializar?
--   La consulta base requiere un JOIN de cuatro tablas
--   (detalle_pedido → pedidos → productos → categorias),
--   filtra por estado y borrado lógico, agrupa con DATE_TRUNC
--   y calcula SUM sobre potencialmente millones de filas de
--   detalle_pedido. Cada vez que un dashboard o informe la
--   ejecuta, el motor repite todo ese trabajo.
--
-- Solución: persistir el resultado en una vista materializada
--   y refrescarla periódicamente (p. ej. con pg_cron o manualmente).
--   El índice UNIQUE sobre (categoria_id, mes) habilita
--   REFRESH CONCURRENTLY, que actualiza sin bloquear lecturas.
-- =========================================================

-- ---------------------------------------------------------
-- PASO 1 (Seguridad): asegurarse de trabajar sobre la copia
--   de desarrollo antes de ejecutar en producción:
--
--   createdb -T foodstore foodstore_desarrollo
--   \c foodstore_desarrollo
-- ---------------------------------------------------------

-- ---------------------------------------------------------
-- PASO 2: Crear la vista materializada con WITH DATA
--   (WITH DATA ejecuta la consulta inmediatamente y persiste
--   las filas; usar WITH NO DATA solo si se quiere diferir
--   la primera carga)
-- ---------------------------------------------------------

CREATE MATERIALIZED VIEW mv_facturacion_categoria_mes AS
SELECT
    c.id                            AS categoria_id,
    c.nombre                        AS categoria,
    DATE_TRUNC('month', p.fecha)    AS mes,          -- truncado al 1er día del mes
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
GROUP BY
    c.id,
    c.nombre,
    DATE_TRUNC('month', p.fecha)
WITH DATA;   -- ejecuta la consulta y materializa las filas al crear

-- ---------------------------------------------------------
-- PASO 3: Índice UNIQUE sobre (categoria_id, mes)
--   Requisito obligatorio para poder usar REFRESH CONCURRENTLY.
--   La combinación (categoria_id, mes) identifica de forma
--   única cada fila del resultado (un mismo mes no puede
--   tener dos filas para la misma categoría).
-- ---------------------------------------------------------

CREATE UNIQUE INDEX uix_mv_facturacion_categoria_mes
    ON mv_facturacion_categoria_mes (categoria_id, mes);

-- Índice adicional de soporte para consultas que filtran
-- solo por mes (p. ej. reportes de un período específico):
CREATE INDEX idx_mv_facturacion_mes
    ON mv_facturacion_categoria_mes (mes DESC);

-- ---------------------------------------------------------
-- PASO 4: Verificar el contenido materializado
-- ---------------------------------------------------------

-- Ver primeras filas ordenadas por mes y total descendente:
-- SELECT * FROM mv_facturacion_categoria_mes
-- ORDER BY mes DESC, total_facturado DESC
-- LIMIT 20;

-- ---------------------------------------------------------
-- PASO 5: Refrescar la vista (cuando los datos base cambien)
-- ---------------------------------------------------------

-- Refresco CONCURRENTE (no bloquea lecturas en curso):
-- REFRESH MATERIALIZED VIEW CONCURRENTLY mv_facturacion_categoria_mes;
--
-- Refresco completo (bloquea la vista mientras actualiza,
-- usar solo en ventana de mantenimiento o la primera vez
-- si se creó con WITH NO DATA):
-- REFRESH MATERIALIZED VIEW mv_facturacion_categoria_mes;

-- ---------------------------------------------------------
-- PASO 6 (Rollback de seguridad)
-- Para deshacer todo en caso de error:
--
--   DROP MATERIALIZED VIEW IF EXISTS mv_facturacion_categoria_mes;
--   -- (el DROP de la vista elimina sus índices automáticamente)
-- ---------------------------------------------------------
