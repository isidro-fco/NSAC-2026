"""Genera el marco de las ventanas grandes (menús de módulo) a partir de la
unidad de pantalla de Orion ("Imagen pegada (2).png"), en pixel art a escala 2
(cada píxel lógico = 2x2):

  - bisel color carbón con teclas de función: 12 en cada lado largo y 8 en
    cada lado corto, cada una con su marca blanca hacia la pantalla,
  - placa izquierda: 2 perillas oscuras con escala y 2 botones cuadrados,
  - placa derecha: 5 interruptores con protector (panel "SM Pwr Supply"),
  - interruptor pequeño en la esquina superior izquierda del bisel y perilla
    en la inferior derecha.

Produce en recursos/sprites/interfaz/:
  - marco_ventana.png: el bisel liso con la pantalla de marco_cabina en el
    centro (StyleBoxTexture de 9 partes en mosaico).
  - controles_cabina.png: hoja de piezas en píxeles lógicos. MarcoVentana
    (escenas/interfaz/estilo/marco_ventana.gd) las reparte según el tamaño de
    la ventana, siempre en la misma cantidad.

Las regiones de la hoja deben coincidir con REGIONES en marco_ventana.gd.

Uso: python3 herramientas/generar_marco_ventana.py
"""
import math
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import generar_marco_cabina as cab  # noqa: E402

ESCALA = 2
LOGICO = 16                    # margen de arriba/abajo en píxeles lógicos
EXTRA = 10                     # la placa de los lados es 10 px lógicos más ancha
LOGICO_LADO = LOGICO + EXTRA
MARGEN = LOGICO * ESCALA       # = MarcoVentana.MARGEN (32 px)
MARGEN_LADO = LOGICO_LADO * ESCALA   # = MarcoVentana.MARGEN_LADO (52 px)
CENTRO = 64                    # px reales, pantalla igual que marco_cabina

# Bandas (distancia lógica d al canto exterior, medida arriba/abajo).
PLACA = range(2, 5)            # placa azul noche (en los lados, 2..14)
SURCO = 5
BISEL = range(6, 15)           # bisel carbón con las teclas (d 7..11) y marcas (d 13)
CRISTAL = 15

# Colores tomados de la foto.
PLACA_C = (38, 38, 62, 255)
PLACA_LUZ = (78, 78, 112, 255)
PLACA_SOMBRA = (20, 20, 34, 255)
CARBON = (36, 35, 42, 255)
CARBON_LUZ = (66, 64, 76, 255)
CARBON_SOMBRA = (18, 18, 22, 255)
TECLA = (76, 76, 86, 255)
TECLA_LUZ = (118, 118, 130, 255)
TECLA_SOMBRA = (28, 28, 34, 255)
BLANCO = (232, 232, 238, 255)
ROTULO = (200, 200, 216, 255)
METAL = (176, 180, 190, 255)
METAL_LUZ = (238, 240, 246, 255)
METAL_SOMBRA = (96, 100, 112, 255)
PERILLA_C = (44, 44, 52, 255)
PERILLA_LUZ = (92, 92, 104, 255)
PERILLA_SOMBRA = (22, 22, 28, 255)
RANURA = (10, 10, 14, 255)
LEDS = {"verde": (88, 230, 160, 255), "ambar": (242, 198, 109, 255)}


# --- Bisel liso -------------------------------------------------------------

def banda(d: int, luz: bool) -> tuple:
    if d == 0:
        return cab.CONTORNO
    if d == 1:
        return PLACA_LUZ if luz else PLACA_SOMBRA
    if d in PLACA:
        return PLACA_C
    if d == SURCO:
        return RANURA
    if d == 6:
        return CARBON_LUZ if luz else CARBON_SOMBRA
    if d in BISEL:
        return CARBON
    return cab.PANTALLAS["marco_cabina.png"][3] if luz else RANURA


