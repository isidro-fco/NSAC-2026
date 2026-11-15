# interruptor_pixel.gd
# Interruptor deslizante de dos posiciones dibujado en pixel art (p. ej. Construir / Demoler).

class_name InterruptorPixel
extends Control
## Interruptor de cabina de dos posiciones. La palanca (un bloque con bisel y
## estrías) tapa la opción activa y lleva su nombre; la otra se lee apagada
## sobre la ranura. Un clic en cualquier parte la desliza al otro lado.
##   ┏━━━━━━━━━━━━━━━━┳━━━━━━━━━━━━━━━━┓
##   ┃▓ CONSTRUIR ▓▓▓▓▓┃    DEMOLER     ┃     ▓ palanca con bisel y estrías
##   ┗━━━━━━━━━━━━━━━━┻━━━━━━━━━━━━━━━━┛

signal cambiado(indice: int)

const PIXEL := 2.0                    # tamaño de un "píxel" del dibujo
const DURACION := 0.12                # segundos que tarda la palanca en deslizarse

var opciones: Array[String] = []
var colores: Array[Color] = []
var indice := 0
var _posicion := 0.0                  # 0 = izquierda, 1 = derecha (animada)


func _init(textos: Array[String], colores_opcion: Array[Color], inicial := 0, alto := 40.0) -> void:
	opciones = textos
	colores = colores_opcion
	indice = inicial
	_posicion = float(inicial)
	custom_minimum_size = Vector2(0, alto)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_NONE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tooltip_text = "Clic: cambiar a %s" % opciones[1 - indice].capitalize()


func _gui_input(evento: InputEvent) -> void:
	if evento is InputEventMouseButton and evento.pressed and evento.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		elegir(1 - indice)


## Desliza la palanca a `nuevo` y avisa cuando llega.
func elegir(nuevo: int) -> void:
	if nuevo == indice:
		return
	indice = nuevo
	var tween := create_tween()
	tween.tween_method(func(v: float) -> void:
		_posicion = v
		queue_redraw(), _posicion, float(nuevo), DURACION)
	tween.tween_callback(cambiado.emit.bind(nuevo))


func _draw() -> void:
	var p := PIXEL
	var s := size
	var mitad := floorf(s.x / 2.0 / p) * p
	var fondo := Cabina.REJILLA_FONDO
	var borde := Cabina.REJILLA_BORDE

	# Ranura: marco exterior oscuro, borde claro y fondo hundido (sombra arriba).
	draw_rect(Rect2(Vector2.ZERO, s), Color("#05080c"))
	draw_rect(Rect2(Vector2(p, p), s - Vector2(p, p) * 2), borde)
	draw_rect(Rect2(Vector2(p, p) * 2, s - Vector2(p, p) * 4), fondo)
	draw_rect(Rect2(Vector2(p, p) * 2, Vector2(s.x - p * 4, p)), Color.BLACK)
	# Remaches en las cuatro esquinas de la ranura.
	for esquina: Vector2 in [Vector2(p * 3, p * 3), Vector2(s.x - p * 4, p * 3),
			Vector2(p * 3, s.y - p * 4), Vector2(s.x - p * 4, s.y - p * 4)]:
		draw_rect(Rect2(esquina, Vector2(p, p)), borde.lightened(0.3))

	# Textos apagados de las dos opciones, sobre la ranura.
	var fuente := UI.fuente_pixel()
	var tam := UI.T_TEXTO
	for i in opciones.size():
		var centro := mitad * (i + 0.5) + (p if i == 1 else 0.0)
		_texto(fuente, opciones[i], Vector2(centro, s.y / 2.0), tam, Color(UI.TEXTO_SUAVE, 0.7))

	# Palanca: bloque del color de la opción con bisel (luz arriba e izquierda,
	# sombra abajo y derecha) y estrías de agarre en el borde que mira al centro.
	var color: Color = colores[0].lerp(colores[1], _posicion)
	var x := floorf(lerpf(p * 2, s.x - mitad, _posicion) / p) * p
	var palanca := Rect2(Vector2(x, p * 2), Vector2(mitad - p * 2, s.y - p * 4))
	draw_rect(palanca.grow(p), Color("#05080c"))
	draw_rect(palanca, color)
	draw_rect(Rect2(palanca.position, Vector2(palanca.size.x, p)), color.lightened(0.35))
	draw_rect(Rect2(palanca.position, Vector2(p, palanca.size.y)), color.lightened(0.2))
	draw_rect(Rect2(palanca.position + Vector2(0, palanca.size.y - p), Vector2(palanca.size.x, p)), color.darkened(0.4))
	draw_rect(Rect2(palanca.position + Vector2(palanca.size.x - p, 0), Vector2(p, palanca.size.y)), color.darkened(0.3))
	var agarre := palanca.end.x - p * 6 if _posicion < 0.5 else palanca.position.x + p * 3
	for k in 2:
		var estria := Rect2(Vector2(agarre + k * p * 2, palanca.position.y + p * 3), Vector2(p, palanca.size.y - p * 6))
		draw_rect(estria, color.darkened(0.35))
		draw_rect(Rect2(estria.position + Vector2(p, 0), estria.size), color.lightened(0.25))
	# Nombre de la opción activa sobre la palanca.
	var activo := opciones[0] if _posicion < 0.5 else opciones[1]
	# Centrado en la parte lisa de la palanca (sin las estrías).
	var centro_texto := palanca.position.x + (palanca.size.x - p * 7) / 2.0 + (p * 7 if _posicion >= 0.5 else 0.0)
	_texto(fuente, activo, Vector2(centro_texto, s.y / 2.0), tam, Cabina.REJILLA_FONDO)


## Texto centrado en `centro` (horizontal y vertical).
func _texto(fuente: Font, texto: String, centro: Vector2, tam: int, color: Color) -> void:
	var ancho := fuente.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
	var base := centro.y + (fuente.get_ascent(tam) - fuente.get_descent(tam)) / 2.0
	draw_string(fuente, Vector2(floorf(centro.x - ancho / 2.0), floorf(base)), texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, color)
