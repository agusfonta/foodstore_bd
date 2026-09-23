Lee la especificación y a partir de ella, proponé el índice adecuado para mi base de datos foodstore especificando:

El tipo de índice 

Las columnas involucradas y su orden exacto en caso de ser un índice compuesto (justificando por qué va primero una columna y luego otra).

Si corresponde, una condición de índice parcial (ej. WHERE eliminado = FALSE).

La sentencia CREATE INDEX final comentada."


# spec: Optimizazion del la consulta ranking de productos con mas volumen de venta

## Objetivo
Crear una optimizacion de la consulta ranking de productos con mas volumen de venta mediante la propuesta de un inice que  : 

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



## Columnas involucradas
- pedido: estado, eliminado, id (Filtro y JOIN)
- producto: eliminado, id, nombre (Filtro y JOIN)
- detalle_pedido: pedido_id, producto_id, cantidad, subtotal (JOIN y agregacion)

## Requerimientos
- Exponer: id, nombre, unidades_vendidas, total_vendido 
- Filtrar solo productos eliminado = FALSE y estado no debe ser CANCELADO ni PENDIENTE
- Tablas involucradas: detalle_pedido, pedido, producto

## Criterio de aceptación
- Reducir el tiempo total de ejecución medido con EXPLAIN ANALYZE
- Cambiar el plan de acceso sobre las tablas principales de Seq Scan a Index Scan o Bitmap Heap Scan
- Mantener la equivalencia exacta del resultado final en filas y valores



---


Lee la especificación y a partir de ella, proponé el índice adecuado para mi base de datos foodstore especificando:

El tipo de índice 

Las columnas involucradas y su orden exacto en caso de ser un índice compuesto (justificando por qué va primero una columna y luego otra).

Si corresponde, una condición de índice parcial (ej. WHERE eliminado = FALSE).

La sentencia CREATE INDEX final comentada.


# spec: Optimizazion del la consulta reporte de cobranza por forma de pago y estado 

## Objetivo
Crear una optimizacion de la consulta de reporte de cobranzas segun el medio de pago y su estado : 

SELECT forma_pago, estado, COUNT(*) AS cantidad_pedidos, SUM(total) AS monto
FROM pedidos
WHERE eliminado = FALSE
GROUP BY forma_pago, estado
ORDER BY monto DESC;

## Columnas involucradas 
- pedido: eliminado, estado (Filtro)
- pedido: forma_pago (Agregacion/ GROUP BY)

## Requerimientos
- Exponer: forma_pago, estado, cantidad_pedido, monto
- Filtrar únicamente pedidos activos eliminado = FALSE.



## Criterio de aceptación
- Reducir el tiempo total de ejecución medido con EXPLAIN ANALYZE
- Cambiar el plan de acceso sobre las tablas principales de Seq Scan a Index Scan o Bitmap Heap Scan
- Mantener la equivalencia exacta del resultado final en filas y valores


---



Lee la especificación y a partir de ella, proponé el índice adecuado para mi base de datos foodstore especificando:

El tipo de índice 

Las columnas involucradas y su orden exacto en caso de ser un índice compuesto (justificando por qué va primero una columna y luego otra).

Si corresponde, una condición de índice parcial (ej. WHERE eliminado = FALSE).

La sentencia CREATE INDEX final comentada.

# spec: Optimizazion del la consulta historial completo de compras de un cliente

## Objetivo
Crear una optimizacion de la consulta de historial completo de compras de un cliente : 

SELECT id, fecha, estado, forma_pago, total
FROM pedidos
WHERE cliente_id = 5 AND eliminado = FALSE
ORDER BY fecha DESC;


## Columnas involucradas (Candidatas a indexar)
- pedido: cliente_id , eliminado (Filtros de igualdad)
- pedido: fecha (Ordenamiento / ORDER BY)

## Requerimientos
- Exponer: id, fecha, estado, forma_pago, total
- Filtrar  únicamente clientes activos eliminado = FALSE  y cuyo id coincida
- Tablas involucradas: pedidos

## Criterio de aceptación
- Reducir el tiempo total de ejecución medido con EXPLAIN ANALYZE
- Cambiar el plan de acceso sobre las tablas principales de Seq Scan a Index Scan o Bitmap Heap Scan
- Mantener la equivalencia exacta del resultado final en filas y valores

