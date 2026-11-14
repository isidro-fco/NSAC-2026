# menu_descanso.gd
# Menú del módulo de descanso: lista de colonos, regreso a la Tierra, reclutamiento y ampliación de cuartos.

class_name MenuDescanso
extends MenuModulo
## HU-03: lista de colonos, regreso a la Tierra, reclutamiento y expansión.

var reclutando := false


func construir() -> void:
	var tripulacion := EstadoJuego.tripulacion
	var recursos := EstadoJuego.economia.recursos
	var resumen := "Cuartos ocupados: %d/%d    Presupuesto: %s    Materiales: %s" % [
		tripulacion.cuartos - tripulacion.cuartos_libres(), tripulacion.cuartos,
		UI.dinero(recursos["presupuesto"]), UI.num(recursos["materiales"])]
	contenido.add_child(UI.etiqueta_pixel(resumen, UI.T_DETALLE))
	if reclutando and tripulacion.cuartos_libres() <= 0:
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

	var datos := EstadoJuego.datos_balance
	var texto_expandir := "Expandir Módulo (%s + %d materiales)" % [UI.dinero(datos.expandir_descanso_dinero), datos.expandir_descanso_materiales]
	if EstadoJuego.tripulacion.cuartos >= datos.cuartos_max:
		texto_expandir = "Capacidad máxima alcanzada (%d/%d)" % [EstadoJuego.tripulacion.cuartos, datos.cuartos_max]
	f.add_child(UI.expandir(UI.boton(texto_expandir, _pedir_expansion, EstadoJuego.tripulacion.puede_ampliar_cuartos())))
	return panel


func _pedir_expansion() -> void:
	var datos := EstadoJuego.datos_balance
	var texto := "Añadir 1 cuarto por %s y %d materiales" % [UI.dinero(datos.expandir_descanso_dinero), datos.expandir_descanso_materiales]
	interfaz.confirmar("Expandir módulo", texto, EstadoJuego.tripulacion.ampliar_cuartos)


func _construir_reclutamiento() -> void:
	cabecera_subvista("Candidatos disponibles", _ver_reclutamiento.bind(false))
	var lista := UI.columna(6)
	for candidato in EstadoJuego.tripulacion.candidatos:
		var tarjeta := UI.tarjeta()
		var f := UI.fila(10)
		tarjeta.add_child(f)
		var perfil := DatosColono.new(candidato["nombre"], candidato["rol"], candidato.get("retrato", ""))
		f.add_child(UI.avatar(perfil))
		f.add_child(UI.expandir(UI.cabecera_tarjeta(candidato["nombre"], Enums.NOMBRE_ROL[candidato["rol"]], UI.TEXTO)))
		var alcanza := EstadoJuego.economia.puede_pagar(candidato["coste"], 0)
		f.add_child(UI.boton_accion("Contratar (%s)" % UI.dinero(candidato["coste"]), _pedir_contrato.bind(candidato), alcanza))
		lista.add_child(tarjeta)
	if EstadoJuego.tripulacion.candidatos.is_empty():
		lista.add_child(UI.parrafo("No quedan candidatos. Habrá nuevos en unos soles."))
	contenido.add_child(vista_con_scroll(lista))


func _pedir_contrato(candidato: Dictionary) -> void:
	var texto := "Contratar a %s por %s.\nViajará desde la Tierra y llegará a la plataforma de aterrizaje en %d soles; su cuarto queda reservado." % [
		candidato["nombre"], UI.dinero(candidato["coste"]), EstadoJuego.datos_balance.soles_viaje_colono]
	interfaz.confirmar("Confirmar contratación", texto, func() -> void:
		reclutando = false
		EstadoJuego.tripulacion.contratar(candidato))
