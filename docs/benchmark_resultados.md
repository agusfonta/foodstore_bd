# Benchmark: Consulta Original vs Vista Materializada

## Contexto

Reporte medido: **Facturación por categoría y mes** (`mv_facturacion_categoria_mes`).

La consulta original recorre cuatro tablas en tiempo real
(`detalle_pedido → pedidos → productos → categorias`), aplica filtros de estado
y borrado lógico, trunca fechas con `DATE_TRUNC` y calcula `SUM` / `COUNT DISTINCT`.
La vista materializada almacena ese resultado como un snapshot persistido en disco.

### Entorno de medición

| Parámetro | Valor |
| :--- | :--- |
| Motor | PostgreSQL 17 |
| Base de datos | `foodstore_desarrollo` |
| Sistema operativo | Windows 10/11 |
| Herramienta de medición | `EXPLAIN (ANALYZE, BUFFERS)` en psql |
| Volumen — `detalle_pedido` | **600 000 filas** |
| Volumen — `pedidos` | 200 000 filas |
| Volumen — `productos` | 50 000 filas |
| Volumen — `categorias` | 5 filas |
| Filas en la vista materializada | **65 filas** (5 categorías × 13 meses) |

---

## Resultados

### Medición 1 — Consulta ORIGINAL (sin materializar)

| Ejecución | Planning Time (ms) | Execution Time (ms) |
| :---: | ---: | ---: |
| 1 | 28.472 | 1 364.313 |
| 2 | 17.607 | 1 335.215 |
| 3 | 10.050 | 1 388.373 |
| **Mediana** | **17.607** | **1 364.313** |

**Plan de ejecución completo (última corrida con EXPLAIN ANALYZE BUFFERS):**

```
Incremental Sort  (cost=61529.96..78549.77 rows=298101 width=64)
                  (actual time=1274.707..1295.673 rows=65 loops=1)
  Sort Key: (date_trunc('month', p.fecha)) DESC, (sum(dp.subtotal)) DESC
  Presorted Key: (date_trunc('month', p.fecha))
  Full-sort Groups: 2  Sort Method: quicksort  Avg Memory: 27kB
  Buffers: shared hit=10869, temp read=1895 written=1901
  -> GroupAggregate  (cost=61529.85..70472.88 rows=298101 width=64)
                     (actual time=1097.789..1295.508 rows=65 loops=1)
       Group Key: (date_trunc('month', p.fecha)), c.nombre
       Buffers: shared hit=10863, temp read=1895 written=1901
       -> Sort  (cost=61529.85..62275.10 rows=298101 width=38)
                (actual time=1089.169..1187.081 rows=300000 loops=1)
            Sort Key: (date_trunc('month'...)) DESC, c.nombre, p.id
            Sort Method: external merge  Disk: 15160kB   ← escribe a disco
            Buffers: shared hit=10863, temp read=1895 written=1901
            -> Hash Join  (cost=10129.20..26272.86 rows=298101 width=38)
                          (actual time=86.665..508.042 rows=300000 loops=1)
                 Hash Cond: (pr.categoria_id = c.id)
                 -> Hash Join  (Hash Cond: dp.producto_id = pr.id)
                      -> Hash Join  (Hash Cond: dp.pedido_id = p.id)
                           -> Seq Scan on detalle_pedido  (600000 rows)
                           -> Seq Scan on pedidos         (100000 rows efectivos)
                      -> Seq Scan on productos            (50000 rows)
                 -> Seq Scan on categorias                (5 rows)

Planning Time: 16.072 ms
Execution Time: 1313.224 ms
```

**Costo estimado del nodo raíz:** `cost=61529.96..78549.77`

---

### Medición 2 — Vista MATERIALIZADA

| Ejecución | Planning Time (ms) | Execution Time (ms) |
| :---: | ---: | ---: |
| 1 | 2.927 | 0.164 |
| 2 | 4.436 | 0.190 |
| 3 | 3.998 | 0.332 |
| **Mediana** | **3.998** | **0.190** |

**Plan de ejecución completo:**

