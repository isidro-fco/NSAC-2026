# menu_almacen.gd
# Menú del almacén: reservas, racionamiento, cocina, pedidos a la Tierra y expansión del depósito.

class_name MenuAlmacen
extends MenuModulo
## HU-04: reservas, racionamiento, cocina y expansión del depósito.
## HU-09: pedidos de suministros a la Tierra, que tardan unos soles en llegar.
## Diseño: docs/diseno/Almacen y cocina.pdf
##   Víveres: 42.5 / 100    Materiales: 60 / 100    Presupuesto: $1250
##   Reservas                         Cocina
##   ╭ Comida cruda: 18 ───────╮      ╭ Ración básica ──── [Cocinar] ╮
##   ╰ Gasto: 3/Sol ...        ╯      ╰ 2 comida + 1 agua → 3 ...    ╯
##   Racionamiento                    Pedidos a la Tierra
##   (Abundante)(Normal)(Estricta)    ╭ Víveres ─────── [Pedir ($300)] ╮
##   ╭──── Expandir Depósito: nivel 1 → 2 (+50 capacidad) $250 + 40 materiales ────╮

const DESCRIPCION_RACION := {
	Enums.Racion.ABUNDANTE: "+50 % de consumo. Mejora la productividad y acelera la recuperación.",
	Enums.Racion.NORMAL: "Consumo balanceado por colono.",
	Enums.Racion.ESTRICTA: "Mitad de consumo. Tras 3 soles seguidos: debilidad, enfermedad y peor productividad.",
}


func construir() -> void:
	var economia := EstadoJuego.economia
	var cap := EstadoJuego.almacen.capacidad()
	var resumen := "Víveres: %s / %s    Materiales: %s / %s    Presupuesto: $%s" % [
		UI.num(economia.viveres()), UI.num(cap), UI.num(economia.recursos["materiales"]), UI.num(cap),
		UI.num(economia.recursos["presupuesto"])]
	contenido.add_child(UI.etiqueta_pixel(resumen, UI.T_DETALLE))

	var cuerpo := UI.fila(16)
	cuerpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	contenido.add_child(cuerpo)
	var izquierda := UI.columna(8)
	UI.expandir(izquierda)
	cuerpo.add_child(izquierda)
	izquierda.add_child(_reservas())
	izquierda.add_child(_racionamiento())
	var derecha := UI.columna(8)
	derecha.add_child(_cocina())
	derecha.add_child(_pedidos())
	cuerpo.add_child(UI.expandir(derecha))
	contenido.add_child(_expansion())


## Tarjeta con título amarillo y detalle; `accion` (opcional) va a la derecha.
func _tarjeta(titulo: String, detalle: String, accion: Control = null) -> Control:
	var tarjeta := UI.tarjeta()
	var f := UI.fila(10)
	tarjeta.add_child(f)
	f.add_child(UI.expandir(UI.cabecera_tarjeta(titulo, detalle)))
	if accion != null:
		f.add_child(accion)
	return tarjeta


# --- Reservas -------------------------------------------------------------

func _reservas() -> Control:
	var c := UI.columna(6)
	c.add_child(UI.seccion("Reservas"))
	var economia := EstadoJuego.economia
	var recursos := economia.recursos
	# Se comen primero las raciones preparadas y después la comida cruda.
	var hambre := economia.consumo("comida")
	var de_raciones := minf(hambre, recursos["raciones"])
	var soles_raciones: float = INF if hambre <= 0.0 else recursos["raciones"] / hambre
	var colonos := maxi(EstadoJuego.tripulacion.activos(), 1)
	c.add_child(_linea("Comida cruda", recursos["comida"], hambre - de_raciones, colonos, economia.soles_restantes("comida")))
	c.add_child(_linea("Raciones preparadas", recursos["raciones"], de_raciones, colonos, soles_raciones))
	c.add_child(_linea("Agua potable", recursos["agua"], economia.consumo("agua"), colonos, economia.soles_restantes("agua")))
	c.add_child(_linea("Materiales", recursos["materiales"], 0.0, colonos, INF))
	return c


