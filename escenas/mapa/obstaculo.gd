class_name Obstaculo
extends Node2D
## Roca o cráter que bloquea casillas. Se puede demoler para obtener materiales.

var origen := Vector2i.ZERO
var tam := Vector2i.ONE
var textura: Texture2D


func configurar(origen_celda: Vector2i, tam_celdas: Vector2i, textura_obstaculo: Texture2D) -> void:
	origen = origen_celda
	tam = tam_celdas
	textura = textura_obstaculo
	position = Vector2(origen) * GestorCuadricula.TAM_CELDA
	queue_redraw()


func tam_celdas() -> Vector2i:
	return tam


func coste_demoler() -> int:
	return EstadoJuego.datos_balance.demoler_obstaculo_dinero


func materiales_al_demoler() -> int:
	return tam.x * tam.y * EstadoJuego.datos_balance.demoler_obstaculo_materiales


func nombre() -> String:
	return "Obstáculo natural"


func _draw() -> void:
	if textura:
		draw_texture(textura, Vector2.ZERO)
