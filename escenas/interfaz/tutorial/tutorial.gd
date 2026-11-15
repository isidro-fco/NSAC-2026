# tutorial.gd
# Tutorial guiado: enseña paso a paso todo lo que se puede hacer en el juego, con objetivos que se cumplen jugando.

class_name Tutorial
extends CanvasLayer
## Guía interactiva para aprender a jugar. Es una banda abajo de la pantalla:
##   ┌──────────────────────────────────────────────────────────────────────┐
##   │ [TUTORIAL 4/17]   Texto que explica el paso...            [SIGUIENTE] │
##   │ EL TIEMPO         > OBJETIVO: pulsa Espacio para reanudar  [ANTERIOR] │
##   │ ▬▬▬▬▭▭▭▭▭▭▭▭                                                 [SALTAR] │
##   └──────────────────────────────────────────────────────────────────────┘
## - Cada paso tiene un texto y, a veces, un objetivo: al cumplirlo jugando
##   (abrir un módulo, asignar una tarea, construir...) pasa solo al siguiente.
## - Un marco que late señala de qué se habla (un módulo del mapa, la barra de
##   recursos, un botón...).
## - El tiempo queda en pausa mientras dura, para leer con calma.
## - La primera vez empieza solo; después se abre con F1 o con el botón
##   "? Tutorial" (se recuerda en user://ajustes.cfg).
## Los pasos están en _crear_pasos(): { "titulo", "texto", "objetivo"?,
## "listo"?: Callable -> bool, "foco"?: Callable -> Rect2, "al_entrar"?: Callable }.

const RUTA_AJUSTES := "user://ajustes.cfg"
const ANCHO_MAX := 980.0
const MARGEN_BOTONES_HUD := 70.0      # hueco para los botones inferiores del HUD
const ANCHO_PANEL_CONSTRUCCION := 330.0

var juego: Juego
var pasos: Array[Dictionary] = []
var indice := -1                      # -1: tutorial cerrado
var memoria := {}                     # valores guardados al entrar a un paso (para ver si cambian)
var pausa_previa := false

var raiz := Control.new()
var foco := Control.new()
var panel := PanelContainer.new()
var boton_ayuda: Button


func _init(juego_base: Juego) -> void:
	juego = juego_base
	layer = 50                        # sobre la interfaz, bajo los tooltips (100)


func _ready() -> void:
	for control: Control in [raiz, foco]:
		control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.theme = UI.tema()
	add_child(raiz)
	raiz.add_child(foco)
	foco.draw.connect(_dibujar_foco)
	MarcoVentana.aplicar_lateral(panel, 10)
	panel.visible = false
	raiz.add_child(panel)

	boton_ayuda = UI.boton_pixel("? Tutorial", iniciar, false, UI.T_DETALLE)
	boton_ayuda.tooltip_text = "Volver a ver el tutorial (F1)"
	raiz.add_child(boton_ayuda)

	pasos = _crear_pasos()
	if not _ya_visto():
		iniciar.call_deferred()


func activo() -> bool:
	return indice >= 0


func iniciar() -> void:
	if activo():
		return
	pausa_previa = GestorTiempo.en_pausa
	GestorTiempo.en_pausa = true
	_ir_a(0)


## Cierra el tutorial (al terminarlo o al saltarlo) y lo recuerda.
func terminar() -> void:
	indice = -1
	panel.visible = false
	foco.queue_redraw()
	GestorTiempo.en_pausa = pausa_previa
	_marcar_visto()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		if activo():
			terminar()
		else:
			iniciar()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	boton_ayuda.visible = not activo() and juego.mapa.modo == Enums.ModoMapa.NORMAL and juego.menu == null
	var vista := get_viewport().get_visible_rect().size
	boton_ayuda.position = Vector2(Hud.MARGEN, vista.y - 96)
	if not activo():
		return
	var paso := pasos[indice]
	if paso.has("listo") and (paso["listo"] as Callable).call():
		_ir_a(indice + 1)
		return
	_colocar_panel(vista)
	foco.queue_redraw()


# --- Pasos ----------------------------------------------------------------

func _ir_a(nuevo: int) -> void:
	if nuevo >= pasos.size():
		terminar()
		return
	indice = maxi(nuevo, 0)
	memoria.clear()
	var paso := pasos[indice]
	if paso.has("al_entrar"):
		(paso["al_entrar"] as Callable).call()
	_mostrar_paso(paso)


