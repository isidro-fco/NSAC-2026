# cabina.gd
# Piezas de interfaz con el estilo de cabina del Módulo de Comando, compartidas por los menús de módulo.

class_name Cabina
extends RefCounted
## Estilo "pantalla de cabina" (Modulo Comando.pdf): pantallas oscuras con
## rejilla, encabezados pixel con contador, píldoras de estado, fichas de
## colono con borde naranja y tarjetas de lista con borde fino.
##   TRIPULACION [3]                     2 LIBRES
##   ┌ ▣ ELENA VARGAS RUIZ ─────── [LIBRE] ┐
##   │   INGENIERIA                        │
##   │   RAD ▬▬▭▭▭▭▭│▭  12/120              │
##   └─────────────────────────────────────┘

const NARANJA := UI.ACENTO           # bordes de fichas, roles, contadores
const VERDE := UI.BIEN               # libre, recompensas, balance positivo
const ROJO := UI.CRITICO             # en misión, enfermo, umbral de radiación
const REJILLA_FONDO := Color("#152331")
const REJILLA_LINEA := Color("#213549")
const REJILLA_BORDE := Color("#2f455c")
const TARJETA := Color("#1a2b3d")
const PASO_REJILLA := 16
const ALTO_ENCABEZADO := 24


## Mayúsculas sin tildes: la fuente pixel no trae las vocales acentuadas en
## mayúscula (y el diseño las escribe así: "OXIGENO", "INGENIERIA").
static func mayus(texto: String) -> String:
	var t := texto.to_upper()
	for par: Array in [["Á", "A"], ["É", "E"], ["Í", "I"], ["Ó", "O"], ["Ú", "U"], ["Ü", "U"]]:
		t = t.replace(par[0], par[1])
	return t


## Pantalla de cabina (fondo de listas y tableros): el mismo marco con
## tornillos que las pantallas de recursos.
static func pantalla(margen := 8) -> PanelContainer:
	var panel := PanelContainer.new()
	UI.aplicar_marco(panel, UI.MARGEN_MARCO + margen)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return panel


## Etiqueta pixel centrada en las dos direcciones.
static func centrada(texto: String, color := UI.TEXTO, tam := UI.T_TEXTO) -> Label:
	var etiqueta := UI.etiqueta_pixel(texto, tam, color)
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiqueta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return etiqueta


## Etiqueta pixel de una línea que se recorta con "…" si no cabe.
static func recortada(texto: String, tam := UI.T_TEXTO, color := UI.TEXTO) -> Label:
	var etiqueta := UI.etiqueta_pixel(texto, tam, color)
	etiqueta.clip_text = true
	etiqueta.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return etiqueta


## Barra fina sin texto (reservas, radiación, avance).
static func barra(valor: float, maximo: float, color: Color, alto := 4) -> ProgressBar:
	var b := ProgressBar.new()
	b.max_value = maximo
	b.value = valor
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, alto)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_theme_stylebox_override("background", UI.estilo(REJILLA_LINEA, REJILLA_LINEA, 0, 0, 0))
	b.add_theme_stylebox_override("fill", UI.estilo(color, color, 0, 0, 0))
	return b


## Verde por encima de la mitad, ámbar por encima de un cuarto, rojo debajo.
static func color_fraccion(fraccion: float) -> Color:
	return VERDE if fraccion > 0.5 else UI.ADVERTENCIA if fraccion > 0.25 else UI.CRITICO


## Encabezado de sección: "TRIPULACION [3]" y, a la derecha, un detalle en gris.
## Con cuenta < 0 no lleva contador.
static func encabezado(titulo: String, cuenta := -1, detalle := "") -> HBoxContainer:
	var f := UI.fila(6)
	f.custom_minimum_size = Vector2(0, ALTO_ENCABEZADO)
	var etiqueta := UI.etiqueta_pixel(mayus(titulo), UI.T_TEXTO)
	etiqueta.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	f.add_child(etiqueta)
	if cuenta >= 0:
		f.add_child(pildora(str(cuenta), NARANJA))
	f.add_child(UI.expandir(Control.new()))
	if detalle != "":
		var d := UI.etiqueta_pixel(mayus(detalle), UI.T_DETALLE, UI.TEXTO_SUAVE)
		d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		f.add_child(d)
	return f


