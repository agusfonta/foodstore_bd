-- ============================================
-- v_snapshot_movil - TP8 (consigna 2.a)
-- ============================================
-- Base: PostgreSQL 17, SOLO sobre la copia de trabajo (nunca sobre foodstore).
--   createdb -U postgres -T foodstore foodstore_desarrollo
-- Antes de crear la vista (DDL): respaldo estructural
--   pg_dump -U postgres -d foodstore_desarrollo -F c -b -v -f respaldo_estructura.backup
-- Uso: psql -U postgres -d foodstore_desarrollo -f vista_snapshot.sql
-- ============================================

-- Precio en centavos (entero) y booleanos en 0/1. Las bajas lógicas NO se
-- filtran: viajan con eliminado = 1 (lápidas) para que la tablet se entere.
CREATE OR REPLACE VIEW v_snapshot_movil AS
SELECT p.id,
       p.nombre,
       CAST(ROUND(p.precio * 100) AS INTEGER)  AS precio_centavos,
       p.stock                                  AS stock_visto,
       CASE WHEN p.disponible THEN 1 ELSE 0 END AS disponible,
       CASE WHEN p.eliminado  THEN 1 ELSE 0 END AS eliminado,
       CURRENT_TIMESTAMP(0)                     AS fecha_copia
FROM productos p
WHERE p.id <= 10          -- productos de prueba
ORDER BY p.id;

-- Exportar la instantánea (en psql, desde la carpeta movil/ de la entrega):
--   \copy (SELECT * FROM v_snapshot_movil) TO 'servidor_snapshot.csv' CSV HEADER
-- Importarla en SQLite: ver movil/carga_snapshot.sql

-- ============================================
-- Verificación final de la consigna 2.c: PostgreSQL no cambió
-- Correr ANTES de los casos y DESPUÉS de simular; los valores deben coincidir.
-- (La tablet nunca escribe en el servidor.)
-- ============================================
SELECT (SELECT COUNT(*) FROM pedidos)                                    AS cantidad_pedidos,
       (SELECT COUNT(*) FROM detalle_pedido)                              AS cantidad_detalles,
       (SELECT SUM(stock) FROM productos WHERE id <= 10)                  AS stock_total_1_a_10,
       (SELECT SUM(precio) FROM productos WHERE id <= 10)                 AS suma_precios_1_a_10,
       (SELECT COUNT(*) FROM productos WHERE id <= 10 AND eliminado)      AS bajas_1_a_10,
       (SELECT md5(string_agg(id || ':' || precio || ':' || stock || ':' || eliminado,
                              ',' ORDER BY id))
          FROM productos WHERE id <= 10)                                  AS huella_productos_1_a_10;
