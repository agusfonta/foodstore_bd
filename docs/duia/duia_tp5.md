# DUIA — TP 5: Optimización de consultas con índices (Foodstore)

**Proyecto:** Foodstore — PostgreSQL, base de trabajo `foodstore_desarrollo` (copia, no producción)
**Informe asociado:** `Informes_tps/TP5_Informe_mediciones.md`
**Specs asociadas:** `spec/spec_tp5.md`
**Script de mediciones:** `db/tp5_mediciones_pendientes.sql`

> Completar los campos marcados con **[CONFIRMAR]** con el dato real, por ejemplo el modelo que tenía configurado OpenCode.

---

## Uso 1: Consulta Nº 1, ranking de ventas por producto

| Campo | Completar |
| :--- | :--- |
| **Herramienta** | OpenCode |
| **Modelo/proveedor** | **[OpenCode zen]** |
| **Spec o prompt utilizado** | Prompt: "Lee la especificación y a partir de ella, proponé el índice adecuado para mi base de datos foodstore especificando: El tipo de índice. Las columnas involucradas y su orden exacto en caso de ser un índice compuesto (justificando por qué va primero una columna y luego otra). Si corresponde, una condición de índice parcial (ej. WHERE eliminado = FALSE). La sentencia CREATE INDEX final comentada." + spec "Optimización de la consulta ranking de productos con más volumen de venta" (texto completo en `spec/spec_tp5.md`). |
| **Qué generó la IA** | Dos índices: `idx_pedidos_volumen_venta ON pedidos (estado, eliminado) WHERE estado IN ('CONFIRMADO','TERMINADO') AND eliminado = FALSE` (B-Tree parcial) e `idx_detalle_pedido_agg_ventas ON detalle_pedido (pedido_id, producto_id) INCLUDE (cantidad, subtotal)` (B-Tree covering). También sugirió índices individuales sobre `pedidos(estado)` y `pedidos(eliminado)`. |
| **Qué se aceptó** | Nada quedó en la solución final. Los dos índices se crearon en la copia de trabajo para medirlos. |
| **Qué se modificó o descartó, y por qué** | **Se descartaron los dos índices.** El plan con índices (captura image-1) es igual al plan sin índices: `pedidos` y `detalle_pedido` se siguen leyendo con Parallel Seq Scan, así que el planner no los usa. La consulta necesita la mitad de `pedidos` y todo `detalle_pedido`, y con esa selectividad conviene la lectura secuencial. La baja de 773.753 a 381.783 ms se debió al efecto caché, no al índice: el scan de `pedidos` pasó de 195 a 19 ms con el mismo tipo de acceso. Los índices individuales sobre `estado` y `eliminado` se descartaron antes de aplicarlos, por baja selectividad. **La explicación de la IA (que el índice iba a cambiar el acceso a `pedidos`) resultó incorrecta.** |
| **Verificación realizada** | `EXPLAIN ANALYZE` antes (773.753 ms) y después (381.783 ms) sobre `foodstore_desarrollo`. Medición de control repetida (3 ejecuciones sin índices y 3 con índices): **[COMPLETAR con los resultados del bloque 1 del script]**. |

---

## Uso 2: Consulta Nº 2, reporte de cobranza por forma de pago y estado

| Campo | Completar |
| :--- | :--- |
| **Herramienta** | OpenCode |
| **Modelo/proveedor** | **[OpenCode zen]** |
| **Spec o prompt utilizado** | Mismo prompt que el Uso 1 + spec "Optimización de la consulta reporte de cobranza por forma de pago y estado" (`spec/spec_tp5.md`). |
| **Qué generó la IA** | `idx_pedidos_cobranza ON pedidos (forma_pago, estado) INCLUDE (total) WHERE eliminado = FALSE` (B-Tree covering parcial, columnas en el orden del GROUP BY). Como alternativa propuso la misma estructura con condición `WHERE estado IN ('CONFIRMADO','TERMINADO') AND eliminado = FALSE`. |
| **Qué se aceptó** | `idx_pedidos_cobranza` tal como lo generó la IA. |
| **Qué se modificó o descartó, y por qué** | Se descartó la variante con `estado IN (...)`: la consulta agrupa por **todos** los estados, así que ese índice no tendría todas las filas necesarias y el planner no podría usarlo. |
| **Verificación realizada** | `EXPLAIN ANALYZE`: antes, Parallel Seq Scan + HashAggregate + Sort, **41.055 ms**. Después, Parallel Index Only Scan con Heap Fetches: 0 + GroupAggregate, **32.989 ms**. Mejora: **1,24x**. La propuesta de la IA fue verificada y se confirmó. |

---

## Uso 3: Consulta Nº 3, historial de pedidos por cliente

