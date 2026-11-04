-- U7 · Parte 2 · Consigna 5: consultas equivalentes a b) y c) en PostgreSQL (foodstore_desarrollo).
-- Solo lectura. Uso: psql -U postgres -d foodstore_desarrollo -f mongodb/consultas_postgresql.sql
-- Mongo solo tiene los pedidos 1..10, por eso se acota con id BETWEEN 1 AND 10 para comparar lo mismo.

-- b) pedidos en estado CONFIRMADO (subconjunto migrado)
SELECT count(*) AS cantidad, array_agg(id ORDER BY id) AS ids
FROM pedidos
WHERE estado = 'CONFIRMADO' AND NOT eliminado AND id BETWEEN 1 AND 10;

-- c) pedidos que contienen el producto 6 (EXISTS evita duplicar un pedido por join)
SELECT count(*) AS cantidad, array_agg(p.id ORDER BY p.id) AS ids
FROM pedidos p
WHERE NOT p.eliminado AND p.id BETWEEN 1 AND 10
  AND EXISTS (SELECT 1 FROM detalle_pedido d WHERE d.pedido_id = p.id AND d.producto_id = 6);

-- Apoyo: sin acotar al subconjunto, la base completa devuelve muchos mas pedidos (no migrados).
SELECT count(*) AS cantidad_total_base FROM pedidos WHERE estado = 'CONFIRMADO' AND NOT eliminado;
SELECT count(DISTINCT pedido_id) AS cantidad_total_base FROM detalle_pedido WHERE producto_id = 6;
