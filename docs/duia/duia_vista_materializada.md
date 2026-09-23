# DUIA – Vista Materializada: Facturación por Categoría y Mes

## Declaración de Uso de Inteligencia Artificial

| Campo | Completar |
| :--- | :--- |
| **Herramienta** | Kiro (Claude – Anthropic) |
| **Spec o prompt utilizado** | "Elegir un reporte agregado costoso del sistema (por ejemplo, facturación por categoría y mes, u otro que el estudiante identifique a partir de las consultas analíticas de la Semana 4) y crear la vista materializada correspondiente, con WITH DATA y un índice único que permita, a futuro, un REFRESH CONCURRENTLY." |
| **Qué generó** | Archivo `db/vista_materializada.sql` con: (1) `CREATE MATERIALIZED VIEW mv_facturacion_categoria_mes … WITH DATA`, (2) `CREATE UNIQUE INDEX uix_mv_facturacion_categoria_mes ON … (categoria_id, mes)`, (3) índice secundario por mes, (4) comentarios explicativos de cada paso y comandos de rollback/refresh. |
| **Qué se aceptó** | La estructura completa del script tal como fue generada: nombre de la vista, columnas agregadas (`total_facturado`, `cantidad_pedidos`, `cantidad_productos_distintos`), filtros de estado y borrado lógico, y ambos índices. |
| **Qué se modificó o descartó, y por qué** | — (ninguna modificación manual; la consulta base es idéntica a la ya validada en `indexes_optimizacion.sql`) |
| **Verificación realizada** | Ver sección abajo |

---

## Spec del Reporte

**Nombre de la vista:** `mv_facturacion_categoria_mes`

**Justificación del costo:** la consulta base requiere un JOIN de cuatro tablas
(`detalle_pedido → pedidos → productos → categorias`), aplica filtros de estado y borrado
lógico, trunca la fecha con `DATE_TRUNC('month', ...)` y calcula agregados (`SUM`, `COUNT DISTINCT`)
sobre potencialmente millones de filas. Sin materializar, cada acceso desde un dashboard
o informe repite todo ese trabajo.

**Columnas de salida:**

| Columna | Tipo | Descripción |
| :--- | :--- | :--- |
| `categoria_id` | BIGINT | PK de la categoría |
| `categoria` | VARCHAR | Nombre de la categoría |
| `mes` | TIMESTAMPTZ | Primer día del mes (resultado de `DATE_TRUNC`) |
| `total_facturado` | NUMERIC | Suma de subtotales de todos los ítems del mes |
| `cantidad_pedidos` | BIGINT | Pedidos distintos en ese mes y categoría |
| `cantidad_productos_distintos` | BIGINT | Productos distintos vendidos en ese mes y categoría |

**Filtros aplicados:**
- `p.estado IN ('CONFIRMADO', 'TERMINADO')` — solo pedidos efectivos
- `p.eliminado = FALSE` — borrado lógico en pedidos
- `pr.eliminado = FALSE` — borrado lógico en productos
- `c.eliminado = FALSE` — borrado lógico en categorías

**Clave única para `REFRESH CONCURRENTLY`:**  
`(categoria_id, mes)` — identifica unívocamente cada fila del agregado.

---

## Verificación

Ejecutar en `foodstore_desarrollo` dentro de un bloque de transacción de inspección:

```sql
-- Paso 1: crear la vista (en la copia de desarrollo)
\i db/vista_materializada.sql

-- Paso 2: verificar filas materializadas
SELECT * FROM mv_facturacion_categoria_mes
ORDER BY mes DESC, total_facturado DESC
LIMIT 10;
-- Resultado esperado: filas con categoria, mes truncado al 1er día,
-- total_facturado > 0, cantidad_pedidos y cantidad_productos_distintos >= 1.

-- Paso 3: verificar que el índice único existe
SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = 'mv_facturacion_categoria_mes';
-- Resultado esperado: uix_mv_facturacion_categoria_mes (UNIQUE) e
-- idx_mv_facturacion_mes.

-- Paso 4: probar REFRESH CONCURRENTLY (no debe lanzar error si el índice único existe)
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_facturacion_categoria_mes;
-- Resultado esperado: "REFRESH MATERIALIZED VIEW" sin error.

-- Paso 5 (rollback si algo falla):
-- DROP MATERIALIZED VIEW IF EXISTS mv_facturacion_categoria_mes;
```

---

## Protocolo de Seguridad Aplicado

1. **Copia de trabajo:** ejecutar sobre `foodstore_desarrollo` creada con
   `createdb -T foodstore foodstore_desarrollo`.
2. **Transacción de inspección:** se recomienda correr el CREATE dentro de un
   `BEGIN; … ROLLBACK;` la primera vez para verificar que no hay errores de
   compilación antes de confirmar con `COMMIT;`.  
   *(Las vistas materializadas admiten CREATE dentro de una transacción en PostgreSQL.)*
3. **Respaldo previo:** antes del DDL, ejecutar  
   `pg_dump -U postgres -d foodstore_desarrollo -F c -b -v -f respaldo_estructura.backup`
