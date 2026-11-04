class_name DatosModulo
extends Resource
## Definición de un tipo de módulo. Cada uno vive en datos/modulos/<id>.tres.

const CARPETA := "res://datos/modulos/%s.tres"

@export var id := ""
@export var nombre := ""
@export var tam := Vector2i.ONE
@export var letra := ""
@export var color := Color.WHITE
## Escena propia (comando, descanso, almacén, pasillo); null = modulo.tscn.
@export var escena: PackedScene
## Módulo inicial: no aparece en el catálogo ni se puede demoler.
@export var es_base := false
@export var dinero := 0
@export var materiales := 0
## recurso -> unidades producidas por sol
@export var produce: Dictionary = {}


static func obtener(id_modulo: String) -> DatosModulo:
	return load(CARPETA % id_modulo)


## Módulos que se pueden construir, en el orden de balance.tres -> catalogo.
static func construibles() -> Array[DatosModulo]:
	var lista: Array[DatosModulo] = []
	for id_modulo: String in EstadoJuego.datos_balance.catalogo:
		lista.append(obtener(id_modulo))
	return lista


func coste_demoler() -> int:
	return int(ceil(dinero * EstadoJuego.datos_balance.fraccion_coste_demoler))


func es_pasillo() -> bool:
	return id == "pasillo"
