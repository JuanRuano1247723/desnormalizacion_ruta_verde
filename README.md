# Ruta Verde — Postgres en Docker (modelo normalizado)

## Estructura esperada

```
ruta_verde/
├── docker-compose.yml
├── generar_datos.py        <- el que ya tenes
├── datos/                  <- se crea al correr el script
└── sql/
    ├── 01_schema.sql
    ├── 02_load.sql
    └── 03_queries_ejemplo.sql
```

## Pasos

### 1. Generar los CSV
```bash
python generar_datos.py
```
Esto crea la carpeta `./datos` con los 6 CSV. Con `N_PEDIDOS = 3_000_000`
el archivo `pedido.csv` va a pesar varios cientos de MB — normal.

### 2. Levantar Postgres
```bash
docker compose up -d
```
Verificá que el contenedor esté sano:
```bash
docker compose ps
docker compose logs -f db   # Ctrl+C para salir del log
```

### 3. Crear el esquema
```bash
docker exec -i ruta_verde_db psql -U rutaverde -d rutaverde < sql/01_schema.sql
```

### 4. Cargar los datos
```bash
docker exec -i ruta_verde_db psql -U rutaverde -d rutaverde < sql/02_load.sql
```
Con `\timing on` activado vas a ver cuánto tarda cada `COPY`. La tabla
`pedido` (3M filas) es la que más tiempo toma; en una laptop normal
debería ser de segundos, no minutos, gracias a `COPY` en vez de `INSERT`.

### 5. Correr las queries de ejemplo
```bash
docker exec -i ruta_verde_db psql -U rutaverde -d rutaverde < sql/03_queries_ejemplo.sql
```
O, si preferís explorar interactivamente:
```bash
docker exec -it ruta_verde_db psql -U rutaverde -d rutaverde
```

Dentro de `psql`, comandos útiles:
```sql
\timing on          -- muestra el tiempo de cada query
\dt                  -- lista las tablas
\d+ pedido           -- describe la tabla con tamaño
\di                  -- lista los indices
```

## Notas sobre lo que vas a medir

- Las queries en `03_queries_ejemplo.sql` ya usan `EXPLAIN ANALYZE` donde
  vale la pena, para que veas el plan real de ejecución (seq scan vs
  index scan, cuántas filas filtra cada join, tiempo real).
- Ahí es donde vas a ver el "costo de la normalización": cada consulta
  que necesita el nombre del departamento tiene que atravesar
  `pedido -> restaurante -> zona -> municipio -> departamento`, 4 joins.
- Esa es la línea base contra la que vas a comparar tu versión
  desnormalizada (por ejemplo, una tabla plana `pedido_completo` con
  el departamento, municipio, zona y segmento ya incluidos en cada fila).
  El trade-off que tenés que justificar es: menos joins y queries más
  rápidas, a cambio de más espacio en disco y redundancia que hay que
  mantener consistente si algo cambia (ej. si un restaurante se muda de
  zona, en el modelo normalizado se actualiza una fila; en el
  desnormalizado, potencialmente miles).

## Apagar / limpiar
```bash
docker compose down          # detiene el contenedor, conserva los datos
docker compose down -v       # detiene y BORRA el volumen (datos perdidos)
```
