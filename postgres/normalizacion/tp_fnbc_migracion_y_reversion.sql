-- =========================================================
-- U4 · Parte 1 — Esquema original, migración de la instancia y reversión
-- Complementa tp_fnbc_control_lote.sql (tablas descompuestas + vista).
-- Transcribe los pasos de migración del informe (docs/informes/informe_u4_fnbc_desnormalizacion.pdf, punto 4.2.f)
-- con el nombre real de la tabla de responsables del proyecto: clientes(id).
--
-- USO (solo sobre foodstore_desarrollo, nunca sobre foodstore):
--   1) psql -U postgres -d foodstore_desarrollo -f postgres/normalizacion/tp_fnbc_control_lote.sql
--   2) psql -U postgres -d foodstore_desarrollo -f postgres/normalizacion/tp_fnbc_migracion_y_reversion.sql
-- Todo corre dentro de una transacción que termina en ROLLBACK: se revisan los
-- resultados y, si son correctos, se cambia el ROLLBACK final por COMMIT.
-- ESTE ARCHIVO NO SE EJECUTÓ AL CREARSE: falta correrlo y adjuntar la salida.
-- =========================================================
BEGIN;

-- Maestras (el informe asume que existen)
INSERT INTO lote (id)     VALUES (501), (502), (503)  ON CONFLICT DO NOTHING;
INSERT INTO deposito (id) VALUES (30), (31)           ON CONFLICT DO NOTHING;

-- Esquema original con la dependencia responsable_control_id -> deposito_id (viola FNBC)
CREATE TABLE control_lote_almacen (
    lote_id                BIGINT NOT NULL REFERENCES lote(id),
    deposito_id            BIGINT NOT NULL REFERENCES deposito(id),
    responsable_control_id BIGINT NOT NULL REFERENCES clientes(id),
    PRIMARY KEY (lote_id, deposito_id)
);

INSERT INTO control_lote_almacen VALUES
    (501, 30, 801),
    (502, 30, 801),
    (503, 31, 802);

-- Migración a las tablas descompuestas
INSERT INTO responsable_deposito (responsable_control_id, deposito_id)
SELECT DISTINCT responsable_control_id, deposito_id FROM control_lote_almacen;

INSERT INTO control_lote (lote_id, responsable_control_id)
SELECT lote_id, responsable_control_id FROM control_lote_almacen;

-- Verificación de equivalencia: ambos EXCEPT deben devolver 0 filas
SELECT 'original - vista' AS sentido, count(*) AS filas FROM (
    SELECT lote_id, deposito_id, responsable_control_id FROM control_lote_almacen
    EXCEPT
    SELECT lote_id, deposito_id, responsable_control_id FROM v_control_lote_almacen) a
UNION ALL
SELECT 'vista - original', count(*) FROM (
    SELECT lote_id, deposito_id, responsable_control_id FROM v_control_lote_almacen
    EXCEPT
    SELECT lote_id, deposito_id, responsable_control_id FROM control_lote_almacen) b;

SELECT * FROM v_control_lote_almacen ORDER BY lote_id;

-- ---------------------------------------------------------
-- Plan de reversión (descomponer es reversible sin pérdida):
-- la vista reconstruye la relación original, así que se puede volver con
--   DROP VIEW v_control_lote_almacen;
--   DROP TABLE control_lote, responsable_deposito;
-- conservando control_lote_almacen. Con ROLLBACK no queda nada de lo de arriba.
-- ---------------------------------------------------------
ROLLBACK;  -- cambiar por COMMIT solo si las dos filas de verificación dan 0
