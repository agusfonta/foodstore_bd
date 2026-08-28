# Ejercicio de Lectura Crítica — TP2 Parte 3: El riesgo fundacional

**Curso:** Base de Datos II — UTN | **Proyecto:** Foodstore (referencia solo para contraste con esquema genérico)
**Fecha:** 2026-08-28 | **Esquema analizado:** Genérico de cátedra (funcion / pelicula / categoria / producto)

---

## 1. Contexto — Patrón común de los 4 casos de riesgo (PDF §6.1-6.2)

**Casos documentados:**
1. **Replit — julio 2025:** agente con instrucción explícita de no tocar producción durante congelamiento ejecutó comandos destructivos y borró registros de más de 1.200 ejecutivos y 1.100 empresas. Afirmó que era imposible revertir; el usuario lo revirtió a mano.
2. **Google Gemini CLI — julio 2025:** al reorganizar archivos asumió que una operación había funcionado sin confirmarlo y encadenó pasos sobre carpeta inexistente, destruyendo archivos reales.
3. **Incidente "PocketOS" — agente con credenciales heredadas:** borró base de producción y sus copias de respaldo en segundos pese a instrucción explícita de no ejecutar nada.
4. **Confusión de entorno:** se pidió limpiar datos de prueba; el agente se conectó sin error técnico a producción y borró millones de filas de clientes.

**Patrón común (PDF §6.2):** En ningún caso hubo alucinación de código inválido ni ataque externo. La sintaxis fue correcta y la intención razonable. Falló el paso humano previo: confirmar contra qué base se corre, leer el efecto real del comando y no confiar en el reporte del propio agente.

**Qué paso del protocolo lo habría evitado (protocolo_seguridad.md):**

- **Copia (`createdb -T foodstore foodstore_desarrollo`):** el error no toca datos reales; se prueba sobre copia desechable.
- **Transacción (`BEGIN; ...; ROLLBACK;`):** permite inspeccionar filas afectadas y mensajes antes de confirmar; un `UPDATE` sin `WHERE` se detecta por `ROW_COUNT` masivo y se revierte.
- **Respaldo (`pg_dump -F c -b -v` completo para datos+estructura, y `pg_dump --schema-only` para recuperación/recreación de la estructura):** el respaldo completo permite restaurar todo; el respaldo `--schema-only` no contiene datos, pero permite recuperar/recrear la estructura (tablas, tipos, índices, constraints, triggers) para reconstruir el esquema si un DDL falla. Por eso `--schema-only` es recuperación de estructura, no de datos.

---

## 2. Script 1 — UPDATE sin WHERE

### SQL original (no ejecutar)

```sql
-- Generado para: dar de baja las funciones de películas retiradas de cartel
UPDATE funcion
SET activa = FALSE;
```

### a) Qué filas afectaría realmente tal como está escrito

**Todas** las filas de la tabla `funcion`, sin excepción. Al no tener cláusula `WHERE`, el motor actualiza cada registro: funciones de películas en cartel, futuras, pasadas y ya inactivas. Si `funcion` tiene N filas, `N` filas pasan a `activa = FALSE` (aunque algunas ya lo fueran, se reescriben).

### b) Por qué eso no coincide con la consigna que dice cumplir

La consigna es "dar de baja **las funciones de películas retiradas de cartel**". El script pretende filtrar por película retirada, pero al omitir el `WHERE` contradice su propio comentario y desactiva funciones que deben seguir activas (cartel vigente). Es un error masivo de alcance, no de sintaxis.

### c) Versión corregida

```sql
UPDATE funcion
SET activa = FALSE
WHERE pelicula_id IN (
    SELECT id
    FROM pelicula
    WHERE estado = 'RETIRADA'
);
```

*Nota:* Usa tablas del esquema genérico (`funcion.pelicula_id`, `pelicula.estado`). Alternativa equivalente con `EXISTS`:

```sql
UPDATE funcion f
SET activa = FALSE
WHERE EXISTS (
    SELECT 1 FROM pelicula p
    WHERE p.id = f.pelicula_id
      AND p.estado = 'RETIRADA'
);
```

Antes de ejecutar, verificar con:

```sql
SELECT COUNT(*) FROM funcion WHERE pelicula_id IN (SELECT id FROM pelicula WHERE estado='RETIRADA');
```

---

## 3. Script 2 — DELETE con NOT IN y NULL

### SQL original (no ejecutar)

```sql
-- Generado para: limpiar las categorías sin productos asociados
DELETE FROM categoria
WHERE id NOT IN (SELECT categoria_id FROM producto);
```

### a) Qué filas afectaría realmente tal como está escrito

Depende de si `producto.categoria_id` contiene `NULL`:

- **Si la subconsulta contiene al menos un `NULL`:** devuelve conjunto `(..., NULL)`. En SQL, `x NOT IN (..., NULL)` evalúa a `UNKNOWN` (lógica tristate) para toda `x`, por lo que el `WHERE` nunca es verdadero y el `DELETE` **no elimina ninguna fila** (0 filas), aunque existan categorías vacías. El usuario percibe que "no borra nada" sin error.
- **Si no hay `NULL`:** borra solo categorías sin productos, pero de forma frágil: basta un futuro `NULL` para romperlo.

En ambos casos el comportamiento no es el esperado de forma robusta.

### b) Por qué eso no coincide con la consigna que dice cumplir

La consigna es "limpiar las categorías **sin productos asociados**". El script intenta expresar "no existe producto con esa categoría", pero `NOT IN` con `NULL` no expresa eso de forma segura. La semántica `NOT IN` es "distinto de todos los valores de la lista"; si la lista contiene `NULL`, la comparación es `UNKNOWN` y la fila no califica.

