# Informe de Optimización de Consultas SQL e Índices

> Marcado con **[COMPLETAR]**: mediciones nuevas que hay que correr con `db/tp5_mediciones_pendientes.sql` y pegar acá.

## Criterio de medición

* Todas las mediciones se hacen con `EXPLAIN ANALYZE` sobre la copia de trabajo de foodstore.
* Se compara **Execution Time** (tiempo real). El `cost` es una estimación del planner y no se usa para decidir.
* **Efecto caché:** la primera ejecución de una consulta suele ser más lenta porque las páginas todavía no están en memoria (`shared_buffers`). Por eso cada consulta se ejecuta **3 veces** y se informa la **mediana**, tanto antes como después del cambio.
* Mejora (x) = tiempo antes ÷ tiempo después.

---

## Consulta Nº 1: Ranking de Ventas por Producto

### Consulta
```sql
EXPLAIN ANALYZE
SELECT pr.id, pr.nombre,
     SUM(dp.cantidad) AS unidades_vendidas,
     SUM(dp.subtotal) AS total_vendido
FROM detalle_pedido dp
JOIN pedidos p    ON p.id = dp.pedido_id
JOIN productos pr ON pr.id = dp.producto_id
WHERE p.estado IN ('CONFIRMADO', 'TERMINADO')
 AND p.eliminado = FALSE
 AND pr.eliminado = FALSE
GROUP BY pr.id, pr.nombre
ORDER BY total_vendido DESC;
```

### ANÁLISIS SIN ÍNDICES

![alt text](image.png)

> Nodos principales: `Parallel Seq Scan on detalle_pedido` (~200.000 filas por proceso, 3 procesos), `Parallel Seq Scan on pedidos` (Rows Removed by Filter: 33.333 por proceso), `Seq Scan on productos` (50.000 filas).
> Joins: `Parallel Hash Join` (detalle_pedido ↔ pedidos) y `Hash Join` (↔ productos).
> Cuello de botella: el `Sort` previo al `GroupAggregate` usa **external merge en disco** (~4,3–4,6 MB por proceso) porque no entra en `work_mem`.
> Planning Time: 19.129 ms — Execution Time: 773.753 ms

### PROPUESTAS DE LA IA: CREACIÓN DE ÍNDICES

1. **Índice parcial sobre `pedidos`:**
   * **Columnas:** `(estado, eliminado)`, con la condición parcial que replica el `WHERE`.

   ```sql
   CREATE INDEX idx_pedidos_volumen_venta
   ON pedidos (estado, eliminado)
   WHERE estado IN ('CONFIRMADO', 'TERMINADO')
     AND eliminado = FALSE;
   ```

2. **Índice covering sobre `detalle_pedido`:**
   * `pedido_id` (clave del JOIN), `producto_id` (agrupación), `INCLUDE (cantidad, subtotal)` (datos de la agregación).

   ```sql
   CREATE INDEX idx_detalle_pedido_agg_ventas
   ON detalle_pedido (pedido_id, producto_id)
   INCLUDE (cantidad, subtotal);
   ```

### ANÁLISIS CON ÍNDICES

![alt text](image-1.png)

> **El plan es el mismo que sin índices.** `pedidos` se sigue leyendo con `Parallel Seq Scan` (línea 23 del plan) y `detalle_pedido` también (línea 20). **Ninguno de los dos índices aparece en el plan.**
> Planning Time: 0.425 ms — Execution Time: 381.783 ms

**Interpretación:** la diferencia de tiempo (773.753 → 381.783 ms) **no se debe a los índices**: el plan no cambió. Se ve en los nodos: el `Parallel Seq Scan on pedidos` pasó de 195 ms a 19 ms y el de `detalle_pedido` de 240 ms a 26 ms, **con el mismo tipo de acceso**. Eso es efecto caché: en la segunda medición las páginas ya estaban en memoria.

**¿Por qué el optimizador no usa los índices?**
* `idx_pedidos_volumen_venta`: la consulta necesita **la mitad** de la tabla `pedidos` (33.333 de 66.666 filas por proceso). Con esa selectividad, leer la tabla completa en forma secuencial es más barato que ir y venir entre índice y tabla.
* `idx_detalle_pedido_agg_ventas`: la consulta **no filtra** `detalle_pedido`, necesita todas sus filas para el Hash Join. Un índice no evita leerlas.

