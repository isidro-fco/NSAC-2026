# panel_alertas.gd
# Alertas activas abajo a la derecha (como en RimWorld): avisos de lo que pasa en la colonia, con sugerencias.

class_name PanelAlertas
extends VBoxContainer
## Una fila por alerta, alineada a la derecha y apilada hacia arriba:
##                                  ¡Se acaba el agua!   <- roja: urgente
##                          La nube del Sol llega en 2 soles
##                                     2 colonos sin tarea
## Al pasar el mouse, un tooltip (Tooltips) explica qué pasa y qué hacer; al
## hacer clic lleva al lugar (abre el menú, el modo construcción o señala al
## colono). Las alertas se recalculan cada vez que cambia el estado del juego.

signal alerta_pulsada(alerta: Dictionary)

const MAXIMO := 8
const ROJO := Color(0.62, 0.16, 0.12, 0.93)
const NORMAL := Color(0.09, 0.13, 0.17, 0.82)
const NOMBRE := { "oxigeno": "el oxígeno", "agua": "el agua", "comida": "la comida" }
const SIN := { "oxigeno": "¡Sin oxígeno!", "agua": "¡Sin agua!", "comida": "¡Sin comida!" }
const SUGERENCIA := {
	"oxigeno": "Construye un soporte vital, pon a alguien de Soporte vital a «Recargar reservas de oxígeno» o pide tanques a la Tierra.",
	"agua": "Construye un soporte vital (recicla el 80 % del agua) y una perforadora de hielo, o pide víveres a la Tierra.",
	"comida": "Construye agricultura, pon a alguien a «Cuidar cultivos», cocina raciones o pide víveres a la Tierra.",
}
const MENU := { "oxigeno": "comando", "agua": "almacen", "comida": "almacen" }

var filas := {}                       # id -> { "panel", "label", "alerta" }


func _init() -> void:
	alignment = BoxContainer.ALIGNMENT_END
	add_theme_constant_override("separation", 3)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func actualizar() -> void:
	var alertas := calcular()
	var vistas := {}
	for i in alertas.size():
		var alerta: Dictionary = alertas[i]
		vistas[alerta["id"]] = true
		if not filas.has(alerta["id"]):
			filas[alerta["id"]] = _crear_fila()
		var fila: Dictionary = filas[alerta["id"]]
		fila["alerta"] = alerta
		(fila["label"] as Label).text = alerta["texto"]
		(fila["panel"] as PanelContainer).add_theme_stylebox_override("panel",
			UI.estilo(ROJO if alerta["critica"] else NORMAL, Color(0, 0, 0, 0), 0, 6, 0))
		move_child(fila["panel"], i)
	for id: String in filas.keys():
		if not vistas.has(id):
			filas[id]["panel"].queue_free()
			filas.erase(id)


func _crear_fila() -> Dictionary:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var label := UI.etiqueta_simple("", 13, UI.TEXTO)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	add_child(panel)
	var fila := { "panel": panel, "label": label, "alerta": {} }
	Tooltips.registrar(panel, func() -> Dictionary:
		var a: Dictionary = fila["alerta"]
		return { "titulo": a.get("texto", ""), "texto": a.get("detalle", ""), "sugerencia": a.get("sugerencia", ""),
			"color_titulo": UI.CRITICO.lightened(0.35) if a.get("critica", false) else UI.ADVERTENCIA,
			"pie": "Clic: ir a resolverlo" if a.has("accion") else "" })
	panel.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			Tooltips.cerrar_todo()
			alerta_pulsada.emit(fila["alerta"])
			panel.accept_event())
	return fila


# --- Reglas ---------------------------------------------------------------

