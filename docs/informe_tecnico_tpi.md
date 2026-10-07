# Informe técnico — TPI «Food Store» · Primera entrega parcial

**Materia:** Base de Datos II · **Integrantes:** Gianella Peña, Martina Suarez y Agustina Fontagnol
**Motor:** PostgreSQL 16+ con PL/pgSQL (desarrollado y probado en 17.11, Windows 11)
**Alcance de esta entrega (Unidades 1, 2 y 3):** integridad, transacciones y concurrencia · optimización de consultas · índices, vistas y objetos programables.
**Fecha:** 2026-10-07 (versión corregida a partir de la devolución del docente)

> Esta entrega **no es el TP5**: el TP5 (optimización con índices) es una de las partes que la componen. El [`README.md`](../README.md) explica cómo recorrer el repositorio y los scripts están numerados en orden de ejecución.

---

## 0. Checklist de los 9 objetivos que la entrega debe acreditar

| # | Objetivo de la consigna | Evidencia en el repositorio | Cómo verificarlo |
| :-: | :--- | :--- | :--- |
| 1 | Modelo ER (entidades, atributos, claves, cardinalidad, participación) | [`docs/01_modelo_er.md`](01_modelo_er.md) | Diagrama ER + tablas de entidades y de relaciones con participación (mín,máx) |
| 2 | Paso de ER a relacional, con 1:N y N:M resueltas con tablas intermedias | [`docs/02_modelo_relacional.md`](02_modelo_relacional.md) | Reglas R1–R7; `detalle_pedido` resuelve la N:M; consulta a `pg_constraint` (sección 4 del documento) |
| 3 | Normalización hasta 3FN/BCNF con justificación de dependencias funcionales | [`docs/03_normalizacion.md`](03_normalizacion.md) | UNF → 1FN → 2FN → 3FN/BCNF, 9 dependencias funcionales numeradas, desnormalizaciones justificadas |
| 4 | DDL completo: tipos, PK, FK, restricciones e índices | [`db/01_ddl_schema.sql`](../db/01_ddl_schema.sql) · [`db/03_ddl_indices.sql`](../db/03_ddl_indices.sql) | `ENUM`, `IDENTITY`, `TIMESTAMPTZ`, 5 PK, 4 FK, `CHECK`, `UNIQUE`, índices parciales/compuestos/*covering* |
| 5 | DML y consultas: JOIN, agregación, subconsultas, GROUP BY/HAVING, ventana | [`db/04_dml_carga_masiva.sql`](../db/04_dml_carga_masiva.sql) · [`db/05_dml_consultas.sql`](../db/05_dml_consultas.sql) | Carga de 20.000 clientes / 50.000 productos / 200.000 pedidos / 600.000 renglones; consultas con `HAVING`, `RANK`, `LAG`, `ROW_NUMBER`, `NOT EXISTS` |
| 6 | Vistas, funciones y procedimientos en PL/pgSQL | [`db/06_vistas.sql`](../db/06_vistas.sql) · [`db/07_vista_materializada.sql`](../db/07_vista_materializada.sql) · [`db/08_funciones_procedimientos_plpgsql.sql`](../db/08_funciones_procedimientos_plpgsql.sql) | 3 vistas + 1 materializada; 3 funciones; **5 procedimientos invocados con `CALL`** (ejemplos en la sección 1.3) |
| 7 | Reglas de negocio con CHECK, UNIQUE y triggers | [`db/02_reglas_negocio_check_unique_triggers.sql`](../db/02_reglas_negocio_check_unique_triggers.sql) · [`docs/duia/duia_parte1.md`](duia/duia_parte1.md) | `CHECK` de subtotal, 2 triggers (transición de estado, baja de cliente), `UNIQUE` en el DDL; pruebas en la sección 3 |
| 8 | Transacciones: atomicidad, COMMIT, ROLLBACK, aislamiento, concurrencia | [`db/09_transacciones.sql`](../db/09_transacciones.sql) · [`docs/informe_concurrencia.md`](informe_concurrencia.md) · [`capturas/`](../capturas) | Script ejecutable + 3 experimentos de dos sesiones con capturas |
| 9 | Borrado lógico y su impacto en consultas e índices | [`db/10_borrado_logico.sql`](../db/10_borrado_logico.sql) | Columnas `eliminado`/`deleted_at`, `sp_baja_logica_*`, índices parciales, efecto en vistas y en `UNIQUE` |

---

## 1. Qué elementos se implementaron en cada unidad

### 1.1 Unidad 1 — Integridad, transacciones y concurrencia

* **Protocolo de seguridad** de 3 pasos (copia de trabajo con `createdb -T`, transacción con `ROLLBACK` previo, respaldo con `pg_dump`): [`protocolo_seguridad.md`](../protocolo_seguridad.md). Respaldo de ejemplo en [`backups/`](../backups).
* **Restricciones de integridad** ([script 02](../db/02_reglas_negocio_check_unique_triggers.sql)): regla 1, `CHECK subtotal = cantidad × precio_unitario`; regla 2, trigger `trg_pedidos_transicion_estado` (PENDIENTE → CONFIRMADO/CANCELADO, CONFIRMADO → TERMINADO/CANCELADO; los estados finales no cambian); regla 3, trigger `trg_clientes_baja_logica` (no se da de baja a un cliente con pedidos PENDIENTE o CONFIRMADO). Más los `CHECK`, `UNIQUE` y FK del [DDL](../db/01_ddl_schema.sql). DUIA: [`duia_parte1.md`](duia/duia_parte1.md).
* **Concurrencia** ([informe_concurrencia.md](informe_concurrencia.md)): lectura no repetible, lectura fantasma y espera por bloqueo, cada una con dos sesiones, en `READ COMMITTED` y `REPEATABLE READ`; capturas en [`capturas/`](../capturas). DUIA: [`duia_parte2.md`](duia/duia_parte2.md).
* **Lectura crítica de SQL peligroso** (`UPDATE` sin `WHERE`, `NOT IN` con `NULL`): [`ejercicio_lectura_critica.md`](ejercicio_lectura_critica.md).
* **Transacciones sobre objetos programables** ([script 09](../db/09_transacciones.sql)): atomicidad con `sp_crear_pedido`, `SAVEPOINT`, `ROLLBACK`, `COMMIT`, niveles de aislamiento y concurrencia sobre la última unidad de stock.

### 1.2 Unidad 2 — Optimización de consultas

* **Carga masiva** ([script 04](../db/04_dml_carga_masiva.sql)) con `generate_series`, set-based, respetando todas las restricciones: 20.000 clientes, 50.000 productos, 200.000 pedidos y 600.000 renglones.
* **Consultas de reporte** ([script 05](../db/05_dml_consultas.sql)): facturación por categoría y mes, ranking de clientes, ranking de productos por categoría (`RANK() OVER`), productos más caros que el promedio de su categoría (subconsulta correlacionada), cobranza por forma de pago, top de productos vendidos; **agregadas en esta versión:** `GROUP BY … HAVING`, `NOT EXISTS`, `LAG()`/`SUM() OVER`, `ROW_NUMBER() OVER (PARTITION BY …)` y sentencias `INSERT`/`UPDATE` probadas dentro de `BEGIN … ROLLBACK`.
* **Medición con `EXPLAIN ANALYZE`**, reescrituras (subconsulta correlacionada → CTE / función de ventana) y propuestas de índices evaluadas con criterio: [`Informes_tps/Informe_optimizacion_consultas_indices.md`](../Informes_tps/Informe_optimizacion_consultas_indices.md), specs en [`spec/spec_tp5.md`](../spec/spec_tp5.md), scripts de medición [`db/tp5_mediciones_pendientes.sql`](../db/tp5_mediciones_pendientes.sql) y [`db/parte5_competencia.sql`](../db/parte5_competencia.sql).

### 1.3 Unidad 3 — Índices, vistas y objetos programables

* **Índices** ([script 03](../db/03_ddl_indices.sql)): B-Tree compuestos, **parciales** (`WHERE eliminado = FALSE`, `WHERE estado IN (…)`) y **covering** (`INCLUDE`). Los aceptados tras medir: `idx_pedidos_cobranza` e `idx_pedidos_historial_cliente`; los descartados por no ser usados por el planner (`idx_pedidos_volumen_venta`, `idx_detalle_pedido_agg_ventas`) están documentados con su motivo.
* **Vistas** ([script 06](../db/06_vistas.sql)): `v_productos_vigentes_con_categoria`, `v_pedidos_con_cliente` (no expone la contraseña), `v_detalle_pedido_con_producto`. Equivalencia entre dos versiones generadas por IA verificada con `EXCEPT`: [`informe_equivalencia_vistas.md`](informe_equivalencia_vistas.md) y [`bitacora_verificacion_vistas_parteB.md`](bitacora_verificacion_vistas_parteB.md).
* **Vista materializada** ([script 07](../db/07_vista_materializada.sql)): `mv_facturacion_categoria_mes` con índice único para `REFRESH … CONCURRENTLY`; [política de refresco](politica_refresh.md) y [benchmark](benchmark_resultados.md).
* **Funciones y procedimientos PL/pgSQL** ([script 08](../db/08_funciones_procedimientos_plpgsql.sql)):

| Objeto | Tipo | Qué hace |
| :--- | :--- | :--- |
| `fn_total_pedido(pedido_id)` | función | Suma de subtotales (audita `pedidos.total`) |
| `fn_pedidos_cliente(cliente_id, estado)` | función `RETURNS TABLE` | Historial de pedidos vigentes, filtro opcional por estado |
| `fn_ranking_productos_categoria(top_n)` | función `RETURNS TABLE` | Top-N de ventas por categoría con `RANK() OVER (PARTITION BY …)` |
| `sp_crear_pedido(cliente, forma_pago, items JSONB, INOUT pedido_id)` | **procedimiento** | Cabecera + renglones + descuento de stock + total, todo atómico, con bloqueo `FOR UPDATE` |
| `sp_cambiar_estado_pedido(pedido, estado)` | **procedimiento** | Cambia el estado (valida el trigger) y repone stock al cancelar |
| `sp_baja_logica_producto(producto)` | **procedimiento** | `eliminado = TRUE`, `deleted_at = now()`, `disponible = FALSE` |
| `sp_baja_logica_cliente(cliente)` | **procedimiento** | Baja lógica protegida por el trigger de pedidos activos |
| `sp_refrescar_facturacion_categoria_mes()` | **procedimiento** | `REFRESH MATERIALIZED VIEW CONCURRENTLY` |

Invocación con `CALL`:

```sql
CALL sp_crear_pedido(1, 'TARJETA', '[{"producto_id": 10, "cantidad": 2}, {"producto_id": 11, "cantidad": 1}]', NULL);
-- devuelve p_pedido_id (parámetro INOUT)
CALL sp_cambiar_estado_pedido(1, 'CONFIRMADO');
CALL sp_baja_logica_producto(10);
CALL sp_baja_logica_cliente(5);
CALL sp_refrescar_facturacion_categoria_mes();
```

---

## 2. Cómo se probó el funcionamiento

| Qué | Cómo |
| :--- | :--- |
| Unidad 1 (experimentos originales) | Dos sesiones `psql` en paralelo sobre `foodstore_desarrollo`, con capturas ([`capturas/`](../capturas)) y consulta a `pg_stat_activity` para ver la espera por bloqueo |
| Unidades 2 y 3 (mediciones) | `EXPLAIN ANALYZE` sobre la carga masiva; **mediana de 3 ejecuciones** por consulta, antes y después; se compara solo *Execution Time*, no el *cost* |
| Scripts 08, 09 y 10 y consultas nuevas del 05 | Se ejecutaron completos, en orden, en una **instancia temporal de PostgreSQL 17.11** (no se usó `foodstore` ni `foodstore_desarrollo`). Cada script lleva comentarios `-- Esperado:` con el resultado correcto y los pasos que deben fallar están marcados `ERROR ESPERADO`. Se creó la base con los scripts 01 → 02 → 03 → 06 → 07 → 08 y, para el volumen, con 04. La herramienta usada para esta tanda fue Claude Code (ver sección 5) |
| Reproducción por el docente | Crear la copia (`createdb -T foodstore foodstore_desarrollo`), ejecutar los scripts 01 → 10 en orden. Los scripts 09 y 10 limpian sus datos de prueba (prefijos `TPI_TX` / `TPI_BL`) |

---

## 3. Resultados obtenidos

### 3.1 Integridad y reglas de negocio

| Prueba | Resultado |
| :--- | :--- |
| Transición inválida `CANCELADO → CONFIRMADO` (`sp_cambiar_estado_pedido`) | `ERROR: Estado CANCELADO es final y no puede modificarse`; el estado queda en `CANCELADO` |
| Baja lógica de un cliente con pedido CONFIRMADO | `ERROR: No se puede dar de baja al cliente 3: tiene pedidos en estado PENDIENTE o CONFIRMADO`; tras cancelar el pedido, la baja se concreta |
| `DELETE` físico de un producto vendido | `ERROR … viola la llave foránea «fk_detalle_producto»` (`ON DELETE RESTRICT`): la única baja posible es la lógica |
| `sp_crear_pedido` con lista vacía / cantidad 0 / cliente inexistente | Cada caso se rechaza con su mensaje y no deja datos |
| `sp_crear_pedido` con el mismo producto repetido (3 + 2 unidades) | Un único renglón de 5 unidades (respeta `UNIQUE (pedido_id, producto_id)`) |
| Coherencia de `pedidos.total` tras la carga masiva (`WHERE total <> fn_total_pedido(id)`) | **0 filas** sobre 200.000 pedidos (1,6 s) |

### 3.2 Transacciones y concurrencia ([script 09](../db/09_transacciones.sql))

| Prueba | Resultado observado |
| :--- | :--- |
| Atomicidad, caso exitoso (3 u. de A a $100 + 1 u. de B a $50) | Pedido PENDIENTE con `total = 350.00` = `fn_total_pedido`; stock A 10 → 7, B 2 → 1 |
| Atomicidad, caso con fallo (A × 2 válido, B × 5 con stock 1) | `ERROR: Stock insuficiente … pedido 5, disponible 1`. Tras `ROLLBACK TO SAVEPOINT`: **1 pedido** del cliente y **stock de A = 7** (el descuento parcial que el procedimiento ya había hecho se deshizo) |
| `UPDATE` directo seguido de `ROLLBACK` | Stock 0 dentro de la transacción, 7 después del `ROLLBACK` |
| Cancelación (`PENDIENTE → CONFIRMADO → CANCELADO`) | Stock repuesto: A 10, B 2 |
| Niveles de aislamiento | `read committed` por defecto; `BEGIN ISOLATION LEVEL REPEATABLE READ` y `SERIALIZABLE` verificados con `SHOW transaction_isolation` |
| **Dos sesiones, última unidad de stock** | Sesión A: `BEGIN; CALL sp_crear_pedido(…)` y espera 4 s. Sesión B lanza el mismo `CALL` 1,5 s después y queda **bloqueada** (`pg_stat_activity`: `wait_event_type = Lock`, `wait_event = transactionid`). A hace `COMMIT`; B se destraba, relee el stock y falla con `Stock insuficiente … disponible 0`. Resultado: stock 0 y **un solo pedido** (no hay sobreventa) |
| Experimentos originales ([informe](informe_concurrencia.md)) | Lectura no repetible y fantasma ocurren en `READ COMMITTED` y desaparecen en `REPEATABLE READ`; `SELECT … FOR UPDATE` produce espera por bloqueo |

### 3.3 Borrado lógico ([script 10](../db/10_borrado_logico.sql))

| Prueba | Resultado observado |
| :--- | :--- |
| `sp_baja_logica_producto` | Fila conservada con `eliminado = t` y `deleted_at` cargado; `disponible = f` |
| Vista `v_productos_vigentes_con_categoria` | De 2 a 1 productos vigentes de la categoría de prueba |
| Ranking de ventas (`pr.eliminado = FALSE`) | El producto dado de baja ya no se cuenta (0 filas) |
| Historial del pedido que lo contenía | Se conserva íntegro: 2 × 100.00 = 200.00 |
| Venta de un producto dado de baja | `ERROR: Producto … inexistente o dado de baja` |
| **Índice parcial** `idx_productos_categoria_eliminado` | Con carga masiva y el predicado `AND eliminado = FALSE` el plan usa `Bitmap Index Scan on idx_productos_categoria_eliminado`; **sin** el predicado hace `Seq Scan`: el índice parcial solo se usa si la consulta repite la condición |
| **`UNIQUE` y borrado lógico** (hallazgo) | Con `UNIQUE (nombre)` sobre toda la tabla, crear un producto con el nombre de uno dado de baja falla (`productos_nombre_key`). Un índice único parcial `WHERE eliminado = FALSE`, probado dentro de `BEGIN…ROLLBACK`, lo permite y sigue impidiendo dos vigentes con el mismo nombre. **No se aplicó al esquema entregado** (queda como decisión del equipo) |

### 3.4 Funciones y consultas nuevas

* `fn_ranking_productos_categoria(2)` devolvió el top-2 por categoría con posiciones (`RANK`) correctas.
* `fn_pedidos_cliente(cliente)` y con filtro de estado devolvieron los pedidos esperados (y 0 filas para un estado sin pedidos).
* `CALL sp_refrescar_facturacion_categoria_mes()` actualizó la vista materializada: tras confirmar un pedido de prueba, `mv_facturacion_categoria_mes` reflejó los totales por categoría.
* Consultas nuevas del script 05 ejecutadas sobre la carga masiva: `HAVING` (clientes con ≥ 3 pedidos), `LAG` + `SUM OVER` (facturación mensual, variación y acumulado de 13 meses), `ROW_NUMBER` (último pedido por cliente) y `INSERT`/`UPDATE` dentro de `BEGIN…ROLLBACK`. `NOT EXISTS` devolvió 0 productos sin ventas, esperable porque la carga masiva reparte 600.000 renglones entre 50.000 productos.

---

## 4. Consultas optimizadas: diferencias antes y después

Todas las cifras son *Execution Time* de `EXPLAIN ANALYZE` y están tomadas de los informes fuente indicados.

| Consulta | Cambio aplicado | Antes | Después | Mejora | Decisión | Fuente |
| :--- | :--- | ---: | ---: | :---: | :--- | :--- |
| Historial de pedidos por cliente | `idx_pedidos_historial_cliente (cliente_id, fecha DESC) INCLUDE (…) WHERE eliminado = FALSE` | 19,577 ms | 0,110 ms | ≈ 178 × | Aceptado | [Informe de optimización](../Informes_tps/Informe_optimizacion_consultas_indices.md) |
| Reporte de cobranza por forma de pago y estado | `idx_pedidos_cobranza (forma_pago, estado) INCLUDE (total) WHERE eliminado = FALSE` | 41,055 ms | 32,989 ms | 1,24 × | Aceptado (Parallel Seq Scan → Parallel Index Only Scan) | ídem |
| Ranking de ventas por producto | 2 índices (`pedidos`, `detalle_pedido`) | 773,753 ms | 381,783 ms | No atribuible al índice | **Descartados**: el planner no los usa (la baja fue efecto caché) | ídem |
| Facturación por categoría y mes | Vista materializada `mv_facturacion_categoria_mes` | 1.364,31 ms | 0,19 ms | ≈ 7.180 × | Aceptada, con desfase de datos y política de `REFRESH` | [Benchmark](benchmark_resultados.md), [política](politica_refresh.md) |
| Productos por categoría con filtro de precio y orden | `idx_productos_q1_cat_precio (categoria_id, precio DESC) INCLUDE (nombre, stock) WHERE eliminado = FALSE AND disponible = TRUE` | 18,546 ms | 0,283 ms | ≈ 65,5 × | Aceptado | [`TP3 (docx)`](../Informes_tps/TP3_Semana3_Unidad2_TERMINADO.docx) |
| Historial de pedidos por cliente (TP3, índice simple) | `idx_pedidos_cliente (cliente_id)` | 74,734 ms | 0,408 ms | ≈ 183 × | Aceptado | ídem |
| Ranking de categorías (TP3) | `idx_productos_categoria` parcial | 26,965 ms | 48,385 ms | Empeora | **Descartado**: el índice no se usó | ídem |
| Productos más caros que el promedio de su categoría | Reescritura: subconsulta correlacionada → CTE con un único `AVG` por categoría + índice parcial `(categoria_id, precio)` | 174.947,862 ms | 58,058 ms | ≈ 3.000 × | Aceptado (Nested Loop → Hash Join) | [`TP4 (docx)`](../Informes_tps/TP4_Semana4_Unidad2_Practica.docx) |
| Ranking de productos por categoría | Reescritura: subconsulta correlacionada → `RANK() OVER (PARTITION BY …)` + índice `(categoria_id, precio DESC, id)` | 101.891,491 ms | 67,771 ms | ≈ 1.500 × | Aceptado (→ Merge Join) | ídem |

**Costo de escritura de los índices:** la prueba de inserción de 500 filas en `detalle_pedido` dio 16 ms sin índice y 15 ms con índice (diferencia dentro del ruido). La medición repetida con 50.000 filas está **pendiente de completar** en el informe de optimización (marcada `[COMPLETAR]`); por eso este informe no cita un costo de inserción.

---

## 5. Uso de otras herramientas de IA

Las herramientas indicadas por la cátedra (OpenCode con distintos modelos y Kiro) se declaran, una por una, en las DUIA de cada parte: [`duia_parte1.md`](duia/duia_parte1.md), [`duia_parte2.md`](duia/duia_parte2.md), [`duia_parteB_vistas.md`](duia/duia_parteB_vistas.md), [`duia_vista_materializada.md`](duia/duia_vista_materializada.md) y [`duia_tp5.md`](duia/duia_tp5.md). Decisiones destacadas de esas partes:

| Parte | Aceptado | Descartado / corregido |
| :--- | :--- | :--- |
| TP5, consulta 1 | — | Los 2 índices propuestos: el plan real era igual; la explicación de la IA (cambiaría el acceso a `pedidos`) resultó **incorrecta** |
| TP5, consulta 2 | `idx_pedidos_cobranza` tal cual | La variante con `estado IN (…)`: la consulta agrupa por *todos* los estados |
| TP5, consulta 3 | Índice compuesto parcial | La IA anunció Index Only Scan y el plan real fue Bitmap Heap Scan + Sort: se agregó `id` al `INCLUDE`; índice simple sobre `cliente_id` descartado por redundante |
| Vistas | Versión de OpenCode como definitiva | La versión propia se conservó como evidencia; ambas se verificaron con `EXCEPT` |

**Herramienta adicional — Claude Code (Anthropic, modelo Claude Sonnet 5.5):** **no figura entre las indicadas por la cátedra.** Se usó para atender la devolución del docente: reorganizar y renombrar los archivos, redactar el modelo ER, el paso a relacional y la normalización, desarrollar las funciones y procedimientos PL/pgSQL, los scripts de transacciones y borrado lógico, las consultas nuevas del script 05 y este informe. Declaración completa en [`duia_tpi_entrega1.md`](duia/duia_tpi_entrega1.md). Decisiones tomadas:

* **Aceptado:** procedimientos sin `COMMIT` interno (la atomicidad la da el llamador); reserva de stock al crear el pedido y devolución al cancelar; bloqueo `FOR UPDATE` en orden de `id`.
* **Descartado:** duplicar en el procedimiento la validación de transiciones (ya la hace el trigger); modificar el esquema entregado para cambiar `UNIQUE` por un índice único parcial (se demuestra y se deja a decisión del equipo); presentar el esquema como BCNF sin aclarar que `subtotal` y `total` son atributos derivados.
* **Corregido con respecto a la versión anterior de la entrega:** nombres de archivos que ocultaban qué objetivo cubrían (p. ej. `informe_mediciones.md` era en realidad la comparación de vistas) y consultas del script 05 que no incluían `HAVING`.

---

## 6. Limitaciones conocidas y puntos a decidir

1. `pedidos.total` es un atributo derivado **sin restricción declarativa**: depende de `sp_crear_pedido` (auditable con `fn_total_pedido`). Un trigger sobre `detalle_pedido` lo blindaría.
2. `UNIQUE` sobre `productos.nombre`, `clientes.mail` y `categorias.nombre` abarca también filas dadas de baja (ver 3.3).
3. El mínimo de un renglón por pedido (participación total de `PEDIDO` en `CONTIENE`) lo garantiza el procedimiento, no el DDL.
4. Medición de inserción por lotes de 50.000 filas pendiente en el informe de optimización (sección 4).
