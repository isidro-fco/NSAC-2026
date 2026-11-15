# juego.gd
# Escena principal: une mapa, cámara e interfaz, abre menús, diálogos y avisos, y maneja el fin de la partida.

class_name Juego
extends Node2D
## Escena principal ("el director"): junta el Mapa, la Cámara y la Interfaz.
## - Abre y cierra los menús de módulo, los diálogos, los avisos y el
##   inspector de colonos.
## - Escucha las señales del Mapa y de EstadoJuego y decide qué mostrar.
## El movimiento de la cámara vive en camara.gd.

const SEGUNDOS_AVISO := 4.0

## id -> [título de la ventana, clase del menú]. Es var y no const porque
## GDScript no admite clases globales en una expresión constante.
var menus := {
	"comando": ["Módulo de Comando", MenuComando],
	"descanso": ["Módulo de Descanso", MenuDescanso],
	"almacen": ["Almacén y Cocina", MenuAlmacen],
	"refugio": ["Refugio Blindado", MenuRefugio],
	"bitacora": ["Bitácora de la misión", MenuBitacora],
	"glosario": ["Glosario técnico", MenuGlosario],
	"opciones": ["Opciones", MenuOpciones],     # sin botón: solo con Esc (ver _escape)
}
## Atajos de teclado de los botones inferiores del HUD.
const ACCION_POR_TECLA := { KEY_B: "construir", KEY_G: "glosario", KEY_L: "bitacora" }

var menu: MenuModulo
var dialogo: DialogoConfirmacion
var inspector: TarjetaColono
var hud := Hud.new()
var panel_tripulacion: PanelTripulacion
var avisos := UI.columna(4)
var ayuda_colocar := UI.etiqueta_pixel("Clic: colocar   ·   Clic derecho o Esc: cancelar")
var etiqueta_flotante := UI.etiqueta_pixel("")
var tutorial: Tutorial

@onready var mapa: Mapa = $Mapa
@onready var camara: CamaraJuego = $Camara
@onready var raiz: Control = $Interfaz/Raiz


func _ready() -> void:
	raiz.theme = UI.tema()
	MenuOpciones.aplicar_pantalla()
	RenderingServer.set_default_clear_color(UI.FONDO.darkened(0.3))
	raiz.add_child(hud)
	GestorAudio.iniciar_ambiente()
	panel_tripulacion = PanelTripulacion.new(mapa)
	raiz.add_child(panel_tripulacion)
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
	hud.alerta_pulsada.connect(_resolver_alerta)
	mapa.modo_cambiado.connect(func(modo: Enums.ModoMapa) -> void:
		hud.mostrar_modo_normal(modo == Enums.ModoMapa.NORMAL)
		# El panel de construcción ocupa el mismo lado izquierdo.
		panel_tripulacion.visible = modo == Enums.ModoMapa.NORMAL)
	panel_tripulacion.colono_elegido.connect(mapa.resaltar)
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
	# Guía para aprender a jugar: empieza sola la primera vez (después, con F1).
	tutorial = Tutorial.new(self)
	add_child(tutorial)


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
	elif ACCION_POR_TECLA.has(event.keycode):
		_accion(ACCION_POR_TECLA[event.keycode])
	else:
		return
	get_viewport().set_input_as_handled()


## Botones inferiores del HUD y sus teclas.
func _accion(id: String) -> void:
	if id == "construir":
		mapa.alternar_construccion()
	elif mapa.modo == Enums.ModoMapa.NORMAL:
		abrir_menu(id)


## Clic en una alerta: lleva a donde se resuelve.
func _resolver_alerta(alerta: Dictionary) -> void:
	var accion: Dictionary = alerta.get("accion", {})
	if accion.has("colono"):
		var datos: DatosColono = accion["colono"]
		var colono := mapa.colono_de(datos)
		if colono != null:
			camara.enfocar(colono.position)
		mapa.resaltar(datos)
		inspeccionar(datos)
	elif accion.has("menu") and mapa.modo == Enums.ModoMapa.NORMAL:
		abrir_menu(accion["menu"])
	elif accion.has("construir") and mapa.modo == Enums.ModoMapa.NORMAL:
		mapa.alternar_construccion()


