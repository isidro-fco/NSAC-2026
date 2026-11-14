# marco_ventana.gd
# Marco grande de las ventanas: unidad de pantalla de Orion con teclas, perillas e interruptores.

class_name MarcoVentana
extends RefCounted
## Marco de las ventanas grandes, copiado de la unidad de pantalla de Orion
## ("Imagen pegada (2).png"): bisel carbón con 12 teclas de función en cada
## lado largo y 8 en cada lado corto (con su marca blanca), 2 perillas con
## escala y 2 botones a la izquierda, y 5 interruptores con protector a la derecha.
##
##   ╔═[sw]═ ▭ ▭ ▭ ▭ ▭ ▭ ▭ ▭ ▭ ▭ ▭ ▭ ════╗   sw: interruptor de la esquina
##   ║ ◉  ▯ ┌────────────────────┐ ▯ [▣] ║   ◉: perillas con escala (2)
##   ║ ◉  ▯ │                    │ ▯ [▣] ║   ▪: botones cuadrados (2)
##   ║ ▪  ▯ │      pantalla      │ ▯ [▣] ║   [▣]: interruptores con protector (5)
##   ║ ▪  ▯ └────────────────────┘ ▯ [▣] ║   ▭ ▯: teclas (12 arriba/abajo, 8 a los lados)
##   ╚═════ ▭ ▭ ▭ ▭ ▭ ▭ ▭ ▭ ▭ ▭ ▭ ▭ ═(o)╝   (o): perilla de la esquina
##
## El bisel liso es un StyleBoxTexture (marco_ventana.png). Las piezas de
## controles_cabina.png se dibujan encima en el evento draw del panel,
## repartidas según el tamaño de la ventana, así nunca quedan cortadas.
## Generado por herramientas/generar_marco_ventana.py.

const BISEL := preload("res://recursos/sprites/interfaz/marco_ventana.png")
const HOJA := preload("res://recursos/sprites/interfaz/controles_cabina.png")
const ESCALA := 2                # cada píxel lógico de la hoja se dibuja 2x2
const MARGEN := 32               # arriba/abajo, = MARGEN en el generador
const MARGEN_LADO := 52          # izquierda/derecha, = MARGEN_LADO en el generador
const EXTRA := 10                # px lógicos que la placa de los lados es más ancha
const TECLAS_LARGO := 12         # teclas arriba y abajo (como en la foto)
const TECLAS_CORTO := 8          # teclas a cada lado
const CONTROLES_IZQUIERDA := ["perilla_0", "perilla_1", "boton", "boton"]
const INTERRUPTORES_DERECHA := 5

## Regiones de la hoja en píxeles lógicos (= REGIONES en el generador).
const REGIONES := {
	"tecla_h": Rect2(0, 0, 10, 5),
	"tecla_v": Rect2(11, 0, 5, 10),
	"marca_h": Rect2(17, 0, 4, 1),
	"marca_v": Rect2(22, 0, 1, 4),
	"protegido": Rect2(24, 0, 9, 9),
	"interruptor": Rect2(34, 0, 7, 10),
	"perilla_0": Rect2(0, 11, 11, 11),
	"perilla_1": Rect2(12, 11, 11, 11),
	"perilla_chica": Rect2(24, 11, 7, 7),
	"boton": Rect2(32, 11, 5, 5),
	"led_verde": Rect2(38, 11, 2, 2),
	"led_ambar": Rect2(41, 11, 2, 2),
	"tornillo": Rect2(38, 14, 3, 3),
	"rotulo": Rect2(0, 23, 5, 1),
	"rotulo_corto": Rect2(6, 23, 3, 1),
}


## Pone el marco en un PanelContainer. `margen` es el espacio libre dentro del bisel.
static func aplicar(panel: PanelContainer, margen := 10) -> void:
	var caja := StyleBoxTexture.new()
	caja.texture = BISEL
	caja.set_texture_margin_all(MARGEN)
	caja.texture_margin_left = MARGEN_LADO
	caja.texture_margin_right = MARGEN_LADO
	caja.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	caja.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	caja.set_content_margin_all(MARGEN + margen)
	caja.content_margin_left = MARGEN_LADO + margen
	caja.content_margin_right = MARGEN_LADO + margen
	panel.add_theme_stylebox_override("panel", caja)
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	panel.draw.connect(_dibujar.bind(panel))
	panel.resized.connect(panel.queue_redraw)


