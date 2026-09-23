# Informe de mediciones: equivalencia de vistas de reportes

**Base de datos:** foodstore (PostgreSQL 17)  
**Archivos comparados:**
- `db/vistas_reportes_prompt_opencode.sql` — vistas generadas con prompt OpenCode
- `db/vistas_reportes_prompt_propio.sql` — vistas generadas con prompt propio

---

## Metodología

Para cada una de las 3 vistas se realizó:

1. **Análisis estático** — comparación de nombre de vista, columnas expuestas, aliases, JOIN, filtros WHERE y política de seguridad entre ambas versiones.
2. **Consulta de equivalencia** — query SQL que el estudiante debe ejecutar contra la base de datos para verificar que ambas versiones devuelven el mismo conjunto de filas. Se usa `EXCEPT` en ambas direcciones: si los dos `EXCEPT` devuelven 0 filas, los resultados son idénticos.
3. **Veredicto** — la vista se considera válida solo si el análisis estático y la prueba de equivalencia coinciden.

---

## Vista 1 — Productos vigentes con categoría

### Versiones en cada archivo

| Aspecto | prompt_opencode | prompt_propio |
|---|---|---|
| Nombre de vista | `v_productos_vigentes_con_categoria` | `v_productos_vigentes` |
| Columnas expuestas | `producto_id, producto_nombre, precio, stock, disponible, categoria_id, categoria_nombre` | `id, nombre, precio, stock, categoria` |
| Columnas de más | `p.disponible`, `p.id` (como `categoria_id`), `c.id` (como `categoria_id`) | — |
| Columnas de menos | — | `p.disponible`, `c.id` (no expone el id de categoría) |
| JOIN | `productos p JOIN categorias c ON c.id = p.categoria_id` | idem |
| Filtro WHERE | `p.eliminado=FALSE AND p.deleted_at IS NULL AND c.eliminado=FALSE AND c.deleted_at IS NULL` | idem |
| Seguridad | sin datos sensibles | sin datos sensibles |

**Diferencias detectadas:**
- La versión opencode expone 7 columnas (`disponible`, `categoria_id` incluidos); la versión propia expone 5 (omite `disponible` e `id` de categoría).
- Los aliases difieren: opencode usa `producto_id / producto_nombre / categoria_nombre`, propio usa `id / nombre / categoria`.
- El conjunto de filas (filas retornadas, no columnas) es el mismo porque el JOIN y los filtros WHERE son equivalentes.

### Consulta de equivalencia (columnas comunes)

Ejecutar las dos sentencias siguientes. Ambas deben devolver **0 filas** para que la vista sea válida.

```sql
-- Filas en opencode que NO están en propio (columnas comunes)
SELECT producto_id, producto_nombre, precio, stock
FROM v_productos_vigentes_con_categoria
EXCEPT
SELECT id, nombre, precio, stock
FROM v_productos_vigentes;

-- Filas en propio que NO están en opencode (columnas comunes)
SELECT id, nombre, precio, stock
FROM v_productos_vigentes
EXCEPT
SELECT producto_id, producto_nombre, precio, stock
FROM v_productos_vigentes_con_categoria;
```

**Resultado esperado:** 0 filas en ambas consultas.

**Consulta alternativa completa (conteo):**

```sql
SELECT
    (SELECT COUNT(*) FROM v_productos_vigentes_con_categoria) AS total_opencode,
    (SELECT COUNT(*) FROM v_productos_vigentes)               AS total_propio;
```

**Resultado esperado:** ambos conteos iguales.

### Veredicto — Vista 1

| Criterio | Estado |
|---|---|
| Filtros WHERE idénticos | ✅ |
| JOIN idéntico | ✅ |
| Seguridad (sin datos sensibles) | ✅ |
| Conjunto de filas equivalente | ✅ (verificar con queries arriba) |
| Columnas expuestas idénticas | ⚠️ Difieren en cantidad y aliases — normal dado que los prompts pedían columnas distintas |

**Vista válida** una vez ejecutadas las consultas de equivalencia sin diferencias de filas.

