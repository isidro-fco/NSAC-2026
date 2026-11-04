class_name TarjetaModulo
extends Button
## Entrada del catálogo de construcción (HU-05): color, nombre, tamaño y coste.
## Queda deshabilitada y atenuada si no alcanza el dinero o los materiales.

const ESCENA := "res://escenas/interfaz/componentes/tarjeta_modulo.tscn"

var datos: DatosModulo



static func crear(datos_modulo: DatosModulo, al_elegir: Callable) -> TarjetaModulo:
	var tarjeta: TarjetaModulo = load(ESCENA).instantiate()
	tarjeta.configurar(datos_modulo, al_elegir)
	return tarjeta


func configurar(datos_modulo: DatosModulo, al_elegir: Callable) -> void:
	datos = datos_modulo
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(0, 74)
	var alcanza := EstadoJuego.puede_pagar(datos.dinero, datos.materiales)
	disabled = not alcanza
	if not alcanza:
		modulate = Color(1, 1, 1, 0.5)
	pressed.connect(al_elegir.bind(datos.id))

	var margen := MarginContainer.new()
	margen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for lado: String in ["left", "right", "top", "bottom"]:
		margen.add_theme_constant_override("margin_" + lado, 8)
	add_child(margen)

	var f := Hud.fila(10)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margen.add_child(f)
	var icono := Panel.new()
	icono.add_theme_stylebox_override("panel", Hud.estilo(datos.color, datos.color.darkened(0.3), Hud.RADIO - 2, 0))
	icono.custom_minimum_size = Vector2(36, 36)
	icono.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icono.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f.add_child(icono)

	var c := Hud.columna(0)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f.add_child(Hud.expandir(c))
	c.add_child(Hud.etiqueta(datos.nombre))
	c.add_child(Hud.etiqueta("%dx%d casillas" % [datos.tam.x, datos.tam.y], 12, Hud.TEXTO_SUAVE))
	var coste := Hud.etiqueta("$%d · %d mat." % [datos.dinero, datos.materiales], 13, Hud.ACENTO)
	coste.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	c.add_child(coste)
	for etiqueta: Control in c.get_children():
		etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
