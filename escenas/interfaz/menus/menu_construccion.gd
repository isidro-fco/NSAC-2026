class_name MenuConstruccion
extends PanelContainer
## HU-05: panel lateral del modo construcción y selector de demolición.

var mapa: Mapa
var contenido: VBoxContainer


func iniciar(mapa_base: Mapa) -> void:
	mapa = mapa_base
	set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	offset_top = 64
	offset_bottom = -12
	offset_left = 12
	offset_right = 312
	add_theme_stylebox_override("panel", Hud.estilo_elevado(Color(Hud.FONDO, 0.97), Hud.BORDE, Hud.RADIO + 2, 14))
	contenido = Hud.columna(6)
	add_child(contenido)
	EstadoJuego.estado_cambiado.connect(actualizar)
	actualizar()


func actualizar() -> void:
	if not visible:
		return
	for hijo in contenido.get_children():
		contenido.remove_child(hijo)
		hijo.queue_free()
	var demoliendo := mapa.modo == Enums.ModoMapa.DEMOLICION
	contenido.add_child(Hud.etiqueta("Construcción", 18))
	contenido.add_child(Hud.separador())
	contenido.add_child(Hud.etiqueta("Dinero: $%s    Materiales: %s" % [
		Hud.num(EstadoJuego.recursos["presupuesto"]), Hud.num(EstadoJuego.recursos["materiales"])],
		13, Hud.TEXTO_SUAVE))
	var texto_modo := "Volver a construir" if demoliendo else "Modo demolición"
	contenido.add_child(Hud.boton(texto_modo, mapa.alternar_demolicion, true, "" if demoliendo else Hud.PELIGRO))
	if demoliendo:
		contenido.add_child(Hud.parrafo(
			"Señala un módulo construido o un obstáculo y haz clic para demolerlo. Los módulos iniciales no se pueden demoler."))
		var hueco := Control.new()
		hueco.size_flags_vertical = Control.SIZE_EXPAND_FILL
		contenido.add_child(hueco)
	else:
		var lista := Hud.columna(6)
		for datos: DatosModulo in DatosModulo.construibles():
			lista.add_child(TarjetaModulo.crear(datos, mapa.elegir_modulo))
		contenido.add_child(Hud.desplazable(lista))
	contenido.add_child(Hud.boton("Salir (Esc)", mapa.salir_construccion, true, Hud.FANTASMA))
