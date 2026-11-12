class_name Mapa
extends Node2D
## Mapa de la colonia: suelo, módulos, obstáculos, colonos y los modos de
## construcción/demolición (HU-05). No conoce la interfaz: le habla por señales.

signal modo_cambiado(modo: Enums.ModoMapa)
signal colono_clicado(colono: Colono)
signal modulo_clicado(id: String)
## `filas` son las líneas [recurso, cambio, quedará] de la tabla del aviso (docs/diseno/aviso.png).
signal confirmacion_pedida(titulo: String, texto: String, accion: Callable, filas: Array,
		texto_confirmar: String, peligro: bool)
signal aviso_pedido(texto: String)
## Texto del coste al señalar algo en modo demolición; "" para ocultarlo.
signal etiqueta_demolicion(texto: String)

const TEX_SUELO: Array[Texture2D] = [
	preload("res://recursos/sprites/suelo/suelo1.png"), preload("res://recursos/sprites/suelo/suelo2.png"),
]
const MODULOS_CON_MENU := ["comando", "descanso", "almacen", "refugio"]
const SIN_ORIGEN := Vector2i(-1000, -1000)

@export_range(0.0, 1.0) var densidad_obstaculos := 0.15
@export_range(0.0, 1.0) var fraccion_crater_grande := 0.1
@export var semilla := 0                     # 0 = aleatoria

var cuadricula := GestorCuadricula.new()
var rutas := BuscadorRutas.new()
var rng := RandomNumberGenerator.new()
var suelo := []                   # suelo[y][x] -> textura

var modo: Enums.ModoMapa = Enums.ModoMapa.NORMAL
var modulo_elegido: DatosModulo
var objetivo_demoler: Node2D
var modal_abierto := false:       # menú o diálogo sobre el mapa
	set(valor):
		modal_abierto = valor
		# Al cerrarse el diálogo de confirmación, la vista previa vuelve a seguir al ratón.
		if not valor and origen_fijado != SIN_ORIGEN:
			origen_fijado = SIN_ORIGEN
			capa.queue_redraw()
## Casilla elegida con el clic mientras se espera la confirmación; así la vista
## previa se queda quieta en vez de seguir al ratón.
var origen_fijado := SIN_ORIGEN

@onready var contenedor_obstaculos: Node2D = $Obstaculos
@onready var contenedor_modulos: Node2D = $Modulos
@onready var capa: Node2D = $Capa                  # cuadrícula y previsualización
@onready var contenedor_colonos: Node2D = $Colonos


func _ready() -> void:
	capa.draw.connect(_dibujar_capa)
	if semilla == 0:
		rng.randomize()
	else:
		rng.seed = semilla
	cuadricula.reiniciar()
	for y in GestorCuadricula.ALTO:
		suelo.append(range(GestorCuadricula.ANCHO).map(func(_x: int) -> Texture2D:
			return TEX_SUELO[rng.randi_range(0, TEX_SUELO.size() - 1)]))
	GeneradorMapa.generar(self, rng)
	rutas.actualizar(cuadricula)
	for c: DatosColono in EstadoJuego.tripulacion.colonos:
		_crear_colono(c, celda_en_modulo("descanso"))
	EstadoJuego.colono_agregado.connect(_crear_colono)
	EstadoJuego.colono_retirado.connect(func(datos: DatosColono) -> void:
		for colono: Colono in contenedor_colonos.get_children():
			if colono.datos == datos:
				colono.queue_free())


func agregar_modulo(id: String, origen: Vector2i) -> void:
	var modulo := Modulo.new(origen, DatosModulo.obtener(id))
	contenedor_modulos.add_child(modulo)
	cuadricula.ocupar_modulo(modulo)
	rutas.actualizar(cuadricula)          # antes de avisar: los colonos reaccionan al aviso
	EstadoJuego.economia.registrar_modulo(id)


func agregar_obstaculo(origen: Vector2i, tam: Vector2i, textura: Texture2D) -> void:
	var obstaculo := Obstaculo.new(origen, tam, textura)
	contenedor_obstaculos.add_child(obstaculo)
	cuadricula.ocupar_obstaculo(obstaculo)


