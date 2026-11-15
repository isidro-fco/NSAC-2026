# gestor_tooltips.gd
# Autoload Tooltips: tooltips enriquecidos que se fijan y se encadenan, al estilo de Crusader Kings 3.

extends CanvasLayer
## Cómo se usa:
##   Tooltips.registrar(control, func() -> Dictionary: return {
##       "titulo": "Oxígeno", "texto": "Hay 100 de 180 kg...", "sugerencia": "..." })
## Los términos del glosario que aparecen en el texto se resaltan solos. Los
## textos resaltados del resto de la interfaz (UI.texto_glosario) también abren
## su tooltip al pasar el mouse.
##
## Reglas:
##   1. Al dejar el mouse DEMORA segundos sobre algo, aparece su tooltip.
##   2. Abajo se llena una barra; a los SEGUNDOS_FIJAR segundos el tooltip se
##      fija (borde verde) y ya se puede mover el mouse dentro de él.
##   3. Dentro de un tooltip fijado, pasar sobre una palabra resaltada abre otro
##      tooltip encima: así se encadenan.
##   4. Un tooltip sigue abierto mientras el mouse esté sobre lo que lo abrió, o
##      dentro de él si está fijado, o en alguno de los que abrió después.
##      Si no, se cierra (y con él los que dependían de él).
## Esc o un clic fuera de los tooltips los cierra todos; también se cierran
## cuando se abre una ventana (evento, menú o confirmación).
## "Estar sobre" algo se comprueba con el control que Godot tiene bajo el mouse
## (no solo con su rectángulo): así, si una ventana tapa el origen, cuenta como
## que el mouse ya no está ahí. Las señales meta_hover_ended de RichTextLabel no
## siempre llegan (al salir rápido del texto), por eso no se confía solo en ellas.

const DEMORA := 0.35                  # s sobre un control para abrir su tooltip
const DEMORA_TERMINO := 0.25          # s sobre una palabra resaltada
const SEGUNDOS_FIJAR := 2.0
const GRACIA := 0.2                   # s antes de cerrar (para cruzar del origen al tooltip)
const ANCHO := 320.0
const SEPARACION_MOUSE := Vector2(16, 20)

## Cada nivel: { "panel", "barra", "fijado", "t", "muerto",
##   "control" (origen si es un control) o "rtl" + "meta" (origen si es una palabra),
##   "sobre_meta" (el mouse sigue en esa palabra) }
var pila: Array[Dictionary] = []
var _proveedores := {}                # Control -> Callable
var _candidato: Control = null        # control registrado bajo el mouse
var _candidato_t := 0.0
var _meta_rtl: RichTextLabel = null   # palabra resaltada bajo el mouse
var _meta_id := ""
var _meta_t := 0.0
var _raiz := Control.new()


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.theme = UI.tema()
	add_child(_raiz)


# --- API ------------------------------------------------------------------

## `contenido` devuelve { "titulo", "texto", "sugerencia"?, "pie"? } al momento de abrir.
func registrar(control: Control, contenido: Callable) -> void:
	_proveedores[control] = contenido
	control.tooltip_text = ""
	control.mouse_entered.connect(func() -> void:
		_candidato = control
		_candidato_t = 0.0)
	control.mouse_exited.connect(func() -> void:
		if _candidato == control:
			_candidato = null)
	control.tree_exiting.connect(func() -> void:
		_proveedores.erase(control)
		if _candidato == control:
			_candidato = null)


## Lo llaman los RichTextLabel de UI.texto_glosario al entrar y salir de una palabra.
func entrar_termino(rtl: RichTextLabel, id: String) -> void:
	_meta_rtl = rtl
	_meta_id = id
	_meta_t = 0.0


func salir_termino(rtl: RichTextLabel, id: String) -> void:
	if _meta_rtl == rtl and _meta_id == id:
		_meta_rtl = null
	for nivel in pila:
		if nivel.get("rtl") == rtl and nivel.get("meta") == id:
			nivel["sobre_meta"] = false


func cerrar_todo() -> void:
	_cerrar_desde(0)


# --- Ciclo ----------------------------------------------------------------

