-- =============================================================================
-- FOODSTORE - Borrado logico (soft delete) e impacto en consultas e indices
-- TPI «Food Store» - Primera entrega parcial (Unidades 1, 2 y 3)
-- Objetivo 9 de la consigna: "Borrado logico (soft delete) y su impacto correcto
--                             sobre consultas e indices"
-- Motor: PostgreSQL 16+ (probado en 17)
-- =============================================================================
-- COMO ESTA IMPLEMENTADO EL BORRADO LOGICO (script 01_ddl_schema.sql)
--   Todas las tablas "maestras" (categorias, productos, clientes, pedidos) tienen
--     eliminado  BOOLEAN NOT NULL DEFAULT FALSE
--     deleted_at TIMESTAMPTZ  (fecha de la baja, NULL = vigente)
--   La fila NO se borra: se marca. Los procedimientos sp_baja_logica_producto y
--   sp_baja_logica_cliente (script 08) setean las dos columnas juntas.
--   detalle_pedido no tiene baja propia: sigue a su pedido.
--   Las FK son ON DELETE RESTRICT: un DELETE fisico de un producto vendido o de
--   un cliente con pedidos falla -> el borrado logico es la unica baja posible
--   y conserva el historial de ventas.
--
-- REQUISITOS: scripts 01, 02, 03 (indices), 06 (vistas) y 08 ya ejecutados en la
-- COPIA de trabajo. Los datos de prueba llevan prefijo TPI_BL y se eliminan al final.
-- En DBeaver los pasos "ERROR ESPERADO" requieren "ignorar errores y continuar".
-- =============================================================================


-- =============================================================================
-- 0) DATOS DE PRUEBA
-- =============================================================================
BEGIN;
INSERT INTO categorias (nombre) VALUES ('TPI_BL_Categoria');
INSERT INTO clientes (nombre, apellido, mail, celular, contrasenia, rol)
VALUES ('TPI_BL', 'Cliente', 'tpi_bl@test.com', '000000', 'hash_de_prueba', 'CLIENTE');
INSERT INTO productos (nombre, precio, stock, disponible, categoria_id)
SELECT 'TPI_BL_Prod_Vendido', 100.00, 10, TRUE, id FROM categorias WHERE nombre = 'TPI_BL_Categoria';
INSERT INTO productos (nombre, precio, stock, disponible, categoria_id)
SELECT 'TPI_BL_Prod_Sin_Ventas', 20.00, 5, TRUE, id FROM categorias WHERE nombre = 'TPI_BL_Categoria';
COMMIT;

SELECT set_config('tpi.bl_cli',  (SELECT id::text FROM clientes  WHERE mail   = 'tpi_bl@test.com'),      false);
SELECT set_config('tpi.bl_prod', (SELECT id::text FROM productos WHERE nombre = 'TPI_BL_Prod_Vendido'),  false);

-- Un pedido CONFIRMADO que vende el producto "vendido"
CALL sp_crear_pedido(current_setting('tpi.bl_cli')::BIGINT, 'TARJETA',
     jsonb_build_array(jsonb_build_object('producto_id', current_setting('tpi.bl_prod')::BIGINT, 'cantidad', 2)),
     NULL);
SELECT set_config('tpi.bl_ped',
       (SELECT id::text FROM pedidos WHERE cliente_id = current_setting('tpi.bl_cli')::BIGINT ORDER BY id DESC LIMIT 1), false);
CALL sp_cambiar_estado_pedido(current_setting('tpi.bl_ped')::BIGINT, 'CONFIRMADO');


-- =============================================================================
-- 1) El DELETE fisico NO es posible sobre datos con historial
-- =============================================================================
-- ERROR ESPERADO: viola la llave foranea fk_detalle_producto (ON DELETE RESTRICT)
DELETE FROM productos WHERE id = current_setting('tpi.bl_prod')::BIGINT;


-- =============================================================================
-- 2) Baja logica de un producto: la fila queda, pero "desaparece" de los reportes
-- =============================================================================
SELECT count(*) AS vigentes_antes
FROM v_productos_vigentes_con_categoria WHERE categoria_nombre = 'TPI_BL_Categoria';
-- Esperado: 2

CALL sp_baja_logica_producto(current_setting('tpi.bl_prod')::BIGINT);