# --- Consultas (las usan los colonos) -------------------------------------

## Casilla al azar dentro del módulo `id` (o del de comando si no existe).
func celda_en_modulo(id: String) -> Vector2i:
	var modulos := modulos_de(id)
	return celda_en((contenedor_modulos.get_child(0) if modulos.is_empty() else modulos[0]) as Modulo)


func celda_en(modulo: Modulo) -> Vector2i:
	var tam := modulo.tam_celdas()
	return modulo.origen + Vector2i(rng.randi_range(0, tam.x - 1), rng.randi_range(0, tam.y - 1))


func modulos_de(id: String) -> Array[Node]:
	return contenedor_modulos.get_children().filter(func(m: Modulo) -> bool: return m.datos.id == id)


## HU-08: refugio al que debe ir el colono durante una tormenta solar, o null.
## Cada refugio acoge a `capacidad_refugio` colonos, por orden de la tripulación.
func refugio_para(datos: DatosColono) -> Modulo:
	if not EstadoJuego.eventos.tormenta_activa():
		return null
	# Solo los refugios a los que se puede llegar andando desde la base.
	var comando := celda_en_modulo("comando")
	var refugios := modulos_de("refugio").filter(
		func(r: Modulo) -> bool: return not rutas.ruta(comando, r.origen).is_empty())
	var plazas: int = EstadoJuego.datos_balance.capacidad_refugio
	var i := EstadoJuego.tripulacion.colonos.find(datos)
	return refugios[i / plazas] as Modulo if i >= 0 and i < refugios.size() * plazas else null


## "interior", "exterior" o "refugio" según la casilla.
func ubicacion(c: Vector2i) -> String:
	if not cuadricula.es_estructura(c):
		return "exterior"
	return "refugio" if cuadricula.celdas_modulo[c].datos.id == "refugio" else "interior"


func celda_exterior_aleatoria() -> Vector2i:
	var opciones := rutas.casillas_exteriores(cuadricula)
	if opciones.is_empty():
		return celda_en_modulo("comando")
	return opciones[rng.randi_range(0, opciones.size() - 1)]


## Los que llegan de la Tierra aparecen en la plataforma de aterrizaje.
func _crear_colono(datos: DatosColono, celda := SIN_ORIGEN) -> void:
	var colono := Colono.new()
	contenedor_colonos.add_child(colono)
	colono.configurar(datos, self, celda_en_modulo("plataforma") if celda == SIN_ORIGEN else celda)


func _mapa_modificado() -> void:
	rutas.actualizar(cuadricula)
	for colono: Colono in contenedor_colonos.get_children():
		colono.replanificar()
	capa.queue_redraw()


# --- Modos de construcción (HU-05) ----------------------------------------

func cambiar_modo(nuevo: Enums.ModoMapa) -> void:
	modo = nuevo
	origen_fijado = SIN_ORIGEN
	if modo != Enums.ModoMapa.COLOCANDO:
		modulo_elegido = null
	if modo != Enums.ModoMapa.DEMOLICION:
		objetivo_demoler = null
		etiqueta_demolicion.emit("")
	capa.queue_redraw()
	modo_cambiado.emit(modo)


func alternar_construccion() -> void:
	cambiar_modo(Enums.ModoMapa.CATALOGO if modo == Enums.ModoMapa.NORMAL else Enums.ModoMapa.NORMAL)


func elegir_modulo(id: String) -> void:
	modulo_elegido = DatosModulo.obtener(id)
	cambiar_modo(Enums.ModoMapa.COLOCANDO)


## Responde a Escape cuando no hay ningún menú abierto.
func cancelar_modo() -> void:
	cambiar_modo(Enums.ModoMapa.CATALOGO if modo == Enums.ModoMapa.COLOCANDO else Enums.ModoMapa.NORMAL)


func origen_preview() -> Vector2i:
	if origen_fijado != SIN_ORIGEN:
		return origen_fijado
	var celda := GestorCuadricula.celda_desde_pixel(get_global_mouse_position())
	return celda - (modulo_elegido.tam - Vector2i.ONE) / 2


