# DUIA — Declaración de Uso de IA (TP8)

Equipo: Agustina Fontagnol, Gianella Peña, Martina Suarez. El relato de cada uso está en `bitacora_ia.md`.

## Parte A — Esquema SQLite (`movil/schema_sqlite.sql`)

| Campo | Completar |
| :--- | :--- |
| **Herramienta** | OpenCode (Claude Sonnet 4.5, desde Kiro) |
| **Spec o prompt utilizado** | "Arma el schema SQL para SQLite con estas 4 tablas: 1. producto_cache: snapshot de productos del servidor (id INTEGER PK, nombre TEXT, precio_centavos INTEGER, stock_visto INTEGER, disponible INTEGER como booleano, eliminado INTEGER como booleano, fecha_copia TEXT ISO8601). 2. pedido_borrador: id_local TEXT PK (UUID), usuario, forma_pago con CHECK de valores válidos, fecha. 3. item_borrador: id_local FK a pedido_borrador, producto_id FK a producto_cache, cantidad con CHECK > 0, precio_centavos_visto, PK compuesta (id_local, producto_id). 4. cola_sync: solicitud_uuid TEXT PK, id_local FK a pedido_borrador, estado con CHECK (PENDIENTE, CONFLICTO, RECHAZADO, SIMULADO_APROBADO), motivo nullable, fecha_creacion. Requisitos: todas STRICT, PRAGMA foreign_keys = ON, índices idx_producto_cache_disponible, idx_cola_sync_estado, idx_item_borrador_id_local, ON DELETE CASCADE para item_borrador.id_local y ON DELETE RESTRICT para item_borrador.producto_id." |
| **Qué generó** | El script con las cuatro tablas STRICT, los CHECK, las FK, el PRAGMA, tres índices y comentarios. |
| **Qué se aceptó** | Estructura de las tablas, todos los CHECK, las FK con sus acciones y los tres índices. |
| **Qué se modificó o descartó, y por qué** | Se agregó `DEFAULT (datetime('now'))` en las fechas para no pasarlas en cada INSERT. Se descartó `AUTOINCREMENT`: el id del producto viene del servidor y `id_local` es UUID. |
| **Verificación realizada** | `pruebas_sqlite.sql`: borrador completo con COMMIT, ROLLBACK que no deja filas, cantidad 0 → `CHECK constraint failed: cantidad > 0`, producto 999 → `FOREIGN KEY constraint failed`; `PRAGMA foreign_key_check` sin filas. |

## Parte B — Semáforo (`movil/semaforo.sql`) y simulador (`movil/simulador_casos.py`)

| Campo | Completar |
| :--- | :--- |
| **Herramienta** | OpenCode (Claude Sonnet 4.5) para la primera versión; Claude Code para la revisión final |
| **Spec o prompt utilizado** | "Implementá el semáforo de validación en SQLite que compare los borradores locales contra snapshot_servidor (id, nombre, precio_centavos, stock_visto) y actualice cola_sync: RECHAZADO si el producto no existe en el snapshot o cantidad > stock; CONFLICTO si el precio visto es distinto del actual; SIMULADO_APROBADO si todo está bien. Guardar un motivo descriptivo, procesar solo las solicitudes PENDIENTE y validar en orden: primero RECHAZADO, luego CONFLICTO, finalmente APROBADO." |
| **Qué generó** | `semaforo.sql` con la lógica de los tres estados y un simulador en Python para los casos. |
| **Qué se aceptó** | El orden rojo, amarillo, verde; el `LEFT JOIN` a la instantánea; el motivo con valores concretos; el filtro por PENDIENTE. |
| **Qué se modificó o descartó, y por qué** | Se agregaron las reglas de producto no disponible y dado de baja (la consigna las pide). Se corrigió el motivo de precio, que daba `0` por la precedencia de `\|\|` frente a `/`. Se descartó la copia del SQL dentro del simulador: ahora ejecuta `semaforo.sql`. |
| **Verificación realizada** | `python movil/simulador_casos.py` reconstruye la base y corre C2 a C6: CONFLICTO y luego SIMULADO_APROBADO, RECHAZADO (stock), RECHAZADO (baja), SIMULADO_APROBADO, UUID repetido rechazado sin reevaluar. |

## Parte C — Code review (informe, consigna 3.c)

