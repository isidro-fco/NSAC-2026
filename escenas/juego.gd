extends Node2D
## Escena principal: instancia Mapa, HUD y Cámara.
## - Cámara: WASD/flechas, arrastre con botón central y rueda para el zoom.
## - Interfaz: abre los menús de módulo, diálogos, avisos e inspector de
##   colonos, y responde a las señales del mapa y de EstadoJuego.

const VELOCIDAD_CAMARA := 500.0
const ZOOM_MAX := 3.0
const SEGUNDOS_AVISO := 4.0
const MENUS := {
	"comando": ["Módulo de comando", preload("res://escenas/interfaz/menus/menu_comando.tscn")],
	"descanso": ["Módulo de descanso", preload("res://escenas/interfaz/menus/menu_descanso.tscn")],
	"almacen": ["Almacén y cocina", preload("res://escenas/interfaz/menus/menu_almacen.tscn")],
}

var menu: Control
var dialogo: DialogoConfirmacion
var inspector: TarjetaColono
var avisos: VBoxContainer
var etiqueta_flotante: PanelContainer
var texto_flotante: Label
var ayuda_colocar: Label

@onready var mapa: Mapa = $Mapa
@onready var camara: Camera2D = $Camara
@onready var raiz: Control = $Interfaz/Raiz
@onready var hud: Hud = $Interfaz/Raiz/Hud
@onready var menu_construccion: MenuConstruccion = $Interfaz/Raiz/MenuConstruccion


func _ready() -> void:
	raiz.theme = Hud.tema()
	RenderingServer.set_default_clear_color(Hud.FONDO.darkened(0.3))
	_crear_capas_interfaz()
	hud.construccion_pulsada.connect(mapa.alternar_construccion)
	menu_construccion.iniciar(mapa)

	mapa.modo_cambiado.connect(_al_cambiar_modo)
	mapa.modulo_clicado.connect(abrir_menu)
	mapa.colono_clicado.connect(_al_clicar_colono)
	mapa.confirmacion_pedida.connect(confirmar)
	mapa.aviso_pedido.connect(mostrar_aviso)
	mapa.etiqueta_demolicion.connect(_mostrar_etiqueta)
	EstadoJuego.aviso.connect(mostrar_aviso)
	EstadoJuego.colono_retirado.connect(cerrar_inspector_de)
	EstadoJuego.partida_terminada.connect(_fin_de_partida)

	get_viewport().size_changed.connect(_centrar_camara)
	_centrar_camara()


func _crear_capas_interfaz() -> void:
	avisos = Hud.columna(4)
	avisos.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	avisos.grow_horizontal = Control.GROW_DIRECTION_BOTH
	avisos.offset_top = 66
	avisos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(avisos)

	ayuda_colocar = Hud.etiqueta("Clic: colocar   ·   Clic derecho o Esc: cancelar", 14)
	ayuda_colocar.add_theme_stylebox_override("normal", Hud.estilo(Color(Hud.FONDO, 0.9), Hud.BORDE, 999, 8))
	ayuda_colocar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	ayuda_colocar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	ayuda_colocar.offset_top = 66
	ayuda_colocar.visible = false
	raiz.add_child(ayuda_colocar)

	etiqueta_flotante = PanelContainer.new()
	etiqueta_flotante.add_theme_stylebox_override("panel", Hud.estilo(Hud.FONDO, Hud.CRITICO, Hud.RADIO - 2, 6))
	etiqueta_flotante.mouse_filter = Control.MOUSE_FILTER_IGNORE
	etiqueta_flotante.visible = false
	texto_flotante = Hud.etiqueta("", 13)
	etiqueta_flotante.add_child(texto_flotante)
	raiz.add_child(etiqueta_flotante)


func hay_modal() -> bool:
	return menu != null or dialogo != null


func _actualizar_modal() -> void:
	mapa.modal_abierto = hay_modal()


