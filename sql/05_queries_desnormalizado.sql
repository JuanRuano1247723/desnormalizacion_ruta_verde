-- =========================================================
-- Queries equivalentes a 03_queries_ejemplo.sql, pero corridas
-- sobre las estructuras desnormalizadas. Compara el tiempo y
-- el plan (EXPLAIN ANALYZE) linea por linea contra el original.
-- =========================================================

\timing on

-- Equivalente a Query 1 (ventas por departamento)
-- Original: 4 joins sobre pedido (3M filas)
-- Ahora: agregacion directa sobre pedido_plano, sin joins
EXPLAIN ANALYZE
SELECT
    departamento_nombre AS departamento,
    count(*)             AS total_pedidos,
    sum(total)            AS ventas_totales,
    round(avg(total), 2)  AS ticket_promedio
FROM pedido_plano
GROUP BY departamento_nombre
ORDER BY ventas_totales DESC;

-- Equivalente a Query 2 (estadisticas por segmento)
-- Original: join pedido-cliente + CASE calculado en cada corrida
-- Ahora: usa la columna derivada es_cancelado, sin join
EXPLAIN ANALYZE
SELECT
    segmento,
    count(*)                                             AS total_pedidos,
    round(avg(total), 2)                                 AS ticket_promedio,
    round(100.0 * sum(es_cancelado::int) / count(*), 2)  AS pct_cancelados
FROM pedido_plano
GROUP BY segmento
ORDER BY total_pedidos DESC;

-- Equivalente a Query 3 (ventas mensuales por zona)
-- Original: recorre 3M filas de pedido con 2 joins y agrega
-- Ahora: lee directo la tabla ya agregada, ni siquiera toca pedido
EXPLAIN ANALYZE
SELECT zona_nombre, mes, pedidos, ventas
FROM resumen_ventas_zona_mes
ORDER BY mes, ventas DESC;

-- Equivalente a Query 4 (top 10 restaurantes)
-- Original: join pedido-restaurante + GROUP BY sobre 3M filas
-- Ahora: lee directo la tabla agregada, orden de magnitud menos filas
EXPLAIN ANALYZE
SELECT restaurante_nombre, pedidos, ventas
FROM resumen_ventas_restaurante
ORDER BY ventas DESC
LIMIT 10;

-- ---------------------------------------------------------
-- Comparacion de espacio: normalizado vs desnormalizado
-- (dato crudo para la seccion de trade-off del reporte)
-- ---------------------------------------------------------
SELECT
    relname AS tabla,
    pg_size_pretty(pg_total_relation_size(relid)) AS tamano_total,
    pg_size_pretty(pg_relation_size(relid))       AS tamano_tabla,
    pg_size_pretty(pg_indexes_size(relid))        AS tamano_indices
FROM pg_catalog.pg_statio_user_tables
WHERE relname IN (
    'pedido', 'restaurante', 'zona', 'municipio', 'departamento', 'cliente',
    'pedido_plano', 'resumen_ventas_zona_mes', 'resumen_ventas_restaurante'
)
ORDER BY pg_total_relation_size(relid) DESC;
