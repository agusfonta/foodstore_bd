-- =========================================================
-- FOODSTORE - Carga masiva (variante A)
-- =========================================================
-- OBJETIVO: 50.000 productos / 20.000 clientes / 200.000 pedidos
--           con 1-5 detalles por pedido (200k-1M filas en detalle_pedido)
--
-- SEGURIDAD (protocolo_seguridad.md):
--   - EJECUTAR UNICAMENTE EN foodstore_desarrollo (copia via createdb -T foodstore)
--   - NUNCA en foodstore (produccion)
--   - Verificar antes: SELECT current_database(), current_user; -- debe ser foodstore_desarrollo / postgres
--   - Respaldo previo obligatorio:
--       if (-not (Test-Path ".\backups")) { New-Item -ItemType Directory -Path ".\backups" }
--       pg_dump -U postgres -h localhost -p 5432 -d foodstore_desarrollo -F c -b -v -f ".\backups\respaldo_completo_$(Get-Date -Format 'yyyyMMdd_HHmmss').backup"
--   - Ejecutar DENTRO DE TRANSACCION de prueba primero:
--       BEGIN;
--       \i carga_masiva.sql
--       -- verificaciones de conteos/restricciones (ver pie del archivo)
--       ROLLBACK;  -- solo COMMIT tras verificacion 100% correcta
--   - No incluye BEGIN/COMMIT: los envuelve el caller
--
-- VARIANTE A: se conservan categorias existentes (no se truncan).
--   Si categorias tambien debe limpiarse, ver bloque comentado variante B.
--
-- REQUISITOS: PostgreSQL 17.x, base vacia en tablas transaccionales,
--             categorias con al menos 1 fila.
--             Usa generate_series + operaciones set-based, sin PL/pgSQL.
--
-- ORDEN: clientes -> productos -> pedidos (total=0) -> detalle_pedido -> UPDATE total -> ANALYZE
-- =========================================================


-- =========================================================
-- 0) LIMPIEZA - Dejar base vacia (solo desarrollo)
-- =========================================================
-- TRUNCATE es DDL eficiente: vacia y reinicia IDENTITY en una operacion,
-- respeta FKs con CASCADE (detalle_pedido referencia pedidos y productos).
-- DELETE se descarta: fila por fila, WAL por fila, no reinicia IDENTITY.

TRUNCATE detalle_pedido, pedidos, productos, clientes RESTART IDENTITY CASCADE;

-- Variante B (desactivada): truncar tambien categorias y re-seedear.
-- Descomentar solo si se quiere partir de 5 categorias canonicas:
-- TRUNCATE categorias RESTART IDENTITY CASCADE;
-- INSERT INTO categorias (nombre, descripcion) VALUES
--   ('Bebidas',   'Bebidas y aguas'),
--   ('Lacteos',   'Leche, yogures y quesos'),
--   ('Panaderia', 'Pan y facturas'),
--   ('Frutas',    'Frutas frescas'),
--   ('Snacks',    'Snacks y golosinas');

-- Verificacion opcional dentro de la transaccion (deben ser 0):
-- SELECT 'detalle_pedido' AS tabla, COUNT(*) FROM detalle_pedido
-- UNION ALL SELECT 'pedidos', COUNT(*) FROM pedidos
-- UNION ALL SELECT 'productos', COUNT(*) FROM productos
-- UNION ALL SELECT 'clientes', COUNT(*) FROM clientes;


-- =========================================================
-- 1) 20.000 CLIENTES (= usuarios)
-- =========================================================
-- Tabla: clientes (Script.sql:77)
-- Restricciones: mail UNIQUE + CHECK POSITION('@' IN mail) > 1
-- Genera mail unico deterministico usuario<gs>@test.com; rol NOT NULL.

INSERT INTO clientes (nombre, apellido, mail, celular, contrasenia, rol)
SELECT
    'Nombre'  || gs,
    'Apellido'|| gs,
    'usuario' || gs || '@test.com',
    '54 11 '  || lpad((1000000 + gs)::text, 7, '0'),
    'hash_'   || md5(random()::text),
    'CLIENTE'
FROM generate_series(1, 20000) AS gs;


