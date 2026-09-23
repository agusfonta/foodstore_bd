-- =============================================================================
-- Verificación de equivalencia Parte B — ejecutar contra foodstore_desarrollo
-- Orden: 1) crear vistas previas, 2) crear vistas definitivas, 3) correr EXCEPT
-- Uso (psql, tras verificar \conninfo = foodstore_desarrollo):
--   \i db/vistas_reportes_prompt_opencode.sql
--   \i db/vistas_reportes_prompt_propio.sql
--   \i db/views.sql
--   \i db/verificacion_vistas_parteB.sql
-- Cada EXCEPT debe devolver 0 filas. Pegar los resultados en
-- docs/bitacora_verificacion_vistas_parteB.md
-- =============================================================================

-- ---------- VISTA 1: productos + categoría (columnas comunes) ----------
SELECT producto_id, producto_nombre, precio, stock
FROM v_productos_vigentes_con_categoria
EXCEPT
SELECT id, nombre, precio, stock
FROM v_productos_vigentes;

SELECT id, nombre, precio, stock
FROM v_productos_vigentes
EXCEPT
SELECT producto_id, producto_nombre, precio, stock
FROM v_productos_vigentes_con_categoria;

SELECT
    (SELECT COUNT(*) FROM v_productos_vigentes_con_categoria) AS total_opencode,
    (SELECT COUNT(*) FROM v_productos_vigentes) AS total_propio;

-- ---------- VISTA 2: pedidos + cliente (columnas comunes) ----------
SELECT pedido_id, fecha, estado, total, forma_pago,
       cliente_nombre, cliente_apellido, cliente_mail, cliente_celular
FROM v_pedidos_con_cliente
EXCEPT
SELECT id, fecha, estado, total, forma_pago,
       nombre, apellido, mail, celular
FROM v_pedidos_clientes;

SELECT id, fecha, estado, total, forma_pago,
       nombre, apellido, mail, celular
FROM v_pedidos_clientes
EXCEPT
SELECT pedido_id, fecha, estado, total, forma_pago,
       cliente_nombre, cliente_apellido, cliente_mail, cliente_celular
FROM v_pedidos_con_cliente;

SELECT
    (SELECT COUNT(*) FROM v_pedidos_con_cliente) AS total_opencode,
    (SELECT COUNT(*) FROM v_pedidos_clientes) AS total_propio;

-- ---------- VISTA 3: detalle + producto (columnas comunes) ----------
SELECT pedido_id, producto_id, producto_nombre, cantidad, precio_unitario, subtotal
FROM v_detalle_pedido_con_producto
EXCEPT
SELECT pedido_id, producto_id, producto, cantidad, precio_unitario, subtotal
FROM v_detalle_pedido;

SELECT pedido_id, producto_id, producto, cantidad, precio_unitario, subtotal
FROM v_detalle_pedido
EXCEPT
SELECT pedido_id, producto_id, producto_nombre, cantidad, precio_unitario, subtotal
FROM v_detalle_pedido_con_producto;

SELECT
    (SELECT COUNT(*) FROM v_detalle_pedido_con_producto) AS total_opencode,
    (SELECT COUNT(*) FROM v_detalle_pedido) AS total_propio;

-- ---------- SEGURIDAD: contrasenia no expuesta (0 filas esperado) ----------
SELECT table_name, column_name
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name IN ('v_pedidos_con_cliente', 'v_pedidos_clientes', 'v_productos_vigentes_con_categoria', 'v_detalle_pedido_con_producto')
  AND column_name = 'contrasenia';

-- Estas dos deben FALLAR con "column does not exist" (pegar el error):
-- SELECT contrasenia FROM v_pedidos_con_cliente LIMIT 1;
-- SELECT contrasenia FROM v_pedidos_clientes LIMIT 1;