## Píldora con texto pixel: rellena (texto oscuro) o en contorno (texto del color).
static func pildora(texto: String, color: Color, relleno := true) -> PanelContainer:
	var p := PanelContainer.new()
	var caja := UI.estilo(color if relleno else Color(color, 0.12), color, 0, 0, 1)
	caja.content_margin_left = 5
	caja.content_margin_right = 5
	caja.content_margin_top = 2
	caja.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", caja)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(UI.etiqueta_pixel(texto, UI.T_DETALLE, REJILLA_FONDO if relleno else color))
	return p


## Línea divisoria con rótulo: "── SIN TRIPULANTE LIBRE (2) ──".
static func separador(texto: String, cuenta := -1) -> Control:
	var f := UI.fila(8)
	f.custom_minimum_size = Vector2(0, 18)
	for i in 2:
		var linea := ColorRect.new()
		linea.color = REJILLA_BORDE
		linea.custom_minimum_size = Vector2(0, 1)
		linea.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		f.add_child(UI.expandir(linea))
		if i == 0:
			var rotulo := mayus(texto) + (" (%d)" % cuenta if cuenta >= 0 else "")
			f.add_child(UI.etiqueta_pixel(rotulo, UI.T_DETALLE, UI.TEXTO_SUAVE))
	return f


## Botón pequeño en pixel: del color dado si está habilitado, apagado si no.
static func boton(texto: String, accion: Callable, habilitado := true, color := UI.ACENTO) -> Button:
	var b := UI.boton(mayus(texto), accion, habilitado)
	b.add_theme_font_override("font", UI.fuente_pixel())
	b.add_theme_font_size_override("font_size", UI.T_DETALLE)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UI.pintar_boton_pixel(b, habilitado, color, REJILLA_LINEA, 0)
	b.add_theme_color_override("font_disabled_color", UI.TEXTO_SUAVE)
	return b


## Botón de un grupo de opciones: naranja el elegido, apagado el resto.
static func boton_opcion(texto: String, accion: Callable, elegido: bool, alto := 34) -> Button:
	var b := UI.boton(mayus(texto), accion)
	b.add_theme_font_override("font", UI.fuente_pixel())
	b.add_theme_font_size_override("font_size", UI.T_TEXTO)
	b.custom_minimum_size = Vector2(0, alto)
	UI.pintar_boton_pixel(b, elegido, UI.ACENTO, TARJETA.lightened(0.04), 0)
	return b


## Botón ancho de dos líneas (mejorar, expandir, reclutar): título y detalle.
## Si no está habilitado y hay `motivo`, el detalle va en rojo y el motivo en el tooltip.
static func boton_grande(titulo: String, detalle: String, accion: Callable, habilitado := true,
		motivo := "", alto := 56) -> Button:
	var b := UI.boton("", accion, habilitado)
	UI.pintar_boton_pixel(b, habilitado, UI.ACENTO, REJILLA_FONDO, 0)
	b.custom_minimum_size = Vector2(0, alto)
	b.tooltip_text = motivo if not habilitado else ""
	var c := UI.columna(6)
	c.alignment = BoxContainer.ALIGNMENT_CENTER
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(centrada(mayus(titulo), UI.TEXTO_PRIMARIO if habilitado else UI.TEXTO_SUAVE))
	if detalle != "":
		var color := UI.TEXTO_PRIMARIO if habilitado else (UI.CRITICO if motivo != "" else UI.TEXTO_SUAVE)
		c.add_child(centrada(mayus(detalle), color, UI.T_DETALLE))
	# Las etiquetas van sueltas sobre el botón: el ancho mínimo lo da el texto.
	var ancho := 0.0
	for etiqueta: Control in c.get_children():
		ancho = maxf(ancho, etiqueta.get_combined_minimum_size().x)
	b.custom_minimum_size.x = ancho + 24
	b.add_child(c)
	return b


## Celda de cabina (marco con tornillos) con una columna centrada dentro.
## Devuelve [celda, columna].
static func celda(ancho := 0.0, alto := 56.0) -> Array:
	var p := PanelContainer.new()
	UI.aplicar_marco(p, 8)
	p.custom_minimum_size = Vector2(ancho, alto)
	var c := UI.columna(5)
	c.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(c)
	return [p, c]