-- 2.a) La fila sigue en la tabla, marcada
SELECT id, nombre, eliminado, deleted_at IS NOT NULL AS tiene_deleted_at, disponible
FROM productos WHERE id = current_setting('tpi.bl_prod')::BIGINT;
-- Esperado: eliminado = t, tiene_deleted_at = t, disponible = f

-- 2.b) La vista de productos vigentes ya no lo muestra
SELECT count(*) AS vigentes_despues
FROM v_productos_vigentes_con_categoria WHERE categoria_nombre = 'TPI_BL_Categoria';
-- Esperado: 1

-- 2.c) Las consultas de reportes (05_dml_consultas.sql) lo excluyen con
--      "pr.eliminado = FALSE": el ranking de ventas ya no lo cuenta ...
SELECT pr.id, pr.nombre, SUM(dp.cantidad) AS unidades_vendidas
FROM detalle_pedido dp
JOIN pedidos p    ON p.id  = dp.pedido_id
JOIN productos pr ON pr.id = dp.producto_id
WHERE p.estado IN ('CONFIRMADO', 'TERMINADO')
  AND p.eliminado = FALSE AND pr.eliminado = FALSE
  AND pr.nombre LIKE 'TPI_BL%'
GROUP BY pr.id, pr.nombre;
-- Esperado: 0 filas

-- 2.d) ... pero el HISTORIAL del pedido se conserva integro (detalle + total)
SELECT dp.pedido_id, dp.producto_id, dp.cantidad, dp.precio_unitario, dp.subtotal, p.total
FROM detalle_pedido dp JOIN pedidos p ON p.id = dp.pedido_id
WHERE dp.pedido_id = current_setting('tpi.bl_ped')::BIGINT;
-- Esperado: 1 fila (2 x 100.00 = 200.00): la venta historica no se altera

-- 2.e) Sobre un producto ya dado de baja, el procedimiento rechaza la repeticion
-- ERROR ESPERADO: Producto ... inexistente o ya dado de baja
CALL sp_baja_logica_producto(current_setting('tpi.bl_prod')::BIGINT);

-- 2.f) Y no se puede vender un producto dado de baja
-- ERROR ESPERADO: Producto ... inexistente o dado de baja
CALL sp_crear_pedido(current_setting('tpi.bl_cli')::BIGINT, 'EFECTIVO',
     jsonb_build_array(jsonb_build_object('producto_id', current_setting('tpi.bl_prod')::BIGINT, 'cantidad', 1)),
     NULL);


-- =============================================================================
-- 3) Baja logica de un cliente: la regla de negocio (trigger) la protege
-- =============================================================================
-- ERROR ESPERADO: No se puede dar de baja al cliente ...: tiene pedidos PENDIENTE o CONFIRMADO
CALL sp_baja_logica_cliente(current_setting('tpi.bl_cli')::BIGINT);

-- Se cancela el pedido (repone stock) y recien ahi la baja es posible
CALL sp_cambiar_estado_pedido(current_setting('tpi.bl_ped')::BIGINT, 'CANCELADO');
CALL sp_baja_logica_cliente(current_setting('tpi.bl_cli')::BIGINT);

SELECT mail, eliminado, deleted_at IS NOT NULL AS tiene_deleted_at
FROM clientes WHERE mail = 'tpi_bl@test.com';
-- Esperado: eliminado = t, tiene_deleted_at = t

-- El pedido historico del cliente dado de baja no aparece en la vista con datos
-- del cliente (la vista filtra cl.eliminado = FALSE) pero sigue en la tabla:
SELECT (SELECT count(*) FROM v_pedidos_con_cliente
        WHERE pedido_id = current_setting('tpi.bl_ped')::BIGINT) AS en_vista,
       (SELECT count(*) FROM pedidos
        WHERE id = current_setting('tpi.bl_ped')::BIGINT)         AS en_tabla;
-- Esperado: 0 | 1


-- =============================================================================
-- 4) IMPACTO EN INDICES - los indices parciales "WHERE eliminado = FALSE"
--    (03_ddl_indices.sql) solo contienen filas vigentes:
--      * son mas chicos (no cargan filas dadas de baja),
--      * pero el planner SOLO los usa si la consulta repite el predicado
--        eliminado = FALSE (por eso todas las consultas del proyecto lo incluyen).
--    Con tan pocas filas el planner prefiere Seq Scan; se desactiva SOLO dentro de
--    la transaccion para poder mostrar el uso del indice. (Con la carga masiva del
--    script 04 el planner lo elige solo, ver Informes_tps/Informe_optimizacion_consultas_indices.md.)
-- =============================================================================
BEGIN;
SET LOCAL enable_seqscan = off;

