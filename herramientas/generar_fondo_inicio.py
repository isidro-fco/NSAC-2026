#!/usr/bin/env python3
"""Convierte fondo.jpeg (raíz del proyecto) en el fondo pixel art del menú de inicio.

Pasos: recorta a 16:9, reduce a 160x90 (cada píxel se ve 8x8 a 1280x720),
sube contraste y saturación, alisa las texturas finas (filtro de mediana) y
limita la imagen a 20 colores sin tramado: quedan manchas planas y píxeles
gruesos, como en los sprites del juego (11 a 37 colores cada uno).

Uso: python3 herramientas/generar_fondo_inicio.py
"""
from pathlib import Path

from PIL import Image, ImageEnhance, ImageFilter

RAIZ = Path(__file__).resolve().parent.parent
ORIGEN = RAIZ / "fondo.jpeg"
SALIDA = RAIZ / "recursos/sprites/interfaz/fondo_inicio.png"
TAM = (160, 90)
COLORES = 20


def main() -> None:
    im = Image.open(ORIGEN).convert("RGB")
    ancho, alto = im.size
    # Recorte centrado a la proporción de TAM.
    alto_nuevo = round(ancho * TAM[1] / TAM[0])
    arriba = (alto - alto_nuevo) // 2
    im = im.crop((0, arriba, ancho, arriba + alto_nuevo))
    # Primero al doble del tamaño final para alisar el grano de la foto, luego al final.
    im = im.resize((TAM[0] * 2, TAM[1] * 2), Image.LANCZOS).filter(ImageFilter.MedianFilter(5))
    im = im.resize(TAM, Image.BOX)
    im = ImageEnhance.Contrast(im).enhance(1.25)
    im = ImageEnhance.Color(im).enhance(1.5)
    im = ImageEnhance.Sharpness(im).enhance(1.8)
    im = im.quantize(COLORES, method=Image.MEDIANCUT, dither=Image.NONE).convert("RGB")
    im.save(SALIDA)
    print(f"Guardado {SALIDA} ({TAM[0]}x{TAM[1]}, {COLORES} colores)")


if __name__ == "__main__":
    main()
