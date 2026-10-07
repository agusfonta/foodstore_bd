# DUIA — Parcial 1 (TPI «Food Store», primera entrega parcial): correcciones de la entrega

**Proyecto:** Food Store — PostgreSQL 16+ (probado en 17.11)
**Fecha:** 2026-10-07
**Contexto:** devolución del docente sobre la primera entrega: faltaban *modelo ER, paso a modelo relacional, normalización con dependencias funcionales, procedimientos almacenados invocados con `CALL` e informe técnico del TPI*; además el repositorio se leía como «TP5» y no como entrega del TPI.
**Informe asociado:** [`Informe_Parcial_1.md`](../../Informe_Parcial_1.md)

> Esta DUIA se suma a las de las partes anteriores (`duia_parte1.md`, `duia_parte2.md`, `duia_parteB_vistas.md`, `duia_vista_materializada.md`, `duia_tp5.md`), que usaron OpenCode y Kiro.

---

## Uso 1 — Reorganización de archivos para que cada objetivo sea identificable

| Campo | Descripción |
| :--- | :--- |
| **Herramienta** | Claude Code (Anthropic), modelo Claude Sonnet 5.5 — **no es una de las herramientas indicadas por la cátedra (OpenCode / Kiro)** |
| **Spec o prompt utilizado** | Pedido del equipo: agregar o corregir lo que señaló el docente; si algo ya estaba resuelto en un archivo con otro nombre, renombrarlo según la consigna del aula virtual (los 9 objetivos y el informe técnico) para que el docente lo identifique fácilmente. Se adjuntaron capturas de la consigna y la corrección escrita. |
| **Qué generó** | Renombres con `git mv` (se conserva el historial) y actualización de las referencias cruzadas en `docs/`, `spec/` y `db/`: `schema.sql → parcial1_01_ddl_schema.sql`, `restricciones.sql → parcial1_02_reglas_negocio_check_unique_triggers.sql`, `indices.sql → parcial1_03_ddl_indices.sql`, `carga_masiva.sql → parcial1_04_dml_carga_masiva.sql`, `queries.sql → parcial1_05_dml_consultas.sql`, `views.sql → parcial1_06_vistas.sql`, `vista_materializada.sql → parcial1_07_vista_materializada.sql`; `docs/informe_mediciones.md → docs/informes/parcial1_informe_equivalencia_vistas.md` (el nombre anterior sugería mediciones de rendimiento pero el archivo compara vistas); `Informes_tps/TP5_Informe_mediciones.md → Informes_tps/Parcial1_Informe_optimizacion_consultas_indices.md` |
| **Qué se aceptó** | Todos los renombres. El contenido de los scripts renombrados no cambió (solo las rutas citadas en comentarios) |
| **Qué se modificó o descartó, y por qué** | Los archivos auxiliares de partes anteriores **no se borraron**: se agruparon en `db/anexos_tps/` (`vistas_reportes_prompt_*.sql`, `parte5_competencia.sql`, `tp5_mediciones_pendientes.sql`, `benchmark_vista_materializada.sql`, `verificacion_vistas_parteB.sql`) y los informes de partes anteriores en `docs/informes/`; se eliminaron los `.DS_Store` versionados y se agregó `.gitignore`. Se conservó el texto histórico «Script.sql» dentro de las DUIA antiguas porque transcribe el prompt original |
| **Verificación realizada** | `git status` muestra los movimientos como *renamed*; las rutas citadas en los `.md`/`.sql` fueron reemplazadas con búsqueda por patrón y revisadas con `git diff`; los scripts renombrados se cargaron sin errores en PostgreSQL 17.11 (ver informe técnico, sección 3) |

## Uso 2 — Modelo ER, paso a modelo relacional y normalización (objetivos 1, 2 y 3)

| Campo | Descripción |
| :--- | :--- |
| **Herramienta** | Claude Code (Anthropic), Claude Sonnet 5.5 |
| **Spec o prompt utilizado** | Mismo pedido que el Uso 1, punto «faltan: el modelo ER, el paso a modelo relacional, la normalización con dependencias funcionales». Se le dio como fuente de verdad el DDL real del repositorio (`parcial1_01_ddl_schema.sql` y `parcial1_02_reglas_negocio_check_unique_triggers.sql`) |
| **Qué generó** | `docs/parcial1_01_modelo_er.md` (entidades, atributos, claves, cardinalidad y participación, diagrama Mermaid), `docs/parcial1_02_modelo_relacional.md` (reglas de transformación, 1:N y N:M con tabla intermedia, verificación contra `pg_constraint`) y `docs/parcial1_03_normalizacion.md` (UNF → 1FN → 2FN → 3FN/BCNF con dependencias funcionales numeradas) |
| **Qué se aceptó** | La estructura de los tres documentos y el modelado de `detalle_pedido` como relación N:M con atributos propios |
| **Qué se modificó o descartó, y por qué** | Se **descartó** presentar el esquema como «BCNF sin matices»: `detalle_pedido.subtotal` y `pedidos.total` son atributos derivados que, estrictamente, violan 3FN. Se documentan como **desnormalización deliberada** con su protección (`CHECK chk_detalle_subtotal_coherente`; `total` calculado por `sp_crear_pedido` y auditable con `fn_total_pedido`) y se aclara que `total` **no** tiene restricción declarativa. También se aclara que `precio_unitario` no es dependencia parcial de `producto_id` (es el precio histórico de la venta) y que la participación mínima 1 de `PEDIDO` en `CONTIENE` es regla aplicada por el procedimiento, no por el DDL |
| **Verificación realizada** | La lista de PK/FK/UNIQUE del documento 02 se obtuvo con una consulta a `pg_constraint` sobre una base creada con los scripts 01 y 02: 5 PK, 4 FK, 4 claves candidatas. Consulta de coherencia de `pedidos.total` sobre la carga masiva (200.000 pedidos): 0 filas incoherentes |