-- 4.a) Con el predicado: usa el indice parcial idx_productos_categoria_eliminado
EXPLAIN (COSTS OFF)
SELECT id, nombre FROM productos
WHERE categoria_id = (SELECT id FROM categorias WHERE nombre = 'TPI_BL_Categoria')
  AND eliminado = FALSE;
-- Esperado: Index Scan / Bitmap ... idx_productos_categoria_eliminado

-- 4.b) Sin el predicado: el indice parcial NO es aplicable (no puede garantizar
--      que cubre todas las filas) y ademas la consulta devolveria productos dados de baja
EXPLAIN (COSTS OFF)
SELECT id, nombre FROM productos
WHERE categoria_id = (SELECT id FROM categorias WHERE nombre = 'TPI_BL_Categoria');
-- Esperado: NO aparece idx_productos_categoria_eliminado
ROLLBACK;

-- Nota: con la carga masiva (script 04) el indice parcial pesa solo las filas vigentes;
-- se puede comparar con: SELECT pg_size_pretty(pg_relation_size('idx_productos_categoria_eliminado'));


-- =============================================================================
-- 5) PUNTO DE ATENCION: UNIQUE + borrado logico
--    productos.nombre, clientes.mail y categorias.nombre son UNIQUE sobre TODAS
--    las filas, incluidas las dadas de baja. Consecuencia: no se puede volver a
--    crear un producto con el nombre de uno dado de baja (el "fantasma" sigue
--    ocupando el nombre).
-- =============================================================================
-- ERROR ESPERADO: llave duplicada viola productos_nombre_key
INSERT INTO productos (nombre, precio, stock, disponible, categoria_id)
SELECT 'TPI_BL_Prod_Vendido', 110.00, 5, TRUE, id FROM categorias WHERE nombre = 'TPI_BL_Categoria';

-- Alternativa correcta para soft delete: UNIQUE PARCIAL solo sobre filas vigentes.
-- Se prueba dentro de una transaccion y se deshace: NO se modifica el esquema
-- entregado (decision de la/del estudiante si se adopta en la version final).
BEGIN;
ALTER TABLE productos DROP CONSTRAINT productos_nombre_key;
CREATE UNIQUE INDEX uq_productos_nombre_vigente ON productos (nombre) WHERE eliminado = FALSE;

INSERT INTO productos (nombre, precio, stock, disponible, categoria_id)
SELECT 'TPI_BL_Prod_Vendido', 110.00, 5, TRUE, id FROM categorias WHERE nombre = 'TPI_BL_Categoria';
-- Esperado: INSERT 0 1 (ahora si se puede: el anterior esta dado de baja)

-- ERROR ESPERADO: sigue prohibido tener DOS vigentes con el mismo nombre
INSERT INTO productos (nombre, precio, stock, disponible, categoria_id)
SELECT 'TPI_BL_Prod_Vendido', 120.00, 5, TRUE, id FROM categorias WHERE nombre = 'TPI_BL_Categoria';
ROLLBACK;
-- (tras el ERROR la transaccion esta abortada; el ROLLBACK restaura el esquema original)


-- =============================================================================
-- 6) LIMPIEZA de los datos de prueba (deja la base como estaba)
-- =============================================================================
BEGIN;
DELETE FROM detalle_pedido WHERE pedido_id IN (SELECT id FROM pedidos WHERE cliente_id = current_setting('tpi.bl_cli')::BIGINT);
DELETE FROM pedidos    WHERE cliente_id = current_setting('tpi.bl_cli')::BIGINT;
DELETE FROM productos  WHERE nombre LIKE 'TPI_BL%';
DELETE FROM clientes   WHERE mail = 'tpi_bl@test.com';
DELETE FROM categorias WHERE nombre = 'TPI_BL_Categoria';
COMMIT;

SELECT (SELECT count(*) FROM productos  WHERE nombre LIKE 'TPI_BL%')       AS productos_prueba,
       (SELECT count(*) FROM clientes   WHERE mail = 'tpi_bl@test.com')     AS clientes_prueba,
       (SELECT count(*) FROM categorias WHERE nombre = 'TPI_BL_Categoria')  AS categorias_prueba;
-- Esperado: 0 | 0 | 0
