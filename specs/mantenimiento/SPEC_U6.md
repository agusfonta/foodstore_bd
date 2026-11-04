# SPEC_U6 — Especificación y plan de mantenimiento

**Proyecto:** Food Store | PostgreSQL 16+
**Base original (no se toca):** `foodstore`
**Base de trabajo (se respalda y monitorea):** `foodstore_desarrollo`
**Base de restauración (descartable):** `foodstore_restore_test`
**Objetivos previstos del laboratorio:** RPO 24 h (respaldo diario) · RTO 15 min (restauración + validaciones)

---

## Tareas automatizadas

| Tarea mínima | Frecuencia | Qué se automatiza | Condición que confirma finalización correcta |
|---|---|---|---|
| **Respaldo de foodstore_desarrollo** | Diaria | `pg_dump -Fc` en formato custom. Nombre con fecha y hora (`foodstore_YYYYMMDD_HHMMSS.dump`). Resultado registrado en `logs/backup_foodstore.log`. | Existe el archivo `.dump` en `backups/` y el log registra éxito (exit code 0). Si `pg_dump` falla, el script termina con error. |
| **Chequeo de salud** | Diaria | `health_check.sql`: tamaño de la base, conexiones activas, estado de tablas (tuplas vivas/muertas, autovacuum) y consultas en ejecución. | El script devuelve 4 result sets sin error sobre `foodstore_desarrollo`. |
| **Revisión de mantenimiento** | Semanal | `maintenance.sql`: revisión de `n_dead_tup`, `last_autovacuum` y `last_autoanalyze` por tabla. Acción de mantenimiento (`VACUUM` o `ANALYZE`) solo si la observación lo justifica. | La consulta de revisión se ejecuta sin error y, si se aplica `VACUUM`/`ANALYZE`, se documenta la justificación con los valores observados. |
| **Restauración de prueba** | Semanal | `createdb foodstore_restore_test` (se recrea en cada ensayo) + `pg_restore --no-owner --no-privileges` del último respaldo. Validación de conteos y restricciones. | Los conteos de `categorias`, `clientes`, `productos`, `pedidos`, `detalle_pedido` coinciden con los registrados antes del respaldo y los checks de inválidos devuelven 0. |

---

## Reglas de seguridad del laboratorio

1. **Sin contraseñas en scripts ni en el repositorio.** El respaldo usa `PGPASSWORD` como variable de entorno del proceso o archivo `.pgpass`, nunca hardcodeada.
2. **Formato custom (`-Fc`)** para todo respaldo, de modo que la restauración use `pg_restore`.
3. **Pruebas destructivas solo en bases descartables.** Las bases `foodstore` y `foodstore_desarrollo` no se eliminan ni se reemplazan durante el simulacro. La restauración se hace siempre en `foodstore_restore_test`.
4. **`VACUUM FULL` prohibido** como mantenimiento periódico. Si se incluye `VACUUM` o `ANALYZE` manual, la decisión se justifica con la observación previa del estado de las tablas.
5. **Protocolo de 3 pasos (AGENTS.md):** todo script que escriba datos se prueba primero en transacción (`BEGIN; ... ROLLBACK;`); todo DDL requiere `pg_dump` de respaldo estructural previo; se trabaja sobre copia local (`foodstore_desarrollo`) cuando corresponde.

---

## Uso de OpenCode

OpenCode puede generar la primera versión de los scripts a partir de esta spec y de `AGENTS.md`. La entrega debe demostrar que el código fue revisado y probado. No se evalúa la cantidad de texto generado, sino la corrección del procedimiento final. Cada parte asistida con IA se documenta en la DUIA correspondiente (`docs/ia/duia_tp6.md`).
