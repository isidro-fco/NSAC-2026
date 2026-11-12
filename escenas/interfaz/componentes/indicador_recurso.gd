class_name IndicadorRecurso
extends VBoxContainer
## Píldora de un recurso en la barra superior (HU-07), según docs/diseno/Principal.pdf:
##   ╭──────────────╮      ╭──────────────╮
##   │   Oxígeno    │      │ Presupuesto  │   Los recursos con capacidad máxima
##   │ ▪▪▪▪▪▪▫▫▫▫▫▫ │      │     1250     │   muestran una barra de cuadritos;
##   ╰──────────────╯      ╰──────────────╯   los demás, su valor.
## Valor exacto y balance por sol en el tooltip. Si el recurso es crítico, el
## nombre y la barra se pintan en rojo.

const ANCHO := 118

var recurso := ""
var nombre_label: Label
var valor_label: Label
var barra: BarraSegmentada


func _init(id_recurso: String) -> void:
	recurso = id_recurso
	custom_minimum_size = Vector2(ANCHO, 0)
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 6)
	mouse_filter = Control.MOUSE_FILTER_PASS     # para mostrar el tooltip

	nombre_label = UI.etiqueta_pixel(Enums.NOMBRE_RECURSO[recurso], UI.T_TEXTO)
	nombre_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(nombre_label)
	if is_inf(EstadoJuego.economia.capacidad(recurso)):
		valor_label = UI.etiqueta_pixel("", UI.T_TEXTO)
		valor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(valor_label)
	else:
		barra = BarraSegmentada.new()
		add_child(barra)
	# Los hijos no capturan el ratón: así el tooltip aparece en toda la píldora.
	for hijo: Control in find_children("*", "Control", true, false):
		hijo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	actualizar()


func actualizar() -> void:
	var cap := EstadoJuego.economia.capacidad(recurso)
	var valor := EstadoJuego.economia.valor(recurso)
	var saldo := EstadoJuego.economia.balance(recurso)
	var critico := EstadoJuego.economia.es_critico(recurso)
	var color_nombre := UI.CRITICO if critico else UI.TEXTO
	nombre_label.add_theme_color_override("font_color", color_nombre)
	if valor_label != null:
		valor_label.text = UI.num(valor)
		valor_label.add_theme_color_override("font_color", color_nombre)
	if barra != null:
		barra.proporcion = valor / cap
		barra.color = UI.CRITICO if critico else UI.COLOR_RECURSO.get(recurso, UI.TEXTO)
	var capacidad := "" if is_inf(cap) else "/%d" % int(cap)
	tooltip_text = "%s: %s%s (%s por sol)" % [Enums.NOMBRE_RECURSO[recurso], UI.num(valor),
		capacidad, UI.con_signo(saldo)]
