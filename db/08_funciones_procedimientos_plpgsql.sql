-- =============================================================================
-- FOODSTORE - Funciones y procedimientos almacenados en PL/pgSQL
-- TPI «Food Store» - Primera entrega parcial (Unidades 1, 2 y 3)
-- Objetivo 6 de la consigna: "Vistas, funciones y procedimientos almacenados
--                             desarrollados en PL/pgSQL"
-- Motor: PostgreSQL 16+ (probado en 17)
-- =============================================================================
-- ORDEN DE EJECUCION (sobre la COPIA de trabajo foodstore_desarrollo):
--   01_ddl_schema.sql -> 02_reglas_negocio_check_unique_triggers.sql -> ...
--   -> 08_funciones_procedimientos_plpgsql.sql (este archivo)
-- Protocolo de seguridad (ver protocolo_seguridad.md): no correr sobre la base
-- original, respaldo previo con pg_dump y primera corrida dentro de BEGIN/ROLLBACK.
--
-- Este archivo es idempotente (CREATE OR REPLACE): se puede volver a ejecutar.
-- Las PRUEBAS con CALL estan en 09_transacciones.sql y 10_borrado_logico.sql.
--
-- Contenido
--   FUNCIONES   (se invocan con SELECT)
--     fn_total_pedido(pedido_id)
--     fn_pedidos_cliente(cliente_id, estado)
--     fn_ranking_productos_categoria(top_n)           -> usa funcion de ventana
--   PROCEDIMIENTOS (se invocan con CALL)
--     sp_crear_pedido(cliente_id, forma_pago, items JSONB, INOUT pedido_id)
--     sp_cambiar_estado_pedido(pedido_id, nuevo_estado)
--     sp_baja_logica_producto(producto_id)
--     sp_baja_logica_cliente(cliente_id)
--     sp_refrescar_facturacion_categoria_mes()
--   (Las funciones de trigger fn_check_transicion_estado y
--    fn_check_baja_cliente_con_pedidos_activos estan en el script 02.)
--
-- Decisiones de diseno
--   * Los procedimientos NO hacen COMMIT/ROLLBACK propios: la atomicidad la da
--     la transaccion del llamador. Si un CALL falla (RAISE EXCEPTION, CHECK, FK,
--     trigger) PostgreSQL deshace TODO lo que ese CALL habia hecho. Dentro de un
--     BEGIN ... COMMIT explicito el llamador decide cuando confirmar.
--   * El stock se RESERVA al crear el pedido y se DEVUELVE al cancelarlo.
--   * El control de concurrencia es pesimista: SELECT ... FOR UPDATE sobre las
--     filas de productos / pedidos que se van a modificar (ver docs/informes/informe_concurrencia.md).
--     Los productos se bloquean siempre en orden de id para evitar deadlocks
--     entre dos pedidos que compran los mismos productos en distinto orden.
--   * Borrado logico: se marcan juntos eliminado = TRUE y deleted_at = now().
-- =============================================================================


-- =============================================================================
-- FUNCIONES
-- =============================================================================

-- -----------------------------------------------------------------------------
-- fn_total_pedido: suma de subtotales de un pedido (0 si no tiene detalle).
-- Sirve para auditar la columna derivada pedidos.total (ver normalizacion).
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_total_pedido(p_pedido_id BIGINT)
RETURNS NUMERIC(12,2)
LANGUAGE sql
STABLE
AS $$
    SELECT COALESCE(SUM(dp.subtotal), 0)::NUMERIC(12,2)
    FROM detalle_pedido dp
    WHERE dp.pedido_id = p_pedido_id;
$$;


-- -----------------------------------------------------------------------------
-- fn_pedidos_cliente: historial de pedidos vigentes de un cliente, con filtro
-- opcional por estado (NULL = todos). Respeta el borrado logico.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_pedidos_cliente(
    p_cliente_id BIGINT,
    p_estado     estado_pedido DEFAULT NULL
)
RETURNS TABLE (
    pedido_id  BIGINT,
    fecha      TIMESTAMPTZ,
    estado     estado_pedido,
    forma_pago forma_pago,
    total      NUMERIC(12,2)
)
LANGUAGE sql
STABLE
AS $$
    SELECT p.id, p.fecha, p.estado, p.forma_pago, p.total
    FROM pedidos p
    WHERE p.cliente_id = p_cliente_id
      AND p.eliminado  = FALSE
      AND (p_estado IS NULL OR p.estado = p_estado)
    ORDER BY p.fecha DESC;
$$;


