class_name Obstaculo
extends Node2D
## Roca o cráter que bloquea casillas. Se puede demoler para obtener materiales.

var origen := Vector2i.ZERO
var tam := Vector2i.ONE
var textura: Texture2D


func _init(origen_celda: Vector2i, tam_celdas_: Vector2i, textura_: Texture2D) -> void:
	origen = origen_celda
	tam = tam_celdas_
	textura = textura_
	position = Vector2(origen) * GestorCuadricula.TAM_CELDA


func tam_celdas() -> Vector2i:
	return tam


func coste_demoler() -> int:
	return EstadoJuego.datos_balance.demoler_obstaculo_dinero


func materiales_al_demoler() -> int:
	return tam.x * tam.y * EstadoJuego.datos_balance.demoler_obstaculo_materiales


## Los cráteres usan las texturas crater*.png; el resto son rocas.
func es_crater() -> bool:
	return textura != null and textura.resource_path.get_file().begins_with("crater")


func nombre() -> String:
	return "Obstáculo natural"


func _draw() -> void:
	draw_texture(textura, Vector2.ZERO)
