# Bitácora de uso de IA — TP8

Equipo: Agustina Fontagnol, Gianella Peña, Martina Suarez · 3 de noviembre de 2026
Herramientas: Kiro (spec), OpenCode (esquema, semáforo, code review y documentos) y Claude Code (revisión y orden final).
El texto exacto de cada prompt y la tabla de la Declaración de Uso de IA están en `DUIA.md`; acá va el relato de cada uso.

---

## Entrada 1 — Esquema SQLite (`movil/schema_sqlite.sql`)

- **Qué pedí:** las cuatro tablas STRICT de la tablet con sus CHECK, claves foráneas, `PRAGMA foreign_keys = ON` y tres índices.
- **Qué acepté:** columnas y tipos, todos los CHECK (precio no negativo, cantidad > 0, booleanos 0/1, forma de pago, estado) y las FK: `ON DELETE CASCADE` hacia el borrador y `RESTRICT` hacia el producto.
- **Qué descarté o cambié:** sin `AUTOINCREMENT` (el `id` del producto viene del servidor y `id_local` es un UUID). Agregué `DEFAULT (datetime('now'))` en las fechas para no pasarlas en cada INSERT.
- **Cómo lo comprobé:** `pruebas_sqlite.sql` — cantidad 0 da `CHECK constraint failed` y producto inexistente da `FOREIGN KEY constraint failed`, sin filas nuevas.

## Entrada 2 — Semáforo (`movil/semaforo.sql`)

- **Qué pedí:** comparar cada solicitud PENDIENTE con `snapshot_servidor` y guardar estado y motivo (rojo, amarillo, verde), sin reevaluar lo ya resuelto.
- **Qué acepté:** el orden rojo, amarillo, verde con un `LEFT JOIN` de `item_borrador` a `snapshot_servidor`, el motivo con valores concretos y el filtro `WHERE estado = 'PENDIENTE'`.
- **Qué corregí:** al revisar `cola_sync` después de C2, el motivo de precio decía `0`. La concatenación `'texto' || x / 100 || ...` se evalúa mal porque `||` tiene más precedencia que `/` en SQLite. Se dejó el motivo con los centavos enteros (`visto=350, actual=400`).
- **Qué descarté:** la copia del SQL del semáforo que el simulador en Python llevaba pegada. Ahora el simulador ejecuta `semaforo.sql`, así el SQL existe una sola vez.
- **Cómo lo comprobé:** `python movil/simulador_casos.py` arma una base temporal y los casos C2 a C6 dan el resultado esperado.

## Entrada 3 — Code review de los scripts de la cursada

- **Qué pedí:** a OpenCode (agente Plan), que leyera `parcial1_02` a `parcial1_10` y marcara problemas de diseño, seguridad y rendimiento, de varias unidades. Después se pidió a Claude Code completar la revisión con el resto de los scripts de la cursada (`parcial1_01`, anexos de TP5, `sql/`, `entrega_tp6/sql` y `entrega_tp7`), que sumó los hallazgos 6 a 14 del informe.
- **Qué acepté:** el hallazgo de U6 (contraseñas en texto plano en datos de prueba). Se corrigió en `parcial1_09` y `parcial1_10`: hash falso con formato bcrypt y comentario de seguridad.
- **Qué descarté y por qué:** el hallazgo 1 (race condition en `sp_crear_pedido`: el `ORDER BY 1` ordena los bloqueos); el 3 (CHECK en vista materializada: PostgreSQL no lo admite y el origen ya lo garantiza); el 5 (índice sobre `fecha`: el compuesto ya lo cubre). El 2 ya estaba mitigado con vistas.
- **Cómo lo comprobé:** en una copia descartable de `foodstore_desarrollo` (esos scripts no estaban aplicados en la base de trabajo): dos sesiones de psql sobre el mismo producto, `EXPLAIN` de los índices y el intento de crear el CHECK. Al revisar los planes vi que el planner usa índices de TP4 (`idx_tp4_*`) además de los que nombraba la IA, y lo ajusté en el informe. El detalle está en el informe, consigna 3.c.

## Entrada 4 — Mapa de los tres motores y plan de mantenimiento

