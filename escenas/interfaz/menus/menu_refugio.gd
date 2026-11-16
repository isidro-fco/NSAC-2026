# menu_refugio.gd
# Menú del refugio blindado: colonos resguardados y capacidad durante una tormenta solar.

class_name MenuRefugio
extends MenuModulo
## HU-08: colonos dentro de los refugios blindados y su capacidad (ej. 2 / 5).
## Estilo de cabina del Módulo de Comando (ver Cabina):
##   [TORMENTA SOLAR / QUEDAN 2 SOLES] [OCUPACION 2/5 ■■□□□] (explicación)
##   REFUGIADOS [2]                              3 PLAZAS LIBRES
##   ┌ ▣ ELENA ... ┐ ┌ ▣ TOMAS ... ┐
##   ── FUERA DEL REFUGIO (1) ──          (solo durante la tormenta)

const COLUMNAS := 2

var refugiados: Array[DatosColono] = []


func _init() -> void:
	con_cabecera = false     # sin título: como la sala de comandos


func construir() -> void:
	var plazas: int = EstadoJuego.datos_balance.capacidad_refugio * interfaz.mapa.modulos_de("refugio").size()
	var eventos := EstadoJuego.eventos
	var tormenta := eventos.tormenta_activa()
	var f := UI.fila(6)
	var estado: Array = Cabina.celda(220)
	estado[1].add_child(Cabina.centrada(Idioma.t("TORMENTA SOLAR") if tormenta else Idioma.t("SIN TORMENTA"),
		Cabina.ROJO if tormenta else Cabina.VERDE))
	estado[1].add_child(Cabina.centrada(Idioma.t("QUEDAN %s") % Cabina.mayus(UI.soles(eventos.tormenta_soles)) if tormenta
		else Idioma.t("REFUGIO EN RESERVA"), UI.TEXTO_SUAVE, UI.T_DETALLE))
	f.add_child(estado[0])
	var ocupacion: Array = Cabina.celda(180)
	ocupacion[1].add_child(Cabina.centrada(Idioma.t("OCUPACION %d/%d") % [refugiados.size(), plazas]))
	if plazas > 0:
		ocupacion[1].add_child(Cabina.marcas(refugiados.size(), plazas, Cabina.VERDE, clampi(140 / plazas, 4, 14)))
	else:
		ocupacion[1].add_child(Cabina.centrada(Idioma.t("SIN REFUGIOS CONSTRUIDOS"), UI.CRITICO, UI.T_DETALLE))
	f.add_child(ocupacion[0])
	var texto := Idioma.t("Tormenta solar en curso: la tripulación se refugia aquí para no recibir radiación.") if tormenta \
		else Idioma.t("Sin tormenta solar: el refugio está en reserva. Cuando llegue una, la tripulación vendrá aquí.")
	var explicacion: Array = Cabina.celda()
	explicacion[1].add_child(UI.parrafo(texto, 12))
	f.add_child(UI.expandir(explicacion[0]))
	contenido.add_child(f)

	var libres := maxi(plazas - refugiados.size(), 0)
	contenido.add_child(Cabina.encabezado(Idioma.t("Refugiados"), refugiados.size(),
		Idioma.t("%d plaza libre" if libres == 1 else "%d plazas libres") % libres))
	var pantalla := Cabina.pantalla()
	contenido.add_child(pantalla)
	var lista := UI.columna(6)
	lista.add_child(_rejilla(refugiados))
	if refugiados.is_empty():
		lista.add_child(Cabina.vacio(Idioma.t("No hay nadie dentro del refugio.")))
	if tormenta:
		var fuera := EstadoJuego.tripulacion.colonos.filter(func(c: DatosColono) -> bool: return not refugiados.has(c))
		if not fuera.is_empty():
			lista.add_child(Cabina.separador(Idioma.t("Fuera del refugio"), fuera.size()))
			lista.add_child(_rejilla(fuera))
	pantalla.add_child(vista_con_scroll(Cabina.con_margen_scroll(lista)))


func _rejilla(colonos: Array) -> GridContainer:
	var rejilla := GridContainer.new()
	rejilla.columns = COLUMNAS
	rejilla.add_theme_constant_override("h_separation", 8)
	rejilla.add_theme_constant_override("v_separation", 6)
	for c: DatosColono in colonos:
		rejilla.add_child(UI.expandir(Cabina.ficha_colono(c)))
	return rejilla


## Los colonos entran y salen andando: se rehace la lista cuando cambia quién está dentro.
func _process(_delta: float) -> void:
	var dentro := EstadoJuego.tripulacion.colonos.filter(
		func(c: DatosColono) -> bool: return c.ubicacion == "refugio")
	if dentro != refugiados:
		refugiados.assign(dentro)
		_pedir_reconstruccion()
