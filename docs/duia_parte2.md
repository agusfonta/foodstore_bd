# DUIA — Parte 2: Concurrencia (Foodstore TP2)

**Proyecto:** Foodstore — PostgreSQL 17.11 (Windows — terminal CMD + psql 17.11, postgres@localhost:5432, base foodstore_desarrollo)
**Informe asociado:** informe_concurrencia.md
**Fecha:** 2026-08-28
**Orden documentado:** 1) Espera por bloqueo, 2) Lectura no repetible, 3) Lectura fantasma (orden solicitado para esta DUIA)

---

## Escenario 1 — Espera por bloqueo con SELECT ... FOR UPDATE (productos.id=2)

| Campo | Completar |
| :--- | :--- |
| **Herramienta** | OpenCode |
| **Modelo/proveedor** | Nemotron 3 Ultra Free |
| **Spec o prompt utilizado** | Prompt exacto del historial (común a los tres escenarios, parte correspondiente a este escenario: "3. Espera por bloqueo"): "Estamos comenzando la Parte 2 del TP. Analizá únicamente el esquema actual de PostgreSQL del proyecto y proponé experimentos reproducibles para estos tres escenarios: 1. Lectura no repetible. 2. Lectura fantasma. 3. Espera por bloqueo. Usá solamente las tablas reales de Script.sql. Para cada escenario indicá: - tabla y columnas a utilizar; - datos necesarios; - Sesión A, comando por comando; - Sesión B, comando por comando; - nivel de aislamiento inicial; - qué resultado debería observarse; - qué nivel de aislamiento o mecanismo de bloqueo debería evitar el fenómeno; - cómo repetir el experimento para verificar esa solución. IMPORTANTE: - No modifiques archivos. - No ejecutes SQL contra PostgreSQL. - No inventes columnas ni tablas. - No supongas datos que no existan. - Quiero un plan de experimento, no una implementación. Al final recomendá el orden más sencillo para realizar los tres experimentos." |
| **Qué generó la IA** | Mecanismo propuesto: `SELECT ... FOR UPDATE` adquiere lock exclusivo de fila hasta `COMMIT`/`ROLLBACK`; una segunda transacción que solicita el mismo lock queda en espera (wait queue) hasta liberación. Como gestión posible mencionó `SELECT ... FOR UPDATE NOWAIT` / `SKIP LOCKED` / `SET lock_timeout` y mantener transacciones cortas con orden consistente de adquisición. Resumen sin inventar cita textual; no se copia la explicación de `informe_concurrencia.md` como si fuera texto original de la IA. |
| **Qué se aceptó** | Secuencia propuesta A `SELECT ... FOR UPDATE WHERE id=2` dentro de transacción → B mismo `SELECT` queda bloqueado → verificación en `pg_stat_activity` → `COMMIT` de A libera a B. Aceptado como diseño del experimento. |
| **Qué se modificó o descartó, y por qué** | No se afirma ejecución de `NOWAIT`, `SKIP LOCKED` ni `lock_timeout`. Fueron mencionados por la IA como mecanismos posibles, pero **no fueron ejecutados** en la verificación real; se deja constancia explícita para no inventar ejecución. Nada descartado de la explicación principal sobre espera por bloqueo. |
| **Verificación realizada** | **Resultados reales en PostgreSQL 17.11 sobre `foodstore_desarrollo` (fuente `informe_concurrencia.md:132-183`):** Sesión A ejecutó `SELECT * FROM productos WHERE id = 2 FOR UPDATE` dentro de `BEGIN` y mantuvo transacción abierta. Sesión B ejecutó el mismo `SELECT ... FOR UPDATE` y quedó esperando (bloqueada, sin error inmediato). `pg_stat_activity` para el `pid` de B mostró: `state=active`, `wait_event_type=Lock`, `wait_event=transactionid`. `COMMIT` de A liberó el bloqueo y B continuó y obtuvo la fila. Fenómeno reproducido; la explicación de espera por bloqueo fue verificada en el motor. |

---

## Escenario 2 — Lectura no repetible (productos.id=2, precio)

| Campo | Completar |
| :--- | :--- |
| **Herramienta** | OpenCode |
| **Modelo/proveedor** | Nemotron 3 Ultra Free |
| **Spec o prompt utilizado** | Mismo prompt exacto del historial que Escenario 1 (común a los tres escenarios, parte correspondiente a este escenario: "1. Lectura no repetible"): "Estamos comenzando la Parte 2 del TP. Analizá únicamente el esquema actual de PostgreSQL del proyecto y proponé experimentos reproducibles para estos tres escenarios: 1. Lectura no repetible. 2. Lectura fantasma. 3. Espera por bloqueo. Usá solamente las tablas reales de Script.sql. Para cada escenario indicá: - tabla y columnas a utilizar; - datos necesarios; - Sesión A, comando por comando; - Sesión B, comando por comando; - nivel de aislamiento inicial; - qué resultado debería observarse; - qué nivel de aislamiento o mecanismo de bloqueo debería evitar el fenómeno; - cómo repetir el experimento para verificar esa solución. IMPORTANTE: - No modifiques archivos. - No ejecutes SQL contra PostgreSQL. - No inventes columnas ni tablas. - No supongas datos que no existan. - Quiero un plan de experimento, no una implementación. Al final recomendá el orden más sencillo para realizar los tres experimentos." |
| **Qué generó la IA** | Explicación propuesta: en `READ COMMITTED` cada sentencia ve datos confirmados al momento de ejecutarse, por lo que la segunda lectura de A ve el `COMMIT` de B (`100.00` → `250.00`); en `REPEATABLE READ` el snapshot al inicio de la transacción evita el fenómeno y la segunda lectura sigue viendo el valor inicial (`100.00`). Resumen sin cita textual inventada. |
| **Qué se aceptó** | Explicación sobre `READ COMMITTED` vs `REPEATABLE READ` y diseño de pasos con `productos.precio` (`id=2`). Aceptado como guía para reproducir y para la repetición con `REPEATABLE READ`. |
| **Qué se modificó o descartó, y por qué** | Se descartó afirmar que se ejecutó `SERIALIZABLE`. Fue mencionado como alternativa del estándar/SQL, pero **no se ejecutó** ni verificó en esta parte; solo se verificó `REPEATABLE READ`. |
| **Verificación realizada** | **Resultados reales:** `READ COMMITTED`: primera lectura de A `productos.id=2` `precio 100.00` → Sesión B `UPDATE productos SET precio = 250.00 WHERE id=2` y `COMMIT` → segunda lectura de A `250.00` (lectura no repetible reproducida). `REPEATABLE READ`: primera lectura `100.00` → B actualizó a `250.00` y confirmó → segunda lectura de A `100.00` (fenómeno evitado). **La explicación fue verificada en el motor y confirmada.** |

