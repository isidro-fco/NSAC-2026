# menu_glosario.gd
# Menú del glosario estilo terminal: términos descubiertos y su ficha; pausa el tiempo mientras está abierto.

class_name MenuGlosario
extends MenuModulo
## HU-12: glosario con aspecto de terminal de datos. A la izquierda los términos
## descubiertos; a la derecha la ficha del seleccionado. Mientras está abierto
## el tiempo se detiene; al cerrarlo la pausa vuelve a como estaba.
## Las dos columnas usan las pantallas de cabina del Módulo de Comando (ver Cabina).

const VERDE := UI.BIEN                       # Teal Signal

var seleccionado := ""
var pausa_previa := false


func _init() -> void:
	con_cabecera = false     # sin título: como la sala de comandos


func _ready() -> void:
	pausa_previa = GestorTiempo.en_pausa
	GestorTiempo.en_pausa = true


func _exit_tree() -> void:
	GestorTiempo.en_pausa = pausa_previa


func seleccionar(id: String) -> void:
	seleccionado = id
	_pedir_reconstruccion()


func construir() -> void:
	var glosario := EstadoJuego.glosario
	var descubiertos: Array = glosario.descubiertos.keys()
	if seleccionado == "" and not descubiertos.is_empty():
		seleccionado = descubiertos[0]
	var cuerpo := UI.fila(16)
	cuerpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	contenido.add_child(cuerpo)

	# Izquierda: los términos descubiertos.
	var izquierda := UI.columna(6)
	izquierda.custom_minimum_size = Vector2(300, 0)
	cuerpo.add_child(izquierda)
	izquierda.add_child(Cabina.encabezado(Idioma.t("> Archivo de datos"), descubiertos.size(),
		Idioma.t("de %d") % glosario.terminos.size()))
	var pantalla := Cabina.pantalla()
	izquierda.add_child(pantalla)
	var botones := UI.columna(4)
	for id: String in descubiertos:
		var b := Cabina.boton_opcion(Idioma.t(glosario.termino(id)["nombre"]), seleccionar.bind(id), id == seleccionado, 28)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", UI.T_DETALLE)
		botones.add_child(b)
	if descubiertos.is_empty():
		botones.add_child(Cabina.vacio(Idioma.t("No se han encontrado palabras. Aparecen al leerlas en la interfaz.")))
	pantalla.add_child(vista_con_scroll(Cabina.con_margen_scroll(botones)))

	# Derecha: la ficha del término elegido, como una terminal.
	var derecha := UI.columna(6)
	cuerpo.add_child(UI.expandir(derecha))
	var termino := glosario.termino(seleccionado) if seleccionado != "" else {}
	derecha.add_child(Cabina.encabezado(Idioma.t("> Ficha"), -1, Idioma.t("Tiempo en pausa")))
	var ficha_pantalla := Cabina.pantalla(8)
	derecha.add_child(ficha_pantalla)
	var ficha := UI.columna(12)
	if termino.is_empty():
		ficha.add_child(Cabina.vacio(Idioma.t("Elige un término del archivo.")))
	else:
		var titulo := UI.etiqueta_pixel("> " + Cabina.mayus(termino["nombre"]), 16, VERDE)
		titulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ficha.add_child(titulo)
		var linea := ColorRect.new()
		linea.color = Color(VERDE, 0.35)
		linea.custom_minimum_size = Vector2(0, 2)
		ficha.add_child(linea)
		ficha.add_child(UI.parrafo(termino["corto"], 15, UI.TEXTO))
		ficha.add_child(UI.parrafo(termino["detalle"], 14, VERDE.lerp(UI.TEXTO, 0.6)))
	ficha_pantalla.add_child(vista_con_scroll(Cabina.con_margen_scroll(ficha)))