func _process(delta: float) -> void:
	if not hay_modal():
		_mover_camara(delta)
	ayuda_colocar.visible = mapa.modo == Enums.ModoMapa.COLOCANDO and dialogo == null
	if etiqueta_flotante.visible:
		var limite := raiz.size - etiqueta_flotante.size
		etiqueta_flotante.position = (raiz.get_local_mouse_position() + Vector2(16, 16)).min(limite)


# --- Entrada --------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		_tecla(event)
	elif not hay_modal():
		_raton_camara(event)


func _tecla(event: InputEventKey) -> void:
	if not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		_escape()
		get_viewport().set_input_as_handled()
	elif hay_modal():
		return
	elif event.keycode == KEY_SPACE:
		GestorTiempo.alternar_pausa()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_B:
		mapa.alternar_construccion()
		get_viewport().set_input_as_handled()


func _escape() -> void:
	if dialogo != null:
		if dialogo.cancelable:
			dialogo.cerrar()
	elif menu != null:
		if not menu.atras():
			cerrar_menu()
	elif mapa.modo != Enums.ModoMapa.NORMAL:
		mapa.cancelar_modo()
	elif inspector != null:
		cerrar_inspector()


# --- Cámara ---------------------------------------------------------------

func _raton_camara(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
		camara.position = _limitar_camara(camara.position - event.relative / camara.zoom)
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_cambiar_zoom(1.1)
			MOUSE_BUTTON_WHEEL_DOWN:
				_cambiar_zoom(1.0 / 1.1)


func _mover_camara(delta: float) -> void:
	var dir := Vector2(
		Input.get_axis("ui_left", "ui_right"), Input.get_axis("ui_up", "ui_down"))
	if Input.is_physical_key_pressed(KEY_A):
		dir.x -= 1
	if Input.is_physical_key_pressed(KEY_D):
		dir.x += 1
	if Input.is_physical_key_pressed(KEY_W):
		dir.y -= 1
	if Input.is_physical_key_pressed(KEY_S):
		dir.y += 1
	if dir != Vector2.ZERO:
		camara.position += dir.limit_length() * VELOCIDAD_CAMARA * delta / camara.zoom.x
		camara.position = _limitar_camara(camara.position)


func _tam_mapa() -> Vector2:
	return Vector2(GestorCuadricula.ANCHO, GestorCuadricula.ALTO) * GestorCuadricula.TAM_CELDA


func _zoom_minimo() -> float:
	var vista := get_viewport_rect().size
	var mapa_px := _tam_mapa()
	return minf(vista.x / mapa_px.x, (vista.y - Hud.ALTO_BARRA) / mapa_px.y)


func _centrar_camara() -> void:
	camara.zoom = Vector2.ONE * _zoom_minimo()
	camara.position = _limitar_camara(_tam_mapa() / 2.0)


## Mantiene el mapa a la vista, dejando sitio para la barra superior.
func _limitar_camara(posicion: Vector2) -> Vector2:
	var vista := get_viewport_rect().size / camara.zoom
	var alto_hud := Hud.ALTO_BARRA / camara.zoom.y
	var mapa_px := _tam_mapa()
	var min_pos := Vector2(vista.x / 2.0, vista.y / 2.0 - alto_hud)
	var max_pos := mapa_px - vista / 2.0
	var limitada := posicion
	limitada.x = mapa_px.x / 2.0 if min_pos.x > max_pos.x else clampf(posicion.x, min_pos.x, max_pos.x)
	limitada.y = (min_pos.y + max_pos.y) / 2.0 if min_pos.y > max_pos.y else clampf(posicion.y, min_pos.y, max_pos.y)
	return limitada


func _cambiar_zoom(factor: float) -> void:
	var zoom := clampf(camara.zoom.x * factor, _zoom_minimo(), ZOOM_MAX)
	camara.zoom = Vector2(zoom, zoom)
	camara.position = _limitar_camara(camara.position)


func enfocar(punto: Vector2) -> void:
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(camara, "position", _limitar_camara(punto), 0.4)


# --- Modo construcción ----------------------------------------------------

func _al_cambiar_modo(modo: Enums.ModoMapa) -> void:
	menu_construccion.visible = modo in [Enums.ModoMapa.CATALOGO, Enums.ModoMapa.DEMOLICION]
	menu_construccion.actualizar()


# --- Menús de módulo ------------------------------------------------------

func abrir_menu(id: String) -> void:
	cerrar_menu()
	if not MENUS.has(id):
		return
	menu = MENUS[id][1].instantiate()
	raiz.add_child(menu)
	# Los diálogos y la etiqueta flotante siempre quedan por encima del menú.
	raiz.move_child(etiqueta_flotante, -1)
	menu.iniciar(self, MENUS[id][0])
	_actualizar_modal()


func cerrar_menu() -> void:
	if menu != null:
		menu.queue_free()
		menu = null
	_actualizar_modal()


# --- Diálogos -------------------------------------------------------------

func confirmar(titulo: String, texto: String, al_confirmar: Callable) -> void:
	_abrir_dialogo(DialogoConfirmacion.crear_confirmacion(titulo, texto, al_confirmar))


func _abrir_dialogo(nuevo: DialogoConfirmacion) -> void:
	cerrar_dialogo()
	dialogo = nuevo
	dialogo.cerrado.connect(func() -> void:
		if dialogo == nuevo:
			dialogo = null
			_actualizar_modal())
	raiz.add_child(dialogo)
	_actualizar_modal()


func cerrar_dialogo() -> void:
	if dialogo != null:
		dialogo.cerrar()


func pedir_regreso(c: DatosColono) -> void:
	var texto := "%s dejará la colonia para siempre y liberará su cuarto." % c.nombre
	confirmar("Enviar a la Tierra", texto, EstadoJuego.enviar_a_la_tierra.bind(c))


func _fin_de_partida(motivo: String) -> void:
	cerrar_menu()
	if mapa.modo != Enums.ModoMapa.NORMAL:
		mapa.salir_construccion()
	var final := DialogoConfirmacion.crear()
	final.cancelable = false
	var texto := "%s\nSobreviviste hasta el sol %d." % [motivo, GestorTiempo.sol_actual]
	final.configurar("Fin de la partida", texto, Hud.boton_primario("Nueva partida", _nueva_partida))
	_abrir_dialogo(final)


func _nueva_partida() -> void:
	EstadoJuego.nueva_partida()
	get_tree().reload_current_scene()


# --- Inspector de colonos (HU-06) -----------------------------------------

func _al_clicar_colono(colono: Colono) -> void:
	enfocar(colono.position)
	inspeccionar(colono.datos)


func inspeccionar(c: DatosColono) -> void:
	cerrar_inspector()
	inspector = TarjetaColono.crear_inspector(c)
	raiz.add_child(inspector)
	raiz.move_child(inspector, hud.get_index() + 1)
	inspector.cerrado.connect(cerrar_inspector)
	inspector.regreso_pedido.connect(pedir_regreso)


func cerrar_inspector() -> void:
	if inspector != null:
		inspector.queue_free()
		inspector = null


func cerrar_inspector_de(c: DatosColono) -> void:
	if inspector != null and inspector.colono == c:
		cerrar_inspector()


# --- Avisos y etiqueta flotante -------------------------------------------

func mostrar_aviso(texto: String) -> void:
	# Aviso tipo "toast": superficie elevada con franja naranja a la izquierda.
	var caja := PanelContainer.new()
	var estilo := Hud.estilo_elevado(Hud.FONDO, Hud.BORDE, Hud.RADIO, 10)
	estilo.border_width_left = 4
	estilo.border_color = Hud.ACENTO
	estilo.content_margin_left = 14
	caja.add_theme_stylebox_override("panel", estilo)
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.add_child(Hud.etiqueta(texto, 13))
	avisos.add_child(caja)
	get_tree().create_timer(SEGUNDOS_AVISO).timeout.connect(caja.queue_free)


func _mostrar_etiqueta(texto: String) -> void:
	texto_flotante.text = texto
	etiqueta_flotante.visible = texto != ""
