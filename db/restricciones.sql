-- =========================================================
-- FOODSTORE - Restricciones de Integridad (Parte 1 TP2)
-- =========================================================
-- Regla 1: Coherencia subtotal en detalle_pedido
-- Regla 2: Transiciones de estado en pedidos
-- Regla 3: Baja lógica de clientes con pedidos activos
-- =========================================================
-- EJECUCIÓN ÚNICA: Este script crea objetos nuevos.
-- No es idempotente para triggers/funciones (usar DROP si re-ejecutar).
-- =========================================================


-- =========================================================
-- REGLA 1: Coherencia del subtotal (CHECK declarativo)
-- =========================================================
-- Tabla: detalle_pedido
-- Columnas: cantidad (INTEGER), precio_unitario (NUMERIC(10,2)), subtotal (NUMERIC(12,2))
-- Restricción existente relacionada: chk_detalle_subtotal (subtotal >= 0)
-- Nueva restricción: subtotal = cantidad * precio_unitario
-- =========================================================

ALTER TABLE detalle_pedido
ADD CONSTRAINT chk_detalle_subtotal_coherente
CHECK (subtotal = cantidad * precio_unitario);


-- =========================================================
-- REGLA 2: Transiciones de estado válidas en pedidos
-- =========================================================
-- Tabla: pedidos
-- Columna: estado (tipo estado_pedido ENUM)
-- Valores ENUM: 'PENDIENTE', 'CONFIRMADO', 'TERMINADO', 'CANCELADO'
-- Transiciones permitidas:
--   PENDIENTE → CONFIRMADO, CANCELADO
--   CONFIRMADO → TERMINADO, CANCELADO
--   TERMINADO, CANCELADO → no cambian (estados finales)
-- =========================================================

CREATE OR REPLACE FUNCTION fn_check_transicion_estado()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    -- Si no hay cambio real de estado, permitir
    IF OLD.estado = NEW.estado THEN
        RETURN NEW;
    END IF;

    -- PENDIENTE puede ir a CONFIRMADO o CANCELADO
    IF OLD.estado = 'PENDIENTE' AND NEW.estado IN ('CONFIRMADO', 'CANCELADO') THEN
        RETURN NEW;
    END IF;

    -- CONFIRMADO puede ir a TERMINADO o CANCELADO
    IF OLD.estado = 'CONFIRMADO' AND NEW.estado IN ('TERMINADO', 'CANCELADO') THEN
        RETURN NEW;
    END IF;

    -- TERMINADO y CANCELADO son estados finales: no permiten cambio
    IF OLD.estado IN ('TERMINADO', 'CANCELADO') THEN
        RAISE EXCEPTION 'Estado % es final y no puede modificarse', OLD.estado;
    END IF;

    -- Cualquier otra transición no listada es inválida
    RAISE EXCEPTION 'Transición de estado inválida: % → %', OLD.estado, NEW.estado;
END;
$$;

CREATE TRIGGER trg_pedidos_transicion_estado
BEFORE UPDATE OF estado ON pedidos
FOR EACH ROW EXECUTE FUNCTION fn_check_transicion_estado();


-- =========================================================
-- REGLA 3: Bloqueo de baja lógica de clientes con pedidos activos
-- =========================================================
-- Tabla principal: clientes
-- Columna: eliminado (BOOLEAN DEFAULT FALSE)
-- Tabla relacionada: pedidos (FK cliente_id → clientes.id)
-- Regla: No permitir UPDATE clientes SET eliminado = TRUE
--        si existe pedidos con ese cliente_id y estado IN ('PENDIENTE', 'CONFIRMADO')
-- =========================================================

CREATE OR REPLACE FUNCTION fn_check_baja_cliente_con_pedidos_activos()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    -- Solo actuar cuando se intenta cambiar de FALSE a TRUE
    IF OLD.eliminado = FALSE AND NEW.eliminado = TRUE THEN
        IF EXISTS (
            SELECT 1
            FROM pedidos
            WHERE cliente_id = OLD.id
              AND estado IN ('PENDIENTE', 'CONFIRMADO')
        ) THEN
            RAISE EXCEPTION 'No se puede dar de baja al cliente %: tiene pedidos en estado PENDIENTE o CONFIRMADO', OLD.id;
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_clientes_baja_logica
BEFORE UPDATE OF eliminado ON clientes
FOR EACH ROW EXECUTE FUNCTION fn_check_baja_cliente_con_pedidos_activos();


-- =========================================================
-- FIN IMPLEMENTACIÓN
-- =========================================================