## Dibuja una pieza con su esquina superior izquierda en `pos` (px).
static func _pieza(panel: Control, nombre: String, pos: Vector2) -> void:
	var region: Rect2 = REGIONES[nombre]
	pos = (pos / ESCALA).floor() * ESCALA          # alineado a la rejilla de píxeles lógicos
	panel.draw_texture_rect_region(HOJA, Rect2(pos, region.size * ESCALA), region)


## Centros de `n` piezas repartidas a lo largo de `largo` px.
static func _repartir(largo: float, n: int) -> Array[float]:
	var centros: Array[float] = []
	for i in n:
		centros.append(largo * (i + 0.5) / n)
	return centros


static func _dibujar(panel: Control) -> void:
	var s := panel.size
	var e := float(ESCALA)
	var ancho := s.x - MARGEN_LADO * 2
	var alto := s.y - MARGEN * 2
	var lado := EXTRA * e                          # corrimiento del bisel en los lados

	# Teclas de arriba y abajo con su marca blanca hacia la pantalla.
	for cx in _repartir(ancho, TECLAS_LARGO):
		var x := MARGEN_LADO + cx
		_pieza(panel, "tecla_h", Vector2(x - 5 * e, 7 * e))
		_pieza(panel, "marca_h", Vector2(x - 2 * e, 13 * e))
		_pieza(panel, "tecla_h", Vector2(x - 5 * e, s.y - 12 * e))
		_pieza(panel, "marca_h", Vector2(x - 2 * e, s.y - 14 * e))

	# Teclas de los lados.
	for cy in _repartir(alto, TECLAS_CORTO):
		var y := MARGEN + cy
		_pieza(panel, "tecla_v", Vector2(lado + 7 * e, y - 5 * e))
		_pieza(panel, "marca_v", Vector2(lado + 13 * e, y - 2 * e))
		_pieza(panel, "tecla_v", Vector2(s.x - lado - 12 * e, y - 5 * e))
		_pieza(panel, "marca_v", Vector2(s.x - lado - 14 * e, y - 2 * e))

	# Placa izquierda: 2 perillas con escala y 2 botones cuadrados, con rótulos.
	var i := 0
	for cy in _repartir(alto, CONTROLES_IZQUIERDA.size()):
		var y := MARGEN + cy
		var nombre: String = CONTROLES_IZQUIERDA[i]
		if nombre == "boton":
			_pieza(panel, "boton", Vector2(4 * e, y - 2.5 * e))
			_pieza(panel, "led_verde" if i % 2 == 0 else "led_ambar", Vector2(11 * e, y - 1 * e))
			_pieza(panel, "rotulo_corto", Vector2(5 * e, y + 4 * e))
		else:
			_pieza(panel, nombre, Vector2(3 * e, y - 5.5 * e))
			_pieza(panel, "rotulo", Vector2(6 * e, y + 7 * e))
		i += 1

	# Placa derecha: interruptores con protector y su rótulo debajo.
	for cy in _repartir(alto, INTERRUPTORES_DERECHA):
		var y := MARGEN + cy
		_pieza(panel, "protegido", Vector2(s.x - 13 * e, y - 4.5 * e))
		_pieza(panel, "rotulo", Vector2(s.x - 11 * e, y + 6 * e))

	# Esquinas: interruptor (arriba izquierda) y perilla (abajo derecha) en el
	# bisel, y tornillos en la placa.
	_pieza(panel, "interruptor", Vector2(lado + 7 * e, 6 * e))
	_pieza(panel, "perilla_chica", Vector2(s.x - lado - 14 * e, s.y - 14 * e))
	for pos: Vector2 in [Vector2(2, 2), Vector2(s.x / e - 5, 2), Vector2(2, s.y / e - 5), Vector2(s.x / e - 5, s.y / e - 5)]:
		_pieza(panel, "tornillo", pos * e)
