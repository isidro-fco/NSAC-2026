# indicador_ocupantes.gd
# Etiqueta en la base de cada módulo con un punto por colono que está dentro (oculto); parpadea si trabaja.

class_name IndicadorOcupantes
extends Node2D
## Los colonos se vuelven invisibles al quedarse quietos dentro de un módulo
## (entraron al edificio). Esta etiqueta deja ver quién está dentro: un punto del
## color de su rol por colono, y los que trabajan parpadean.

const SEPARACION := 7.0
const RADIO_PUNTO := 2.5

var mapa: Mapa


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var por_modulo := {}                 # Modulo -> Array[Colono]
	for colono: Colono in mapa.contenedor_colonos.get_children():
		var modulo: Modulo = mapa.cuadricula.celdas_modulo.get(colono.celda)
		if modulo != null and colono.oculto():
			por_modulo.get_or_add(modulo, []).append(colono)
	for modulo: Modulo in por_modulo:
		_dibujar_etiqueta(modulo, por_modulo[modulo])


func _dibujar_etiqueta(modulo: Modulo, colonos: Array) -> void:
	var tam := Vector2(modulo.tam_celdas()) * GestorCuadricula.TAM_CELDA
	var ancho := colonos.size() * SEPARACION + 4.0
	var etiqueta := Rect2(modulo.position + Vector2((tam.x - ancho) / 2.0, tam.y - 13.0), Vector2(ancho, 9))
	draw_rect(etiqueta, Color(UI.FONDO, 0.85))
	draw_rect(etiqueta, Color(0, 0, 0, 0.6), false, 1.0)
	for i in colonos.size():
		var colono: Colono = colonos[i]
		var centro := etiqueta.position + Vector2(2.0 + SEPARACION * (i + 0.5), 4.5)
		var color := colono.datos.color_rol()
		if colono.datos.estado == Enums.EstadoColono.ENFERMO:
			color = color.darkened(0.45)
		if colono.trabajando():
			color = color.lerp(Color.WHITE, 0.5 * absf(sin(colono.tiempo * 4.0)))
		draw_circle(centro, RADIO_PUNTO, color)