func _process(delta: float) -> void:
	# Palabra "atascada": la señal de salida no llegó pero el mouse ya no está en ese texto.
	if _meta_rtl != null and (not is_instance_valid(_meta_rtl) or not _bajo_mouse(_meta_rtl)):
		_meta_rtl = null
	if _candidato != null and (not is_instance_valid(_candidato) or not _bajo_mouse(_candidato)):
		_candidato = null
	_abrir_si_toca(delta)
	if pila.is_empty():
		return
	var mouse := _raiz.get_global_mouse_position()
	# Vivo: el mouse está en su origen, o dentro de él (fijado), o un hijo vive.
	var hijo_vivo := false
	for i in range(pila.size() - 1, -1, -1):
		var nivel := pila[i]
		var vivo: bool = hijo_vivo or _sobre_origen(nivel, mouse) \
			or (nivel["fijado"] and _dentro(nivel["panel"], mouse))
		nivel["muerto"] = 0.0 if vivo else nivel["muerto"] + delta
		hijo_vivo = hijo_vivo or vivo or nivel["muerto"] < GRACIA
	for i in pila.size():
		if pila[i]["muerto"] >= GRACIA:
			_cerrar_desde(i)
			break
	for nivel in pila:
		_avanzar_fijado(nivel, delta)


func _abrir_si_toca(delta: float) -> void:
	if _meta_rtl != null and is_instance_valid(_meta_rtl):
		_meta_t += delta
		if _meta_t >= DEMORA_TERMINO and not _abierto_por_meta(_meta_rtl, _meta_id):
			var nivel := _nivel_que_contiene(_meta_rtl) + 1
			# Dentro de un tooltip solo se encadena si ese tooltip ya está fijado.
			if nivel == 0 or pila[nivel - 1]["fijado"]:
				_abrir(nivel, _contenido_termino(_meta_id), { "rtl": _meta_rtl, "meta": _meta_id, "sobre_meta": true })
	elif _candidato != null and is_instance_valid(_candidato) and _candidato.is_visible_in_tree():
		_candidato_t += delta
		if _candidato_t >= DEMORA and not _abierto_por_control(_candidato):
			var nivel := _nivel_que_contiene(_candidato) + 1
			_abrir(nivel, _proveedores[_candidato].call(), { "control": _candidato })


## Se usa _input (antes que la interfaz) para enterarse de todos los clics,
## aunque los atienda un botón; no se consume el evento.
func _input(event: InputEvent) -> void:
	if pila.is_empty():
		return
	if event.is_action_pressed("ui_cancel"):
		cerrar_todo()
	elif event is InputEventMouseButton and event.pressed:
		var mouse := _raiz.get_global_mouse_position()
		if not pila.any(func(n: Dictionary) -> bool: return _dentro(n["panel"], mouse)):
			cerrar_todo()


# --- Abrir y cerrar -------------------------------------------------------

func _abrir(nivel: int, contenido: Dictionary, origen: Dictionary) -> void:
	if contenido.is_empty():
		return
	_cerrar_desde(nivel)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", UI.estilo(Color(UI.FONDO, 0.97), UI.BORDE, 4, 12, 2))
	var c := UI.columna(6)
	panel.add_child(c)
	if contenido.get("titulo", "") != "":
		var titulo := UI.etiqueta_pixel(contenido["titulo"], UI.T_TEXTO, contenido.get("color_titulo", UI.ADVERTENCIA))
		titulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		titulo.custom_minimum_size.x = ANCHO
		c.add_child(titulo)
	c.add_child(_texto(contenido.get("texto", ""), UI.TEXTO))
	if contenido.get("sugerencia", "") != "":
		c.add_child(_texto("Sugerencia: " + contenido["sugerencia"], UI.BIEN))
	if contenido.get("pie", "") != "":
		c.add_child(_texto(contenido["pie"], UI.TEXTO_SUAVE, 11))
	var barra := ColorRect.new()
	barra.color = UI.ACENTO
	barra.custom_minimum_size = Vector2(0, 3)
	barra.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(barra)
	_raiz.add_child(panel)
	var ancla := _raiz.get_global_mouse_position()
	_colocar(panel, ancla)
	var datos := { "panel": panel, "barra": barra, "fijado": false, "t": 0.0, "muerto": 0.0, "ancla": ancla }
	datos.merge(origen)
	pila.append(datos)


## Texto del tooltip con los términos del glosario resaltados (encadenables).
func _texto(texto: String, color: Color, tam := 13) -> RichTextLabel:
	var bbcode := EstadoJuego.glosario.resaltar(texto)
	var r := UI.texto_glosario(bbcode if bbcode != "" else texto.replace("[", "[lb]"), tam, color)
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.custom_minimum_size.x = ANCHO
	return r