---

## Vista 2 — Pedidos con datos del cliente

### Versiones en cada archivo

| Aspecto | prompt_opencode | prompt_propio |
|---|---|---|
| Nombre de vista | `v_pedidos_con_cliente` | `v_pedidos_clientes` |
| Columnas expuestas | `pedido_id, fecha, estado, total, forma_pago, cliente_id, cliente_nombre, cliente_apellido, cliente_mail, cliente_celular` | `id, fecha, estado, total, forma_pago, nombre, apellido, mail, celular` |
| Columnas de más | `cl.id` (como `cliente_id`) | — |
| Columnas de menos | — | no expone `cl.id` |
| JOIN | `pedidos pe JOIN clientes cl ON cl.id = pe.cliente_id` | idem |
| Filtro WHERE | `pe.eliminado=FALSE AND pe.deleted_at IS NULL AND cl.eliminado=FALSE AND cl.deleted_at IS NULL` | idem |
| Seguridad `contrasenia` | ✅ excluida con comentario | ✅ excluida con comentario |
| Seguridad `rol` | ✅ excluida | ✅ excluida |

**Diferencias detectadas:**
- Opencode expone 10 columnas (incluye `cliente_id`); propio expone 9 (sin id de cliente).
- Aliases descriptivos en opencode (`cliente_nombre`, `cliente_apellido`…) vs. simples en propio (`nombre`, `apellido`…).
- Lógica de filtro, JOIN y exclusión de `contrasenia` son idénticos.

### Consulta de equivalencia (columnas comunes)

```sql
-- Filas en opencode que NO están en propio (columnas comunes)
SELECT pedido_id, fecha, estado, total, forma_pago,
       cliente_nombre, cliente_apellido, cliente_mail, cliente_celular
FROM v_pedidos_con_cliente
EXCEPT
SELECT id, fecha, estado, total, forma_pago,
       nombre, apellido, mail, celular
FROM v_pedidos_clientes;

-- Filas en propio que NO están en opencode (columnas comunes)
SELECT id, fecha, estado, total, forma_pago,
       nombre, apellido, mail, celular
FROM v_pedidos_clientes
EXCEPT
SELECT pedido_id, fecha, estado, total, forma_pago,
       cliente_nombre, cliente_apellido, cliente_mail, cliente_celular
FROM v_pedidos_con_cliente;
```

**Resultado esperado:** 0 filas en ambas consultas.

**Conteo:**

```sql
SELECT
    (SELECT COUNT(*) FROM v_pedidos_con_cliente) AS total_opencode,
    (SELECT COUNT(*) FROM v_pedidos_clientes)    AS total_propio;
```

**Resultado esperado:** ambos conteos iguales.

### Veredicto — Vista 2

| Criterio | Estado |
|---|---|
| Filtros WHERE idénticos | ✅ |
| JOIN idéntico | ✅ |
| `contrasenia` excluida | ✅ en ambas versiones |
| `rol` excluido | ✅ en ambas versiones |
| Conjunto de filas equivalente | ✅ (verificar con queries arriba) |
| Columnas expuestas idénticas | ⚠️ Difieren en cantidad y aliases — normal dado que los prompts pedían columnas distintas |

**Vista válida** una vez ejecutadas las consultas de equivalencia sin diferencias de filas.

---

## Vista 3 — Detalle de pedido con producto

### Versiones en cada archivo

| Aspecto | prompt_opencode | prompt_propio |
|---|---|---|
| Nombre de vista | `v_detalle_pedido_con_producto` | `v_detalle_pedido` |
| Columnas expuestas | `pedido_id, detalle_id, producto_id, producto_nombre, cantidad, precio_unitario, subtotal` | `pedido_id, producto_id, producto, cantidad, precio_unitario, subtotal` |
| Columnas de más | `dp.id` (como `detalle_id`) | — |
| Columnas de menos | — | no expone `dp.id` |
| JOIN | `detalle_pedido dp JOIN productos pr ON pr.id = dp.producto_id` | idem |
| Filtro WHERE | `pr.eliminado=FALSE AND pr.deleted_at IS NULL` | idem |
| Comentario histórico | ✅ indica cómo ver histórico completo | ✅ ídem |

