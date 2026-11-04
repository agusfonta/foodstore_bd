# Informe técnico — Segunda entrega del TPI «Food Store» (Unidades 4 a 8)

**Materia:** Base de Datos II · **Equipo:** Agustina Fontagnol, Gianella Peña, Martina Suarez
**Motores:** PostgreSQL 17.11 (PL/pgSQL), MongoDB (mongosh), SQLite 3.54 · **Fecha:** 4 de noviembre de 2026
**Condiciones que responde:** [`consignas/Condiciones_de_Entrega_TPI_Segunda_entrega.pdf`](consignas/Condiciones_de_Entrega_TPI_Segunda_entrega.pdf)

Todo se hizo con datos de prueba y sobre la copia `foodstore_desarrollo`, nunca sobre `foodstore` (protocolo en [`ia/protocolo_seguridad.md`](ia/protocolo_seguridad.md)). Las rutas de este informe son relativas a la raíz del repositorio salvo que se indique otra cosa; el mapa completo de evidencia está en el [`README.md`](../README.md).

---

## 1. Qué se implementó en cada unidad

### Unidad 4 · Normalización avanzada y redundancia

Resuelta con el TP «Normalización Avanzada y Redundancia» ([`informes/informe_u4_fnbc_desnormalizacion.pdf`](informes/informe_u4_fnbc_desnormalizacion.pdf)) y dos scripts en [`../postgres/normalizacion/`](../postgres/normalizacion/README.md).

| Objetivo del PDF | Qué hay | Dónde |
| :-- | :-- | :-- |
| Refactor hasta Boyce-Codd validado contra las dependencias funcionales | Extensión mayorista del dominio: `control_lote_almacen(lote_id, deposito_id, responsable_control_id)`. Dependencias `{lote, depósito} → responsable` y `responsable → depósito`; claves candidatas `{lote, depósito}` y `{lote, responsable}` (los tres atributos son primos); **viola FNBC** porque `responsable` no es superclave. Se describen las tres anomalías (inserción: responsable 803 sin lote; borrado: lote 503 es la única evidencia de 802 en el depósito 31; actualización: traslado de 801 en dos filas) y se descompone en `responsable_deposito` y `control_lote` | Informe U4 (parte 1), [`tp_fnbc_control_lote.sql`](../postgres/normalizacion/tp_fnbc_control_lote.sql); antecedente teórico del esquema general en [`modelo/parcial1_03_normalizacion.md`](modelo/parcial1_03_normalizacion.md) |
| Migración sin pérdida, transacción reversible, plan de reversión | Sin pérdida por el teorema de Heath (el atributo común `responsable_control_id` es clave de `responsable_deposito`); la vista `v_control_lote_almacen` reconstruye la instancia original mediante reunión natural. Migración con verificación por `EXCEPT` y plan de reversión dentro de `BEGIN … ROLLBACK` | Spec Kiro: [`../specs/normalizacion/`](../specs/normalizacion/requirements.md) (11 requisitos EARS y tareas). Informe U4 (4.2.e y 4.2.f), [`tp_fnbc_migracion_y_reversion.sql`](../postgres/normalizacion/tp_fnbc_migracion_y_reversion.sql) (creado al integrar la unidad; ejecutado el 04/11/2026: equivalencia con 0 y 0 filas, ver [`informes/evidencias_u4_ejecucion.md`](informes/evidencias_u4_ejecucion.md)) |
| Desnormalización controlada: cuándo, por qué y con qué salvaguardas | Consulta del top 5 de categorías del día (4 `JOIN`): **157,459 ms**. Se elige la vista materializada `mv_top_categorias_dia` con índice único `(categoria, fecha)` y `REFRESH MATERIALIZED VIEW CONCURRENTLY` (no bloquea lecturas): **0,177 ms** en el informe y, repetido el 04/11/2026 en `foodstore_desarrollo`, 121,009 ms → 0,357 ms. Es reversible con `DROP MATERIALIZED VIEW`. Un script de auditoría compara la vista con la fuente y devuelve 0 filas. Antecedentes del proyecto: `subtotal`, `total`, borrado lógico | Informe U4 (parte 2), [`tp_desnormalizacion_top_categorias.sql`](../postgres/normalizacion/tp_desnormalizacion_top_categorias.sql), [`modelo/parcial1_03_normalizacion.md`](modelo/parcial1_03_normalizacion.md) (secciones 5 y 6), [`informes/parcial1_politica_refresh.md`](informes/parcial1_politica_refresh.md) |

