# menu_comando.gd
# Menú del Módulo de Comando: métricas e historial de recursos, mejora del módulo, tripulación y asignación de tareas.

class_name MenuComando
extends MenuModulo
## HU-02: tripulación, métricas de la base, historial, nivel del módulo y tablero de tareas.
## Diseño: docs/diseno/Modulo Comando.pdf
##   (Oxígeno 108 -1/Sol)(Energía ...)...(Presupuesto 1150 +25/Sol)   clic: historial
##   ╭ Nivel 1/5  Producción x1 ───────── [Mejorar Módulo de Comando ($400 ...)] ╮
##   Tripulación [ 3 ]        Tareas disponibles [ 9 ]
##   (foto) Elena ...         ╭ Limpiar paneles solares ──── [Asignar a Elena ...] ╮

var recurso_historial := ""


func construir() -> void:
	if recurso_historial != "":
		_construir_historial()
		return
	contenido.add_child(_barra_metricas())
	contenido.add_child(_panel_mejora())
	var cuerpo := UI.fila(12)
	cuerpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	contenido.add_child(cuerpo)
	cuerpo.add_child(_columna_tripulacion())
	cuerpo.add_child(_tablero_tareas())


func atras() -> bool:
	if recurso_historial != "":
		_ver_historial("")
		return true
	return false


func _ver_historial(recurso: String) -> void:
	recurso_historial = recurso
	_pedir_reconstruccion()


# --- Barra superior -------------------------------------------------------

func _barra_metricas() -> Control:
	var barra := UI.fila(16)
	for recurso: String in EstadoJuego.datos_balance.recursos_comando:
		var saldo := EstadoJuego.economia.balance(recurso)
		var b := UI.boton("", _ver_historial.bind(recurso))
		b.custom_minimum_size = Vector2(0, 50)
		b.tooltip_text = "Ver historial de %d soles" % EstadoJuego.datos_balance.soles_historial
		var c := UI.columna(3)
		c.alignment = BoxContainer.ALIGNMENT_CENTER
		c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# La energía muestra su balance en kW (potencia); lo demás, cuánto cambia por sol.
		var por_sol: String = UI.kw(saldo, true) if recurso == "energia" \
			else ("+" if saldo >= 0.0 else "") + UI.dinero(saldo) + "/Sol" if recurso == "presupuesto" \
			else "%s%s/Sol" % [UI.con_signo(saldo), " " + UI.UNIDAD[recurso] if UI.UNIDAD.has(recurso) else ""]
		for linea: Array in [[Enums.NOMBRE_RECURSO[recurso], UI.TEXTO],
				[UI.cantidad(recurso, EstadoJuego.economia.valor(recurso)), UI.COLOR_RECURSO.get(recurso, UI.TEXTO)],
				[por_sol, UI.CRITICO if EstadoJuego.economia.es_critico(recurso) else UI.TEXTO]]:
			var etiqueta := UI.etiqueta_pixel(linea[0], UI.T_TEXTO, linea[1])
			etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			c.add_child(etiqueta)
		b.add_child(c)
		barra.add_child(UI.expandir(b))
	return barra


