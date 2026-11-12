extends Node2D
## Escena principal ("el director"): junta el Mapa, la Cámara y la Interfaz.
## - Abre y cierra los menús de módulo, los diálogos, los avisos y el
##   inspector de colonos.
## - Escucha las señales del Mapa y de EstadoJuego y decide qué mostrar.
## El movimiento de la cámara vive en camara.gd.

const SEGUNDOS_AVISO := 4.0

var menus := {
	"comando": ["Módulo de Comando", MenuComando],
	"descanso": ["Módulo de Descanso", MenuDescanso],
	"almacen": ["Almacén y Cocina", MenuAlmacen],
	"refugio": ["Refugio Blindado", MenuRefugio],
	"bitacora": ["Bitácora de la misión", MenuBitacora],
	"glosario": ["Glosario técnico", MenuGlosario],
}
var menu: MenuModulo
var dialogo: DialogoConfirmacion
var inspector: TarjetaColono
var hud := Hud.new()
var avisos := UI.columna(4)
var ayuda_colocar := UI.etiqueta_pixel("Clic: colocar   ·   Clic derecho o Esc: cancelar")
var etiqueta_flotante := UI.etiqueta_pixel("")

@onready var mapa: Mapa = $Mapa
@onready var camara: CamaraJuego = $Camara
@onready var raiz: Control = $Interfaz/Raiz


func _ready() -> void:
	raiz.theme = UI.tema()
	RenderingServer.set_default_clear_color(UI.FONDO.darkened(0.3))
	raiz.add_child(hud)
	raiz.add_child(MenuConstruccion.new(mapa))

	for control: Control in [avisos, ayuda_colocar]:
		control.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		control.grow_horizontal = Control.GROW_DIRECTION_BOTH
		control.offset_top = Hud.ALTO_BARRA
		raiz.add_child(control)
	avisos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ayuda_colocar.add_theme_stylebox_override("normal", UI.estilo(Color(UI.FONDO, 0.95), UI.BORDE, 0, 10, 2))
	ayuda_colocar.visible = false
	etiqueta_flotante.add_theme_stylebox_override("normal", UI.estilo(UI.FONDO, UI.CRITICO, 0, 8, 2))
	etiqueta_flotante.visible = false
	raiz.add_child(etiqueta_flotante)

	hud.accion_pedida.connect(_accion)
	mapa.modo_cambiado.connect(func(modo: Enums.ModoMapa) -> void:
		hud.botones_inferiores.visible = modo == Enums.ModoMapa.NORMAL)
	mapa.modulo_clicado.connect(abrir_menu)
	mapa.colono_clicado.connect(func(colono: Colono) -> void:
		camara.enfocar(colono.position)
		inspeccionar(colono.datos))
	mapa.confirmacion_pedida.connect(confirmar)
	mapa.aviso_pedido.connect(mostrar_aviso)
	mapa.etiqueta_demolicion.connect(func(texto: String) -> void:
		etiqueta_flotante.text = texto
		etiqueta_flotante.visible = texto != "")
	EstadoJuego.aviso.connect(mostrar_aviso)
	EstadoJuego.colono_retirado.connect(func(c: DatosColono) -> void:
		if inspector != null and inspector.colono == c:
			cerrar_inspector())
	EstadoJuego.partida_terminada.connect(_fin_de_partida)
	EstadoJuego.victoria.connect(_victoria)
	EstadoJuego.evento_iniciado.connect(_mostrar_evento)
	EstadoJuego.glosario_pedido.connect(abrir_glosario)


## Con un menú o diálogo abierto, el mapa y la cámara dejan de responder.
func _actualizar_modal() -> void:
	mapa.modal_abierto = menu != null or dialogo != null
	camara.bloqueada = mapa.modal_abierto


func _process(_delta: float) -> void:
	ayuda_colocar.visible = mapa.modo == Enums.ModoMapa.COLOCANDO and dialogo == null
	if etiqueta_flotante.visible:
		var limite := raiz.size - etiqueta_flotante.size
		etiqueta_flotante.position = (raiz.get_local_mouse_position() + Vector2(16, 16)).min(limite)


func _unhandled_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		_escape()
	elif mapa.modal_abierto:
		return
	elif event.keycode == KEY_SPACE:
		GestorTiempo.en_pausa = not GestorTiempo.en_pausa
	elif event.keycode in [KEY_B, KEY_G, KEY_L]:
		_accion({KEY_B: "construir", KEY_G: "glosario", KEY_L: "bitacora"}[event.keycode])
	else:
		return
	get_viewport().set_input_as_handled()


## Botones inferiores del HUD y sus teclas.
func _accion(id: String) -> void:
	if id == "construir":
		mapa.alternar_construccion()
	elif mapa.modo == Enums.ModoMapa.NORMAL:
		abrir_menu(id)


