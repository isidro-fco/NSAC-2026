# menu_comando.gd
# Menú del Módulo de Comando: métricas e historial de recursos, mejora del módulo, tripulación y asignación de tareas.

class_name MenuComando
extends MenuModulo
## HU-02: tripulación, métricas de la base, historial, nivel del módulo y tablero de tareas.
## Diseño: Modulo Comando.pdf (panel de cabina con pantallas de rejilla):
##     OXIGENO    ENERGIA    AGUA     COMIDA    MATERIALES  PRESUPUESTO
##   [94.7 kg ] [5000 kWh] [44 L  ] [40.9 kg] [   60    ] [$1,250 M]     clic: historial
##   [-0.9/Sol] [ +20 kW ] [-12/Sol] [-1.9/Sol] [        ] [+25 M/Sol]
##   [▬▬▬▬▬▭▭ ] [▬▬▬▬▬▬▭ ] ...                                           reserva / capacidad
##   [NIVEL 1/5 ■□□□□] [PRODUCCION x1 > x1.25] [MEJORAR MODULO DE COMANDO / costo]   (la X va en el marco)
##   TRIPULACION [3]        2 LIBRES   TAREAS DISPONIBLES [4]
##   ┌ ▣ ELENA VARGAS RUIZ ───┐        ┃ LIMPIAR PANELES SOLARES      [ASIGNAR A ...] ┐
##   │   INGENIERIA DISPONIBLE│        ┃ INGENIERIA · 2 SOLES                         │
##   │   RAD ▬▬▭▭▭▭▭▭  12/100 │        ┃ Exterior (+6 radiación)   +600 kWh Energía   │
##   └────────────────────────┘        ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┘

## Orden de las pantallas de recursos, como en el diseño.
const ORDEN := ["oxigeno", "energia", "agua", "comida", "materiales", "presupuesto"]
const ALTO_FILA_MEJORA := 56

var recurso_historial := ""
## Colono libre seleccionado: el tablero solo muestra las tareas de su rol.
var colono_filtro: DatosColono = null


func _init() -> void:
	con_cabecera = false
	marco_comando = true


func construir() -> void:
	if recurso_historial != "":
		_construir_historial()
		return
	contenido.add_child(_barra_metricas())
	contenido.add_child(_panel_mejora())
	var cuerpo := UI.fila(16)
	cuerpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	contenido.add_child(cuerpo)
	cuerpo.add_child(_columna_tripulacion())
	cuerpo.add_child(UI.expandir(_tablero_tareas()))


func atras() -> bool:
	if recurso_historial != "":
		_ver_historial("")
		return true
	return false


func _ver_historial(recurso: String) -> void:
	recurso_historial = recurso
	_pedir_reconstruccion()

# --- Barra superior -------------------------------------------------------

## Nombres arriba y, debajo, una pantalla de cabina por recurso con su reserva,
## cuánto cambia por sol y una barra de reserva/capacidad. Cada pantalla abre
## el historial del recurso.
func _barra_metricas() -> Control:
	var economia := EstadoJuego.economia
	var tabla := GridContainer.new()
	tabla.columns = ORDEN.size()
	tabla.add_theme_constant_override("h_separation", 6)
	tabla.add_theme_constant_override("v_separation", 4)
	for recurso: String in ORDEN:
		tabla.add_child(UI.expandir(Cabina.centrada(Cabina.mayus(Enums.NOMBRE_RECURSO[recurso]))))
	for recurso: String in ORDEN:
		var saldo := economia.balance(recurso)
		var valor := economia.valor(recurso)
		var capacidad := economia.capacidad(recurso)
		var b := UI.boton("", _ver_historial.bind(recurso))
		UI.aplicar_marco_boton(b)
		b.custom_minimum_size = Vector2(0, 64)
		b.tooltip_text = "Ver historial de %d soles" % EstadoJuego.datos_balance.soles_historial
		if not is_inf(capacidad):
			b.tooltip_text = "%s de %s\n%s" % [UI.cantidad(recurso, valor), UI.cantidad(recurso, capacidad), b.tooltip_text]
		UI.expandir(b)
		var c := UI.columna(5)
		c.alignment = BoxContainer.ALIGNMENT_CENTER
		c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		c.offset_left = 14
		c.offset_right = -14
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.add_child(Cabina.centrada(UI.cantidad(recurso, valor)))
		# La energía muestra su balance en kW (potencia); lo demás, cuánto cambia por sol.
		if recurso != "materiales" or not is_zero_approx(saldo):
			var por_sol: String = UI.kw(saldo, true) if recurso == "energia" \
				else ("+" if saldo >= 0.0 else "") + UI.dinero(saldo) + "/Sol" if recurso == "presupuesto" \
				else "%s%s/Sol" % [UI.con_signo(saldo), " " + UI.UNIDAD[recurso] if UI.UNIDAD.has(recurso) else ""]
			var color := UI.TEXTO_SUAVE
			if economia.es_critico(recurso):
				color = UI.CRITICO
			elif saldo > 0.0:
				color = Cabina.VERDE
			c.add_child(Cabina.centrada(por_sol, color, UI.T_DETALLE))
		if not is_inf(capacidad) and capacidad > 0.0:
			var fraccion := valor / capacidad
			c.add_child(Cabina.barra(valor, capacidad, Cabina.color_fraccion(fraccion)))
		b.add_child(c)
		tabla.add_child(b)
	return tabla


