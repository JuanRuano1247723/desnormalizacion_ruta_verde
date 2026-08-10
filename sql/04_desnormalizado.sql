-- =========================================================
-- Desnormalizacion - Ruta Verde
-- Construye las 2 estructuras que resuelven los 5 problemas
-- observados en las queries 1-5 sobre el modelo normalizado.
-- =========================================================

\timing on

-- ---------------------------------------------------------
-- Estructura 1: tabla ancha
-- Resuelve:
--   - Query 1 (pre-join): aplana pedido->restaurante->zona->
--     municipio->departamento en una sola fila, sin joins.
--   - Query 2 (columna derivada): precalcula el mes y el flag
--     de cancelado, para no repetir ese calculo en cada consulta.
-- ---------------------------------------------------------
DROP TABLE IF EXISTS pedido_plano;

CREATE TABLE pedido_plano AS
SELECT
    p.pedido_id,
    p.fecha,
    date_trunc('month', p.fecha)::date AS mes,
    p.total,
    p.estado,
    (p.estado = 'cancelado')             AS es_cancelado,
    c.cliente_id,
    c.segmento,
    r.restaurante_id,
    r.nombre          AS restaurante_nombre,
    z.zona_id,
    z.nombre          AS zona_nombre,
    m.municipio_id,
    m.nombre          AS municipio_nombre,
    d.departamento_id,
    d.nombre          AS departamento_nombre
FROM pedido p
JOIN cliente c      ON c.cliente_id = p.cliente_id
JOIN restaurante r  ON r.restaurante_id = p.restaurante_id
JOIN zona z         ON z.zona_id = r.zona_id
JOIN municipio m    ON m.municipio_id = z.municipio_id
JOIN departamento d ON d.departamento_id = m.departamento_id;

-- Sin PK/indices todavia a proposito: primero se mide el
-- espacio "crudo" de la tabla ancha (ver 03 del reporte de
-- espacio). Los indices se agregan despues, en el bloque
-- de "uso real", para que el trade-off de espacio quede
-- separado del trade-off de velocidad de consulta.
ALTER TABLE pedido_plano ADD PRIMARY KEY (pedido_id);
CREATE INDEX idx_plano_depto ON pedido_plano(departamento_nombre);
CREATE INDEX idx_plano_zona_mes ON pedido_plano(zona_nombre, mes);
CREATE INDEX idx_plano_segmento ON pedido_plano(segmento);

-- ---------------------------------------------------------
-- Estructura 2: tablas agregadas
-- Resuelve:
--   - Query 3 (tabla agregada): ventas mensuales por zona,
--     ya no hay que recorrer 3M filas de pedido cada vez.
--   - Query 4 (misma tecnica, GROUP BY simple): top
--     restaurantes por ventas.
-- ---------------------------------------------------------
DROP TABLE IF EXISTS resumen_ventas_zona_mes;
DROP TABLE IF EXISTS resumen_ventas_restaurante;

CREATE TABLE resumen_ventas_zona_mes AS
SELECT
    zona_nombre,
    mes,
    count(*)     AS pedidos,
    sum(total)   AS ventas
FROM pedido_plano
GROUP BY zona_nombre, mes;

ALTER TABLE resumen_ventas_zona_mes ADD PRIMARY KEY (zona_nombre, mes);

CREATE TABLE resumen_ventas_restaurante AS
SELECT
    restaurante_nombre,
    count(*)     AS pedidos,
    sum(total)   AS ventas
FROM pedido_plano
GROUP BY restaurante_nombre;

ALTER TABLE resumen_ventas_restaurante ADD PRIMARY KEY (restaurante_nombre);

ANALYZE pedido_plano;
ANALYZE resumen_ventas_zona_mes;
ANALYZE resumen_ventas_restaurante;

-- Verificacion rapida
SELECT 'pedido_plano' AS tabla, count(*) FROM pedido_plano
UNION ALL SELECT 'resumen_ventas_zona_mes', count(*) FROM resumen_ventas_zona_mes
UNION ALL SELECT 'resumen_ventas_restaurante', count(*) FROM resumen_ventas_restaurante;
