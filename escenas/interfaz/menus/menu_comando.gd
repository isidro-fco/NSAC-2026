class_name MenuComando
extends Control
## HU-02: tripulación, métricas de la base, historial y tablero de tareas.

var interfaz                  # escena Juego: abre diálogos y cierra el menú
var contenido: VBoxContainer
var scrolls: Array[ScrollContainer] = []
var reconstruccion_pendiente := false

var recurso_historial := ""
var tarea_elegida := ""


func iniciar(juego: Node, titulo: String) -> void:
	interfaz = juego
	contenido = Hud.marco_menu(self, titulo, cerrar)
	EstadoJuego.estado_cambiado.connect(_pedir_reconstruccion)
	_reconstruir()


func cerrar() -> void:
	interfaz.cerrar_menu()


func vista_con_scroll(interior: Control) -> ScrollContainer:
	var scroll := Hud.desplazable(interior)
	scrolls.append(scroll)
	return scroll


func _pedir_reconstruccion() -> void:
	if not reconstruccion_pendiente:
		reconstruccion_pendiente = true
		_reconstruir.call_deferred()


func _reconstruir() -> void:
	reconstruccion_pendiente = false
	Hud.reconstruir(contenido, scrolls, construir)


func construir() -> void:
	if recurso_historial != "":
		_construir_historial()
		return
	contenido.add_child(_barra_metricas())
	var cuerpo := Hud.fila(12)
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
	var barra := Hud.fila(6)
	for recurso: String in EstadoJuego.datos_balance.recursos_comando:
		var saldo := EstadoJuego.balance(recurso)
		var texto := "%s\n%s\n%s/sol" % [
			Enums.NOMBRE_RECURSO[recurso], Hud.num(EstadoJuego.valor(recurso)), Hud.con_signo(saldo)]
		var b := Hud.boton(texto, _ver_historial.bind(recurso))
		b.custom_minimum_size = Vector2(0, 76)
		b.tooltip_text = "Ver historial de %d soles" % EstadoJuego.datos_balance.soles_historial
		barra.add_child(Hud.expandir(b))
	return barra


func _construir_historial() -> void:
	var nombre: String = Enums.NOMBRE_RECURSO[recurso_historial]
	var cabecera := Hud.fila()
	cabecera.add_child(Hud.boton("< Volver", _ver_historial.bind(""), true, Hud.FANTASMA))
	cabecera.add_child(Hud.etiqueta("%s: últimos %d soles" % [nombre, EstadoJuego.datos_balance.soles_historial], 16))
	contenido.add_child(cabecera)

	var puntos: Array = EstadoJuego.historial[recurso_historial]
	for datos: Array in [
		["Reserva al final de cada sol", "valor", false],
		["Ganancia o pérdida por sol", "cambio", true],
	]:
		var grafica := Grafica.new()
		grafica.size_flags_vertical = Control.SIZE_EXPAND_FILL
		grafica.configurar(datos[0], puntos, datos[1], datos[2])
		contenido.add_child(grafica)


# --- Tripulación ----------------------------------------------------------

func _columna_tripulacion() -> Control:
	var caja := Hud.columna(6)
	caja.custom_minimum_size = Vector2(340, 0)
	caja.size_flags_vertical = Control.SIZE_EXPAND_FILL
	caja.add_child(Hud.etiqueta("Tripulación (%d)" % EstadoJuego.colonos_activos(), 16))
	var lista := Hud.columna(6)
	for t in EstadoJuego.colonos:
		lista.add_child(TarjetaColono.crear(t, true))
	if EstadoJuego.colonos.is_empty():
		lista.add_child(Hud.parrafo("No hay colonos. Recluta desde el módulo de descanso."))
	caja.add_child(vista_con_scroll(lista))
	return caja


# --- Tablero de tareas ----------------------------------------------------