## Nivel con un indicador por nivel, multiplicador actual y siguiente, y el
## botón de mejora (en curso o nivel máximo: deshabilitado).
func _panel_mejora() -> Control:
	var comando := EstadoJuego.comando
	var mejora := comando.siguiente_mejora()
	var f := UI.fila(6)

	var nivel: Array = Cabina.celda(150)
	nivel[1].add_child(Cabina.centrada("NIVEL %d/%d" % [comando.nivel, comando.nivel_max()]))
	var marcas := Cabina.marcas(comando.nivel, comando.nivel_max())
	if comando.soles_mejora > 0 and comando.nivel < comando.nivel_max():
		marcas.get_child(comando.nivel).color = Color(Cabina.NARANJA, 0.45)       # nivel en obra
	nivel[1].add_child(marcas)
	f.add_child(nivel[0])

	var produccion: Array = Cabina.celda(170)
	produccion[1].add_child(Cabina.centrada("PRODUCCION x%s" % UI.num(comando.multiplicador())))
	var siguiente := "SIGUIENTE x%s" % UI.num(comando.multiplicador_siguiente()) if not mejora.is_empty() else "MAXIMA"
	produccion[1].add_child(Cabina.centrada(siguiente, UI.TEXTO_SUAVE, UI.T_DETALLE))
	f.add_child(produccion[0])

	var titulo := "NIVEL MAXIMO ALCANZADO"
	var detalle := "EL MODULO DE COMANDO YA NO SE PUEDE MEJORAR"
	if comando.soles_mejora > 0:
		titulo = "MEJORANDO A NIVEL %d" % (comando.nivel + 1)
		detalle = "FALTAN %s" % Cabina.mayus(UI.soles(comando.soles_mejora))
	elif not mejora.is_empty():
		titulo = "MEJORAR MODULO DE COMANDO"
		detalle = "%s  ·  %d MATERIALES  ·  %s DE OBRA" % [UI.dinero(mejora["dinero"]), mejora["materiales"],
			Cabina.mayus(UI.soles(mejora["soles"]))]
	var puede := comando.puede_mejorar()
	var motivo := ""
	if not puede and comando.soles_mejora == 0 and not mejora.is_empty():
		motivo = "No alcanzan el presupuesto o los materiales"
	var boton := Cabina.boton_grande(titulo, detalle, _pedir_mejora, puede, motivo, ALTO_FILA_MEJORA)
	f.add_child(UI.expandir(boton))
	return f


func _pedir_mejora() -> void:
	var comando := EstadoJuego.comando
	var mejora := comando.siguiente_mejora()
	var texto := "Subir al nivel %d por %s y %d materiales.\nLa obra tarda %d soles; al terminar, la producción pasa a x%s (salvo la energía de los paneles)." % [
		comando.nivel + 1, UI.dinero(mejora["dinero"]), mejora["materiales"], mejora["soles"],
		UI.num(comando.multiplicador_siguiente())]
	interfaz.confirmar("Mejorar Módulo de Comando", texto, comando.mejorar)


func _construir_historial() -> void:
	var nombre: String = Enums.NOMBRE_RECURSO[recurso_historial]
	cabecera_subvista("%s: últimos %d soles" % [nombre, EstadoJuego.datos_balance.soles_historial],
		_ver_historial.bind(""))

	var puntos: Array = EstadoJuego.economia.historial[recurso_historial]
	contenido.add_child(_grafica("Reserva al final de cada sol", puntos, "valor", false))
	contenido.add_child(_grafica("Ganancia o pérdida por sol", puntos, "cambio", true))