### Unidad 5 · Administración y seguridad

- **Roles de mínimo privilegio** ([`../postgres/seguridad/roles.sql`](../postgres/seguridad/roles.sql), spec Kiro en [`../specs/seguridad/kiro_roles/`](../specs/seguridad/kiro_roles/)). Roles de grupo `rol_app_lectura`, `rol_app_escritura` (sin `DELETE` ni `TRUNCATE`), `rol_soporte` (permiso por columna sobre `clientes`) y `rol_reportes`; roles de login `app_web` (`SCRAM-SHA-256`, `CONNECTION LIMIT`) y `admin_datos`; `ALTER DEFAULT PRIVILEGES` y script idempotente.
- **Auditoría y simulacro de acceso indebido.** Parámetros de log activados (`log_connections`, `log_disconnections`, `log_statement = 'mod'`, `log_failed_auth`, `log_min_duration_statement`, `log_line_prefix`); secuencia de prueba en [`../postgres/seguridad/auditoria_test.sql`](../postgres/seguridad/auditoria_test.sql) y simulacro de cuatro fases (3 logins fallidos, login correcto, lectura masiva de `clientes`, intento de escalamiento) en [`../postgres/seguridad/simulacro_incidente.sql`](../postgres/seguridad/simulacro_incidente.sql). Se reconstruyó el incidente desde el log y se propuso contención: [`informes/informe_incidente_acceso_indebido.md`](informes/informe_incidente_acceso_indebido.md).
- **Auditoría de seguridad asistida por IA con decisión humana:** [`informes/informe_auditoria_permisos.md`](informes/informe_auditoria_permisos.md) y [`ia/duia_u5_seguridad_roles.md`](ia/duia_u5_seguridad_roles.md) (la IA marcó 6 áreas de mejora de `roles.sql`; cada una quedó aceptada o descartada con motivo).
- **Privacidad:** [`../postgres/seguridad/usuario_anon.sql`](../postgres/seguridad/usuario_anon.sql) crea `clientes_anon` con datos enmascarados para compartir con asistentes de IA.

### Unidad 6 · Mantenimiento

- **Plan automatizado** ([`../specs/mantenimiento/SPEC_U6.md`](../specs/mantenimiento/SPEC_U6.md)): respaldo con `pg_dump -Fc` y log ([`../postgres/mantenimiento/backup_foodstore.ps1`](../postgres/mantenimiento/backup_foodstore.ps1)), restauración probada ([`restore_test.ps1`](../postgres/mantenimiento/restore_test.ps1)), chequeo diario de solo lectura ([`health_check.sql`](../postgres/mantenimiento/health_check.sql)) y revisión semanal de autovacuum y estadísticas ([`maintenance.sql`](../postgres/mantenimiento/maintenance.sql)).
- **Simulacro de desastre contra reloj** con informe post-incidente: [`informes/informe_u6_mantenimiento.pdf`](informes/informe_u6_mantenimiento.pdf) y salidas reales en [`informes/evidencias_u6_mantenimiento.md`](informes/evidencias_u6_mantenimiento.md).

### Unidad 7 · NoSQL

