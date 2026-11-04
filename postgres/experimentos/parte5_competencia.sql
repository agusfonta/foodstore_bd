-- =====================================================================
-- TP Semana 3 - PARTE 5: Competencia de optimización
-- Consulta: listado de productos de una categoría, con filtro de precio
--           y orden por precio (consigna común de la cátedra).
--
-- Cómo correrlo (DBeaver): conectado a la COPIA de trabajo, NO a producción.
--   Ejecutar como script (Alt+X). Cada bloque BEGIN ... ROLLBACK prueba una
--   alternativa y la deshace, así cada medición arranca del mismo estado.
--   Cada EXPLAIN se corre 3 veces: anotar la MEDIANA del Execution Time.
--   Se compara SOLO Execution Time (tiempo real), nunca el cost.
-- =====================================================================

-- 0) Estadísticas y visibility map al día (necesario para Index Only Scan)
VACUUM ANALYZE producto;

-- ---------------------------------------------------------------------
-- 1) ANTES: sin ningún índice de apoyo.
--    Los índices creados en la Parte 2 se eliminan DENTRO de la
--    transacción y el ROLLBACK los devuelve: la copia queda igual.
-- ---------------------------------------------------------------------
BEGIN;
DROP INDEX IF EXISTS idx_producto_categoria_precio;
DROP INDEX IF EXISTS idx_producto_categoria;
DROP INDEX IF EXISTS idx_producto_precio;

EXPLAIN (ANALYZE, BUFFERS)
SELECT id_producto, nombre, precio
FROM producto
WHERE id_categoria = 26
  AND deleted_at IS NULL
  AND precio BETWEEN 1000 AND 2000
ORDER BY precio DESC;
-- (repetir la ejecución del EXPLAIN 2 veces más y anotar la mediana)
ROLLBACK;

-- ---------------------------------------------------------------------
-- 2) ALTERNATIVA A: índice simple por categoría
--    Ataca: el Seq Scan (filtra por id_categoria).
--    No ataca: el filtro de precio (queda como Filter) ni el Sort.
-- ---------------------------------------------------------------------
BEGIN;
DROP INDEX IF EXISTS idx_producto_categoria_precio;
DROP INDEX IF EXISTS idx_producto_categoria;
DROP INDEX IF EXISTS idx_producto_precio;
CREATE INDEX comp_a_categoria ON producto (id_categoria);
ANALYZE producto;

EXPLAIN (ANALYZE, BUFFERS)
SELECT id_producto, nombre, precio
FROM producto
WHERE id_categoria = 26
  AND deleted_at IS NULL
  AND precio BETWEEN 1000 AND 2000
ORDER BY precio DESC;
ROLLBACK;

-- ---------------------------------------------------------------------
-- 3) ALTERNATIVA B: índice parcial solo por precio
--    Ataca: el rango de precio y el orden.
--    Problema: el rango 1000-2000 abarca ~22% de TODA la tabla y la
--    categoría queda como Filter: se leen muchas filas para descartarlas.
-- ---------------------------------------------------------------------
BEGIN;
DROP INDEX IF EXISTS idx_producto_categoria_precio;
DROP INDEX IF EXISTS idx_producto_categoria;
DROP INDEX IF EXISTS idx_producto_precio;
CREATE INDEX comp_b_precio ON producto (precio DESC) WHERE deleted_at IS NULL;
ANALYZE producto;

EXPLAIN (ANALYZE, BUFFERS)
SELECT id_producto, nombre, precio
FROM producto
WHERE id_categoria = 26
  AND deleted_at IS NULL
  AND precio BETWEEN 1000 AND 2000
ORDER BY precio DESC;
ROLLBACK;

-- ---------------------------------------------------------------------
-- 4) ALTERNATIVA C: compuesto parcial (id_categoria, precio DESC)
--    (es el índice de la Parte 2). Igualdad primero, rango después:
--    ambos predicados entran en el Index Cond.
--    Pero id_producto y nombre NO están en el índice: hay que ir al heap,
--    y el planner puede elegir Bitmap Heap Scan + Sort.
-- ---------------------------------------------------------------------
BEGIN;
DROP INDEX IF EXISTS idx_producto_categoria_precio;
DROP INDEX IF EXISTS idx_producto_categoria;
DROP INDEX IF EXISTS idx_producto_precio;
CREATE INDEX comp_c_cat_precio ON producto (id_categoria, precio DESC)
  WHERE deleted_at IS NULL;
ANALYZE producto;

EXPLAIN (ANALYZE, BUFFERS)
SELECT id_producto, nombre, precio
FROM producto
WHERE id_categoria = 26
  AND deleted_at IS NULL
  AND precio BETWEEN 1000 AND 2000
ORDER BY precio DESC;
ROLLBACK;

-- ---------------------------------------------------------------------
-- 5) ALTERNATIVA D (candidata ganadora): C + INCLUDE (id_producto, nombre)
--    Índice "covering": todas las columnas del SELECT están en el índice
--    -> Index Only Scan (Heap Fetches: 0) y sin nodo Sort, porque el
--    índice ya entrega las filas ordenadas por precio DESC.
-- ---------------------------------------------------------------------
BEGIN;
DROP INDEX IF EXISTS idx_producto_categoria_precio;
DROP INDEX IF EXISTS idx_producto_categoria;
DROP INDEX IF EXISTS idx_producto_precio;
CREATE INDEX comp_d_cat_precio_cov ON producto (id_categoria, precio DESC)
  INCLUDE (id_producto, nombre)
  WHERE deleted_at IS NULL;
ANALYZE producto;

EXPLAIN (ANALYZE, BUFFERS)
SELECT id_producto, nombre, precio
FROM producto
WHERE id_categoria = 26
  AND deleted_at IS NULL
  AND precio BETWEEN 1000 AND 2000
ORDER BY precio DESC;
ROLLBACK;

-- ---------------------------------------------------------------------
-- 6) APLICAR la ganadora en la copia de trabajo (solo si la medición
--    confirmó que D fue la de menor Execution Time).
-- ---------------------------------------------------------------------
-- CREATE INDEX idx_producto_comp_cat_precio_cov ON producto (id_categoria, precio DESC)
--   INCLUDE (id_producto, nombre)
--   WHERE deleted_at IS NULL;
-- VACUUM ANALYZE producto;