## Alertas que tocan ahora, primero las urgentes (rojas). Cada una:
## { "id", "texto", "critica", "detalle", "sugerencia", "accion"?: { "menu" | "colono" | "construir" } }
static func calcular() -> Array[Dictionary]:
	var lista: Array[Dictionary] = []
	var e := EstadoJuego.economia
	var datos := EstadoJuego.datos_balance

	# Oxígeno, agua y comida.
	for r: String in EstadoJuego.VITALES:
		var unidad: String = UI.UNIDAD[r]
		var soles := e.soles_restantes(r)
		var gasto := "Se gastan %s %s y se producen %s %s por sol." % [
			UI.num(e.consumo(r)), unidad, UI.num(e.produccion(r)), unidad]
		var accion := { "menu": MENU[r] }
		if e.valor(r) <= 0.0:
			lista.append({ "id": "sin_" + r, "texto": SIN[r], "critica": true, "accion": accion,
				"detalle": "La colonia se quedó sin %s. Llevan %s sin soporte vital: a los %d se pierde la partida." % [
					NOMBRE[r].get_slice(" ", 1), UI.soles(EstadoJuego.tripulacion.soles_sin_vitales),
					datos.soles_sin_vitales_derrota],
				"sugerencia": SUGERENCIA[r] })
		elif soles <= 3.0:
			lista.append({ "id": "acaba_" + r, "texto": "¡Se acaba %s!" % NOMBRE[r], "critica": true, "accion": accion,
				"detalle": "Quedan %s. %s Alcanza para %s." % [UI.cantidad(r, e.valor(r)), gasto, UI.soles(int(soles))],
				"sugerencia": SUGERENCIA[r] })
		elif not is_inf(soles):
			var nombre: String = NOMBRE[r]
			lista.append({ "id": "baja_" + r, "texto": "%s baja cada sol" % (nombre[0].to_upper() + nombre.substr(1)), "critica": false,
				"accion": accion, "detalle": "%s Al ritmo de ahora alcanza para %s." % [gasto, UI.soles(int(soles))],
				"sugerencia": SUGERENCIA[r] })

	# Energía.
	var kw := e.balance("energia")
	if kw < 0.0:
		var soles := e.soles_restantes("energia")
		var detalle := "Los módulos gastan %s y se producen %s (%s). Las baterías bajan %s kWh por sol: duran %s. Si se vacían, la base se apaga y se pierde la partida." % [
			UI.kw(e.consumo("energia")), UI.kw(e.produccion("energia")), UI.kw(kw, true),
			UI.num(-e.cambio_por_sol("energia")), UI.soles(int(soles))]
		var urgente := soles <= 2.0
		lista.append({ "id": "energia", "critica": urgente, "detalle": detalle, "accion": { "construir": true },
			"texto": "¡Baterías casi vacías!" if urgente else "Se gasta más energía de la que hay",
			"sugerencia": "Construye paneles solares (20 kW cada uno) o demuele un módulo que gaste mucho." })

	# Clima espacial.
	var hay_refugio := "refugio" in e.modulos_activos
	var sugerencia_refugio := "Manda a los colonos al refugio blindado: ahí no reciben radiación." if hay_refugio \
		else "Construye un refugio blindado: ahí los colonos no reciben radiación."
	var accion_refugio: Dictionary = { "menu": "refugio" } if hay_refugio else { "construir": true }
	if EstadoJuego.eventos.tormenta_activa():
		var expuestos := EstadoJuego.tripulacion.colonos.filter(
			func(c: DatosColono) -> bool: return c.ubicacion != "refugio").size()
		lista.append({ "id": "tormenta", "texto": "¡Tormenta solar!", "critica": expuestos > 0, "accion": accion_refugio,
			"detalle": "La radiación está muy alta durante %s: %d por sol afuera, %d dentro de los módulos y 0 en el refugio. Hay %d colonos fuera del refugio." % [
				UI.soles(EstadoJuego.eventos.tormenta_soles), int(datos.radiacion_tormenta_exterior),
				int(datos.radiacion_tormenta_interior * EstadoJuego.eventos.blindaje), expuestos],
			"sugerencia": sugerencia_refugio })
	var nube := EstadoJuego.clima.tormenta_pendiente
	if not nube.is_empty():
		lista.append({ "id": "nube", "texto": "La nube del Sol llega en %s" % UI.soles(nube["soles"]),
			"critica": nube["soles"] <= 1 and not hay_refugio, "accion": accion_refugio,
			"detalle": "Una eyección de masa coronal viene hacia Marte. Cuando llegue habrá una tormenta solar de %s." % UI.soles(nube["duracion"]),
			"sugerencia": sugerencia_refugio })

	# Tripulación.
	var limite: float = datos.radiacion_enfermedad
	var sin_tarea: Array[String] = []
	for c: DatosColono in EstadoJuego.tripulacion.colonos:
		var colono := { "colono": c }
		if c.radiacion >= limite:
			lista.append({ "id": "rad_" + c.nombre, "texto": "Radiación peligrosa: %s" % c.nombre, "critica": true,
				"accion": colono, "detalle": "%s tiene %s de dosis (a partir de %d enferma)." % [c.nombre, UI.num(c.radiacion), int(limite)],
				"sugerencia": "Que descanse dentro de la base. Si no baja, puedes mandarlo de regreso a la Tierra, como hace la NASA." })
		elif c.radiacion >= limite / 2.0:
			lista.append({ "id": "rad_" + c.nombre, "texto": "Mucha radiación: %s" % c.nombre, "critica": false,
				"accion": colono, "detalle": "%s tiene %s de dosis; a los %d enferma." % [c.nombre, UI.num(c.radiacion), int(limite)],
				"sugerencia": "Dale tareas dentro de la base y no en el exterior." })
		if c.estado == Enums.EstadoColono.ENFERMO:
			lista.append({ "id": "enfermo_" + c.nombre, "texto": "%s está enfermo" % c.nombre, "critica": false,
				"accion": colono, "detalle": "Un colono enfermo no puede hacer tareas.",
				"sugerencia": "Con ración abundante se recupera en 2 soles en vez de 3. Que no falten oxígeno, agua ni comida." })
		elif c.estado == Enums.EstadoColono.DISPONIBLE and EstadoJuego.tareas.disponibles().any(
				func(t: Dictionary) -> bool: return t["rol"] == c.rol):
			sin_tarea.append(c.nombre)
	if not sin_tarea.is_empty():
		lista.append({ "id": "sin_tarea", "critica": false, "accion": { "menu": "comando" },
			"texto": "%s sin tarea" % (sin_tarea[0] if sin_tarea.size() == 1 else "%d colonos" % sin_tarea.size()),
			"detalle": "Sin tarea: %s. Hay tareas que pueden hacer." % ", ".join(sin_tarea),
			"sugerencia": "Abre el Módulo de Comando y asígnales una tarea: cada tarea da recursos." })

	# Almacén y dinero.
	var almacen := EstadoJuego.almacen
	if almacen.racion == Enums.Racion.ESTRICTA and almacen.soles_estricta >= 1:
		lista.append({ "id": "racion", "texto": "Ración estricta", "critica": almacen.racion_debilita(),
			"accion": { "menu": "almacen" },
			"detalle": "Llevan %s con ración estricta. Desde el sol %d los colonos se debilitan y pueden enfermar." % [
				UI.soles(almacen.soles_estricta), datos.soles_estricta_para_riesgo],
			"sugerencia": "Vuelve a la ración normal en cuanto haya comida y agua suficientes." })
	if e.viveres() >= almacen.capacidad() * 0.9:
		lista.append({ "id": "almacen_lleno", "texto": "Almacén casi lleno", "critica": false, "accion": { "menu": "almacen" },
			"detalle": "Hay %s kg de víveres en un almacén de %s kg. Lo que no cabe se pierde." % [
				UI.num(e.viveres()), UI.num(almacen.capacidad())],
			"sugerencia": "Amplía el depósito en el Almacén y cocina." })
	if e.recursos["presupuesto"] < datos.presupuesto_critico:
		lista.append({ "id": "dinero", "texto": "Poco presupuesto", "critica": false, "accion": { "menu": "comando" },
			"detalle": "Quedan %s." % UI.dinero(e.recursos["presupuesto"]),
			"sugerencia": "Pon a un científico a «Enviar informe a la Tierra» para conseguir fondos." })

	# Primero las urgentes, sin cambiar el orden dentro de cada grupo.
	var ordenadas: Array[Dictionary] = []
	for urgente: bool in [true, false]:
		for a in lista:
			if a["critica"] == urgente and ordenadas.size() < MAXIMO:
				ordenadas.append(a)
	return ordenadas