- **Modelo documental** de los pedidos (cliente y líneas embebidas): [`informes/modelo_documental_u7.md`](informes/modelo_documental_u7.md). Se exportan los pedidos 1 a 10 de PostgreSQL ([`../mongodb/sql/exportar_pedidos_json.sql`](../mongodb/sql/exportar_pedidos_json.sql) → [`datos/pedidos.jsonl`](../mongodb/datos/pedidos.jsonl)) y se cargan en `foodstore_u7.pedidos` con [`migrar_pedidos.js`](../mongodb/migrar_pedidos.js).
- **Consultas verificadas sobre datos reales:** cada consulta de [`consultas_mongodb.js`](../mongodb/consultas_mongodb.js) tiene su equivalente en [`consultas_postgresql.sql`](../mongodb/consultas_postgresql.sql) y se comparan en [`informes/tabla_verificacion_u7.md`](informes/tabla_verificacion_u7.md). [`verificacion_integridad.js`](../mongodb/verificacion_integridad.js) comprueba en MongoDB las reglas que PostgreSQL impone con restricciones.
- **Comparación documental vs relacional:** [`informes/ia_contraste_u7.md`](informes/ia_contraste_u7.md) y [`informes/informe_u7_nosql.pdf`](informes/informe_u7_nosql.pdf).

### Unidad 8 · Bases móviles e integración

- **Base SQLite de la tablet** ([`../movil/schema_sqlite.sql`](../movil/schema_sqlite.sql)): tablas `STRICT`, UUID v4 forzado con `CHECK`, índice único parcial `ux_cola_sync_una_pendiente`, `snapshot_servidor` y registro `evaluacion_sync` cargado por trigger. Spec en [`../specs/movil/`](../specs/movil/) (11 requisitos EARS). Regla de oro: *el móvil propone, el servidor dispone*; `SIMULADO_APROBADO` no es una venta.
- **Sincronización simulada con conflictos** ([`../movil/simulador_casos.py`](../movil/simulador_casos.py), [`semaforo.sql`](../movil/semaforo.sql)): seis casos (precio cambiado, stock insuficiente, producto dado de baja, sin cambios, reenvío del mismo UUID) con resultado esperado y obtenido.
- **Code review final asistido por IA** de los 35 scripts de la cursada, 14 hallazgos con decisión humana: [`informes/informe_u8_movil.pdf`](informes/informe_u8_movil.pdf) e [`informes/inventario_scripts.md`](informes/inventario_scripts.md).
- **Capa de datos completa:** PostgreSQL → MongoDB (copia de lectura) y PostgreSQL → SQLite (instantánea CSV); guion de defensa en [`defensa/guion_defensa.md`](defensa/guion_defensa.md).

---

## 2. Cómo se probó

| Mecanismo | Dónde se aplicó |
| :-- | :-- |
| **Transacciones reversibles** (`BEGIN … ROLLBACK`) | Simulador de U8: cada cambio del servidor (precio, stock, baja) se hace en PostgreSQL dentro de una transacción, se exporta la vista y se revierte; la huella `md5(id, precio, stock, eliminado)` es idéntica antes y después. En U7, los tres `INSERT` inválidos en PostgreSQL se probaron con `BEGIN`/`ROLLBACK` |
| **Copias de prueba** | `foodstore_desarrollo` (trabajo), `foodstore_restore_test` (restauración descartable), `foodstore_u7` en MongoDB, base temporal SQLite del simulador |
| **Simulacro de acceso indebido** | Cuatro fases sobre `foodstore_desarrollo`; el escalamiento `GRANT admin_datos TO rol_app_lectura` fue denegado. Capturas en [`evidencias/seguridad/`](evidencias/seguridad/) |
| **Simulacro de desastre** | `restore_test.ps1` restaura el último `.dump` en una base nueva, compara conteos con la de trabajo y valida restricciones lógicas |
| **Conflictos de sincronización** | Casos C1 a C7 en [`../movil/pruebas_sqlite.sql`](../movil/pruebas_sqlite.sql) y [`simulador_casos.py`](../movil/simulador_casos.py) |

### Verificación de esta reorganización (4 de noviembre de 2026)

Tras mover los archivos a la estructura definitiva se volvieron a ejecutar desde las rutas nuevas:

