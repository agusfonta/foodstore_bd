# DUIA — TP Unidad 7: NoSQL y nuevas formas de almacenamiento (Food Store)

**Proyecto:** Foodstore — PostgreSQL 17 (base de trabajo `foodstore_desarrollo`) y MongoDB 9.0.2 local (`foodstore_u7.pedidos`)
**Informe asociado:** `informe_u7.pdf`
**Herramienta realmente usada:** Claude Code (Claude Sonnet 5.5) en todas las partes.

---

## Uso 1: Parte 1 — Modelo documental y migración (consignas 1 a 3)

| Campo | Descripción |
| :--- | :--- |
| **Herramienta** | Claude Code |
| **Spec o prompt utilizado** | "Arma un plan para resolver las consignas del pdf CONSIGNAS.pdf" |
| **Qué generó** | El prompt con el plan a seguir. Consultas sobre la migracion |
| **Qué se aceptó** | Todo lo generado, sin cambios. |
| **Qué se modificó o descartó, y por qué** | Sin modificaciones. |
| **Verificación realizada** | Exportación de 10 líneas JSON desde `foodstore_desarrollo` (solo lectura); `insertMany` de 10 documentos (3 CONFIRMADO, 3 TERMINADO, 2 PENDIENTE, 2 CANCELADO); `verificacion_integridad.js` con 0 incumplimientos en las cuatro reglas. |

---

## Uso 2: Parte 2 — Consultas y verificación (consignas 4 y 5)

| Campo | Descripción |
| :--- | :--- |
| **Herramienta** | Claude Code |
| **Spec o prompt utilizado** | "Genera las consultas de Mongo y PostgreSQL y la tabla comparativa." |
| **Qué generó** | `mongodb/consultas_mongodb.js`, `mongodb/consultas_postgresql.sql` y `docs/informes/tabla_verificacion_u7.md`. Eligió el estado `CONFIRMADO`, el producto 6 y el umbral 2134.07 (promedio de `total`), y usó `EXISTS` en lugar de `JOIN` en la consulta c). |
| **Qué se aceptó** | Todo lo generado, sin cambios manuales. |
| **Qué se modificó o descartó, y por qué** | Sin modificaciones manuales hasta la fecha de esta declaración. Las consultas de PostgreSQL se acotaron a `id BETWEEN 1 AND 10` porque Mongo solo contiene el subconjunto migrado; sin ese límite las cantidades no son comparables. |
| **Verificación realizada** | Estado `CONFIRMADO`: 3 pedidos en ambos motores (ids 1, 5, 9). Producto 6: 3 pedidos en ambos (ids 2, 3, 4). Consulta d): 4 pedidos (ids 2, 3, 4, 9). Sin acotar, PostgreSQL devuelve 50.000 y 12 pedidos (no migrados). |

---

## Uso 3: Parte 3 — Evaluación de la tecnología con IA (consignas 6 y 7)

| Campo | Descripción |
| :--- | :--- |
| **Herramienta** | Claude Code |
| **Spec o prompt utilizado** |  El texto del prompt de comparación está en `ia_contraste.md`. |
| **Qué generó** | `docs/informes/ia_contraste_u7.md`: prompt de comparación, resumen de la respuesta, contraste de dos afirmaciones y conclusión de 175 palabras. |
| **Qué se aceptó** | La estructura, las dos afirmaciones contrastadas y la conclusión. |
| **Qué se modificó o descartó, y por qué** | Sin modificaciones manuales hasta la fecha de esta declaración. La IA que responde la consulta y la que ejecuta las pruebas es la misma herramienta; por eso las afirmaciones se contrastaron con ejecución real. La prueba de transacciones falló con un mensaje sobre *retryable writes* y no con uno que mencione el replica set; se informó tal cual. No se consultó la documentación oficial de MongoDB. |
| **Verificación realizada** | MongoDB aceptó en una colección de prueba (ya borrada) un pedido con cliente y producto inexistentes, cantidad -5 y subtotal incoherente. PostgreSQL, dentro de `BEGIN`/`ROLLBACK`, rechazó los tres casos (`chk_detalle_cantidad`, `fk_pedido_cliente`, `chk_detalle_subtotal_coherente`). La transacción en la instalación local (instancia única) falló y el pedido 1 quedó intacto. |


