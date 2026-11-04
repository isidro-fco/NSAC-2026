class_name Hud
extends Control
## HU-07: recursos, reloj de soles y botón Construir, siempre visibles.
## También define el estilo común de toda la interfaz (colores, tema y piezas
## básicas como etiquetas, botones y filas) y el marco de los menús.

signal construccion_pulsada

const ALTO_BARRA := 56.0
const TAM_MENU := Vector2(1180, 640)

# --- Paleta ---------------------------------------------------------------
# Tokens al estilo shadcn/ui con los colores de la plantilla "Madera para la
# casa": naranja cálido (#e7652b) sobre paneles antracita (#374c5f).

const FONDO := Color("#1b2530")          # background / popover
const FONDO_CLARO := Color("#243241")    # card / secondary
const SILENCIADO := Color("#2e3f51")     # muted (hover, pistas de barras)
const BORDE := Color("#374c5f")          # border: antracita de la plantilla
const ACENTO := Color("#e7652b")         # primary: naranja de la plantilla
const TEXTO := Color("#f1f1f1")          # foreground
const TEXTO_SUAVE := Color("#9fb0c2")    # muted-foreground
const TEXTO_PRIMARIO := Color("#ffffff") # primary-foreground
const ADVERTENCIA := Color("#facc15")
const CRITICO := Color("#ef4444")        # destructive
const BIEN := Color("#22c55e")
const SOMBRA := Color(0, 0, 0, 0.35)
const RADIO := 8

## Variantes de botón (theme_type_variation), como en shadcn/ui.
const PRIMARIO := "BotonPrimario"
const FANTASMA := "BotonFantasma"
const PELIGRO := "BotonPeligro"

static var _fuente: Font
static var _fuente_titulo: Font


# --- Piezas comunes -------------------------------------------------------

static func estilo(fondo: Color, borde := BORDE, radio := RADIO, margen := 10) -> StyleBoxFlat:
	var caja := StyleBoxFlat.new()
	caja.bg_color = fondo
	caja.border_color = borde
	caja.set_border_width_all(1)
	caja.set_corner_radius_all(radio)
	caja.set_content_margin_all(margen)
	caja.anti_aliasing = true
	return caja


## Superficie elevada (panel, diálogo, aviso): borde fino y sombra suave.
static func estilo_elevado(fondo := FONDO, borde := BORDE, radio := RADIO + 2, margen := 14) -> StyleBoxFlat:
	var caja := estilo(fondo, borde, radio, margen)
	caja.shadow_color = SOMBRA
	caja.shadow_size = 14
	caja.shadow_offset = Vector2(0, 4)
	return caja


static func _estilo_boton(fondo: Color, borde: Color) -> StyleBoxFlat:
	var caja := estilo(fondo, borde, RADIO - 2, 8)
	caja.content_margin_left = 14
	caja.content_margin_right = 14
	return caja


static func fuente(titulo := false) -> Font:
	if _fuente == null:
		var nombres := PackedStringArray(["Inter", "Geist", "Segoe UI", "Roboto", "Ubuntu", "Noto Sans", "sans-serif"])
		var normal := SystemFont.new()
		normal.font_names = nombres
		normal.font_weight = 400
		var negrita := SystemFont.new()
		negrita.font_names = nombres
		negrita.font_weight = 600
		_fuente = normal
		_fuente_titulo = negrita
	return _fuente_titulo if titulo else _fuente


static func _variante_boton(t: Theme, nombre: String, fondo: Color, borde: Color, texto: Color, hover: Color) -> void:
	t.set_type_variation(nombre, "Button")
	t.set_stylebox("normal", nombre, _estilo_boton(fondo, borde))
	t.set_stylebox("hover", nombre, _estilo_boton(hover, borde if borde != fondo else hover))
	t.set_stylebox("pressed", nombre, _estilo_boton(hover.darkened(0.1), borde if borde != fondo else hover.darkened(0.1)))
	t.set_stylebox("hover_pressed", nombre, _estilo_boton(hover, borde if borde != fondo else hover))
	var apagado := _estilo_boton(fondo, borde)
	apagado.bg_color.a *= 0.5
	apagado.border_color.a *= 0.5
	t.set_stylebox("disabled", nombre, apagado)
	for estado: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		t.set_color(estado, nombre, texto)
	t.set_color("font_disabled_color", nombre, Color(texto, 0.5))