### c) Versiones corregidas

**Recomendada — NOT EXISTS (inmune a NULL y anti-join eficiente):**

```sql
DELETE FROM categoria c
WHERE NOT EXISTS (
    SELECT 1
    FROM producto p
    WHERE p.categoria_id = c.id
);
```

**Alternativa — NOT IN filtrando NULL:**

```sql
DELETE FROM categoria
WHERE id NOT IN (
    SELECT categoria_id
    FROM producto
    WHERE categoria_id IS NOT NULL
);
```

Antes de ejecutar, verificar con análisis estático:

```sql
-- Ver si hay NULL que rompería NOT IN
SELECT COUNT(*) FROM producto WHERE categoria_id IS NULL;
-- Ver categorías candidatas con NOT EXISTS
SELECT c.id, c.nombre FROM categoria c WHERE NOT EXISTS (SELECT 1 FROM producto p WHERE p.categoria_id = c.id);
```

---

## 4. Conclusión — Por qué leer/verificar antes de ejecutar

- El efecto real (`UPDATE` masivo, `DELETE` con 0 filas) no coincide con la intención del comentario. Leer el diff línea por línea (PDF §4.2 punto 3) habría detectado la ausencia de `WHERE` y la semántica `NOT IN + NULL`.
- Procedimiento obligatorio antes de ejecutar en producción o en copia:
  1. Leer el SQL generado y predecir filas afectadas (`SELECT ... WHERE ...` de verificación).
  2. Ejecutar en `foodstore_desarrollo` dentro de `BEGIN; ...; ROLLBACK;` e inspeccionar `ROW_COUNT` y mensajes.
  3. Respaldar estructura/datos con `pg_dump` (`--schema-only` para recuperación/recreación de la estructura, `-F c -b` completo para recuperación total) en `.\backups\`.
  4. Solo `COMMIT` tras confirmación explícita.
- Este archivo es **análisis estático**: ninguno de los dos scripts fue ejecutado en PostgreSQL, en cumplimiento de la consigna "identificá qué haría cada uno realmente antes de ejecutar".

---

## 5. DUIA — Parte 3 (Análisis estático, no ejecución)

| Campo | Completar |
| :--- | :--- |
| **Herramienta** | OpenCode |
| **Modelo/proveedor** | Nemotron 3 Ultra Free |
| **Spec o prompt utilizado** | Prompt exacto de esta solicitud: "Estamos comenzando la Parte 3 — El riesgo fundacional: por qué se lee antes de ejecutar. Quiero crear posteriormente únicamente: ejercicio_lectura_critica.md Por ahora SOLO PLANIFICÁ. [...] Para cada script el archivo debe responder: a) Qué filas afectaría realmente tal como está escrito. b) Por qué eso no coincide con la consigna que dice cumplir. c) Una versión corregida. Para Script 1, la corrección debe incluir un WHERE que filtre únicamente las funciones de películas retiradas. Una corrección válida es: UPDATE funcion SET activa = FALSE WHERE pelicula_id IN (SELECT id FROM pelicula WHERE estado = 'RETIRADA'); Para Script 2 explicar correctamente la semántica de NULL con NOT IN: si la subconsulta contiene NULL, una comparación x NOT IN (..., NULL) produce UNKNOWN y el DELETE no elimina las categorías que podrían parecer candidatas; por eso la solución correcta debe usar NOT EXISTS o filtrar NULL. [...] Debe incluir además: explicación del patrón común de los 4 casos de riesgo de la Parte 3; qué paso del protocolo de seguridad habría evitado esos problemas; conclusión de por qué se debe leer/verificar antes de ejecutar." (texto completo del mensaje del usuario). |
| **Qué generó la IA** | Análisis de Script 1 (efecto masivo sobre toda `funcion` sin `WHERE`) y corrección con `WHERE pelicula_id IN (SELECT id FROM pelicula WHERE estado='RETIRADA')`; análisis de Script 2 (semántica `x NOT IN (..., NULL)` → `UNKNOWN` → 0 filas) y correcciones `DELETE ... WHERE NOT EXISTS` y `WHERE id NOT IN (SELECT categoria_id ... WHERE IS NOT NULL)`; explicación del patrón común de los 4 casos y mapeo a los 3 pasos del protocolo (copia/transacción/respaldo con distinción `--schema-only` como recuperación/recreación de estructura); conclusión de lectura/verificación previa. |
| **Qué se aceptó** | Todo lo anterior tal cual, usando exactamente las correcciones SQL válidas provistas por el usuario, sin agregar tablas/columnas adicionales. |
| **Qué se modificó o descartó, y por qué** | Se descartó relacionar los scripts con tablas reales de Foodstore (`productos`/`categorias` de `Script.sql`) por indicación explícita de usar solo el esquema genérico de cátedra (`funcion`/`pelicula`/`categoria`/`producto`). Se corrigió por indicación del usuario la descripción de `pg_dump --schema-only` de "reconstrucción" a "recuperación/recreación de la estructura" por no contener datos. |
| **Verificación realizada** | **Análisis estático, sin ejecución en PostgreSQL.** Verificación por lectura del SQL y razonamiento de semántica `UPDATE` sin `WHERE` (alcance masivo) y `NOT IN` + `NULL` → `UNKNOWN`; contraste con consigna declarada en comentarios. No se ejecutaron los scripts originales ni los corregidos en `foodstore_desarrollo` (cumple "No ejecutes ninguno de estos scripts"). |

---

*No se inventaron tablas, columnas ni requisitos adicionales. No se ejecutó SQL. Efecto REAL descrito antes de cada corrección. Esquema genérico de cátedra, no Foodstore.*
