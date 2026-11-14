# indicador_recurso.gd
# Píldora del HUD que muestra un recurso con su valor (y su máximo) y se pinta en rojo si es crítico.

class_name IndicadorRecurso
extends VBoxContainer
## Píldora de un recurso en la barra superior (HU-07), según docs/diseno/Principal.pdf:
##   ╭──────────────╮      ╭──────────────╮
##   │   Oxígeno    │      │ Presupuesto  │   Los recursos con capacidad máxima
##   │   120/200    │      │     1250     │   muestran "lo que hay / máximo";
##   ╰──────────────╯      ╰──────────────╯   los demás, solo su valor.
## Balance por sol en el tooltip. Si el recurso es crítico (reserva baja o
## balance negativo), el nombre y el valor se pintan en rojo.

const ANCHO := 118

var recurso := ""
var nombre_label: Label
var valor_label: Label


func _init(id_recurso: String) -> void:
	recurso = id_recurso
	custom_minimum_size = Vector2(ANCHO, 0)
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 6)
	mouse_filter = Control.MOUSE_FILTER_PASS     # para mostrar el tooltip

	nombre_label = UI.etiqueta_pixel(Enums.NOMBRE_RECURSO[recurso], UI.T_TEXTO)
	nombre_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(nombre_label)
	valor_label = UI.etiqueta_pixel("", UI.T_TEXTO)
	valor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(valor_label)
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
	nombre_label.add_theme_color_override("font_color", UI.CRITICO if critico else UI.TEXTO)
	valor_label.text = UI.num(valor) + capacidad
	valor_label.add_theme_color_override("font_color",
		UI.CRITICO if critico else UI.COLOR_RECURSO.get(recurso, UI.TEXTO))
	tooltip_text = "%s: %s%s (%s por sol)" % [Enums.NOMBRE_RECURSO[recurso], UI.num(valor),
		capacidad, UI.con_signo(saldo)]