func _mostrar_paso(paso: Dictionary) -> void:
	for hijo in panel.get_children():
		panel.remove_child(hijo)
		hijo.queue_free()
	panel.visible = true
	var ultimo := indice == pasos.size() - 1
	var f := UI.fila(14)
	panel.add_child(f)

	# Izquierda: número de paso, título y avance.
	var izquierda := UI.columna(8)
	izquierda.custom_minimum_size = Vector2(200, 0)
	izquierda.alignment = BoxContainer.ALIGNMENT_CENTER
	var numero := Cabina.pildora("TUTORIAL %d/%d" % [indice + 1, pasos.size()], Cabina.NARANJA)
	numero.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	izquierda.add_child(numero)
	var titulo := UI.etiqueta_pixel(Cabina.mayus(paso["titulo"]), UI.T_TEXTO)
	titulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titulo.add_theme_constant_override("line_spacing", 4)
	izquierda.add_child(titulo)
	izquierda.add_child(Cabina.barra(indice + 1, pasos.size(), Cabina.NARANJA, 4))
	f.add_child(izquierda)

	# Centro: la explicación y, si lo hay, el objetivo del paso.
	var centro := UI.columna(8)
	centro.alignment = BoxContainer.ALIGNMENT_CENTER
	centro.add_child(UI.parrafo(paso["texto"], 13, UI.TEXTO))
	if paso.get("objetivo", "") != "":
		var objetivo := UI.etiqueta_pixel("> OBJETIVO: " + Cabina.mayus(paso["objetivo"]), UI.T_DETALLE, UI.ADVERTENCIA)
		objetivo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		objetivo.add_theme_constant_override("line_spacing", 4)
		centro.add_child(objetivo)
	f.add_child(UI.expandir(centro))

	# Derecha: avanzar, volver y saltar.
	var botones := UI.columna(4)
	botones.alignment = BoxContainer.ALIGNMENT_CENTER
	botones.custom_minimum_size = Vector2(150, 0)
	var con_objetivo := paso.has("listo")
	var texto_siguiente := "Empezar a jugar" if ultimo else ("Omitir paso" if con_objetivo else "Siguiente")
	var siguiente := Cabina.boton(texto_siguiente, _ir_a.bind(indice + 1), true,
		UI.SILENCIADO if con_objetivo and not ultimo else UI.ACENTO)
	if con_objetivo:
		siguiente.tooltip_text = "Pasa al siguiente paso sin hacer el objetivo"
	botones.add_child(siguiente)
	if indice > 0:
		botones.add_child(Cabina.boton("Anterior", _ir_a.bind(indice - 1), true, UI.SILENCIADO))
	if not ultimo:
		var saltar := Cabina.boton("Saltar tutorial", terminar, true, UI.SILENCIADO)
		saltar.tooltip_text = "Cierra el tutorial. Puedes volver a verlo con F1."
		botones.add_child(saltar)
	f.add_child(botones)
	_colocar_panel(get_viewport().get_visible_rect().size)


## Abajo y centrado. Con una ventana abierta baja hasta el borde (la ventana
## tapa los botones del HUD); con el panel de construcción se corre a la derecha.
func _colocar_panel(vista: Vector2) -> void:
	var modo := juego.mapa.modo
	var izquierda := ANCHO_PANEL_CONSTRUCCION if modo in [Enums.ModoMapa.CATALOGO, Enums.ModoMapa.DEMOLICION] else 0.0
	var ancho := minf(ANCHO_MAX, vista.x - izquierda - 24.0)
	panel.custom_minimum_size.x = ancho
	panel.size = Vector2(ancho, panel.get_combined_minimum_size().y)
	var con_ventana := juego.menu != null or juego.dialogo != null
	var abajo := 8.0 if con_ventana else MARGEN_BOTONES_HUD
	panel.position = Vector2(izquierda + (vista.x - izquierda - ancho) / 2.0, vista.y - abajo - panel.size.y).floor()


