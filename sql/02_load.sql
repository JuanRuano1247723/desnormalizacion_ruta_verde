-- =========================================================
-- Carga de datos via COPY (mucho mas rapido que INSERT fila
-- por fila; para 3M filas es la diferencia entre segundos y horas)
-- Orden importa por las llaves foraneas.
-- =========================================================

\timing on

COPY departamento FROM '/datos/departamento.csv' WITH (FORMAT csv, HEADER true);
COPY municipio     FROM '/datos/municipio.csv'     WITH (FORMAT csv, HEADER true);
COPY zona          FROM '/datos/zona.csv'          WITH (FORMAT csv, HEADER true);
COPY restaurante   FROM '/datos/restaurante.csv'   WITH (FORMAT csv, HEADER true);
COPY cliente       FROM '/datos/cliente.csv'       WITH (FORMAT csv, HEADER true);
COPY pedido        FROM '/datos/pedido.csv'        WITH (FORMAT csv, HEADER true);

-- Actualiza las estadisticas del planner despues de una carga masiva
ANALYZE departamento;
ANALYZE municipio;
ANALYZE zona;
ANALYZE restaurante;
ANALYZE cliente;
ANALYZE pedido;

-- Conteo rapido de verificacion
SELECT 'departamento' AS tabla, count(*) FROM departamento
UNION ALL SELECT 'municipio', count(*) FROM municipio
UNION ALL SELECT 'zona', count(*) FROM zona
UNION ALL SELECT 'restaurante', count(*) FROM restaurante
UNION ALL SELECT 'cliente', count(*) FROM cliente
UNION ALL SELECT 'pedido', count(*) FROM pedido;