## Gráfica de línea del historial. Reserva y balance van en gráficas separadas
## porque tienen escalas distintas; la de balance incluye siempre el cero.
func _grafica(titulo: String, puntos: Array, clave: String, con_cero: bool) -> Control:
	var g := Control.new()
	g.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var valores: Array = puntos.map(func(p: Dictionary) -> float: return p[clave])
	g.draw.connect(func() -> void:
		var texto := func(pos: Vector2, t: String, tam := 11, color := UI.TEXTO_SUAVE) -> void:
			g.draw_string(UI.FUENTE_NORMAL, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, color)
		g.draw_style_box(UI.estilo(Cabina.REJILLA_FONDO, Cabina.REJILLA_BORDE, 0, 12, 1), Rect2(Vector2.ZERO, g.size))
		for x in range(Cabina.PASO_REJILLA, int(g.size.x) - 1, Cabina.PASO_REJILLA):
			g.draw_line(Vector2(x, 1), Vector2(x, g.size.y - 1), Cabina.REJILLA_LINEA)
		for y in range(Cabina.PASO_REJILLA, int(g.size.y) - 1, Cabina.PASO_REJILLA):
			g.draw_line(Vector2(1, y), Vector2(g.size.x - 1, y), Cabina.REJILLA_LINEA)
		g.draw_string(UI.fuente_pixel(), Vector2(12, 20), Cabina.mayus(titulo), HORIZONTAL_ALIGNMENT_LEFT, -1, UI.T_TEXTO, UI.TEXTO)
		if valores.size() < 2:
			texto.call(Vector2(12, g.size.y / 2.0), "Se necesitan 2 soles de datos para trazar la línea.", 12)
			return
		var area := Rect2(46, 28, g.size.x - 62, g.size.y - 52)
		var minimo: float = minf(valores.min(), 0.0) if con_cero else valores.min()
		var maximo: float = maxf(valores.max(), 0.0) if con_cero else valores.max()
		if is_equal_approx(minimo, maximo):
			minimo -= 1.0
			maximo += 1.0
		var y_de := func(v: float) -> float: return area.end.y - area.size.y * (v - minimo) / (maximo - minimo)
		for v: float in [minimo, (minimo + maximo) / 2.0, maximo]:
			g.draw_line(Vector2(area.position.x, y_de.call(v)), Vector2(area.end.x, y_de.call(v)), Color(1, 1, 1, 0.07))
			texto.call(Vector2(6, y_de.call(v) + 4), UI.num(v))
		if minimo < 0.0 and maximo > 0.0:
			g.draw_line(Vector2(area.position.x, y_de.call(0.0)), Vector2(area.end.x, y_de.call(0.0)), Color(1, 1, 1, 0.4))
		texto.call(Vector2(area.position.x, g.size.y - 6), "Sol %d" % puntos[0]["sol"])
		texto.call(Vector2(area.end.x - 44, g.size.y - 6), "Sol %d" % puntos[-1]["sol"])
		var linea := PackedVector2Array()
		for i in valores.size():
			linea.append(Vector2(area.position.x + area.size.x * i / (valores.size() - 1.0), y_de.call(valores[i])))
		g.draw_polyline(linea, UI.ACENTO, 2.0, true))
	return g


# --- Tripulación ----------------------------------------------------------

func _columna_tripulacion() -> Control:
	var tripulacion := EstadoJuego.tripulacion
	var libres := tripulacion.colonos.filter(func(c: DatosColono) -> bool:
		return c.estado == Enums.EstadoColono.DISPONIBLE).size()
	var columna := UI.columna(6)
	columna.custom_minimum_size = Vector2(340, 0)
	columna.add_child(Cabina.encabezado("TRIPULACION", tripulacion.colonos.size(),
		"%d LIBRE%s" % [libres, "" if libres == 1 else "S"]))
	var pantalla := Cabina.pantalla(8)
	columna.add_child(pantalla)
	var lista := UI.columna(6)
	for t in tripulacion.colonos + tripulacion.en_viaje:
		lista.add_child(_ficha_colono(t))
	if tripulacion.colonos.is_empty():
		lista.add_child(UI.parrafo("No hay colonos. Recluta desde el módulo de descanso."))
	elif libres > 0:
		lista.add_child(Cabina.vacio("Clic en un tripulante libre para ver sus tareas"))
	pantalla.add_child(vista_con_scroll(Cabina.con_margen_scroll(lista)))
	return columna


