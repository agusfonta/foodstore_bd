# 03 — Normalización hasta 3FN / BCNF

> **TPI «Food Store» — Primera entrega parcial · Objetivo 3 de la consigna:**
> *Normalización hasta 3FN/BCNF, con la justificación de las dependencias funcionales correspondientes.*
> Parte de: [`02_modelo_relacional.md`](02_modelo_relacional.md) · Implementación: [`db/01_ddl_schema.sql`](../db/01_ddl_schema.sql)

Notación: `X → Y` = «X determina funcionalmente a Y». `{ … }` = grupo repetitivo. Las columnas de auditoría y borrado lógico se tratan en la sección 6.

## 1. Punto de partida: relación sin normalizar (UNF)

Sin pensar en el diseño, la información de un pedido se podría registrar en una única «planilla»:

```
PEDIDO_PLANO ( pedido_id, fecha, estado, forma_pago, total,
               cliente_id, cliente_nombre, cliente_apellido, cliente_mail, cliente_celular,
               { producto_id, producto_nombre, precio_vigente,
                 categoria_id, categoria_nombre, cantidad, precio_unitario, subtotal } )
```

Dependencias funcionales (DF) del dominio, tomadas de las reglas de negocio:

| # | DF | Justificación |
| :-: | :--- | :--- |
| DF1 | `pedido_id → fecha, estado, forma_pago, total, cliente_id` | Un pedido tiene una única fecha, estado, forma de pago y un único cliente |
| DF2 | `cliente_id → nombre, apellido, mail, celular, rol` | Los datos personales dependen del cliente, no del pedido |
| DF3 | `mail → cliente_id` (y por tanto → todo el cliente) | El mail es único por cliente (`UNIQUE`) |
| DF4 | `producto_id → nombre, precio_vigente, stock, disponible, categoria_id` | Un producto tiene un único nombre, precio vigente, etc. |
| DF5 | `nombre_producto → producto_id` | El nombre de producto es único (`UNIQUE`) |
| DF6 | `categoria_id → categoria_nombre, descripcion` y `categoria_nombre → categoria_id` | El nombre de categoría es único (`UNIQUE`) |
| DF7 | `(pedido_id, producto_id) → cantidad, precio_unitario, subtotal` | Para cada producto de cada pedido hay una cantidad y un precio **de esa venta** |
| DF8 | `(cantidad, precio_unitario) → subtotal` | Atributo derivado (ver sección 5) |
| DF9 | `pedido_id → total = Σ subtotal` | Atributo derivado entre relaciones (ver sección 5) |

## 2. Primera forma normal (1FN)

**Problema:** `PEDIDO_PLANO` tiene un **grupo repetitivo** (los productos del pedido), es decir, atributos no atómicos/multivaluados.
**Solución:** una fila por producto de cada pedido; la clave pasa a ser `(pedido_id, producto_id)`.

```
PEDIDO_1FN ( pedido_id, producto_id, cantidad, precio_unitario, subtotal,
             fecha, estado, forma_pago, total,
             cliente_id, cliente_nombre, cliente_apellido, cliente_mail, cliente_celular,
             producto_nombre, precio_vigente, categoria_id, categoria_nombre )
             PK (pedido_id, producto_id)
```

Todos los atributos son atómicos (precios, fechas, textos simples; el estado y la forma de pago son valores `ENUM`, no listas).

## 3. Segunda forma normal (2FN)

**Problema:** hay **dependencias parciales** — atributos que dependen de una *parte* de la clave compuesta:

* de `pedido_id` solamente (DF1): `fecha, estado, forma_pago, total, cliente_*`
* de `producto_id` solamente (DF4): `producto_nombre, precio_vigente, categoria_*`

Esto produce redundancia (los datos del pedido se repiten en cada renglón) y anomalías de actualización (cambiar el estado de un pedido exigiría tocar N filas).

**Solución:** descomponer sin pérdida de información:

```
PEDIDO_2FN   ( pedido_id PK, fecha, estado, forma_pago, total,
               cliente_id, cliente_nombre, cliente_apellido, cliente_mail, cliente_celular )
PRODUCTO_2FN ( producto_id PK, producto_nombre, precio_vigente, stock, disponible,
               categoria_id, categoria_nombre )
DETALLE      ( pedido_id, producto_id, cantidad, precio_unitario, subtotal )
               PK (pedido_id, producto_id)
```

En `DETALLE`, cada atributo no clave depende de la clave **completa** (DF7): no quedan dependencias parciales.

> **¿`precio_unitario` es una dependencia parcial de `producto_id`?** No. Si dependiera solo de `producto_id` sería igual a `precio_vigente` y estaría repetido. Pero es el precio **al momento de esa venta**: cambia el precio del producto mañana y los pedidos viejos conservan el suyo. Depende de la venta `(pedido_id, producto_id)`, por eso está correctamente en `DETALLE`.

## 4. Tercera forma normal (3FN) y BCNF

**Problema:** quedan **dependencias transitivas** (un atributo no clave determina a otros no clave):

* En `PEDIDO_2FN`: `pedido_id → cliente_id → cliente_nombre, apellido, mail, celular` (DF1 + DF2).
* En `PRODUCTO_2FN`: `producto_id → categoria_id → categoria_nombre, descripcion` (DF4 + DF6).

**Solución:** extraer `CLIENTE` y `CATEGORIA`, dejando solo la FK en la tabla que los referencia. El resultado son las 5 relaciones del modelo implementado:

| Relación final | Determinantes (lado izquierdo de cada DF) | ¿Son superclaves? | ¿BCNF? |
| :--- | :--- | :---: | :---: |
| `categorias` | `id` · `nombre` (UK) | Sí · Sí | **Sí** |
| `productos` | `id` · `nombre` (UK) | Sí · Sí | **Sí** |
| `clientes` | `id` · `mail` (UK) | Sí · Sí | **Sí** |
| `pedidos` | `id` | Sí | **Sí** (ver nota de `total`) |
| `detalle_pedido` | `id` · `(pedido_id, producto_id)` (UK) | Sí · Sí | **Sí** (ver nota de `subtotal`) |

**Criterio BCNF:** para toda DF no trivial `X → Y` de la relación, `X` debe ser superclave. Verificado fila por fila en la tabla de arriba: el único determinante de cada relación son sus claves (PK o UNIQUE). Las FK (`categoria_id`, `cliente_id`, `pedido_id`, `producto_id`) **no determinan** otros atributos dentro de su tabla (por ejemplo `productos.categoria_id` no determina `nombre` ni `precio`), de modo que no introducen dependencias transitivas.

**Resultado: el esquema está en 3FN y en BCNF**, con las dos desnormalizaciones controladas de la sección 5.

## 5. Atributos derivados: desnormalización deliberada y controlada

Dos atributos son **calculables** a partir de otros; estrictamente, mantenerlos rompe 3FN/BCNF (DF8, DF9). Se conservan **a propósito** y con una defensa explícita contra la inconsistencia:

| Atributo | Dependencia | Por qué se guarda | Cómo se protege |
| :--- | :--- | :--- | :--- |
| `detalle_pedido.subtotal` | `subtotal = cantidad × precio_unitario` (DF8; dentro de la misma fila) | Evita multiplicar en cada reporte y permite índices *covering* (`INCLUDE (cantidad, subtotal)`) y la vista materializada de facturación | `CHECK chk_detalle_subtotal_coherente (subtotal = cantidad * precio_unitario)` — la base **rechaza** una fila incoherente |
| `pedidos.total` | `total = Σ subtotal` de sus renglones (DF9; entre tablas) | Los reportes de cobranza y ranking de clientes (`SUM(total)`) no necesitan unir con `detalle_pedido` | El único camino de alta/actualización previsto es `sp_crear_pedido` ([`08_funciones_procedimientos_plpgsql.sql`](../db/08_funciones_procedimientos_plpgsql.sql)), que calcula `total` en la misma transacción que inserta los renglones. Auditable con `fn_total_pedido()` |

Consulta de auditoría de coherencia de `total` (debe devolver 0 filas):

```sql
SELECT p.id, p.total, fn_total_pedido(p.id) AS suma_renglones
FROM pedidos p
WHERE p.total <> fn_total_pedido(p.id)
  AND p.eliminado = FALSE;
```

> **Costo asumido:** `pedidos.total` no está protegido por una restricción declarativa (un `CHECK` no puede mirar otra tabla); depende de que los cambios pasen por el procedimiento. Si se quisiera blindar, la alternativa sería un trigger sobre `detalle_pedido` que recalcule el total. Si el curso exigiera 3FN estricta, bastaría con eliminar ambas columnas y reemplazarlas por vistas que calculen `cantidad × precio_unitario` y `SUM(...)`; se perderían los índices *covering* sobre esas columnas y el `SUM(total)` directo sobre `pedidos` que usan los reportes (ver [`Informes_tps/Informe_optimizacion_consultas_indices.md`](../Informes_tps/Informe_optimizacion_consultas_indices.md)).

## 6. Otras observaciones sobre dependencias

| Atributo(s) | Observación |
| :--- | :--- |
| `eliminado` / `deleted_at` | `deleted_at IS NOT NULL ⇔ eliminado = TRUE` es una redundancia intencional del **borrado lógico**: la bandera booleana permite índices parciales simples (`WHERE eliminado = FALSE`) y `deleted_at` registra **cuándo**. Los procedimientos `sp_baja_logica_*` escriben ambas a la vez. Ver [`db/10_borrado_logico.sql`](../db/10_borrado_logico.sql) |
| `clientes.rol` | Texto libre sin dependencias propias (`rol` no determina ningún otro atributo), por lo que no requiere tabla aparte. Si los roles tuvieran atributos (permisos, descripción) habría que extraer una relación `roles` para mantener 3FN |
| `pedidos.estado`, `pedidos.forma_pago` | Dominios cerrados modelados como `ENUM`, no como columnas libres: no hay redundancia ni anomalías de escritura |
| `productos.precio` vs. `detalle_pedido.precio_unitario` | Atributos distintos: precio **vigente** vs. precio **histórico de la venta** (ver sección 3). No es redundancia |

## 7. Anomalías que la normalización evita (resumen)

| Anomalía en `PEDIDO_PLANO` | Cómo la evita el esquema final |
| :--- | :--- |
| **Actualización**: cambiar el mail de un cliente obliga a modificar todas sus filas | El mail vive en una sola fila de `clientes` |
| **Inserción**: no se puede dar de alta un producto sin venderlo (faltaría `pedido_id`) | `productos` es independiente de `pedidos` |
| **Borrado**: al borrar el único pedido de un producto se pierde el producto/categoría | Los datos de producto y categoría persisten; además `ON DELETE RESTRICT` y borrado lógico protegen el historial |