| Campo | Completar |
| :--- | :--- |
| **Herramienta** | OpenCode (Claude Sonnet 4.5), agente Plan |
| **Spec o prompt utilizado** | "Lee los scripts SQL de la cursada (parcial1_02_reglas_negocio_check_unique_triggers.sql, parcial1_03_ddl_indices.sql, parcial1_08_funciones_procedimientos_plpgsql.sql, parcial1_09_transacciones.sql, parcial1_10_borrado_logico.sql) y detecta problemas de diseño, seguridad, rendimiento o mantenibilidad. Prioriza hallazgos de diferentes unidades (U2 Índices, U3 Transacciones, U4 Vistas, U6 Seguridad). Para cada hallazgo indicá: archivo afectado, descripción del problema, decisión sugerida (ACEPTAR, CORREGIR o DESCARTAR con fundamento) y verificación en base de datos." |
| **Qué generó** | Cinco hallazgos de cuatro unidades: race condition en `sp_crear_pedido`, índice parcial sin predicado, CHECK en vista materializada, contraseñas en texto plano en datos de prueba e índice faltante en `pedidos.fecha`. |
| **Qué se aceptó** | El hallazgo de contraseñas en texto plano (U6); el cambio (hash falso con formato bcrypt y comentario de seguridad) se aplicó en `parcial1_09` y `parcial1_10`. |
| **Qué se modificó o descartó, y por qué** | Descartados: 1 (el `ORDER BY 1` ordena los bloqueos), 3 (PostgreSQL no admite CHECK en vistas materializadas) y 5 (el índice compuesto existente cubre el rango). El 2 ya estaba mitigado con vistas. |
| **Verificación realizada** | Repetida el 2026-11-03 en una copia descartable de `foodstore_desarrollo` con `parcial1_03`, `_06`, `_07` y `_08` aplicados: dos sesiones de psql sobre el producto 7; `EXPLAIN (ANALYZE)` con y sin predicado y para el rango de enero de 2026; `CREATE MATERIALIZED VIEW ... CHECK` (error de sintaxis); INSERT con subtotal negativo rechazado por `chk_detalle_subtotal`; ejecución de `parcial1_09` y `_10` con el hash nuevo. |

## Parte D — Mapa de los tres motores y plan de mantenimiento (informe, 3.a y 3.b)

| Campo | Completar |
| :--- | :--- |
| **Herramienta** | OpenCode (Claude Sonnet 4.5) para el borrador; Claude Code para ajustarlo a los archivos reales |
| **Spec o prompt utilizado** | "Crea un mapa de arquitectura que explique: los 3 motores (PostgreSQL servidor central, MongoDB analytics y reportes, SQLite cache offline en la tablet); quién controla precio, stock, pedidos confirmados y borradores; el flujo PostgreSQL → MongoDB, PostgreSQL → SQLite y SQLite → PostgreSQL; y una tabla comparativa. Extiende el plan de mantenimiento de la Unidad 6: qué se respalda y cómo se prueba la restauración, qué hacen las tablets si se restaura un respaldo viejo de PostgreSQL, y cada cuánto y quién revisa las solicitudes en CONFLICTO o RECHAZADO." |
| **Qué generó** | Mapa con tabla y diagrama, reglas de sincronización y un plan de respaldos con comandos y calendario. |
| **Qué se aceptó** | PostgreSQL como única fuente de verdad, flujo en un solo sentido, no respaldar SQLite y la repetición del semáforo con una instantánea nueva tras restaurar. |
| **Qué se modificó o descartó, y por qué** | Se descartó Redis como cuarto motor (fuera de alcance) y `pg_cron` con archivado de WAL (la Unidad 6 usa un script de `pg_dump`). Se quitaron datos inventados (versión de MongoDB, cantidad de productos, tamaño del respaldo) y el plan se alineó con los archivos de U6 y U7. |
| **Verificación realizada** | Cotejo con `entrega_tp6/sql` (respaldo y simulacro de restauración) y con `entrega_tp7/modelo_documental.md` (colección `foodstore_u7.pedidos`). |

## Parte E — Spec en Kiro (`docs/kiro/`)

