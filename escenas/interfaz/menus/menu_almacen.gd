class_name MenuAlmacen
extends Control
## HU-04: reservas, racionamiento, cocina y expansión del depósito.

var interfaz                  # escena Juego: abre diálogos y cierra el menú
var contenido: VBoxContainer
var scrolls: Array[ScrollContainer] = []
var reconstruccion_pendiente := false

const DESCRIPCION_RACION := {
	Enums.Racion.ABUNDANTE: "+50 % de consumo. Mejora la productividad y acelera la recuperación.",
	Enums.Racion.NORMAL: "Consumo balanceado por colono.",
	Enums.Racion.ESTRICTA: "Mitad de consumo. Tras 3 soles seguidos: debilidad, enfermedad y peor productividad.",
}


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


## Escape: devuelve true si cerró una subvista en lugar del menú entero.
func atras() -> bool:
	return false


func construir() -> void:
	var cap := EstadoJuego.capacidad_almacen()
	var resumen := "Víveres: %s/%s    Materiales: %s/%s    Presupuesto: $%s" % [
		Hud.num(EstadoJuego.viveres()), Hud.num(cap), Hud.num(EstadoJuego.recursos["materiales"]), Hud.num(cap),
		Hud.num(EstadoJuego.recursos["presupuesto"])]
	contenido.add_child(Hud.etiqueta(resumen, 15))

	var cuerpo := Hud.fila(12)
	cuerpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	contenido.add_child(cuerpo)
	var izquierda := Hud.columna(10)
	Hud.expandir(izquierda)
	cuerpo.add_child(izquierda)
	izquierda.add_child(_reservas())
	izquierda.add_child(_racionamiento())
	cuerpo.add_child(Hud.expandir(_cocina()))
	contenido.add_child(_expansion())


# --- Reservas -------------------------------------------------------------

func _reservas() -> Control:
	var c := Hud.columna(4)
	c.add_child(Hud.etiqueta("Reservas", 16))
	var hambre := EstadoJuego.consumo("comida")
	var de_raciones := minf(hambre, EstadoJuego.recursos["raciones"])
	var colonos := maxi(EstadoJuego.colonos_activos(), 1)
	c.add_child(_linea("Comida cruda", EstadoJuego.recursos["comida"], hambre - de_raciones, colonos, EstadoJuego.soles_restantes("comida")))
	c.add_child(_linea("Raciones preparadas", EstadoJuego.recursos["raciones"], de_raciones, colonos, _soles_raciones(hambre)))
	c.add_child(_linea("Agua potable", EstadoJuego.recursos["agua"], EstadoJuego.consumo("agua"), colonos, EstadoJuego.soles_restantes("agua")))
	c.add_child(_linea("Materiales", EstadoJuego.recursos["materiales"], 0.0, colonos, INF))
	return c


func _soles_raciones(hambre: float) -> float:
	return INF if hambre <= 0.0 else EstadoJuego.recursos["raciones"] / hambre


func _linea(nombre: String, valor: float, gasto: float, colonos: int, soles: float) -> Control:
	var tarjeta := Hud.tarjeta()
	var c := Hud.columna(1)
	tarjeta.add_child(c)
	c.add_child(Hud.etiqueta("%s: %s" % [nombre, Hud.num(valor)]))
	var restante := "no se agota" if is_inf(soles) else "%s soles" % Hud.num(soles)
	var detalle := "Gasto: %s/sol (%s por colono) · %s" % [Hud.num(gasto), Hud.num(gasto / colonos), restante]
	c.add_child(Hud.etiqueta(detalle, 12, Hud.TEXTO_SUAVE))
	return tarjeta


# --- Racionamiento --------------------------------------------------------

func _racionamiento() -> Control:
	var c := Hud.columna(4)
	c.add_child(Hud.etiqueta("Racionamiento", 16))
	var f := Hud.fila(6)
	c.add_child(f)
	for nivel: Enums.Racion in [Enums.Racion.ABUNDANTE, Enums.Racion.NORMAL, Enums.Racion.ESTRICTA]:
		var nombre: String = Enums.NOMBRE_RACION[nivel]
		var activo: bool = EstadoJuego.racion == nivel
		var b := Hud.boton(nombre, EstadoJuego.fijar_racion.bind(nivel), true, Hud.PRIMARIO if activo else "")
		f.add_child(Hud.expandir(b))
	c.add_child(Hud.parrafo(DESCRIPCION_RACION[EstadoJuego.racion]))
	return c


# --- Cocina ---------------------------------------------------------------

func _cocina() -> Control:
	var c := Hud.columna(6)
	c.add_child(Hud.etiqueta("Cocina", 16))
	for receta: Dictionary in EstadoJuego.datos_balance.recetas:
		var tarjeta := Hud.tarjeta()
		var f := Hud.fila(10)
		tarjeta.add_child(f)
		var datos := Hud.columna(2)
		f.add_child(Hud.expandir(datos))
		datos.add_child(Hud.etiqueta(receta["nombre"]))
		var detalle := "%s comida + %s agua → %s raciones" % [
			Hud.num(receta["comida"]), Hud.num(receta["agua"]), Hud.num(receta["raciones"])]
		datos.add_child(Hud.etiqueta(detalle, 12, Hud.TEXTO_SUAVE))
		var falta := EstadoJuego.falta_para_receta(receta)
		var texto := "Cocinar" if falta == "" else falta
		f.add_child(Hud.boton(texto, func() -> void: EstadoJuego.cocinar(receta), falta == ""))
		c.add_child(tarjeta)
	return c


# --- Expansión ------------------------------------------------------------

func _expansion() -> Control:
	var nivel := EstadoJuego.nivel_almacen
	var texto := "Expandir Depósito: nivel %d → %d (+%d capacidad) · $%d + %d materiales" % [
		nivel, nivel + 1, int(EstadoJuego.datos_balance.cap_almacen_por_nivel),
		EstadoJuego.datos_balance.expandir_almacen_dinero, EstadoJuego.datos_balance.expandir_almacen_materiales]
	if nivel >= EstadoJuego.datos_balance.nivel_almacen_max:
		texto = "Límite alcanzado (nivel %d)" % nivel
	return Hud.boton(texto, _pedir_expansion, EstadoJuego.puede_expandir_almacen())


func _pedir_expansion() -> void:
	var texto := "Ampliar el depósito por $%d y %d materiales" % [
		EstadoJuego.datos_balance.expandir_almacen_dinero, EstadoJuego.datos_balance.expandir_almacen_materiales]
	interfaz.confirmar("Expandir depósito", texto, EstadoJuego.expandir_almacen)
