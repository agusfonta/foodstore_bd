# Evaluación de la tecnología con IA (consignas 6 y 7)

## Consigna 6: consulta a la IA

**Herramienta:** Claude Code (Claude Sonnet 5.5).

**Prompt utilizado**

> Comparar PostgreSQL y MongoDB para almacenar y consultar los pedidos de Food Store. El modelo actual es relacional: `pedidos` (id, fecha, estado, total, cliente_id) y `detalle_pedido` (pedido_id, producto_id, cantidad, precio_unitario, subtotal), con claves foráneas, CHECK y UNIQUE (pedido_id, producto_id). El acceso más frecuente es leer un pedido completo con sus líneas. Además, es imprescindible conservar la coherencia entre cantidades y precios (subtotal = cantidad × precio_unitario y total = suma de subtotales). Indicar ventajas y riesgos de cada motor para este caso.

**Resumen de la respuesta (sin transcripción)**

1. MongoDB resuelve la lectura de un pedido completo con una sola consulta, porque las líneas van embebidas, sin JOIN.
2. En MongoDB las transacciones de varios documentos requieren un replica set.
3. MongoDB no aplica por defecto claves foráneas ni CHECK, así que la coherencia de cantidades y precios pasa a depender de la aplicación, salvo que se agregue validación de esquema.
4. PostgreSQL garantiza la integridad con restricciones declarativas y transacciones ACID.
5. Recomendó mantener PostgreSQL para el registro de pedidos y usar MongoDB solo como vista de lectura si hace falta.

## Consigna 7: contraste de dos afirmaciones

| # | Afirmación de la IA | Contraste en el laboratorio | Resultado |
| :--- | :--- | :--- | :--- |
| 1 | MongoDB no aplica integridad por defecto; PostgreSQL sí. | En la colección de prueba, MongoDB aceptó un pedido con cliente inexistente (999999), producto inexistente (888888), `cantidad = -5`, precio negativo y subtotal incoherente. En PostgreSQL (`BEGIN`/`ROLLBACK`) los tres intentos fueron rechazados: `chk_detalle_cantidad`, `fk_pedido_cliente` y `chk_detalle_subtotal_coherente`. | Confirmada |
| 2 | Las transacciones multidocumento de MongoDB requieren un replica set. | La instalación local es una instancia única (`standalone`). Al iniciar una transacción con una sesión, falló con: «This MongoDB deployment does not support retryable writes». El estado del pedido 1 quedó intacto. | Confirmada |

Fuente complementaria para la afirmación 2: https://www.mongodb.com/docs/manual/core/transactions/ (a revisar al armar el PDF).

**Nota de laboratorio.** Los tres INSERT fallidos en PostgreSQL se hicieron dentro de `BEGIN`/`ROLLBACK`, pero consumieron valores de la secuencia de `detalle_pedido`. No dejan filas, solo saltan los ids siguientes.

## Conclusión (máximo 200 palabras)

Conviene mantener PostgreSQL como sistema de registro de pedidos. Primero, por la integridad: en el laboratorio PostgreSQL rechazó una cantidad negativa, un cliente inexistente y un subtotal incoherente, mientras MongoDB aceptó un documento con esos errores, porque sin validación de esquema la coherencia de cantidades y precios queda a cargo de la aplicación. Segundo, por la atomicidad: en la instalación local de MongoDB una transacción multidocumento no pudo ejecutarse y requeriría un replica set, mientras que en PostgreSQL es el comportamiento básico. A favor de MongoDB está el patrón de acceso: un pedido completo se lee con un solo `find`, sin JOIN, y el precio histórico queda congelado en el documento. Esa ventaja es real, pero no compensa perder garantías en un dominio donde los importes deben ser exactos. La opción de combinar tecnologías tiene sentido solo como copia de lectura derivada, con PostgreSQL como única fuente de escritura y validación, y únicamente si el volumen de lecturas de pedidos completos lo justifica. Para el tamaño actual del proyecto, esa complejidad adicional no se justifica.
