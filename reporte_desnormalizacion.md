# Reporte de desnormalización — Ruta Verde

## 1. Punto de partida

Sobre el modelo normalizado (3FN) se corrieron 5 consultas representativas.
Cada una expone un problema de rendimiento distinto:

| # | Consulta | Problema observado | Técnica de desnormalización |
|---|----------|---------------------|------------------------------|
| 1 | Ventas por departamento | La consulta encadena muchos joins para llegar a un atributo | Pre-join |
| 2 | Estadísticas por segmento | El mismo cálculo se repite en cada consulta | Columna derivada |
| 3 | Ventas mensuales por zona | Una consulta recurrente recorre millones de filas para devolver pocas | Tabla agregada |
| 4 | Top restaurantes por ventas | Mismo patrón que la query 3 (agregación sobre toda la tabla) | Tabla agregada |
| 5 | Tamaño de tablas e índices | Consulta al catálogo del sistema, no a datos de negocio | *(no aplica desnormalización)* |

## 2. Por qué estas técnicas y no otras

**Query 1 → Pre-join.**
El dato "departamento" vive a 4 saltos de distancia de `pedido`
(`pedido → restaurante → zona → municipio → departamento`). No es un
cálculo, es solo *distancia estructural*: la técnica correcta para
acortar distancia es aplanar la jerarquía en una sola fila, no
agregar ni derivar nada. Por eso se construyó `pedido_plano`
copiando el nombre de zona, municipio y departamento directamente en
cada fila del pedido.

**Query 2 → Columna derivada.**
A diferencia de la query 1, acá el costo no es de *joins* sino de
*cómputo repetido*: el `CASE WHEN estado = 'cancelado'` se evalúa
fila por fila cada vez que alguien corre la consulta, aunque el
resultado de esa evaluación nunca cambia una vez que el pedido queda
en estado final. Se materializó como columna booleana
(`es_cancelado`) y se aprovechó la misma tabla ancha para agregar
`mes` precalculado, ya que el `date_trunc('month', fecha)` tiene el
mismo problema: se recalcula en cada `GROUP BY` cuando podría
calcularse una sola vez, en el momento de la carga.

**Queries 3 y 4 → Tabla agregada.**
Ambas comparten la misma forma: `GROUP BY` sobre la totalidad de
`pedido` (3M filas) para devolver un resultado que, en comparación,
es minúsculo (decenas de zonas×meses, miles de restaurantes como
máximo). No hace falta guardar el dato en un formato distinto
(anidado, por ejemplo) — alcanza con guardar el *resultado ya
agregado* como su propia tabla, y dejar que la consulta lea
directamente eso en vez de recalcularlo sobre el detalle cada vez.
Es la misma técnica para las dos porque el problema de fondo es
idéntico: costo de agregación repetida, no estructura de los datos.

**Query 5 → No se desnormaliza.**
Esta consulta no lee datos de negocio: lee metadata del motor
(`pg_catalog`), que refleja el estado físico real de las tablas en
ese instante. Desnormalizar implica aceptar algo de redundancia o
de posible desactualización a cambio de velocidad; en este caso no
hay nada que ganar, porque el dato tiene que ser exacto en el
momento en que se consulta (si se cachea, deja de ser confiable) y
el catálogo de Postgres ya es eficiente por diseño para este tipo de
consulta. Forzar una estructura desnormalizada acá solo introduciría
la posibilidad de que el número mostrado no coincida con el estado
real del disco.

## 3. Qué se construyó

- **`pedido_plano`** — tabla ancha: resuelve queries 1 y 2 a la vez,
  ya que un pre-join y una columna derivada normalmente conviene que
  vivan juntos en la misma estructura física en vez de duplicar el
  trabajo de "aplanar" dos veces.
- **`resumen_ventas_zona_mes`** y **`resumen_ventas_restaurante`** —
  tablas agregadas: resuelven queries 3 y 4, calculadas *a partir*
  de `pedido_plano` (no directamente de `pedido`), para no repetir
  los joins de la primera etapa.

## 4. Trade-offs

### 4.1 Velocidad

> Nota metodológica: en el modelo normalizado, las queries 1 y 2 se
> midieron con `SELECT * FROM vista` (tiempo total reportado por
> `psql`, incluye transferencia del resultado al cliente). Las
> queries 3 y 4, en cambio, sí se corrieron con `EXPLAIN ANALYZE` en
> ambos modelos, así que ahí la comparación de `Execution Time` es
> directa. Para 1 y 2 se usó el tiempo total como aproximación —no es
> perfectamente equivalente, pero la magnitud de la diferencia hace
> que la conclusión no cambie.

