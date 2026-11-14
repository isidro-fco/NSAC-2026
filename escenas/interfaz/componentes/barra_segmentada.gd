# barra_segmentada.gd
# Barra de nivel hecha de cuadritos que se llenan según una proporción de 0 a 1.

class_name BarraSegmentada
extends Control
## Barra de nivel hecha de cuadritos (docs/diseno/Principal.pdf).
## Se pintan llenos tantos cuadritos como indique `proporcion` (0..1).

const LADO := 6
const SEPARACION := 3

var segmentos := 12
var proporcion := 0.0:
	set(valor):
		proporcion = clampf(valor, 0.0, 1.0)
		queue_redraw()
var color := UI.TEXTO:
	set(valor):
		color = valor
		queue_redraw()


## Con `expandir`, los cuadritos que caben dependen del ancho disponible (barra del sol).
func _init(n_segmentos := 12, expandir := false) -> void:
	segmentos = n_segmentos
	custom_minimum_size = Vector2(segmentos * (LADO + SEPARACION) - SEPARACION, LADO)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL if expandir else Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var total := maxi(segmentos, int((size.x + SEPARACION) / (LADO + SEPARACION)))
	var inicio := floorf((size.x - (total * (LADO + SEPARACION) - SEPARACION)) / 2.0)
	var llenos := int(round(proporcion * total))
	for i in total:
		var rect := Rect2(inicio + i * (LADO + SEPARACION), 0, LADO, LADO)
		draw_rect(rect, color if i < llenos else UI.SILENCIADO)