## Ficha de colono; la de un colono libre se puede seleccionar para filtrar
## el tablero de tareas por su rol (otro clic la deselecciona).
func _ficha_colono(c: DatosColono) -> Control:
	var seleccionado := c == colono_filtro
	var ficha := Cabina.ficha_colono(c, null, seleccionado)
	if c.estado == Enums.EstadoColono.DISPONIBLE:
		ficha.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		ficha.tooltip_text += "\nClic: ver solo las tareas de %s" % Enums.NOMBRE_ROL[c.rol]
		ficha.gui_input.connect(func(evento: InputEvent) -> void:
			if evento is InputEventMouseButton and evento.pressed and evento.button_index == MOUSE_BUTTON_LEFT:
				_filtrar_por(null if seleccionado else c))
	return ficha


func _filtrar_por(c: DatosColono) -> void:
	colono_filtro = c
	_pedir_reconstruccion()


# --- Tablero de tareas ----------------------------------------------------

## Tareas disponibles: primero las que alguien libre puede hacer ya y, bajo un
## separador, las que esperan a un tripulante con el rol adecuado. Con un
## colono seleccionado solo se ven las de su rol.
func _tablero_tareas() -> Control:
	if colono_filtro != null and (colono_filtro.estado != Enums.EstadoColono.DISPONIBLE
			or not EstadoJuego.tripulacion.colonos.has(colono_filtro)):
		colono_filtro = null
	var tareas := EstadoJuego.tareas.disponibles()
	if colono_filtro != null:
		tareas = tareas.filter(func(t: Dictionary) -> bool: return t["rol"] == colono_filtro.rol)
	var listas := tareas.filter(func(t: Dictionary) -> bool: return not EstadoJuego.tareas.colonos_para(t).is_empty())
	var bloqueadas := tareas.filter(func(t: Dictionary) -> bool: return EstadoJuego.tareas.colonos_para(t).is_empty())
	var columna := UI.columna(6)
	var detalle := "%d SE PUEDEN ASIGNAR" % listas.size() if not tareas.is_empty() else ""
	var encabezado := Cabina.encabezado("TAREAS DISPONIBLES", tareas.size(), "" if colono_filtro != null else detalle)
	if colono_filtro != null:
		var quitar := Cabina.boton("Para %s  x" % colono_filtro.nombre.get_slice(" ", 0), _filtrar_por.bind(null), true)
		quitar.tooltip_text = "Quitar el filtro y ver todas las tareas"
		for estado: String in ["normal", "hover", "pressed", "hover_pressed"]:
			var caja: StyleBox = quitar.get_theme_stylebox(estado)
			caja.content_margin_top = 3
			caja.content_margin_bottom = 3
		encabezado.add_child(quitar)
	columna.add_child(encabezado)
	var pantalla := Cabina.pantalla(8)
	columna.add_child(pantalla)
	var lista := UI.columna(6)
	for tarea: Dictionary in listas:
		lista.add_child(_tarjeta_tarea(tarea))
	if not bloqueadas.is_empty():
		lista.add_child(Cabina.separador("SIN TRIPULANTE LIBRE", bloqueadas.size()))
		for tarea: Dictionary in bloqueadas:
			lista.add_child(_tarjeta_tarea(tarea))
	if tareas.is_empty():
		var vacio := "No hay tareas disponibles: toda la tripulación está ocupada en ellas."
		if colono_filtro != null:
			vacio = "No quedan tareas de %s disponibles." % Enums.NOMBRE_ROL[colono_filtro.rol]
		lista.add_child(UI.parrafo(vacio))
	pantalla.add_child(vista_con_scroll(Cabina.con_margen_scroll(lista)))
	return columna