| Campo | Completar |
| :--- | :--- |
| **Herramienta** | OpenCode |
| **Modelo/proveedor** | **[OpenCode zen]** |
| **Spec o prompt utilizado** | Mismo prompt que el Uso 1 + spec "Optimización de la consulta historial completo de compras de un cliente" (`spec/spec_tp5.md`). |
| **Qué generó la IA** | `idx_pedidos_historial_cliente ON pedidos (cliente_id, fecha DESC) INCLUDE (estado, forma_pago, total) WHERE eliminado = FALSE`, con el objetivo declarado de lograr un Index Only Scan sin Sort. También evaluó un índice simple sobre `pedidos(cliente_id)`. |
| **Qué se aceptó** | El índice compuesto parcial: `cliente_id` primero (igualdad muy selectiva) y `fecha DESC` después (orden del ORDER BY). |
| **Qué se modificó o descartó, y por qué** | **La IA se equivocó en el resultado esperado:** anunció Index Only Scan sin Sort, pero el plan real (image-4) muestra Bitmap Heap Scan + Sort, porque la columna `id` del SELECT no estaba en el índice. Se agregó a mano una variante con `INCLUDE (id, estado, forma_pago, total)` para lograr el covering completo (decisión final: **[COMPLETAR]**). El índice simple sobre `cliente_id` se descartó por redundante: el índice compuesto ya empieza por esa columna. |
| **Verificación realizada** | `EXPLAIN ANALYZE`: antes, Parallel Seq Scan + Sort, **19.577 ms**. Después, Bitmap Heap Scan + Sort, **0.110 ms** (≈178x). Variante con `id` en el INCLUDE: **[COMPLETAR con los resultados del bloque 2 del script]**. |

---

## Uso 4: Prueba de impacto en la inserción

| Campo | Completar |
| :--- | :--- |
| **Herramienta** | OpenCode **[CONFIRMAR si el script de inserción lo generó la IA o fue propio]** |
| **Modelo/proveedor** | **[OpenCode zen]** |
| **Spec o prompt utilizado** | **[CONFIRMAR el prompt usado]** |
| **Qué generó** | Script de prueba: 100 pedidos + 500 filas en `detalle_pedido` dentro de `BEGIN … ROLLBACK`, midiendo sin y con `idx_detalle_pedido_agg_ventas`. |
| **Qué se aceptó** | La estructura de la prueba (transacción con ROLLBACK para no dejar datos). |
| **Qué se modificó o descartó, y por qué** | La línea `\timing on sobre el INSERT` no es válida en DBeaver (`\timing` es un comando de psql). Una sola ejecución de 500 filas (16 ms contra 15 ms) no alcanza para sacar conclusiones, porque la diferencia es ruido. Se repite con 50.000 filas y 5 ejecuciones, midiendo con `EXPLAIN ANALYZE` sobre el INSERT. |
| **Verificación realizada** | 500 filas: 16 ms sin índice, 15 ms con índice. 50.000 filas (mediana de 5): **[COMPLETAR con los resultados del bloque 3 del script]**. |

---

## Uso 5: Revisión y corrección del informe

| Campo | Completar |
| :--- | :--- |
| **Herramienta** | Claude (Anthropic) |
| **Modelo/proveedor** | Claude, Anthropic |
| **Spec o prompt utilizado** | "Teniendo en cuenta las consignas, quiero que te pongas en plan de profesor de base de datos y corrijas todo; en el caso de que haya errores, que los cambies y me expliques los cambios que hiciste. Arreglame solo el TP 5 y no modifiques los TP anteriores (3 y 4)." |
| **Qué generó** | Contrastó cada afirmación del informe con las capturas de `EXPLAIN ANALYZE`. Detectó que en la consulta 1 los índices no se usaban y que en la consulta 3 el plan no era Index Only Scan. Corrigió el informe, la spec y la prueba de inserción, y armó el script `db/tp5_mediciones_pendientes.sql` para las mediciones faltantes. |
| **Qué se aceptó** | **[CONFIRMAR]** |
| **Qué se modificó o descartó, y por qué** | **[CONFIRMAR]** No se incorporó ningún tiempo que no saliera de nuestras propias mediciones. Los valores nuevos se completan corriendo el script sobre `foodstore_desarrollo`. |
| **Verificación realizada** | Las correcciones se verifican con las mediciones del script `db/tp5_mediciones_pendientes.sql`: **[COMPLETAR]**. |

---

## Trazabilidad

- Todas las pruebas se hicieron sobre la copia `foodstore_desarrollo`, siguiendo el protocolo de seguridad: copia de trabajo, transacciones con ROLLBACK para las pruebas de escritura y respaldo antes de DDL.
- Resumen de decisiones: **aceptados** `idx_pedidos_cobranza` e `idx_pedidos_historial_cliente`. **Descartados** `idx_pedidos_volumen_venta`, `idx_detalle_pedido_agg_ventas` y los índices simples sobre `estado`, `eliminado` y `cliente_id`.
- En dos de las tres consultas la IA anunció un plan que el `EXPLAIN ANALYZE` real no confirmó (consultas 1 y 3). Se deja constancia, como pide el criterio de aceptación: ninguna propuesta se da por buena sin verificarla en el plan real.
