# Food Store — Capa de datos completa (relacional · documental · móvil)

**Materia:** Base de Datos II · **Equipo:** Gianella Peña, Martina Suarez, Agustina Fontagnol
**Motores:** PostgreSQL 16+ (PL/pgSQL) · MongoDB · SQLite 3.37+

Un único proyecto: la base relacional (`postgres/`), su extensión documental (`mongodb/`) y la base de la tablet (`movil/`), con sus specs, informes y registro de uso de IA. El código se organiza **por componente**; la relación con cada consigna está en la matriz de trazabilidad de abajo.

## Mapa del repositorio

```
postgres/
├── schema/            DDL, reglas de negocio (CHECK/UNIQUE/triggers), índices
├── normalizacion/     TP U4: FNBC de control_lote_almacen y vista materializada de top categorías
├── programabilidad/   vistas, vista materializada, funciones/procedimientos, transacciones, borrado lógico
├── datos/             carga masiva, consultas DML, vista_snapshot (fuente de la sincronización móvil)
├── seguridad/         roles, auditoría, simulacro de acceso indebido, usuario anonimizado
├── mantenimiento/     backup, restore_test, health_check, maintenance
└── experimentos/      benchmark, competencia de optimización, verificación de vistas
mongodb/               exportación, migración, verificación de integridad, consultas Mongo y SQL, datos
movil/                 esquema SQLite, carga, semáforo, pruebas, simulador de conflictos, base de la tablet
specs/                 specs Kiro/EARS por componente (relacional, seguridad, mantenimiento, movil, normalizacion)
docs/
├── modelo/            ER, modelo relacional, normalización, diagrama
├── informes/          informes por tema (ver docs/informes/README.md)
├── ia/                protocolo de seguridad, bitácoras de IA y DUIA (ver docs/ia/README.md)
├── defensa/           guion de defensa oral
├── evidencias/        capturas y logs (concurrencia, seguridad)
├── consignas/         enunciados originales, incluido el PDF de condiciones de la segunda entrega
└── _archivo_duplicados/  copias idénticas de archivos que ya están arriba (nada se borró)
backups/  logs/        respaldos y logs que usan los scripts de mantenimiento
```

## Matriz de trazabilidad — Segunda entrega (U4–U8)

Fuente: `docs/consignas/Condiciones_de_Entrega_TPI_Segunda_entrega.pdf`.

| Unidad | Objetivo exigido | Evidencia |
| :-- | :-- | :-- |
| **U4** | Refactor a BCNF validado con dependencias funcionales | `docs/informes/informe_u4_fnbc_desnormalizacion.pdf` (DFs, clausuras, claves candidatas, anomalías), `postgres/normalizacion/tp_fnbc_control_lote.sql`; antecedente: `docs/modelo/parcial1_03_normalizacion.md` |
| U4 | Migración sin pérdida en transacción reversible, spec Kiro, plan de reversión | Descomposición sin pérdida (Heath) y vista de compatibilidad en el informe y `tp_fnbc_control_lote.sql`; migración con `BEGIN … ROLLBACK` y reversión en `postgres/normalizacion/tp_fnbc_migracion_y_reversion.sql` (ejecutado el 04/11/2026: `docs/informes/evidencias_u4_ejecucion.md`); spec Kiro en `specs/normalizacion/` |
| U4 | Desnormalización controlada documentada | `postgres/normalizacion/tp_desnormalizacion_top_categorias.sql` e informe U4 (EXPLAIN 157,459 ms → 0,177 ms, auditoría de sincronía); además `docs/modelo/parcial1_03_normalizacion.md` (secciones 5 y 6) y `docs/informes/parcial1_politica_refresh.md` |
| **U5** | Usuarios, roles y permisos de mínimo privilegio | `postgres/seguridad/roles.sql`, `specs/seguridad/kiro_roles/` |
| U5 | Auditoría activada + simulacro de acceso indebido + contención | `postgres/seguridad/auditoria_test.sql`, `simulacro_incidente.sql`, `docs/informes/informe_incidente_acceso_indebido.md`, `docs/evidencias/seguridad/` |
| U5 | Auditoría de seguridad asistida por IA, decisión humana | `docs/informes/informe_auditoria_permisos.md`, `docs/ia/bitacora_u5_seguridad.md` |
| **U6** | Plan de mantenimiento: respaldo, restauración probada, tareas rutinarias | `postgres/mantenimiento/`, `specs/mantenimiento/SPEC_U6.md`, `docs/informes/evidencias_u6_mantenimiento.md` |
| U6 | Simulacro de desastre con informe post-incidente (RTO) | `docs/informes/informe_u6_mantenimiento.pdf`, `logs/restore_test.log`, `backups/` |
| **U7** | Modelo documental con consultas generadas y verificadas sobre datos reales | `mongodb/`, `docs/informes/modelo_documental_u7.md`, `docs/informes/tabla_verificacion_u7.md` |
| U7 | Comparación documental vs relacional con justificación | `docs/informes/ia_contraste_u7.md`, `docs/informes/informe_u7_nosql.pdf` |
| **U8** | Base SQLite y sincronización especificadas en Kiro y generadas con OpenCode | `movil/`, `specs/movil/` |
| U8 | Sincronización simulada con conflictos probados y resueltos | `movil/simulador_casos.py`, `movil/pruebas_sqlite.sql`, `docs/informes/informe_u8_movil.pdf` |
| U8 | Code review final asistido por IA, decisión humana por hallazgo | `docs/informes/inventario_scripts.md`, `docs/informes/informe_u8_movil.pdf` |
| U8 | Capa completa lista para defensa | este repositorio, `docs/defensa/guion_defensa.md` |
| **IA** | Protocolo de uso de IA (4 reglas), DUIA y bitácora | `docs/ia/` |
| **Informe técnico** | Resumen de lo implementado, probado, resultados y decisiones | **`docs/informe_tecnico.md`** (informes por unidad en `docs/informes/`) |


## Cómo ejecutar

Trabajar siempre sobre la copia, nunca sobre `foodstore` (ver `docs/ia/protocolo_seguridad.md`):

```powershell
createdb -U postgres -T foodstore foodstore_desarrollo
```

Los scripts de `postgres/schema/` y `postgres/datos/` se ejecutan en el orden de su prefijo `parcial1_NN_`. Los pasos de `movil/` están en `movil/README.md` y los de `mongodb/` en los comentarios de cada script (se corren desde la raíz del repo, p. ej. `mongosh --quiet mongodb/migrar_pedidos.js`). Los scripts de `postgres/mantenimiento/*.ps1` toman la raíz del repo como carpeta de trabajo y escriben en `backups/` y `logs/`.

## Notas de la reorganización

- Solo se movieron archivos y se agregaron índices; no se eliminó ni reescribió contenido. Las únicas ediciones a archivos existentes fueron rutas relativas: raíz del proyecto en los dos `.ps1`, ruta de `vista_snapshot.sql` en `movil/simulador_casos.py`, ruta del `.jsonl` en `mongodb/migrar_pedidos.js`, y los links de los `.md` movidos.
- `movil/README.md`, `docs/informes/README_parcial1.md` y `docs/informes/inventario_scripts.md` conservan su texto original: pueden nombrar rutas anteriores (`entrega_tp8/`, `db/`, `sql/`).
- Los scripts de `mongodb/` se ejecutan ahora con `mongodb/…` en lugar de `entrega_tp7/…`.
