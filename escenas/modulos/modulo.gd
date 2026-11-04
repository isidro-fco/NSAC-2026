class_name Modulo
extends Node2D
## Módulo colocado en el mapa. Sus datos vienen de datos/modulos/<id>.tres;
## las escenas heredadas (comando, descanso, almacén, pasillo) pueden fijar
## una textura propia.

@export var textura: Texture2D

var datos: DatosModulo
var origen := Vector2i.ZERO


func _ready() -> void:
	EstadoJuego.partida_terminada.connect(func(_motivo: String) -> void: queue_redraw())


func configurar(origen_celda: Vector2i, datos_modulo: DatosModulo) -> void:
	datos = datos_modulo
	origen = origen_celda
	position = Vector2(origen) * GestorCuadricula.TAM_CELDA
	queue_redraw()


func tam_celdas() -> Vector2i:
	return datos.tam


func coste_demoler() -> int:
	return datos.coste_demoler()


func materiales_al_demoler() -> int:
	return 0


func nombre() -> String:
	return datos.nombre


func _draw() -> void:
	if datos == null:
		return
	var rect := Rect2(Vector2.ZERO, Vector2(datos.tam) * GestorCuadricula.TAM_CELDA)
	var tinte := Color(0.45, 0.45, 0.5) if EstadoJuego.modulos_apagados else Color.WHITE
	if textura:
		draw_texture_rect(textura, rect, false, tinte)
		return
	draw_rect(rect, datos.color.darkened(0.35) * tinte)
	draw_rect(rect.grow(-3), datos.color * tinte)
	draw_rect(rect, Color(0, 0, 0, 0.5), false, 2.0)
	if datos.letra != "":
		var fuente := ThemeDB.fallback_font
		var tam_letra := 18
		var ancho_texto := fuente.get_string_size(datos.letra, HORIZONTAL_ALIGNMENT_LEFT, -1, tam_letra)
		var pos := rect.get_center() + Vector2(-ancho_texto.x / 2.0, tam_letra * 0.35)
		draw_string(fuente, pos, datos.letra, HORIZONTAL_ALIGNMENT_LEFT, -1, tam_letra, Color(0, 0, 0, 0.7))
