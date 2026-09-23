# Bitácora de verificación de equivalencia — Parte B (complemento)

> No modifica `docs/informe_mediciones.md`. Lo complementa con el entregable
> exigido (`db/views.sql`), la trazabilidad de specs y la planilla para pegar
> resultados reales. La equivalencia de filas ya fue analizada estáticamente
> (JOIN y WHERE idénticos); falta solo pegar la ejecución real.

**Entregable:** `db/views.sql` (3 vistas definitivas: `v_productos_vigentes_con_categoria`, `v_pedidos_con_cliente`, `v_detalle_pedido_con_producto`).
**Previos conservados:** `db/vistas_reportes_prompt_opencode.sql`, `db/vistas_reportes_prompt_propio.sql`.
**Spec Kiro:** `spec/spec_parteB_kiro.md`. **DUIA:** `docs/duia_parteB_vistas.md`.
**Script de verificación:** `db/verificacion_vistas_parteB.sql`.
**Protocolo ejecutado el 2026-09-23:**
- Conexión verificada: `SELECT current_database(), current_user` → `foodstore_desarrollo, postgres` (PostgreSQL 17.11).
- Base `foodstore_desarrollo` ya existía (junto a `foodstore`, `foodstore_tpi`); no se recreó para no borrar datos (50.000 productos, 20.000 clientes, 200.000 pedidos, 600.000 detalles).
- Respaldo estructural previo al DDL: `pg_dump --schema-only -F c` → `backups/respaldo_esquema_views_20260923_103912.backup` (15.617 bytes, copiado a `foodstore_bd/backups/`).
- Vistas aplicadas sobre `foodstore_desarrollo`: `vistas_reportes_prompt_opencode.sql` (3× CREATE VIEW) + `vistas_reportes_prompt_propio.sql` (3× CREATE VIEW) + `views.sql` (3× CREATE VIEW).

## Aclaración sobre “coinciden exactamente”

Los JOIN y filtros WHERE son idénticos entre versiones, por lo que el conjunto
de **filas** es el mismo. Las **columnas** difieren por diseño (OpenCode agrega
`disponible, categoria_id, cliente_id, detalle_id`; ver `docs/informe_mediciones.md`).
Por eso la verificación `EXCEPT` se hace sobre columnas comunes y `db/views.sql`
fija la lista definitiva (la completa de OpenCode). Completar la tabla con 0 filas.

## Resultados reales (ejecución 2026-09-23 sobre foodstore_desarrollo)

Salida completa de `db/verificacion_vistas_parteB.sql`:

| Vista | EXCEPT opencode→propio | EXCEPT propio→opencode | Conteo opencode / propio | Válida |
|---|---|---|---|---|
| 1 productos+categoría | 0 filas | 0 filas | 50000 / 50000 | ☑ |
| 2 pedidos+cliente | 0 filas | 0 filas | 200000 / 200000 | ☑ |
| 3 detalle+producto | 0 filas | 0 filas | 600000 / 600000 | ☑ |
| Seguridad `contrasenia` en vistas | `information_schema` → 0 filas | `SELECT contrasenia FROM v_pedidos_con_cliente` → `ERROR: no existe la columna «contrasenia»`; ídem `v_pedidos_clientes` | — | ☑ |

Detalle textual pegado de psql:

```text
-- Vista 1
producto_id | producto_nombre | precio | stock → (0 filas)
id | nombre | precio | stock → (0 filas)
total_opencode | total_propio → 50000 | 50000
-- Vista 2
pedido_id | fecha | estado | total | ... → (0 filas)
id | fecha | estado | total | ... → (0 filas)
total_opencode | total_propio → 200000 | 200000
-- Vista 3
pedido_id | producto_id | producto_nombre | ... → (0 filas)
pedido_id | producto_id | producto | ... → (0 filas)
total_opencode | total_propio → 600000 | 600000
-- Seguridad
table_name | column_name → (0 filas)
```

## Criterio de seguridad (punto 4)

Vista 2 (`v_pedidos_con_cliente` en `db/views.sql:28-53`) expone cliente sin
`contrasenia` (tampoco `rol` ni auditoría). Patrón para otorgar acceso sin tabla base:

```sql
REVOKE SELECT ON clientes FROM rol_reportes;
REVOKE SELECT ON pedidos FROM rol_reportes;
GRANT SELECT ON v_pedidos_con_cliente TO rol_reportes;
```

## Pasos reproducibles (5 min)

1. `psql -d foodstore_desarrollo`, verificar `\conninfo`.
2. `\i db/vistas_reportes_prompt_opencode.sql` + `\i db/vistas_reportes_prompt_propio.sql` + `\i db/views.sql`.
3. `\i db/verificacion_vistas_parteB.sql` — resultado ya registrado arriba el 2026-09-23.
4. Las 3 vistas quedan validadas (0 filas de diferencia y conteos iguales).