**Medición de control** (mediana de 3 ejecuciones, sin índices y con índices):

| Escenario | Execution Time (mediana) | Acceso a `pedidos` |
| :--- | :--- | :--- |
| Sin índices | **[COMPLETAR] ms** | Parallel Seq Scan |
| Con índices | **[COMPLETAR] ms** | **[COMPLETAR]** |

### DECISIÓN SOBRE LAS PROPUESTAS

* **`idx_pedidos_volumen_venta`: DESCARTADO.** El planner no lo usa (Parallel Seq Scan en el plan) y su condición no deja afuera lo suficiente para que convenga.
* **`idx_detalle_pedido_agg_ventas`: DESCARTADO.** El planner no lo usa y agrega costo en cada `INSERT` sobre `detalle_pedido` (ver la sección de impacto en la inserción).
* **Índices individuales sobre `pedidos(estado)` o `pedidos(eliminado)`: DESCARTADOS** antes de aplicarlos, por el mismo motivo: baja selectividad. `estado` tiene pocos valores distintos y `eliminado` es booleano.

**Conclusión de la consulta 1:** no se cumple el criterio de la spec ("cambiar el plan de acceso de Seq Scan a Index Scan o Bitmap Heap Scan"). Para esta consulta, con este volumen, **un índice no es la herramienta adecuada**: el trabajo real es juntar y agregar casi toda la tabla `detalle_pedido`, y el costo extra viene del `Sort` que se hace en disco. Se documenta como propuesta de la IA que no funcionó, como pide el criterio de aceptación de la cátedra.

---

## Consulta Nº 2: Resumen de Cobranzas y Estados de Pedidos

### Consulta

```sql
SELECT forma_pago, estado, COUNT(*) AS cantidad_pedidos, SUM(total) AS monto
FROM pedidos
WHERE eliminado = FALSE
GROUP BY forma_pago, estado
ORDER BY monto DESC;
```

### ANÁLISIS SIN ÍNDICES
![alt text](image-2.png)

> Nodo principal: `Parallel Seq Scan on pedidos` (Filter: NOT eliminado) → `Partial HashAggregate` → `Sort` por (forma_pago, estado) en cada proceso → `Gather Merge` → `Finalize GroupAggregate` → `Sort` final por monto.
> Planning Time: 0.120 ms — Execution Time: 41.055 ms

### PROPUESTAS DE LA IA: CREACIÓN DE ÍNDICES

> **Objetivo:** reemplazar el `Parallel Seq Scan` por un `Index Only Scan` que entregue las filas ya ordenadas por (forma_pago, estado).

* **Columnas:** `(forma_pago, estado)` en el mismo orden del `GROUP BY`, para que la agregación reciba las filas ya agrupadas.
* **`INCLUDE (total)`:** la suma se calcula directamente desde el índice, sin ir a la tabla.
* **Índice parcial:** `WHERE eliminado = FALSE`, igual que el filtro de la consulta.

```sql
CREATE INDEX idx_pedidos_cobranza
ON pedidos (forma_pago, estado)
INCLUDE (total)
WHERE eliminado = FALSE;
```

### ANÁLISIS CON ÍNDICES
![alt text](image-3.png)

> Nodo principal: `Parallel Index Only Scan using idx_pedidos_cobranza` con **Heap Fetches: 0** (no se accede a la tabla).
> Desaparecen el `Parallel Seq Scan` y el `Sort` intermedio de cada proceso: el índice ya entrega las filas en el orden del `GROUP BY`, por eso el agregado pasa a ser `Partial GroupAggregate`.
> Planning Time: 0.107 ms — Execution Time: 32.989 ms

**Mejora:** 41.055 ms → 32.989 ms = **1,24x** (≈20 % menos). Es una mejora real pero moderada: la consulta igual necesita recorrer todos los pedidos no eliminados (~200.000). El índice evita leer la tabla y ordenar, pero no reduce la cantidad de filas a procesar.

