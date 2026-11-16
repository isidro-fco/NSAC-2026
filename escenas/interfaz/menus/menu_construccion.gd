# menu_construccion.gd
# Panel lateral del modo construcción con el interruptor Construir / Demoler.

class_name MenuConstruccion
extends PanelContainer
## HU-05: panel lateral del modo construcción, según docs/diseno/Construir.pdf y Demoler.pdf,
## con el estilo de cabina del Módulo de Comando (ver Cabina):
##   CONSTRUCCION
##   [▓ CONSTRUIR ▓|  DEMOLER  ]   interruptor pixel (InterruptorPixel)
##   MODULOS [7]        4 AL ALCANCE
##   ╔ ┃▦ SOPORTE VITAL ╗          tarjetas de módulos  o  instrucciones para demoler
##   ╚ ┃  $300 M 30 MAT ╝
## Para salir, el botón Construir del HUD pasa a ser Cancelar.

const ANCHO := 360

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
	MarcoVentana.aplicar_lateral(self, 8)
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
	var economia := EstadoJuego.economia

	var titulo := UI.etiqueta_pixel(Idioma.t("CONSTRUCCION"), UI.T_TEXTO + 4)
	titulo.custom_minimum_size = Vector2(0, 24)
	titulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	contenido.add_child(titulo)
	var opciones: Array[String] = [Idioma.t("CONSTRUIR"), Idioma.t("DEMOLER")]
	var colores: Array[Color] = [UI.ACENTO, UI.CRITICO]
	var interruptor := InterruptorPixel.new(opciones, colores, 1 if demoliendo else 0)
	interruptor.cambiado.connect(func(i: int) -> void:
		mapa.cambiar_modo(Enums.ModoMapa.DEMOLICION if i == 1 else Enums.ModoMapa.CATALOGO))
	contenido.add_child(interruptor)

	if demoliendo:
		contenido.add_child(Cabina.encabezado(Idioma.t("Demolición")))
		var pantalla := Cabina.pantalla(10)
		var ayuda := UI.columna(14)
		var aviso := Cabina.pildora(Idioma.t("MODO DEMOLICION"), UI.CRITICO)
		aviso.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		ayuda.add_child(aviso)
		for texto: String in ["Señala un módulo construido o un obstáculo y haz clic para demolerlo.",
				Idioma.t("Los módulos iniciales no se pueden demoler.")]:
			var linea := UI.etiqueta_pixel(Cabina.mayus(texto), UI.T_DETALLE, UI.TEXTO_SUAVE)
			linea.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			linea.add_theme_constant_override("line_spacing", 4)
			ayuda.add_child(linea)
		pantalla.add_child(ayuda)
		contenido.add_child(pantalla)
	else:
		var catalogo: Array = EstadoJuego.datos_balance.catalogo
		var alcanzables := catalogo.filter(func(id: String) -> bool:
			var d := DatosModulo.obtener(id)
			return economia.puede_pagar(d.dinero, d.materiales)).size()
		contenido.add_child(Cabina.encabezado(Idioma.t("Módulos"), catalogo.size(), Idioma.t("%d al alcance") % alcanzables))
		var pantalla := Cabina.pantalla(4)
		var lista := UI.columna(6)
		for id: String in catalogo:
			lista.add_child(TarjetaModulo.new(DatosModulo.obtener(id), mapa.elegir_modulo))
		var scroll := UI.desplazable(Cabina.con_margen_scroll(lista))
		pantalla.add_child(scroll)
		contenido.add_child(pantalla)
