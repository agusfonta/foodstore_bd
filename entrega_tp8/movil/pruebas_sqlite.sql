-- ============================================
-- PRUEBAS SQLITE - TP8 (consigna 1.c)
-- ============================================
-- Requisito: schema_sqlite.sql y carga_snapshot.sql ya ejecutados
-- (producto_cache tiene los productos de la instantánea).
-- Uso: sqlite3 foodstore_movil.db ".read pruebas_sqlite.sql"
-- Todo con datos inventados.
-- ============================================

PRAGMA foreign_keys = ON;
PRAGMA foreign_keys;   -- esperado: 1

-- ============================================
-- 1. Borrador completo (borrador + ítems + solicitud) con COMMIT
-- ============================================
BEGIN;
INSERT INTO pedido_borrador (id_local, usuario, forma_pago)
VALUES ('550e8400-e29b-41d4-a716-446655440000', 'vendedor01', 'EFECTIVO');

INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('550e8400-e29b-41d4-a716-446655440000', 1, 3, 12063),  -- 3 unidades del producto 1
       ('550e8400-e29b-41d4-a716-446655440000', 3, 2, 3066);   -- 2 unidades del producto 3

INSERT INTO cola_sync (solicitud_uuid, id_local, estado)
VALUES ('f47ac10b-58cc-4372-a567-0e02b2c3d479', '550e8400-e29b-41d4-a716-446655440000', 'PENDIENTE');
COMMIT;

SELECT 'COMMIT: borradores, ítems, solicitudes' AS prueba,
       (SELECT COUNT(*) FROM pedido_borrador) AS borradores,
       (SELECT COUNT(*) FROM item_borrador)   AS items,
       (SELECT COUNT(*) FROM cola_sync)       AS solicitudes;
-- esperado: 1 | 2 | 1

-- ============================================
-- 1 (bis). Otra operación deshecha con ROLLBACK
-- ============================================
BEGIN;
INSERT INTO pedido_borrador (id_local, usuario, forma_pago)
VALUES ('999e8400-e29b-41d4-a716-446655440099', 'vendedor02', 'TARJETA');
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('999e8400-e29b-41d4-a716-446655440099', 2, 5, 39583);
ROLLBACK;

SELECT 'ROLLBACK: nada quedó guardado' AS prueba,
       (SELECT COUNT(*) FROM pedido_borrador) AS borradores,
       (SELECT COUNT(*) FROM item_borrador)   AS items;
-- esperado: 1 | 2 (igual que antes del ROLLBACK)

-- ============================================
-- C1. Catálogo disponible sin conectarse al servidor
-- ============================================
SELECT id, nombre, precio_centavos / 100.0 AS precio_pesos, stock_visto
FROM producto_cache
WHERE disponible = 1 AND eliminado = 0
ORDER BY nombre;
-- esperado: los 10 productos del cache local

-- ============================================
-- C7. Cantidad en 0 y producto inexistente: error y ninguna fila nueva
-- ============================================
BEGIN;
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('550e8400-e29b-41d4-a716-446655440000', 5, 0, 49871);
-- esperado: Runtime error: CHECK constraint failed: cantidad > 0
ROLLBACK;

BEGIN;
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('550e8400-e29b-41d4-a716-446655440000', 999, 2, 12063);
-- esperado: Runtime error: FOREIGN KEY constraint failed
ROLLBACK;

SELECT 'C7: filas nuevas tras los dos errores' AS prueba,
       (SELECT COUNT(*) FROM item_borrador) AS items;
-- esperado: 2 (sin cambios)

-- ============================================
-- Extra: UUID válido e índice único parcial de cola_sync
-- ============================================
BEGIN;
INSERT INTO pedido_borrador (id_local, usuario, forma_pago)
VALUES ('c2-borrador', 'vendedor01', 'EFECTIVO');
-- esperado: Runtime error: CHECK constraint failed (no es un UUID v4)
ROLLBACK;

BEGIN;
INSERT INTO cola_sync (solicitud_uuid, id_local, estado)
VALUES ('0b9b6c1e-2f6d-4a8e-9c53-7d1f4e2a9b10', '550e8400-e29b-41d4-a716-446655440000', 'PENDIENTE');
-- esperado: Runtime error: UNIQUE constraint failed: cola_sync.id_local
--           (el borrador ya tiene una solicitud PENDIENTE)
ROLLBACK;

SELECT 'Extra: solicitudes tras los dos errores' AS prueba,
       (SELECT COUNT(*) FROM pedido_borrador) AS borradores,
       (SELECT COUNT(*) FROM cola_sync)       AS solicitudes,
       (SELECT COUNT(*) FROM evaluacion_sync) AS evaluaciones;
-- esperado: 1 | 1 | 0 (nada cambió; todavía no se corrió el semáforo)

PRAGMA foreign_key_check;   -- esperado: sin filas
