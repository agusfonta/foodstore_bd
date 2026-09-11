
# PUNTO 2
Explica linea por linea este plan: 

WindowAgg  (cost=0.55..6204.19 rows=50000 width=52) (actual time=0.022..73.532 rows=50000 loops=1)
  ->  Merge Join  (cost=0.55..5204.19 rows=50000 width=44) (actual time=0.016..40.441 rows=50000 loops=1)
        Merge Cond: (p.categoria_id = c.id)
        ->  Index Scan using idx_productos_categoria_precio_deleted on productos p  (cost=0.41..4566.97 rows=50000 width=36) (actual time=0.007..27.125 rows=50000 loops=1)
        ->  Index Scan using categorias_pkey on categorias c  (cost=0.13..12.21 rows=5 width=16) (actual time=0.006..0.012 rows=5 loops=1)
              Filter: (deleted_at IS NULL)
Planning Time: 0.213 ms
Execution Time: 77.201 ms



# PUNTO 3 
## Prompt 1 Consulta 1

Generar una consulta para postgresql para obtener un ranking de productos dentro de cada categoría, ordenados por precio de mayor a menor. Usando la base de datos foodstore
Tablas a utilizar: 
- Productos
- Categoría
Filtro de borrado lógico:
- Se deben considerar productos cuyo deleted_at IS NULL.
- Se deben considerar categorías cuyo deleted_at IS NULL.
- Columnas de salida:
- ID del producto.
- Nombre del producto.
- Nombre de la categoría.
- Precio del producto.
- Ranking del producto dentro de su categoría.
Criterio de partición:
- El ranking debe reiniciarse para cada categoría. 
- Cada categoría tiene su propio ranking por lo que la partición se realiza por el ID de la categoría
Criterio de orden:
- Los productos deben ordenarse por precio de mayor a menor.
Desempate:
- Si dos productos tienen el mismo precio, se deben ordenar por ID de producto de menor a mayor.

## Prompt 2 Consulta 1
Teniendo en cuenta esta consulta provista anteriormente: 
SELECT
    p.id AS producto_id,
    p.nombre AS producto_nombre,
    c.nombre AS categoria_nombre,
    p.precio AS producto_precio,
    1 + (
        SELECT COUNT(*)
        FROM productos p2
        WHERE p2.categoria_id = p.categoria_id
          AND p2.deleted_at IS NULL
          AND (p2.precio > p.precio
               OR (p2.precio = p.precio AND p2.id < p.id))
    )                  AS ranking
FROM productos p
JOIN categorias c ON c.id = p.categoria_id
WHERE p.deleted_at IS NULL AND c.deleted_at IS NULL;

Generame una segunda version con diferente estructura(por ejemplo, la misma pregunta resuelta con  subconsulta y con join + agregación) pero que cumplan el mismo objetivo. 

## Prompt 1 Consulta 2

Generar una consulta para postgresql para obtener los productos cuyo precio sea mayor al precio promedio de los productos de su misma categoría. Usando la base de datos foodstore teniendo en cuenta los siguientes criterios
Tablas a utilizar: 
- Producto
- Categoría 
Filtro de borrado lógico:
- Se deben considerar productos cuyo deleted_at IS NULL.
- Se deben considerar categorias cuyo deleted_at IS NULL.
- Columnas de salida:
- ID del producto.
- Nombre del producto.
- Precio del producto.
Criterio de partición:
-Para cada producto se debe obtener el precio promedio de los productos activos pertenecientes a la misma categoría.
- Se debe mostrar únicamente el producto cuyo precio sea mayor a dicho promedio.
Criterio de orden:
- Los productos  requieren  ningún orden específico 
Desempate:
- Si dos productos tienen el mismo precio, se deben ordenar por ID de producto de menor a mayor.

## Prompt 2 Consulta 2

Teniendo en cuenta esta consulta provista anteriormente: 

SELECT
    p.id AS producto_id,
    p.nombre AS producto_nombre,
    c.nombre AS categoria_nombre,
    p.precio AS producto_precio,
    1 + (
        SELECT COUNT(*)
        FROM productos p2
        WHERE p2.categoria_id = p.categoria_id
          AND p2.deleted_at IS NULL
          AND (p2.precio > p.precio
               OR (p2.precio = p.precio AND p2.id < p.id))
    )                  AS ranking
FROM productos p
JOIN categorias c ON c.id = p.categoria_id
WHERE p.deleted_at IS NULL AND c.deleted_at IS NULL;


Generame una segunda version con diferente estructura(por ejemplo, la misma pregunta resuelta con  subconsulta y con join + agregación) pero que cumplan el mismo objetivo. 