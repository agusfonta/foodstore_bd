# Food Store — Trabajo Práctico Integrador (TPI) · PARCIAL 1 (primera entrega parcial)

**Materia:** Base de Datos II · **Motor:** PostgreSQL 16+ con PL/pgSQL (probado en 17.11)
**Integrantes:** Gianella Peña, Martina Suarez y Agustina Fontagnol
**Alcance:** Unidades 1, 2 y 3 — integridad, transacciones y concurrencia · optimización de consultas · índices, vistas y objetos programables.

> Este repositorio contiene la **primera entrega parcial del TPI «Food Store»**. Los trabajos prácticos TP3, TP4 y TP5 (optimización, reportes, índices) son partes que se integran en la entrega y están en `Informes_tps/`.

## Empezar por acá

📄 **[`Informe_Parcial_1.md`](Informe_Parcial_1.md)** (informe del Parcial 1) — informe técnico (qué se implementó por unidad, cómo se probó, resultados, optimizaciones antes/después y uso de IA) con el **checklist de los 9 objetivos**.

> **Cómo encontrar los archivos:** todo lo que corresponde al Parcial 1 lleva `parcial1` / `Parcial1` / `Parcial_1` en el nombre: `docs/informes/Informe_Parcial_1.md`, `postgres/**/parcial1_*.sql`, `docs/modelo/parcial1_*.md`, `docs/informes/parcial1_*.md`, `docs/ia/duia_parcial1_correcciones.md` y `docs/informes/optimizacion_indices/Parcial1_*.md`.

## Checklist de objetivos → dónde está la evidencia

| # | Objetivo | Archivo |
| :-: | :--- | :--- |
| 1 | Modelo ER (entidades, atributos, claves, cardinalidad, participación) | [`docs/modelo/parcial1_01_modelo_er.md`](../modelo/parcial1_01_modelo_er.md) · TP1 del equipo: [`TP1 (docx)`](../consignas/TP1_FoodStore_ModeloER_Normalizacion_DDL.docx) y [`diagrama`](../modelo/img/TP1_diagrama_ER_pata_de_gallo.png) |
| 2 | Paso de ER a modelo relacional (1:N y N:M con tabla intermedia) | [`docs/modelo/parcial1_02_modelo_relacional.md`](../modelo/parcial1_02_modelo_relacional.md) · TP1, Parte 2 |
| 3 | Normalización hasta 3FN/BCNF con dependencias funcionales | [`docs/modelo/parcial1_03_normalizacion.md`](../modelo/parcial1_03_normalizacion.md) · TP1, Parte 3 |
| 4 | DDL completo (tipos, PK, FK, restricciones, índices) | [`postgres/schema/parcial1_01_ddl_schema.sql`](../../postgres/schema/parcial1_01_ddl_schema.sql) · [`postgres/schema/parcial1_03_ddl_indices.sql`](../../postgres/schema/parcial1_03_ddl_indices.sql) |
| 5 | DML y consultas (JOIN, agregación, subconsultas, GROUP BY/HAVING, ventana) | [`postgres/datos/parcial1_04_dml_carga_masiva.sql`](../../postgres/datos/parcial1_04_dml_carga_masiva.sql) · [`postgres/datos/parcial1_05_dml_consultas.sql`](../../postgres/datos/parcial1_05_dml_consultas.sql) |
| 6 | Vistas, funciones y procedimientos (PL/pgSQL, `CALL`) | [`postgres/programabilidad/parcial1_06_vistas.sql`](../../postgres/programabilidad/parcial1_06_vistas.sql) · [`postgres/programabilidad/parcial1_07_vista_materializada.sql`](../../postgres/programabilidad/parcial1_07_vista_materializada.sql) · [`postgres/programabilidad/parcial1_08_funciones_procedimientos_plpgsql.sql`](../../postgres/programabilidad/parcial1_08_funciones_procedimientos_plpgsql.sql) |
| 7 | Reglas de negocio (CHECK, UNIQUE, triggers) | [`postgres/schema/parcial1_02_reglas_negocio_check_unique_triggers.sql`](../../postgres/schema/parcial1_02_reglas_negocio_check_unique_triggers.sql) |
| 8 | Transacciones: atomicidad, COMMIT, ROLLBACK, aislamiento, concurrencia | [`postgres/programabilidad/parcial1_09_transacciones.sql`](../../postgres/programabilidad/parcial1_09_transacciones.sql) · [`docs/informes/parcial1_informe_concurrencia.md`](parcial1_informe_concurrencia.md) · [`capturas/`](../evidencias) |
| 9 | Borrado lógico y su impacto en consultas e índices | [`postgres/programabilidad/parcial1_10_borrado_logico.sql`](../../postgres/programabilidad/parcial1_10_borrado_logico.sql) |

