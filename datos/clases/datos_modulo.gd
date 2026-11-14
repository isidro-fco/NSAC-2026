# datos_modulo.gd
# Recurso que define un tipo de módulo: nombre, tamaño, sprite, costo y producción.

class_name DatosModulo
extends Resource
## Definición de un tipo de módulo. Cada uno vive en datos/modulos/<id>.tres.

@export var id := ""
@export var nombre := ""
@export var tam := Vector2i.ONE
@export var letra := ""
@export var color := Color.WHITE
## Sprite del módulo; sin él se dibuja un bloque de color con la letra.
@export var textura: Texture2D
## Módulo inicial: no aparece en el catálogo ni se puede demoler.
@export var es_base := false
@export var dinero := 0
@export var materiales := 0
## recurso -> unidades producidas por sol
@export var produce: Dictionary = {}


static func obtener(id_modulo: String) -> DatosModulo:
	return load("res://datos/modulos/%s.tres" % id_modulo)


func coste_demoler() -> int:
	return int(ceil(dinero * EstadoJuego.datos_balance.fraccion_coste_demoler))


func es_pasillo() -> bool:
	return id == "pasillo"
