# Informe de Concurrencia — Foodstore TP2 Parte 2

**Motor:** PostgreSQL 17.11
**Base de trabajo:** foodstore_desarrollo (copia de foodstore via `createdb -T foodstore`)
**SO:** Windows — terminal CMD + psql 17.11
**Usuario/Host/Puerto:** postgres / localhost / 5432
**Tablas reales utilizadas:** `productos` (Script.sql:46), `categorias` (Script.sql:32)
**Fecha:** 2026-08-28

## Resumen ejecutivo

Se reproducen con dos sesiones `psql` paralelas tres fenómenos de concurrencia sobre el esquema real de `Script.sql`:

1. Lectura no repetible (READ COMMITTED vs REPEATABLE READ)
2. Lectura fantasma (READ COMMITTED vs REPEATABLE READ)
3. Espera por bloqueo (SELECT ... FOR UPDATE)

Nivel inicial: `READ COMMITTED` (default PostgreSQL). Verificación: `REPEATABLE READ` y mecanismo de bloqueo pesimista.

---

## Experimento 1 — Lectura no repetible

### Objetivo
Demostrar que en `READ COMMITTED` una misma fila leída dos veces dentro de una transacción puede devolver valores distintos si otra transacción la modifica y confirma entre ambas lecturas, y verificar que `REPEATABLE READ` evita el fenómeno mediante snapshot.

### Preparación
- Tabla: `productos` (`id BIGINT`, `precio NUMERIC(10,2)`)
- Producto utilizado: `productos.id = 2` (precio inicial verificado `100.00`)
- No se asumen IDs; `id=2` corresponde al producto de prueba creado ("Producto Bloqueo") asociado a "Cat Bloqueo" (id=2).

### Pasos Sesión A (READ COMMITTED)
```sql
-- psql -U postgres -h localhost -p 5432 -d foodstore_desarrollo
BEGIN; -- READ COMMITTED (default)
SELECT precio FROM productos WHERE id = 2; -- 1ra lectura
-- pausa: Sesión B actualiza
SELECT precio FROM productos WHERE id = 2; -- 2da lectura
COMMIT;
```

### Pasos Sesión B
```sql
BEGIN;
UPDATE productos SET precio = 250.00 WHERE id = 2;
COMMIT;
```

### Resultado observado
- Primera lectura de A: `precio = 100.00`
- Sesión B actualizó precio a `250.00` y confirmó (`UPDATE 1` / `COMMIT`)
- Segunda lectura de A: `precio = 250.00`
- **Fenómeno observado: lectura no repetible reproducida.**

### Explicación
En `READ COMMITTED` cada sentencia ve los datos confirmados al momento de ejecutarse. La segunda lectura ve el `COMMIT` de B.

### Mecanismo / Nivel de aislamiento que evita el fenómeno
`REPEATABLE READ` (snapshot al inicio de la transacción) o `SERIALIZABLE`.

### Repetición para verificar la solución
```sql
-- Sesión A
BEGIN ISOLATION LEVEL REPEATABLE READ;
SELECT precio FROM productos WHERE id = 2; -- 100.00 (1ra lectura)
-- Sesión B: UPDATE precio = 250.00 WHERE id = 2; COMMIT;
SELECT precio FROM productos WHERE id = 2; -- 100.00 (2da lectura, no cambia)
COMMIT;
```
- **Resultado verificación:** Primera lectura `100.00`; tras `UPDATE` de B y `COMMIT`, segunda lectura de A `100.00`.

### Conclusión
`REPEATABLE READ` evitó la lectura no repetible. El snapshot de A no vio el cambio confirmado por B hasta iniciar una nueva transacción.

---

## Experimento 2 — Lectura fantasma

### Objetivo
Demostrar que un `COUNT(*)` repetido dentro de una transacción cambia si otra transacción inserta una fila que cumple la condición del `WHERE`, y verificar que `REPEATABLE READ` evita ver el nuevo registro dentro del snapshot.

### Preparación
- Tabla: `productos` (`categoria_id BIGINT`, `id BIGINT`)
- Categoría utilizada: `categorias.id = 3` ("Cat Fantasma")
- Estado inicial verificado en `READ COMMITTED`: `COUNT(*) = 2` para `categoria_id = 3` (productos "Prod Fantasma 1" y "Prod Fantasma 2").

### Pasos Sesión A (READ COMMITTED)
```sql
BEGIN; -- READ COMMITTED
SELECT COUNT(*) FROM productos WHERE categoria_id = 3; -- 2 (1ra consulta)
-- pausa: Sesión B inserta
SELECT COUNT(*) FROM productos WHERE categoria_id = 3; -- 3 (2da consulta)
COMMIT;
```

### Pasos Sesión B
```sql
BEGIN;
INSERT INTO productos (nombre, precio, stock, disponible, categoria_id)
VALUES ('Prod Fantasma 3', 60.00, 3, TRUE, 3);
COMMIT;
```

### Resultado observado
- Primera consulta `COUNT(*) = 2`
- Sesión B insertó un producto y confirmó
- Segunda consulta `COUNT(*) = 3`
- **Fenómeno observado: lectura fantasma reproducida.**

### Explicación
En `READ COMMITTED` cada sentencia ve filas confirmadas al momento de ejecutarse; la nueva fila que cumple el `WHERE` aparece en la segunda consulta.

### Mecanismo / Nivel de aislamiento que evita el fenómeno
En PostgreSQL `REPEATABLE READ` ya evita fantasmas (snapshot al inicio); estándar SQL exige `SERIALIZABLE`.