-- =========================================================
-- 2) 50.000 PRODUCTOS - distribucion pareja entre categorias
-- =========================================================
-- Tabla: productos (Script.sql:46)
-- Restricciones: nombre UNIQUE, precio >=0, stock >=0, fk_producto_categoria
-- Estrategia: array_agg de categorias en una sola lectura; indice
--   cat.ids[1 + (gs-1) % array_length(cat.ids,1)] reparte parejo.
-- Requiere: al menos 1 categoria en categorias (variante A la conserva).

WITH cat AS (
    SELECT array_agg(id ORDER BY id) AS ids
    FROM categorias
)
INSERT INTO productos (nombre, precio, stock, disponible, categoria_id, descripcion)
SELECT
    'Producto_' || gs,
    round((5 + random() * 495)::numeric, 2),  -- 5.00 .. 500.00  cumple chk_producto_precio
    1 + (random() * 100)::int,                -- 1 .. 101        cumple chk_producto_stock
    TRUE,
    cat.ids[1 + (gs - 1) % array_length(cat.ids, 1)],
    'Prod masivo ' || gs
FROM generate_series(1, 50000) AS gs
CROSS JOIN cat;


-- =========================================================
-- 3) 200.000 PEDIDOS (total = 0 temporal)
-- =========================================================
-- Tabla: pedidos (Script.sql:98)
-- Tipos: estado_pedido ENUM('PENDIENTE','CONFIRMADO','TERMINADO','CANCELADO')
--        forma_pago  ENUM('TARJETA','TRANSFERENCIA','EFECTIVO')
-- Restricciones: total >=0, fk_pedido_cliente
-- Se inserta total=0 para luego recalcular desde detalle_pedido y evitar
-- inconsistencias durante la carga masiva.

WITH cli AS (
    SELECT array_agg(id ORDER BY id) AS ids
    FROM clientes
)
INSERT INTO pedidos (cliente_id, estado, forma_pago, total, fecha)
SELECT
    cli.ids[1 + (gs - 1) % array_length(cli.ids, 1)],
    (ARRAY['PENDIENTE','CONFIRMADO','TERMINADO','CANCELADO']::estado_pedido[])[1 + (gs % 4)],
    (ARRAY['TARJETA','TRANSFERENCIA','EFECTIVO']::forma_pago[])[1 + (gs % 3)],
    0,
    now() - ((gs % 365) || ' days')::interval * random()
FROM generate_series(1, 200000) AS gs
CROSS JOIN cli;


-- =========================================================
-- 4) DETALLE_PEDIDO - 1 a 5 filas por pedido (200k - 1M filas)
-- =========================================================
-- Tabla: detalle_pedido (Script.sql:125)
-- Restricciones:
--   cantidad > 0, precio_unitario >=0, subtotal >=0,
--   chk_detalle_subtotal_coherente CHECK (subtotal = cantidad * precio_unitario)
--   UNIQUE (pedido_id, producto_id)
--   FKs a pedidos y productos ON DELETE RESTRICT
-- Estrategia set-based sin PL/pgSQL:
--   - prod: array de productos.id (50000)
--   - ped:  pedidos.id + row_number para k deterministico
--   - exp:  expande cada pedido en k = 1 + (rn % 5) filas via LATERAL generate_series
--           k en 1..5, promedio ~3 => ~600k detalles
--   - producto distinto por pedido: offset (rn + k) % prod.n garantiza
--     que los k productos de un mismo pedido sean diferentes (n=50000 >>5)
--   - precio_unitario copiado de productos.precio, subtotal coherente

WITH prod AS (
    SELECT array_agg(id ORDER BY id) AS ids, COUNT(*) AS n
    FROM productos
),
ped AS (
    SELECT id, row_number() OVER (ORDER BY id) AS rn
    FROM pedidos
),
exp AS (
    SELECT ped.id AS pedido_id, ped.rn, g.k
    FROM ped
    CROSS JOIN LATERAL generate_series(1, 1 + (ped.rn % 5)) AS g(k)
)
INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, precio_unitario, subtotal)
SELECT
    e.pedido_id,
    prod.ids[1 + ((e.rn + e.k) % prod.n)],
    1 + ((e.rn + e.k) % 5)                         AS cantidad,
    p.precio                                       AS precio_unitario,
    (1 + ((e.rn + e.k) % 5)) * p.precio            AS subtotal
