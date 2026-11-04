# DUIA — TP Unidad 6: Mantenimiento, respaldo y recuperación (Food Store)

**Proyecto:** Foodstore — PostgreSQL 17.11, base de trabajo `foodstore_desarrollo`, restauración en `foodstore_restore_test`
**Informe asociado:** `informe_u6.pdf`
**Spec asociada:** `specs/mantenimiento/SPEC_U6.md`
**Nota sobre la herramienta:** la consigna menciona OpenCode, pero esta unidad se resolvió con **Kiro** (Parte 1) y **Claude Code** (Partes 2 a 5). Se declara la herramienta realmente usada.

---

## Uso 1: Parte 1 — Especificación y plan de mantenimiento

| Campo | Descripción |
| :--- | :--- |
| **Herramienta** | Kiro |
| **Spec o prompt utilizado** | Consigna de la Parte 1 del TP (specs/mantenimiento/SPEC_U6.md de una página: qué se automatiza, frecuencia, condición de éxito). |
| **Qué generó** | `specs/mantenimiento/SPEC_U6.md`: tabla con las 4 tareas mínimas y reglas de seguridad del laboratorio. |
| **Qué se aceptó** | La tabla de tareas, las reglas de seguridad y los nombres de tabla reales del DDL (`categorias`, `clientes`…), que difieren de los nombres en singular del PDF. |
| **Qué se modificó o descartó, y por qué** | Se corrigió la base de origen: la spec decía `foodstore`, que está **vacía**; el origen correcto es `foodstore_desarrollo` (copia de trabajo con 880.025 filas, según `docs/ia/protocolo_seguridad.md`). Se agregaron los RPO/RTO previstos (24 h / 15 min), que la spec no definía. |
| **Verificación realizada** | Contraste con el PDF de la consigna y con `postgres/schema/parcial1_01_ddl_schema.sql`; `SELECT count(*)` en `foodstore` (0 filas) y en `foodstore_desarrollo`. |

---

## Uso 2: Parte 2 — Script de respaldo

| Campo | Descripción |
| :--- | :--- |
| **Herramienta** | Kiro (primera versión) y Claude Code (corrección) |
| **Spec o prompt utilizado** | Kiro: generar `backup_foodstore.ps1` desde specs/mantenimiento/SPEC_U6.md. Claude Code: "creame un .env con la contraseña" / "ya está el .env", y revisión del script. |
| **Qué generó** | Kiro: `postgres/mantenimiento/backup_foodstore.ps1` con `pg_dump -Fc`, fecha en el nombre, log y `exit 1` si falla. Claude Code: carga de `PGPASSWORD` desde `.env`, captura de stderr en el log, borrado del archivo parcial y validación de tamaño > 0. |
| **Qué se aceptó** | La estructura del script de Kiro (carpetas, timestamp, función de log, comprobación de `PGPASSWORD`). |
| **Qué se modificó o descartó, y por qué** | La primera ejecución falló (código 1) y dejó un `.dump` de **0 bytes** sin ningún mensaje de error en el log. Se agregó captura de errores, borrado del parcial y la validación de tamaño. Se cambió la base de `foodstore` (vacía) a `foodstore_desarrollo`. Claude Code no pudo crear el `.env` (permiso denegado en la sesión): lo creó la persona y el script lo lee sin imprimir su contenido. |
| **Verificación realizada** | Ejecución manual: exit 0, `foodstore_20261021_114403.dump` de 10.639 KB y entrada `OK` en `logs/backup_foodstore.log`. |

---

## Uso 3: Parte 3 — Monitoreo y mantenimiento

| Campo | Descripción |
| :--- | :--- |
| **Herramienta** | Claude Code |
| **Spec o prompt utilizado** | "Sí, commiteá la Parte 2 y seguí con la Parte 3 (health_check.sql y maintenance.sql)" + las consultas base del PDF. |
| **Qué generó** | `postgres/mantenimiento/health_check.sql` (4 controles, solo lectura) y `postgres/mantenimiento/maintenance.sql` (revisión de autovacuum, candidatas a ANALYZE y acción de mantenimiento). |
| **Qué se aceptó** | `health_check.sql` tal como se generó. |
| **Qué se modificó o descartó, y por qué** | **Error de la IA:** la primera versión de `maintenance.sql` ejecutaba `ANALYZE VERBOSE` sin condición, sobre toda la base (incluidos catálogos). La consulta de candidatas devolvió 0 filas, así que no había justificación, que es lo que exige la consigna. Ya se había ejecutado una vez (solo actualiza estadísticas, sin riesgo para los datos). Se dejó el `ANALYZE` comentado y por tabla. `VACUUM` se descartó: `categorias` tiene 37,5 % de muertas pero son 3 filas en 1 página. |
| **Verificación realizada** | Ejecución de ambos scripts sobre `foodstore_desarrollo` en PostgreSQL 17.11: `health_check.sql` devolvió 4 result sets; la revisión mostró `n_mod_since_analyze = 0` en todas las tablas. |

---

## Uso 4: Parte 4 — Simulacro de restauración

| Campo | Descripción |
| :--- | :--- |
| **Herramienta** | Claude Code |
| **Spec o prompt utilizado** | "Sí, hacé el simulacro de la Parte 4 con cronómetro y validaciones". |
| **Qué generó** | `postgres/mantenimiento/restore_test.ps1`: toma el último `.dump`, registra conteos de referencia, recrea `foodstore_restore_test`, restaura con `--no-owner --no-privileges`, valida y mide el RTO. |
| **Qué se aceptó** | El script completo, tras revisarlo. Solo borra `foodstore_restore_test` (nombre fijo, base descartable) y solo lee `foodstore_desarrollo`. |
| **Qué se modificó o descartó, y por qué** | Las consultas de validación del PDF usan nombres en singular (`categoria`, `producto`…); se adaptaron a los nombres reales del esquema. |
| **Verificación realizada** | Ejecución real: conteos 5 / 20.000 / 50.000 / 200.000 / 600.000 coinciden; `productos_invalidos = 0`, `detalles_invalidos = 0`; RTO observado 14,8 s (`logs/restore_test.log`). |

---

## Uso 5: Parte 5 — Informe, DUIA y bitácora

| Campo | Descripción |
| :--- | :--- |
| **Herramienta** | Claude Code |
| **Spec o prompt utilizado** | "Armá el informe_u6 (1 página, en PDF) y la DUIA docs/ia/duia_tp6.md, y actualizá la BITACORA". |
| **Qué generó** | `informe_u6.pdf` (generado con reportlab), este archivo y la sección U6 de `BITACORA.md`. |
| **Qué se aceptó** | Pendiente de revisión por la persona antes de entregar. |
| **Qué se modificó o descartó, y por qué** | Los valores del informe (fechas, RTO, conteos) se tomaron de los logs y no se estimaron. La antigüedad del respaldo es 0 min porque se generó justo antes del ensayo; el informe lo aclara y discute el RPO real con respaldo diario. |
| **Verificación realizada** | Contraste de cada cifra con `logs/backup_foodstore.log` y `logs/restore_test.log`; control de que el PDF tenga 1 página. |