static func tema() -> Theme:
	var t := Theme.new()
	t.default_font = fuente()
	t.default_font_size = 14
	t.set_color("font_color", "Label", TEXTO)
	t.set_stylebox("panel", "PanelContainer", estilo_elevado())
	t.set_stylebox("panel", "Panel", estilo(FONDO_CLARO))

	# Botón por defecto = variante "outline" de shadcn.
	t.set_stylebox("normal", "Button", _estilo_boton(FONDO_CLARO, BORDE))
	t.set_stylebox("hover", "Button", _estilo_boton(SILENCIADO, BORDE.lightened(0.15)))
	t.set_stylebox("pressed", "Button", _estilo_boton(SILENCIADO.darkened(0.15), ACENTO))
	t.set_stylebox("hover_pressed", "Button", _estilo_boton(SILENCIADO, ACENTO))
	t.set_stylebox("disabled", "Button", _estilo_boton(FONDO, BORDE.darkened(0.3)))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXTO)
	t.set_color("font_hover_color", "Button", TEXTO_PRIMARIO)
	t.set_color("font_pressed_color", "Button", TEXTO_PRIMARIO)
	t.set_color("font_hover_pressed_color", "Button", TEXTO_PRIMARIO)
	t.set_color("font_disabled_color", "Button", TEXTO_SUAVE.darkened(0.3))

	_variante_boton(t, PRIMARIO, ACENTO, ACENTO, TEXTO_PRIMARIO, ACENTO.lightened(0.1))
	_variante_boton(t, FANTASMA, Color(FONDO, 0.0), Color(FONDO, 0.0), TEXTO_SUAVE, SILENCIADO)
	t.set_color("font_hover_color", FANTASMA, TEXTO)
	_variante_boton(t, PELIGRO, CRITICO.darkened(0.15), CRITICO.darkened(0.15), TEXTO_PRIMARIO, CRITICO)

	t.set_stylebox("background", "ProgressBar", estilo(SILENCIADO, SILENCIADO, 999, 0))
	t.set_stylebox("fill", "ProgressBar", estilo(ACENTO, ACENTO, 999, 0))

	var pista := StyleBoxFlat.new()
	pista.bg_color = Color(0, 0, 0, 0)
	pista.content_margin_left = 6
	pista.content_margin_right = 0
	t.set_stylebox("scroll", "VScrollBar", pista)
	t.set_stylebox("grabber", "VScrollBar", estilo(BORDE, BORDE, 999, 0))
	t.set_stylebox("grabber_highlight", "VScrollBar", estilo(BORDE.lightened(0.2), BORDE.lightened(0.2), 999, 0))
	t.set_stylebox("grabber_pressed", "VScrollBar", estilo(ACENTO, ACENTO, 999, 0))

	t.set_stylebox("panel", "TooltipPanel", estilo(FONDO, BORDE, RADIO - 2, 8))
	t.set_color("font_color", "TooltipLabel", TEXTO)
	t.set_font_size("font_size", "TooltipLabel", 12)

	var linea := StyleBoxLine.new()
	linea.color = BORDE
	linea.thickness = 1
	t.set_stylebox("separator", "HSeparator", linea)
	t.set_constant("separation", "HSeparator", 1)
	return t


static func etiqueta(texto: String, tam := 14, color := TEXTO) -> Label:
	var label := Label.new()
	label.text = texto
	label.add_theme_font_size_override("font_size", tam)
	label.add_theme_color_override("font_color", color)
	if tam >= 16:
		label.add_theme_font_override("font", fuente(true))
	return label