FROM exp e
CROSS JOIN prod
JOIN productos p ON p.id = prod.ids[1 + ((e.rn + e.k) % prod.n)];


-- =========================================================
-- 5) RECALCULO DE TOTALES EN PEDIDOS
-- =========================================================
-- Mantiene coherencia pedidos.total = SUM(detalle_pedido.subtotal)
-- Cumple chk_pedido_total CHECK (total >=0)

UPDATE pedidos p
SET total = s.sum_sub
FROM (
    SELECT pedido_id, SUM(subtotal) AS sum_sub
    FROM detalle_pedido
    GROUP BY pedido_id
) s
WHERE p.id = s.pedido_id;


-- =========================================================
-- 6) ANALYZE - Actualizar estadisticas para el planificador
-- =========================================================
-- Imprescindible tras carga masiva antes de mediciones EXPLAIN.

ANALYZE categorias;
ANALYZE clientes;
ANALYZE productos;
ANALYZE pedidos;
ANALYZE detalle_pedido;


-- =========================================================
-- VERIFICACIONES (ejecutar dentro de la misma transaccion antes de COMMIT)
-- =========================================================
-- -- Conteos minimos
-- SELECT COUNT(*) FROM clientes;        -- 20000
-- SELECT COUNT(*) FROM productos;       -- 50000
-- SELECT COUNT(*) FROM pedidos;         -- 200000
-- SELECT COUNT(*) FROM detalle_pedido;  -- 200000..1000000 (esperado ~600k)
--
-- -- Distribucion pareja por categoria (max - min <= 1)
-- SELECT categoria_id, COUNT(*) FROM productos GROUP BY categoria_id ORDER BY categoria_id;
--
-- -- Detalles por pedido
-- SELECT COUNT(*) AS pedidos_con_detalle FROM (SELECT pedido_id FROM detalle_pedido GROUP BY pedido_id) q; -- 200000
-- SELECT MIN(c), MAX(c), AVG(c)::numeric(10,2) FROM (SELECT pedido_id, COUNT(*) AS c FROM detalle_pedido GROUP BY pedido_id) q; -- 1, 5, ~3.00
-- SELECT COUNT(*) AS pedidos_sin_detalle FROM pedidos p LEFT JOIN detalle_pedido d ON d.pedido_id = p.id WHERE d.pedido_id IS NULL; -- 0
--
-- -- Restricciones
-- SELECT COUNT(*) AS viol_mail FROM clientes WHERE POSITION('@' IN mail) <= 1; -- 0
-- SELECT COUNT(*) AS dup_mail  FROM (SELECT mail FROM clientes GROUP BY mail HAVING COUNT(*)>1) q; -- 0
-- SELECT COUNT(*) AS dup_prod  FROM (SELECT nombre FROM productos GROUP BY nombre HAVING COUNT(*)>1) q; -- 0
-- SELECT COUNT(*) AS precio_neg FROM productos WHERE precio < 0; -- 0
-- SELECT COUNT(*) AS stock_neg  FROM productos WHERE stock  < 0; -- 0
-- SELECT COUNT(*) AS total_neg  FROM pedidos   WHERE total < 0; -- 0
-- SELECT COUNT(*) AS cant_bad   FROM detalle_pedido WHERE cantidad <= 0; -- 0
-- SELECT COUNT(*) AS sub_inc    FROM detalle_pedido WHERE subtotal <> cantidad * precio_unitario; -- 0
-- SELECT COUNT(*) AS dup_det    FROM (SELECT pedido_id, producto_id FROM detalle_pedido GROUP BY 1,2 HAVING COUNT(*)>1) q; -- 0
-- SELECT COUNT(*) AS total_desact FROM pedidos p JOIN (SELECT pedido_id, SUM(subtotal) AS s FROM detalle_pedido GROUP BY 1) s ON s.pedido_id=p.id WHERE p.total <> s.s; -- 0
--
-- -- Estadisticas
-- SELECT relname, last_analyze, n_live_tup FROM pg_stat_all_tables WHERE relname IN ('categorias','productos','clientes','pedidos','detalle_pedido');
--
-- -- Rollback de prueba: ROLLBACK;  -- solo COMMIT si todo es 0 / conteos OK
-- =========================================================