---

## Escenario 3 — Lectura fantasma (productos categoria_id=3, COUNT*)

| Campo | Completar |
| :--- | :--- |
| **Herramienta** | OpenCode |
| **Modelo/proveedor** | Nemotron 3 Ultra Free |
| **Spec o prompt utilizado** | Mismo prompt exacto del historial que Escenario 1 (común a los tres escenarios, parte correspondiente a este escenario: "2. Lectura fantasma"): "Estamos comenzando la Parte 2 del TP. Analizá únicamente el esquema actual de PostgreSQL del proyecto y proponé experimentos reproducibles para estos tres escenarios: 1. Lectura no repetible. 2. Lectura fantasma. 3. Espera por bloqueo. Usá solamente las tablas reales de Script.sql. Para cada escenario indicá: - tabla y columnas a utilizar; - datos necesarios; - Sesión A, comando por comando; - Sesión B, comando por comando; - nivel de aislamiento inicial; - qué resultado debería observarse; - qué nivel de aislamiento o mecanismo de bloqueo debería evitar el fenómeno; - cómo repetir el experimento para verificar esa solución. IMPORTANTE: - No modifiques archivos. - No ejecutes SQL contra PostgreSQL. - No inventes columnas ni tablas. - No supongas datos que no existan. - Quiero un plan de experimento, no una implementación. Al final recomendá el orden más sencillo para realizar los tres experimentos." |
| **Qué generó la IA** | Explicación propuesta: en `READ COMMITTED` el `COUNT(*)` repetido ve la fila insertada y confirmada por B que cumple el `WHERE` (`2` → `3`); en `REPEATABLE READ` el snapshot al inicio no ve la nueva fila (`3` → `3`). Sin cita inventada. |
| **Qué se aceptó** | Diseño con `productos WHERE categoria_id=3` y `COUNT(*)` y verificación con `REPEATABLE READ` (en PostgreSQL ya evita fantasmas; estándar exige `SERIALIZABLE` solo mencionado). |
| **Qué se modificó o descartó, y por qué** | Se descartó afirmar ejecución de `SERIALIZABLE` — solo mencionado como exigencia del estándar, no ejecutado ni verificado. |
| **Verificación realizada** | **Resultados reales:** `READ COMMITTED`: `COUNT inicial 2` para `categoria_id=3` → B insertó un producto (`Prod Fantasma 3`) y confirmó → `COUNT posterior 3` (fantasma reproducido). `REPEATABLE READ`: `COUNT inicial 3` (snapshot ya con 3 productos tras experimento anterior) → B insertó otro producto (`Prod Fantasma 4`) y confirmó → `COUNT posterior 3` (nuevo registro no visible en snapshot, fenómeno evitado). **Verificación confirma explicación propuesta.** |

---

## Trazabilidad y constancia de verificación

- Las tres explicaciones/mecanismos propuestos por la IA fueron **verificados en PostgreSQL 17.11 sobre `foodstore_desarrollo`** con dos sesiones `psql` paralelas (CMD + psql 17.11). Los resultados reales del motor confirmaron lo propuesto, tal como exige PDF P.5 §5.2 punto 4 ("Registrar si la IA acertó").
- `informe_concurrencia.md` es la fuente de los comandos y resultados reales, pero su texto explicativo **no se replica como cita textual de la IA**.
- No se afirma ejecución de `NOWAIT`, `SKIP LOCKED`, `lock_timeout` ni `SERIALIZABLE`: fueron mencionados como mecanismos posibles en la explicación, pero no ejecutados en la verificación real.
- Datos de prueba asociados: "Cat Bloqueo" (id=2) / "Producto Bloqueo" (id=2) y "Cat Fantasma" (id=3) / "Prod Fantasma 1" a "Prod Fantasma 4" (ids 3,4,5,6) — creados para las pruebas y eliminados explícitamente al finalizar; no quedaron en `foodstore_desarrollo` (`informe_concurrencia.md:201-207`).

## Nota sobre prompts exactos

Los prompts exactos transcriptos arriba corresponden literalmente al mensaje del usuario del historial: "Estamos comenzando la Parte 2 del TP. Analizá únicamente el esquema actual de PostgreSQL del proyecto y proponé experimentos reproducibles para estos tres escenarios: 1. Lectura no repetible. 2. Lectura fantasma. 3. Espera por bloqueo..." (texto completo en cada escenario). No se inventaron prompts adicionales.
