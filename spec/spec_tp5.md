Leé la especificación y, a partir de ella, proponé el índice adecuado para mi base de datos foodstore especificando:

- El tipo de índice.
- Las columnas involucradas y su orden exacto en caso de ser un índice compuesto (justificando por qué va primero una columna y luego otra).
- Si corresponde, una condición de índice parcial (ej. WHERE eliminado = FALSE).
- La sentencia CREATE INDEX final comentada.


# Spec: Optimización de la consulta ranking de productos con más volumen de venta

## Objetivo
Optimizar la consulta de ranking de productos con más volumen de venta mediante la propuesta de un índice:

```sql
SELECT pr.id, pr.nombre,
      SUM(dp.cantidad) AS unidades_vendidas,
      SUM(dp.subtotal) AS total_vendido
FROM detalle_pedido dp
JOIN pedidos p    ON p.id = dp.pedido_id
JOIN productos pr ON pr.id = dp.producto_id
WHERE p.estado IN ('CONFIRMADO', 'TERMINADO')
  AND p.eliminado = FALSE
  AND pr.eliminado = FALSE
GROUP BY pr.id, pr.nombre
ORDER BY total_vendido DESC;
```

## Columnas involucradas
- pedidos: estado, eliminado (filtro); id (JOIN)
- productos: eliminado (filtro); id (JOIN y GROUP BY); nombre (GROUP BY y salida)
- detalle_pedido: pedido_id, producto_id (JOIN); cantidad, subtotal (agregación)

## Requerimientos
- Exponer: id, nombre, unidades_vendidas, total_vendido.
- Filtrar solo productos con eliminado = FALSE.
- Filtrar solo pedidos con eliminado = FALSE y estado CONFIRMADO o TERMINADO.
- Tablas involucradas: detalle_pedido, pedidos, productos.

## Criterio de aceptación
- Reducir el Execution Time medido con EXPLAIN ANALYZE (mediana de 3 ejecuciones, antes y después).
- Cambiar el plan de acceso sobre las tablas principales de Seq Scan a Index Scan, Index Only Scan o Bitmap Heap Scan. Si el planner no usa el índice, se documenta el motivo y el índice se descarta.
- Mantener la equivalencia exacta del resultado final en filas y valores.


---


Leé la especificación y, a partir de ella, proponé el índice adecuado para mi base de datos foodstore especificando:

- El tipo de índice.
- Las columnas involucradas y su orden exacto en caso de ser un índice compuesto (justificando por qué va primero una columna y luego otra).
- Si corresponde, una condición de índice parcial (ej. WHERE eliminado = FALSE).
- La sentencia CREATE INDEX final comentada.


# Spec: Optimización de la consulta reporte de cobranza por forma de pago y estado

## Objetivo
Optimizar la consulta de reporte de cobranzas según el medio de pago y el estado del pedido:

```sql
SELECT forma_pago, estado, COUNT(*) AS cantidad_pedidos, SUM(total) AS monto
FROM pedidos
WHERE eliminado = FALSE
GROUP BY forma_pago, estado
ORDER BY monto DESC;
```

## Columnas involucradas
- pedidos: eliminado (filtro)
- pedidos: forma_pago, estado (GROUP BY)
- pedidos: total (agregación SUM)

## Requerimientos
- Exponer: forma_pago, estado, cantidad_pedidos, monto.
- Filtrar únicamente pedidos activos (eliminado = FALSE). Se incluyen todos los estados.
- Tablas involucradas: pedidos.

## Criterio de aceptación
- Reducir el Execution Time medido con EXPLAIN ANALYZE (mediana de 3 ejecuciones, antes y después).
- Cambiar el plan de acceso sobre la tabla de Seq Scan a Index Scan, Index Only Scan o Bitmap Heap Scan.
- Mantener la equivalencia exacta del resultado final en filas y valores.


---


Leé la especificación y, a partir de ella, proponé el índice adecuado para mi base de datos foodstore especificando:

- El tipo de índice.
- Las columnas involucradas y su orden exacto en caso de ser un índice compuesto (justificando por qué va primero una columna y luego otra).
- Si corresponde, una condición de índice parcial (ej. WHERE eliminado = FALSE).
- La sentencia CREATE INDEX final comentada.

# Spec: Optimización de la consulta historial completo de compras de un cliente

## Objetivo
Optimizar la consulta de historial completo de compras de un cliente:

```sql
SELECT id, fecha, estado, forma_pago, total
FROM pedidos
WHERE cliente_id = 5 AND eliminado = FALSE
ORDER BY fecha DESC;
```

## Columnas involucradas (candidatas a indexar)
- pedidos: cliente_id (filtro de igualdad)
- pedidos: eliminado (filtro de igualdad, candidato a condición de índice parcial)
- pedidos: fecha (ORDER BY)
- pedidos: id, estado, forma_pago, total (columnas de salida, candidatas a INCLUDE)

## Requerimientos
- Exponer: id, fecha, estado, forma_pago, total.
- Filtrar únicamente los pedidos no eliminados (pedidos.eliminado = FALSE) del cliente indicado (cliente_id).
- Tablas involucradas: pedidos.

## Criterio de aceptación
- Reducir el Execution Time medido con EXPLAIN ANALYZE (mediana de 3 ejecuciones, antes y después).
- Cambiar el plan de acceso sobre la tabla de Seq Scan a Index Scan, Index Only Scan o Bitmap Heap Scan.
- Mantener la equivalencia exacta del resultado final en filas y valores.
