# indicador_recurso.gd
# Píldora del HUD que muestra un recurso con su valor (y su máximo) y se pinta en rojo si es crítico.

class_name IndicadorRecurso
extends VBoxContainer
## Píldora de un recurso en la barra superior (HU-07), según docs/diseno/Principal.pdf:
##   ╭──────────────╮      ╭──────────────╮
##   │   Oxígeno    │      │ Presupuesto  │   Los recursos con capacidad máxima
##   │   120/200    │      │     1250     │   muestran "lo que hay / máximo";
##   ╰──────────────╯      ╰──────────────╯   los demás, solo su valor.
## La unidad va al lado del valor, más chica (kg, L, kWh). Al pasar el mouse,
## un tooltip encadenable (Tooltips) explica de dónde sale y a dónde va el
## recurso, con los términos del glosario resaltados. Si el recurso es crítico (reserva baja o
## balance negativo), solo el valor se pinta en rojo; el nombre no cambia.

const ANCHO := 108

var recurso := ""
var nombre_label: Label
var valor_label: Label
var unidad_label: Label


func _init(id_recurso: String) -> void:
	recurso = id_recurso
	custom_minimum_size = Vector2(ANCHO, 0)
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 6)
	mouse_filter = Control.MOUSE_FILTER_PASS     # para mostrar el tooltip

	nombre_label = UI.etiqueta_pixel(Idioma.t(Enums.NOMBRE_RECURSO[recurso]), UI.T_TEXTO)
	nombre_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(nombre_label)
	var fila := UI.fila(3)
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(fila)
	valor_label = UI.etiqueta_pixel("", UI.T_TEXTO)
	fila.add_child(valor_label)
	unidad_label = UI.etiqueta_pixel(UI.UNIDAD.get(recurso, ""), UI.T_DETALLE, UI.TEXTO_SUAVE)
	unidad_label.size_flags_vertical = Control.SIZE_SHRINK_END
	unidad_label.visible = unidad_label.text != ""
	fila.add_child(unidad_label)
	# Los hijos no capturan el ratón: así el tooltip aparece en toda la píldora.
	for hijo: Control in find_children("*", "Control", true, false):
		hijo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	actualizar()
	Tooltips.registrar(self, contenido_tooltip)


func actualizar() -> void:
	var cap := EstadoJuego.economia.capacidad(recurso)
	var valor := EstadoJuego.economia.valor(recurso)
	var critico := EstadoJuego.economia.es_critico(recurso)
	var capacidad := "" if is_inf(cap) else "/%d" % int(cap)
	valor_label.text = (UI.dinero(valor) if recurso == "presupuesto" else UI.num(valor)) + capacidad
	valor_label.add_theme_color_override("font_color",
		UI.CRITICO if critico else UI.COLOR_RECURSO.get(recurso, UI.TEXTO))


## Tooltip: cuánto hay, de dónde sale, en qué se gasta y para cuántos soles alcanza.
func contenido_tooltip() -> Dictionary:
	var e := EstadoJuego.economia
	var valor := e.valor(recurso)
	var cap := e.capacidad(recurso)
	var lineas: PackedStringArray = []
	var hay := UI.cantidad(recurso, valor) + ("" if is_inf(cap) else Idioma.t(" de ") + UI.cantidad(recurso, cap))
	lineas.append((Idioma.t("Baterías: ") if recurso == "energia" else Idioma.t("Hay: ")) + hay)
	if recurso == "energia":
		lineas.append(Idioma.t("Producción: %s") % UI.kw(e.produccion(recurso)))
		lineas.append(Idioma.t("  Base: 2 reactores de fisión de 40 kW y 1 panel solar de 20 kW"))
		_lineas_modulos(lineas, func(d: DatosModulo) -> float: return d.produce.get("energia", 0.0), " kW")
		lineas.append(Idioma.t("Consumo de los módulos: %s") % UI.kw(e.consumo(recurso)))
		_lineas_modulos(lineas, func(d: DatosModulo) -> float: return d.consumo_kw, " kW")
		lineas.append(Idioma.t("Balance: %s, o sea %s kWh por sol en las baterías.") % [
			UI.kw(e.balance(recurso), true), UI.con_signo(e.cambio_por_sol(recurso))])
	else:
		var unidad: String = " " + UI.UNIDAD[recurso] if UI.UNIDAD.has(recurso) else ""
		var base: float = EstadoJuego.datos_balance.produccion_base.get(recurso, 0.0)
		if recurso == "presupuesto":
			lineas.append(Idioma.t("Llega cada sol: %s (fondos de la misión)") % UI.dinero(e.produccion(recurso)))
		else:
			lineas.append(Idioma.t("Producción por sol: %s%s") % [UI.num(e.produccion(recurso)), unidad])
		if base > 0.0 and recurso != "presupuesto":
			lineas.append(Idioma.t("  Base inicial: %s%s") % [UI.num(base), unidad])
		_lineas_modulos(lineas, func(d: DatosModulo) -> float: return d.produce.get(recurso, 0.0), unidad)
		if recurso == "agua" and e.agua_reciclada() > 0.0:
			lineas.append(Idioma.t("  Reciclaje del soporte vital (80 %%): %s L") % UI.num(e.agua_reciclada()))
		if e.consumo(recurso) > 0.0:
			var por_colono: float = EstadoJuego.datos_balance.consumo_por_colono.get(recurso, 0.0)
			lineas.append(Idioma.t("Consumo por sol: %s%s (%d colonos x %s%s%s)") % [UI.num(e.consumo(recurso)), unidad,
				EstadoJuego.tripulacion.activos(), UI.num(por_colono), unidad,
				"" if recurso == "oxigeno" else Idioma.t(", según la ración")])
		if EstadoJuego.comando.multiplicador() > 1.0:
			lineas.append(Idioma.t("El Módulo de Comando multiplica la producción x%s.") % UI.num(EstadoJuego.comando.multiplicador()))
	var restantes := e.soles_restantes(recurso)
	if not is_inf(restantes):
		lineas.append(Idioma.t("Al ritmo de ahora se acaba en %s soles.") % UI.num(floorf(restantes)))
	return { "titulo": Idioma.t(Enums.NOMBRE_RECURSO[recurso]), "texto": "\n".join(lineas) }


## "  2 Panel solar: 40 kW" por cada tipo de módulo construido que aporte algo.
func _lineas_modulos(lineas: PackedStringArray, cuanto: Callable, unidad: String) -> void:
	var cuenta := {}
	for id: String in EstadoJuego.economia.modulos_activos:
		cuenta[id] = cuenta.get(id, 0) + 1
	for id: String in cuenta:
		var d := DatosModulo.obtener(id)
		var valor: float = cuanto.call(d)
		if valor > 0.0:
			lineas.append("  %s%s: %s%s" % ["%d x " % cuenta[id] if cuenta[id] > 1 else "", d.nombre,
				UI.num(valor * cuenta[id]), unidad])