func _linea(nombre: String, valor: float, gasto: float, colonos: int, soles: float) -> Control:
	var restante := "no se agota" if is_inf(soles) else "%s soles" % UI.num(soles)
	var detalle := "Gasto: %s/Sol (%s por colono)  %s" % [UI.num(gasto), UI.num(gasto / colonos), restante]
	return _tarjeta("%s: %s" % [nombre, UI.num(valor)], detalle)


# --- Racionamiento --------------------------------------------------------

func _racionamiento() -> Control:
	var c := UI.columna(6)
	c.add_child(UI.seccion("Racionamiento"))
	var f := UI.fila(10)
	c.add_child(f)
	for nivel: Enums.Racion in [Enums.Racion.ABUNDANTE, Enums.Racion.NORMAL, Enums.Racion.ESTRICTA]:
		var b := UI.boton(Enums.NOMBRE_RACION[nivel], EstadoJuego.almacen.fijar_racion.bind(nivel), true,
			UI.PRIMARIO if EstadoJuego.almacen.racion == nivel else "")
		b.custom_minimum_size = Vector2(0, 42)
		f.add_child(UI.expandir(b))
	c.add_child(UI.parrafo(DESCRIPCION_RACION[EstadoJuego.almacen.racion], 12))
	return c


# --- Cocina ---------------------------------------------------------------

func _cocina() -> Control:
	var c := UI.columna(6)
	c.add_child(UI.seccion("Cocina"))
	for receta: Dictionary in EstadoJuego.datos_balance.recetas:
		var detalle := "%s comida + %s agua -> %s raciones" % [
			UI.num(receta["comida"]), UI.num(receta["agua"]), UI.num(receta["raciones"])]
		var falta := EstadoJuego.almacen.falta_para_receta(receta)
		var boton := UI.boton_accion("Cocinar" if falta == "" else falta,
			func() -> void: EstadoJuego.almacen.cocinar(receta), falta == "")
		c.add_child(_tarjeta(receta["nombre"], detalle, boton))
	return c


# --- Pedidos a la Tierra (HU-09) -----------------------------------------

func _pedidos() -> Control:
	var c := UI.columna(6)
	c.add_child(UI.seccion("Pedidos a la Tierra"))
	for pedido: Dictionary in EstadoJuego.datos_balance.pedidos:
		var contenido_pedido := PackedStringArray()
		for recurso: String in pedido["contenido"]:
			contenido_pedido.append("%s %s" % [UI.num(pedido["contenido"][recurso]), Enums.NOMBRE_RECURSO[recurso]])
		var detalle := "%s -> llega en %d soles" % [", ".join(contenido_pedido), pedido["soles"]]
		var boton := UI.boton_accion("Pedir ($%d)" % pedido["dinero"], func() -> void:
			interfaz.confirmar("Pedido a la Tierra", "%s por $%d.\nPor la latencia del viaje llegará en %d soles." % [
				pedido["nombre"], pedido["dinero"], pedido["soles"]], EstadoJuego.tierra.pedir.bind(pedido)),
			EstadoJuego.economia.puede_pagar(pedido["dinero"], 0))
		c.add_child(_tarjeta(pedido["nombre"], detalle, boton))
	return c


# --- Expansión ------------------------------------------------------------

func _expansion() -> Control:
	var datos := EstadoJuego.datos_balance
	var nivel := EstadoJuego.almacen.nivel
	var texto := "Expandir Depósito: nivel %d -> %d (+%d capacidad) $%d + %d materiales" % [
		nivel, nivel + 1, int(datos.cap_almacen_por_nivel), datos.expandir_almacen_dinero, datos.expandir_almacen_materiales]
	if nivel >= datos.nivel_almacen_max:
		texto = "Límite alcanzado (nivel %d)" % nivel
	var b := UI.boton(texto, _pedir_expansion, EstadoJuego.almacen.puede_expandir())
	b.custom_minimum_size = Vector2(0, 34)
	return b


func _pedir_expansion() -> void:
	var datos := EstadoJuego.datos_balance
	var texto := "Ampliar el depósito por $%d y %d materiales" % [datos.expandir_almacen_dinero, datos.expandir_almacen_materiales]
	interfaz.confirmar("Expandir depósito", texto, EstadoJuego.almacen.expandir)
