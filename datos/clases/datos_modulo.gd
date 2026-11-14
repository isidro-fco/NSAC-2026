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
## Parte del sprite que se usa como ícono (el emblema del centro del módulo) en
## el panel de tripulación. Vacía = un cuadro de LADO_ICONO px en el centro.
@export var region_icono := Rect2()
## Módulo inicial: no aparece en el catálogo ni se puede demoler.
@export var es_base := false
@export var dinero := 0
@export var materiales := 0
## recurso -> unidades producidas por sol (energía en kW).
@export var produce: Dictionary = {}
## Potencia eléctrica que consume mientras está construido (kW).
@export var consumo_kw := 0.0
## Línea de producción especial para la tarjeta de construcción (p. ej. el reciclaje de agua).
@export var nota_produccion := ""


## Lado del ícono en píxeles del sprite; una región más chica se dibuja a 2x.
const LADO_ICONO := 24


static func obtener(id_modulo: String) -> DatosModulo:
	return load("res://datos/modulos/%s.tres" % id_modulo)


## Región del sprite para el ícono: la de region_icono o el centro del sprite.
func region_del_icono() -> Rect2:
	if region_icono.has_area() or textura == null:
		return region_icono
	var lado := minf(LADO_ICONO, minf(textura.get_width(), textura.get_height()))
	return Rect2((textura.get_size() - Vector2(lado, lado)) / 2.0, Vector2(lado, lado))


func coste_demoler() -> int:
	return int(ceil(dinero * EstadoJuego.datos_balance.fraccion_coste_demoler))


func es_pasillo() -> bool:
	return id == "pasillo"