func _tablero_tareas() -> Control:
	var caja := Hud.columna(6)
	Hud.expandir(caja)
	caja.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var tareas := EstadoJuego.tareas_disponibles()
	caja.add_child(Hud.etiqueta("Tareas disponibles (%d)" % tareas.size(), 16))
	var rejilla := GridContainer.new()
	rejilla.columns = 2
	rejilla.add_theme_constant_override("h_separation", 8)
	rejilla.add_theme_constant_override("v_separation", 8)
	for tarea in tareas:
		rejilla.add_child(_tarjeta_tarea(tarea))
	caja.add_child(vista_con_scroll(rejilla))
	return caja


func _tarjeta_tarea(tarea: Dictionary) -> Control:
	var tarjeta := Hud.tarjeta()
	Hud.expandir(tarjeta)
	var c := Hud.columna(3)
	tarjeta.add_child(c)
	c.add_child(Hud.etiqueta(tarea["titulo"]))
	c.add_child(Hud.etiqueta(
		"%s · %d soles" % [Enums.NOMBRE_ROL[tarea["rol"]], tarea["soles"]], 12, Hud.TEXTO_SUAVE))
	var entorno := "Interior (sin exposición)"
	if tarea["exterior"]:
		entorno = "Exterior (+%s radiación)" % Hud.num(tarea["radiacion"])
	c.add_child(Hud.etiqueta(entorno, 12, Hud.ADVERTENCIA if tarea["exterior"] else Hud.TEXTO_SUAVE))
	c.add_child(Hud.etiqueta(Hud.texto_recompensa(tarea["recompensa"]), 12, Hud.BIEN))
	if tarea_elegida == tarea["id"]:
		_opciones_asignacion(c, tarea)
	else:
		c.add_child(Hud.boton("Seleccionar", _elegir_tarea.bind(tarea["id"])))
	return tarjeta


func _opciones_asignacion(c: Control, tarea: Dictionary) -> void:
	var libres := EstadoJuego.colonos_para_tarea(tarea)
	if libres.is_empty():
		c.add_child(Hud.parrafo("Ningún colono libre tiene este rol.", 12, Hud.ADVERTENCIA))
	for t in libres:
		c.add_child(Hud.boton_primario("Asignar a %s" % t.nombre, _pedir_asignacion.bind(tarea, t)))
	c.add_child(Hud.boton("Cancelar", _elegir_tarea.bind(""), true, Hud.FANTASMA))


func _elegir_tarea(id: String) -> void:
	tarea_elegida = id
	_pedir_reconstruccion()


func _pedir_asignacion(tarea: Dictionary, t: DatosColono) -> void:
	var texto := "%s\nAsignar a %s durante %d soles" % [tarea["titulo"], t.nombre, tarea["soles"]]
	interfaz.confirmar("Confirmar asignación", texto, func() -> void:
		tarea_elegida = ""
		EstadoJuego.asignar_tarea(tarea, t))


# --- Gráfica del historial ------------------------------------------------