func _crear_pasos() -> Array[Dictionary]:
	var mapa := juego.mapa
	var hud := juego.hud
	var balance := EstadoJuego.datos_balance
	var lista: Array[Dictionary] = [
		{
			"titulo": "Bienvenida a Marte",
			"texto": "Diriges una colonia en Marte. Tu meta: que sea autosuficiente, mejorando el Módulo de Comando hasta el nivel %d. Pierdes si la energía se agota o si la tripulación pasa %d soles seguidos sin oxígeno, agua o comida. Este tutorial te enseña todo; el tiempo está en pausa mientras lo sigues." % [
				EstadoJuego.comando.nivel_max(), balance.soles_sin_vitales_derrota],
		},
		{
			"titulo": "Mover la cámara",
			"texto": "Mueve la vista con WASD o las flechas, o arrastrando con el botón derecho del ratón. La rueda acerca y aleja el mapa.",
			"objetivo": "mueve la cámara o cambia el zoom",
			"al_entrar": _recordar_camara,
			"listo": _camara_movida,
		},
		{
			"titulo": "Los recursos",
			"texto": "Arriba ves las reservas: oxígeno, energía, agua, comida, materiales y presupuesto (en millones). Cada sol la tripulación consume oxígeno, agua y comida, y los módulos gastan energía. Un número en rojo avisa de que ese recurso se acaba. Deja el ratón sobre cualquiera para ver su detalle.",
			"foco": func() -> Rect2: return _rect_de(hud.indicadores),
		},
		{
			"titulo": "El tiempo",
			"texto": "Un sol es un día marciano (%d segundos). Al terminar cada sol se consume, se produce y avanzan las tareas. Con Espacio pausas y reanudas; x2 y x4 aceleran. Al cumplir este paso volveremos a pausar para seguir con calma." % int(balance.segundos_por_sol),
			"objetivo": "pulsa Espacio (o el botón ▶) para reanudar el tiempo",
			"al_entrar": func() -> void: GestorTiempo.en_pausa = true,
			"listo": func() -> bool: return not GestorTiempo.en_pausa,
			"foco": func() -> Rect2: return _rect_de([hud.boton_pausa, hud.boton_reanudar] + hud.botones_velocidad.values()),
		},
		{
			"titulo": "El Módulo de Comando",
			"texto": "Es el centro de la base. Desde ahí ves las métricas, diriges a la tripulación y mejoras la colonia. Los módulos con ventana propia se abren con un clic en el mapa.",
			"objetivo": "haz clic en el Módulo de Comando",
			"al_entrar": func() -> void: GestorTiempo.en_pausa = true,
			"listo": func() -> bool: return juego.menu is MenuComando,
			"foco": func() -> Rect2: return _rect_modulo("comando"),
		},
		{
			"titulo": "Asignar tareas",
			"texto": "A la izquierda está la tripulación y a la derecha las tareas. Cada tarea pide un rol, tarda unos soles y da una recompensa. Las de exterior suman radiación al colono. Un clic en un tripulante libre muestra solo sus tareas.",
			"objetivo": "pulsa «Asignar a...» en una tarea y confirma",
			"al_entrar": func() -> void: memoria["en_mision"] = _en_mision(),
			"listo": func() -> bool: return _en_mision() > memoria["en_mision"],
		},
		{
			"titulo": "Métricas y mejora",
			"texto": "Un clic en cualquier recurso de arriba de esta ventana abre su historial de %d soles. El botón naranja «Mejorar Módulo de Comando» cuesta presupuesto y materiales, tarda unos soles y multiplica la producción de toda la base. Llegar al nivel %d es ganar la partida." % [
				balance.soles_historial, EstadoJuego.comando.nivel_max()],
		},
		{
			"titulo": "Almacén y Cocina",
			"texto": "Cierra esta ventana con Esc o con la X. Después abre el Almacén y Cocina: ahí se guardan los víveres y los materiales.",
			"objetivo": "haz clic en el Almacén y Cocina del mapa",
			"listo": func() -> bool: return juego.menu is MenuAlmacen,
			"foco": func() -> Rect2: return _rect_modulo("almacen"),
		},
		{
			"titulo": "Cocinar raciones",
			"texto": "En «Reservas» ves cuántos soles alcanza cada cosa. En «Cocina» conviertes comida cruda y agua en raciones preparadas, que rinden más; la tripulación se las come primero.",
			"objetivo": "pulsa «Cocinar» en una receta",
			"al_entrar": func() -> void: memoria["raciones"] = EstadoJuego.economia.recursos["raciones"],
			"listo": func() -> bool: return EstadoJuego.economia.recursos["raciones"] > memoria["raciones"],
		},
		{
			"titulo": "Raciones y pedidos",
			"texto": "«Racionamiento» decide cuánto come la tripulación: Abundante gasta más y mejora el trabajo; Estricta ahorra, pero tras %d soles debilita y enferma. «Pedidos a la Tierra» compra víveres, materiales u oxígeno que tardan varios soles en llegar en nave. «Expandir depósito» aumenta la capacidad." % balance.soles_estricta_para_riesgo,
		},
		{
			"titulo": "Módulo de Descanso",
			"texto": "Cierra el almacén (Esc) y abre el Módulo de Descanso, donde vive la tripulación.",
			"objetivo": "haz clic en el Módulo de Descanso del mapa",
			"listo": func() -> bool: return juego.menu is MenuDescanso,
			"foco": func() -> Rect2: return _rect_modulo("descanso"),
		},
		{
			"titulo": "Reclutar y relevar",
			"texto": "Cada colono ocupa un cuarto. «Reclutar colono» contrata candidatos que llegan en %d soles a la plataforma de aterrizaje; «Construir cuarto» hace sitio para más (hasta %d). «A la Tierra» retira a un colono para siempre: úsalo cuando acumule demasiada radiación." % [
				balance.soles_viaje_colono, balance.cuartos_max],
		},
		{
			"titulo": "Construir",
			"texto": "La base crece con módulos nuevos: soporte vital (oxígeno y reciclaje de agua), agricultura (comida), panel solar (energía), perforadora (agua), taller (materiales) y refugio. Cierra esta ventana y entra al modo construcción.",
			"objetivo": "pulsa el botón Construir (tecla B)",
			"listo": func() -> bool: return mapa.modo == Enums.ModoMapa.CATALOGO and juego.menu == null,
			"foco": func() -> Rect2: return _rect_de([hud.botones["construir"]]),
		},
		{
			"titulo": "Colocar un módulo",
			"texto": "Cada tarjeta muestra el costo, la energía que gasta o produce y lo que da por sol. Elige una (el panel solar es barato) y llévala al mapa: en verde se puede colocar. Debe quedar una casilla libre entre módulos. Clic derecho cancela.",
			"objetivo": "elige un módulo, colócalo en el mapa y confirma",
			"al_entrar": func() -> void: memoria["construidos"] = EstadoJuego.modulos_construidos,
			"listo": func() -> bool: return EstadoJuego.modulos_construidos > memoria["construidos"],
		},
		{
			"titulo": "Pasillos",
			"texto": "Los colonos caminan entre módulos. Si no hay camino techado salen al exterior y reciben radiación: une los módulos con «Pasillo» (se colocan uno tras otro, casilla a casilla). Vigila el balance de energía: si un módulo gasta más de lo que produces, las baterías se vacían.",
		},
		{
			"titulo": "Demoler",
			"texto": "El interruptor de arriba del panel cambia entre construir y demoler. Demoliendo quitas rocas y cráteres que estorban (cuesta %s y devuelve %d materiales) o módulos que construiste. Los módulos iniciales no se pueden demoler." % [
				UI.dinero(balance.demoler_obstaculo_dinero), balance.demoler_obstaculo_materiales],
			"objetivo": "mueve el interruptor a DEMOLER",
			"listo": func() -> bool: return mapa.modo == Enums.ModoMapa.DEMOLICION,
		},
		{
			"titulo": "Salir de construcción",
			"texto": "En modo demolición, señala una roca o un módulo para ver lo que cuesta y haz clic para quitarlo. Para volver al juego normal, el botón de abajo ahora dice Cancelar.",
			"objetivo": "pulsa Cancelar (B o Esc) para salir",
			"listo": func() -> bool: return mapa.modo == Enums.ModoMapa.NORMAL,
			"foco": func() -> Rect2: return _rect_de([hud.botones["construir"]]),
		},
		{
			"titulo": "La tripulación",
			"texto": "Este panel dice dónde está cada colono; un clic lo resalta en el mapa, y un clic sobre un colono en el mapa abre su ficha. Vigila su radiación: a los %d enferma y deja de trabajar unos soles. Dentro de los módulos están protegidos." % int(balance.radiacion_enfermedad),
			"foco": func() -> Rect2: return _rect_de([juego.panel_tripulacion]),
		},
		{
			"titulo": "Alertas y eventos",
			"texto": "Abajo a la derecha aparecen las alertas: pasa el ratón para ver qué ocurre y haz clic para ir a resolverlo. Cada varios soles surge un evento con dos opciones; algunos son tormentas solares reales registradas por la NASA. Durante una tormenta solar la radiación se dispara: construye un Refugio blindado (%d plazas) para proteger a la tripulación." % balance.capacidad_refugio,
			"foco": func() -> Rect2: return _rect_de([hud.panel_alertas]),
		},
		{
			"titulo": "Glosario y bitácora",
			"texto": "Las palabras subrayadas son términos técnicos: deja el ratón encima para leer qué significan. Todos los que descubras se guardan en el Glosario (G). La Bitácora (L) registra todo lo ocurrido en la misión, sol a sol.",
			"foco": func() -> Rect2: return _rect_de([hud.botones["glosario"], hud.botones["bitacora"]]),
		},
		{
			"titulo": "¡A colonizar!",
			"texto": "Resumen: mantén oxígeno, agua, comida y energía en positivo; da tareas a la tripulación; construye para producir más; cuida la radiación; y mejora el Módulo de Comando hasta el nivel %d. La Tierra envía fondos cada %d soles. Puedes volver a este tutorial con F1." % [
				EstadoJuego.comando.nivel_max(), balance.transferencia_cada],
		},
	]
	return lista


