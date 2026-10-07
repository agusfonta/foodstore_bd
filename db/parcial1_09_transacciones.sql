-- =============================================================================
-- FOODSTORE - Transacciones: atomicidad, COMMIT, ROLLBACK, SAVEPOINT,
--             niveles de aislamiento y control de concurrencia
-- TPI «Food Store» - PARCIAL 1 (primera entrega parcial) (Unidad 1)
-- Objetivo 8 de la consigna: "Transacciones: atomicidad, COMMIT, ROLLBACK,
--                             niveles de aislamiento y control de concurrencia"
-- Motor: PostgreSQL 16+ (probado en 17)
-- =============================================================================
-- REQUISITOS: scripts 01, 02 y 08 ya ejecutados en la COPIA de trabajo
--             (foodstore_desarrollo). NUNCA correr sobre la base original.
--
-- COMO EJECUTARLO
--   psql  : psql -U postgres -d foodstore_desarrollo -f db/parcial1_09_transacciones.sql
--   DBeaver: Alt+X (script). Los pasos marcados "ERROR ESPERADO" fallan a
--            proposito; en DBeaver elegir "ignorar errores y continuar".
--
-- Los ids de prueba se guardan en variables de sesion (set_config) para que el
-- script sea portable entre psql y DBeaver. Todos los datos de prueba llevan el
-- prefijo TPI_TX y se eliminan en la seccion 7 (la base queda como estaba).
--
-- La evidencia de los experimentos con DOS sesiones simultaneas (lectura no
-- repetible, lectura fantasma y espera por bloqueo) esta en
-- docs/informes/parcial1_informe_concurrencia.md. La seccion 6 de este script agrega la prueba de
-- concurrencia sobre sp_crear_pedido (ultima unidad de stock).
-- =============================================================================


-- =============================================================================
-- 0) DATOS DE PRUEBA (confirmados con COMMIT)
--    Producto A: stock 10, $100.00 | Producto B: stock 2, $50.00
-- =============================================================================
BEGIN;

INSERT INTO categorias (nombre, descripcion)
VALUES ('TPI_TX_Categoria', 'Datos de prueba de parcial1_09_transacciones.sql');

INSERT INTO clientes (nombre, apellido, mail, celular, contrasenia, rol)
VALUES ('TPI_TX', 'Cliente', 'tpi_tx@test.com', '000000', 'hash_de_prueba', 'CLIENTE');

INSERT INTO productos (nombre, precio, stock, disponible, categoria_id)
SELECT 'TPI_TX_Prod_A', 100.00, 10, TRUE, id FROM categorias WHERE nombre = 'TPI_TX_Categoria';
INSERT INTO productos (nombre, precio, stock, disponible, categoria_id)
SELECT 'TPI_TX_Prod_B',  50.00,  2, TRUE, id FROM categorias WHERE nombre = 'TPI_TX_Categoria';

COMMIT;

SELECT set_config('tpi.cli',    (SELECT id::text FROM clientes  WHERE mail   = 'tpi_tx@test.com'), false);
SELECT set_config('tpi.prod_a', (SELECT id::text FROM productos WHERE nombre = 'TPI_TX_Prod_A'),   false);
SELECT set_config('tpi.prod_b', (SELECT id::text FROM productos WHERE nombre = 'TPI_TX_Prod_B'),   false);

SELECT nombre, stock, precio FROM productos WHERE nombre LIKE 'TPI_TX%' ORDER BY id;
-- Esperado: A stock 10 / B stock 2


-- =============================================================================
-- 1) ATOMICIDAD - caso exitoso + COMMIT
--    sp_crear_pedido inserta cabecera + 2 renglones + descuenta stock + calcula
--    total: o se hace todo o no se hace nada.
-- =============================================================================
BEGIN;

CALL sp_crear_pedido(
    current_setting('tpi.cli')::BIGINT,
    'TARJETA',
    jsonb_build_array(
        jsonb_build_object('producto_id', current_setting('tpi.prod_a')::BIGINT, 'cantidad', 3),
        jsonb_build_object('producto_id', current_setting('tpi.prod_b')::BIGINT, 'cantidad', 1)
    ),
    NULL
);
-- Devuelve una fila con p_pedido_id (parametro INOUT).

