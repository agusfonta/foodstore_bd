# Inventario de scripts de la cursada (U1–U8)

Lista de todos los scripts que existen en el repositorio al 4 de noviembre de 2026, ordenados por unidad, con lo que se revisó en el code review (consigna 3.c, `informe.pdf`). La columna **Hallazgos** usa los números de la tabla del informe; `—` significa revisado sin hallazgos.

Cómo se armó: `find` de `*.sql`, `*.ps1`, `*.js` y `*.py` fuera de `entrega_tp8/`, y se asignó cada archivo a la unidad cuyo trabajo práctico lo pidió. Los archivos de `entrega_tp6/sql/` repiten los de `sql/` (se comprobó con `cmp`: idénticos), por eso se cuentan una sola vez.

| Unidad | Tema | Archivo | Qué hace | Hallazgos |
| :--- | :--- | :--- | :--- | :--- |
| **U1** | Modelo y DDL | `db/parcial1_01_ddl_schema.sql` | Esquema definitivo de `foodstore` (tablas, claves, CHECK) | 6, 7 |
| U1 | DML | `db/parcial1_04_dml_carga_masiva.sql` | Carga masiva: 50 000 productos, 20 000 clientes, 200 000 pedidos | 8 |
| U1 | DML | `db/parcial1_05_dml_consultas.sql` | Facturación, historial, ranking, top 10 | 9 |
| U1 | Integridad | `db/parcial1_02_reglas_negocio_check_unique_triggers.sql` | CHECK, UNIQUE y triggers (subtotal, transiciones de estado) | — |
| U1 | Borrado lógico | `db/parcial1_10_borrado_logico.sql` | Soft delete e impacto en consultas e índices | 4 |
| **U2** | Índices | `db/parcial1_03_ddl_indices.sql` | Índices para facturación y ranking | 2, 5 |
| U2 | Índices | `db/anexos_tps/parte5_competencia.sql` | Competencia de optimización (TP5) | 13 |
| U2 | Medición | `db/anexos_tps/tp5_mediciones_pendientes.sql` | `EXPLAIN` pendientes del informe de TP5 | — |
| **U3** | Transacciones | `db/parcial1_09_transacciones.sql` | COMMIT, ROLLBACK, SAVEPOINT, aislamiento | 4 |
| U3 | PL/pgSQL | `db/parcial1_08_funciones_procedimientos_plpgsql.sql` | Funciones y procedimientos (`sp_crear_pedido`) | 1 |
| **U4** | Vistas | `db/parcial1_06_vistas.sql` | Vistas de reportes (entregable de la Parte B) | — |
| U4 | Vista materializada | `db/parcial1_07_vista_materializada.sql` | Facturación por categoría y mes | 3 |
| U4 | Vistas | `db/anexos_tps/vistas_reportes_prompt_opencode.sql` | Versión OpenCode de las vistas | — |
| U4 | Vistas | `db/anexos_tps/vistas_reportes_prompt_propio.sql` | Versión propia de las vistas | — |
| U4 | Verificación | `db/anexos_tps/verificacion_vistas_parteB.sql` | `EXCEPT` entre las dos versiones | — |
| U4 | Benchmark | `db/anexos_tps/benchmark_vista_materializada.sql` | Consulta original vs vista materializada | — |
| **U5** | Roles | `sql/roles.sql` | Roles de mínimo privilegio | 10 |
| U5 | Auditoría | `sql/auditoria_test.sql` | Secuencia de prueba de auditoría | 11 |
| U5 | Incidente | `sql/simulacro_incidente.sql` | Simulacro de acceso indebido | — |
| U5 | Privacidad | `sql/usuario_anon.sql` | Anonimización (`clientes_anon`) | — |
| **U6** | Respaldo | `sql/backup_foodstore.ps1` | Respaldo con `pg_dump` | 14 |
| U6 | Restauración | `sql/restore_test.ps1` | Simulacro de restauración en `foodstore_restore_test` | 14 |
| U6 | Mantenimiento | `sql/health_check.sql` | Chequeo diario (solo lectura) | 14 |
| U6 | Mantenimiento | `sql/maintenance.sql` | Revisión semanal de mantenimiento | 14 |
| U6 | Copia de la entrega | `entrega_tp6/sql/` (4 archivos) | Idénticos a los de `sql/` | 14 |
| **U7** | Exportar | `entrega_tp7/sql/exportar_pedidos_json.sql` | Pedidos 1–10 como JSONL | — |
| U7 | Migrar | `entrega_tp7/migrar_pedidos.js` | Carga en `foodstore_u7.pedidos` (MongoDB) | — |
| U7 | Integridad | `entrega_tp7/verificacion_integridad.js` | Reglas de PostgreSQL verificadas en MongoDB | 12 |
| U7 | Consultas | `entrega_tp7/consultas_mongodb.js` | Consultas en MongoDB | — |
| U7 | Consultas | `entrega_tp7/consultas_postgresql.sql` | Las mismas consultas en PostgreSQL | — |
| **U8** | Vista | `entrega_tp8/db/vista_snapshot.sql` | `v_snapshot_movil` + control de que PostgreSQL no cambió | — |
| U8 | Tablet | `entrega_tp8/movil/schema_sqlite.sql` | 6 tablas STRICT, UUID v4, índice único parcial, trigger de registro | — |
| U8 | Tablet | `entrega_tp8/movil/carga_snapshot.sql` | Importa el CSV y carga `producto_cache` | — |
| U8 | Tablet | `entrega_tp8/movil/semaforo.sql` | Rojo / amarillo / verde | — |
| U8 | Tablet | `entrega_tp8/movil/pruebas_sqlite.sql` | COMMIT, ROLLBACK, C1, C7 y restricciones nuevas | — |
| U8 | Simulación | `entrega_tp8/movil/simulador_casos.py` | Casos C2–C6 contra PostgreSQL | — |

## Resumen

| Unidad | Archivos | Con hallazgo |
| :--- | :---: | :---: |
| U1 | 5 | 4 (`parcial1_02` sin hallazgos) |
| U2 | 3 | 2 |
| U3 | 2 | 2 |
| U4 | 6 | 1 |
| U5 | 4 | 2 |
| U6 | 4 (+4 copias) | 4 |
| U7 | 5 | 1 |
| U8 | 6 | 0 (revisados por el equipo y con `pruebas_sqlite.sql`) |
| **Total** | **35 (+4 copias)** | |

Los hallazgos 1 a 14 (decisión y comprobación en la base) están en el informe, consigna 3.c. Los scripts sin hallazgo figuran en la última línea del informe como «revisados sin otros hallazgos».
