"""Genera el marco del HUD inspirado en la cabina de la cápsula Orion.

Referencia: paneles de vuelo de Orion (bisel de metal azul con teclas de función
alrededor de cada pantalla, tornillos en las esquinas y pantalla oscura con un
leve barrido de líneas).

La imagen se usa como StyleBoxTexture de 9 partes con bordes y centro en
mosaico (AXIS_STRETCH_MODE_TILE), así que:
  - las esquinas son placas lisas con un tornillo (tapan el corte de las teclas),
  - el centro es múltiplo de PERIODO (teclas) y de REJILLA (pantalla),
  - todo lo del centro es periódico para que el mosaico no tenga costuras.

Uso: python3 herramientas/generar_marco_cabina.py
"""
from pathlib import Path

from PIL import Image

CARPETA = Path(__file__).resolve().parent.parent / "recursos/sprites/interfaz"

MARGEN = 8          # = UI.MARGEN_MARCO
CENTRO = 64         # múltiplo de PERIODO y de REJILLA
PERIODO = 8         # una tecla de función cada 8 px
REJILLA = 16        # cuadrícula tenue de la pantalla
LADO = MARGEN * 2 + CENTRO

CONTORNO = (8, 11, 18, 255)
BISEL_LUZ = (104, 128, 178, 255)     # canto iluminado (arriba/izquierda)
BISEL_SOMBRA = (22, 30, 52, 255)     # canto en sombra (abajo/derecha)
BISEL = (46, 62, 104, 255)           # metal azul anodizado
BISEL_OSCURO = (36, 48, 82, 255)
TECLA = (176, 184, 198, 255)         # teclas de función grises
TECLA_LUZ = (222, 228, 236, 255)
TECLA_SOMBRA = (88, 96, 116, 255)
HUECO = (6, 9, 15, 255)              # hendidura entre bisel y pantalla
CRISTAL = (40, 92, 120, 255)         # filo del cristal, reflejo frío
# Pantallas: (fondo, líneas de barrido, rejilla, filo del cristal) por archivo.
# - marco_cabina: pantalla apagada (paneles y botones normales).
# - marco_cabina_acento: pantalla encendida en ACENTO (botón principal, p. ej. Construir).
PANTALLAS = {
    "marco_cabina.png": ((11, 18, 28, 255), (14, 23, 35, 255), (18, 33, 48, 255), CRISTAL),
    "marco_cabina_acento.png": ((200, 124, 84, 255), (190, 116, 78, 255), (214, 140, 98, 255), (246, 196, 158, 255)),
}
TORNILLO = (150, 156, 168, 255)
TORNILLO_LUZ = (232, 236, 242, 255)
TORNILLO_RANURA = (40, 44, 54, 255)


def bisel(x: int, y: int, d: int) -> tuple:
    """Metal del bisel con canto iluminado arriba/izquierda y sombra abajo/derecha."""
    if d == 1:
        abajo_derecha = x == LADO - 2 or y == LADO - 2
        return BISEL_SOMBRA if abajo_derecha else BISEL_LUZ
    if d == 6:
        return BISEL_OSCURO
    return BISEL


def tecla(pos: int, d: int):
    """Tecla de función a lo largo de un borde: 4 px de largo, filas d=2..4."""
    p = pos % PERIODO
    if not 2 <= p <= 5 or not 2 <= d <= 4:
        return None
    if d == 4 or p == 5:
        return TECLA_SOMBRA
    if d == 2 or p == 2:
        return TECLA_LUZ
    return TECLA


def pantalla(x: int, y: int, colores: tuple) -> tuple:
    fondo, linea, rejilla, _ = colores
    if x % REJILLA == 0 or y % REJILLA == 0:
        return rejilla
    return linea if y % 2 == 0 else fondo


def generar(nombre: str, colores: tuple) -> None:
    im = Image.new("RGBA", (LADO, LADO), (0, 0, 0, 0))
    px = im.load()
    fin = LADO - MARGEN
    for y in range(LADO):
        for x in range(LADO):
            d = min(x, y, LADO - 1 - x, LADO - 1 - y)
            en_esquina = (x < MARGEN or x >= fin) and (y < MARGEN or y >= fin)
            if d == 0:
                c = CONTORNO
            elif d <= 6:
                c = bisel(x, y, d)
                if not en_esquina:
                    # posición a lo largo del borde, medida desde el inicio del centro
                    pos = (x - MARGEN) if d in (y, LADO - 1 - y) else (y - MARGEN)
                    c = tecla(pos, d) or c
            elif d == 7:
                # filo del cristal: reflejo frío arriba/izquierda, hendidura oscura abajo/derecha
                c = HUECO if x == fin or y == fin else colores[3]
            else:
                c = pantalla(x - MARGEN, y - MARGEN, colores)
            px[x, y] = c

    # Tornillos de 3x3 en las placas de esquina.
    for cx, cy in [(3, 3), (LADO - 4, 3), (3, LADO - 4), (LADO - 4, LADO - 4)]:
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                px[cx + dx, cy + dy] = TORNILLO
        px[cx - 1, cy - 1] = TORNILLO_LUZ
        px[cx - 1, cy] = TORNILLO_RANURA
        px[cx, cy] = TORNILLO_RANURA
        px[cx + 1, cy] = TORNILLO_RANURA
        px[cx + 1, cy + 1] = BISEL_SOMBRA

    salida = CARPETA / nombre
    salida.parent.mkdir(parents=True, exist_ok=True)
    im.save(salida)
    print(f"Guardado {salida} ({LADO}x{LADO})")


def main() -> None:
    for nombre, colores in PANTALLAS.items():
        generar(nombre, colores)


if __name__ == "__main__":
    main()
