// U7 · Paso 2: carga en MongoDB los pedidos exportados desde PostgreSQL.
// Uso: mongosh --quiet mongodb/migrar_pedidos.js   (desde la raiz del repo)
const fs = require('fs');
const dec = (s) => Decimal128.fromString(s);

const docs = fs.readFileSync('mongodb/datos/pedidos.jsonl', 'utf8')
  .split(/\r?\n/).filter(l => l.trim())
  .map(l => JSON.parse(l))
  .map(d => ({
    ...d,
    fecha: new Date(d.fecha),
    total: dec(d.total),
    lineas: d.lineas.map(x => ({ ...x, precio_unitario: dec(x.precio_unitario), subtotal: dec(x.subtotal) })),
  }));

const col = db.getSiblingDB('foodstore_u7').pedidos;
col.drop();
const r = col.insertMany(docs);
print('insertados:', Object.keys(r.insertedIds).length, '| en coleccion:', col.countDocuments());
