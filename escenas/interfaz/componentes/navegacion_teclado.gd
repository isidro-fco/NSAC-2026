# navegacion_teclado.gd
# Recorre los botones del panel abierto con las flechas y los pulsa con Enter, con un marco que señala el elegido.

class_name NavegacionTeclado
extends CanvasLayer
## Solo las flechas (no WASD: WASD sigue moviendo la cámara). Funciona en el
## panel que esté al frente: la ventana de un evento o confirmación, el menú de
## un módulo (Bitácora, Glosario, Opciones...), el panel de construcción o el
## menú de inicio. Quien la crea le pasa `panel_activo`, que devuelve ese
## Control (o null si no hay ninguno).
##
## - Flecha: pasa al botón más cercano en esa dirección (la primera vez, al
##   primero de arriba a la izquierda). Si está dentro de una lista con barra,
##   la lista se desplaza para que se vea.
## - Enter: lo pulsa (igual que un clic).
## - Mover el mouse o hacer clic quita el marco.
## Además de los botones, cuenta cualquier Control con la meta "navegable"
## (un Callable que se llama con Enter) y, opcional, "al_enfocar" (Callable(bool)).
## No usa el foco de Godot a propósito: los botones del juego no toman foco para
## que Espacio siga pausando.

const GROSOR := 3.0

var panel_activo: Callable
var actual: Control = null
var _marco := Control.new()
var _t := 0.0
## Al pulsar con Enter, muchos menús se redibujan y el botón elegido se borra:
## se recuerda dónde estaba para volver a marcar el que quede en ese lugar.
var _recordado := Vector2.INF
var _recordado_ms := 0                 # solo vale un momento después de pulsar


func _init(proveedor: Callable) -> void:
	panel_activo = proveedor
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_marco.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_marco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marco.draw.connect(_dibujar)
	add_child(_marco)


## true si hay un panel al frente: mientras tanto las flechas no mueven la cámara.
func activa() -> bool:
	var panel: Variant = panel_activo.call()
	return panel != null and is_instance_valid(panel) and (panel as Control).is_visible_in_tree()


func _process(delta: float) -> void:
	_t += delta
	if actual != null and (not is_instance_valid(actual) or not actual.is_visible_in_tree() or not activa() \
			or not (panel_activo.call() as Control).is_ancestor_of(actual)):
		_soltar()
	if _recordado != Vector2.INF and Time.get_ticks_msec() - _recordado_ms > 400:
		_recordado = Vector2.INF
	if actual == null and _recordado != Vector2.INF and activa():
		var mas_cerca: Control = null
		for c in _candidatos(panel_activo.call()):
			if mas_cerca == null or c.get_global_rect().get_center().distance_to(_recordado) \
					< mas_cerca.get_global_rect().get_center().distance_to(_recordado):
				mas_cerca = c
		_recordado = Vector2.INF
		if mas_cerca != null:
			_enfocar(mas_cerca)
	_marco.queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and actual != null and event.relative.length() > 2.0:
		_soltar()
		_recordado = Vector2.INF
		return
	if event is not InputEventKey or not event.pressed or not activa():
		return
	var direccion := Vector2.ZERO
	match event.physical_keycode:
		KEY_UP:
			direccion = Vector2.UP
		KEY_DOWN:
			direccion = Vector2.DOWN
		KEY_LEFT:
			direccion = Vector2.LEFT
		KEY_RIGHT:
			direccion = Vector2.RIGHT
		KEY_ENTER, KEY_KP_ENTER:
			if actual != null and not event.echo:
				_recordado = actual.get_global_rect().get_center()
				_recordado_ms = Time.get_ticks_msec()
				_pulsar(actual)
				get_viewport().set_input_as_handled()
			return
		_:
			return
	_mover(direccion)
	get_viewport().set_input_as_handled()


func _mover(direccion: Vector2) -> void:
	var candidatos := _candidatos(panel_activo.call())
	if candidatos.is_empty():
		return
	var siguiente: Control = null
	if actual == null:
		siguiente = candidatos[0]
	else:
		var desde := actual.get_global_rect().get_center()
		var mejor := INF
		for c in candidatos:
			if c == actual:
				continue
			var d := c.get_global_rect().get_center() - desde
			var avance := d.dot(direccion)
			if avance <= 1.0:
				continue
			# Lo que está derecho en esa dirección pesa menos que lo que está de lado.
			var costo := avance + 2.5 * absf(d.dot(Vector2(direccion.y, -direccion.x)))
			if costo < mejor:
				mejor = costo
				siguiente = c
	if siguiente != null:
		_enfocar(siguiente)


## Botones y controles "navegables" visibles dentro del panel, de arriba a abajo y de izquierda a derecha.
func _candidatos(panel: Control) -> Array[Control]:
	var lista: Array[Control] = []
	for n: Node in panel.find_children("*", "Control", true, false):
		var c := n as Control
		if not c.is_visible_in_tree() or c.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			continue
		if c.has_meta("navegable") or (c is BaseButton and not (c as BaseButton).disabled):
			lista.append(c)
	lista.sort_custom(func(a: Control, b: Control) -> bool:
		var pa := a.get_global_rect().position
		var pb := b.get_global_rect().position
		return pa.y < pb.y - 4.0 or (absf(pa.y - pb.y) <= 4.0 and pa.x < pb.x))
	return lista


func _enfocar(c: Control) -> void:
	_soltar()
	actual = c
	_t = 0.0
	if c.has_meta("al_enfocar"):
		(c.get_meta("al_enfocar") as Callable).call(true)
	# Si está en una lista con barra, que se vea.
	var padre := c.get_parent()
	while padre != null:
		if padre is ScrollContainer:
			(padre as ScrollContainer).ensure_control_visible(c)
			break
		padre = padre.get_parent()


func _soltar() -> void:
	if actual != null and is_instance_valid(actual) and actual.has_meta("al_enfocar"):
		(actual.get_meta("al_enfocar") as Callable).call(false)
	actual = null


func _pulsar(c: Control) -> void:
	if c.has_meta("navegable"):
		(c.get_meta("navegable") as Callable).call()
	elif c is BaseButton:
		var b := c as BaseButton
		if b.toggle_mode:
			b.button_pressed = not b.button_pressed
		else:
			b.pressed.emit()


## Marco amarillo que late alrededor del elegido.
func _dibujar() -> void:
	if actual == null or not is_instance_valid(actual):
		return
	var rect := actual.get_global_rect().grow(4.0)
	var pulso := 0.6 + 0.4 * sin(_t * 6.0)
	_marco.draw_rect(rect, Color(UI.ADVERTENCIA, pulso), false, GROSOR)
	_marco.draw_rect(rect.grow(GROSOR), Color(0, 0, 0, 0.5 * pulso), false, 1.0)