## Orden de ejecución de los scripts (`postgres/schema/`, `postgres/datos/`, `postgres/programabilidad/`)

Trabajar siempre sobre la **copia** de la base, nunca sobre la original (ver [`docs/ia/protocolo_seguridad.md`](../ia/protocolo_seguridad.md)):

```powershell
createdb -U postgres -h localhost -p 5432 -T foodstore foodstore_desarrollo
```

| Orden | Script | Contenido |
| :-: | :--- | :--- |
| 01 | `parcial1_01_ddl_schema.sql` | Tipos `ENUM`, tablas, PK, FK, `CHECK`, `UNIQUE` (incluye `CREATE DATABASE foodstore`: conectarse a esa base antes de seguir con el resto) |
| 02 | `parcial1_02_reglas_negocio_check_unique_triggers.sql` | `CHECK` de subtotal y 2 triggers (transición de estado, baja de cliente) |
| 03 | `parcial1_03_ddl_indices.sql` | Índices compuestos, parciales y *covering* |
| 04 | `parcial1_04_dml_carga_masiva.sql` | Carga de 20.000 clientes, 50.000 productos, 200.000 pedidos, 600.000 renglones (solo en la copia de desarrollo; hace `TRUNCATE`) |
| 05 | `parcial1_05_dml_consultas.sql` | Consultas de reporte, `HAVING`, ventana, DML de ejemplo |
| 06 | `parcial1_06_vistas.sql` | 3 vistas de reportes |
| 07 | `parcial1_07_vista_materializada.sql` | `mv_facturacion_categoria_mes` |
| 08 | `parcial1_08_funciones_procedimientos_plpgsql.sql` | 3 funciones y 5 procedimientos (`CALL`) |
| 09 | `parcial1_09_transacciones.sql` | Pruebas de atomicidad, `COMMIT`/`ROLLBACK`, aislamiento y concurrencia |
| 10 | `parcial1_10_borrado_logico.sql` | Pruebas de borrado lógico, índices parciales y `UNIQUE` |

Los scripts 09 y 10 crean datos de prueba y los eliminan al terminar.

## Otros archivos

| Carpeta / archivo | Contenido |
| :--- | :--- |
| `docs/ia/` | Declaraciones de uso de IA de cada parte (la corrección de esta entrega: [`duia_parcial1_correcciones.md`](../ia/duia_parcial1_correcciones.md)) |
| `docs/informes/Informe_Parcial_1.md`, `docs/modelo/parcial1_01..03_*.md` | Informe técnico del Parcial 1; modelo ER, relacional y normalización |
| `docs/informes/` | Informes que acreditan los objetivos 3, 6 y 8: concurrencia, lectura crítica, equivalencia de vistas, bitácora de verificación, benchmark de la vista materializada, política de refresh |
| `docs/modelo/img/` | Imágenes (diagrama ER del TP1) |
| `docs/consignas/` | Trabajos prácticos del equipo (los `.docx`/`.pdf`) y enunciados: TP1 (ER, relacional, normalización, DDL), consigna del TP2, TP3, TP4, Parte 5 y el informe de optimización ([`Parcial1_Informe_optimizacion_consultas_indices.md`](optimizacion_indices/Parcial1_Informe_optimizacion_consultas_indices.md)) |
| `specs/` | Especificaciones entregadas a la IA |
| `postgres/experimentos/` | Scripts auxiliares de las partes anteriores: `tp5_mediciones_pendientes.sql`, `parte5_competencia.sql`, `benchmark_vista_materializada.sql`, `verificacion_vistas_parteB.sql`, `vistas_reportes_prompt_*.sql` |
| `backups/` | Respaldo estructural (`pg_dump`) previo a cambios DDL |
