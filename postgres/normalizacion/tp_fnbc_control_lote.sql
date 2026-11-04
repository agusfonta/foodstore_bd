-- =========================================================
-- Creacion de tablas
-- =========================================================
CREATE TABLE IF NOT EXISTS lote (
    id BIGINT PRIMARY KEY
);

CREATE TABLE IF NOT EXISTS deposito (
    id BIGINT PRIMARY KEY
);


CREATE TABLE responsable_deposito (
    responsable_control_id BIGINT NOT NULL
    REFERENCES clientes(id),
    deposito_id BIGINT NOT NULL
    REFERENCES deposito(id),
    PRIMARY KEY (responsable_control_id)
);


CREATE TABLE control_lote (
    lote_id BIGINT NOT NULL
    REFERENCES lote(id),
    responsable_control_id BIGINT NOT NULL
    REFERENCES responsable_deposito(responsable_control_id),
    PRIMARY KEY (lote_id, responsable_control_id)
);
-- =========================================================
-- Vista de compatibilidad
-- =========================================================
CREATE OR REPLACE VIEW v_control_lote_almacen AS
SELECT
cl.lote_id,
rd.deposito_id,
cl.responsable_control_id
FROM control_lote cl
JOIN responsable_deposito rd
ON cl.responsable_control_id = rd.responsable_control_id;