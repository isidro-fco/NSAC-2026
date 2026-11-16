# panel_curiosidades.gd
# Tarjetas "¿Sabías que...?" a la derecha: hasta 2 a la vez, 15 segundos cada una, y se desvanecen.

class_name PanelCuriosidades
extends VBoxContainer
## Escucha EstadoJuego.curiosidad_nueva (ver SistemaCuriosidades).
##                                   ┌ ¿SABÍAS QUE...? ─────────────┐
##                                   │ Atardeceres azules           │
##                                   │ En Marte el cielo es ...     │
##                                   │ Fuente: Space.com ...        │
##                                   │ ▬▬▬▬▬▬▬▬▬▬▭▭▭▭  (tiempo)      │
##                                   └──────────────────────────────┘
## - Fondo un poco transparente, para no tapar del todo el mapa.
## - Cada tarjeta dura DURACION segundos y luego se desvanece. La barra de abajo
##   muestra cuánto le queda.
## - Máximo MAXIMO a la vez: las demás esperan su turno.
## - Clic derecho en una tarjeta: se quita sin abrir nada.
## - Clic en el nombre de la fuente: abre la página de la fuente en el navegador.
## - Clic en una tarjeta: se quita y emite `elegida` (el juego abre la bitácora
##   en la página "Curiosidad", con ese dato marcado). Un clic en una palabra
##   del glosario abre el glosario, no la bitácora.
## - El tiempo no corre mientras el mouse está encima (para leer con calma y
##   pasar por las palabras del glosario) ni mientras `pausado` devuelva true
##   (una ventana o un menú abiertos; entonces el panel se esconde).

const DURACION := 15.0
const MAXIMO := 2
const ANCHO := 360.0
const DESVANECER := 0.8
const OPACIDAD_FONDO := 0.82

signal elegida(dato: Dictionary)

var pausado := func() -> bool: return false
var _cola: Array[Dictionary] = []
var _tarjetas: Array[Dictionary] = []   # { "panel", "barra", "restante", "saliendo", "dato" }
var _glosario_ms := -10000              # cuándo se pulsó una palabra del glosario


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size.x = ANCHO
	EstadoJuego.curiosidad_nueva.connect(mostrar)


func mostrar(dato: Dictionary) -> void:
	_cola.append(dato)
	_sacar_de_la_cola()


func _sacar_de_la_cola() -> void:
	while not _cola.is_empty() and _tarjetas.size() < MAXIMO:
		_tarjetas.append(_crear(_cola.pop_front()))


func _process(delta: float) -> void:
	var detenido: bool = pausado.call()
	visible = not detenido
	if detenido:
		return
	for t in _tarjetas.duplicate():
		var panel: Control = t["panel"]
		if t["saliendo"]:
			continue
		if not panel.get_global_rect().has_point(panel.get_global_mouse_position()):
			t["restante"] -= delta
		(t["barra"] as ColorRect).custom_minimum_size.x = (ANCHO - 28.0) * clampf(t["restante"] / DURACION, 0.0, 1.0)
		if t["restante"] <= 0.0:
			_desvanecer(t)


func _desvanecer(t: Dictionary) -> void:
	t["saliendo"] = true
	var panel: Control = t["panel"]
	var tween := panel.create_tween()
	tween.tween_property(panel, "modulate:a", 0.0, DESVANECER)
	tween.tween_callback(func() -> void:
		_tarjetas.erase(t)
		panel.queue_free()
		_sacar_de_la_cola())


## Clic en la tarjeta (en el panel o en su texto). `del_panel` es true cuando
## llega al panel: solo ahí se acepta el clic izquierdo (aceptarlo en el texto
## le quitaría el clic a las palabras del glosario).
func _al_clic(event: InputEvent, t: Dictionary, del_panel := false) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		# Que no llegue al mapa (ahí el clic derecho cancela la construcción).
		(t["panel"] as Control).accept_event()
		if not event.pressed:
			_cerrar(t)
		return
	if del_panel and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		(t["panel"] as Control).accept_event()       # que no llegue al mapa
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		# Se decide después: si el clic cayó en una palabra del glosario, el
		# texto avisa (meta_clicked) y el clic es del glosario.
		_elegir.call_deferred(t)


func _elegir(t: Dictionary) -> void:
	if Time.get_ticks_msec() - _glosario_ms < 600 or t["saliendo"] or not _tarjetas.has(t):
		return
	_cerrar(t)
	elegida.emit(t["dato"])


## Quita la tarjeta al instante y deja pasar a la siguiente de la cola.
func _cerrar(t: Dictionary) -> void:
	if t["saliendo"] or not _tarjetas.has(t):
		return
	t["saliendo"] = true
	_tarjetas.erase(t)
	(t["panel"] as Control).queue_free()
	Tooltips.cerrar_todo()
	_sacar_de_la_cola()


func _crear(dato: Dictionary) -> Dictionary:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var normal := UI.estilo(Color(UI.FONDO, OPACIDAD_FONDO), Color(UI.BIEN, 0.7), 0, 12, 2)
	var encima := UI.estilo(Color(UI.FONDO, OPACIDAD_FONDO + 0.08), UI.BIEN, 0, 12, 2)
	panel.add_theme_stylebox_override("panel", normal)
	panel.mouse_entered.connect(func() -> void: panel.add_theme_stylebox_override("panel", encima))
	panel.mouse_exited.connect(func() -> void: panel.add_theme_stylebox_override("panel", normal))
	var c := UI.columna(6)
	panel.add_child(c)
	c.add_child(UI.etiqueta_pixel(Idioma.t("¿SABIAS QUE...?"), UI.T_DETALLE, UI.BIEN))
	c.add_child(UI.etiqueta_pixel(Idioma.t(dato["titulo"]), UI.T_TEXTO, UI.ADVERTENCIA))
	# resaltar() devuelve "" si el texto no tiene palabras del glosario.
	var traducido := Idioma.t(str(dato["texto"]))
	var bbcode := EstadoJuego.glosario.resaltar(traducido)
	var texto := UI.texto_glosario(bbcode if bbcode != "" else traducido.replace("[", "[lb]"), 13, UI.TEXTO)
	texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texto.custom_minimum_size.x = ANCHO - 28.0
	texto.meta_clicked.connect(func(_id: Variant) -> void: _glosario_ms = Time.get_ticks_msec())
	c.add_child(texto)
	var fuente := UI.enlace_fuente(str(dato["fuente"]), str(dato.get("enlace", "")))
	fuente.custom_minimum_size.x = ANCHO - 28.0
	c.add_child(fuente)
	var pie := UI.etiqueta_simple(Idioma.t("Clic: ver en la bitácora  ·  Clic derecho: cerrar"), 11, Color(UI.BIEN, 0.85))
	pie.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(pie)
	var barra := ColorRect.new()
	barra.color = Color(UI.BIEN, 0.8)
	barra.custom_minimum_size = Vector2(ANCHO - 28.0, 3)
	barra.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(barra)
	# Aparece con un fundido.
	panel.modulate.a = 0.0
	add_child(panel)
	var tween := panel.create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.4)
	var t := { "panel": panel, "barra": barra, "restante": DURACION, "saliendo": false, "dato": dato }
	panel.gui_input.connect(_al_clic.bind(t, true))
	texto.gui_input.connect(_al_clic.bind(t))
	# La fuente se queda con el clic izquierdo (es un enlace); el derecho también cierra.
	fuente.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
			_al_clic(event, t))
	return t
