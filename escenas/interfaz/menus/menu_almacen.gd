# menu_almacen.gd
# Menú del almacén: reservas, racionamiento, cocina, pedidos a la Tierra y expansión del depósito.

class_name MenuAlmacen
extends MenuModulo
## HU-04: reservas, racionamiento, cocina y expansión del depósito.
## HU-09: pedidos de suministros a la Tierra, que tardan unos soles en llegar.
## Estilo de cabina del Módulo de Comando (ver Cabina):
##   [VIVERES 185/300 ▬▬▭] [MATERIALES 60/100] [PRESUPUESTO] [DEPOSITO 1/3 ■□□] [EXPANDIR DEPOSITO / costo]
##   RESERVAS                 3 COLONOS    COCINA [2]
##   ┃ COMIDA CRUDA   45 kg  [30 SOLES] ┃   ┃ RACION BASICA         [COCINAR] ┃
##   ┃ GASTO 3 KG/SOL · 1 POR COLONO    ┃   ┃ 2.6 KG COMIDA + 4 L AGUA > ...  ┃
##   RACIONAMIENTO                         PEDIDOS A LA TIERRA [3]      1 EN CAMINO
##   [ABUNDANTE][NORMAL][ESTRICTA]         ┃ VIVERES  [LLEGA EN 4 SOLES] [PEDIR $300 M] ┃

const DESCRIPCION_RACION := {
	Enums.Racion.ABUNDANTE: "+50 % de consumo. Mejora la productividad y acelera la recuperación.",
	Enums.Racion.NORMAL: "Consumo balanceado por colono.",
	Enums.Racion.ESTRICTA: "Mitad de consumo. Tras 3 soles seguidos: debilidad, enfermedad y peor productividad.",
}


func _init() -> void:
	con_cabecera = false     # sin título: como la sala de comandos


func construir() -> void:
	contenido.add_child(_barra_superior())
	var cuerpo := UI.fila(16)
	cuerpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	contenido.add_child(cuerpo)
	var izquierda := UI.columna(6)
	izquierda.add_child(_reservas())
	izquierda.add_child(_racionamiento())
	cuerpo.add_child(UI.expandir(izquierda))
	var derecha := UI.columna(6)
	derecha.add_child(_cocina())
	derecha.add_child(_pedidos())
	cuerpo.add_child(UI.expandir(derecha))


# --- Barra superior -------------------------------------------------------

## Víveres y materiales con su capacidad, presupuesto, nivel del depósito y
## el botón de expansión.
func _barra_superior() -> Control:
	var economia := EstadoJuego.economia
	var almacen := EstadoJuego.almacen
	var datos := EstadoJuego.datos_balance
	var f := UI.fila(6)
	f.add_child(Cabina.celda_metrica(Idioma.t("Víveres"), "%s / %s kg" % [UI.num(economia.viveres()), UI.num(almacen.capacidad())],
		economia.viveres(), almacen.capacidad()))
	var materiales: float = economia.recursos["materiales"]
	f.add_child(Cabina.celda_metrica(Idioma.t("Materiales"), "%s / %s" % [UI.num(materiales), UI.num(almacen.capacidad_materiales())],
		materiales, almacen.capacidad_materiales()))
	f.add_child(Cabina.celda_metrica(Idioma.t("Presupuesto"), UI.dinero(economia.recursos["presupuesto"])))
	var nivel: Array = Cabina.celda(130)
	nivel[1].add_child(Cabina.centrada(Idioma.t("DEPOSITO %d/%d") % [almacen.nivel, datos.nivel_almacen_max]))
	nivel[1].add_child(Cabina.marcas(almacen.nivel, datos.nivel_almacen_max))
	f.add_child(nivel[0])

	var titulo := Idioma.t("Depósito al máximo")
	var detalle := Idioma.t("Nivel %d: no se puede ampliar más") % almacen.nivel
	if almacen.nivel < datos.nivel_almacen_max:
		titulo = Idioma.t("Expandir depósito")
		detalle = Idioma.t("+%d kg  ·  %s  ·  %d mat.") % [int(datos.cap_almacen_por_nivel),
			UI.dinero(datos.expandir_almacen_dinero), datos.expandir_almacen_materiales]
	var puede := almacen.puede_expandir()
	var motivo := Idioma.t("No alcanzan el presupuesto o los materiales") \
		if not puede and almacen.nivel < datos.nivel_almacen_max else ""
	var boton := Cabina.boton_grande(titulo, detalle, _pedir_expansion, puede, motivo)
	f.add_child(UI.expandir(boton))
	return f


