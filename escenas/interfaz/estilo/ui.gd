# ui.gd
# Estilo común de la interfaz: paleta de colores, fuentes, tema y funciones para crear piezas básicas.

class_name UI
extends RefCounted
## Estilo común de toda la interfaz: paleta (docs/diseno/paleta_colores.png),
## fuentes, tema y piezas básicas (etiquetas, botones, filas...). Solo funciones estáticas.

# --- Paleta ---------------------------------------------------------------
# Colores de docs/diseno/paleta_colores.png y sus derivados.

const FONDO := Color("#18232d")          # diálogos, placas de tecla (Deep Space oscurecido)
const FONDO_CLARO := Color("#22313F")    # Deep Space: píldoras del HUD, paneles y menús
const TARJETA := Color("#2b3d4e")        # tarjetas dentro de un panel
const SILENCIADO := Color("#2c3e4f")     # hover, pistas de barras, botones apagados
const BORDE := Color("#3a4f62")          # bordes y divisores
const ACENTO := Color("#D98B5F")         # Dusty Clay: acción principal, selección
const TEXTO := Color("#F5F1E8")          # Mist White
const TEXTO_SUAVE := Color("#a3aab0")    # Mist White apagado
const TEXTO_PRIMARIO := TEXTO            # texto sobre ACENTO (como en los diseños)
const ADVERTENCIA := Color("#F2C66D")    # Sand Glow
const CRITICO := Color("#B55239")        # Rust Red
const BIEN := Color("#36C2B4")           # Teal Signal
const RADIO := 6                         # tarjetas y botones (docs/diseno/*.pdf)
const RADIO_PILDORA := 10                # píldoras del HUD y panel de construcción
const RADIO_PANEL := 16                  # ventanas de módulo

# Tamaños de la fuente pixel (docs/diseno/*.pdf, a 1280x720).
const T_TITULO := 24                     # título de una ventana
const T_SECCION := 14                    # "Reservas", "Tripulación [ 3 ]"...
const T_TEXTO := 10                      # títulos de tarjeta, botones, HUD
const T_DETALLE := 8                     # líneas secundarias, botones pequeños

## Color de cada recurso en la barra superior.
## Como en docs/diseno/barra_superior.png (oxígeno claro, energía amarilla,
## agua azulada, comida cálida), pero con tonos de la paleta.
const COLOR_RECURSO := {
	"oxigeno": Color("#9fe3dc"), "energia": ADVERTENCIA, "agua": BIEN,
	"comida": ACENTO, "presupuesto": BIEN, "materiales": ADVERTENCIA,
}

## Variantes de botón (theme_type_variation), como en shadcn/ui.
const PRIMARIO := "BotonPrimario"
const FANTASMA := "BotonFantasma"
const PELIGRO := "BotonPeligro"

const FUENTE_NORMAL := preload("res://recursos/fuentes/Manrope-Regular.ttf")
const FUENTE_NEGRITA := preload("res://recursos/fuentes/Manrope-Bold.ttf")

static var _fuente_pixel: FontFile


# --- Piezas comunes -------------------------------------------------------

## Caja con fondo y borde. Con radio 0 y grosor 2 es la caja "pixel" de los prototipos.
static func estilo(fondo: Color, borde := BORDE, radio := RADIO, margen := 10, grosor := 1) -> StyleBoxFlat:
	var caja := StyleBoxFlat.new()
	caja.bg_color = fondo
	caja.border_color = borde
	caja.set_border_width_all(grosor)
	caja.set_corner_radius_all(radio)
	caja.set_content_margin_all(margen)
	caja.anti_aliasing = radio > 0
	return caja


## Marco con cinta de peligro y piso granulado, como la base de la sala de
## comandos. Lo usan la barra del HUD y
## todas las ventanas. El control que lo lleve debe usar TEXTURE_FILTER_NEAREST
## (ver aplicar_marco).
const MARCO := preload("res://recursos/sprites/interfaz/marco_hud.png")
const MARGEN_MARCO := 8                       # = MARGEN en generar_marco_hud.py


static func estilo_marco(margen := 12) -> StyleBoxTexture:
	var caja := StyleBoxTexture.new()
	caja.texture = MARCO
	caja.set_texture_margin_all(MARGEN_MARCO)
	# En mosaico (no estirados) para que las franjas y el grano no se deformen.
	caja.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	caja.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	caja.set_content_margin_all(maxi(margen, MARGEN_MARCO + 2))
	return caja