## Escape cierra lo que esté más arriba: el glosario puede abrirse sobre un diálogo.
## Si no hay nada que cerrar, abre el menú de opciones.
func _escape() -> void:
	if dialogo != null and (menu == null or dialogo.get_index() > menu.get_index()):
		if dialogo.cancelable:
			dialogo.cerrar()
	elif menu != null:
		if not menu.atras():
			cerrar_menu()
	elif mapa.modo != Enums.ModoMapa.NORMAL:
		mapa.cancelar_modo()
	elif inspector != null:
		cerrar_inspector()
	else:
		abrir_menu("opciones")


# --- Menús y diálogos -----------------------------------------------------

func abrir_menu(id: String) -> void:
	Tooltips.cerrar_todo()
	cerrar_menu()
	var titulo: String = menus[id][0]
	menu = menus[id][1].new()
	raiz.add_child(menu)
	# La etiqueta flotante siempre queda por encima del menú.
	raiz.move_child(etiqueta_flotante, -1)
	menu.iniciar(self, titulo)
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
	Tooltips.cerrar_todo()
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
## Los eventos reales llevan arriba la placa "▶ DATO REAL DE LA NASA": al
## pulsarla se despliega lo que pasó de verdad (fecha, números y fuente).
##   │ [ Opción 1 ]           [ Opción 2 ]      │
##   └──────────────────────────────────────────┘
func _mostrar_evento(evento: Dictionary) -> void:
	var botones := UI.fila(4)
	var ventana := DialogoConfirmacion.new(evento["titulo"], "", Callable(), botones)
	ventana.cancelable = false
	ventana.caja.custom_minimum_size = Vector2(560, 0)
	# Evento real: la placa es un botón; la información técnica (fecha, números,
	# fuente) queda escondida hasta que se pulsa, para no saturar la ventana.
	if evento.has("real"):
		var bloque_real := _bloque_real(evento["real"])
		bloque_real.visible = false
		ventana.insertar(_insignia_real(evento["real"], bloque_real))
		ventana.insertar(bloque_real)
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
		var b := DialogoConfirmacion.boton("Opción %d" % (i + 1), func() -> void:
			ventana.cerrar()
			EstadoJuego.eventos.resolver(i))
		b.tooltip_text = opcion["texto"]
		botones.add_child(UI.expandir(b))
	_abrir_dialogo(ventana)


## Placa verde arriba de los eventos que salen de datos reales de la NASA. Es un
## botón: muestra u oculta `bloque` ("lo que pasó de verdad"). La flecha dice
## si está abierto (▼) o cerrado (▶). Hasta que se pulsa la primera vez, se
## infla y desinfla suavemente para que se note que se puede picar.
func _insignia_real(real: Dictionary, bloque: Control) -> Control:
	var quien := "DATO REAL DE LA NASA" if real.get("de_nasa", true) else "DATO REAL"
	# Nombres largos ("Eyección de masa coronal (CME)") se acortan a la sigla
	# para que la placa quepa en una línea; el nombre completo va al desplegarla.
	var tipo: String = real["tipo"]
	if tipo.length() > 24 and tipo.contains("("):
		tipo = tipo.get_slice("(", 1).trim_suffix(")")
	var texto := "%s · %s %s" % [quien, tipo, real["valor"]]
	var placa := Button.new()
	placa.focus_mode = Control.FOCUS_NONE
	placa.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	placa.alignment = HORIZONTAL_ALIGNMENT_LEFT
	placa.add_theme_font_override("font", UI.fuente_pixel())
	placa.add_theme_font_size_override("font_size", UI.T_DETALLE)
	# Bloque pixel art verde azulado con contorno del mismo color.
	var fondo_placa := UI.FONDO.lerp(UI.BIEN, 0.18)
	UI.vestir_boton_pixel(placa, fondo_placa, UI.BIEN, 8, 6)
	placa.add_theme_stylebox_override("normal", UI.estilo_boton_pixel(fondo_placa, UI.BIEN, false, 8, 6))
	for color: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		placa.add_theme_color_override(color, UI.BIEN)
	var pintar := func() -> void:
		placa.text = ("▼ " if bloque.visible else "▶ ") + texto
		placa.tooltip_text = "Ocultar lo que pasó de verdad" if bloque.visible else "Ver lo que pasó de verdad"
	pintar.call()
	# Latido: crece un 4 % y vuelve, en bucle. Se escala desde el centro.
	placa.resized.connect(func() -> void: placa.pivot_offset = placa.size / 2.0)
	var latido: Array[Tween] = []
	placa.ready.connect(func() -> void:
		var t := placa.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		t.tween_property(placa, "scale", Vector2(1.04, 1.12), 0.55)
		t.tween_property(placa, "scale", Vector2.ONE, 0.55)
		t.tween_interval(0.35)
		latido.append(t))
	placa.pressed.connect(func() -> void:
		for t in latido:
			t.kill()
		latido.clear()
		placa.scale = Vector2.ONE
		bloque.visible = not bloque.visible
		pintar.call())
	return placa


