# menu_construccion.gd
# Panel lateral del modo construcción con las pestañas Construir y Demoler.

class_name MenuConstruccion
extends PanelContainer
## HU-05: panel lateral del modo construcción, según docs/diseno/Construir.pdf y Demoler.pdf:
##   ╭──────────────────────╮
##   │ Construcción         │
##   │ (Construir)(Demoler) │   pestañas: la activa en naranja
##   │ Disponible: $1,250 M  60 mat.
##   │ Energía: produce 100 kW, gasta 80 kW
##   │ ▦ Soporte Vital      │   tarjetas de módulos  o  instrucciones para demoler
##   │   $300   30 mat.     │
##   │ ...                  │
##   │ (      Cerrar      ) │
##   ╰──────────────────────╯

const ANCHO := 264

var mapa: Mapa
var contenido := UI.columna(12)


func _init(mapa_base: Mapa) -> void:
	mapa = mapa_base
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	offset_top = Hud.ALTO_BARRA + 6
	offset_bottom = -Hud.MARGEN
	offset_left = Hud.MARGEN
	offset_right = Hud.MARGEN + ANCHO
	UI.aplicar_marco(self, 14)
	add_child(contenido)
	EstadoJuego.estado_cambiado.connect(actualizar)
	mapa.modo_cambiado.connect(func(modo: Enums.ModoMapa) -> void:
		visible = modo in [Enums.ModoMapa.CATALOGO, Enums.ModoMapa.DEMOLICION]
		actualizar())


func actualizar() -> void:
	if not visible:
		return
	for hijo in contenido.get_children():
		contenido.remove_child(hijo)
		hijo.queue_free()
	var demoliendo := mapa.modo == Enums.ModoMapa.DEMOLICION

	var titulo := UI.seccion("Construcción")
	titulo.custom_minimum_size = Vector2(0, 30)
	titulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	contenido.add_child(titulo)
	var pestanas := UI.fila(6)
	for pestana: Array in [["Construir", Enums.ModoMapa.CATALOGO], ["Demoler", Enums.ModoMapa.DEMOLICION]]:
		var b := UI.boton_pixel(pestana[0], mapa.cambiar_modo.bind(pestana[1]), false, UI.T_TEXTO)
		UI.pintar_boton_pixel(b, mapa.modo == pestana[1], UI.ACENTO, UI.TARJETA)
		b.custom_minimum_size = Vector2(0, 32)
		pestanas.add_child(UI.expandir(b))
	contenido.add_child(pestanas)
	var recursos: Dictionary = EstadoJuego.economia.recursos
	contenido.add_child(UI.etiqueta_pixel("Disponible: %s   %s mat." % [
		UI.dinero(recursos["presupuesto"]), UI.num(recursos["materiales"])], UI.T_DETALLE))
	var economia := EstadoJuego.economia
	contenido.add_child(UI.etiqueta_pixel("Energía: produce %s, gasta %s" % [
		UI.kw(economia.produccion("energia")), UI.kw(economia.consumo("energia"))], UI.T_DETALLE,
		UI.CRITICO if economia.balance("energia") < 0.0 else UI.TEXTO_SUAVE))

	if demoliendo:
		var ayuda := UI.etiqueta_pixel(
			"Señala un módulo construido o un obstáculo y haz clic para demolerlo.\n\nLos módulos iniciales no se pueden demoler.",
			UI.T_DETALLE)
		ayuda.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ayuda.add_theme_constant_override("line_spacing", 4)
		ayuda.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var margen := MarginContainer.new()
		margen.add_theme_constant_override("margin_top", 10)
		margen.size_flags_vertical = Control.SIZE_EXPAND_FILL
		margen.add_child(ayuda)
		contenido.add_child(margen)
	else:
		var lista := UI.columna(8)
		for id: String in EstadoJuego.datos_balance.catalogo:
			lista.add_child(TarjetaModulo.new(DatosModulo.obtener(id), mapa.elegir_modulo))
		contenido.add_child(UI.desplazable(lista))

	var cerrar := UI.boton("Cerrar", mapa.cambiar_modo.bind(Enums.ModoMapa.NORMAL))
	cerrar.custom_minimum_size = Vector2(0, 34)
	cerrar.tooltip_text = "Salir del modo construcción (Esc)"
	contenido.add_child(cerrar)
