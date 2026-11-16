# menu_descanso.gd
# Menú del módulo de descanso: lista de colonos, regreso a la Tierra, reclutamiento y ampliación de cuartos.

class_name MenuDescanso
extends MenuModulo
## HU-03: lista de colonos, regreso a la Tierra, reclutamiento y expansión.
## Estilo de cabina del Módulo de Comando (ver Cabina):
##   [CUARTOS 3/4 ■■■□] [PRESUPUESTO] [MATERIALES] [RECLUTAR COLONO / 3 candidatos] [EXPANDIR MODULO / costo]
##   TRIPULACION [3]                                             1 EN VIAJE
##   ┌ ▣ ELENA VARGAS RUIZ ──── [LIBRE] [ENVIAR] ┐ ┌ ▣ TOMAS IBARRA ... ┐
##   │   INGENIERIA  RAD ▬▬▭▭▭│▭ 12/120          │ │                    │

const COLUMNAS := 2

var reclutando := false


func _init() -> void:
	con_cabecera = false     # sin título: como la sala de comandos


func construir() -> void:
	var tripulacion := EstadoJuego.tripulacion
	if reclutando and tripulacion.cuartos_libres() <= 0:
		reclutando = false
	contenido.add_child(_barra_superior())
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


# --- Barra superior -------------------------------------------------------

## Ocupación de los cuartos, dinero y materiales, y los botones de reclutar
## y expandir el módulo.
func _barra_superior() -> Control:
	var tripulacion := EstadoJuego.tripulacion
	var recursos := EstadoJuego.economia.recursos
	var datos := EstadoJuego.datos_balance
	var f := UI.fila(6)
	var ocupados := tripulacion.cuartos - tripulacion.cuartos_libres()
	var cuartos: Array = Cabina.celda(150)
	cuartos[1].add_child(Cabina.centrada(Idioma.t("CUARTOS %d/%d") % [ocupados, tripulacion.cuartos]))
	var marcas := Cabina.marcas(ocupados, tripulacion.cuartos, Cabina.NARANJA, clampi(100 / maxi(tripulacion.cuartos, 1), 6, 14))
	# Los cuartos reservados para quien viene de viaje, en ámbar.
	for i in range(tripulacion.colonos.size(), mini(ocupados, tripulacion.cuartos)):
		marcas.get_child(i).color = UI.ADVERTENCIA
	cuartos[1].add_child(marcas)
	f.add_child(cuartos[0])
	for metrica: Control in [Cabina.celda_metrica(Idioma.t("Presupuesto"), UI.dinero(recursos["presupuesto"])),
			Cabina.celda_metrica(Idioma.t("Materiales"), UI.num(recursos["materiales"]))]:
		metrica.size_flags_horizontal = Control.SIZE_FILL
		metrica.custom_minimum_size.x = 120
		f.add_child(metrica)

	var hay_cuartos := tripulacion.cuartos_libres() > 0
	var candidatos := tripulacion.candidatos.size()
	var libres := tripulacion.cuartos_libres()
	var detalle := Idioma.t("%d candidato%s") % [candidatos, "" if candidatos == 1 else "s"] \
		+ "  ·  " + Idioma.t("%d libre" if libres == 1 else "%d libres") % libres
	if not hay_cuartos:
		detalle = Idioma.t("Sin cuartos libres")
	var reclutar := Cabina.boton_grande(Idioma.t("Reclutar colono"), detalle, _ver_reclutamiento.bind(not reclutando),
		hay_cuartos, Idioma.t("Hace falta un cuarto libre") if not hay_cuartos else "")
	if reclutando:
		reclutar = Cabina.boton_grande(Idioma.t("Ver tripulación"), Idioma.t("Volver a la lista"), _ver_reclutamiento.bind(false))
	f.add_child(UI.expandir(reclutar))

	var titulo := Idioma.t("Construir cuarto")
	var costo := Idioma.t("%s  ·  %d materiales") % [UI.dinero(datos.expandir_descanso_dinero), datos.expandir_descanso_materiales]
	var al_maximo := tripulacion.cuartos >= datos.cuartos_max
	if al_maximo:
		titulo = Idioma.t("Capacidad máxima")
		costo = Idioma.t("%d/%d cuartos") % [tripulacion.cuartos, datos.cuartos_max]
	var puede := tripulacion.puede_ampliar_cuartos()
	f.add_child(UI.expandir(Cabina.boton_grande(titulo, costo, _pedir_expansion, puede,
		Idioma.t("No alcanzan el presupuesto o los materiales") if not puede and not al_maximo else "")))
	return f