def equivalente_lado(dx: int) -> int:
    """Distancia de un lado convertida a la de arriba/abajo (placa EXTRA px más ancha)."""
    if dx <= PLACA[-1]:
        return dx
    return max(PLACA[-1], dx - EXTRA)


def bisel() -> Image.Image:
    ancho = LOGICO_LADO * 2 + CENTRO // ESCALA
    alto = LOGICO * 2 + CENTRO // ESCALA
    im = Image.new("RGBA", (ancho, alto))
    px = im.load()
    for y in range(alto):
        for x in range(ancho):
            dx = equivalente_lado(min(x, ancho - 1 - x))
            dy = min(y, alto - 1 - y)
            d = min(dx, dy)
            if d > CRISTAL:
                continue
            luz_x = x < ancho / 2
            luz_y = y < alto / 2
            luz = luz_x if dx < dy else luz_y if dy < dx else luz_x and luz_y
            px[x, y] = banda(d, luz)
    im = im.resize((ancho * ESCALA, alto * ESCALA), Image.NEAREST)
    pantalla = im.load()
    colores = cab.PANTALLAS["marco_cabina.png"]
    for y in range(CENTRO):
        for x in range(CENTRO):
            pantalla[MARGEN_LADO + x, MARGEN + y] = cab.pantalla(x, y, colores)
    return im


# --- Piezas sueltas (píxeles lógicos) --------------------------------------

# nombre -> (x, y, ancho, alto). Copiar a REGIONES de marco_ventana.gd.
REGIONES = {
    "tecla_h": (0, 0, 10, 5),
    "tecla_v": (11, 0, 5, 10),
    "marca_h": (17, 0, 4, 1),
    "marca_v": (22, 0, 1, 4),
    "protegido": (24, 0, 9, 9),
    "interruptor": (34, 0, 7, 10),
    "perilla_0": (0, 11, 11, 11),
    "perilla_1": (12, 11, 11, 11),
    "perilla_chica": (24, 11, 7, 7),
    "boton": (32, 11, 5, 5),
    "led_verde": (38, 11, 2, 2),
    "led_ambar": (41, 11, 2, 2),
    "tornillo": (38, 14, 3, 3),
    "rotulo": (0, 23, 5, 1),
    "rotulo_corto": (6, 23, 3, 1),
}


def caja(px, ox: int, oy: int, ancho: int, alto: int, cuerpo, luz, sombra) -> None:
    """Rectángulo en relieve: canto claro arriba/izquierda, oscuro abajo/derecha."""
    for y in range(alto):
        for x in range(ancho):
            if y == alto - 1 or x == ancho - 1:
                c = sombra
            elif y == 0 or x == 0:
                c = luz
            else:
                c = cuerpo
            px[ox + x, oy + y] = c


def perilla(px, ox: int, oy: int, lado: int, apunta: float, escala: bool) -> None:
    """Perilla redonda con marca blanca. Con `escala` es oscura con aro metálico
    y 7 puntos blancos alrededor (abierta abajo), como las de la placa izquierda
    de la foto; sin ella es metálica, como la de la esquina del bisel."""
    c0 = (lado - 1) / 2
    r = c0 - (0.6 if escala else -0.4)
    for y in range(lado):
        for x in range(lado):
            dx, dy = x - c0, y - c0
            dist = math.hypot(dx, dy)
            if dist > r:
                continue
            if escala:
                if dist > r - 1.1:
                    c = METAL_LUZ if dx + dy < -2 else METAL if dx + dy < 2 else METAL_SOMBRA
                else:
                    c = PERILLA_LUZ if dx + dy <= -2 else PERILLA_C if dx + dy <= 1 else PERILLA_SOMBRA
            else:
                c = METAL_LUZ if dx + dy <= -2 else METAL if dx + dy <= 1 else METAL_SOMBRA
            px[ox + x, oy + y] = c
    if escala:
        for grados in (-180, -135, -90, -45, 0, 45, 135):
            ang = math.radians(grados)
            px[ox + round(c0 + c0 * math.cos(ang)), oy + round(c0 + c0 * math.sin(ang))] = BLANCO
    ang = math.radians(apunta)
    for paso in range(1, int(r)):
        x = round(c0 + math.cos(ang) * paso)
        y = round(c0 + math.sin(ang) * paso)
        px[ox + x, oy + y] = BLANCO if escala else RANURA