**Diferencias detectadas:**
- Opencode expone 7 columnas (incluye `detalle_id = dp.id`); propio expone 6.
- Alias del nombre del producto: `producto_nombre` vs. `producto`.
- JOIN, filtros y política de histórico son idénticos.

### Consulta de equivalencia (columnas comunes)

```sql
-- Filas en opencode que NO están en propio (columnas comunes)
SELECT pedido_id, producto_id, producto_nombre, cantidad, precio_unitario, subtotal
FROM v_detalle_pedido_con_producto
EXCEPT
SELECT pedido_id, producto_id, producto, cantidad, precio_unitario, subtotal
FROM v_detalle_pedido;

-- Filas en propio que NO están en opencode (columnas comunes)
SELECT pedido_id, producto_id, producto, cantidad, precio_unitario, subtotal
FROM v_detalle_pedido
EXCEPT
SELECT pedido_id, producto_id, producto_nombre, cantidad, precio_unitario, subtotal
FROM v_detalle_pedido_con_producto;
```

**Resultado esperado:** 0 filas en ambas consultas.

**Conteo:**

```sql
SELECT
    (SELECT COUNT(*) FROM v_detalle_pedido_con_producto) AS total_opencode,
    (SELECT COUNT(*) FROM v_detalle_pedido)              AS total_propio;
```

**Resultado esperado:** ambos conteos iguales.

### Veredicto — Vista 3

| Criterio | Estado |
|---|---|
| Filtros WHERE idénticos | ✅ |
| JOIN idéntico | ✅ |
| Manejo de histórico documentado | ✅ en ambas versiones |
| Conjunto de filas equivalente | ✅ (verificar con queries arriba) |
| Columnas expuestas idénticas | ⚠️ Difieren en cantidad y aliases — normal dado que los prompts pedían columnas distintas |

**Vista válida** una vez ejecutadas las consultas de equivalencia sin diferencias de filas.

---

## Resumen general

| Vista | Filtros WHERE | JOIN | Seguridad | Filas equivalentes | Válida |
|---|---|---|---|---|---|
| Productos vigentes + categoría | ✅ idénticos | ✅ | ✅ | Pendiente ejecución | ✅* |
| Pedidos + cliente | ✅ idénticos | ✅ | ✅ `contrasenia` excluida | Pendiente ejecución | ✅* |
| Detalle pedido + producto | ✅ idénticos | ✅ | ✅ | Pendiente ejecución | ✅* |

*✅ condicionado a que las consultas `EXCEPT` devuelvan 0 filas al ejecutarse contra la base de datos real.

### Diferencias sistemáticas entre versiones (no son errores)

Todas las diferencias entre `prompt_opencode` y `prompt_propio` son **diferencias de especificación**, no de lógica:

- **Nombres de vista:** opencode usa nombres más descriptivos; propio usa nombres más cortos.
- **Aliases de columnas:** opencode prefija con el nombre de la entidad (`cliente_nombre`, `producto_id`…); propio usa el nombre de columna directo.
- **Columnas adicionales en opencode:** `disponible`, `categoria_id`, `cliente_id`, `detalle_id` — el prompt opencode pedía más columnas que el prompt propio.

Ninguna diferencia afecta la corrección lógica ni la política de seguridad de las vistas.

---

## Criterio de seguridad teórico: vista sin columna contraseña

### Verificación del requisito

**El requisito ya está cumplido.** La Vista 2 en ambas versiones implementa exactamente el patrón de seguridad visto en la teoría: exponer los datos del usuario a través de una vista que omite deliberadamente la columna `contrasenia`, de modo que se puede otorgar `SELECT` sobre la vista sin dar acceso directo a la tabla base `clientes`.

### Vista que lo implementa

| Versión | Nombre de vista | Tabla base |
|---|---|---|
| prompt_opencode | `v_pedidos_con_cliente` | `clientes` |
| prompt_propio | `v_pedidos_clientes` | `clientes` |

