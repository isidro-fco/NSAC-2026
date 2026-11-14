# resaltado_colono.gd
# Brillo amarillo sobre el colono elegido en el panel de tripulación, o sobre su módulo si está dentro.

class_name ResaltadoColono
extends Node2D
## Sigue al colono elegido cada cuadro:
## - si se ve (afuera, en un pasillo o caminando): halo y aro a sus pies, y una
##   flecha encima de la cabeza;
## - si entró a un módulo (está oculto): halo que sigue la silueta del sprite del módulo.
## Late con el tiempo real, así que también se ve con el juego en pausa.
## Va justo debajo de los colonos para que el halo quede detrás del sprite.

const COLOR := UI.ADVERTENCIA
const VELOCIDAD_PULSO := 4.0

var mapa: Mapa
var objetivo: DatosColono


func _process(_delta: float) -> void:
	if objetivo != null:
		queue_redraw()


## Cambia el colono resaltado (null = ninguno).
func resaltar(datos: DatosColono) -> void:
	objetivo = datos
	queue_redraw()


func _draw() -> void:
	if objetivo == null:
		return
	var colono := mapa.colono_de(objetivo)
	if colono == null:
		return                               # todavía viene en la nave
	var pulso := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * VELOCIDAD_PULSO)
	var modulo: Modulo = mapa.cuadricula.celdas_modulo.get(colono.celda)
	if colono.oculto() and modulo != null:
		_resaltar_modulo(modulo, pulso)
	else:
		_resaltar_colono(colono.position, pulso)


func _resaltar_colono(pies: Vector2, pulso: float) -> void:
	# Halo detrás del sprite (el sprite va de 20 px arriba a 12 px abajo de `pies`).
	draw_circle(pies + Vector2(0, -4), 19.0, Color(COLOR, 0.22 + 0.18 * pulso))
	draw_circle(pies + Vector2(0, -4), 13.0, Color(COLOR, 0.25 + 0.15 * pulso))
	# Aro a los pies.
	draw_set_transform(pies + Vector2(0, 11), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 12.0, Color(COLOR, 0.35))
	draw_arc(Vector2.ZERO, 13.0, 0.0, TAU, 28, COLOR, 3.0)
	draw_arc(Vector2.ZERO, 17.0 + 3.0 * pulso, 0.0, TAU, 28, Color(COLOR, 0.6 * (1.0 - pulso)), 2.0)
	draw_set_transform(Vector2.ZERO)
	# Flecha que sube y baja encima de la cabeza.
	var punta := pies + Vector2(0, -26.0 - 4.0 * pulso)
	var flecha := PackedVector2Array([punta, punta + Vector2(-7, -8), punta + Vector2(7, -8)])
	draw_colored_polygon(flecha, COLOR)
	flecha.append(punta)
	draw_polyline(flecha, Color(0, 0, 0, 0.75), 1.5)


## Contorno que sigue la silueta real del sprite del módulo (ver _silueta), con
## un halo de 3 píxeles que late. Sin sprite, un rectángulo con el mismo halo.
func _resaltar_modulo(modulo: Modulo, pulso: float) -> void:
	var alfa := 0.65 + 0.35 * pulso
	var textura := modulo.datos.textura
	if textura != null:
		var brillo := _silueta(textura)
		draw_texture(brillo, modulo.position - Vector2(MARGEN_HALO, MARGEN_HALO), Color(1, 1, 1, alfa))
		return
	var rect := Rect2(modulo.position, Vector2(modulo.tam_celdas()) * GestorCuadricula.TAM_CELDA)
	draw_rect(rect, Color(COLOR_CAPAS[0], COLOR_CAPAS[0].a * alfa))
	for i in 3:
		var color := COLOR_CAPAS[i + 1]
		draw_rect(rect.grow(1.0 + i), Color(color, color.a * alfa), false, 1.0)


# --- Silueta del sprite ---------------------------------------------------
# Los sprites de módulo no tienen transparencia: traen dibujada la tierra
# alrededor. La silueta son los píxeles que no son de la paleta de la tierra,
# sin el mástil de la luz (una "apertura" quita lo de 1-2 px de grosor) y
# quedándose con la pieza más grande. Se calcula una vez por sprite.

