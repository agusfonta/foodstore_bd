-- ============================================
-- SCHEMA SQLITE - FOOD STORE MÓVIL
-- TP8 - Unidad 8 - Base de Datos II
-- Food truck en feria sin señal
-- ============================================
-- Equipo: Agustina Fontagnol, Gianella Peña, Martina Suarez
-- Fecha: 2026-11-03
-- Base: SQLite 3.37+ (tablas STRICT)
-- Uso: sqlite3 foodstore_movil.db ".read schema_sqlite.sql"
-- Regla de oro: El móvil propone, el servidor dispone
-- ============================================

-- Activar claves foráneas (crítico en SQLite)
PRAGMA foreign_keys = ON;

-- ============================================
-- TABLA 1: producto_cache
-- Cache local de productos del servidor
-- Fuente de verdad: PostgreSQL
-- ============================================
CREATE TABLE producto_cache (
    id INTEGER PRIMARY KEY,
    nombre TEXT NOT NULL,
    precio_centavos INTEGER NOT NULL CHECK(precio_centavos >= 0),
    stock_visto INTEGER NOT NULL,
    disponible INTEGER NOT NULL CHECK(disponible IN (0, 1)),
    eliminado INTEGER NOT NULL CHECK(eliminado IN (0, 1)),
    fecha_copia TEXT NOT NULL DEFAULT (datetime('now'))
) STRICT;

-- ============================================
-- TABLA 2: pedido_borrador
-- Borradores de pedidos armados offline
-- No son ventas hasta que el servidor los apruebe
-- ============================================
CREATE TABLE pedido_borrador (
    id_local TEXT PRIMARY KEY
        CHECK(id_local GLOB '[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]-[0-9a-f][0-9a-f][0-9a-f][0-9a-f]-4[0-9a-f][0-9a-f][0-9a-f]-[89ab][0-9a-f][0-9a-f][0-9a-f]-[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]'),  -- UUID v4 (minúsculas) generado en la tablet
    usuario TEXT NOT NULL,
    forma_pago TEXT NOT NULL CHECK(forma_pago IN ('EFECTIVO', 'TARJETA', 'TRANSFERENCIA')),
    fecha TEXT NOT NULL DEFAULT (datetime('now'))
) STRICT;

-- ============================================
-- TABLA 3: item_borrador
-- Items (líneas) de cada borrador de pedido
-- Guarda el precio "visto" para detectar cambios
-- ============================================
CREATE TABLE item_borrador (
    id_local TEXT NOT NULL,  -- UUID del pedido_borrador
    producto_id INTEGER NOT NULL,
    cantidad INTEGER NOT NULL CHECK(cantidad > 0),
    precio_centavos_visto INTEGER NOT NULL,
    PRIMARY KEY (id_local, producto_id),
    FOREIGN KEY (id_local) REFERENCES pedido_borrador(id_local) ON DELETE CASCADE,
    FOREIGN KEY (producto_id) REFERENCES producto_cache(id) ON DELETE RESTRICT
) STRICT;

-- ============================================
-- TABLA 4: cola_sync
-- Cola de sincronización: solicitudes pendientes
-- y resultados del semáforo del servidor
-- ============================================
CREATE TABLE cola_sync (
    solicitud_uuid TEXT PRIMARY KEY
        CHECK(solicitud_uuid GLOB '[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]-[0-9a-f][0-9a-f][0-9a-f][0-9a-f]-4[0-9a-f][0-9a-f][0-9a-f]-[89ab][0-9a-f][0-9a-f][0-9a-f]-[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]'),  -- UUID v4 único de la solicitud (clave de idempotencia)
    id_local TEXT NOT NULL,  -- Referencia al borrador
    estado TEXT NOT NULL CHECK(estado IN ('PENDIENTE', 'CONFLICTO', 'RECHAZADO', 'SIMULADO_APROBADO')),
    motivo TEXT,  -- Razón del rechazo o conflicto
    fecha_creacion TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (id_local) REFERENCES pedido_borrador(id_local) ON DELETE CASCADE
) STRICT;