## Pone el marco de cinta de peligro como fondo de un PanelContainer.
static func aplicar_marco(panel: PanelContainer, margen := 12) -> void:
	panel.add_theme_stylebox_override("panel", estilo_marco(margen))
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## Superficie elevada (panel, diálogo, aviso): borde fino y sombra suave.
static func estilo_elevado(fondo := FONDO, borde := BORDE, radio := RADIO + 2, margen := 14) -> StyleBoxFlat:
	var caja := estilo(fondo, borde, radio, margen)
	caja.shadow_color = Color(0, 0, 0, 0.35)
	caja.shadow_size = 14
	caja.shadow_offset = Vector2(0, 4)
	return caja


## Press Start 2P: barra superior, panel de construcción y botones de acción.
## Se ve nítida en tamaños múltiplos de 8 (8, 16...).
static func fuente_pixel() -> Font:
	if _fuente_pixel == null:
		_fuente_pixel = load("res://recursos/fuentes/PressStart2P-Regular.ttf")
		_fuente_pixel.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		_fuente_pixel.hinting = TextServer.HINTING_NONE
		_fuente_pixel.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	return _fuente_pixel


## Estilos de un tipo de botón: normal, hover/pulsado (más claro) y deshabilitado (translúcido).
static func _botones(t: Theme, tipo: String, fondo: Color, borde: Color, texto: Color, hover: Color) -> void:
	if tipo != "Button":
		t.set_type_variation(tipo, "Button")
	var borde_hover := hover if borde == fondo else borde
	var estados := {"normal": [fondo, borde], "hover": [hover, borde_hover], "hover_pressed": [hover, borde_hover],
		"pressed": [hover.darkened(0.1), borde_hover], "disabled": [Color(fondo, fondo.a * 0.5), Color(borde, borde.a * 0.5)]}
	for estado: String in estados:
		var caja := estilo(estados[estado][0], estados[estado][1], RADIO, 8, 2)
		caja.content_margin_left = 14
		caja.content_margin_right = 14
		t.set_stylebox(estado, tipo, caja)
	for estado: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		t.set_color(estado, tipo, texto)
	t.set_color("font_disabled_color", tipo, Color(texto, 0.5))


static func tema() -> Theme:
	var t := Theme.new()
	t.default_font = FUENTE_NORMAL
	t.default_font_size = 14
	t.set_color("font_color", "Label", TEXTO)
	t.set_stylebox("panel", "PanelContainer", estilo_elevado())
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	# Los botones usan la fuente pixel, como en los diseños.
	t.set_font("font", "Button", fuente_pixel())
	t.set_font_size("font_size", "Button", T_TEXTO)
	# Botón por defecto: tarjeta con borde.
	_botones(t, "Button", TARJETA, BORDE, TEXTO, SILENCIADO)
	_botones(t, PRIMARIO, ACENTO, ACENTO, TEXTO_PRIMARIO, ACENTO.lightened(0.1))
	_botones(t, FANTASMA, Color(FONDO, 0.0), Color(FONDO, 0.0), TEXTO_SUAVE, SILENCIADO)
	t.set_color("font_hover_color", FANTASMA, TEXTO)
	_botones(t, PELIGRO, CRITICO, CRITICO, TEXTO, CRITICO.lightened(0.1))

	t.set_stylebox("background", "ProgressBar", estilo(SILENCIADO, SILENCIADO, 999, 0))
	t.set_stylebox("fill", "ProgressBar", estilo(ACENTO, ACENTO, 999, 0))
	var pista := StyleBoxEmpty.new()
	pista.content_margin_left = 6
	t.set_stylebox("scroll", "VScrollBar", pista)
	t.set_stylebox("grabber", "VScrollBar", estilo(BORDE, BORDE, 999, 0))
	t.set_stylebox("grabber_highlight", "VScrollBar", estilo(BORDE.lightened(0.2), BORDE.lightened(0.2), 999, 0))
	t.set_stylebox("grabber_pressed", "VScrollBar", estilo(ACENTO, ACENTO, 999, 0))
	t.set_stylebox("panel", "TooltipPanel", estilo(FONDO, BORDE, RADIO, 8))
	t.set_color("font_color", "TooltipLabel", TEXTO)
	t.set_font_size("font_size", "TooltipLabel", 12)
	var linea := StyleBoxLine.new()
	linea.color = BORDE
	t.set_stylebox("separator", "HSeparator", linea)
	t.set_constant("separation", "HSeparator", 1)
	return t


## Etiqueta con la fuente pixel (tamaños 8 o 16).
static func etiqueta_pixel(texto: String, tam := 8, color := TEXTO) -> Label:
	var label := etiqueta_simple(texto, tam, color)
	label.add_theme_font_override("font", fuente_pixel())
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## Botón cuadrado con fuente pixel. `activo` lo pinta con el color de acento.
static func boton_pixel(texto: String, accion: Callable, activo := false, tam := 8) -> Button:
	var b := boton(texto, accion)
	b.add_theme_font_override("font", fuente_pixel())
	b.add_theme_font_size_override("font_size", tam)
	pintar_boton_pixel(b, activo)
	return b