const MARGEN_HALO := 4                    # px alrededor del sprite para el halo
## Los tres colores de la tierra en los sprites (RGBA de 32 bits).
const TIERRA: Array[int] = [0xFF791EFF, 0xCC6218FF, 0xFF8A39FF]
## Color de cada capa: dentro de la silueta y los anillos a 1, 2 y 3 px. El
## anillo pegado al módulo va casi blanco para que resalte sobre la tierra naranja.
const COLOR_CAPAS: Array[Color] = [
	Color(UI.ADVERTENCIA, 0.25),
	Color(1.0, 0.96, 0.78, 1.0),
	Color(UI.ADVERTENCIA, 0.9),
	Color(UI.ADVERTENCIA, 0.45),
]

static var _siluetas := {}                # Texture2D -> ImageTexture del halo


static func _silueta(textura: Texture2D) -> ImageTexture:
	if _siluetas.has(textura):
		return _siluetas[textura]
	var imagen := textura.get_image()
	if imagen.is_compressed():
		imagen.decompress()
	var m := MARGEN_HALO
	var w := imagen.get_width() + 2 * m
	var h := imagen.get_height() + 2 * m
	var estructura := PackedByteArray()
	estructura.resize(w * h)
	for y in imagen.get_height():
		for x in imagen.get_width():
			if imagen.get_pixel(x, y).to_rgba32() not in TIERRA:
				estructura[(y + m) * w + x + m] = 1
	estructura = _mayor_pieza(_dilatar(_erosionar(estructura, w, h), w, h), w, h)
	var anillo1 := _dilatar(estructura, w, h)
	var anillo2 := _dilatar(anillo1, w, h)
	var anillo3 := _dilatar(anillo2, w, h)
	var brillo := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for i in w * h:
		var capa := -1
		if estructura[i]:
			capa = 0
		elif anillo1[i]:
			capa = 1
		elif anillo2[i]:
			capa = 2
		elif anillo3[i]:
			capa = 3
		if capa >= 0:
			brillo.set_pixel(i % w, i / w, COLOR_CAPAS[capa])
	var resultado := ImageTexture.create_from_image(brillo)
	_siluetas[textura] = resultado
	return resultado


## 1 donde la casilla o alguna de sus 8 vecinas es 1.
static func _dilatar(m: PackedByteArray, w: int, h: int) -> PackedByteArray:
	var r := PackedByteArray()
	r.resize(w * h)
	for y in h:
		for x in w:
			if m[y * w + x]:
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var nx := x + dx
						var ny := y + dy
						if nx >= 0 and ny >= 0 and nx < w and ny < h:
							r[ny * w + nx] = 1
	return r


## 1 solo donde la casilla y sus 8 vecinas son 1 (el borde de la imagen cuenta como 0).
static func _erosionar(m: PackedByteArray, w: int, h: int) -> PackedByteArray:
	var r := PackedByteArray()
	r.resize(w * h)
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			var todo := true
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if not m[(y + dy) * w + x + dx]:
						todo = false
			if todo:
				r[y * w + x] = 1
	return r


## Se queda con la pieza conectada más grande (descarta la luz del mástil).
static func _mayor_pieza(m: PackedByteArray, w: int, h: int) -> PackedByteArray:
	var visto := PackedByteArray()
	visto.resize(w * h)
	var mejor := PackedInt32Array()
	for inicio in w * h:
		if not m[inicio] or visto[inicio]:
			continue
		var pieza := PackedInt32Array([inicio])
		visto[inicio] = 1
		var i := 0
		while i < pieza.size():
			var actual := pieza[i]
			i += 1
			var x := actual % w
			for vecina: int in [actual - 1 if x > 0 else -1, actual + 1 if x < w - 1 else -1, actual - w, actual + w]:
				if vecina >= 0 and vecina < w * h and m[vecina] and not visto[vecina]:
					visto[vecina] = 1
					pieza.append(vecina)
		if pieza.size() > mejor.size():
			mejor = pieza
	var r := PackedByteArray()
	r.resize(w * h)
	for i in mejor:
		r[i] = 1
	return r
