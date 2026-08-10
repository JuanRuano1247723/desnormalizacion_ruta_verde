"""
=====================================================================
  GENERADOR DE DATOS - Ruta Verde  (modelo normalizado 3FN)
  Curso de Ciencia de Datos
=====================================================================

  Genera seis archivos CSV con el modelo YA NORMALIZADO.
  La desnormalizacion la disena y construye usted: ese es el trabajo.

  No requiere instalar nada: solo Python 3.
  Ejecutar:   python generar_datos.py

  Salida (carpeta ./datos):
      departamento.csv   municipio.csv   zona.csv
      restaurante.csv    cliente.csv     pedido.csv

  Ajuste N_PEDIDOS segun lo que quiera medir. Con menos de
  1 millon de filas las diferencias de tiempo NO se notan.
=====================================================================
"""
import csv, os, random, datetime

# ---------------------------------------------------------------
# CONFIGURACION - cambie estos numeros y vuelva a generar
# ---------------------------------------------------------------
N_PEDIDOS      = 3_000_000
N_CLIENTES     =   500_000
N_RESTAURANTES =    20_000
N_ZONAS        =     3_000
N_MUNICIPIOS   =       340
SEMILLA        = 42          # misma semilla = mismos datos, reproducible
CARPETA        = "datos"
# ---------------------------------------------------------------

random.seed(SEMILLA)
os.makedirs(CARPETA, exist_ok=True)

DEPARTAMENTOS = [
    "Guatemala", "Sacatepequez", "Chimaltenango", "Escuintla", "Santa Rosa",
    "Solola", "Totonicapan", "Quetzaltenango", "Suchitepequez", "Retalhuleu",
    "San Marcos", "Huehuetenango", "Quiche", "Baja Verapaz", "Alta Verapaz",
    "Peten", "Izabal", "Zacapa", "Chiquimula", "Jalapa", "Jutiapa", "El Progreso",
]
ESTADOS = ["entregado", "entregado", "entregado", "cancelado", "en_ruta"]


def escribir(nombre, encabezado, filas):
    ruta = os.path.join(CARPETA, nombre)
    with open(ruta, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(encabezado)
        w.writerows(filas)
    mb = os.path.getsize(ruta) / 1024 / 1024
    print(f"  {nombre:<20} {mb:8.1f} MB")


print("Generando modelo normalizado...\n")

# --- departamento ---
escribir("departamento.csv", ["departamento_id", "nombre"],
         [(i + 1, d) for i, d in enumerate(DEPARTAMENTOS)])

# --- municipio ---
escribir("municipio.csv", ["municipio_id", "nombre", "departamento_id"],
         [(i, f"Municipio_{i}", (i % len(DEPARTAMENTOS)) + 1)
          for i in range(1, N_MUNICIPIOS + 1)])

# --- zona ---
escribir("zona.csv", ["zona_id", "nombre", "municipio_id"],
         [(i, f"Zona_{i}", (i % N_MUNICIPIOS) + 1)
          for i in range(1, N_ZONAS + 1)])

# --- restaurante ---
escribir("restaurante.csv", ["restaurante_id", "nombre", "zona_id"],
         [(i, f"Restaurante_{i}", (i % N_ZONAS) + 1)
          for i in range(1, N_RESTAURANTES + 1)])

# --- cliente ---
def gen_clientes():
    for i in range(1, N_CLIENTES + 1):
        yield (i, f"Cliente_{i}", f"segmento_{i % 7}", f"5{i % 10000000:07d}")
escribir("cliente.csv", ["cliente_id", "nombre", "segmento", "telefono"],
         gen_clientes())

# --- pedido (la tabla grande) ---
inicio = datetime.date(2025, 1, 1)
def gen_pedidos():
    for i in range(1, N_PEDIDOS + 1):
        yield (
            i,
            (i % N_CLIENTES) + 1,
            (i % N_RESTAURANTES) + 1,
            (inicio + datetime.timedelta(days=i % 730)).isoformat(),
            round(25 + (i % 400) + random.random() * 50, 2),
            ESTADOS[i % len(ESTADOS)],
        )
escribir("pedido.csv",
         ["pedido_id", "cliente_id", "restaurante_id", "fecha", "total", "estado"],
         gen_pedidos())

print(f"""
Listo. Los archivos estan en ./{CARPETA}/

Siguiente paso (lo hace usted):
  1. Cargue los CSV en el motor que prefiera.
  2. Mida la consulta sobre el modelo NORMALIZADO.
  3. Disene y construya su version DESNORMALIZADA.
  4. Mida la misma consulta sobre su version.
  5. Compare tiempo y espacio, y justifique el trade-off.
""")