## Uso 3 — Funciones y procedimientos PL/pgSQL, transacciones y borrado lógico (objetivos 5, 6, 8 y 9)

| Campo | Descripción |
| :--- | :--- |
| **Herramienta** | Claude Code (Anthropic), Claude Sonnet 5.5 |
| **Spec o prompt utilizado** | Mismo pedido que el Uso 1, punto «faltan los procedimientos almacenados invocados con CALL», más la lista de objetivos 5, 6, 8 y 9 de la consigna |
| **Qué generó** | `db/parcial1_08_funciones_procedimientos_plpgsql.sql` (3 funciones y 5 procedimientos: `sp_crear_pedido` con parámetro `JSONB` e `INOUT`, `sp_cambiar_estado_pedido`, `sp_baja_logica_producto`, `sp_baja_logica_cliente`, `sp_refrescar_facturacion_categoria_mes`); `db/parcial1_09_transacciones.sql`; `db/parcial1_10_borrado_logico.sql`; y consultas nuevas al final de `db/parcial1_05_dml_consultas.sql` (`HAVING`, `NOT EXISTS`, `LAG`/`SUM OVER`, `ROW_NUMBER`, `INSERT`/`UPDATE` dentro de `BEGIN…ROLLBACK`) porque el archivo original no tenía ningún `HAVING` |
| **Qué se aceptó** | Los 5 procedimientos y 3 funciones; el control de concurrencia con `SELECT … FOR UPDATE` ordenado por `id` (evita deadlocks); reservar stock al crear el pedido y devolverlo al cancelar |
| **Qué se modificó o descartó, y por qué** | (a) Los procedimientos **no** hacen `COMMIT`/`ROLLBACK` internos: la atomicidad la da la transacción del llamador y un error revierte todo el `CALL`. (b) La validación de transiciones de estado **no** se duplicó en el procedimiento: la hace el trigger existente del script 02. (c) Se **descartaron** los bloques `DO $$ … $$` para demostrar errores y las variables de psql (`\gset`): los scripts de prueba usan `SAVEPOINT` + `set_config()` para que funcionen igual en psql y en DBeaver. (d) Se **descartó modificar el esquema entregado** para reemplazar `UNIQUE (nombre)` por un índice único parcial `WHERE eliminado = FALSE`; el problema (un producto dado de baja sigue ocupando su nombre) se demuestra en `parcial1_10_borrado_logico.sql` y la solución se prueba dentro de `BEGIN…ROLLBACK`, dejando la decisión al equipo |
| **Verificación realizada** | Los tres scripts se ejecutaron completos en una instancia temporal de PostgreSQL 17.11 (puerto 55432; no se tocaron `foodstore` ni `foodstore_desarrollo`) y cada paso mostró el resultado esperado indicado en los comentarios. Prueba con **dos sesiones simultáneas**: dos `CALL sp_crear_pedido` por la última unidad de stock — la segunda quedó bloqueada (`wait_event_type = Lock`, `wait_event = transactionid`) y al confirmar la primera falló con «Stock insuficiente»; resultado final: stock 0 y un solo pedido. Resultados detallados en `Informe_Parcial_1.md`, sección 3 |

## Uso 4 — Informe técnico del TPI

| Campo | Descripción |
| :--- | :--- |
| **Herramienta** | Claude Code (Anthropic), Claude Sonnet 5.5 |
| **Spec o prompt utilizado** | Los cinco puntos que pide la consigna para el informe técnico (qué elementos por unidad, cómo se probó, resultados, consultas optimizadas antes/después, uso de IA) |
| **Qué generó** | `Informe_Parcial_1.md`, `README.md` (índice y checklist de los 9 objetivos) y esta DUIA |
| **Qué se aceptó** | La organización por unidad y la tabla «objetivo → archivo → cómo verificarlo» |
| **Qué se modificó o descartó, y por qué** | Las cifras de optimización **no se inventaron ni se recalcularon**: se citan tal cual de `Informes_tps/Parcial1_Informe_optimizacion_consultas_indices.md`, `docs/informes/parcial1_benchmark_resultados.md` y de los informes TP3/TP4. Excepción: la tabla de inserción por lotes (50.000 filas) se completó con una **medición real** hecha en una instancia temporal de PostgreSQL 17.11 (mediana de 5 corridas: 973,4 ms sin índice, 1052,1 ms con índice), con el entorno indicado en el informe |
| **Verificación realizada** | Cada cifra del informe técnico se contrastó contra el archivo fuente citado; los resultados de pruebas de los scripts 08–10 son la salida real de psql |