SELECT set_config('tpi.ped1',
       (SELECT id::text FROM pedidos
        WHERE cliente_id = current_setting('tpi.cli')::BIGINT ORDER BY id DESC LIMIT 1), false);

-- Estado dentro de la transaccion (aun no confirmada)
SELECT p.id, p.estado, p.total,
       fn_total_pedido(p.id) AS suma_subtotales,
       (p.total = fn_total_pedido(p.id)) AS total_coherente
FROM pedidos p WHERE p.id = current_setting('tpi.ped1')::BIGINT;
-- Esperado: PENDIENTE, total 350.00 (3x100 + 1x50), total_coherente = t

SELECT nombre, stock FROM productos WHERE nombre LIKE 'TPI_TX%' ORDER BY id;
-- Esperado: A stock 7 / B stock 1

COMMIT;


-- =============================================================================
-- 2) ATOMICIDAD - caso con fallo + ROLLBACK TO SAVEPOINT
--    El renglon de A (2 u.) seria valido, pero el de B pide 5 y solo queda 1.
--    El CALL falla y se revierte COMPLETO, incluido el descuento de stock de A
--    que el procedimiento ya habia hecho antes de llegar a B.
-- =============================================================================
BEGIN;
SAVEPOINT antes_del_pedido;

-- ERROR ESPERADO: Stock insuficiente para ... (TPI_TX_Prod_B)
CALL sp_crear_pedido(
    current_setting('tpi.cli')::BIGINT,
    'EFECTIVO',
    jsonb_build_array(
        jsonb_build_object('producto_id', current_setting('tpi.prod_a')::BIGINT, 'cantidad', 2),
        jsonb_build_object('producto_id', current_setting('tpi.prod_b')::BIGINT, 'cantidad', 5)
    ),
    NULL
);

ROLLBACK TO SAVEPOINT antes_del_pedido;   -- la transaccion vuelve a ser usable

SELECT count(*) AS pedidos_del_cliente
FROM pedidos WHERE cliente_id = current_setting('tpi.cli')::BIGINT;
-- Esperado: 1 (solo el de la seccion 1; el fallido no dejo rastro)

SELECT nombre, stock FROM productos WHERE nombre LIKE 'TPI_TX%' ORDER BY id;
-- Esperado: A stock 7 (NO 5) / B stock 1  -> el descuento parcial se deshizo

COMMIT;


-- =============================================================================
-- 3) ROLLBACK explicito de una modificacion directa
-- =============================================================================
BEGIN;
UPDATE productos SET stock = 0 WHERE nombre = 'TPI_TX_Prod_A';
SELECT nombre, stock FROM productos WHERE nombre = 'TPI_TX_Prod_A';   -- 0 (solo visible aqui)
ROLLBACK;
SELECT nombre, stock FROM productos WHERE nombre = 'TPI_TX_Prod_A';   -- 7 otra vez


-- =============================================================================
-- 4) Regla de negocio dentro de una transaccion: estados + reposicion de stock
-- =============================================================================
-- 4.a) PENDIENTE -> CONFIRMADO -> CANCELADO, todo atomico, y se repone el stock
BEGIN;
CALL sp_cambiar_estado_pedido(current_setting('tpi.ped1')::BIGINT, 'CONFIRMADO');
CALL sp_cambiar_estado_pedido(current_setting('tpi.ped1')::BIGINT, 'CANCELADO');
SELECT nombre, stock FROM productos WHERE nombre LIKE 'TPI_TX%' ORDER BY id;
-- Esperado: A stock 10 / B stock 2 (stock reservado devuelto)
COMMIT;

-- 4.b) Transicion invalida: CANCELADO es estado final (trigger del script 02)
BEGIN;
-- ERROR ESPERADO: Estado CANCELADO es final y no puede modificarse
CALL sp_cambiar_estado_pedido(current_setting('tpi.ped1')::BIGINT, 'CONFIRMADO');
ROLLBACK;

SELECT id, estado FROM pedidos WHERE id = current_setting('tpi.ped1')::BIGINT;
-- Esperado: CANCELADO (sin cambios)


-- =============================================================================
-- 5) NIVELES DE AISLAMIENTO
--    PostgreSQL implementa READ COMMITTED (por defecto), REPEATABLE READ
--    (snapshot isolation) y SERIALIZABLE (SSI). READ UNCOMMITTED se comporta
--    como READ COMMITTED: nunca hay lecturas sucias.
-- =============================================================================
SHOW default_transaction_isolation;      -- read committed

