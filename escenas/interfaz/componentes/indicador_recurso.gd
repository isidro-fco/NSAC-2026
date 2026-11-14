# indicador_recurso.gd
# Píldora del HUD que muestra un recurso con su valor (y su máximo) y se pinta en rojo si es crítico.

class_name IndicadorRecurso
extends VBoxContainer
## Píldora de un recurso en la barra superior (HU-07), según docs/diseno/Principal.pdf:
##   ╭──────────────╮      ╭──────────────╮
##   │   Oxígeno    │      │ Presupuesto  │   Los recursos con capacidad máxima
##   │   120/200    │      │     1250     │   muestran "lo que hay / máximo";
##   ╰──────────────╯      ╰──────────────╯   los demás, solo su valor.
## La unidad va al lado del valor, más chica (kg, L, kWh). Balance por sol en
## el tooltip (la energía, en kW). Si el recurso es crítico (reserva baja o
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

	nombre_label = UI.etiqueta_pixel(Enums.NOMBRE_RECURSO[recurso], UI.T_TEXTO)
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


func actualizar() -> void:
	var cap := EstadoJuego.economia.capacidad(recurso)
	var valor := EstadoJuego.economia.valor(recurso)
	var saldo := EstadoJuego.economia.balance(recurso)
	var critico := EstadoJuego.economia.es_critico(recurso)
	var capacidad := "" if is_inf(cap) else "/%d" % int(cap)
	valor_label.text = (UI.dinero(valor) if recurso == "presupuesto" else UI.num(valor)) + capacidad
	valor_label.add_theme_color_override("font_color",
		UI.CRITICO if critico else UI.COLOR_RECURSO.get(recurso, UI.TEXTO))
	var nombre: String = Enums.NOMBRE_RECURSO[recurso]
	if recurso == "energia":
		var economia := EstadoJuego.economia
		tooltip_text = "Baterías: %s de %s\nPaneles y reactores: %s · Módulos: %s\nBalance: %s (%s kWh por sol)" % [
			UI.cantidad(recurso, valor), UI.cantidad(recurso, cap), UI.kw(economia.produccion(recurso)),
			UI.kw(economia.consumo(recurso)), UI.kw(saldo, true), UI.con_signo(economia.cambio_por_sol(recurso))]
	else:
		var tope := "" if is_inf(cap) else " de " + UI.cantidad(recurso, cap)
		var por_sol: String = ("+" if saldo >= 0.0 else "") + UI.dinero(saldo) if recurso == "presupuesto" \
			else UI.con_signo(saldo) + (" " + UI.UNIDAD[recurso] if UI.UNIDAD.has(recurso) else "")
		tooltip_text = "%s: %s%s (%s por sol)" % [nombre, UI.cantidad(recurso, valor), tope, por_sol]