## Tarjeta de una tarea (exterior con radiación o interior).
## Arriba el título y la duración; debajo, etiquetas de rol y entorno y la
## recompensa. A la derecha, un botón por colono libre con el rol necesario;
## avisa si la dosis de la tarea lo dejaría cerca de enfermar.
func _tarjeta_tarea(tarea: Dictionary) -> Control:
	var libres := EstadoJuego.tareas.colonos_para(tarea)
	if colono_filtro != null:
		libres = libres.filter(func(t: DatosColono) -> bool: return t == colono_filtro)
	var tarjeta := Cabina.tarjeta(UI.ADVERTENCIA if tarea["exterior"] else Cabina.VERDE)
	if libres.is_empty():
		tarjeta.modulate = Color(1, 1, 1, 0.55)

	var f := UI.fila(10)
	tarjeta.add_child(f)
	var c := UI.columna(5)
	f.add_child(UI.expandir(c))

	var cabecera := UI.fila(8)
	var titulo := UI.etiqueta_pixel(Cabina.mayus(tarea["titulo"]), UI.T_TEXTO)
	titulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cabecera.add_child(UI.expandir(titulo))
	cabecera.add_child(Cabina.pildora(Cabina.mayus(UI.soles(tarea["soles"])), UI.TEXTO_SUAVE, false))
	c.add_child(cabecera)

	var etiquetas := HFlowContainer.new()
	etiquetas.add_theme_constant_override("h_separation", 6)
	etiquetas.add_theme_constant_override("v_separation", 4)
	etiquetas.add_child(Cabina.pildora(Cabina.mayus(Enums.NOMBRE_ROL[tarea["rol"]]), Cabina.NARANJA, false))
	if tarea["exterior"]:
		etiquetas.add_child(Cabina.pildora("EXTERIOR +%s RAD" % UI.num(tarea["radiacion"]), UI.ADVERTENCIA, false))
	else:
		etiquetas.add_child(Cabina.pildora("INTERIOR", UI.TEXTO_SUAVE, false))
	c.add_child(etiquetas)

	var recompensa := UI.fila(6)
	var rotulo := UI.etiqueta_pixel("RECOMPENSA", UI.T_DETALLE, UI.TEXTO_SUAVE)
	rotulo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	recompensa.add_child(rotulo)
	recompensa.add_child(UI.expandir(UI.parrafo(UI.texto_recompensa(tarea["recompensa"]), 12, Cabina.VERDE)))
	c.add_child(recompensa)

	var botones := UI.columna(4)
	botones.alignment = BoxContainer.ALIGNMENT_CENTER
	botones.custom_minimum_size = Vector2(130, 0)
	f.add_child(botones)
	var enfermedad := EstadoJuego.datos_balance.radiacion_enfermedad
	for t in libres:
		var dosis: float = t.radiacion + (tarea["radiacion"] if tarea["exterior"] else 0.0)
		var riesgo: bool = tarea["exterior"] and dosis >= enfermedad * 0.7
		# Solo el nombre de pila para que la tarjeta no ensanche la ventana.
		var b := Cabina.boton("%sAsignar a %s" % ["! " if riesgo else "", t.nombre.get_slice(" ", 0)],
			_pedir_asignacion.bind(tarea, t), true, UI.CRITICO if dosis >= enfermedad else UI.ACENTO)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.tooltip_text = "Asignar a %s" % t.nombre
		if tarea["exterior"]:
			b.tooltip_text += "\nRadiación: %s → %s / %d" % [UI.num(t.radiacion), UI.num(dosis), int(enfermedad)]
			if dosis >= enfermedad:
				b.tooltip_text += "\n¡Enfermaría por radiación!"
			elif riesgo:
				b.tooltip_text += "\nQuedaría cerca del umbral de enfermedad"
		botones.add_child(b)
	if libres.is_empty():
		var aviso := UI.etiqueta_pixel("REQUIERE\n%s" % Cabina.mayus(Enums.NOMBRE_ROL[tarea["rol"]]), UI.T_DETALLE, UI.TEXTO_SUAVE)
		aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		aviso.mouse_filter = Control.MOUSE_FILTER_PASS
		aviso.tooltip_text = "Ningún colono libre tiene el rol %s" % Enums.NOMBRE_ROL[tarea["rol"]]
		botones.add_child(aviso)
	return tarjeta


func _pedir_asignacion(tarea: Dictionary, t: DatosColono) -> void:
	var texto := "%s\nAsignar a %s durante %d soles" % [tarea["titulo"], t.nombre, tarea["soles"]]
	if tarea["exterior"]:
		var dosis: float = t.radiacion + tarea["radiacion"]
		texto += "\nRadiación: %s → %s / %d" % [UI.num(t.radiacion), UI.num(dosis),
			int(EstadoJuego.datos_balance.radiacion_enfermedad)]
	interfaz.confirmar("Confirmar asignación", texto, EstadoJuego.tareas.asignar.bind(tarea, t))