| Campo | Completar |
| :--- | :--- |
| **Herramienta** | Kiro, con ajuste final de Claude Code |
| **Spec o prompt utilizado** | "Crea una especificación de requisitos usando el patrón EARS con al menos 4 requisitos, cada uno con el caso que lo prueba, y un design.md y tasks.md breves, antes de generar el esquema y la simulación." |
| **Qué generó** | `requirements.md` con requisitos EARS, requisitos no funcionales y casos de uso; `design.md` y `tasks.md`. |
| **Qué se aceptó** | El patrón EARS y la matriz de trazabilidad. |
| **Qué se modificó o descartó, y por qué** | Se descartó el requisito de cifrado en reposo (fuera de alcance) y el material extenso. Los requisitos se rehicieron como REQ-01 a REQ-04, ligados a C2, C3, C4 y C6; `design.md` y `tasks.md` se acortaron. |
| **Verificación realizada** | Cada requisito se corresponde con un caso que corre `simulador_casos.py` y da el resultado esperado. |

## Parte F — Orden final de la entrega

| Campo | Completar |
| :--- | :--- |
| **Herramienta** | Claude Code |
| **Spec o prompt utilizado** | "Según las consignas del PDF quiero que ordenes el contenido de esta carpeta para que cumpla con todo lo pedido. Si hay información repetida ordenala que solo aparezca una vez, crea el csv que falta y la DUIA ya está pero dentro del informe y además repetida en la bitácora. Deja cada archivo con lo necesario y con su nombre correspondiente." |
| **Qué generó** | La estructura final, `servidor_snapshot.csv`, `carga_snapshot.sql`, el `simulador_casos.py` que ejecuta los scripts, `informe.pdf`, `docs/kiro/`, esta DUIA, la bitácora y el README. |
| **Qué se aceptó** | La estructura de carpetas y la reconstrucción de la base desde los scripts. |
| **Qué se modificó o descartó, y por qué** | `servidor_snapshot.csv` se exportó de la vista en `foodstore_desarrollo`, tras un `pg_dump` de respaldo. Se eliminaron `crear_y_probar_db.py`, `code_review_ia.md` y `informe_tp8.md` porque repetían lo que ya está en los scripts y el informe. |
| **Verificación realizada** | Se reconstruyó `foodstore_movil.db` desde cero con `python movil/simulador_casos.py`: los seis resultados coinciden con lo esperado. En PostgreSQL solo se creó la vista y se exportó el CSV; pedidos, detalles, stock, precios y huella md5 de los productos 1 a 10 son idénticos antes y después. |

## Parte G — Ronda de mejoras tras la corrección

| Campo | Completar |
| :--- | :--- |
| **Herramienta** | Claude Code |
| **Spec o prompt utilizado** | "Los cambios del servidor de C2 y C4 se emularon editando snapshot_servidor en SQLite y no en PostgreSQL, lo que contradice la consigna 3.1. Los UUID de los casos no son UUID reales. Falta el índice único parcial de cola_sync y el registro de evaluaciones. C3 pide más que la copia local. Solo hay 4 requisitos EARS. No hay inventario U1–U8. No hay guion de defensa. Revisa de a una las mejoras e implementalas." |
| **Qué generó** | `simulador_casos.py` con los cambios hechos en PostgreSQL (BEGIN, exportación de la vista, ROLLBACK); UUID v4 reales y `CHECK` de formato; `ux_cola_sync_una_pendiente`, `evaluacion_sync` y su trigger; `snapshot_servidor` dentro del esquema; casos nuevos en `pruebas_sqlite.sql`; `requirements.md` ampliado; `inventario_scripts.md`; `guion_defensa.md`; actualización de README, bitácora y DUIA. |
| **Qué se aceptó** | La transacción con `ROLLBACK` para cada caso, el `CHECK` con `GLOB`, el índice único parcial sobre `id_local WHERE estado = 'PENDIENTE'` y el trigger de registro. |
| **Qué se modificó o descartó, y por qué** | Se evaluó y descartó confirmar los cambios en PostgreSQL y revertirlos a mano (queda la copia modificada si algo falla). C3 pasó de 140 unidades sin cambios en el servidor a 50 unidades con el stock del servidor bajado a 10. `--emular` queda solo como plan B. En el inventario se quitaron descripciones que no se habían comprobado leyendo cada script. |
| **Verificación realizada** | `sqlite3 ... ".read pruebas_sqlite.sql"`: UUID inválido → `CHECK constraint failed`; segunda solicitud PENDIENTE → `UNIQUE constraint failed: cola_sync.id_local`; sin filas nuevas. `python movil/simulador_casos.py`: resultado esperado en cada caso, 6 evaluaciones para 6 solicitudes y control de PostgreSQL igual antes y después. |

