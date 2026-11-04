# Tabla de verificación (consigna 5)

Se comparan los pedidos 1 a 10, que son los migrados a MongoDB.

| Consulta | Cantidad en PostgreSQL | Cantidad en MongoDB | Coinciden los IDs |
| :--- | :---: | :---: | :---: |
| Estado seleccionado (`CONFIRMADO`) | 3 (`1, 5, 9`) | 3 (`1, 5, 9`) | Sí |
| Producto seleccionado (`producto_id = 6`) | 3 (`2, 3, 4`) | 3 (`2, 3, 4`) | Sí |

## Diferencia detectada

Sin acotar a los pedidos 1 a 10, PostgreSQL devuelve 50.000 pedidos `CONFIRMADO` y 12 pedidos con el producto 6. La diferencia viene del alcance de la migración, no de un error: MongoDB solo contiene el subconjunto migrado. Por eso las consultas de `consultas_postgresql.sql` se acotan con `id BETWEEN 1 AND 10`.

En la consulta c) se usa `EXISTS` en lugar de un `JOIN` con `detalle_pedido`. Con el `JOIN` un pedido aparecería una vez por cada línea que cumpla la condición, mientras que en Mongo cada documento se devuelve una sola vez.

## Consulta d) (solo MongoDB)

- Umbral: 2134.07, el promedio de `total` de los 10 pedidos migrados (2134.068).
- Resultado: 4 pedidos (`2, 3, 4, 9`).