## Celda con nombre, valor y, si hay capacidad, barra de reserva/capacidad.
static func celda_metrica(nombre: String, valor_texto: String, valor := 0.0, capacidad := 0.0,
		color_valor := UI.TEXTO) -> Control:
	var c: Array = celda()
	UI.expandir(c[0])
	c[1].add_child(centrada(mayus(nombre), UI.TEXTO_SUAVE, UI.T_DETALLE))
	c[1].add_child(centrada(valor_texto, color_valor))
	if capacidad > 0.0:
		var margen := MarginContainer.new()
		margen.add_theme_constant_override("margin_left", 6)
		margen.add_theme_constant_override("margin_right", 6)
		margen.add_child(barra(valor, capacidad, color_fraccion(valor / capacidad)))
		c[1].add_child(margen)
	return c[0]


## Marcas de nivel u ocupación: ■■□□ (llenas en `color`).
static func marcas(llenas: int, total: int, color := NARANJA, ancho := 14) -> HBoxContainer:
	var f := UI.fila(3)
	f.alignment = BoxContainer.ALIGNMENT_CENTER
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in total:
		var m := ColorRect.new()
		m.custom_minimum_size = Vector2(ancho, 5)
		m.color = color if i < llenas else REJILLA_BORDE
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		f.add_child(m)
	return f


## Tarjeta de lista (fondo oscuro con borde fino). Devuelve la tarjeta;
## el contenido se añade como su único hijo. `_color` ya no se dibuja (antes
## era una franja a la izquierda); se conserva para no cambiar las llamadas.
static func tarjeta(_color: Color, margen := 7) -> PanelContainer:
	var t := PanelContainer.new()
	var caja := UI.estilo(TARJETA, REJILLA_BORDE, 0, margen, 1)
	caja.content_margin_left = 10
	t.add_theme_stylebox_override("panel", caja)
	return t


## Deja sitio a la barra de desplazamiento para que no tape las tarjetas.
static func con_margen_scroll(interior: Control) -> Control:
	var margen := MarginContainer.new()
	margen.add_theme_constant_override("margin_right", 10)
	margen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	interior.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margen.add_child(interior)
	return margen


## Texto vacío centrado dentro de una pantalla.
static func vacio(texto: String) -> Control:
	var e := UI.etiqueta_pixel(mayus(texto), UI.T_DETALLE, UI.TEXTO_SUAVE)
	e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	e.custom_minimum_size = Vector2(0, 40)
	e.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return e


# --- Colonos --------------------------------------------------------------

## Color y texto del estado de un colono (la píldora de su ficha).
static func estado_colono(c: DatosColono) -> Array:
	match c.estado:
		Enums.EstadoColono.DISPONIBLE:
			return [VERDE, "LIBRE"]
		Enums.EstadoColono.EN_MISION:
			return [UI.ACENTO, "EN MISION"]
		Enums.EstadoColono.EN_VIAJE:
			return [UI.ADVERTENCIA, "EN VIAJE"]
	return [ROJO, mayus(Enums.NOMBRE_ESTADO_COLONO[c.estado])]


## Retrato cuadrado en pixel art sobre una placa gris; sin foto, el avatar redondo.
static func retrato(c: DatosColono, lado := 42) -> Control:
	var textura := c.textura_retrato()
	if textura == null:
		var avatar := UI.avatar(c, lado - 2)
		avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return avatar
	var placa := PanelContainer.new()
	placa.add_theme_stylebox_override("panel", UI.estilo(Color("#6b6f86"), Color("#3a3d4f"), 0, 1, 1))
	placa.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	placa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var imagen := TextureRect.new()
	imagen.texture = textura
	imagen.custom_minimum_size = Vector2(lado, lado)
	imagen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	imagen.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	imagen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	imagen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	placa.add_child(imagen)
	return placa