## `color_activo` cambia el color del estado activo (p. ej. CRITICO para "Demoler").
## `fondo_inactivo` y `radio` permiten usarlo dentro de píldoras y paneles.
static func pintar_boton_pixel(b: Button, activo: bool, color_activo := ACENTO, fondo_inactivo := TARJETA,
		radio := RADIO) -> void:
	var fondo := color_activo if activo else fondo_inactivo
	var hover := fondo.lightened(0.08)
	var estados := {"normal": fondo, "hover": hover, "pressed": fondo.darkened(0.1), "hover_pressed": hover, "disabled": fondo}
	for estado: String in estados:
		var borde := color_activo if estado == "hover" and not activo else fondo
		b.add_theme_stylebox_override(estado, estilo(estados[estado], borde, radio, 6, 2))
	var texto := TEXTO_PRIMARIO if activo else TEXTO
	for estado: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(estado, texto)
	b.add_theme_color_override("font_disabled_color", Color(texto, 0.4))


## Etiqueta de una línea. Si el texto menciona un término del glosario (HU-12)
## devuelve un texto enriquecido con el término resaltado (ver texto_glosario).
static func etiqueta(texto: String, tam := 14, color := TEXTO) -> Control:
	var bbcode := EstadoJuego.glosario.resaltar(texto)
	return texto_glosario(bbcode, tam, color) if bbcode != "" else etiqueta_simple(texto, tam, color)


## Como etiqueta(), pero ajusta el texto al ancho disponible.
static func parrafo(texto: String, tam := 13, color := TEXTO_SUAVE) -> Control:
	var control := etiqueta(texto, tam, color)
	control.set("autowrap_mode", TextServer.AUTOWRAP_WORD_SMART)    # Label o RichTextLabel
	return control


## Texto enriquecido cuyos términos marcados muestran su definición al pasar el
## ratón y abren el glosario al hacer clic. Cambia su texto con fijar_texto().
static func texto_glosario(bbcode := "", tam := 14, color := TEXTO) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_OFF
	r.mouse_filter = Control.MOUSE_FILTER_PASS
	r.add_theme_font_size_override("normal_font_size", tam)
	r.add_theme_color_override("default_color", color)
	if tam >= 16:
		r.add_theme_font_override("normal_font", FUENTE_NEGRITA)
	r.meta_hover_started.connect(func(id: Variant) -> void:
		r.tooltip_text = EstadoJuego.glosario.termino(str(id))["corto"])
	r.meta_hover_ended.connect(func(_id: Variant) -> void: r.tooltip_text = "")
	r.meta_clicked.connect(func(id: Variant) -> void: EstadoJuego.glosario_pedido.emit(str(id)))
	r.text = bbcode
	return r


static func fijar_texto(r: RichTextLabel, texto: String) -> void:
	var bbcode := EstadoJuego.glosario.resaltar(texto)
	if bbcode == "":
		bbcode = texto.replace("[", "[lb]")
	if r.text != bbcode:      # el inspector lo llama cada frame: no rehacer el texto si no cambia
		r.text = bbcode


static func etiqueta_simple(texto: String, tam := 14, color := TEXTO) -> Label:
	var label := Label.new()
	label.text = texto
	label.add_theme_font_size_override("font_size", tam)
	label.add_theme_color_override("font_color", color)
	if tam >= 16:
		label.add_theme_font_override("font", FUENTE_NEGRITA)
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


## Tarjeta redondeada con borde, como las de Reservas o Tareas disponibles.
static func tarjeta(fondo := TARJETA, margen := 10) -> PanelContainer:
	var panel := PanelContainer.new()
	var caja := estilo(fondo, BORDE, RADIO, margen, 2)
	caja.content_margin_top = margen - 1
	caja.content_margin_bottom = margen - 1
	panel.add_theme_stylebox_override("panel", caja)
	return panel


## Título de una ventana ("Almacén y Cocina").
static func titulo(texto: String) -> Label:
	return etiqueta_pixel(texto, T_TITULO)


## Encabezado de sección ("Reservas", "Tripulación [ 3 ]").
static func seccion(texto: String) -> Label:
	return etiqueta_pixel(texto, T_SECCION)


## Título y línea de detalle de una tarjeta (Comida cruda: 18 / Gasto: ...).
static func cabecera_tarjeta(titulo_tarjeta: String, detalle := "", color := ADVERTENCIA) -> VBoxContainer:
	var c := columna(5)
	c.alignment = BoxContainer.ALIGNMENT_CENTER
	c.add_child(etiqueta_pixel(titulo_tarjeta, T_TEXTO, color))
	if detalle != "":
		c.add_child(etiqueta_pixel(detalle, T_DETALLE))
	return c


