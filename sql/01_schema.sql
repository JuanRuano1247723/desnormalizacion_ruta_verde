-- =========================================================
-- Esquema NORMALIZADO (3FN) - Ruta Verde
-- Coincide exactamente con las columnas de generar_datos.py
-- =========================================================

DROP TABLE IF EXISTS pedido, cliente, restaurante, zona, municipio, departamento CASCADE;

CREATE TABLE departamento (
    departamento_id  INTEGER PRIMARY KEY,
    nombre            VARCHAR(50) NOT NULL
);

CREATE TABLE municipio (
    municipio_id      INTEGER PRIMARY KEY,
    nombre            VARCHAR(50) NOT NULL,
    departamento_id   INTEGER NOT NULL REFERENCES departamento(departamento_id)
);

CREATE TABLE zona (
    zona_id           INTEGER PRIMARY KEY,
    nombre            VARCHAR(50) NOT NULL,
    municipio_id      INTEGER NOT NULL REFERENCES municipio(municipio_id)
);

CREATE TABLE restaurante (
    restaurante_id    INTEGER PRIMARY KEY,
    nombre            VARCHAR(50) NOT NULL,
    zona_id           INTEGER NOT NULL REFERENCES zona(zona_id)
);

CREATE TABLE cliente (
    cliente_id        INTEGER PRIMARY KEY,
    nombre            VARCHAR(50) NOT NULL,
    segmento          VARCHAR(20) NOT NULL,
    telefono          VARCHAR(15) NOT NULL
);

CREATE TABLE pedido (
    pedido_id         BIGINT PRIMARY KEY,
    cliente_id        INTEGER NOT NULL REFERENCES cliente(cliente_id),
    restaurante_id    INTEGER NOT NULL REFERENCES restaurante(restaurante_id),
    fecha             DATE NOT NULL,
    total             NUMERIC(10,2) NOT NULL,
    estado            VARCHAR(20) NOT NULL
);

-- Indices sobre las FK de la tabla grande: Postgres NO los crea
-- automaticamente (solo indexa la PK), y sin ellos cualquier
-- join contra pedido hace seq scan completo.
CREATE INDEX idx_pedido_cliente     ON pedido(cliente_id);
CREATE INDEX idx_pedido_restaurante ON pedido(restaurante_id);
CREATE INDEX idx_pedido_fecha       ON pedido(fecha);
CREATE INDEX idx_restaurante_zona   ON restaurante(zona_id);
CREATE INDEX idx_zona_municipio     ON zona(municipio_id);
CREATE INDEX idx_municipio_depto    ON municipio(departamento_id);
