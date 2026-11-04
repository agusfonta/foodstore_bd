# Tareas — Base móvil de la tablet (TP8)

Las tareas se ejecutaron en este orden; el esquema y la simulación se generaron con OpenCode a partir de ellas (ver `../bitacora_ia.md`).

- [x] **T1** Elegir qué columnas de `productos` viajan a la tablet (REQ-01 a REQ-11) → tabla 1.a en `docs/informe.pdf`
- [x] **T2** Crear `movil/schema_sqlite.sql` con las cuatro tablas STRICT y sus CHECK/FK, más UUID v4 con CHECK, índice único parcial de `cola_sync` y `evaluacion_sync` (REQ-06, REQ-08, REQ-09)
- [x] **T3** Escribir `movil/pruebas_sqlite.sql`: COMMIT, ROLLBACK, C1 y C7
- [x] **T4** Crear `v_snapshot_movil` en PostgreSQL y exportar `movil/servidor_snapshot.csv` → `db/vista_snapshot.sql`
- [x] **T5** Importar el CSV en `snapshot_servidor` y cargar `producto_cache` → `movil/carga_snapshot.sql`
- [x] **T6** Escribir `movil/semaforo.sql` (REQ-01, REQ-02, REQ-03, REQ-05)
- [x] **T7** Correr C2 a C6 cambiando datos en PostgreSQL (UPDATE en BEGIN, ROLLBACK al final) y comprobar que no cambió (REQ-04, REQ-11) → `movil/simulador_casos.py`
- [x] **T8** Mapa de los tres motores, plan de mantenimiento y code review → `docs/informe.pdf`
- [x] **T9** Bitácora, DUIA y README
- [x] **T10** Inventario de scripts U1–U8 → `docs/inventario_scripts.md`
- [x] **T11** Guion de defensa → `docs/guion_defensa.md`
