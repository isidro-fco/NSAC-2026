class_name MenuDescanso
extends Control
## HU-03: lista de colonos, regreso a la Tierra, reclutamiento y expansión.

var interfaz                  # escena Juego: abre diálogos y cierra el menú
var contenido: VBoxContainer
var scrolls: Array[ScrollContainer] = []
var reconstruccion_pendiente := false

var reclutando := false


func iniciar(juego: Node, titulo: String) -> void:
	interfaz = juego
	contenido = Hud.marco_menu(self, titulo, cerrar)
	EstadoJuego.estado_cambiado.connect(_pedir_reconstruccion)
	_reconstruir()


func cerrar() -> void:
	interfaz.cerrar_menu()


func vista_con_scroll(interior: Control) -> ScrollContainer:
	var scroll := Hud.desplazable(interior)
	scrolls.append(scroll)
	return scroll


func _pedir_reconstruccion() -> void:
	if not reconstruccion_pendiente:
		reconstruccion_pendiente = true
		_reconstruir.call_deferred()


func _reconstruir() -> void:
	reconstruccion_pendiente = false
	Hud.reconstruir(contenido, scrolls, construir)


func construir() -> void:
	var resumen := "Cuartos ocupados: %d/%d    Presupuesto: $%s    Materiales: %s" % [
		EstadoJuego.colonos_activos(), EstadoJuego.cuartos,
		Hud.num(EstadoJuego.recursos["presupuesto"]), Hud.num(EstadoJuego.recursos["materiales"])]
	contenido.add_child(Hud.etiqueta(resumen, 15))
	if reclutando and EstadoJuego.cuartos_libres() <= 0:
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
	var lista := Hud.columna(6)
	for t in EstadoJuego.colonos:
		lista.add_child(TarjetaColono.crear(t, false, interfaz.pedir_regreso))
	lista.add_child(_panel_acciones())
	contenido.add_child(vista_con_scroll(lista))


func _panel_acciones() -> Control:
	var panel := Hud.tarjeta(Hud.FONDO)
	var c := Hud.columna(6)
	panel.add_child(c)
	var f := Hud.fila()
	c.add_child(f)
	var hay_cuartos := EstadoJuego.cuartos_libres() > 0
	var texto_reclutar := "Reclutar Colono" if hay_cuartos else "Reclutar: se requiere expandir el módulo"
	f.add_child(Hud.expandir(Hud.boton_primario(texto_reclutar, _ver_reclutamiento.bind(true), hay_cuartos)))

	var texto_expandir := "Expandir Módulo ($%d + %d materiales)" % [
		EstadoJuego.datos_balance.expandir_descanso_dinero, EstadoJuego.datos_balance.expandir_descanso_materiales]
	if EstadoJuego.cuartos >= EstadoJuego.datos_balance.cuartos_max:
		texto_expandir = "Capacidad máxima alcanzada (%d/%d)" % [EstadoJuego.cuartos, EstadoJuego.datos_balance.cuartos_max]
	f.add_child(Hud.expandir(Hud.boton(texto_expandir, _pedir_expansion, EstadoJuego.puede_expandir_descanso())))
	return panel


func _pedir_expansion() -> void:
	var texto := "Añadir 1 cuarto por $%d y %d materiales" % [
		EstadoJuego.datos_balance.expandir_descanso_dinero, EstadoJuego.datos_balance.expandir_descanso_materiales]
	interfaz.confirmar("Expandir módulo", texto, EstadoJuego.expandir_descanso)


func _construir_reclutamiento() -> void:
	var cabecera := Hud.fila()
	cabecera.add_child(Hud.boton("< Volver", _ver_reclutamiento.bind(false), true, Hud.FANTASMA))
	cabecera.add_child(Hud.etiqueta("Candidatos disponibles", 16))
	contenido.add_child(cabecera)
	var lista := Hud.columna(6)
	for candidato in EstadoJuego.candidatos:
		var tarjeta := Hud.tarjeta()
		var f := Hud.fila(10)
		tarjeta.add_child(f)
		var datos := Hud.columna(2)
		f.add_child(Hud.expandir(datos))
		datos.add_child(Hud.etiqueta(candidato["nombre"]))
		datos.add_child(Hud.etiqueta(Enums.NOMBRE_ROL[candidato["rol"]], 12, Hud.TEXTO_SUAVE))
		var alcanza := EstadoJuego.puede_pagar(candidato["coste"], 0)
		f.add_child(Hud.boton_primario("Contratar ($%d)" % candidato["coste"], _pedir_contrato.bind(candidato), alcanza))
		lista.add_child(tarjeta)
	if EstadoJuego.candidatos.is_empty():
		lista.add_child(Hud.parrafo("No quedan candidatos. Habrá nuevos en unos soles."))
	contenido.add_child(vista_con_scroll(lista))


func _pedir_contrato(candidato: Dictionary) -> void:
	var texto := "Contratar a %s por $%d" % [candidato["nombre"], candidato["coste"]]
	interfaz.confirmar("Confirmar contratación", texto, func() -> void:
		reclutando = false
		EstadoJuego.contratar(candidato))