## Junto a donde estaba el mouse al abrirse; si no cabe, del otro lado.
func _colocar(panel: PanelContainer, mouse: Vector2) -> void:
	panel.reset_size()
	var pantalla := _raiz.get_viewport_rect().size
	var tam := panel.get_combined_minimum_size()
	var pos := mouse + SEPARACION_MOUSE
	if pos.x + tam.x > pantalla.x - 8:
		pos.x = mouse.x - SEPARACION_MOUSE.x - tam.x
	if pos.y + tam.y > pantalla.y - 8:
		pos.y = mouse.y - SEPARACION_MOUSE.y - tam.y
	panel.position = pos.clamp(Vector2(8, 8), (pantalla - tam - Vector2(8, 8)).max(Vector2(8, 8)))


func _cerrar_desde(nivel: int) -> void:
	while pila.size() > nivel:
		var ultimo: Dictionary = pila.pop_back()
		if is_instance_valid(ultimo["panel"]):
			ultimo["panel"].queue_free()


func _avanzar_fijado(nivel: Dictionary, delta: float) -> void:
	if nivel["fijado"] or not is_instance_valid(nivel["panel"]):
		return
	nivel["t"] += delta
	# El alto del texto se conoce uno o dos cuadros después: se recoloca al inicio.
	if nivel["t"] < 0.15:
		_colocar(nivel["panel"], nivel["ancla"])
	var barra: ColorRect = nivel["barra"]
	var ancho: float = (nivel["panel"] as Control).size.x - 24.0
	barra.custom_minimum_size.x = ancho * clampf(nivel["t"] / SEGUNDOS_FIJAR, 0.0, 1.0)
	if nivel["t"] >= SEGUNDOS_FIJAR:
		nivel["fijado"] = true
		barra.color = UI.BIEN
		(nivel["panel"] as PanelContainer).add_theme_stylebox_override("panel",
			UI.estilo(Color(UI.FONDO, 0.97), UI.BIEN, 4, 12, 2))


# --- Consultas ------------------------------------------------------------

## El origen puede haberse borrado (p. ej. una alerta que ya no aplica): se
## revisa con is_instance_valid ANTES de guardarlo en una variable con tipo,
## porque asignar un objeto liberado a una variable tipada es un error.
func _sobre_origen(nivel: Dictionary, _mouse: Vector2) -> bool:
	var origen: Variant = nivel.get("control", nivel.get("rtl"))
	if not is_instance_valid(origen):
		nivel["sobre_meta"] = false
		return false
	if nivel.has("control"):
		return _bajo_mouse(origen)
	if not _bajo_mouse(origen):
		nivel["sobre_meta"] = false
	return nivel["sobre_meta"]


## true si el control (o algo dentro de él) es lo que Godot tiene bajo el mouse:
## visible, dentro de su rectángulo y sin otra ventana encima.
func _bajo_mouse(control: Control) -> bool:
	if not control.is_visible_in_tree():
		return false
	var encima := control.get_viewport().gui_get_hovered_control()
	if encima == null:
		return control.get_global_rect().has_point(control.get_global_mouse_position())
	return encima == control or control.is_ancestor_of(encima)


static func _dentro(panel: Variant, mouse: Vector2) -> bool:
	return is_instance_valid(panel) and (panel as Control).get_global_rect().grow(6).has_point(mouse)


## Índice del tooltip que contiene `nodo`, o -1 si está fuera de los tooltips.
func _nivel_que_contiene(nodo: Node) -> int:
	for i in pila.size():
		if is_instance_valid(pila[i]["panel"]) and pila[i]["panel"].is_ancestor_of(nodo):
			return i
	return -1


func _abierto_por_control(control: Control) -> bool:
	return pila.any(func(n: Dictionary) -> bool: return n.get("control") == control)


func _abierto_por_meta(rtl: RichTextLabel, id: String) -> bool:
	return pila.any(func(n: Dictionary) -> bool: return n.get("rtl") == rtl and n.get("meta") == id)


func _contenido_termino(id: String) -> Dictionary:
	var t := EstadoJuego.glosario.termino(id)
	if t.is_empty():
		return {}
	return { "titulo": t["nombre"], "texto": t["corto"], "pie": "Clic en la palabra: abrir en el glosario" }
