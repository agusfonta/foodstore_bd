# BITACORA — TP Unidad 6


Detalle completo por uso en `docs/duia/duia_tp6.md`. Herramientas realmente usadas: Kiro (Parte 1) y Claude Code (Partes 2 a 5).

### Registro U6-1 — Spec y script de respaldo

| Campo | Contenido |
|-------|-----------|
| **Parte** | 1 y 2 |
| **Prompt enviado a la IA** | Kiro: consigna de la Parte 1 (SPEC_U6.md) y el script `backup_foodstore.ps1`. Claude Code: revisar lo hecho por Kiro y hacer funcionar el respaldo con la contraseña en `.env`. |
| **Respuesta relevante recibida** | Spec correcta en estructura y nombres de tabla. Script con `pg_dump -Fc`, log y `exit 1`. |
| **Validación o corrección humana aplicada** | **Error detectado:** la spec y el script apuntaban a `foodstore`, que está vacía (0 filas); el origen debe ser `foodstore_desarrollo`. La primera ejecución dejó un `.dump` de 0 bytes sin error en el log; se agregó captura de stderr, borrado del parcial y validación de tamaño. |

### Registro U6-2 — Monitoreo, mantenimiento y simulacro

| Campo | Contenido |
|-------|-----------|
| **Parte** | 3 y 4 |
| **Prompt enviado a la IA** | "Seguí con la Parte 3 (health_check.sql y maintenance.sql)" y "hacé el simulacro de la Parte 4 con cronómetro y validaciones". |
| **Respuesta relevante recibida** | `health_check.sql`, `maintenance.sql` y `restore_test.ps1`. Simulacro: RTO 14,8 s, conteos coincidentes, 0 registros inválidos. |
| **Validación o corrección humana aplicada** | **Error de la IA:** `maintenance.sql` ejecutaba `ANALYZE` sobre toda la base sin que la observación lo justificara (0 tablas candidatas); se corrigió a un `ANALYZE` por tabla, condicionado. Las validaciones del PDF se adaptaron a los nombres de tabla reales. |

### Registro U6-3 — Informe

| Campo | Contenido |
|-------|-----------|
| **Parte** | 5 |
| **Prompt enviado a la IA** | "Armá el informe_u6 (1 página, en PDF) y la DUIA, y actualizá la BITACORA". |
| **Respuesta relevante recibida** | `informe_u6.pdf`, `docs/duia/duia_tp6.md` y esta sección. |
| **Validación o corrección humana aplicada** | Cifras contrastadas con los logs. Pendiente: revisión final de la persona antes de entregar. |

| Fecha | Parte | Acción |
|-------|-------|--------|
| 2026-10-21 | U6 1–5 | Registros U6-1 a U6-3 y DUIA del TP Unidad 6 |
