# Food Store — Trabajo Práctico Integrador (TPI) · Primera entrega parcial

**Materia:** Base de Datos II · **Motor:** PostgreSQL 16+ con PL/pgSQL (probado en 17.11)
**Integrantes:** Gianella Peña, Martina Suarez y Agustina Fontagnol
**Alcance:** Unidades 1, 2 y 3 — integridad, transacciones y concurrencia · optimización de consultas · índices, vistas y objetos programables.

> Este repositorio contiene la **primera entrega parcial del TPI «Food Store»**. Los trabajos prácticos TP3, TP4 y TP5 (optimización, reportes, índices) son partes que se integran en la entrega y están en `Informes_tps/`.

## Empezar por acá

📄 **[`docs/informe_tecnico_tpi.md`](docs/informe_tecnico_tpi.md)** — informe técnico (qué se implementó por unidad, cómo se probó, resultados, optimizaciones antes/después y uso de IA) con el **checklist de los 9 objetivos**.

## Checklist de objetivos → dónde está la evidencia

| # | Objetivo | Archivo |
| :-: | :--- | :--- |
| 1 | Modelo ER (entidades, atributos, claves, cardinalidad, participación) | [`docs/01_modelo_er.md`](docs/01_modelo_er.md) · TP1 del equipo: [`TP1 (docx)`](Informes_tps/TP1_FoodStore_ModeloER_Normalizacion_DDL.docx) y [`diagrama`](docs/img/TP1_diagrama_ER_pata_de_gallo.png) |
| 2 | Paso de ER a modelo relacional (1:N y N:M con tabla intermedia) | [`docs/02_modelo_relacional.md`](docs/02_modelo_relacional.md) · TP1, Parte 2 |
| 3 | Normalización hasta 3FN/BCNF con dependencias funcionales | [`docs/03_normalizacion.md`](docs/03_normalizacion.md) · TP1, Parte 3 |
| 4 | DDL completo (tipos, PK, FK, restricciones, índices) | [`db/01_ddl_schema.sql`](db/01_ddl_schema.sql) · [`db/03_ddl_indices.sql`](db/03_ddl_indices.sql) |
| 5 | DML y consultas (JOIN, agregación, subconsultas, GROUP BY/HAVING, ventana) | [`db/04_dml_carga_masiva.sql`](db/04_dml_carga_masiva.sql) · [`db/05_dml_consultas.sql`](db/05_dml_consultas.sql) |
| 6 | Vistas, funciones y procedimientos (PL/pgSQL, `CALL`) | [`db/06_vistas.sql`](db/06_vistas.sql) · [`db/07_vista_materializada.sql`](db/07_vista_materializada.sql) · [`db/08_funciones_procedimientos_plpgsql.sql`](db/08_funciones_procedimientos_plpgsql.sql) |
| 7 | Reglas de negocio (CHECK, UNIQUE, triggers) | [`db/02_reglas_negocio_check_unique_triggers.sql`](db/02_reglas_negocio_check_unique_triggers.sql) |
| 8 | Transacciones: atomicidad, COMMIT, ROLLBACK, aislamiento, concurrencia | [`db/09_transacciones.sql`](db/09_transacciones.sql) · [`docs/informes/informe_concurrencia.md`](docs/informes/informe_concurrencia.md) · [`capturas/`](capturas) |
| 9 | Borrado lógico y su impacto en consultas e índices | [`db/10_borrado_logico.sql`](db/10_borrado_logico.sql) |

## Orden de ejecución de los scripts (`db/`)

Trabajar siempre sobre la **copia** de la base, nunca sobre la original (ver [`protocolo_seguridad.md`](protocolo_seguridad.md)):

```powershell
createdb -U postgres -h localhost -p 5432 -T foodstore foodstore_desarrollo
```

| Orden | Script | Contenido |
| :-: | :--- | :--- |
| 01 | `01_ddl_schema.sql` | Tipos `ENUM`, tablas, PK, FK, `CHECK`, `UNIQUE` (incluye `CREATE DATABASE foodstore`: conectarse a esa base antes de seguir con el resto) |
| 02 | `02_reglas_negocio_check_unique_triggers.sql` | `CHECK` de subtotal y 2 triggers (transición de estado, baja de cliente) |
| 03 | `03_ddl_indices.sql` | Índices compuestos, parciales y *covering* |
| 04 | `04_dml_carga_masiva.sql` | Carga de 20.000 clientes, 50.000 productos, 200.000 pedidos, 600.000 renglones (solo en la copia de desarrollo; hace `TRUNCATE`) |
| 05 | `05_dml_consultas.sql` | Consultas de reporte, `HAVING`, ventana, DML de ejemplo |
| 06 | `06_vistas.sql` | 3 vistas de reportes |
| 07 | `07_vista_materializada.sql` | `mv_facturacion_categoria_mes` |
| 08 | `08_funciones_procedimientos_plpgsql.sql` | 3 funciones y 5 procedimientos (`CALL`) |
| 09 | `09_transacciones.sql` | Pruebas de atomicidad, `COMMIT`/`ROLLBACK`, aislamiento y concurrencia |
| 10 | `10_borrado_logico.sql` | Pruebas de borrado lógico, índices parciales y `UNIQUE` |

Los scripts 09 y 10 crean datos de prueba y los eliminan al terminar.

## Otros archivos

| Carpeta / archivo | Contenido |
| :--- | :--- |
| `docs/duia/` | Declaraciones de uso de IA de cada parte (la corrección de esta entrega: [`duia_tpi_entrega1.md`](docs/duia/duia_tpi_entrega1.md)) |
| `docs/01..03_*.md`, `docs/informe_tecnico_tpi.md` | Modelo ER, relacional, normalización e informe técnico del TPI |
| `docs/informes/` | Informes de partes anteriores: concurrencia, lectura crítica, equivalencia de vistas, bitácora de verificación, benchmark de la vista materializada, política de refresh |
| `docs/img/` | Imágenes (diagrama ER del TP1) |
| `Informes_tps/` | Trabajos prácticos del equipo: TP1 (ER, relacional, normalización, DDL), consigna del TP2, TP3, TP4, Parte 5 y el informe de optimización ([`Informe_optimizacion_consultas_indices.md`](Informes_tps/Informe_optimizacion_consultas_indices.md)) |
| `spec/` | Especificaciones entregadas a la IA |
| `db/anexos_tps/` | Scripts auxiliares de las partes anteriores: `tp5_mediciones_pendientes.sql`, `parte5_competencia.sql`, `benchmark_vista_materializada.sql`, `verificacion_vistas_parteB.sql`, `vistas_reportes_prompt_*.sql` |
| `backups/` | Respaldo estructural (`pg_dump`) previo a cambios DDL |
