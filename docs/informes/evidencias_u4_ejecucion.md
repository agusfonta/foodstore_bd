# U4 — Evidencia de ejecución (4 de noviembre de 2026)

Ejecutado por el equipo en `foodstore_desarrollo` (PostgreSQL 17.11), con respaldo previo `backups/foodstore_20261104_104859.dump`. La contraseña se cargó en la sesión de PowerShell; no se guardó en ningún archivo.

## Parte 1 — FNBC

| Script | Resultado |
| :-- | :-- |
| `postgres/normalizacion/tp_fnbc_control_lote.sql` | 4 `CREATE TABLE` (`lote`, `deposito`, `responsable_deposito`, `control_lote`) y `CREATE VIEW v_control_lote_almacen` |
| `postgres/normalizacion/tp_fnbc_migracion_y_reversion.sql` | Dentro de `BEGIN … ROLLBACK`: tabla original creada, 3 filas insertadas, migración (2 filas en `responsable_deposito`, 3 en `control_lote`) |

Verificación de equivalencia (ambos `EXCEPT`):

| sentido | filas |
| :-- | :-: |
| original − vista | 0 |
| vista − original | 0 |

La vista devolvió exactamente la instancia original:

| lote_id | deposito_id | responsable_control_id |
| :-: | :-: | :-: |
| 501 | 30 | 801 |
| 502 | 30 | 801 |
| 503 | 31 | 802 |

Nota: el script de tablas no va dentro de una transacción, así que las 4 tablas y la vista **quedaron creadas** en `foodstore_desarrollo`. Los datos de ejemplo se revirtieron con el `ROLLBACK`, por lo que la vista está vacía hasta que se haga `COMMIT` en la migración.

## Parte 2 — Desnormalización controlada

Script `tp_desnormalizacion_top_categorias.sql` (vista materializada, índice único, `REFRESH CONCURRENTLY`) y `tp_desnormalizacion_auditoria.sql`.

| | Antes (tablas normalizadas) | Después (vista materializada) |
| :-- | :-- | :-- |
| Execution Time | **121,009 ms** | **0,357 ms** |
| Nodo dominante | `Parallel Seq Scan on pedidos` (filtro por fecha y `eliminado`, 66 667 filas descartadas por proceso) | `Seq Scan on mv_top_categorias_dia` (1 820 filas descartadas) |

Auditoría de sincronía (5.2.e): **0 filas**, la vista coincide con la fuente.

Observaciones:

- Las dos consultas devolvieron 0 filas porque no hay pedidos con la fecha de hoy en la base de prueba; los tiempos comparan el costo del plan, no un resultado con datos. El informe PDF original midió 157,459 ms → 0,177 ms (mismo orden de magnitud).
- El plan «antes» usa el índice `idx_tp4_det_cover` sobre `detalle_pedido`, que no figura en los scripts de este repositorio.
- Reversión de la parte 2: `DROP MATERIALIZED VIEW mv_top_categorias_dia;`.
