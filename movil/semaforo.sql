-- ============================================
-- SEMÁFORO - TP8 (consigna 2.b)
-- ============================================
-- Compara cada solicitud PENDIENTE de cola_sync con snapshot_servidor y
-- guarda estado y motivo:
--   ROJO     RECHAZADO         algún producto no existe, no está disponible,
--                              fue dado de baja o no alcanza el stock
--   AMARILLO CONFLICTO         no hay rojo, pero cambió algún precio
--   VERDE    SIMULADO_APROBADO todo coincide (NO es una venta)
-- Solo se evalúan las PENDIENTE (repetir el script no cambia nada) y no se
-- toca PostgreSQL. Requisito: carga_snapshot.sql ya ejecutado.
-- Uso: sqlite3 foodstore_movil.db ".read semaforo.sql"
-- ============================================

UPDATE cola_sync
SET estado = (
        SELECT CASE
                 WHEN SUM(s.id IS NULL
                          OR s.disponible = 0
                          OR s.eliminado = 1
                          OR i.cantidad > s.stock_visto) > 0 THEN 'RECHAZADO'
                 WHEN SUM(i.precio_centavos_visto <> s.precio_centavos) > 0 THEN 'CONFLICTO'
                 ELSE 'SIMULADO_APROBADO'
               END
        FROM item_borrador i
        LEFT JOIN snapshot_servidor s ON s.id = i.producto_id
        WHERE i.id_local = cola_sync.id_local
    ),
    motivo = (
        SELECT GROUP_CONCAT(
                 CASE
                   WHEN s.id IS NULL THEN
                     'Producto ' || i.producto_id || ' no existe'
                   WHEN s.eliminado = 1 THEN
                     'Producto ' || i.producto_id || ' dado de baja'
                   WHEN s.disponible = 0 THEN
                     'Producto ' || i.producto_id || ' no disponible'
                   WHEN i.cantidad > s.stock_visto THEN
                     'Stock insuficiente en producto ' || i.producto_id
                     || ': pedido=' || i.cantidad || ', stock=' || s.stock_visto
                   WHEN i.precio_centavos_visto <> s.precio_centavos THEN
                     'Precio cambió en producto ' || i.producto_id
                     || ': visto=' || i.precio_centavos_visto
                     || ', actual=' || s.precio_centavos
                 END, ' | ')
        FROM item_borrador i
        LEFT JOIN snapshot_servidor s ON s.id = i.producto_id
        WHERE i.id_local = cola_sync.id_local
    )
WHERE estado = 'PENDIENTE';

SELECT solicitud_uuid, estado, motivo FROM cola_sync ORDER BY fecha_creacion, solicitud_uuid;