## Escape cierra lo que esté más arriba: el glosario puede abrirse sobre un diálogo.
func _escape() -> void:
	if dialogo != null and (menu == null or dialogo.get_index() > menu.get_index()):
		if dialogo.cancelable:
			dialogo.cerrar()
	elif menu != null:
		if not menu.atras():
			cerrar_menu()
	elif mapa.modo != Enums.ModoMapa.NORMAL:
		mapa.cancelar_modo()
	else:
		cerrar_inspector()


# --- Menús y diálogos -----------------------------------------------------

func abrir_menu(id: String) -> void:
	cerrar_menu()
	menu = menus[id][1].new()
	raiz.add_child(menu)
	# La etiqueta flotante siempre queda por encima del menú.
	raiz.move_child(etiqueta_flotante, -1)
	menu.iniciar(self, menus[id][0])
	_actualizar_modal()


## HU-12: abre el glosario en un término (desde un texto resaltado).
func abrir_glosario(id: String) -> void:
	if menu is not MenuGlosario:
		abrir_menu("glosario")
	menu.seleccionar(id)


func cerrar_menu() -> void:
	if menu != null:
		menu.queue_free()
		menu = null
	_actualizar_modal()


func confirmar(titulo: String, texto: String, al_confirmar: Callable, filas: Array = [],
		texto_confirmar := "Confirmar", peligro := false) -> void:
	_abrir_dialogo(DialogoConfirmacion.new(titulo, texto, al_confirmar, null, filas, texto_confirmar, peligro))


func _abrir_dialogo(nuevo: DialogoConfirmacion) -> void:
	if dialogo != null:
		dialogo.cerrar()
	dialogo = nuevo
	dialogo.cerrado.connect(func() -> void:
		if dialogo == nuevo:
			dialogo = null
			_actualizar_modal())
	raiz.add_child(dialogo)
	_actualizar_modal()


## HU-08: el evento espera una decisión. Mismo estilo que el aviso
## (docs/diseno/aviso.png): título, descripción, una tabla por opción con lo que
## cambia y cómo quedará, y un botón por opción abajo.
##   ┌──────────────────────────────────────────┐
##   │ Fuga en el reciclador de agua            │
##   │ Una junta del soporte vital ...          │
##   │ Opción 1: Pagar una reparación urgente   │
##   │ ┌ Efecto        Cambio      Quedará ───┐ │
##   │ └ Presupuesto    -$150  $1,000 a $850 ─┘ │
##   │ Opción 2: ...                            │
##   │ [ Opción 1 ]           [ Opción 2 ]      │
##   └──────────────────────────────────────────┘
func _mostrar_evento(evento: Dictionary) -> void:
	var botones := UI.fila(4)
	var ventana := DialogoConfirmacion.new(evento["titulo"], "", Callable(), botones)
	ventana.cancelable = false
	ventana.caja.custom_minimum_size = Vector2(560, 0)
	var descripcion := UI.etiqueta_pixel(evento["descripcion"], UI.T_DETALLE)
	descripcion.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	descripcion.add_theme_constant_override("line_spacing", 4)
	ventana.insertar(descripcion)
	for i in evento["opciones"].size():
		var opcion: Dictionary = evento["opciones"][i]
		var bloque := UI.columna(8)
		var titulo := UI.etiqueta_pixel("Opción %d: %s" % [i + 1, opcion["texto"]], UI.T_DETALLE, UI.ADVERTENCIA)
		titulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bloque.add_child(titulo)
		bloque.add_child(DialogoConfirmacion.tabla(_filas_evento(opcion), ["Efecto", "Cambio", "Quedará"]))
		ventana.insertar(bloque)
		var b := UI.boton_pixel("Opción %d" % (i + 1), func() -> void:
			ventana.cerrar()
			EstadoJuego.eventos.resolver(i))
		UI.pintar_boton_pixel(b, false, UI.ACENTO, UI.TARJETA, 0)
		b.custom_minimum_size = Vector2(0, 38)
		b.tooltip_text = opcion["texto"]
		botones.add_child(UI.expandir(b))
	_abrir_dialogo(ventana)