## Nivel actual, multiplicador y botón de mejora (en curso o nivel máximo: deshabilitado).
func _panel_mejora() -> Control:
	var comando := EstadoJuego.comando
	var panel := UI.tarjeta(UI.TARJETA, 8)
	var f := UI.fila(12)
	panel.add_child(f)
	f.add_child(UI.expandir(UI.seccion("Nivel %d/%d   Producción x%s" % [
		comando.nivel, comando.nivel_max(), UI.num(comando.multiplicador())])))
	var mejora := comando.siguiente_mejora()
	var texto := "Nivel máximo alcanzado"
	if comando.soles_mejora > 0:
		texto = "Mejorando a nivel %d: faltan %s" % [comando.nivel + 1, UI.soles(comando.soles_mejora)]
	elif not mejora.is_empty():
		texto = "Mejorar Módulo de Comando (%s + %d materiales %d soles)" % [
			UI.dinero(mejora["dinero"]), mejora["materiales"], mejora["soles"]]
	f.add_child(UI.boton_accion(texto, _pedir_mejora, comando.puede_mejorar()))
	return panel


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
		g.draw_style_box(UI.estilo(UI.TARJETA, UI.BORDE, UI.RADIO, 12, 2), Rect2(Vector2.ZERO, g.size))
		texto.call(Vector2(12, 19), titulo, 14, UI.TEXTO)
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
	var caja := UI.columna(8)
	caja.custom_minimum_size = Vector2(260, 0)
	caja.size_flags_vertical = Control.SIZE_EXPAND_FILL
	caja.add_child(UI.seccion("Tripulación [ %d ]" % EstadoJuego.tripulacion.activos()))
	var lista := UI.columna(6)
	for t in EstadoJuego.tripulacion.colonos + EstadoJuego.tripulacion.en_viaje:
		lista.add_child(TarjetaColono.new(t, Callable(), false, true))
	if EstadoJuego.tripulacion.colonos.is_empty():
		lista.add_child(UI.parrafo("No hay colonos. Recluta desde el módulo de descanso."))
	caja.add_child(vista_con_scroll(lista))
	return caja


# --- Tablero de tareas ----------------------------------------------------

func _tablero_tareas() -> Control:
	var caja := UI.columna(8)
	UI.expandir(caja)
	caja.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var tareas := EstadoJuego.tareas.disponibles()
	caja.add_child(UI.seccion("Tareas disponibles [ %d ]" % tareas.size()))
	var lista := UI.columna(6)
	for tarea in tareas:
		lista.add_child(_tarjeta_tarea(tarea))
	caja.add_child(vista_con_scroll(lista))
	return caja


## Tarea con sus datos a la izquierda y, a la derecha, un botón por cada colono
## libre con el rol necesario (o un aviso si no hay ninguno).
func _tarjeta_tarea(tarea: Dictionary) -> Control:
	var tarjeta := UI.tarjeta(UI.TARJETA, 8)
	var f := UI.fila(10)
	tarjeta.add_child(f)
	var c := UI.columna(2)
	f.add_child(UI.expandir(c))
	var titulo := UI.etiqueta_pixel(tarea["titulo"], UI.T_TEXTO)
	titulo.custom_minimum_size = Vector2(0, 14)
	c.add_child(titulo)
	c.add_child(UI.etiqueta("%s · %d soles" % [Enums.NOMBRE_ROL[tarea["rol"]], tarea["soles"]], 11, UI.BIEN))
	var entorno := "Interior (sin exposición)"
	if tarea["exterior"]:
		entorno = "Exterior (+%s radiación)" % UI.num(tarea["radiacion"])
	c.add_child(UI.etiqueta(entorno, 11, UI.ADVERTENCIA if tarea["exterior"] else UI.TEXTO_SUAVE))
	c.add_child(UI.etiqueta(UI.texto_recompensa(tarea["recompensa"]), 11, UI.BIEN))

	var botones := UI.columna(4)
	botones.alignment = BoxContainer.ALIGNMENT_CENTER
	f.add_child(botones)
	var libres := EstadoJuego.tareas.colonos_para(tarea)
	for t in libres:
		botones.add_child(_boton_asignar("Asignar a %s" % t.nombre, _pedir_asignacion.bind(tarea, t), true))
	if libres.is_empty():
		botones.add_child(_boton_asignar("Ningún colono libre tiene este rol", Callable(), false))
	return tarjeta


## Botón pequeño con letra normal (los nombres largos no caben en la pixel).
func _boton_asignar(texto: String, accion: Callable, habilitado: bool) -> Button:
	var b := UI.boton_accion(texto, accion if habilitado else func() -> void: pass, habilitado)
	b.add_theme_font_override("font", UI.FUENTE_NORMAL)
	b.add_theme_font_size_override("font_size", 12)
	b.add_theme_color_override("font_disabled_color", UI.TEXTO)
	return b


func _pedir_asignacion(tarea: Dictionary, t: DatosColono) -> void:
	var texto := "%s\nAsignar a %s durante %d soles" % [tarea["titulo"], t.nombre, tarea["soles"]]
	interfaz.confirmar("Confirmar asignación", texto, EstadoJuego.tareas.asignar.bind(tarea, t))