### DESCARTE DE PROPUESTAS POR LA IA
* **Propuesta evaluada:** variante de `idx_pedidos_cobranza` con condición parcial `WHERE estado IN ('CONFIRMADO', 'TERMINADO') AND eliminado = FALSE`.
* **Justificación del descarte:** la consulta agrupa por **todos** los estados, no solo confirmados y terminados. Con esa condición el índice no contendría todas las filas que la consulta necesita y el planner **no podría usarlo** para esta consulta. Por eso se mantiene la condición `WHERE eliminado = FALSE`, que coincide exactamente con el filtro de la consulta.

---

## Consulta Nº 3: Historial de Pedidos por Cliente

### Consulta

```sql
SELECT id, fecha, estado, forma_pago, total
FROM pedidos
WHERE cliente_id = 5 AND eliminado = FALSE
ORDER BY fecha DESC;
```

### ANÁLISIS SIN ÍNDICES

![alt text](image-5.png)

> Nodo principal: `Parallel Seq Scan on pedidos` (Rows Removed by Filter: 66.663 por proceso, para encontrar 10 filas) + `Sort` por fecha DESC + `Gather Merge`.
> Planning Time: 0.082 ms — Execution Time: 19.577 ms

### PROPUESTAS DE LA IA: CREACIÓN DE ÍNDICES

> **Objetivo:** reemplazar el `Parallel Seq Scan` (~200.000 filas) por un acceso puntual a las ~10 filas del cliente y, si es posible, evitar el `Sort`.

* **`cliente_id`:** igualdad muy selectiva (de ~200.000 filas a ~10). Va primero.
* **`fecha DESC`:** mismo orden que el `ORDER BY`. Va segundo porque solo sirve para ordenar **dentro** de un mismo cliente.
* **`INCLUDE (estado, forma_pago, total)`:** columnas del SELECT, para intentar no ir a la tabla.
* **Índice parcial:** `WHERE eliminado = FALSE`, igual que el filtro de la consulta.

```sql
CREATE INDEX idx_pedidos_historial_cliente
ON pedidos (cliente_id, fecha DESC)
INCLUDE (estado, forma_pago, total)
WHERE eliminado = FALSE;
```

### ANÁLISIS CON ÍNDICES
![alt text](image-4.png)

> Nodos: `Bitmap Index Scan on idx_pedidos_historial_cliente` (Index Cond: cliente_id = 5) → `Bitmap Heap Scan on pedidos` (Heap Blocks: exact=10) → **`Sort` por fecha DESC** (quicksort, 25 kB).
> Planning Time: 0.321 ms — Execution Time: 0.110 ms

**Mejora:** 19.577 ms → 0.110 ms = **≈178x**. El `Parallel Seq Scan` desaparece: ahora se leen solo 10 bloques de la tabla.

**Lo que NO se logró (y por qué):** el objetivo era un `Index Only Scan` sin `Sort`, pero el plan muestra `Bitmap Heap Scan` **y el `Sort` sigue estando**. El motivo es que la consulta pide la columna **`id`**, que **no está en el índice**: PostgreSQL tiene que ir a la tabla a buscarla, así que no puede hacer un Index Only Scan. Con tan pocas filas (10), el planner prefiere un Bitmap Heap Scan y ordenar esas 10 filas en memoria, que cuesta casi nada.

### VARIANTE PROBADA: índice covering completo

Se agrega `id` al `INCLUDE` para que todas las columnas del SELECT estén en el índice:

```sql
DROP INDEX idx_pedidos_historial_cliente;
CREATE INDEX idx_pedidos_historial_cliente
ON pedidos (cliente_id, fecha DESC)
INCLUDE (id, estado, forma_pago, total)
WHERE eliminado = FALSE;
VACUUM ANALYZE pedidos;  -- actualiza el visibility map, necesario para Index Only Scan
```

> Plan esperado: `Index Only Scan using idx_pedidos_historial_cliente` — Heap Fetches: 0 — sin `Sort`.
> Plan obtenido: **[COMPLETAR con captura]** — Execution Time (mediana): **[COMPLETAR] ms**

**Decisión:** **[COMPLETAR]**. Si la variante mejora el tiempo, se acepta. Si la diferencia es mínima (ya estamos en décimas de milisegundo), se puede quedar la versión original y documentar que el `Sort` de 10 filas no justifica un índice más grande.

### DESCARTE DE PROPUESTAS POR LA IA