```
Sort  (cost=3.61..3.77 rows=65 width=40)
      (actual time=0.102..0.105 rows=65 loops=1)
  Sort Key: mes DESC, total_facturado DESC
  Sort Method: quicksort  Memory: 29kB
  Buffers: shared hit=7
  -> Seq Scan on mv_facturacion_categoria_mes
       (cost=0.00..1.65 rows=65 width=40)
       (actual time=0.020..0.028 rows=65 loops=1)
         Buffers: shared hit=1

Planning Time: 3.498 ms
Execution Time: 0.157 ms
```

**Costo estimado del nodo raíz:** `cost=3.61..3.77`

---

## Comparación y Análisis

### Tabla resumen

| Métrica | Consulta original | Vista materializada | Factor de mejora |
| :--- | ---: | ---: | ---: |
| Execution Time — mediana (ms) | **1 364.31** | **0.19** | **~7 180 ×** |
| Planning Time — mediana (ms) | 17.61 | 3.99 | ~4.4 × |
| Costo estimado planner (total) | 78 549.77 | 3.77 | **~20 834 ×** |
| Shared hit blocks | 10 869 | 7 | ~1 552 × |
| Temp disk (sort externo) | 15 160 kB | 0 kB | — |

### ¿Por qué la diferencia es tan grande?

#### Consulta original — lo que hace el motor

El plan revela cuatro etapas costosas encadenadas:

1. **Seq Scan sobre `detalle_pedido`** — lee las 600 000 filas completas.
   No hay índice que evite el scan completo porque la consulta necesita
   *todos* los ítems (sin filtro selectivo sobre `detalle_pedido` directo).

2. **Tres Hash Joins** encadenados — construye tablas de hash en memoria
   para `pedidos` (100 000 filas efectivas tras filtrar por estado),
   `productos` (50 000 filas) y `categorias` (5 filas).
   El resultado intermedio son **300 000 filas**.

3. **Sort externo con escritura a disco** — las 300 000 filas con sus claves
   de agrupación no caben en `work_mem`, por eso el motor usa un
   *external merge sort* volcando **15 160 kB a disco temporal**.
   Esta es la operación más cara del plan (~1 100 ms de los ~1 300 ms totales).

4. **GroupAggregate + Incremental Sort** — finalmente agrega los datos
   y los ordena, produciendo solo 65 filas de resultado.

#### Vista materializada — lo que hace el motor

El plan tiene dos nodos únicamente:

1. **Seq Scan sobre `mv_facturacion_categoria_mes`** — lee **65 filas**
   ya calculadas, en **1 bloque de disco** (`shared hit=1`).

2. **Sort en memoria (quicksort, 29 kB)** — ordena 65 filas trivialmente.

No hay joins, no hay agregaciones, no hay escritura a disco.
El snapshot ya existe; el motor solo lo recupera y lo ordena.

### Limitación: datos desactualizados

La vista no refleja pedidos nuevos hasta que se ejecute:

```sql
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_facturacion_categoria_mes;
```

El índice único `uix_mv_facturacion_categoria_mes (categoria_id, mes)`
permite que este refresco ocurra **sin bloquear las lecturas** en curso.
Para un reporte de facturación histórica (datos que no cambian para meses
cerrados), la vista puede refrescarse una vez al día o a la semana
sin impacto en la exactitud del reporte.

---

## DUIA de esta medición

| Campo | Detalle |
| :--- | :--- |
| **Herramienta** | Kiro (Claude – Anthropic) |
| **Prompt utilizado** | "Medir el tiempo de consultar el reporte contra la vista materializada frente al tiempo de ejecutar la consulta original sin materializar." |
| **Qué generó** | Script `db/benchmark_vista_materializada.sql` con EXPLAIN ANALYZE, DISCARD ALL entre mediciones y pasos de cold cache. Este documento con los resultados reales, planes completos y análisis. |
| **Qué se aceptó** | Estructura completa del script, ejecución automatizada de las 6 mediciones (3 por consulta) y redacción del análisis. |
| **Qué se modificó o descartó** | Ninguna modificación manual. Los valores numéricos son los obtenidos directamente de `EXPLAIN ANALYZE` contra `foodstore_desarrollo`. |
| **Verificación realizada** | 3 ejecuciones de cada consulta con `EXPLAIN (ANALYZE, BUFFERS)` sobre 600 000 filas reales. Mediana de Execution Time: 1 364 ms (original) vs 0.19 ms (vista). Factor de mejora real: ~7 180×. |
