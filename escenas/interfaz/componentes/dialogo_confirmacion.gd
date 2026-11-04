class_name DialogoConfirmacion
extends ColorRect
## Diálogo modal centrado sobre un fondo oscurecido.
## Con crear_confirmacion() trae los botones Cancelar / Confirmar.

signal cerrado

const ESCENA := "res://escenas/interfaz/componentes/dialogo_confirmacion.tscn"

## Si es false, Escape no lo cierra (diálogo de fin de partida).
var cancelable := true


static func crear() -> DialogoConfirmacion:
	return load(ESCENA).instantiate()


static func crear_confirmacion(titulo: String, texto: String, al_confirmar: Callable) -> DialogoConfirmacion:
	var dialogo := crear()
	var botones := Hud.fila()
	botones.add_child(Hud.expandir(Hud.boton("Cancelar", dialogo.cerrar)))
	botones.add_child(Hud.expandir(Hud.boton_primario("Confirmar", func() -> void:
		dialogo.cerrar()
		al_confirmar.call())))
	dialogo.configurar(titulo, texto, botones)
	return dialogo


func configurar(titulo: String, texto: String, botones: Control) -> void:
	color = Color(0, 0, 0, 0.6)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centro)
	var caja := PanelContainer.new()
	caja.custom_minimum_size = Vector2(440, 0)
	caja.add_theme_stylebox_override("panel", Hud.estilo_elevado(Hud.FONDO, Hud.BORDE, Hud.RADIO + 4, 20))
	centro.add_child(caja)
	var c := Hud.columna(12)
	caja.add_child(c)
	c.add_child(Hud.etiqueta(titulo, 18))
	c.add_child(Hud.parrafo(texto, 14, Hud.TEXTO))
	c.add_child(botones)


func cerrar() -> void:
	if is_queued_for_deletion():
		return
	queue_free()
	cerrado.emit()