| Consulta | Tiempo normalizado | Tiempo desnormalizado | Mejora |
|----------|---------------------|--------------------------|--------|
| Query 1 — ventas por departamento | 1089.39 ms *(tiempo total)* | 250.29 ms *(Execution Time)* | ~4.3× |
| Query 2 — estadísticas por segmento | 455.62 ms *(tiempo total)* | 255.45 ms *(Execution Time)* | ~1.8× |
| Query 3 — ventas mensuales por zona | 2264.82 ms *(Execution Time)* | 70.32 ms *(Execution Time)* | ~32.2× |
| Query 4 — top restaurantes | 508.96 ms *(Execution Time)* | 2.35 ms *(Execution Time)* | ~216.6× |

**Lectura de los planes de ejecución:**

- **Query 1 y 2**: el plan sobre `pedido_plano` ya no muestra ningún
  `Hash Join` — es un `Parallel Seq Scan` directo sobre la tabla
  ancha seguido de la agregación. El pre-join cumplió exactamente lo
  esperado: sacó el costo del join fuera del camino crítico de la
  consulta (se paga una sola vez, al construir `pedido_plano`, no en
  cada ejecución).
- **Query 3**: el salto es el más dramático de los dos casos de tabla
  agregada porque el plan original tenía que hacer `Hash Join` de
  `pedido` (3M filas) contra `restaurante` y `zona`, más un
  `HashAggregate` con 8 particiones sobre 2.19M grupos estimados. El
  plan desnormalizado es un `Seq Scan` sobre una tabla de apenas
  72,000 filas — ya no toca `pedido` en absoluto.
- **Query 4**: acá está la mejora más grande de las cuatro
  (~217×). Tiene sentido: era la consulta que barría 3M filas en
  paralelo (`Parallel Seq Scan on pedido`) solo para agrupar por
  restaurante y quedarse con 10 filas. Contra `resumen_ventas_restaurante`
  (20,000 filas ya agregadas) el trabajo es casi inmediato.
- El caso con menor mejora relativa es **Query 2 (~1.8×)**: aun en el
  modelo normalizado, esa consulta ya era relativamente barata
  (455 ms sobre 3M filas con un solo join contra `cliente`), así que
  había menos margen para ganar. Esto es consistente con la
  clasificación original: query 2 se trataba de una *columna
  derivada* (costo de cómputo repetido), no de un *pre-join* pesado
  como la query 1 — el ahorro que ofrece es más modesto por
  naturaleza.

### 4.2 Espacio

| Tabla | Tamaño total | Tabla | Índices |
|-------|---------------|-------|---------|
| `pedido` (normalizado) | 353 MB | 196 MB | 158 MB |
| `pedido_plano` (desnormalizado) | 583 MB | 457 MB | 126 MB |
| `resumen_ventas_zona_mes` | 6.9 MB | 4.6 MB | 2.2 MB |
| `resumen_ventas_restaurante` | 2.4 MB | 1.5 MB | 0.8 MB |

**Análisis:**

- `pedido_plano` pesa **~65% más en total** que `pedido` solo (583 MB
  vs 353 MB), y el crecimiento está concentrado en el tamaño de la
  tabla en sí (457 MB vs 196 MB, **2.3× más grande**): cada fila ahora
  carga texto repetido (`zona_nombre`, `municipio_nombre`,
  `departamento_nombre`, `restaurante_nombre`, `segmento`) en vez de
  enteros de 4 bytes que apuntaban a esas mismas cadenas guardadas
  una sola vez en las tablas normalizadas.
- Curiosamente, los **índices de `pedido_plano` pesan menos**
  (126 MB) que los de `pedido` (158 MB), a pesar de que la tabla base
  es más grande. [ *punto para tu propia justificación:* ¿tiene que
  ver con la cantidad de índices definidos en cada caso, con el tipo
  de dato indexado (texto vs entero), o con algo del orden físico de
  los datos? Vale la pena revisar `\di+` sobre ambas tablas. ]
- Las dos tablas agregadas son **prácticamente gratis en espacio**
  (6.9 MB y 2.4 MB, juntas no llegan al 2% del tamaño de
  `pedido_plano`), a cambio de las mejoras de 32× y 217× medidas
  arriba. Ese es el trade-off más claro de los cuatro: para las
  queries 3 y 4, la desnormalización no tiene casi contraindicación
  de espacio.

### 4.3 Consistencia y mantenimiento

[ completar — pensar en al menos estos escenarios: ]

- Si un restaurante cambia de zona, ¿qué hay que actualizar en el
  modelo normalizado? ¿y en `pedido_plano`? ¿Se actualiza el
  histórico o solo los pedidos nuevos?
- Las tablas `resumen_ventas_*` no se actualizan solas: ¿con qué
  frecuencia habría que recalcularlas en un sistema real? ¿qué pasa
  si un reporte se genera justo antes de esa actualización?
- ¿Qué estrategia de actualización elegirías (recalcular todo por
  batch vs. trigger en cada `INSERT`) y qué costo tiene cada una?

### 4.4 Conclusión

[ completar — ¿el trade-off vale la pena para este caso de uso? ¿Para
cuáles de las 4 queries sí y para cuáles quizás no? ]
