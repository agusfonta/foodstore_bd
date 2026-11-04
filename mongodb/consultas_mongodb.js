// U7 · Parte 2 · Consigna 4: consultas en MongoDB sobre foodstore_u7.pedidos
// Uso: mongosh --quiet mongodb/consultas_mongodb.js
const col = db.getSiblingDB('foodstore_u7').pedidos;
const ids = (cur) => cur.toArray().map(d => d._id);

print('--- a) todos los pedidos (id y estado)');
printjson(col.find({}, { estado: 1 }).sort({ _id: 1 }).toArray());

print('--- b) pedidos en estado CONFIRMADO');
const b = ids(col.find({ estado: 'CONFIRMADO' }, { _id: 1 }).sort({ _id: 1 }));
print('cantidad:', b.length, '| ids:', JSON.stringify(b));

print('--- c) pedidos que contienen el producto_id 6');
const c = ids(col.find({ 'lineas.producto_id': 6 }, { _id: 1 }).sort({ _id: 1 }));
print('cantidad:', c.length, '| ids:', JSON.stringify(c));

// Umbral: el promedio de totales de los pedidos migrados (ver consulta de apoyo).
print('--- apoyo d) promedio de total');
const prom = col.aggregate([{ $group: { _id: null, prom: { $avg: '$total' } } }]).toArray()[0].prom;
print('promedio:', prom.toString());

print('--- d) pedidos con total > 2134.07 (aprox. el promedio)');
const d = ids(col.find({ total: { $gt: Decimal128.fromString('2134.07') } }, { _id: 1 }).sort({ _id: 1 }));
print('cantidad:', d.length, '| ids:', JSON.stringify(d));
