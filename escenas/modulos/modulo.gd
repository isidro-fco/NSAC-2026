# modulo.gd
# Módulo construido en el mapa: posición, tamaño, costo de demolición y dibujo.

class_name Modulo
extends ElementoMapa
## Módulo colocado en el mapa. Sus datos vienen de datos/modulos/<id>.tres.
## Demolerlo no devuelve materiales.

var datos: DatosModulo
## Cuartos de vuelta (0..3). Solo los pasillos rotan (Q al colocarlos).
var rotacion := 0


func _init(origen_celda: Vector2i, datos_modulo: DatosModulo) -> void:
	datos = datos_modulo
	_colocar_en(origen_celda)
	EstadoJuego.partida_terminada.connect(func(_motivo: String) -> void: queue_redraw())


func tam_celdas() -> Vector2i:
	return datos.tam


func coste_demoler() -> int:
	return datos.coste_demoler()


func nombre() -> String:
	return datos.nombre


## Dibuja `textura` en `rect` girada `cuartos` cuartos de vuelta alrededor de su
## centro (la usan el módulo y la vista previa al colocar).
static func dibujar_textura(lienzo: CanvasItem, textura: Texture2D, rect: Rect2, cuartos: int, tinte: Color) -> void:
	if cuartos % 4 == 0:
		lienzo.draw_texture_rect(textura, rect, false, tinte)
		return
	lienzo.draw_set_transform(rect.get_center(), cuartos * PI / 2.0)
	lienzo.draw_texture_rect(textura, Rect2(-rect.size / 2.0, rect.size), false, tinte)
	lienzo.draw_set_transform(Vector2.ZERO)


func _draw() -> void:
	if datos.es_pasillo():
		return                      # los dibuja CapaPasillos, bajo los demás módulos
	var rect := Rect2(Vector2.ZERO, Vector2(datos.tam) * GestorCuadricula.TAM_CELDA)
	var tinte := Color(0.45, 0.45, 0.5) if EstadoJuego.modulos_apagados else Color.WHITE
	if datos.textura:
		dibujar_textura(self, datos.textura, rect, rotacion, tinte)
		return
	draw_rect(rect, datos.color.darkened(0.35) * tinte)
	draw_rect(rect.grow(-3), datos.color * tinte)
	draw_rect(rect, Color(0, 0, 0, 0.5), false, 2.0)
	var fuente := ThemeDB.fallback_font
	var ancho := fuente.get_string_size(datos.letra, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	draw_string(fuente, rect.get_center() + Vector2(-ancho / 2.0, 6.3), datos.letra,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0, 0, 0, 0.7))