* **Propuesta evaluada:** crear un índice B-Tree simple sobre `pedidos(cliente_id)`.
* **Justificación del descarte:** redundancia de prefijo. `idx_pedidos_historial_cliente` ya tiene `cliente_id` como primera columna y PostgreSQL puede usarlo para cualquier búsqueda solo por `cliente_id`. Un índice extra solo sumaría costo de mantenimiento en cada `INSERT`/`UPDATE` sobre `pedidos`.

---

## RESUMEN DE RESULTADOS

| Consulta | Cambio | Plan antes | Plan después | Antes (ms) | Después (ms) | Mejora (x) | Decisión |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 1. Ranking de ventas | 2 índices (pedidos, detalle_pedido) | Parallel Seq Scan + Hash Join + Sort en disco | **Igual** (índices no usados) | 773.753 | 381.783 (efecto caché) | No atribuible al índice | Descartados |
| 2. Cobranza | `idx_pedidos_cobranza` | Parallel Seq Scan + HashAggregate + Sort | Parallel Index Only Scan + GroupAggregate | 41.055 | 32.989 | 1,24x | Aceptado |
| 3. Historial cliente | `idx_pedidos_historial_cliente` | Parallel Seq Scan + Sort | Bitmap Heap Scan + Sort | 19.577 | 0.110 | ≈178x | Aceptado |

---

## IMPACTO EN LA INSERCIÓN DE NUEVOS REGISTROS

Prueba: insertar un lote en `detalle_pedido`, sin y con `idx_detalle_pedido_agg_ventas`, dentro de una transacción con `ROLLBACK` para no dejar datos de prueba.

> **Nota:** la línea `\timing on sobre el INSERT` de las capturas no es SQL válido. `\timing` es un comando de **psql** y no funciona en DBeaver. El tiempo que se tomó es el que informa DBeaver ("500 rows affected in … ms").
> **Antes de medir, revisar qué índices tiene `detalle_pedido`** (`SELECT indexname FROM pg_indexes WHERE tablename = 'detalle_pedido';`). Si quedaron índices de trabajos anteriores (por ejemplo, `idx_detalle_pedido_pedido_eliminado`), el escenario "sin índice" no es realmente sin índices.

### 1. Inserción **SIN** el índice idx_detalle_pedido_agg_ventas
 ![alt text](image-6.png)

> 500 filas — 16 ms (una sola ejecución)

### 2. Inserción **CON** el índice idx_detalle_pedido_agg_ventas

 ![alt text](image-7.png)

> 500 filas — 15 ms (una sola ejecución)

### Medición repetida (lote más grande)

Con 500 filas y una sola ejecución, 16 ms contra 15 ms está dentro del ruido de la medición: **la prueba no alcanza para concluir nada**. Incluso "con índice" dio más rápido, cosa que no tiene sentido físico. Se repite con un lote de **50.000 filas** y **5 ejecuciones** por escenario (script `db/tp5_mediciones_pendientes.sql`, bloque 3):

| Escenario | Filas | Tiempo (mediana de 5) |
| :--- | :--- | :--- |
| **SIN** `idx_detalle_pedido_agg_ventas` | 50.000 | **[COMPLETAR] ms** |
| **CON** `idx_detalle_pedido_agg_ventas` | 50.000 | **[COMPLETAR] ms** |
| **Costo del índice** | | **[COMPLETAR] ms (≈ [COMPLETAR] %)** |

### CONCLUSIÓN

Los índices aceleran las lecturas, pero cada `INSERT` tiene que actualizar **la tabla y todos sus índices**. Por eso cada índice tiene un costo de escritura.

1. **Con lotes chicos el costo no se ve:** insertar 500 entradas en un B-Tree (O(log n) por inserción) modifica muy pocas páginas. La diferencia (~1 ms) queda por debajo de la variación normal entre ejecuciones.
2. **Con un lote más grande el costo aparece:** **[COMPLETAR con el resultado de la medición de 50.000 filas]**.
3. **Conclusión práctica:** `idx_detalle_pedido_agg_ventas` **no es usado por la consulta 1** (ver su análisis). Mantenerlo significa pagar ese costo en cada venta registrada sin ningún beneficio en lectura. Por eso se decide **eliminarlo**:

```sql
DROP INDEX IF EXISTS idx_detalle_pedido_agg_ventas;
DROP INDEX IF EXISTS idx_pedidos_volumen_venta;
```