## Botón pequeño naranja ("Cocinar", "Pedir ($300)"). Deshabilitado se ve
## apagado con el texto en naranja ("Falta comida").
static func boton_accion(texto: String, accion: Callable, habilitado := true) -> Button:
	var b := boton(texto, accion, habilitado)
	b.add_theme_font_size_override("font_size", T_DETALLE)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for estado: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var fondo := ACENTO
		if estado.begins_with("hover"):
			fondo = ACENTO.lightened(0.1)
		elif estado == "pressed":
			fondo = ACENTO.darkened(0.1)
		elif estado == "disabled":
			fondo = SILENCIADO
		var caja := estilo(fondo, fondo, 3, 4, 0)
		caja.content_margin_left = 10
		caja.content_margin_right = 10
		b.add_theme_stylebox_override(estado, caja)
	b.add_theme_color_override("font_disabled_color", ACENTO)
	for estado: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(estado, TEXTO)
	return b


## Botón cuadrado naranja con una X para cerrar ventanas.
static func boton_cerrar(accion: Callable) -> Button:
	var b := boton_pixel("X", accion, true, T_TITULO)
	b.custom_minimum_size = Vector2(42, 42)
	b.tooltip_text = "Cerrar (Esc)"
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pintar_boton_pixel(b, true, ACENTO, TARJETA, 8)
	return b


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


## Foto de perfil del colono recortada en un círculo con borde; si no tiene,
## un círculo con sus iniciales en el color de su rol.
static func avatar(c: DatosColono, lado := 34) -> Control:
	var icono := Control.new()
	icono.custom_minimum_size = Vector2(lado, lado)
	icono.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icono.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icono.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icono.tooltip_text = c.nombre
	var textura := c.textura_retrato()
	icono.draw.connect(func() -> void:
		var centro := icono.size / 2.0
		var radio := minf(icono.size.x, icono.size.y) / 2.0
		if textura == null:
			icono.draw_circle(centro, radio, c.color_rol().darkened(0.2))
			icono.draw_string(FUENTE_NEGRITA, centro + Vector2(-radio, 5), c.iniciales(),
				HORIZONTAL_ALIGNMENT_CENTER, radio * 2.0, 13, FONDO)
		else:
			var puntos := PackedVector2Array()
			var uvs := PackedVector2Array()
			for i in 40:
				var dir := Vector2.from_angle(TAU * i / 40.0)
				puntos.append(centro + dir * radio)
				uvs.append(Vector2(0.5, 0.5) + dir * 0.5)
			icono.draw_polygon(puntos, PackedColorArray([Color.WHITE]), uvs, textura)
		icono.draw_arc(centro, radio - 1.0, 0.0, TAU, 40, BORDE, 2.0, true))
	return icono


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


## Número con un decimal como máximo; sin ".0" si es entero (120, no 120.0).
## "1 sol", "3 soles".
static func soles(n: int) -> String:
	return "%d sol%s" % [n, "" if n == 1 else "es"]


static func num(valor: float) -> String:
	var redondeado := snappedf(valor, 0.1)
	if is_equal_approx(redondeado, roundf(redondeado)):
		return str(int(roundf(redondeado)))
	return String.num(redondeado, 1)


## Dinero con separador de miles: 1000 -> "$1,000", -40 -> "-$40".
static func dinero(valor: float) -> String:
	var entero := str(absi(int(roundf(valor))))
	var partes: PackedStringArray = []
	while entero.length() > 3:
		partes.insert(0, entero.right(3))
		entero = entero.left(-3)
	partes.insert(0, entero)
	return ("-" if valor < 0.0 else "") + "$" + ",".join(partes)


static func con_signo(valor: float) -> String:
	return ("+" if valor >= 0.0 else "") + num(valor)


## Fila [nombre, cambio, quedará] de las tablas de los avisos, p. ej.
## "Costo del trabajo | -$40 | $1,000 a $960". Lo que quedará nunca baja de 0.
static func fila_cambio(nombre: String, recurso: String, cambio: float) -> Array:
	var antes := EstadoJuego.economia.valor(recurso)
	var despues := maxf(antes + cambio, 0.0)
	if recurso == "presupuesto":
		return [nombre, ("+" if cambio >= 0.0 else "") + dinero(cambio), "%s a %s" % [dinero(antes), dinero(despues)]]
	return [nombre, con_signo(cambio), "%s a %s" % [num(antes), num(despues)]]


static func texto_recompensa(recompensa: Dictionary) -> String:
	var partes: PackedStringArray = []
	for clave: String in recompensa:
		var nombre: String = Enums.NOMBRE_RECURSO.get(clave, "Investigación")
		partes.append("+%s %s" % [num(recompensa[clave]), nombre])
	return ", ".join(partes)
