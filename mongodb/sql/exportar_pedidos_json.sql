-- U7 · Paso 2: exporta pedidos 1..10 de foodstore_desarrollo como un JSON por linea (JSONL).
-- Solo lectura. Importes como texto para no perder precision (se convierten a Decimal128 al cargar).
-- Uso: psql -U postgres -d foodstore_desarrollo -t -A -f mongodb/sql/exportar_pedidos_json.sql -o mongodb/datos/pedidos.jsonl
SELECT jsonb_build_object(
    '_id',        p.id,
    'fecha',      p.fecha,
    'estado',     p.estado,
    'total',      p.total::text,
    'forma_pago', p.forma_pago,
    'cliente',    jsonb_build_object('id', c.id, 'nombre', c.nombre, 'apellido', c.apellido, 'mail', c.mail),
    'lineas',     (SELECT jsonb_agg(jsonb_build_object(
                        'producto_id',     d.producto_id,
                        'nombre',          pr.nombre,
                        'cantidad',        d.cantidad,
                        'precio_unitario', d.precio_unitario::text,
                        'subtotal',        d.subtotal::text) ORDER BY d.id)
                   FROM detalle_pedido d JOIN productos pr ON pr.id = d.producto_id
                   WHERE d.pedido_id = p.id)
)
FROM pedidos p JOIN clientes c ON c.id = p.cliente_id
WHERE p.id BETWEEN 1 AND 10 AND NOT p.eliminado
ORDER BY p.id;
