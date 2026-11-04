# Normalización avanzada y redundancia (U4)

Resolución del TP de la Unidad 4. El informe con el análisis, las clausuras, las anomalías y las capturas de `EXPLAIN ANALYZE` es [`../../docs/informes/informe_u4_fnbc_desnormalizacion.pdf`](../../docs/informes/informe_u4_fnbc_desnormalizacion.pdf).

| Archivo | Parte | Contenido |
| :-- | :-- | :-- |
| `tp_fnbc_control_lote.sql` | 1 · FNBC (`control_lote_almacen`) | Tablas descompuestas `responsable_deposito` y `control_lote` con PK y FK, y la vista de compatibilidad `v_control_lote_almacen` |
| `tp_fnbc_migracion_y_reversion.sql` | 1 · migración | Esquema original, instancia de ejemplo, migración de datos, verificación por `EXCEPT` y plan de reversión, dentro de `BEGIN … ROLLBACK`. **Creado al integrar la unidad; ejecutado el 04/11/2026 (ver evidencia)** |
| `tp_desnormalizacion_top_categorias.sql` | 2 · desnormalización | `mv_top_categorias_dia`, índice único y `REFRESH … CONCURRENTLY` |
| `tp_desnormalizacion_auditoria.sql` | 2 · mediciones y auditoría | `EXPLAIN ANALYZE` antes y después y auditoría de sincronía (creado al integrar la unidad) |

Resumen de resultados que muestra el informe:

- `{lote, depósito} → responsable` y `responsable → depósito`; claves candidatas `{lote, depósito}` y `{lote, responsable}`; la tabla viola FNBC porque `responsable` no es superclave.
- Descomposición sin pérdida por el teorema de Heath: `responsable_control_id` es clave de `responsable_deposito`.
- Consulta del top 5 de categorías del día: **157,459 ms** sobre las tablas normalizadas contra **0,177 ms** sobre la vista materializada.
- Auditoría de sincronía de la vista: 0 filas.

Evidencia de la ejecución: [`../../docs/informes/evidencias_u4_ejecucion.md`](../../docs/informes/evidencias_u4_ejecucion.md) (en `foodstore_desarrollo`: 121,009 ms → 0,357 ms, auditoría con 0 filas, equivalencia con 0 y 0).

Spec Kiro de la unidad: [`../../specs/normalizacion/`](../../specs/normalizacion/requirements.md) (11 requisitos EARS y tareas).
