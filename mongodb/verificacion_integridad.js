// U7 · Consigna 3: verifica en MongoDB las reglas de integridad de PostgreSQL.
// Uso: mongosh --quiet mongodb/verificacion_integridad.js
const col = db.getSiblingDB('foodstore_u7').pedidos;

// Regla 1: total del pedido = suma de subtotales; subtotal = cantidad * precio_unitario.
print('R1a pedidos con total != suma de subtotales:',
  col.countDocuments({ $expr: { $ne: ['$total', { $sum: '$lineas.subtotal' }] } }));
print('R1b lineas con subtotal != cantidad*precio:',
  col.aggregate([{ $unwind: '$lineas' },
    { $match: { $expr: { $ne: ['$lineas.subtotal', { $multiply: ['$lineas.cantidad', '$lineas.precio_unitario'] }] } } },
    { $count: 'n' }]).toArray().length);

// Regla 2: cantidad > 0 y un solo renglon por producto dentro de cada pedido.
print('R2a lineas con cantidad <= 0:', col.countDocuments({ lineas: { $elemMatch: { cantidad: { $lte: 0 } } } }));
print('R2b pedidos con producto repetido:',
  col.countDocuments({ $expr: { $ne: [{ $size: '$lineas.producto_id' }, { $size: { $setUnion: ['$lineas.producto_id', []] } }] } }));