func _pedir_expansion() -> void:
	var datos := EstadoJuego.datos_balance
	var texto := Idioma.t("Ampliar el depósito por %s y %d materiales") % [UI.dinero(datos.expandir_almacen_dinero), datos.expandir_almacen_materiales]
	interfaz.confirmar(Idioma.t("Expandir depósito"), texto, EstadoJuego.almacen.expandir)


# --- Reservas -------------------------------------------------------------

func _reservas() -> Control:
	var economia := EstadoJuego.economia
	var recursos := economia.recursos
	var colonos := maxi(EstadoJuego.tripulacion.activos(), 1)
	var c := UI.columna(6)
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.add_child(Cabina.encabezado(Idioma.t("Reservas"), -1, Idioma.t("%d colono%s") % [colonos, "" if colonos == 1 else "s"]))
	var pantalla := Cabina.pantalla()
	c.add_child(pantalla)
	var lista := UI.columna(6)
	# Se comen primero las raciones preparadas y después la comida cruda.
	var hambre := economia.consumo("comida")
	var de_raciones := minf(hambre, recursos["raciones"])
	var soles_raciones: float = INF if hambre <= 0.0 else recursos["raciones"] / hambre
	lista.add_child(_linea(Idioma.t("Comida cruda"), recursos["comida"], hambre - de_raciones, colonos, economia.soles_restantes("comida"), "kg"))
	lista.add_child(_linea(Idioma.t("Raciones preparadas"), recursos["raciones"], de_raciones, colonos, soles_raciones, "kg"))
	lista.add_child(_linea(Idioma.t("Agua potable"), recursos["agua"], economia.consumo("agua"), colonos, economia.soles_restantes("agua"), "L"))
	var reciclada := economia.agua_reciclada()
	if reciclada > 0.0:
		lista.add_child(UI.parrafo(Idioma.t("El soporte vital recicla %s L de agua por sol (el 80 %% de lo que se usa).") % UI.num(reciclada), 12))
	lista.add_child(_linea(Idioma.t("Materiales"), recursos["materiales"], 0.0, colonos, INF))
	pantalla.add_child(vista_con_scroll(Cabina.con_margen_scroll(lista)))
	return c


