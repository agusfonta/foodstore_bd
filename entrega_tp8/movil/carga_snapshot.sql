-- ============================================
-- CARGA DE LA INSTANTÁNEA - TP8 (consigna 2.a)
-- ============================================
-- Importa servidor_snapshot.csv (exportado de v_snapshot_movil) en
-- snapshot_servidor y con esa tabla carga/actualiza producto_cache.
-- Cada carga reemplaza la instantánea anterior; las filas dadas de baja
-- (eliminado = 1) NO se borran de producto_cache: viajan como lápidas.
--
-- Uso (desde la carpeta movil/):
--   sqlite3 foodstore_movil.db ".read carga_snapshot.sql"
-- ============================================

-- snapshot_servidor la crea schema_sqlite.sql (ejecutarlo antes).
DELETE FROM snapshot_servidor;

.import --csv --skip 1 servidor_snapshot.csv snapshot_servidor

INSERT INTO producto_cache (id, nombre, precio_centavos, stock_visto, disponible, eliminado, fecha_copia)
SELECT id, nombre, precio_centavos, stock_visto, disponible, eliminado, fecha_copia
FROM snapshot_servidor
WHERE true
ON CONFLICT(id) DO UPDATE SET
    nombre          = excluded.nombre,
    precio_centavos = excluded.precio_centavos,
    stock_visto     = excluded.stock_visto,
    disponible      = excluded.disponible,
    eliminado       = excluded.eliminado,
    fecha_copia     = excluded.fecha_copia;

-- Control: cantidad de productos cargados y fecha de la copia
SELECT COUNT(*) AS productos_en_cache, MAX(fecha_copia) AS fecha_de_la_copia FROM producto_cache;