func _pedir_expansion() -> void:
	var datos := EstadoJuego.datos_balance
	var texto := Idioma.t("Añadir 1 cuarto por %s y %d materiales") % [UI.dinero(datos.expandir_descanso_dinero), datos.expandir_descanso_materiales]
	interfaz.confirmar(Idioma.t("Expandir módulo"), texto, EstadoJuego.tripulacion.ampliar_cuartos)


## Rejilla de dos columnas dentro de una pantalla de cabina con scroll.
func _pantalla_rejilla(controles: Array[Control], vacio: String) -> Control:
	var pantalla := Cabina.pantalla()
	var rejilla := GridContainer.new()
	rejilla.columns = COLUMNAS
	rejilla.add_theme_constant_override("h_separation", 8)
	rejilla.add_theme_constant_override("v_separation", 6)
	for control in controles:
		rejilla.add_child(UI.expandir(control))
	var interior: Control = rejilla
	if controles.is_empty():
		interior = Cabina.vacio(vacio)
	pantalla.add_child(vista_con_scroll(Cabina.con_margen_scroll(interior)))
	return pantalla


# --- Tripulación ----------------------------------------------------------

func _construir_lista() -> void:
	var tripulacion := EstadoJuego.tripulacion
	var detalle := Idioma.t("%d en viaje") % tripulacion.en_viaje.size() if not tripulacion.en_viaje.is_empty() else ""
	contenido.add_child(Cabina.encabezado(Idioma.t("Tripulación"), tripulacion.colonos.size(), detalle))
	var fichas: Array[Control] = []
	for t in tripulacion.colonos:
		var enviar := Cabina.boton(Idioma.t("A la Tierra"), interfaz.pedir_regreso.bind(t), true, UI.CRITICO)
		enviar.tooltip_text = Idioma.t("%s vuelve a la Tierra y deja libre su cuarto") % t.nombre
		fichas.append(Cabina.ficha_colono(t, enviar))
	for t in tripulacion.en_viaje:
		fichas.append(Cabina.ficha_colono(t))
	contenido.add_child(_pantalla_rejilla(fichas, Idioma.t("No hay colonos. Recluta uno para empezar.")))


# --- Reclutamiento --------------------------------------------------------

func _construir_reclutamiento() -> void:
	var tripulacion := EstadoJuego.tripulacion
	contenido.add_child(Cabina.encabezado(Idioma.t("Candidatos disponibles"), tripulacion.candidatos.size(),
		Idioma.t("Llegan en %s") % UI.soles(EstadoJuego.datos_balance.soles_viaje_colono)))
	var tarjetas: Array[Control] = []
	for candidato in tripulacion.candidatos:
		tarjetas.append(_tarjeta_candidato(candidato))
	contenido.add_child(_pantalla_rejilla(tarjetas, Idioma.t("No quedan candidatos. Habrá nuevos en unos soles.")))


## Candidato: retrato, nombre, rol y el botón de contratar con su coste.
func _tarjeta_candidato(candidato: Dictionary) -> Control:
	var perfil := DatosColono.new(candidato["nombre"], candidato["rol"], candidato.get("retrato", ""))
	var alcanza := EstadoJuego.economia.puede_pagar(candidato["coste"], 0)
	var tarjeta := Cabina.tarjeta(Cabina.NARANJA if alcanza else Cabina.REJILLA_BORDE)
	var f := UI.fila(8)
	tarjeta.add_child(f)
	f.add_child(Cabina.retrato(perfil))
	var c := UI.columna(5)
	c.alignment = BoxContainer.ALIGNMENT_CENTER
	f.add_child(UI.expandir(c))
	c.add_child(Cabina.recortada(Cabina.mayus(candidato["nombre"])))
	c.add_child(UI.etiqueta_pixel(Cabina.mayus(Idioma.t(Enums.NOMBRE_ROL[candidato["rol"]])), UI.T_DETALLE, Cabina.NARANJA))
	var boton := Cabina.boton(Idioma.t("Contratar %s") % UI.dinero(candidato["coste"]), _pedir_contrato.bind(candidato), alcanza)
	if not alcanza:
		boton.tooltip_text = Idioma.t("No alcanza el presupuesto")
		boton.mouse_filter = Control.MOUSE_FILTER_PASS
	f.add_child(boton)
	return tarjeta


func _pedir_contrato(candidato: Dictionary) -> void:
	var texto := Idioma.t("Contratar a %s por %s.\nViajará desde la Tierra y llegará a la plataforma de aterrizaje en %d soles; su cuarto queda reservado.") % [
		Idioma.t(candidato["nombre"]), UI.dinero(candidato["coste"]), EstadoJuego.datos_balance.soles_viaje_colono]
	interfaz.confirmar(Idioma.t("Confirmar contratación"), texto, func() -> void:
		reclutando = false
		EstadoJuego.tripulacion.contratar(candidato))