BEGIN ISOLATION LEVEL REPEATABLE READ;
SHOW transaction_isolation;              -- repeatable read
SELECT nombre, stock FROM productos WHERE nombre = 'TPI_TX_Prod_A';
-- (en una 2da sesion un UPDATE + COMMIT sobre este producto NO se veria aqui:
--  el snapshot se fija en la primera consulta de la transaccion)
COMMIT;

BEGIN ISOLATION LEVEL SERIALIZABLE;
SHOW transaction_isolation;              -- serializable
COMMIT;

-- Diferencias demostradas con dos sesiones en docs/informes/parcial1_informe_concurrencia.md:
--   Exp. 1 lectura no repetible : ocurre en READ COMMITTED, no en REPEATABLE READ
--   Exp. 2 lectura fantasma     : ocurre en READ COMMITTED, no en REPEATABLE READ
--   Exp. 3 espera por bloqueo   : UPDATE vs UPDATE sobre la misma fila (lock de fila)


-- =============================================================================
-- 6) CONCURRENCIA - dos clientes compiten por la ULTIMA unidad de stock
--    Prueba con DOS sesiones (dos pestanas de psql / DBeaver) sobre este escenario.
--
--    Preparacion (sesion A, una sola vez): dejar el producto B con stock 1
--       UPDATE productos SET stock = 1 WHERE nombre = 'TPI_TX_Prod_B';
--
--    Sesion A                                      Sesion B
--    ---------------------------------------      ---------------------------------------
--    BEGIN;
--    CALL sp_crear_pedido(<cli>, 'TARJETA',
--      '[{"producto_id": <prod_b>, "cantidad": 1}]',
--      NULL);              -- toma FOR UPDATE
--                                                  BEGIN;
--                                                  CALL sp_crear_pedido(<cli>, 'EFECTIVO',
--                                                    '[{"producto_id": <prod_b>, "cantidad": 1}]',
--                                                    NULL);
--                                                  -- QUEDA ESPERANDO (bloqueada por A)
--    COMMIT;
--                                                  -- se destraba y relee el stock ya
--                                                  -- descontado -> ERROR: Stock insuficiente
--                                                  ROLLBACK;
--
--    Resultado: se vende exactamente 1 unidad, nunca se genera stock negativo
--    ni se vende 2 veces la misma unidad. Sin el FOR UPDATE ambas sesiones leerian
--    stock = 1 y la segunda dejaria stock en -1 (el CHECK chk_producto_stock
--    la rechazaria con otro error, pero se habria vendido de mas en la logica).
--    Mientras B espera, verlo en una tercera sesion:
--       SELECT pid, wait_event_type, wait_event, state, left(query, 60)
--       FROM pg_stat_activity WHERE wait_event_type = 'Lock';
--    Resultado real obtenido: A hizo COMMIT a los ~4 s; B quedo bloqueada con
--    wait_event_type = Lock / wait_event = transactionid y al destrabarse fallo con
--    'Stock insuficiente ... disponible 0'. Detalle en Informe_Parcial_1.md.
-- =============================================================================


-- =============================================================================
-- 7) LIMPIEZA de los datos de prueba (deja la base como estaba)
-- =============================================================================
BEGIN;
DELETE FROM detalle_pedido
 WHERE pedido_id IN (SELECT id FROM pedidos WHERE cliente_id = current_setting('tpi.cli')::BIGINT);
DELETE FROM pedidos    WHERE cliente_id = current_setting('tpi.cli')::BIGINT;
DELETE FROM productos  WHERE nombre LIKE 'TPI_TX%';
DELETE FROM clientes   WHERE mail = 'tpi_tx@test.com';
DELETE FROM categorias WHERE nombre = 'TPI_TX_Categoria';
COMMIT;

SELECT (SELECT count(*) FROM productos  WHERE nombre LIKE 'TPI_TX%')         AS productos_prueba,
       (SELECT count(*) FROM clientes   WHERE mail = 'tpi_tx@test.com')       AS clientes_prueba,
       (SELECT count(*) FROM categorias WHERE nombre = 'TPI_TX_Categoria')    AS categorias_prueba;
-- Esperado: 0 | 0 | 0