class Grafica:
	extends Control
	## Gráfica (historial de HU-02) de una sola línea con cursor al pasar el ratón. Reserva y balance
	## van en gráficas separadas porque tienen escalas distintas.

	const MARGEN := Rect2(46, 28, 16, 24)     # izquierda, arriba, derecha, abajo
	const COLOR_LINEA := Hud.ACENTO
	const COLOR_GUIA := Color(1, 1, 1, 0.07)

	var titulo := ""
	var soles: Array[int] = []
	var valores: Array[float] = []
	var incluir_cero := false
	var indice_hover := -1


	func configurar(titulo_grafica: String, puntos: Array, clave: String, con_cero: bool) -> void:
		titulo = titulo_grafica
		incluir_cero = con_cero
		for punto: Dictionary in puntos:
			soles.append(punto["sol"])
			valores.append(punto[clave])
		mouse_exited.connect(_al_salir)
		queue_redraw()


	func _al_salir() -> void:
		indice_hover = -1
		queue_redraw()


	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion and valores.size() >= 2:
			var area := _area()
			var t: float = (event.position.x - area.position.x) / area.size.x
			var nuevo := clampi(roundi(t * (valores.size() - 1)), 0, valores.size() - 1)
			if nuevo != indice_hover:
				indice_hover = nuevo
				queue_redraw()


	func _area() -> Rect2:
		return Rect2(
			MARGEN.position,
			size - MARGEN.position - Vector2(MARGEN.size.x, MARGEN.size.y))


	func _rango() -> Vector2:
		var minimo: float = valores.min()
		var maximo: float = valores.max()
		if incluir_cero:
			minimo = minf(minimo, 0.0)
			maximo = maxf(maximo, 0.0)
		if is_equal_approx(minimo, maximo):
			maximo += 1.0
			minimo -= 1.0
		return Vector2(minimo, maximo)


	func _punto(indice: int, area: Rect2, rango: Vector2) -> Vector2:
		var x := area.position.x + area.size.x * indice / float(valores.size() - 1)
		var t := (valores[indice] - rango.x) / (rango.y - rango.x)
		return Vector2(x, area.end.y - area.size.y * t)


	func _texto(pos: Vector2, texto: String, tam := 12, color := Hud.TEXTO_SUAVE) -> void:
		draw_string(Hud.fuente(), pos, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, color)


	func _draw() -> void:
		draw_style_box(Hud.estilo(Hud.FONDO_CLARO, Hud.BORDE, Hud.RADIO, 12), Rect2(Vector2.ZERO, size))
		_texto(Vector2(12, 19), titulo, 14, Hud.TEXTO)
		if valores.size() < 2:
			_texto(Vector2(12, size.y / 2.0), "Se necesitan 2 soles de datos para trazar la línea.")
			return
		var area := _area()
		var rango := _rango()
		_dibujar_ejes(area, rango)
		var linea := PackedVector2Array()
		for i in valores.size():
			linea.append(_punto(i, area, rango))
		draw_polyline(linea, COLOR_LINEA, 2.0, true)
		if indice_hover >= 0:
			_dibujar_cursor(area, rango)


	func _dibujar_ejes(area: Rect2, rango: Vector2) -> void:
		for t: float in [0.0, 0.5, 1.0]:
			var y := area.end.y - area.size.y * t
			draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), COLOR_GUIA)
			_texto(Vector2(6, y + 4), Hud.num(lerpf(rango.x, rango.y, t)), 11)
		if incluir_cero and rango.x < 0.0 and rango.y > 0.0:
			var t_cero := -rango.x / (rango.y - rango.x)
			var y_cero := area.end.y - area.size.y * t_cero
			draw_line(Vector2(area.position.x, y_cero), Vector2(area.end.x, y_cero), Color(1, 1, 1, 0.4))
		_texto(Vector2(area.position.x, size.y - 6), "Sol %d" % soles[0], 11)
		_texto(Vector2(area.end.x - 44, size.y - 6), "Sol %d" % soles[-1], 11)


	func _dibujar_cursor(area: Rect2, rango: Vector2) -> void:
		var punto := _punto(indice_hover, area, rango)
		draw_line(Vector2(punto.x, area.position.y), Vector2(punto.x, area.end.y), Color(1, 1, 1, 0.35))
		draw_circle(punto, 6.0, Hud.FONDO_CLARO)
		draw_circle(punto, 4.0, COLOR_LINEA)
		var texto := "Sol %d: %s" % [soles[indice_hover], Hud.num(valores[indice_hover])]
		var ancho := ThemeDB.fallback_font.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 12
		var pos := Vector2(clampf(punto.x + 8, area.position.x, area.end.x - ancho), area.position.y + 2)
		draw_rect(Rect2(pos, Vector2(ancho, 20)), Hud.FONDO)
		_texto(pos + Vector2(6, 14), texto, 12, Hud.TEXTO)
