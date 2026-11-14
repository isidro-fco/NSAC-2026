# tarjeta_modulo.gd
# Botón del catálogo de construcción que muestra un módulo con su costo y se deshabilita si no alcanza.

class_name TarjetaModulo
extends Button
## Entrada del catálogo de construcción (HU-05), según docs/diseno/Construir.pdf:
##   ╭────┬──────────────────╮
##   │ ▦▦ │ Soporte Vital    │   El icono dibuja las casillas que ocupa el módulo.
##   │ ▦▦ │ $300 M  30 mat.  │   El coste se pinta en rojo si no alcanza.
##   │    │ Consume 10 kW    │   Energía: lo que gasta (o produce, el panel).
##   │    │ +5.2 kg O2/sol   │   Lo que produce por sol.
##   ╰────┴──────────────────╯
## Queda deshabilitada y atenuada si no alcanza el dinero o los materiales.

const LADO_ICONO := 26

var datos: DatosModulo


func _init(datos_modulo: DatosModulo, al_elegir: Callable) -> void:
	datos = datos_modulo
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = Vector2(0, LADO_ICONO + 14)
	tooltip_text = "Ocupa %dx%d casillas" % [datos.tam.x, datos.tam.y]
	var economia := EstadoJuego.economia
	disabled = not economia.puede_pagar(datos.dinero, datos.materiales)
	if disabled:
		modulate = Color(1, 1, 1, 0.55)
	pressed.connect(al_elegir.bind(datos.id))
	for estado: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var borde := UI.ACENTO if estado.begins_with("hover") or estado == "pressed" else UI.BORDE
		add_theme_stylebox_override(estado, UI.estilo(UI.TARJETA, borde, 4, 0, 2))

	var f := UI.fila(10)
	f.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	f.offset_left = 7
	f.offset_right = -7
	add_child(f)
	f.add_child(_icono())

	var c := UI.columna(5)
	c.alignment = BoxContainer.ALIGNMENT_CENTER
	f.add_child(UI.expandir(c))
	c.add_child(UI.etiqueta_pixel(datos.nombre, UI.T_TEXTO, UI.TEXTO))
	var coste := UI.fila(16)
	var alcanza_dinero: bool = economia.recursos["presupuesto"] >= datos.dinero
	var alcanzan_materiales: bool = economia.recursos["materiales"] >= datos.materiales
	coste.add_child(UI.etiqueta_pixel(UI.dinero(datos.dinero), 8, UI.BIEN if alcanza_dinero else UI.CRITICO))
	coste.add_child(UI.etiqueta_pixel("%d mat." % datos.materiales, 8, UI.ACENTO if alcanzan_materiales else UI.CRITICO))
	c.add_child(coste)
	var lineas := lineas_energia_y_produccion(datos)
	for linea: Array in lineas:
		c.add_child(UI.etiqueta_pixel(linea[0], 8, linea[1]))
	# Alto según las líneas: nombre (10 px) + costo y cada línea (8 px), separadas 5 px.
	custom_minimum_size.y = maxf(LADO_ICONO + 14, 26 + 13 * (lineas.size() + 1))
	for hijo: Control in find_children("*", "Control", true, false):
		hijo.mouse_filter = Control.MOUSE_FILTER_IGNORE



## Lo que gasta o produce el módulo: [[texto, color], ...]. La energía primero
## ("Consume 10 kW" o "Produce 20 kW"), después lo que produce por sol.
static func lineas_energia_y_produccion(d: DatosModulo) -> Array:
	var lineas := []
	var produce_kw: float = d.produce.get("energia", 0.0)
	if produce_kw > 0.0:
		lineas.append(["Produce %s" % UI.kw(produce_kw), UI.BIEN])
	elif d.consumo_kw > 0.0:
		lineas.append(["Consume %s" % UI.kw(d.consumo_kw), UI.ADVERTENCIA])
	const CORTO := { "oxigeno": "O2", "agua": "agua", "comida": "comida", "materiales": "mat." }
	for recurso: String in d.produce:
		if recurso != "energia":
			var unidad: String = UI.UNIDAD.get(recurso, "")
			lineas.append(["+%s%s %s/sol" % [UI.num(d.produce[recurso]), " " + unidad if unidad != "" else "",
				CORTO.get(recurso, recurso)], UI.TEXTO_SUAVE])
	if d.nota_produccion != "":
		lineas.append([d.nota_produccion, UI.TEXTO_SUAVE])
	return lineas


## Cuadro oscuro con la forma del módulo: una casilla por cada casilla del mapa, rellena con
## el trozo correspondiente del sprite (o amarilla si el módulo no tiene sprite).
func _icono() -> Control:
	var icono := Control.new()
	icono.custom_minimum_size = Vector2(LADO_ICONO, LADO_ICONO)
	icono.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icono.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var tam := datos.tam
	var textura := datos.textura
	icono.draw.connect(func() -> void:
		icono.draw_rect(Rect2(Vector2.ZERO, icono.size), UI.FONDO)
		var hueco := 1.0
		var lado := minf(6.0, (LADO_ICONO - 6.0 - hueco * (maxi(tam.x, tam.y) - 1)) / maxi(tam.x, tam.y))
		var total := Vector2(tam) * lado + Vector2(tam - Vector2i.ONE) * hueco
		var inicio := ((icono.size - total) / 2.0).floor()
		for y in tam.y:
			for x in tam.x:
				var celda := Rect2(inicio + Vector2(x, y) * (lado + hueco), Vector2(lado, lado))
				if textura:
					var lado_fuente := textura.get_size() / Vector2(tam)
					var fuente := Rect2(Vector2(x, y) * lado_fuente, lado_fuente)
					icono.draw_texture_rect_region(textura, celda, fuente)
				else:
					icono.draw_rect(celda, UI.ADVERTENCIA))
	return icono