### Repetición para verificar la solución
```sql
-- Sesión A
BEGIN ISOLATION LEVEL REPEATABLE READ;
SELECT COUNT(*) FROM productos WHERE categoria_id = 3; -- 3 (snapshot inicial ya con 3 tras experimento anterior)
-- Sesión B: INSERT nuevo producto para categoria_id=3; COMMIT; -- inserta "Prod Fantasma 4"
SELECT COUNT(*) FROM productos WHERE categoria_id = 3; -- 3 (no ve el nuevo)
COMMIT;
```
- **Resultado verificación:** Segunda consulta `COUNT(*) = 3` (no aparece el nuevo registro).

### Conclusión
`REPEATABLE READ` evitó que apareciera el nuevo registro en el snapshot de A.

---

## Experimento 3 — Espera por bloqueo

### Objetivo
Reproducir espera por bloqueo pesimista con `SELECT ... FOR UPDATE` sobre la misma fila desde dos transacciones concurrentes y observar el estado de espera en `pg_stat_activity`.

### Preparación
- Tabla: `productos`
- Producto utilizado: `productos.id = 2` ("Producto Bloqueo")

### Pasos Sesión A
```sql
BEGIN;
SELECT * FROM productos WHERE id = 2 FOR UPDATE; -- adquiere lock exclusivo de fila
-- mantiene transacción abierta
```

### Pasos Sesión B
```sql
BEGIN;
SELECT * FROM productos WHERE id = 2 FOR UPDATE; -- queda esperando
```

### Resultado observado
- Sesión A ejecutó `SELECT ... FOR UPDATE` dentro de una transacción.
- Sesión B ejecutó el mismo `SELECT ... FOR UPDATE` y quedó esperando (bloqueada, sin error inmediato).
- `pg_stat_activity` para el `pid` de B mostró:
  ```
  state = active
  wait_event_type = Lock
  wait_event = transactionid
  ```
- `COMMIT` de A liberó el bloqueo y B continuó y obtuvo la fila (`SELECT` devolvió la fila bloqueada).

### Explicación
`SELECT ... FOR UPDATE` adquiere lock exclusivo de fila hasta `COMMIT`/`ROLLBACK`. La segunda transacción que solicita el mismo lock queda en cola (wait queue) hasta liberación. No es anomalía de aislamiento sino mecanismo de concurrencia pesimista.

### Mecanismo / Nivel de aislamiento
El bloqueo es independiente del nivel de aislamiento. Se gestiona con:
- `SELECT ... FOR UPDATE NOWAIT` → error inmediato `55P03` si no puede obtener lock
- `SELECT ... FOR UPDATE SKIP LOCKED` → omite filas bloqueadas
- `SET lock_timeout = '2s'` → cancela espera tras timeout
- Mantener transacciones cortas y orden consistente de adquisición de locks.

### Repetición para verificar gestión
```sql
-- Sesión A: BEGIN; SELECT ... FOR UPDATE WHERE id=2;
-- Sesión B: BEGIN; SET lock_timeout = '2s'; SELECT ... FOR UPDATE WHERE id=2; -- ERROR: canceling statement due to lock timeout
-- Alternativa: SELECT ... FOR UPDATE NOWAIT WHERE id=2; -- ERROR 55P03 could not obtain lock on row
```

### Conclusión
La espera por bloqueo fue reproducida correctamente. El comportamiento observado coincide con el mecanismo documentado de PostgreSQL para locks de fila.

---

## Evidencias / Capturas

Las capturas fueron guardadas durante la ejecución real en `foodstore_desarrollo` y se referencian sin inventar contenido adicional:

- **Exp.1 READ COMMITTED:** Captura de Sesión A con 1ra `SELECT precio=100.00`, Sesión B `UPDATE precio=250.00` + `COMMIT`, y 2da `SELECT precio=250.00`.
- **Exp.1 REPEATABLE READ:** Captura de Sesión A `BEGIN ISOLATION LEVEL REPEATABLE READ` con 1ra lectura `100.00`, Sesión B `UPDATE/COMMIT`, y 2da lectura `100.00`.
- **Exp.2 READ COMMITTED:** Captura de `SELECT COUNT(*)=2` → `INSERT` de B → `SELECT COUNT(*)=3`.
- **Exp.2 REPEATABLE READ:** Captura de `SELECT COUNT(*)=3` (snapshot con 3) → `INSERT` de B → `SELECT COUNT(*)=3` (sin ver nuevo).
- **Exp.3 Bloqueo:** Capturas de Sesión A `SELECT ... FOR UPDATE`, Sesión B bloqueada, consulta `SELECT pid, state, wait_event_type, wait_event, query FROM pg_stat_activity` mostrando `active / Lock / transactionid`, y desbloqueo tras `COMMIT` de A.

No se afirman capturas ni escenarios no ejecutados.

---

## Datos de prueba y limpieza

- Se utilizaron `productos.id = 2` y `categoria_id = 3` durante los experimentos.
- Se crearon para las pruebas la categoría "Cat Bloqueo" (id=2) y el producto "Producto Bloqueo" (id=2).
- Se creó la categoría "Cat Fantasma" (id=3) y los productos "Prod Fantasma 1" a "Prod Fantasma 4" (ids 3,4,5,6).
- Al finalizar los experimentos, se eliminaron explícitamente esos 5 productos y esas 2 categorías.
- No quedaron esos datos de prueba en `foodstore_desarrollo`.

---

## Conclusión general

Los tres fenómenos se comportaron según la teoría de MVCC de PostgreSQL 17.11: `READ COMMITTED` permite lectura no repetible y lectura fantasma (cada sentencia ve datos confirmados al momento), `REPEATABLE READ` los evita mediante snapshot al inicio de la transacción, y `SELECT ... FOR UPDATE` genera espera por bloqueo pesimista gestionable con `NOWAIT`/`SKIP LOCKED`/`lock_timeout`.
