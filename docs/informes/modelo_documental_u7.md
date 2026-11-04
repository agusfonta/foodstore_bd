# Modelo documental de «pedidos y detalle de pedidos» (consignas 1 y 3)

## Consigna 1: tablas de origen y colección propuesta

**Tablas de PostgreSQL que intervienen**

| Tabla | Clave primaria | Claves foráneas | Campos usados |
| :--- | :--- | :--- | :--- |
| `pedidos` | `id` | `cliente_id` → `clientes.id` | `fecha`, `estado`, `total`, `forma_pago` |
| `detalle_pedido` | `id` | `pedido_id` → `pedidos.id`, `producto_id` → `productos.id` | `cantidad`, `precio_unitario`, `subtotal` |
| `clientes` | `id` | | `nombre`, `apellido`, `mail` |
| `productos` | `id` | | `nombre` |

**Colección `foodstore_u7.pedidos`**

```js
{
  _id: 3,                          // = pedidos.id
  fecha: ISODate("2026-09-01T..."),
  estado: "CANCELADO",             // CONFIRMADO | PENDIENTE | TERMINADO | CANCELADO
  total: Decimal128("4740.69"),
  forma_pago: "EFECTIVO",
  cliente: {                       // objeto embebido (copia de datos esenciales)
    id: 3, nombre: "...", apellido: "...", mail: "..."
  },
  lineas: [                        // arreglo embebido (= filas de detalle_pedido)
    { producto_id: 5, nombre: "Producto_5", cantidad: 5,
      precio_unitario: Decimal128("498.71"), subtotal: Decimal128("2493.55") }
  ]
}
```

| Elemento | Detalle |
| :--- | :--- |
| Identificadores conservados | `_id` = `pedidos.id`; `cliente.id` = `clientes.id`; `lineas[].producto_id` = `productos.id` |
| Objeto embebido | `cliente` |
| Arreglo embebido | `lineas` |
| Fuera del documento | `detalle_pedido.id` (no se usa como identificador, el orden del arreglo lo reemplaza) y las columnas de auditoría (`created_at`, `eliminado`, etc.) |

## Consigna 3: reglas de integridad que se conservan

Ambas se verificaron sobre los 10 documentos migrados con `verificacion_integridad.js`. Todos los controles dieron 0 incumplimientos.

1. **Coherencia de importes.** En cada línea, `subtotal = cantidad × precio_unitario`, y el `total` del pedido es la suma de los `subtotal` de sus líneas. En PostgreSQL esto se apoya en los CHECK de `detalle_pedido` y `pedidos`. Se migró el valor guardado, sin recalcular.
2. **Cantidades válidas y un renglón por producto.** `cantidad > 0` y un mismo producto aparece una sola vez por pedido, como exige `UNIQUE (pedido_id, producto_id)` en `detalle_pedido`.

## Qué se embebió y por qué

- **Líneas del pedido (embebidas).** Una línea no existe sin su pedido y siempre se lee junto con él. Embeberlas permite traer un pedido completo en una sola lectura y mantener juntos el `total` y los `subtotal`.
- **Precio unitario (embebido).** Es el precio histórico del momento de la compra. Si se leyera desde `productos`, un cambio posterior de precio alteraría pedidos ya cerrados.
- **Nombre del producto (embebido).** Se copia para poder mostrar el pedido sin consultar otra colección.
- **Datos del cliente (embebidos, solo los esenciales).** Se copian nombre, apellido y mail para identificar el pedido. El resto de los datos (contraseña, rol, celular) queda fuera.
- **Catálogo de productos y clientes (colecciones separadas).** Tienen vida propia, se actualizan con independencia de los pedidos y se reutilizan en muchos documentos. Embeberlos completos duplicaría datos y obligaría a actualizar muchos pedidos ante un cambio.

**Costo del modelo.** El nombre del producto y los datos del cliente quedan duplicados. Si cambian en el origen, los pedidos migrados mantienen el valor anterior, lo que es aceptable para una foto histórica.
