class_name MenuDescanso
extends MenuModulo
## HU-03: lista de colonos, regreso a la Tierra, reclutamiento y expansión.

var reclutando := false


func construir() -> void:
	var resumen := "Cuartos ocupados: %d/%d    Presupuesto: $%s    Materiales: %s" % [
		EstadoJuego.tripulacion.cuartos - EstadoJuego.tripulacion.cuartos_libres(), EstadoJuego.tripulacion.cuartos,
		UI.num(EstadoJuego.economia.recursos["presupuesto"]), UI.num(EstadoJuego.economia.recursos["materiales"])]
	contenido.add_child(UI.etiqueta_pixel(resumen, UI.T_DETALLE))
	if reclutando and EstadoJuego.tripulacion.cuartos_libres() <= 0:
		reclutando = false
	if reclutando:
		_construir_reclutamiento()
	else:
		_construir_lista()


func atras() -> bool:
	if reclutando:
		_ver_reclutamiento(false)
		return true
	return false


func _ver_reclutamiento(activo: bool) -> void:
	reclutando = activo
	_pedir_reconstruccion()


func _construir_lista() -> void:
	var lista := UI.columna(6)
	for t in EstadoJuego.tripulacion.colonos:
		lista.add_child(TarjetaColono.new(t, interfaz.pedir_regreso))
	for t in EstadoJuego.tripulacion.en_viaje:
		lista.add_child(TarjetaColono.new(t))
	lista.add_child(_panel_acciones())
	contenido.add_child(vista_con_scroll(lista))


func _panel_acciones() -> Control:
	var panel := UI.tarjeta(UI.FONDO_CLARO)
	var c := UI.columna(6)
	panel.add_child(c)
	var f := UI.fila()
	c.add_child(f)
	var hay_cuartos := EstadoJuego.tripulacion.cuartos_libres() > 0
	var texto_reclutar := "Reclutar Colono" if hay_cuartos else "Reclutar: se requiere expandir el módulo"
	f.add_child(UI.expandir(UI.boton_primario(texto_reclutar, _ver_reclutamiento.bind(true), hay_cuartos)))

	var texto_expandir := "Expandir Módulo ($%d + %d materiales)" % [
		EstadoJuego.datos_balance.expandir_descanso_dinero, EstadoJuego.datos_balance.expandir_descanso_materiales]
	if EstadoJuego.tripulacion.cuartos >= EstadoJuego.datos_balance.cuartos_max:
		texto_expandir = "Capacidad máxima alcanzada (%d/%d)" % [EstadoJuego.tripulacion.cuartos, EstadoJuego.datos_balance.cuartos_max]
	f.add_child(UI.expandir(UI.boton(texto_expandir, _pedir_expansion, EstadoJuego.tripulacion.puede_ampliar_cuartos())))
	return panel


func _pedir_expansion() -> void:
	var texto := "Añadir 1 cuarto por $%d y %d materiales" % [
		EstadoJuego.datos_balance.expandir_descanso_dinero, EstadoJuego.datos_balance.expandir_descanso_materiales]
	interfaz.confirmar("Expandir módulo", texto, EstadoJuego.tripulacion.ampliar_cuartos)


func _construir_reclutamiento() -> void:
	var cabecera := UI.fila()
	cabecera.add_child(UI.boton("< Volver", _ver_reclutamiento.bind(false)))
	var titulo := UI.seccion("Candidatos disponibles")
	titulo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cabecera.add_child(titulo)
	contenido.add_child(cabecera)
	var lista := UI.columna(6)
	for candidato in EstadoJuego.tripulacion.candidatos:
		var tarjeta := UI.tarjeta()
		var f := UI.fila(10)
		tarjeta.add_child(f)
		var perfil := DatosColono.new(candidato["nombre"], candidato["rol"], candidato.get("retrato", ""))
		f.add_child(UI.avatar(perfil))
		f.add_child(UI.expandir(UI.cabecera_tarjeta(candidato["nombre"], Enums.NOMBRE_ROL[candidato["rol"]], UI.TEXTO)))
		var alcanza := EstadoJuego.economia.puede_pagar(candidato["coste"], 0)
		f.add_child(UI.boton_accion("Contratar ($%d)" % candidato["coste"], _pedir_contrato.bind(candidato), alcanza))
		lista.add_child(tarjeta)
	if EstadoJuego.tripulacion.candidatos.is_empty():
		lista.add_child(UI.parrafo("No quedan candidatos. Habrá nuevos en unos soles."))
	contenido.add_child(vista_con_scroll(lista))


func _pedir_contrato(candidato: Dictionary) -> void:
	var texto := "Contratar a %s por $%d.\nViajará desde la Tierra y llegará a la plataforma de aterrizaje en %d soles; su cuarto queda reservado." % [
		candidato["nombre"], candidato["coste"], EstadoJuego.datos_balance.soles_viaje_colono]
	interfaz.confirmar("Confirmar contratación", texto, func() -> void:
		reclutando = false
		EstadoJuego.tripulacion.contratar(candidato))