static func parrafo(texto: String, tam := 13, color := TEXTO_SUAVE) -> Label:
	var label := etiqueta(texto, tam, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


static func boton(texto: String, accion: Callable, habilitado := true, variante := "") -> Button:
	var b := Button.new()
	b.text = texto
	b.theme_type_variation = variante
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.disabled = not habilitado
	b.focus_mode = Control.FOCUS_NONE      # Espacio y flechas son del juego
	b.pressed.connect(accion)
	return b


static func boton_primario(texto: String, accion: Callable, habilitado := true) -> Button:
	return boton(texto, accion, habilitado, PRIMARIO)


static func tarjeta(fondo := FONDO_CLARO) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", estilo(fondo, BORDE, RADIO, 12))
	return panel


static func separador() -> HSeparator:
	return HSeparator.new()


## Etiqueta tipo "badge" de shadcn: pastilla con texto pequeño.
static func insignia(texto: String, color := ACENTO) -> PanelContainer:
	var panel := PanelContainer.new()
	var caja := estilo(Color(color, 0.15), Color(color, 0.45), 999, 0)
	caja.content_margin_left = 9
	caja.content_margin_right = 9
	caja.content_margin_top = 2
	caja.content_margin_bottom = 2
	panel.add_theme_stylebox_override("panel", caja)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var label := etiqueta(texto, 12, color)
	label.add_theme_font_override("font", fuente(true))
	panel.add_child(label)
	return panel


static func fila(separacion := 8) -> HBoxContainer:
	var caja := HBoxContainer.new()
	caja.add_theme_constant_override("separation", separacion)
	return caja


static func columna(separacion := 6) -> VBoxContainer:
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", separacion)
	return caja


static func expandir(control: Control) -> Control:
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return control


static func desplazable(interior: Control) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	interior.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(interior)
	return scroll


static func avatar(c: DatosColono, lado := 38) -> Control:
	var panel := PanelContainer.new()
	var color: Color = c.color_rol()
	var caja := estilo(color.darkened(0.2), color, lado / 2, 0)
	panel.add_theme_stylebox_override("panel", caja)
	panel.custom_minimum_size = Vector2(lado, lado)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var inicial := etiqueta(c.iniciales(), 14, FONDO)
	inicial.add_theme_font_override("font", fuente(true))
	inicial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inicial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(inicial)
	return panel


static func color_radiacion(valor: float) -> Color:
	if valor >= EstadoJuego.datos_balance.radiacion_enfermedad:
		return CRITICO
	if valor >= EstadoJuego.datos_balance.radiacion_enfermedad * 0.7:
		return ADVERTENCIA
	return BIEN


static func barra_radiacion(valor: float) -> ProgressBar:
	var barra := ProgressBar.new()
	barra.max_value = EstadoJuego.datos_balance.radiacion_max
	barra.value = valor
	barra.show_percentage = false
	barra.custom_minimum_size = Vector2(0, 6)
	barra.add_theme_stylebox_override("fill", estilo(color_radiacion(valor), color_radiacion(valor), 999, 0))
	return barra


static func texto_radiacion(valor: float) -> String:
	return "Radiación: %s / %d" % [num(valor), int(EstadoJuego.datos_balance.radiacion_max)]


static func num(valor: float) -> String:
	return String.num(valor, 1)


static func con_signo(valor: float) -> String:
	return ("+" if valor >= 0.0 else "") + num(valor)


static func texto_recompensa(recompensa: Dictionary) -> String:
	var partes: PackedStringArray = []
	for clave: String in recompensa:
		var nombre: String = Enums.NOMBRE_RECURSO.get(clave, "Investigación")
		partes.append("+%s %s" % [num(recompensa[clave]), nombre])
	return ", ".join(partes)


# --- HUD ------------------------------------------------------------------

var indicadores: Array[IndicadorRecurso] = []
var sol_label: Label
var barra_sol: ProgressBar
var boton_pausa: Button
var boton_velocidad: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var barra := PanelContainer.new()
	var estilo_barra := Hud.estilo(Color(Hud.FONDO, 0.96), Hud.BORDE, 0, 8)
	estilo_barra.set_border_width_all(0)
	estilo_barra.border_width_bottom = 1
	estilo_barra.content_margin_left = 16
	estilo_barra.content_margin_right = 12
	estilo_barra.shadow_color = Hud.SOMBRA
	estilo_barra.shadow_size = 8
	barra.add_theme_stylebox_override("panel", estilo_barra)
	barra.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	barra.custom_minimum_size = Vector2(0, ALTO_BARRA)
	add_child(barra)
	var f := Hud.fila(14)
	barra.add_child(f)
	for recurso: String in EstadoJuego.datos_balance.recursos_hud:
		var indicador := IndicadorRecurso.crear(recurso)
		indicadores.append(indicador)
		f.add_child(indicador)
	f.add_child(Hud.expandir(Control.new()))
	f.add_child(_reloj())

	var boton_construir := Hud.boton_primario("Construir (B)", construccion_pulsada.emit)
	boton_construir.add_theme_font_override("font", Hud.fuente(true))
	boton_construir.add_theme_font_size_override("font_size", 15)
	boton_construir.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	boton_construir.grow_horizontal = Control.GROW_DIRECTION_BOTH
	boton_construir.grow_vertical = Control.GROW_DIRECTION_BEGIN
	boton_construir.offset_top = -12
	boton_construir.offset_bottom = -12
	boton_construir.custom_minimum_size = Vector2(190, 44)
	# Sobre el suelo naranja de Marte el botón necesita un anillo oscuro y sombra.
	# (El tema se asigna después de este _ready, así que el estilo se crea aquí.)
	var fondos := {"normal": Hud.ACENTO, "hover": Hud.ACENTO.lightened(0.1),
		"pressed": Hud.ACENTO.darkened(0.1), "hover_pressed": Hud.ACENTO.lightened(0.1)}
	for estado: String in fondos:
		var caja := Hud._estilo_boton(fondos[estado], Hud.FONDO)
		caja.border_color = Hud.FONDO
		caja.set_border_width_all(2)
		caja.shadow_color = Color(0, 0, 0, 0.5)
		caja.shadow_size = 10
		caja.shadow_offset = Vector2(0, 3)
		boton_construir.add_theme_stylebox_override(estado, caja)
	add_child(boton_construir)

	EstadoJuego.estado_cambiado.connect(actualizar)
	actualizar()


func _reloj() -> Control:
	var f := Hud.fila(8)
	var c := Hud.columna(3)
	c.custom_minimum_size = Vector2(130, 0)
	sol_label = Hud.etiqueta("", 15)
	sol_label.add_theme_font_override("font", Hud.fuente(true))
	barra_sol = ProgressBar.new()
	barra_sol.max_value = 1.0
	barra_sol.show_percentage = false
	barra_sol.custom_minimum_size = Vector2(0, 6)
	c.add_child(sol_label)
	c.add_child(barra_sol)
	f.add_child(c)
	boton_pausa = Hud.boton("", GestorTiempo.alternar_pausa)
	boton_pausa.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	boton_pausa.custom_minimum_size = Vector2(92, 0)
	boton_velocidad = Hud.boton("", GestorTiempo.alternar_velocidad)
	boton_velocidad.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	boton_velocidad.custom_minimum_size = Vector2(52, 0)
	f.add_child(boton_pausa)
	f.add_child(boton_velocidad)
	return f


func actualizar() -> void:
	for indicador in indicadores:
		indicador.actualizar()
	sol_label.text = "Sol %d" % GestorTiempo.sol_actual
	boton_pausa.text = "Reanudar" if GestorTiempo.en_pausa else "Pausar"
	# En pausa, el botón resalta en naranja para que se note.
	boton_pausa.theme_type_variation = Hud.PRIMARIO if GestorTiempo.en_pausa else ""
	boton_velocidad.text = "x1" if GestorTiempo.velocidad == 2 else "x2"


func _process(_delta: float) -> void:
	barra_sol.value = GestorTiempo.progreso_sol


# --- Marco de los menús de módulo -----------------------------------------

## Monta fondo oscurecido, panel, título y botón Cerrar dentro de `menu`.
## Devuelve el contenedor donde el menú pone su contenido.
static func marco_menu(menu: Control, titulo: String, al_cerrar: Callable) -> VBoxContainer:
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var fondo := ColorRect.new()
	fondo.color = Color(0, 0, 0, 0.6)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(fondo)
	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(centro)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = TAM_MENU
	panel.add_theme_stylebox_override("panel", estilo_elevado(FONDO, BORDE, RADIO + 4, 18))
	centro.add_child(panel)
	var marco := columna(12)
	panel.add_child(marco)
	var cabecera := fila(10)
	marco.add_child(cabecera)
	var acento := ColorRect.new()
	acento.color = ACENTO
	acento.custom_minimum_size = Vector2(4, 24)
	acento.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cabecera.add_child(acento)
	cabecera.add_child(expandir(etiqueta(titulo, 20)))
	cabecera.add_child(boton("Cerrar (Esc)", al_cerrar, true, FANTASMA))
	marco.add_child(separador())
	var contenido := columna(10)
	contenido.size_flags_vertical = Control.SIZE_EXPAND_FILL
	marco.add_child(contenido)
	return contenido


## Vacía `contenido`, lo vuelve a construir y conserva la posición de las
## listas con scroll (registradas en `scrolls` durante la construcción).
static func reconstruir(contenido: Control, scrolls: Array[ScrollContainer], construir: Callable) -> void:
	var posiciones: Array[int] = []
	for scroll in scrolls:
		posiciones.append(scroll.scroll_vertical)
	scrolls.clear()
	for hijo in contenido.get_children():
		contenido.remove_child(hijo)
		hijo.queue_free()
	construir.call()
	if scrolls.size() != posiciones.size() or not contenido.is_inside_tree():
		return
	await contenido.get_tree().process_frame
	for i in scrolls.size():
		if is_instance_valid(scrolls[i]):
			scrolls[i].scroll_vertical = posiciones[i]