func _recordar_camara() -> void:
	memoria["pos"] = juego.camara.position
	memoria["zoom"] = juego.camara.zoom.x


func _camara_movida() -> bool:
	return juego.camara.position.distance_to(memoria["pos"]) > 60.0 \
		or not is_equal_approx(juego.camara.zoom.x, memoria["zoom"])


func _en_mision() -> int:
	return EstadoJuego.tripulacion.colonos.filter(func(c: DatosColono) -> bool:
		return c.estado == Enums.EstadoColono.EN_MISION).size()


# --- Foco (marco que señala de qué habla el paso) ---------------------------

## Rectángulo en pantalla que envuelve a varios controles visibles.
func _rect_de(controles: Array) -> Rect2:
	var rect := Rect2()
	for control: Control in controles:
		if control != null and control.is_visible_in_tree():
			rect = control.get_global_rect() if rect.size == Vector2.ZERO else rect.merge(control.get_global_rect())
	return rect


## Rectángulo en pantalla del primer módulo `id` del mapa.
func _rect_modulo(id: String) -> Rect2:
	var modulos := juego.mapa.modulos_de(id)
	if modulos.is_empty():
		return Rect2()
	var modulo: Modulo = modulos[0]
	var a_pantalla := juego.mapa.get_viewport().get_canvas_transform()
	var tam := Vector2(modulo.tam_celdas()) * GestorCuadricula.TAM_CELDA
	return Rect2(a_pantalla * modulo.global_position, tam * a_pantalla.get_scale())