-- -----------------------------------------------------------------------------
-- fn_ranking_productos_categoria: los N productos mas vendidos de CADA categoria.
-- Usa funcion de ventana (RANK() OVER PARTITION BY) sobre el agregado.
-- Solo cuenta pedidos CONFIRMADO/TERMINADO y registros no eliminados.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_ranking_productos_categoria(p_top INTEGER DEFAULT 3)
RETURNS TABLE (
    categoria         VARCHAR,
    posicion          BIGINT,
    producto_id       BIGINT,
    producto          VARCHAR,
    unidades_vendidas BIGINT
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    IF p_top IS NULL OR p_top < 1 THEN
        RAISE EXCEPTION 'p_top debe ser >= 1 (recibido: %)', p_top;
    END IF;

    RETURN QUERY
    WITH ventas AS (
        SELECT c.id   AS categoria_id,
               c.nombre AS categoria,
               pr.id  AS producto_id,
               pr.nombre AS producto,
               SUM(dp.cantidad)::BIGINT AS unidades
        FROM detalle_pedido dp
        JOIN pedidos    p  ON p.id  = dp.pedido_id
        JOIN productos  pr ON pr.id = dp.producto_id
        JOIN categorias c  ON c.id  = pr.categoria_id
        WHERE p.estado IN ('CONFIRMADO', 'TERMINADO')
          AND p.eliminado  = FALSE
          AND pr.eliminado = FALSE
          AND c.eliminado  = FALSE
        GROUP BY c.id, c.nombre, pr.id, pr.nombre
    ),
    ranking AS (
        SELECT v.*,
               RANK() OVER (PARTITION BY v.categoria_id
                            ORDER BY v.unidades DESC, v.producto_id) AS pos
        FROM ventas v
    )
    SELECT r.categoria, r.pos, r.producto_id, r.producto, r.unidades
    FROM ranking r
    WHERE r.pos <= p_top
    ORDER BY r.categoria, r.pos;
END;
$$;


-- =============================================================================
-- PROCEDIMIENTOS ALMACENADOS (se invocan con CALL)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- sp_crear_pedido
--   Crea un pedido PENDIENTE con todos sus renglones en UNA sola operacion
--   atomica: valida el cliente, bloquea y valida cada producto, descuenta el
--   stock, inserta el detalle con el precio vigente (snapshot) y calcula total.
--
--   p_items: JSONB array, ej.  [{"producto_id": 1, "cantidad": 2},
--                               {"producto_id": 7, "cantidad": 1}]
--            Un mismo producto repetido se acumula en un unico renglon
--            (respeta UNIQUE (pedido_id, producto_id)).
--   p_pedido_id: INOUT, devuelve el id generado.
--
--   Errores (todos revierten el CALL completo):
--     - cliente inexistente o con baja logica
--     - items vacio / mal formado / cantidad <= 0
--     - producto inexistente, con baja logica o no disponible
--     - stock insuficiente
-- -----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_crear_pedido(
    IN    p_cliente_id BIGINT,
    IN    p_forma_pago forma_pago,
    IN    p_items      JSONB,
    INOUT p_pedido_id  BIGINT DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_item     RECORD;
    v_producto productos%ROWTYPE;
    v_total    NUMERIC(12,2) := 0;
BEGIN
    -- 1) Validaciones de entrada
    IF p_items IS NULL
       OR jsonb_typeof(p_items) <> 'array'
       OR jsonb_array_length(p_items) = 0 THEN
        RAISE EXCEPTION 'p_items debe ser un array JSON no vacio de {producto_id, cantidad}';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM clientes
                   WHERE id = p_cliente_id AND eliminado = FALSE) THEN
        RAISE EXCEPTION 'Cliente % inexistente o dado de baja', p_cliente_id;
    END IF;

    -- 2) Cabecera del pedido (estado PENDIENTE y total 0 por DEFAULT)
    INSERT INTO pedidos (cliente_id, forma_pago)
    VALUES (p_cliente_id, p_forma_pago)
    RETURNING id INTO p_pedido_id;

    -- 3) Renglones: agrupados por producto y ordenados por id (evita deadlocks)
    FOR v_item IN
        SELECT (e ->> 'producto_id')::BIGINT AS producto_id,
               SUM((e ->> 'cantidad')::INTEGER) AS cantidad
        FROM jsonb_array_elements(p_items) AS e
        GROUP BY (e ->> 'producto_id')::BIGINT
        ORDER BY 1
    LOOP
        IF v_item.producto_id IS NULL OR v_item.cantidad IS NULL OR v_item.cantidad <= 0 THEN
            RAISE EXCEPTION 'Renglon invalido (producto_id=%, cantidad=%): cantidad debe ser > 0',
                            v_item.producto_id, v_item.cantidad;
        END IF;

        -- Bloqueo pesimista de la fila del producto hasta el fin de la transaccion
        SELECT * INTO v_producto
        FROM productos
        WHERE id = v_item.producto_id AND eliminado = FALSE
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Producto % inexistente o dado de baja', v_item.producto_id;
        END IF;
        IF NOT v_producto.disponible THEN
            RAISE EXCEPTION 'Producto % (%) no esta disponible', v_producto.id, v_producto.nombre;
        END IF;
        IF v_producto.stock < v_item.cantidad THEN
            RAISE EXCEPTION 'Stock insuficiente para % (%): pedido %, disponible %',
                            v_producto.id, v_producto.nombre, v_item.cantidad, v_producto.stock;
        END IF;

        UPDATE productos
        SET stock = stock - v_item.cantidad,
            updated_at = CURRENT_TIMESTAMP
        WHERE id = v_producto.id;

        INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, precio_unitario, subtotal)
        VALUES (p_pedido_id, v_producto.id, v_item.cantidad, v_producto.precio,
                v_item.cantidad * v_producto.precio);

        v_total := v_total + v_item.cantidad * v_producto.precio;
    END LOOP;

    -- 4) Total derivado (queda coherente con la suma de subtotales)
    UPDATE pedidos
    SET total = v_total,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = p_pedido_id;