func _se_puede_construir(d: DatosModulo, origen: Vector2i) -> bool:
	return cuadricula.puede_colocar(d, origen) and EstadoJuego.economia.puede_pagar(d.dinero, d.materiales)


func _pedir_construccion(origen: Vector2i) -> void:
	var d := modulo_elegido
	if not _se_puede_construir(d, origen):
		return
	origen_fijado = origen
	capa.queue_redraw()
	var filas := [
		_fila_recurso("Presupuesto", "presupuesto", -d.dinero),
		_fila_recurso("Materiales", "materiales", -d.materiales),
	]
	confirmacion_pedida.emit("¿Construir %s?" % d.nombre, "Ocupa %dx%d casillas" % [d.tam.x, d.tam.y],
		construir.bind(d, origen), filas, "Construir", false)


func construir(d: DatosModulo, origen: Vector2i) -> void:
	if not _se_puede_construir(d, origen):
		return
	EstadoJuego.economia.pagar(d.dinero, d.materiales)
	agregar_modulo(d.id, origen)
	EstadoJuego.modulos_construidos += 1
	if not d.es_pasillo():
		EstadoJuego.registrar("Acción", "Construido: %s" % d.nombre, false)
	_mapa_modificado()
	# Los pasillos se trazan por tramos: se sigue colocando mientras alcance.
	if modo == Enums.ModoMapa.COLOCANDO \
			and (not d.es_pasillo() or not EstadoJuego.economia.puede_pagar(d.dinero, d.materiales)):
		cambiar_modo(Enums.ModoMapa.CATALOGO)


func _pedir_demolicion(objetivo: Node2D) -> void:
	var coste: int = objetivo.coste_demoler()
	if not EstadoJuego.economia.puede_pagar(coste, 0):
		aviso_pedido.emit("No hay dinero para la demolición")
		return
	var filas := [_fila_recurso("Costo del trabajo", "presupuesto", -coste)]
	if objetivo.materiales_al_demoler() > 0:
		filas.append(_fila_recurso("Materiales obtenidos", "materiales", objetivo.materiales_al_demoler()))
	var titulo := "¿Demoler este módulo?"
	if objetivo is Obstaculo:
		titulo = "¿Allanar este cráter?" if objetivo.es_crater() else "¿Excavar esta roca?"
	confirmacion_pedida.emit(titulo, objetivo.nombre(), demoler.bind(objetivo), filas, "Demoler", true)


## Fila de la tabla del aviso: "Costo del trabajo | -$40 | $1,000 a $960".
func _fila_recurso(nombre: String, recurso: String, cambio: float) -> Array:
	var antes := EstadoJuego.economia.valor(recurso)
	if recurso == "presupuesto":
		var signo := "+" if cambio >= 0.0 else "-"
		return [nombre, signo + UI.dinero(absf(cambio)), "%s a %s" % [UI.dinero(antes), UI.dinero(antes + cambio)]]
	return [nombre, UI.con_signo(cambio), "%s a %s" % [UI.num(antes), UI.num(antes + cambio)]]


func demoler(objetivo: Node2D) -> void:
	if not is_instance_valid(objetivo) or not EstadoJuego.economia.puede_pagar(objetivo.coste_demoler(), 0):
		return
	EstadoJuego.economia.pagar(objetivo.coste_demoler(), 0)
	EstadoJuego.registrar("Acción", "Demolido: %s" % objetivo.nombre(), false)
	cuadricula.liberar(objetivo.origen, objetivo.tam_celdas())
	if objetivo is Modulo:
		EstadoJuego.economia.quitar_modulo(objetivo.datos.id)
	else:
		EstadoJuego.economia.sumar("materiales", objetivo.materiales_al_demoler())
		EstadoJuego.estado_cambiado.emit()
	objetivo.get_parent().remove_child(objetivo)
	objetivo.queue_free()
	objetivo_demoler = null
	etiqueta_demolicion.emit("")
	_mapa_modificado()


# --- Entrada --------------------------------------------------------------

func _process(_delta: float) -> void:
	if modo == Enums.ModoMapa.COLOCANDO:
		capa.queue_redraw()
	elif modo == Enums.ModoMapa.DEMOLICION:
		_actualizar_objetivo_demoler()


