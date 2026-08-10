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

## 4. Trade-offs a justificar

> **[ COMPLETAR ]** — Esta sección se llena con los resultados reales
> de correr `sql/03_queries_ejemplo.sql` (normalizado) y
> `sql/05_queries_desnormalizado.sql` (desnormalizado) sobre tus
> propios datos generados.

### 4.1 Velocidad

| Consulta | Tiempo normalizado (ms) | Tiempo desnormalizado (ms) | Diferencia |
|----------|--------------------------|------------------------------|------------|
| Query 1 — ventas por departamento | | | |
| Query 2 — estadísticas por segmento | | | |
| Query 3 — ventas mensuales por zona | | | |
| Query 4 — top restaurantes | | | |

*(Tomar el tiempo de `EXPLAIN ANALYZE`, específicamente `Execution Time`,
no `Planning Time`.)*

**Análisis:** [ completar — ¿el pre-join efectivamente evitó los
joins según el plan de ejecución? ¿la tabla agregada dejó de hacer
seq scan sobre `pedido`? ¿hubo alguna consulta donde la mejora fue
menor a la esperada, y por qué? ]

### 4.2 Espacio

| Tabla | Tamaño normalizado | Tamaño desnormalizado equivalente |
|-------|----------------------|--------------------------------------|
| `pedido` vs `pedido_plano` | | |
| (suma de dimensiones) vs incluido en `pedido_plano` | | |
| — vs `resumen_ventas_zona_mes` | — | |
| — vs `resumen_ventas_restaurante` | — | |

**Análisis:** [ completar — ¿cuánto más pesa `pedido_plano` que
`pedido` solo, y por qué (tipo de dato repetido: texto vs entero)?
¿el peso de las tablas agregadas es despreciable en comparación? ]

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