## Marco naranja que late alrededor del foco del paso, con esquinas marcadas.
## No se dibuja con una ventana abierta (el foco quedaría debajo de ella).
func _dibujar_foco() -> void:
	if not activo() or juego.menu != null or juego.dialogo != null:
		return
	var paso := pasos[indice]
	if not paso.has("foco"):
		return
	var rect: Rect2 = (paso["foco"] as Callable).call()
	if rect.size.x < 2.0 or rect.size.y < 2.0:
		return
	var latido := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 220.0)
	rect = rect.grow(5.0 + 3.0 * latido)
	var color := Color(UI.ADVERTENCIA, 0.55 + 0.45 * latido)
	foco.draw_rect(rect, Color(UI.ADVERTENCIA, 0.06 + 0.06 * latido))
	foco.draw_rect(rect, color, false, 2.0)
	var largo := minf(14.0, minf(rect.size.x, rect.size.y) / 3.0)
	for esquina: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var punto := rect.position + rect.size * esquina
		var hacia := Vector2(1, 1) - esquina * 2.0
		foco.draw_rect(Rect2(punto, Vector2(largo * hacia.x, 4.0 * hacia.y)).abs(), color)
		foco.draw_rect(Rect2(punto, Vector2(4.0 * hacia.x, largo * hacia.y)).abs(), color)


# --- Recordar que ya se vio -------------------------------------------------

func _ya_visto() -> bool:
	var ajustes := ConfigFile.new()
	return ajustes.load(RUTA_AJUSTES) == OK and ajustes.get_value("tutorial", "visto", false)


func _marcar_visto() -> void:
	var ajustes := ConfigFile.new()
	ajustes.load(RUTA_AJUSTES)
	ajustes.set_value("tutorial", "visto", true)
	ajustes.save(RUTA_AJUSTES)
