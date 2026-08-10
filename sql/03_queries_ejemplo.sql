-- =========================================================
-- Queries y vistas de ejemplo sobre el modelo NORMALIZADO
-- Usalas como punto de partida para medir tiempos con
-- EXPLAIN ANALYZE antes de comparar contra tu version
-- desnormalizada.
-- =========================================================

\timing on

-- 1) Vista: ventas totales por departamento (requiere 4 joins
--    porque el dato viaja pedido -> restaurante -> zona ->
--    municipio -> departamento)
CREATE OR REPLACE VIEW v_ventas_por_departamento AS
SELECT
    d.nombre            AS departamento,
    count(*)            AS total_pedidos,
    sum(p.total)        AS ventas_totales,
    round(avg(p.total), 2) AS ticket_promedio
FROM pedido p
JOIN restaurante r ON r.restaurante_id = p.restaurante_id
JOIN zona z         ON z.zona_id = r.zona_id
JOIN municipio m    ON m.municipio_id = z.municipio_id
JOIN departamento d ON d.departamento_id = m.departamento_id
GROUP BY d.nombre
ORDER BY ventas_totales DESC;

SELECT * FROM v_ventas_por_departamento;

-- 2) Vista: comportamiento por segmento de cliente
CREATE OR REPLACE VIEW v_estadisticas_por_segmento AS
SELECT
    c.segmento,
    count(*)                                   AS total_pedidos,
    round(avg(p.total), 2)                     AS ticket_promedio,
    round(100.0 * sum(CASE WHEN p.estado = 'cancelado' THEN 1 ELSE 0 END) / count(*), 2) AS pct_cancelados
FROM pedido p
JOIN cliente c ON c.cliente_id = p.cliente_id
GROUP BY c.segmento
ORDER BY total_pedidos DESC;

SELECT * FROM v_estadisticas_por_segmento;

-- 3) Query mas "pesada": ventas mensuales por zona (agrupa por
--    fecha truncada y hace el mismo recorrido de 4 tablas)
--    Usa EXPLAIN ANALYZE para ver el plan real y el tiempo.
EXPLAIN ANALYZE
SELECT
    z.nombre                       AS zona,
    date_trunc('month', p.fecha)   AS mes,
    count(*)                       AS pedidos,
    sum(p.total)                   AS ventas
FROM pedido p
JOIN restaurante r ON r.restaurante_id = p.restaurante_id
JOIN zona z         ON z.zona_id = r.zona_id
GROUP BY z.nombre, date_trunc('month', p.fecha)
ORDER BY mes, ventas DESC;

-- 4) Top 10 restaurantes por ventas (join simple, buen
--    contraste contra la query de 4 tablas de arriba)
EXPLAIN ANALYZE
SELECT
    r.nombre AS restaurante,
    count(*) AS pedidos,
    sum(p.total) AS ventas
FROM pedido p
JOIN restaurante r ON r.restaurante_id = p.restaurante_id
GROUP BY r.nombre
ORDER BY ventas DESC
LIMIT 10;

-- 5) Tamano de cada tabla e indices, util para el reporte de
--    espacio (parte del trade-off que van a comparar)
SELECT
    relname                                   AS tabla,
    pg_size_pretty(pg_total_relation_size(relid)) AS tamano_total,
    pg_size_pretty(pg_relation_size(relid))       AS tamano_tabla,
    pg_size_pretty(pg_indexes_size(relid))        AS tamano_indices
FROM pg_catalog.pg_statio_user_tables
ORDER BY pg_total_relation_size(relid) DESC;
