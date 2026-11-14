# dialogo_confirmacion.gd
# Diálogo modal de confirmación con título, texto, tabla opcional de costos y botones.

class_name DialogoConfirmacion
extends ColorRect
## Diálogo modal centrado sobre un fondo oscurecido, según docs/diseno/aviso.png:
##   ┌──────────────────────────────────────────┐
##   │ ¿Excavar esta roca?                      │   título pixel 16
##   │ Obstáculo natural                        │   texto (subtítulo)
##   │ ┌──────────────────────────────────────┐ │
##   │ │ Recurso            Cambio    Quedará │ │   tabla opcional (filas)
##   │ │ Costo del trabajo    -$40  $1,000 a…│ │
##   │ └──────────────────────────────────────┘ │
##   │ [ Cancelar ]          [ Demoler ]        │
##   └──────────────────────────────────────────┘
## Si no recibe botones, trae Cancelar / `texto_confirmar`, y este último llama
## a `al_confirmar`. Con `peligro` el botón de confirmar se pinta en rojo.
## Los eventos (HU-08) usan el mismo diálogo: insertar() añade una tabla por opción.

signal cerrado

## Si es false, Escape no lo cierra (diálogo de fin de partida).
var cancelable := true
var caja: PanelContainer
var cuerpo: VBoxContainer
var fila_botones: Control


## `filas`: cada una es [recurso, cambio, quedará] (textos ya formateados).
func _init(titulo: String, texto: String, al_confirmar := Callable(), botones: Control = null,
		filas: Array = [], texto_confirmar := "Confirmar", peligro := false) -> void:
	if botones == null:
		botones = UI.fila(4)
		var cancelar := boton("Cancelar", cerrar)
		cancelar.add_theme_color_override("font_color", UI.TEXTO_SUAVE)
		var confirmar := boton(texto_confirmar, func() -> void:
			cerrar()
			al_confirmar.call(), true, UI.CRITICO if peligro else UI.ACENTO)
		for b: Button in [cancelar, confirmar]:
			botones.add_child(UI.expandir(b))
	color = Color(0, 0, 0, 0.6)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centro)
	caja = PanelContainer.new()
	caja.custom_minimum_size = Vector2(460, 0)
	UI.aplicar_marco(caja, 24)
	centro.add_child(caja)
	var c := UI.columna(14)
	cuerpo = c
	fila_botones = botones
	caja.add_child(c)
	var cabecera := UI.columna(10)
	var etiqueta_titulo := UI.etiqueta_pixel(titulo, 16)
	etiqueta_titulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cabecera.add_child(etiqueta_titulo)
	if texto != "":
		if filas.is_empty():
			cabecera.add_child(UI.parrafo(texto, 14, UI.TEXTO))
		else:
			cabecera.add_child(UI.etiqueta_pixel(texto, 8))
	c.add_child(cabecera)
	if not filas.is_empty():
		c.add_child(tabla(filas))
	c.add_child(botones)


## Botón recto de la fila inferior, como en el aviso. `activo` lo rellena con `color_activo`.
static func boton(texto: String, accion: Callable, activo := false, color_activo := UI.ACENTO) -> Button:
	var b := UI.boton_pixel(texto, accion)
	UI.pintar_boton_pixel(b, activo, color_activo, UI.TARJETA, 0)
	b.custom_minimum_size = Vector2(0, 38)
	return b


## Añade un control encima de los botones.
func insertar(control: Control) -> void:
	cuerpo.add_child(control)
	cuerpo.move_child(control, fila_botones.get_index())


## Tabla Recurso / Cambio / Quedará con marco, como en el prototipo.
static func tabla(filas: Array, cabecera: Array = ["Recurso", "Cambio", "Quedará"]) -> Control:
	var marco := PanelContainer.new()
	marco.add_theme_stylebox_override("panel", UI.estilo(UI.FONDO.darkened(0.15), UI.FONDO_CLARO, 0, 12, 2))
	var rejilla := GridContainer.new()
	rejilla.columns = 3
	rejilla.add_theme_constant_override("h_separation", 20)
	rejilla.add_theme_constant_override("v_separation", 14)
	marco.add_child(rejilla)
	var todas: Array = [cabecera] + filas
	for i in todas.size():
		for j in 3:
			var celda := UI.etiqueta_pixel(str(todas[i][j]), 8, UI.TEXTO_SUAVE if i == 0 else UI.TEXTO)
			if j == 0:
				celda.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			else:
				celda.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			rejilla.add_child(celda)
	return marco


func cerrar() -> void:
	if not is_queued_for_deletion():
		queue_free()
		cerrado.emit()