| Prueba | Resultado |
| :-- | :-- |
| `postgres/mantenimiento/restore_test.ps1` | OK: conteos 5 / 20 000 / 50 000 / 200 000 / 600 000 iguales; `productos_invalidos = 0`, `detalles_invalidos = 0`; **RTO 13,5 s** |
| `postgres/mantenimiento/backup_foodstore.ps1` | OK: `backups/foodstore_20261104_103047.dump` (10 639,86 KB) |
| `movil/pruebas_sqlite.sql` sobre copia de la base | Funciona: los errores esperados (`CHECK cantidad > 0`, `FOREIGN KEY`, UUID inválido, `UNIQUE` en `cola_sync`) se producen |
| `python movil/simulador_casos.py --emular` | Los 6 casos dan el resultado esperado |
| `mongosh mongodb/migrar_pedidos.js`, `verificacion_integridad.js`, `consultas_mongodb.js` | 10 documentos insertados; las 4 verificaciones de integridad dan 0; consultas correctas |
| Enlaces `.md` | 0 enlaces rotos |

**No se ejecutaron en esta verificación** (requieren conectarse a PostgreSQL con contraseña desde una sesión distinta de los scripts del proyecto): `health_check.sql`, `maintenance.sql`, `vista_snapshot.sql`, `simulador_casos.py` contra PostgreSQL y `exportar_pedidos_json.sql`. Sus últimas ejecuciones registradas son las de las entregas originales.

---

## 3. Resultados

| Resultado | Valor | Fuente |
| :-- | :-- | :-- |
| RTO del simulacro de desastre original (21/10/2026) | **14,8 s** (createdb + restore + validaciones) | `logs/restore_test.log`, [`informes/informe_u6_mantenimiento.pdf`](informes/informe_u6_mantenimiento.pdf) |
| RTO repetido tras la reorganización (04/11/2026) | **13,5 s** | `logs/restore_test.log` |
| Tamaño del respaldo | ≈ 10,4 MB (`.dump` formato custom) | `logs/backup_foodstore.log` |
| Datos restaurados | 5 categorías, 20 000 clientes, 50 000 productos, 200 000 pedidos, 600 000 detalles; sin filas inválidas | `logs/restore_test.log` |
| Informe post-incidente | Cronología, RPO/RTO observados y mejoras propuestas | [`informes/informe_u6_mantenimiento.pdf`](informes/informe_u6_mantenimiento.pdf) |
| Escalamiento de privilegios | Denegado por PostgreSQL | [`informes/informe_incidente_acceso_indebido.md`](informes/informe_incidente_acceso_indebido.md) |
| Integridad en MongoDB sin validación de esquema | Aceptó cliente inexistente, producto inexistente, cantidad −5 y subtotal incoherente; PostgreSQL rechazó los tres intentos | [`informes/ia_contraste_u7.md`](informes/ia_contraste_u7.md) |
| Sincronización | C2 CONFLICTO y luego SIMULADO_APROBADO; C3 y C4 RECHAZADO; C5 SIMULADO_APROBADO; C6 sin duplicados. PostgreSQL no cambió (misma huella antes y después) | [`informes/informe_u8_movil.pdf`](informes/informe_u8_movil.pdf) |

---

## 4. Decisiones de diseño

- **Refactorizaciones y desnormalizaciones (U4).** El esquema final está en 3FN/BCNF con dos desnormalizaciones deliberadas: `detalle_pedido.subtotal` (protegida por `CHECK`) y `pedidos.total` (protegido por procedimiento y consulta de auditoría; el costo asumido es que un `CHECK` no puede mirar otra tabla). La bandera `eliminado` junto a `deleted_at` es una redundancia intencional del borrado lógico: permite índices parciales simples.
- **Roles y permisos (U5).** Roles de grupo por función (lectura, escritura sin borrado, soporte con permisos por columna, reportes) y logins separados; la aplicación solo entra con `app_web`, con límite de conexiones y `SCRAM-SHA-256`. `rol_soporte` ve únicamente las columnas de `clientes` necesarias.
- **Mantenimiento (U6).** Respaldo lógico `pg_dump -Fc`, restauración en base descartable y validación por conteos y restricciones, para que «tener respaldo» signifique «sabemos cuánto tarda recuperarlo». El plan de U8 lo extiende a MongoDB (`mongodump`) y SQLite (se recrea desde esquema + instantánea).
- **Documental vs relacional (U7).** PostgreSQL queda como sistema de registro de pedidos por la integridad declarativa y las transacciones ACID; MongoDB solo como copia de lectura de pedidos completos (una consulta sin `JOIN`).
- **Móvil (U8).** PostgreSQL es la fuente de verdad de precio, stock y ventas; la tablet solo guarda una copia de lectura y propone pedidos con UUID. Los datos personales de `clientes` nunca salen del servidor.

