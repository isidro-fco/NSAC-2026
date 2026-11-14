# elemento_mapa.gd
# Clase base de lo que ocupa casillas del mapa (módulos y obstáculos): posición, tamaño y datos de demolición.

class_name ElementoMapa
extends Node2D
## Algo colocado sobre la cuadrícula: un Modulo o un Obstaculo. Define lo que
## necesitan GestorCuadricula y el modo demolición del Mapa.

var origen := Vector2i.ZERO


## Coloca el elemento con su esquina superior izquierda en `origen_celda`.
func _colocar_en(origen_celda: Vector2i) -> void:
	origen = origen_celda
	position = Vector2(origen) * GestorCuadricula.TAM_CELDA


func tam_celdas() -> Vector2i:
	return Vector2i.ONE


## Dinero que cuesta demolerlo.
func coste_demoler() -> int:
	return 0


## Materiales que se recuperan al demolerlo.
func materiales_al_demoler() -> int:
	return 0


## Nombre que se muestra en el aviso de demolición.
func nombre() -> String:
	return ""
