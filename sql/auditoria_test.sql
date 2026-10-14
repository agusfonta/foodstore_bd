-- =============================================================================
-- FOODSTORE — Secuencia de prueba de auditoría
-- TP Unidad 5 — Parte B
-- Motor: PostgreSQL 16+
-- =============================================================================
-- PROPÓSITO: generar en el log de PostgreSQL un conjunto de eventos
-- representativos para demostrar que los parámetros de auditoría configurados
-- en postgresql.conf capturan correctamente las operaciones relevantes.
--
-- PREREQUISITOS:
--   1. postgresql.conf ya debe tener activados:
--        log_connections    = on
--        log_disconnections = on
--        log_statement      = 'mod'   (o 'all' para mayor granularidad)
--        log_failed_auth    = on       (disponible en PG 14+)
--   2. Ejecutar conectado como app_web o como el rol que se quiera auditar.
--   3. El intento de login fallido se ejecuta desde psql o pg_isready,
--      no desde este script (ver instrucciones al final).
--
-- PROTOCOLO DE SEGURIDAD: ejecutar sobre foodstore_desarrollo, no sobre la
-- base original. Ver protocolo_seguridad.md.
-- =============================================================================

-- =============================================================================
-- PASO 1 — LECTURA (SELECT)
-- Genera una entrada de tipo "statement" en el log si log_statement = 'all'
-- o 'ddl'. Con log_statement = 'mod' no aparece (solo aparecen modificaciones).
-- Se incluye para tener evidencia de qué queda fuera del alcance de 'mod'.
-- =============================================================================
SELECT
    producto_id,
    producto_nombre,
    precio,
    stock
FROM v_productos_vigentes_con_categoria
LIMIT 5;


-- =============================================================================
-- PASO 2 — INSERCIÓN (INSERT)
-- Con log_statement = 'mod' o 'all' esta operación aparece en el log.
-- Se usa un cliente y producto de prueba para no afectar datos reales.
-- =============================================================================
BEGIN;

-- Insertar un pedido de prueba (requiere un cliente existente; ajustar el id)
-- NOTA: reemplazar <id_cliente_existente> por un id real de la tabla clientes.
INSERT INTO pedidos (estado, total, forma_pago, cliente_id)
VALUES ('PENDIENTE', 0.00, 'EFECTIVO', (SELECT id FROM clientes WHERE eliminado = FALSE LIMIT 1));

-- Capturar el id generado para los pasos siguientes
-- (en psql se puede usar \gset o una variable; aquí se deja el subselect)
-- =============================================================================
-- PASO 3 — ACTUALIZACIÓN (UPDATE)
-- Cambio de estado del pedido recién creado: también aparece en el log con 'mod'.
-- =============================================================================
UPDATE pedidos
SET estado     = 'CONFIRMADO',
    updated_at = CURRENT_TIMESTAMP
WHERE id = (SELECT MAX(id) FROM pedidos WHERE cliente_id = (SELECT id FROM clientes WHERE eliminado = FALSE LIMIT 1));

-- Rollback para no dejar datos de prueba en la base
ROLLBACK;


-- =============================================================================
-- PASO 4 — INTENTO DE LOGIN FALLIDO
-- Este paso NO se puede ejecutar desde dentro de una sesión ya establecida.
-- Se debe ejecutar desde PowerShell o una segunda terminal de psql:
--
--   psql -U usuario_inexistente -d foodstore_desarrollo
--   (o bien: psql -U app_web -d foodstore_desarrollo con contraseña incorrecta)
--
-- El evento queda registrado en el log con nivel FATAL o LOG según la
-- configuración de log_failed_auth / log_connections.
--
-- Ejemplo de línea esperada en el log:
--   FATAL:  password authentication failed for user "usuario_inexistente"
--   DETAIL: Connection matched pg_hba.conf line ...
-- =============================================================================
-- (Sin código SQL aquí: ver instrucciones arriba)


-- =============================================================================
-- CONSULTA DE VERIFICACIÓN — qué quedó en el log
-- Verificar la ruta del log con:
--   SHOW log_directory;
--   SHOW log_filename;
-- En Windows el log suele estar en:
--   C:\Program Files\PostgreSQL\<version>\data\log\
-- =============================================================================
SHOW log_directory;
SHOW log_filename;
SHOW log_statement;
SHOW log_connections;
SHOW log_disconnections;