## Filas [efecto, cambio, quedará] de una opción de evento, para la tabla del aviso.
func _filas_evento(opcion: Dictionary) -> Array:
	var filas := []
	for recurso: String in opcion.get("recursos", {}):
		var cambio: float = opcion["recursos"][recurso]
		var actual := EstadoJuego.economia.valor(recurso)
		var final := maxf(actual + cambio, 0.0)
		if recurso == "presupuesto":
			filas.append([Enums.NOMBRE_RECURSO[recurso], UI.dinero(cambio), "%s a %s" % [UI.dinero(actual), UI.dinero(final)]])
		else:
			filas.append([Enums.NOMBRE_RECURSO[recurso], UI.con_signo(cambio), "%s a %s" % [UI.num(actual), UI.num(final)]])
	if opcion.has("radiacion"):
		filas.append(["Radiación por colono", "+" + UI.num(opcion["radiacion"]), ""])
	if opcion.has("enfermar"):
		filas.append(["Riesgo de enfermar", "%d %%" % roundi(opcion["enfermar"] * 100), "por colono"])
	if opcion.has("tormenta"):
		filas.append(["Tormenta solar", UI.soles(opcion["tormenta"]), ""])
	if opcion.get("blindaje", 1.0) < 1.0:
		filas.append(["Dosis en los módulos", "%d %%" % roundi(opcion["blindaje"] * 100), ""])
	if filas.is_empty():
		filas.append(["Sin consecuencias", "", ""])
	return filas


func pedir_regreso(c: DatosColono) -> void:
	var texto := "%s dejará la colonia para siempre y liberará su cuarto." % c.nombre
	confirmar("Enviar a la Tierra", texto, EstadoJuego.tripulacion.enviar_a_la_tierra.bind(c))


func _fin_de_partida(motivo: String) -> void:
	var texto := "%s\nSobreviviste hasta el sol %d." % [motivo, GestorTiempo.sol_actual]
	_dialogo_final("Fin de la partida", texto, false)


## HU-11: resumen de la misión con Modo Libre (seguir jugando) o Nueva Partida.
func _victoria() -> void:
	var economia := EstadoJuego.economia
	var lineas := PackedStringArray([
		"La colonia es autosuficiente: el Módulo de Comando alcanzó el nivel %d." % EstadoJuego.comando.nivel,
		"",
		"Soles transcurridos: %d" % (GestorTiempo.sol_actual - 1),
		"Colonos en activo: %d · retornados a la Tierra: %d" % [
			EstadoJuego.tripulacion.activos(), EstadoJuego.tripulacion.retirados.size()],
		"Módulos construidos: %d" % EstadoJuego.modulos_construidos,
		"",
		"Reservas finales (producido en toda la misión):",
	])
	for recurso: String in EstadoJuego.datos_balance.recursos_comando:
		lineas.append("  %s: %s (%s)" % [Enums.NOMBRE_RECURSO[recurso], UI.num(economia.valor(recurso)),
			UI.num(economia.producido.get(recurso, 0.0))])
	_dialogo_final("Misión Cumplida", "\n".join(lineas), true)


## Diálogo que no se cierra con Escape. Con `modo_libre` añade el botón para seguir jugando.
func _dialogo_final(titulo: String, texto: String, modo_libre: bool) -> void:
	cerrar_menu()
	mapa.cambiar_modo(Enums.ModoMapa.NORMAL)
	var botones := UI.fila()
	var final := DialogoConfirmacion.new(titulo, texto, Callable(), botones)
	if modo_libre:
		var libre := UI.boton_pixel("Modo Libre", func() -> void:
			final.cerrar()
			GestorTiempo.en_pausa = false)
		UI.pintar_boton_pixel(libre, false, UI.ACENTO, UI.TARJETA, 0)
		botones.add_child(UI.expandir(libre))
	var nueva := UI.boton_pixel("Nueva Partida", func() -> void:
		EstadoJuego.nueva_partida()
		get_tree().reload_current_scene())
	UI.pintar_boton_pixel(nueva, true, UI.ACENTO, UI.TARJETA, 0)
	nueva.custom_minimum_size = Vector2(0, 38)
	botones.add_child(UI.expandir(nueva))
	final.cancelable = false
	_abrir_dialogo(final)


# --- Inspector de colonos (HU-06) -----------------------------------------

func inspeccionar(c: DatosColono) -> void:
	cerrar_inspector()
	inspector = TarjetaColono.new(c, pedir_regreso, true)
	raiz.add_child(inspector)
	raiz.move_child(inspector, hud.get_index() + 1)
	inspector.cerrado.connect(cerrar_inspector)


func cerrar_inspector() -> void:
	if inspector != null:
		inspector.queue_free()
		inspector = null


# --- Avisos ---------------------------------------------------------------

## Aviso tipo "toast": superficie elevada con franja naranja a la izquierda.
func mostrar_aviso(texto: String) -> void:
	var caja := PanelContainer.new()
	var estilo := UI.estilo_elevado(UI.FONDO, UI.BORDE, UI.RADIO, 10)
	estilo.border_width_left = 4
	estilo.border_color = UI.ACENTO
	estilo.content_margin_left = 14
	caja.add_theme_stylebox_override("panel", estilo)
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.add_child(UI.etiqueta(texto, 13))
	avisos.add_child(caja)
	get_tree().create_timer(SEGUNDOS_AVISO).timeout.connect(caja.queue_free)