---

## 5. Herramientas de IA, prompts y decisiones

Las declaraciones completas (DUIA, con prompt o spec, qué generó, qué se aceptó, qué se descartó y verificación) están en [`ia/`](ia/README.md). Resumen:

| Unidad | Herramientas | Uso | Propuestas descartadas o corregidas (ejemplos) |
| :-- | :-- | :-- | :-- |
| U4 (y Parcial 1) | OpenCode / Claude Code | Modelo ER, relacional y normalización ([`ia/duia_parcial1_correcciones.md`](ia/duia_parcial1_correcciones.md)) | Se descartó presentar el esquema como «BCNF sin matices» por los atributos derivados |
| U5 | Kiro, OpenCode | Spec y `roles.sql`; auditoría del script; análisis del log del simulacro ([`ia/bitacora_u5_seguridad.md`](ia/bitacora_u5_seguridad.md), [`ia/duia_u5_seguridad_roles.md`](ia/duia_u5_seguridad_roles.md)) | Se corrigieron nombres de objetos; OpenCode interpretó el escalamiento denegado como un defecto en lugar de un control que funcionó |
| U6 | Kiro (spec y script de respaldo), Claude Code (partes 2 a 5) | Scripts de mantenimiento, simulacro, informe ([`ia/bitacora_u6_mantenimiento.md`](ia/bitacora_u6_mantenimiento.md), [`ia/duia_tp6.md`](ia/duia_tp6.md)) | Se corrigió la base de origen de la spec: `foodstore` está vacía y el origen correcto es `foodstore_desarrollo` |
| U7 | Claude Code (Sonnet 5.5) | Consultas, verificación y comparación de tecnologías ([`ia/duia_tp7.md`](ia/duia_tp7.md)) | Dos afirmaciones de la IA se contrastaron en el laboratorio (integridad y transacciones multidocumento) |
| U8 | Kiro (spec), OpenCode (review de `parcial1_02` a `parcial1_10`), Claude Code | Spec, esquema SQLite, simulador, code review ([`ia/bitacora_u8_movil.md`](ia/bitacora_u8_movil.md), [`ia/duia_u8_movil.md`](ia/duia_u8_movil.md)) | 14 hallazgos con decisión humana por cada uno |

**Protocolo de uso de IA sobre datos** (las cuatro reglas del PDF):

1. Nada generado por IA se ejecutó sin lectura previa y prueba en copia o en transacción reversible, con respaldo previo ([`ia/protocolo_seguridad.md`](ia/protocolo_seguridad.md)).
2. No se enviaron datos personales: se trabaja con datos de prueba, `clientes_anon` y la instantánea móvil sin tabla `clientes`.
3. Cada uso está declarado en una DUIA con herramienta, finalidad y prompt o spec ([`ia/README.md`](ia/README.md)).
4. Todo lo entregado puede explicarse en la defensa: [`defensa/guion_defensa.md`](defensa/guion_defensa.md).

---

## 6. Notas

No hay pendientes de la Unidad 4. El script `tp_fnbc_control_lote.sql` entregado contiene solo las tablas descompuestas y la vista (sin el esquema original ni la instancia), y el informe muestra la vista vacía; por eso se agregó `tp_fnbc_migracion_y_reversion.sql`.
