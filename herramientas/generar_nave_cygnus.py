"""Genera el sprite del carguero de suministros inspirado en la nave Cygnus.

Referencia: Cygnus (Northrop Grumman), el carguero sin tripulación que lleva
suministros a la ISS. De arriba abajo:
  - anillo de atraque (CBM) oscuro en lo alto,
  - módulo de carga presurizado (PCM): cilindro plateado con costillas
    horizontales y una compuerta de bodega,
  - banda de unión naranja (como el escudo de capsula_orion.png),
  - módulo de servicio corto y facetado, forrado de manta térmica dorada,
  - tobera del motor principal debajo.

Mismo estilo que capsula_orion.png: paleta de grises con luz desde la izquierda
y contorno negro de 1 px calculado alrededor de la silueta.

Uso: python3 herramientas/generar_nave_cygnus.py
"""
from pathlib import Path

from PIL import Image

SALIDA = Path(__file__).resolve().parent.parent / "recursos/sprites/modulos/carguero_cygnus.png"

ANCHO, ALTO = 24, 40
CENTRO = ANCHO // 2           # eje de la nave: columnas 11|12

CONTORNO = (0, 0, 0, 255)
# Casco plateado del PCM (de la luz a la sombra).
LUZ = (227, 227, 227, 255)
CLARO = (192, 192, 192, 255)
MEDIO = (158, 158, 158, 255)
SOMBRA = (124, 124, 134, 255)
OSCURO = (104, 100, 121, 255)
COSTILLA = (79, 64, 107, 255)
# Anillo de atraque y tobera.
METAL = (51, 51, 51, 255)
METAL_LUZ = (110, 110, 118, 255)
# Manta térmica del módulo de servicio.
ORO_LUZ = (246, 206, 110, 255)
ORO = (218, 164, 60, 255)
ORO_SOMBRA = (160, 108, 34, 255)
# Banda de unión (mismo naranja que la cápsula Orion).
NARANJA = (255, 121, 30, 255)
NARANJA_SOMBRA = (204, 98, 24, 255)
COMPUERTA = (70, 66, 97, 255)

# Filas de cada parte (contorno aparte: deja 1 px libre alrededor).
CBM = (1, 3)          # anillo de atraque
CONO = (4, 6)         # hombro que ensancha hasta el cilindro
PCM = (7, 24)         # módulo de carga presurizado
BANDA = (25, 26)
SERVICIO = (27, 32)
TOBERA = (33, 37)
COMPUERTA_RECT = (6, 12, 12, 9)   # x, y, ancho, alto de la bodega (sobre el PCM)
def tono_cilindro(f: float, paleta: list) -> tuple:
    """Color de una columna de un cilindro según su posición 0..1 (luz a la izquierda)."""
    cortes = [0.12, 0.5, 0.72, 0.88]
    for corte, color in zip(cortes, paleta):
        if f < corte:
            return color
    return paleta[-1]


def fila_cilindro(px, y: int, mitad: int, paleta: list) -> None:
    x0, x1 = CENTRO - mitad, CENTRO + mitad - 1
    for x in range(x0, x1 + 1):
        px[x, y] = tono_cilindro((x - x0) / max(1, x1 - x0), paleta)


def main() -> None:
    img = Image.new("RGBA", (ANCHO, ALTO), (0, 0, 0, 0))
    px = img.load()
    plata = [CLARO, LUZ, CLARO, MEDIO, SOMBRA]
    oro = [ORO, ORO_LUZ, ORO, ORO_SOMBRA, ORO_SOMBRA]

    # Anillo de atraque (CBM).
    for y in range(CBM[0], CBM[1] + 1):
        for x in range(CENTRO - 5, CENTRO + 5):
            px[x, y] = METAL_LUZ if y == CBM[0] else METAL
    # Hombro: se ensancha hacia el cilindro.
    for i, y in enumerate(range(CONO[0], CONO[1] + 1)):
        fila_cilindro(px, y, 7 + i, plata)
    # PCM: cilindro con costillas cada 4 filas.
    for y in range(PCM[0], PCM[1] + 1):
        fila_cilindro(px, y, 10, plata)
        if (y - PCM[0]) % 4 == 3:
            for x in range(CENTRO - 10, CENTRO + 10):
                px[x, y] = COSTILLA if x >= CENTRO + 4 else SOMBRA
    # Compuerta de la bodega (el juego pinta encima la apertura).
    cx0, cy0, cw, ch = COMPUERTA_RECT
    for y in range(cy0, cy0 + ch):
        for x in range(cx0, cx0 + cw):
            borde = x in (cx0, cx0 + cw - 1) or y in (cy0, cy0 + ch - 1)
            px[x, y] = METAL if borde else (COMPUERTA if x > cx0 + cw // 2 else OSCURO)
    for x in range(cx0 + 2, cx0 + cw - 2, 3):    # remaches del marco
        px[x, cy0 + 1] = CLARO
    # Banda naranja.
    for y in range(BANDA[0], BANDA[1] + 1):
        for x in range(CENTRO - 11, CENTRO + 11):
            px[x, y] = NARANJA if x < CENTRO + 6 and y == BANDA[0] else NARANJA_SOMBRA
    # Módulo de servicio: facetado (esquinas recortadas) con manta dorada.
    for i, y in enumerate(range(SERVICIO[0], SERVICIO[1] + 1)):
        ultima = SERVICIO[1] - SERVICIO[0]
        mitad = 9 if i == 0 or i == ultima else 10
        fila_cilindro(px, y, mitad, oro)
    for y in (SERVICIO[0] + 2, SERVICIO[0] + 4):            # pliegues de la manta
        for x in range(CENTRO - 8, CENTRO + 8, 2):
            px[x, y] = ORO_SOMBRA
    for lado in (-1, 1):                                     # bloques de propulsores
        x = CENTRO - 10 if lado < 0 else CENTRO + 9
        for y in (SERVICIO[0] + 1, SERVICIO[0] + 2):
            px[x, y] = METAL
    # Tobera del motor principal.
    for i, y in enumerate(range(TOBERA[0], TOBERA[1] + 1)):
        mitad = 2 + i // 2
        for x in range(CENTRO - mitad, CENTRO + mitad):
            px[x, y] = METAL_LUZ if x == CENTRO - mitad else METAL

    # Contorno negro alrededor de la silueta.
    opaco = {(x, y) for y in range(ALTO) for x in range(ANCHO) if px[x, y][3]}
    for x, y in list(opaco):
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < ANCHO and 0 <= ny < ALTO and (nx, ny) not in opaco:
                px[nx, ny] = CONTORNO

    img.save(SALIDA)
    print(f"Guardado {SALIDA.relative_to(SALIDA.parents[3])} ({ANCHO}x{ALTO})")


if __name__ == "__main__":
    main()