- **Qué pedí:** un mapa de PostgreSQL, MongoDB y SQLite con quién manda sobre cada dato, y el plan de respaldos, restauración y revisión de solicitudes.
- **Qué acepté:** PostgreSQL como única fuente de verdad, el flujo en un solo sentido y no respaldar el archivo SQLite porque se regenera desde el servidor.
- **Qué descarté y por qué:** Redis como cuarto motor (fuera del alcance); `pg_cron` y archivado continuo de WAL (el plan de la Unidad 6 usa un script de `pg_dump`); y los números inventados del primer borrador (versión de MongoDB, cantidad de productos, tamaño del respaldo). El plan final se apoya en los archivos reales de U6 y U7.
- **Cómo lo comprobé:** cotejo con `entrega_tp6/sql` (respaldo y simulacro de restauración) y con `entrega_tp7/modelo_documental.md` (colección `foodstore_u7.pedidos`).

## Entrada 5 — Spec en Kiro (`docs/kiro/`)

- **Qué pedí:** `requirements.md` con requisitos EARS, `design.md` y `tasks.md`, antes de generar el esquema.
- **Qué acepté:** el patrón EARS (WHEN / IF-THEN … THE SYSTEM SHALL) y la idea de una tabla de trazabilidad.
- **Qué descarté y por qué:** el requisito sobre cifrado en reposo (requeriría SQLCipher) y los casos de uso, requisitos no funcionales y glosario extensos. Los cuatro requisitos iniciales no apuntaban a un caso concreto, así que se rehicieron como REQ-01 a REQ-04, ligados a C2, C3, C4 y C6. `design.md` y `tasks.md` quedaron breves.
- **Cómo lo comprobé:** cada requisito se corresponde con un caso que se corre en `simulador_casos.py`.

## Entrada 6 — Revisión y orden final de la entrega (Claude Code)

- **Qué pedí:** ordenar la carpeta según la consigna, dejar cada dato en un solo lugar, crear el CSV que faltaba y juntar la DUIA en un archivo.
- **Qué acepté:** la estructura de `README.md`, `movil/`, `db/` y `docs/`; un solo informe (`informe.pdf`); `simulador_casos.py` como reemplazo de `crear_y_probar_db.py`.
- **Qué descarté o dejé pendiente:** `servidor_snapshot.csv` se exportó de `v_snapshot_movil` en `foodstore_desarrollo` (con respaldo `pg_dump` previo, usando `PGPASSWORD` del `.env` del proyecto); la consulta final de la consigna 2.c dio los mismos valores antes y después (200000 pedidos, stock 553, misma huella md5 de los productos 1 a 10). La corrección del hallazgo 4 se aplicó a pedido del equipo.
- **Cómo lo comprobé:** `python movil/simulador_casos.py` corre los casos en una base temporal y los seis resultados coinciden con lo esperado; `foodstore_movil.db` se entrega limpia (`--limpia`) y se comparó con `servidor_snapshot.csv`: `snapshot_servidor` y `producto_cache` tienen las mismas 10 filas.

## Entrada 7 — Ronda de mejoras tras la corrección (Claude Code)

- **Qué pedí:** resolver, de a una, las observaciones de la corrección: cambios del servidor en PostgreSQL y no en SQLite (C2 y C4), UUID reales, índice único parcial de `cola_sync`, registro de evaluaciones, C3 con el servidor involucrado, más requisitos EARS, inventario de scripts U1–U8 y guion de defensa.
- **Qué acepté:** que cada caso haga el `UPDATE` en `foodstore_desarrollo` dentro de `BEGIN`, exporte `v_snapshot_movil` desde esa misma transacción y termine en `ROLLBACK` (cumple la consigna 2.c y el protocolo de seguridad); `CHECK` con `GLOB` para UUID v4; trigger que llena `evaluacion_sync`; 11 requisitos EARS con tabla de trazabilidad.
- **Qué descarté o cambié:** como alternativa se evaluó confirmar (COMMIT) los cambios en PostgreSQL y revertirlos después con otro `UPDATE`; se descartó porque deja la copia modificada si algo falla a la mitad. El caso C3 anterior (140 unidades contra un stock visto de 61) no usaba el servidor: ahora el borrador es de 50 unidades (válido con la copia local) y el servidor baja el stock a 10. Se dejó `--emular` solo como plan B para quien no pueda conectarse. La contraseña de PostgreSQL se toma de `PGPASSWORD`, nunca del código.
- **Cómo lo comprobé:** `pruebas_sqlite.sql` (UUID inválido y segunda solicitud PENDIENTE dan error y no dejan filas); `python movil/simulador_casos.py` (casos C2 a C6 con el resultado esperado, una evaluación por solicitud y PostgreSQL sin cambios antes y después).

