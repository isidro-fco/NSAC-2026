# menu_glosario.gd
# Menú del glosario estilo terminal: términos descubiertos y su ficha; pausa el tiempo mientras está abierto.

class_name MenuGlosario
extends MenuModulo
## HU-12: glosario con aspecto de terminal de datos. A la izquierda los términos
## descubiertos; a la derecha la ficha del seleccionado. Mientras está abierto
## el tiempo se detiene; al cerrarlo la pausa vuelve a como estaba.

const VERDE := UI.BIEN                       # Teal Signal
const FONDO_TERMINAL := Color("#111a22")     # Deep Space muy oscuro

var seleccionado := ""
var pausa_previa := false


func _ready() -> void:
	pausa_previa = GestorTiempo.en_pausa
	GestorTiempo.en_pausa = true


func _exit_tree() -> void:
	GestorTiempo.en_pausa = pausa_previa


func seleccionar(id: String) -> void:
	seleccionado = id
	_pedir_reconstruccion()


func construir() -> void:
	var pantalla := PanelContainer.new()
	pantalla.add_theme_stylebox_override("panel", UI.estilo(FONDO_TERMINAL, VERDE.darkened(0.5), UI.RADIO, 16, 2))
	pantalla.size_flags_vertical = Control.SIZE_EXPAND_FILL
	contenido.add_child(pantalla)
	var cuerpo := UI.fila(16)
	pantalla.add_child(cuerpo)

	var lista := UI.columna(6)
	lista.custom_minimum_size = Vector2(300, 0)
	cuerpo.add_child(lista)
	lista.add_child(UI.etiqueta_pixel("> ARCHIVO DE DATOS", 8, VERDE.darkened(0.3)))
	var descubiertos: Array = EstadoJuego.glosario.descubiertos.keys()
	if descubiertos.is_empty():
		lista.add_child(UI.etiqueta_pixel("No se han encontrado palabras", 8, VERDE))
	elif seleccionado == "":
		seleccionado = descubiertos[0]
	var botones := UI.columna(4)
	for id: String in descubiertos:
		var b := UI.boton_pixel(EstadoJuego.glosario.termino(id)["nombre"], seleccionar.bind(id), id == seleccionado)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		botones.add_child(b)
	lista.add_child(vista_con_scroll(botones))

	var ficha := UI.columna(12)
	cuerpo.add_child(UI.expandir(ficha))
	if seleccionado != "":
		var termino := EstadoJuego.glosario.termino(seleccionado)
		ficha.add_child(UI.etiqueta_pixel("> " + termino["nombre"], 16, VERDE))
		ficha.add_child(UI.parrafo(termino["corto"], 15, UI.TEXTO))
		ficha.add_child(UI.parrafo(termino["detalle"], 14, VERDE.lerp(UI.TEXTO, 0.6)))