## "Lo que pasó de verdad": fecha, explicación con los números reales, fuente
## y de dónde salen los datos (en vivo, guardados o archivo), con enlace.
func _bloque_real(real: Dictionary) -> Control:
	var bloque := UI.columna(6)
	bloque.add_child(UI.etiqueta_pixel("LO QUE PASÓ DE VERDAD · %s" % real["fecha"], UI.T_DETALLE, UI.BIEN))
	bloque.add_child(UI.etiqueta_pixel(real["tipo"], UI.T_DETALLE, UI.TEXTO))
	var texto := UI.parrafo(real["que_paso"], 13, UI.TEXTO)
	texto.custom_minimum_size = Vector2(520, 0)
	bloque.add_child(texto)
	var fuente := UI.etiqueta_pixel("Fuente: %s" % real["fuente"], UI.T_DETALLE, UI.TEXTO_SUAVE)
	fuente.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bloque.add_child(fuente)
	bloque.add_child(UI.etiqueta_pixel("Datos: %s" % real["origen"], UI.T_DETALLE, UI.TEXTO_SUAVE))
	var enlace := LinkButton.new()
	enlace.text = "Ver la fuente en internet"
	enlace.add_theme_font_override("font", UI.fuente_pixel())
	enlace.add_theme_font_size_override("font_size", UI.T_DETALLE)
	enlace.add_theme_color_override("font_color", UI.ADVERTENCIA)
	enlace.pressed.connect(OS.shell_open.bind(real["enlace"]))
	enlace.tooltip_text = real["enlace"]
	bloque.add_child(enlace)
	return bloque


## Filas [efecto, cambio, quedará] de una opción de evento, para la tabla del aviso.
func _filas_evento(opcion: Dictionary) -> Array:
	var filas := []
	for recurso: String in opcion.get("recursos", {}):
		filas.append(UI.fila_cambio(Enums.NOMBRE_RECURSO[recurso], recurso, opcion["recursos"][recurso]))
	if opcion.has("radiacion"):
		filas.append(["Radiación por colono", "+" + UI.num(opcion["radiacion"]), ""])
	if opcion.has("enfermar"):
		filas.append(["Riesgo de enfermar", "%d %%" % roundi(opcion["enfermar"] * 100), "por colono"])
	if opcion.has("tormenta_en"):
		filas.append(["La nube llega en", UI.soles(opcion["tormenta_en"]), ""])
	if opcion.has("tormenta"):
		filas.append(["Tormenta solar", UI.soles(opcion["tormenta"]), ""])
	if opcion.has("retraso_envios"):
		filas.append(["Envíos de la Tierra", "+" + UI.soles(opcion["retraso_envios"]), "de retraso"])
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
		lineas.append("  %s: %s (%s)" % [Enums.NOMBRE_RECURSO[recurso], UI.cantidad(recurso, economia.valor(recurso)),
			UI.cantidad(recurso, economia.producido.get(recurso, 0.0))])
	_dialogo_final("Misión Cumplida", "\n".join(lineas), true)


## Diálogo que no se cierra con Escape. Con `modo_libre` añade el botón para seguir jugando.
func _dialogo_final(titulo: String, texto: String, modo_libre: bool) -> void:
	cerrar_menu()
	mapa.cambiar_modo(Enums.ModoMapa.NORMAL)
	var botones := UI.fila()
	var final := DialogoConfirmacion.new(titulo, texto, Callable(), botones)
	if modo_libre:
		botones.add_child(UI.expandir(DialogoConfirmacion.boton("Modo Libre", func() -> void:
			final.cerrar()
			GestorTiempo.en_pausa = false)))
	botones.add_child(UI.expandir(DialogoConfirmacion.boton("Nueva Partida", func() -> void:
		EstadoJuego.nueva_partida()
		get_tree().reload_current_scene(), true)))
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
	UI.aplicar_marco(caja, 12)
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.add_child(UI.etiqueta(texto, 13))
	avisos.add_child(caja)
	get_tree().create_timer(SEGUNDOS_AVISO).timeout.connect(caja.queue_free)