## Tarjeta de reserva: nombre y gasto a la izquierda; cantidad y cuántos soles
## alcanza (verde de sobra, ámbar pocos, rojo casi agotado) a la derecha.
func _linea(nombre: String, valor: float, gasto: float, colonos: int, soles: float, unidad := "") -> Control:
	var u := " " + unidad if unidad != "" else ""
	var color := Cabina.VERDE
	var restante := Idioma.t("NO SE AGOTA")
	if not is_inf(soles):
		restante = Idioma.t("%s SOLES") % UI.num(soles)
		color = UI.CRITICO if soles < 3.0 else UI.ADVERTENCIA if soles < 10.0 else Cabina.VERDE
	if is_inf(soles) and gasto <= 0.0:
		color = UI.TEXTO_SUAVE
	var tarjeta := Cabina.tarjeta(color)
	var f := UI.fila(8)
	tarjeta.add_child(f)
	var c := UI.columna(4)
	f.add_child(UI.expandir(c))
	c.add_child(UI.etiqueta_pixel(Cabina.mayus(nombre), UI.T_TEXTO))
	var detalle := Idioma.t("GASTO %s%s/SOL") % [UI.num(gasto), Cabina.mayus(u)]
	if gasto > 0.0:
		detalle += Idioma.t(" · %s POR COLONO") % UI.num(gasto / colonos)
	c.add_child(UI.etiqueta_pixel(detalle, UI.T_DETALLE, UI.TEXTO_SUAVE))
	var cantidad := UI.etiqueta_pixel("%s%s" % [UI.num(valor), u], UI.T_TEXTO)
	cantidad.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	f.add_child(cantidad)
	var pildora := Cabina.pildora(restante, color, false)
	pildora.custom_minimum_size = Vector2(88, 0)
	(pildora.get_child(0) as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	f.add_child(pildora)
	return tarjeta


# --- Racionamiento --------------------------------------------------------

func _racionamiento() -> Control:
	var c := UI.columna(6)
	var racion := EstadoJuego.almacen.racion
	var aviso := ""
	if EstadoJuego.almacen.racion_debilita():
		aviso = Idioma.t("Tripulación debilitada")
	c.add_child(Cabina.encabezado(Idioma.t("Racionamiento"), -1, aviso))
	var f := UI.fila(6)
	c.add_child(f)
	for nivel: Enums.Racion in [Enums.Racion.ABUNDANTE, Enums.Racion.NORMAL, Enums.Racion.ESTRICTA]:
		var b := Cabina.boton_opcion(Idioma.t(Enums.NOMBRE_RACION[nivel]), EstadoJuego.almacen.fijar_racion.bind(nivel), racion == nivel)
		b.tooltip_text = DESCRIPCION_RACION[nivel]
		f.add_child(UI.expandir(b))
	var color := UI.ADVERTENCIA if racion == Enums.Racion.ESTRICTA else UI.TEXTO_SUAVE
	c.add_child(UI.parrafo(DESCRIPCION_RACION[racion], 12, color))
	return c


# --- Cocina ---------------------------------------------------------------

func _cocina() -> Control:
	var recetas: Array = EstadoJuego.datos_balance.recetas
	var c := UI.columna(6)
	var listas := recetas.filter(func(r: Dictionary) -> bool: return EstadoJuego.almacen.falta_para_receta(r) == "").size()
	c.add_child(Cabina.encabezado(Idioma.t("Cocina"), recetas.size(), Idioma.t("%d se pueden cocinar") % listas))
	# Sin scroll y sin estirarse: mide lo que sus recetas, y el resto del alto
	# queda para los pedidos.
	var pantalla := Cabina.pantalla()
	pantalla.size_flags_vertical = Control.SIZE_FILL
	c.add_child(pantalla)
	var lista := UI.columna(6)
	for receta: Dictionary in recetas:
		lista.add_child(_tarjeta_receta(receta))
	pantalla.add_child(lista)
	return c


## Receta compacta: nombre y botón arriba; ingredientes en píldoras grises y
## el resultado en verde, en una sola línea.
func _tarjeta_receta(receta: Dictionary) -> Control:
	var falta := EstadoJuego.almacen.falta_para_receta(receta)
	var tarjeta := Cabina.tarjeta(Cabina.VERDE if falta == "" else Cabina.REJILLA_BORDE, 5)
	if falta != "":
		tarjeta.modulate = Color(1, 1, 1, 0.7)
	var c := UI.columna(5)
	tarjeta.add_child(c)
	var cabecera := UI.fila(8)
	var nombre := Cabina.recortada(Cabina.mayus(receta["nombre"]))
	nombre.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cabecera.add_child(UI.expandir(nombre))
	var boton := Cabina.boton(Idioma.t("Cocinar") if falta == "" else falta,
		func() -> void: EstadoJuego.almacen.cocinar(receta), falta == "")
	boton.custom_minimum_size = Vector2(90, 0)
	cabecera.add_child(boton)
	c.add_child(cabecera)
	var ingredientes := HFlowContainer.new()
	ingredientes.add_theme_constant_override("h_separation", 6)
	ingredientes.add_theme_constant_override("v_separation", 4)
	ingredientes.add_child(Cabina.pildora(Idioma.t("%s KG COMIDA") % UI.num(receta["comida"]), UI.TEXTO_SUAVE, false))
	ingredientes.add_child(Cabina.pildora(Idioma.t("%s L AGUA") % UI.num(receta["agua"]), UI.TEXTO_SUAVE, false))
	var flecha := UI.etiqueta_pixel(">", UI.T_DETALLE, UI.TEXTO_SUAVE)
	flecha.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ingredientes.add_child(flecha)
	ingredientes.add_child(Cabina.pildora(Idioma.t("%s KG RACIONES") % UI.num(receta["raciones"]), Cabina.VERDE, false))
	c.add_child(ingredientes)
	return tarjeta


# --- Pedidos a la Tierra (HU-09) -----------------------------------------

func _pedidos() -> Control:
	var pedidos: Array = EstadoJuego.datos_balance.pedidos
	var envios := EstadoJuego.tierra.envios
	var c := UI.columna(6)
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.add_child(Cabina.encabezado(Idioma.t("Pedidos a la Tierra"), pedidos.size(),
		Idioma.t("%d en camino") % envios.size() if not envios.is_empty() else ""))
	var pantalla := Cabina.pantalla()
	c.add_child(pantalla)
	var lista := UI.columna(6)
	for pedido: Dictionary in pedidos:
		lista.add_child(_tarjeta_pedido(pedido))
	if not envios.is_empty():
		lista.add_child(Cabina.separador(Idioma.t("En camino"), envios.size()))
		for envio: Dictionary in envios:
			lista.add_child(_fila_envio(envio))
	pantalla.add_child(vista_con_scroll(Cabina.con_margen_scroll(lista)))
	return c


func _texto_contenido(contenido_envio: Dictionary) -> String:
	var partes := PackedStringArray()
	for recurso: String in contenido_envio:
		partes.append("%s %s" % [UI.cantidad(recurso, contenido_envio[recurso]), Idioma.t(Enums.NOMBRE_RECURSO[recurso])])
	return ", ".join(partes)


func _tarjeta_pedido(pedido: Dictionary) -> Control:
	var alcanza := EstadoJuego.economia.puede_pagar(pedido["dinero"], 0)
	var tarjeta := Cabina.tarjeta(UI.BIEN if alcanza else Cabina.REJILLA_BORDE)
	var f := UI.fila(10)
	tarjeta.add_child(f)
	var c := UI.columna(5)
	f.add_child(UI.expandir(c))
	c.add_child(Cabina.recortada(Cabina.mayus(pedido["nombre"])))
	c.add_child(UI.parrafo(_texto_contenido(pedido["contenido"]), 12, Cabina.VERDE))
	var boton := Cabina.boton(Idioma.t("Pedir %s") % UI.dinero(pedido["dinero"]), func() -> void:
		interfaz.confirmar(Idioma.t("Pedido a la Tierra"), Idioma.t("%s por %s.\nPor la latencia del viaje llegará en %d soles.") % [
			Idioma.t(pedido["nombre"]), UI.dinero(pedido["dinero"]), pedido["soles"]], EstadoJuego.tierra.pedir.bind(pedido)),
		alcanza)
	boton.custom_minimum_size = Vector2(110, 0)
	if not alcanza:
		boton.tooltip_text = Idioma.t("No alcanza el presupuesto")
		boton.mouse_filter = Control.MOUSE_FILTER_PASS
	var derecha := UI.columna(4)
	derecha.alignment = BoxContainer.ALIGNMENT_CENTER
	derecha.add_child(boton)
	derecha.add_child(Cabina.centrada(Idioma.t("LLEGA EN %s") % Cabina.mayus(UI.soles(pedido["soles"])), UI.TEXTO_SUAVE, UI.T_DETALLE))
	f.add_child(derecha)
	return tarjeta


## Envío en camino: nombre, contenido y soles que faltan.
func _fila_envio(envio: Dictionary) -> Control:
	var f := UI.fila(8)
	var nombre := Cabina.recortada("> " + Cabina.mayus(envio["nombre"]), UI.T_DETALLE)
	f.add_child(UI.expandir(nombre))
	if not envio["contenido"].is_empty():
		f.add_child(UI.etiqueta(_texto_contenido(envio["contenido"]), 11, UI.TEXTO_SUAVE))
	f.add_child(Cabina.pildora(Cabina.mayus(UI.soles(envio["soles"])), UI.ADVERTENCIA, false))
	return f
