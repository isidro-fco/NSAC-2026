#!/usr/bin/env python3
# descargar_donki.py
# Descarga eventos reales de NASA DONKI y los guarda en datos/nasa/archivo_donki.json para jugar sin internet.
"""
Uso (desde la carpeta del proyecto):
    python3 herramientas/descargar_donki.py                      # últimos 365 días
    python3 herramientas/descargar_donki.py 2024-05-01 2024-05-31

Guarda la respuesta cruda de cada tipo de evento (FLR, CME, SEP, GST, IPS, HSS,
MPC, RBE) y la fecha de descarga. El juego la convierte con globales/nasa/donki.gd
y le da prioridad sobre datos/nasa/eventos_curados.json. Solo usa la biblioteca
estándar de Python.

Usa la API de DONKI del CCMC (no pide clave). Desde el 30 de septiembre de 2026
está en ccmc.gsfc.nasa.gov/DONKI-API y acepta como máximo 60 días por consulta,
así que el periodo se pide en tramos. Si falla, prueba las direcciones viejas
(kauai y api.nasa.gov, con la clave de datos/nasa/clave_api.txt o DEMO_KEY).
"""

import datetime
import json
import pathlib
import sys
import time
import urllib.error
import urllib.request

TIPOS = ["FLR", "CME", "SEP", "GST", "IPS", "HSS", "MPC", "RBE"]
URL_CCMC = "https://ccmc.gsfc.nasa.gov/DONKI-API/get/{tipo}?startDate={desde}&endDate={hasta}"
URL_CCMC_VIEJA = "https://kauai.ccmc.gsfc.nasa.gov/DONKI/WS/get/{tipo}?startDate={desde}&endDate={hasta}"
DIAS_POR_CONSULTA = 59  # la API nueva rechaza más de 60 días
URL_API_NASA = "https://api.nasa.gov/DONKI/{tipo}?startDate={desde}&endDate={hasta}&api_key={clave}"

RAIZ = pathlib.Path(__file__).resolve().parent.parent
SALIDA = RAIZ / "datos" / "nasa" / "archivo_donki.json"
ARCHIVO_CLAVE = RAIZ / "datos" / "nasa" / "clave_api.txt"


def clave() -> str:
    if ARCHIVO_CLAVE.exists():
        texto = ARCHIVO_CLAVE.read_text(encoding="utf-8").strip()
        if texto:
            return texto
    return "DEMO_KEY"


def pedir(url: str):
    """Lista de eventos, [] si DONKI respondió vacío, o None si falló."""
    try:
        with urllib.request.urlopen(url, timeout=30) as r:
            texto = r.read().decode("utf-8").strip()
    except urllib.error.HTTPError as error:
        cuerpo = error.read().decode("utf-8", "replace")[:200]
        print(f"    falló ({url.split('?')[0]}): HTTP {error.code} {cuerpo}")
        return None
    except (urllib.error.URLError, TimeoutError, OSError) as error:
        print(f"    falló ({url.split('?')[0]}): {error}")
        return None
    if not texto:
        return []
    try:
        datos = json.loads(texto)
    except json.JSONDecodeError:
        print(f"    falló ({url.split('?')[0]}): respondió una página web, no datos")
        return None
    return datos if isinstance(datos, list) else None


def tramos(desde: str, hasta: str):
    """Pedazos [desde, hasta] de DIAS_POR_CONSULTA días que cubren el periodo."""
    a = datetime.date.fromisoformat(desde)
    fin = datetime.date.fromisoformat(hasta)
    while a <= fin:
        b = min(a + datetime.timedelta(days=DIAS_POR_CONSULTA), fin)
        yield a.isoformat(), b.isoformat()
        a = b + datetime.timedelta(days=1)


def pedir_tipo(tipo: str, desde: str, hasta: str):
    for plantilla in (URL_CCMC, URL_CCMC_VIEJA):
        lista = pedir(plantilla.format(tipo=tipo, desde=desde, hasta=hasta))
        if lista is not None:
            return lista
    return pedir(URL_API_NASA.format(tipo=tipo, desde=desde, hasta=hasta, clave=clave()))


def main() -> int:
    hoy = datetime.date.today()
    desde = sys.argv[1] if len(sys.argv) > 1 else (hoy - datetime.timedelta(days=365)).isoformat()
    hasta = sys.argv[2] if len(sys.argv) > 2 else hoy.isoformat()
    archivo = {"meta": {"desde": desde, "hasta": hasta, "descargado": hoy.isoformat(),
                        "fuente": "NASA DONKI (CCMC, Goddard Space Flight Center)"}}
    for tipo in TIPOS:
        archivo[tipo] = []
        for a, b in tramos(desde, hasta):
            print(f"{tipo}: {a} a {b}")
            lista = pedir_tipo(tipo, a, b)
            if lista is None:
                print("No se pudo descargar. No se cambió el archivo.")
                return 1
            print(f"    {len(lista)} eventos")
            archivo[tipo].extend(lista)
            time.sleep(1)  # para no saturar el servidor
    SALIDA.parent.mkdir(parents=True, exist_ok=True)
    SALIDA.write_text(json.dumps(archivo, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"Listo: {SALIDA}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
