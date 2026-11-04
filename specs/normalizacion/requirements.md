# Requisitos — Normalización avanzada (U4)

Regla de oro: **ninguna decisión de diseño se toma por intuición.** Normalizar se decide con
dependencias funcionales; desnormalizar, con EXPLAIN ANALYZE.
Todo se prueba en `foodstore_desarrollo`, con respaldo previo y dentro de BEGIN … ROLLBACK.

## Parte 1 — FNBC

**REQ-01** WHEN se analiza la regla «dado un lote y un depósito, el responsable queda determinado;
cada responsable pertenece a un único depósito»
THE SYSTEM SHALL documentar las dependencias {lote, depósito} → responsable y responsable → depósito,
y no postular lote → depósito ni lote → responsable.
Se prueba con: informe U4, punto 4.2.a.

**REQ-02** WHEN se calculan las clausuras de los subconjuntos de atributos
THE SYSTEM SHALL listar el conjunto completo de claves candidatas ({lote, depósito} y {lote, responsable})
e indicar atributos primos y no primos.
Se prueba con: informe U4, punto 4.2.b.

**REQ-03** IF existe una dependencia cuyo determinante no es superclave
THEN THE SYSTEM SHALL declarar que la tabla no cumple FNBC (definición formal, no 3FN)
e identificar la dependencia violatoria (responsable → depósito).

**REQ-04** WHEN se descompone la tabla
THE SYSTEM SHALL crear responsable_deposito (PK responsable) y control_lote (PK lote + responsable)
con sus FOREIGN KEY, y una vista v_control_lote_almacen que reconstruya la relación original
mediante reunión natural.
Se prueba con: `postgres/normalizacion/tp_fnbc_control_lote.sql`.

**REQ-05** WHEN se migra la instancia de ejemplo (501/30/801, 502/30/801, 503/31/802)
THE SYSTEM SHALL ejecutar la migración dentro de una transacción y verificar con EXCEPT en ambos
sentidos que la vista devuelve exactamente las filas originales (0 y 0).
Se prueba con: `postgres/normalizacion/tp_fnbc_migracion_y_reversion.sql`.

**REQ-06** IF alguna verificación de equivalencia devuelve filas
THEN THE SYSTEM SHALL terminar en ROLLBACK y no dejar datos migrados.
WHEN la migración debe deshacerse después de un COMMIT
THE SYSTEM SHALL poder volver a la relación original con DROP VIEW y DROP TABLE de las dos
tablas descompuestas, conservando control_lote_almacen (plan de reversión).

## Parte 2 — Desnormalización controlada

**REQ-07** WHEN la consulta del top 5 de categorías del día supera el tiempo aceptable
THE SYSTEM SHALL medirla con EXPLAIN ANALYZE y registrar tiempo y nodo dominante antes de decidir.

**REQ-08** WHEN se elige la desnormalización
THE SYSTEM SHALL usar la vista materializada mv_top_categorias_dia con índice único (categoria, fecha)
y refrescarla con REFRESH MATERIALIZED VIEW CONCURRENTLY, sin bloquear lecturas.
Se prueba con: `postgres/normalizacion/tp_desnormalizacion_top_categorias.sql`.

**REQ-09** WHEN se mide la misma consulta sobre la vista materializada
THE SYSTEM SHALL registrar la tabla antes/después de tiempo y nodo dominante.

**REQ-10** WHEN se audita la sincronía
THE SYSTEM SHALL comparar la vista contra la fuente y devolver 0 filas; si devuelve filas,
THE SYSTEM SHALL refrescar la vista antes de usarla.
Se prueba con: `postgres/normalizacion/tp_desnormalizacion_auditoria.sql`.

**REQ-11** WHEN se decide revertir la desnormalización
THE SYSTEM SHALL poder hacerlo con DROP MATERIALIZED VIEW sin pérdida de datos,
porque las tablas originales no se modifican.