-- ============================================
-- TABLA 5: snapshot_servidor
-- Última instantánea importada del servidor (v_snapshot_movil).
-- El semáforo compara contra esta tabla; carga_snapshot.sql la reemplaza.
-- ============================================
CREATE TABLE snapshot_servidor (
    id INTEGER PRIMARY KEY,
    nombre TEXT NOT NULL,
    precio_centavos INTEGER NOT NULL,
    stock_visto INTEGER NOT NULL,
    disponible INTEGER NOT NULL,
    eliminado INTEGER NOT NULL,
    fecha_copia TEXT NOT NULL
);

-- ============================================
-- TABLA 6: evaluacion_sync
-- Registro de evaluaciones: una fila por cada vez que el semáforo resuelve
-- una solicitud (qué dijo, por qué y con qué instantánea). Solo se agrega,
-- nunca se modifica: cola_sync guarda el estado actual y esta tabla la historia.
-- ============================================
CREATE TABLE evaluacion_sync (
    id INTEGER PRIMARY KEY,
    solicitud_uuid TEXT NOT NULL,
    estado TEXT NOT NULL CHECK(estado IN ('CONFLICTO', 'RECHAZADO', 'SIMULADO_APROBADO')),
    motivo TEXT,
    fecha_instantanea TEXT,  -- fecha_copia de la instantánea usada
    fecha_evaluacion TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (solicitud_uuid) REFERENCES cola_sync(solicitud_uuid) ON DELETE CASCADE
) STRICT;

-- Se completa sola cuando una solicitud sale de PENDIENTE (lo hace semaforo.sql).
CREATE TRIGGER trg_cola_sync_registra_evaluacion
AFTER UPDATE OF estado ON cola_sync
WHEN OLD.estado = 'PENDIENTE' AND NEW.estado <> 'PENDIENTE'
BEGIN
    INSERT INTO evaluacion_sync (solicitud_uuid, estado, motivo, fecha_instantanea)
    VALUES (NEW.solicitud_uuid, NEW.estado, NEW.motivo, (SELECT MAX(fecha_copia) FROM snapshot_servidor));
END;

-- ============================================
-- ÍNDICES PARA CONSULTAS FRECUENTES
-- ============================================

-- Índice para consulta del catálogo disponible (Caso C1)
CREATE INDEX idx_producto_cache_disponible 
ON producto_cache(disponible, eliminado) 
WHERE disponible = 1 AND eliminado = 0;

-- Índice para buscar solicitudes pendientes
CREATE INDEX idx_cola_sync_estado 
ON cola_sync(estado) 
WHERE estado = 'PENDIENTE';

-- Índice ÚNICO parcial: un borrador no puede tener dos solicitudes PENDIENTE a la vez
-- (evita encolar dos veces lo mismo). Una solicitud nueva sobre el mismo borrador solo
-- se admite cuando la anterior ya se resolvió (caso C2: CONFLICTO y luego otra solicitud).
CREATE UNIQUE INDEX ux_cola_sync_una_pendiente
ON cola_sync(id_local)
WHERE estado = 'PENDIENTE';

-- Índice para el registro de evaluaciones por solicitud
CREATE INDEX idx_evaluacion_sync_solicitud
ON evaluacion_sync(solicitud_uuid, fecha_evaluacion);

-- Índice para relacionar items con borradores en el semáforo
CREATE INDEX idx_item_borrador_id_local 
ON item_borrador(id_local);

-- ============================================
-- VERIFICACIÓN DEL ESQUEMA
-- ============================================
-- Ejecutar estas consultas para verificar la creación:
-- SELECT name, type FROM sqlite_master WHERE type='table';
-- PRAGMA table_info(producto_cache);
-- PRAGMA foreign_key_check;