func _unhandled_input(event: InputEvent) -> void:
	if modal_abierto or event is not InputEventMouseButton or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_RIGHT and modo == Enums.ModoMapa.COLOCANDO:
		cambiar_modo(Enums.ModoMapa.CATALOGO)
	elif event.button_index == MOUSE_BUTTON_LEFT:
		_clic_izquierdo()


func _clic_izquierdo() -> void:
	var punto := get_global_mouse_position()
	var c := GestorCuadricula.celda_desde_pixel(punto)
	match modo:
		Enums.ModoMapa.COLOCANDO:
			_pedir_construccion(origen_preview())
		Enums.ModoMapa.DEMOLICION:
			if GestorCuadricula.dentro_del_mapa(c) and cuadricula.objetivo_en(c) != null:
				_pedir_demolicion(cuadricula.objetivo_en(c))
		Enums.ModoMapa.NORMAL:
			for colono: Colono in contenedor_colonos.get_children():
				if colono.position.distance_to(punto) <= Colono.RADIO_CLIC:
					colono_clicado.emit(colono)
					return
			if cuadricula.celdas_modulo.has(c) and cuadricula.celdas_modulo[c].datos.id in MODULOS_CON_MENU:
				modulo_clicado.emit(cuadricula.celdas_modulo[c].datos.id)


func _actualizar_objetivo_demoler() -> void:
	var objetivo: Node2D = null
	var c := GestorCuadricula.celda_desde_pixel(get_global_mouse_position())
	if get_viewport().gui_get_hovered_control() == null and not modal_abierto and GestorCuadricula.dentro_del_mapa(c):
		objetivo = cuadricula.objetivo_en(c)
	if objetivo == null:
		etiqueta_demolicion.emit("")
	else:
		var extra := ""
		if objetivo.materiales_al_demoler() > 0:
			extra = "  +%d mat." % objetivo.materiales_al_demoler()
		etiqueta_demolicion.emit("Demoler: $%d%s" % [objetivo.coste_demoler(), extra])
	if objetivo != objetivo_demoler:
		objetivo_demoler = objetivo
		capa.queue_redraw()


# --- Render top-down ------------------------------------------------------

func _draw() -> void:
	for y in GestorCuadricula.ALTO:
		for x in GestorCuadricula.ANCHO:
			draw_texture(suelo[y][x], Vector2(x, y) * GestorCuadricula.TAM_CELDA)


func _dibujar_capa() -> void:
	if modo == Enums.ModoMapa.NORMAL:
		return
	var lado := GestorCuadricula.TAM_CELDA
	for y in GestorCuadricula.ALTO:
		for x in GestorCuadricula.ANCHO:
			var c := Vector2i(x, y)
			var rect := Rect2(Vector2(c) * lado, Vector2.ONE * lado)
			match cuadricula.estado(c):
				Enums.EstadoCasilla.OCUPADA:
					capa.draw_rect(rect, Color(UI.BIEN, 0.28))
				Enums.EstadoCasilla.BLOQUEADA:
					capa.draw_rect(rect, Color(UI.FONDO, 0.55))
			capa.draw_rect(rect, Color(1, 1, 1, 0.22), false, 1.0)
	if modo == Enums.ModoMapa.COLOCANDO:
		var d := modulo_elegido
		var origen := origen_preview()
		var tinte := Color(UI.BIEN, 0.55) if cuadricula.puede_colocar(d, origen) else Color(UI.CRITICO, 0.55)
		var rect := Rect2(Vector2(origen) * lado, Vector2(d.tam) * lado)
		capa.draw_rect(rect, d.color * Color(1, 1, 1, 0.45))
		capa.draw_rect(rect, tinte)
		capa.draw_rect(rect, Color(tinte, 1.0), false, 2.0)
	elif modo == Enums.ModoMapa.DEMOLICION and is_instance_valid(objetivo_demoler):
		var rect := Rect2(objetivo_demoler.position, Vector2(objetivo_demoler.tam_celdas()) * lado)
		capa.draw_rect(rect, UI.CRITICO, false, 3.0)