END;
$$;


-- -----------------------------------------------------------------------------
-- sp_cambiar_estado_pedido
--   Cambia el estado de un pedido vigente. La validez de la transicion la
--   garantiza el trigger trg_pedidos_transicion_estado (script 02): este
--   procedimiento no la duplica. Si el nuevo estado es CANCELADO devuelve el
--   stock reservado, todo en la misma transaccion.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_cambiar_estado_pedido(
    IN p_pedido_id    BIGINT,
    IN p_nuevo_estado estado_pedido
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_estado_actual estado_pedido;
BEGIN
    -- Bloqueo de la fila: dos cambios de estado simultaneos se serializan
    SELECT estado INTO v_estado_actual
    FROM pedidos
    WHERE id = p_pedido_id AND eliminado = FALSE
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Pedido % inexistente o eliminado', p_pedido_id;
    END IF;

    -- El trigger BEFORE UPDATE OF estado aborta si la transicion es invalida
    UPDATE pedidos
    SET estado = p_nuevo_estado,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = p_pedido_id;

    -- Cancelacion efectiva: se repone el stock reservado
    IF p_nuevo_estado = 'CANCELADO' AND v_estado_actual <> 'CANCELADO' THEN
        UPDATE productos pr
        SET stock = pr.stock + dp.cantidad,
            updated_at = CURRENT_TIMESTAMP
        FROM detalle_pedido dp
        WHERE dp.pedido_id = p_pedido_id
          AND pr.id = dp.producto_id;
    END IF;
END;
$$;


-- -----------------------------------------------------------------------------
-- sp_baja_logica_producto
--   Borrado logico (soft delete): eliminado = TRUE, deleted_at = now() y deja
--   de estar disponible. NO borra la fila: el historial de detalle_pedido
--   conserva el producto vendido (FK ON DELETE RESTRICT).
-- -----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_baja_logica_producto(IN p_producto_id BIGINT)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE productos
    SET eliminado  = TRUE,
        deleted_at = CURRENT_TIMESTAMP,
        disponible = FALSE,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = p_producto_id AND eliminado = FALSE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Producto % inexistente o ya dado de baja', p_producto_id;
    END IF;
END;
$$;


-- -----------------------------------------------------------------------------
-- sp_baja_logica_cliente
--   Borrado logico de un cliente. Si tiene pedidos PENDIENTE/CONFIRMADO el
--   trigger trg_clientes_baja_logica (script 02) rechaza la operacion.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_baja_logica_cliente(IN p_cliente_id BIGINT)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE clientes
    SET eliminado  = TRUE,
        deleted_at = CURRENT_TIMESTAMP,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = p_cliente_id AND eliminado = FALSE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Cliente % inexistente o ya dado de baja', p_cliente_id;
    END IF;
END;
$$;


-- -----------------------------------------------------------------------------
-- sp_refrescar_facturacion_categoria_mes
--   Refresca la vista materializada del script 07 sin bloquear lecturas
--   (REFRESH ... CONCURRENTLY exige el indice UNIQUE uix_mv_facturacion_categoria_mes).
--   Politica de frecuencia: docs/informes/politica_refresh.md
-- -----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_refrescar_facturacion_categoria_mes()
LANGUAGE plpgsql
AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_facturacion_categoria_mes;
END;
$$;