def protegido(px, ox: int, oy: int) -> None:
    """Interruptor con protector visto de frente: marco metálico cuadrado y
    palanca redonda en el centro, como los del panel derecho de la foto."""
    caja(px, ox, oy, 9, 9, PERILLA_SOMBRA, METAL_LUZ, METAL_SOMBRA)
    for i in range(1, 8):                        # segundo aro del protector
        px[ox + i, oy + 1] = METAL
        px[ox + 1, oy + i] = METAL
    for y in range(3, 6):                        # palanca
        for x in range(3, 6):
            px[ox + x, oy + y] = METAL
    px[ox + 3, oy + 3] = METAL_LUZ
    px[ox + 4, oy + 3] = METAL_LUZ
    px[ox + 5, oy + 5] = METAL_SOMBRA
    px[ox + 4, oy + 4] = BLANCO


def interruptor(px, ox: int, oy: int) -> None:
    """Interruptor de palanca pequeño con base y bola en la punta."""
    for y in (6, 7, 8):
        for x in (1, 2, 3, 4, 5):
            px[ox + x, oy + y] = METAL_SOMBRA if y == 8 or x == 5 else METAL
    for y in range(2, 7):
        px[ox + 3, oy + y] = METAL_LUZ
        px[ox + 4, oy + y] = METAL_SOMBRA
    for x in (2, 3, 4):
        px[ox + x, oy + 1] = METAL_LUZ if x < 4 else METAL
    px[ox + 3, oy] = METAL


def hoja() -> Image.Image:
    im = Image.new("RGBA", (44, 24), (0, 0, 0, 0))
    px = im.load()
    r = REGIONES
    caja(px, *r["tecla_h"], TECLA, TECLA_LUZ, TECLA_SOMBRA)
    caja(px, *r["tecla_v"], TECLA, TECLA_LUZ, TECLA_SOMBRA)
    for nombre in ("marca_h", "marca_v", "rotulo", "rotulo_corto"):
        x, y, ancho, alto = r[nombre]
        for j in range(alto):
            for i in range(ancho):
                px[x + i, y + j] = BLANCO if nombre.startswith("marca") else ROTULO
    protegido(px, *r["protegido"][:2])
    interruptor(px, *r["interruptor"][:2])
    perilla(px, *r["perilla_0"][:2], 11, -60, True)
    perilla(px, *r["perilla_1"][:2], 11, -140, True)
    perilla(px, *r["perilla_chica"][:2], 7, -45, False)
    caja(px, *r["boton"], (22, 22, 28, 255), (70, 70, 80, 255), RANURA)
    for nombre, color in LEDS.items():
        x, y, _, _ = r[f"led_{nombre}"]
        px[x, y] = px[x + 1, y] = px[x, y + 1] = color
        px[x + 1, y + 1] = tuple(int(v * 0.65) for v in color[:3]) + (255,)
    x, y, _, _ = r["tornillo"]
    caja(px, x, y, 3, 3, METAL, METAL_LUZ, METAL_SOMBRA)
    px[x + 1, y + 1] = RANURA
    return im


def main() -> None:
    for nombre, imagen in [("marco_ventana.png", bisel()), ("controles_cabina.png", hoja())]:
        salida = cab.CARPETA / nombre
        imagen.save(salida)
        print(f"Guardado {salida} ({imagen.width}x{imagen.height})")


if __name__ == "__main__":
    main()