### Columnas de `clientes` expuestas vs. ocultadas

| Columna | Expuesta en la vista | Motivo |
|---|---|---|
| `id` | ✅ (solo en opencode) | Identificador no sensible |
| `nombre` | ✅ | Dato de contacto |
| `apellido` | ✅ | Dato de contacto |
| `mail` | ✅ | Dato de contacto |
| `celular` | ✅ | Dato de contacto |
| `contrasenia` | ❌ **EXCLUIDA** | Dato sensible — nunca debe exponerse |
| `rol` | ❌ excluida | Dato de autorización interna |
| `eliminado` | ❌ excluida | Columna interna de borrado lógico |
| `created_at` | ❌ excluida | Metadato de auditoría interno |
| `updated_at` | ❌ excluida | Metadato de auditoría interno |
| `deleted_at` | ❌ excluida | Metadato de auditoría interno |

### Cómo se aplica el patrón en la práctica

El patrón consiste en tres pasos:

**1. Crear la vista sin la columna sensible:**

```sql
-- La vista expone clientes SIN contrasenia
CREATE OR REPLACE VIEW v_pedidos_con_cliente AS
SELECT
    pe.id          AS pedido_id,
    -- ... columnas del pedido ...
    cl.nombre      AS cliente_nombre,
    cl.apellido    AS cliente_apellido,
    cl.mail        AS cliente_mail,
    cl.celular     AS cliente_celular
    -- cl.contrasenia se omite deliberadamente
FROM pedidos pe
JOIN clientes cl ON cl.id = pe.cliente_id
WHERE pe.eliminado = FALSE AND pe.deleted_at IS NULL
  AND cl.eliminado = FALSE AND cl.deleted_at IS NULL;
```

**2. Revocar el acceso directo a la tabla base para el rol de reporte:**

```sql
-- El rol de reporte NO tiene acceso directo a clientes
REVOKE SELECT ON clientes FROM rol_reportes;
REVOKE SELECT ON pedidos  FROM rol_reportes;
```

**3. Otorgar acceso únicamente sobre la vista:**

```sql
-- Solo puede ver la vista, nunca la tabla base
GRANT SELECT ON v_pedidos_con_cliente TO rol_reportes;
-- Para la versión prompt_propio:
GRANT SELECT ON v_pedidos_clientes TO rol_reportes;
```

Con esta configuración, `rol_reportes` puede consultar nombre, apellido, mail y celular del cliente a través de la vista, pero **nunca puede acceder a `contrasenia`**, ni siquiera con un `SELECT * FROM clientes`.

### Verificación de que la columna no está expuesta

Ejecutar contra la base de datos — ambas consultas deben fallar con "column does not exist":

```sql
-- Debe fallar: contrasenia no existe en la vista opencode
SELECT contrasenia FROM v_pedidos_con_cliente LIMIT 1;

-- Debe fallar: contrasenia no existe en la vista propio
SELECT contrasenia FROM v_pedidos_clientes LIMIT 1;
```

Verificación alternativa con `information_schema`:

```sql
-- Debe devolver 0 filas para ambas vistas
SELECT table_name, column_name
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name   IN ('v_pedidos_con_cliente', 'v_pedidos_clientes')
  AND column_name  = 'contrasenia';
```

**Resultado esperado:** 0 filas — confirma que `contrasenia` no está expuesta en ninguna vista.

---

## Instrucciones para el estudiante

1. Crear las vistas ejecutando ambos archivos `.sql` en psql o pgAdmin contra la base `foodstore`.
2. Ejecutar cada par de consultas `EXCEPT` de este informe y registrar el resultado (número de filas).
3. Ejecutar cada consulta de conteo y registrar los valores.
4. Completar la columna "Filas equivalentes" de la tabla resumen con el resultado real.
5. Si todas las consultas `EXCEPT` devuelven 0 filas y los conteos coinciden, las vistas quedan validadas.
6. Ejecutar la consulta `information_schema` de la sección de seguridad y confirmar que devuelve 0 filas.