## "RAD [barra con marca de enfermedad] 12/120".
static func fila_radiacion(radiacion: float) -> Control:
	var radiacion_max := EstadoJuego.datos_balance.radiacion_max
	var enfermedad := EstadoJuego.datos_balance.radiacion_enfermedad
	var rad := UI.fila(6)
	rad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rotulo := UI.etiqueta_pixel("RAD", UI.T_DETALLE, UI.TEXTO_SUAVE)
	rotulo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rad.add_child(rotulo)
	var color := UI.color_radiacion(radiacion)
	var b := barra(radiacion, radiacion_max, color, 6)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.draw.connect(func() -> void:
		var x := b.size.x * enfermedad / radiacion_max
		b.draw_rect(Rect2(x - 1, -2, 2, b.size.y + 4), Color(ROJO, 0.9)))
	rad.add_child(UI.expandir(b))
	var valor := UI.etiqueta_pixel("%s/%d" % [UI.num(radiacion), int(radiacion_max)], UI.T_DETALLE, color)
	valor.custom_minimum_size = Vector2(52, 0)
	valor.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rad.add_child(valor)
	return rad


## Ficha de un colono: retrato, nombre con su estado a la derecha, rol, la
## misión en curso con su avance y la dosis de radiación. `accion` (opcional)
## va a la derecha de la ficha; `seleccionado` la resalta.
static func ficha_colono(c: DatosColono, accion: Control = null, seleccionado := false) -> PanelContainer:
	var libre := c.estado == Enums.EstadoColono.DISPONIBLE
	var estado: Array = estado_colono(c)
	var ficha := PanelContainer.new()
	var fondo := Color(NARANJA, 0.16) if seleccionado else REJILLA_FONDO
	var borde := NARANJA if libre or seleccionado else Color(NARANJA, 0.45)
	var caja := UI.estilo(fondo, borde, 0, 6, 2)
	caja.content_margin_left = 6
	caja.content_margin_right = 8
	if seleccionado:
		caja.border_width_left = 5
	ficha.add_theme_stylebox_override("panel", caja)
	var radiacion_max := EstadoJuego.datos_balance.radiacion_max
	var enfermedad := EstadoJuego.datos_balance.radiacion_enfermedad
	ficha.tooltip_text = "Radiación: %s / %d (enferma a partir de %d)" % [UI.num(c.radiacion), int(radiacion_max), int(enfermedad)]
	var f := UI.fila(8)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ficha.add_child(f)
	var foto := retrato(c)
	if not libre and not seleccionado:
		foto.modulate = Color(1, 1, 1, 0.6)
	f.add_child(foto)
	var datos := UI.columna(4)
	datos.alignment = BoxContainer.ALIGNMENT_CENTER
	datos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f.add_child(UI.expandir(datos))

	var cabecera := UI.fila(6)
	cabecera.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cabecera.add_child(UI.expandir(recortada(mayus(c.nombre))))
	cabecera.add_child(pildora(estado[1], estado[0]))
	datos.add_child(cabecera)
	var rol := UI.fila(6)
	rol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var etiqueta_rol := UI.etiqueta_pixel(mayus(Enums.NOMBRE_ROL[c.rol]), UI.T_DETALLE, NARANJA)
	etiqueta_rol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rol.add_child(UI.expandir(etiqueta_rol))
	# La acción va junto al rol para que el nombre tenga todo el ancho.
	if accion != null:
		accion.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rol.add_child(accion)
	datos.add_child(rol)

	match c.estado:
		Enums.EstadoColono.EN_MISION when c.tarea.has("titulo"):
			var total := maxf(float(c.tarea["soles"]), 1.0)
			var mision := UI.fila(6)
			mision.mouse_filter = Control.MOUSE_FILTER_IGNORE
			mision.add_child(UI.expandir(recortada("> " + mayus(c.tarea["titulo"]), UI.T_DETALLE)))
			mision.add_child(UI.etiqueta_pixel("FALTA%s %s" % ["" if c.soles_restantes == 1 else "N",
				mayus(UI.soles(c.soles_restantes))], UI.T_DETALLE, UI.ACENTO))
			datos.add_child(mision)
			datos.add_child(barra(total - c.soles_restantes, total, UI.ACENTO, 3))
		Enums.EstadoColono.EN_VIAJE:
			datos.add_child(UI.etiqueta_pixel("LLEGA EN %s" % mayus(UI.soles(c.soles_restantes)),
				UI.T_DETALLE, UI.ADVERTENCIA))
	if c.estado != Enums.EstadoColono.EN_VIAJE:
		datos.add_child(fila_radiacion(c.radiacion))
	return ficha
