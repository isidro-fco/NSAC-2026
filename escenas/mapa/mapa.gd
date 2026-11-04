class_name Mapa
extends Node2D
## Mapa de la colonia: suelo, módulos, obstáculos, colonos y los modos de
## construcción/demolición (HU-05). No conoce la interfaz: le habla por señales.

signal modo_cambiado(modo: Enums.ModoMapa)
signal colono_clicado(colono: Colono)
signal modulo_clicado(id: String)
signal confirmacion_pedida(titulo: String, texto: String, accion: Callable)
signal aviso_pedido(texto: String)
## Texto del coste al señalar algo en modo demolición; "" para ocultarlo.
signal etiqueta_demolicion(texto: String)

const TEX_SUELO: Array[Texture2D] = [
	preload("res://recursos/sprites/suelo1.png"), preload("res://recursos/sprites/suelo2.png"),
]
const ESCENA_COLONO := preload("res://escenas/colonos/colono.tscn")
const ESCENA_OBSTACULO := preload("res://escenas/mapa/obstaculo.tscn")
const ESCENA_MODULO := preload("res://escenas/modulos/modulo.tscn")
const MODULOS_CON_MENU := ["comando", "descanso", "almacen"]

@export_range(0.0, 1.0) var densidad_obstaculos := 0.15
@export_range(0.0, 1.0) var fraccion_crater_grande := 0.1
@export var semilla := 0                     # 0 = aleatoria

var cuadricula := GestorCuadricula.new()
var rutas := BuscadorRutas.new()
var rng := RandomNumberGenerator.new()
var modulos: Array[Modulo] = []
var obstaculos: Array[Obstaculo] = []
var suelo := []                   # suelo[y][x] -> textura

var modo: Enums.ModoMapa = Enums.ModoMapa.NORMAL
var modulo_elegido: DatosModulo
var objetivo_demoler: Node2D
var modal_abierto := false        # menú o diálogo sobre el mapa

@onready var contenedor_obstaculos: Node2D = $Obstaculos
@onready var contenedor_modulos: Node2D = $Modulos
@onready var capa: Node2D = $Capa                  # cuadrícula y previsualización
@onready var contenedor_colonos: Node2D = $Colonos


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	capa.draw.connect(_dibujar_capa)
	generar_mapa()
	for c: DatosColono in EstadoJuego.colonos:
		_crear_colono(c)
	EstadoJuego.colono_agregado.connect(_crear_colono)
	EstadoJuego.colono_retirado.connect(_quitar_colono)


func generar_mapa() -> void:
	if semilla == 0:
		rng.randomize()
	else:
		rng.seed = semilla
	for hijo in contenedor_modulos.get_children() + contenedor_obstaculos.get_children():
		hijo.free()
	modulos.clear()
	obstaculos.clear()
	cuadricula.reiniciar()
	suelo.clear()
	for y in GestorCuadricula.ALTO:
		var fila := []
		for x in GestorCuadricula.ANCHO:
			fila.append(TEX_SUELO[rng.randi_range(0, TEX_SUELO.size() - 1)])
		suelo.append(fila)
	var generador := GeneradorMapa.new()
	generador.densidad_obstaculos = densidad_obstaculos
	generador.fraccion_crater_grande = fraccion_crater_grande
	generador.generar(self, rng)
	rutas.actualizar(cuadricula)
	queue_redraw()


func agregar_modulo(id: String, origen: Vector2i) -> Modulo:
	var datos := DatosModulo.obtener(id)
	var escena: PackedScene = datos.escena if datos.escena else ESCENA_MODULO
	var modulo: Modulo = escena.instantiate()
	modulo.configurar(origen, datos)
	contenedor_modulos.add_child(modulo)
	modulos.append(modulo)
	cuadricula.ocupar_modulo(modulo)
	EstadoJuego.registrar_modulo(id)
	return modulo


func agregar_obstaculo(origen: Vector2i, tam: Vector2i, textura: Texture2D) -> Obstaculo:
	var obstaculo: Obstaculo = ESCENA_OBSTACULO.instantiate()
	obstaculo.configurar(origen, tam, textura)
	contenedor_obstaculos.add_child(obstaculo)
	obstaculos.append(obstaculo)
	cuadricula.ocupar_obstaculo(obstaculo)
	return obstaculo


# --- Consultas (las usan los colonos) -------------------------------------

func es_estructura(c: Vector2i) -> bool:
	return cuadricula.es_estructura(c)


func es_transitable(c: Vector2i) -> bool:
	return rutas.es_transitable(c)


func ruta(desde: Vector2i, hasta: Vector2i) -> Array[Vector2i]:
	return rutas.ruta(desde, hasta)


func casilla_transitable_cercana(c: Vector2i) -> Vector2i:
	return rutas.casilla_transitable_cercana(c)


func centro_celda(c: Vector2i) -> Vector2:
	return GestorCuadricula.centro_celda(c)


func modulo_por_id(id: String) -> Modulo:
	for modulo in modulos:
		if modulo.datos.id == id:
			return modulo
	return null


func celda_en_modulo(id: String) -> Vector2i:
	var modulo := modulo_por_id(id)
	if modulo == null:
		modulo = modulo_por_id("comando")
	var tam := modulo.tam_celdas()
	return modulo.origen + Vector2i(rng.randi_range(0, tam.x - 1), rng.randi_range(0, tam.y - 1))


func celda_exterior_aleatoria() -> Vector2i:
	var opciones := rutas.casillas_exteriores(cuadricula)
	if opciones.is_empty():
		return celda_en_modulo("comando")
	return opciones[rng.randi_range(0, opciones.size() - 1)]


# --- Colonos --------------------------------------------------------------

func _crear_colono(datos: DatosColono) -> void:
	var colono: Colono = ESCENA_COLONO.instantiate()
	contenedor_colonos.add_child(colono)
	colono.configurar(datos, self, celda_en_modulo("descanso"))


func _quitar_colono(datos: DatosColono) -> void:
	var colono := colono_de(datos)
	if colono:
		colono.queue_free()


func colono_de(datos: DatosColono) -> Colono:
	for colono: Colono in contenedor_colonos.get_children():
		if colono.datos == datos:
			return colono
	return null


func _mapa_modificado() -> void:
	rutas.actualizar(cuadricula)
	for colono: Colono in contenedor_colonos.get_children():
		colono.replanificar()
	capa.queue_redraw()


# --- Modos de construcción (HU-05) ----------------------------------------

func _cambiar_modo(nuevo: Enums.ModoMapa) -> void:
	modo = nuevo
	if modo != Enums.ModoMapa.COLOCANDO:
		modulo_elegido = null
	if modo != Enums.ModoMapa.DEMOLICION:
		objetivo_demoler = null
		etiqueta_demolicion.emit("")
	capa.queue_redraw()
	modo_cambiado.emit(modo)


func entrar_construccion() -> void:
	_cambiar_modo(Enums.ModoMapa.CATALOGO)


func salir_construccion() -> void:
	_cambiar_modo(Enums.ModoMapa.NORMAL)


func alternar_construccion() -> void:
	if modo == Enums.ModoMapa.NORMAL:
		entrar_construccion()
	else:
		salir_construccion()


func alternar_demolicion() -> void:
	_cambiar_modo(Enums.ModoMapa.DEMOLICION if modo == Enums.ModoMapa.CATALOGO else Enums.ModoMapa.CATALOGO)


func elegir_modulo(id: String) -> void:
	modulo_elegido = DatosModulo.obtener(id)
	_cambiar_modo(Enums.ModoMapa.COLOCANDO)


## Responde a Escape cuando no hay ningún menú abierto.
func cancelar_modo() -> void:
	match modo:
		Enums.ModoMapa.COLOCANDO:
			_cambiar_modo(Enums.ModoMapa.CATALOGO)
		Enums.ModoMapa.CATALOGO, Enums.ModoMapa.DEMOLICION:
			salir_construccion()


func puede_colocar(id: String, origen: Vector2i) -> bool:
	return cuadricula.puede_colocar(DatosModulo.obtener(id), origen)


func origen_preview() -> Vector2i:
	var celda := GestorCuadricula.celda_desde_pixel(get_global_mouse_position())
	return celda - (modulo_elegido.tam - Vector2i.ONE) / 2


func _pedir_construccion(origen: Vector2i) -> void:
	var d := modulo_elegido
	if not cuadricula.puede_colocar(d, origen) or not EstadoJuego.puede_pagar(d.dinero, d.materiales):
		return
	var texto := "%s\nCoste: $%d y %d materiales" % [d.nombre, d.dinero, d.materiales]
	confirmacion_pedida.emit("Confirmar construcción", texto, construir.bind(d.id, origen))


func construir(id: String, origen: Vector2i) -> bool:
	var d := DatosModulo.obtener(id)
	if not cuadricula.puede_colocar(d, origen) or not EstadoJuego.puede_pagar(d.dinero, d.materiales):
		return false
	EstadoJuego.pagar(d.dinero, d.materiales)
	agregar_modulo(id, origen)
	_mapa_modificado()
	# Los pasillos se trazan por tramos: se sigue colocando mientras alcance.
	if modo == Enums.ModoMapa.COLOCANDO \
			and (not d.es_pasillo() or not EstadoJuego.puede_pagar(d.dinero, d.materiales)):
		_cambiar_modo(Enums.ModoMapa.CATALOGO)
	return true


func _pedir_demolicion(objetivo: Node2D) -> void:
	var coste: int = objetivo.coste_demoler()
	if not EstadoJuego.puede_pagar(coste, 0):
		aviso_pedido.emit("No hay dinero para la demolición")
		return
	var texto := "%s\nCoste del trabajo: $%d" % [objetivo.nombre(), coste]
	if objetivo.materiales_al_demoler() > 0:
		texto += "\nMateriales a conseguir: %d" % objetivo.materiales_al_demoler()
	confirmacion_pedida.emit("Confirmar demolición", texto, demoler.bind(objetivo))


func demoler(objetivo: Node2D) -> bool:
	if not is_instance_valid(objetivo):
		return false
	var coste: int = objetivo.coste_demoler()
	if not EstadoJuego.puede_pagar(coste, 0):
		return false
	EstadoJuego.pagar(coste, 0)
	cuadricula.liberar(objetivo.origen, objetivo.tam_celdas())
	if objetivo is Modulo:
		modulos.erase(objetivo)
		EstadoJuego.quitar_modulo((objetivo as Modulo).datos.id)
	else:
		obstaculos.erase(objetivo)
		EstadoJuego.sumar("materiales", objetivo.materiales_al_demoler())
		EstadoJuego.estado_cambiado.emit()
	objetivo.get_parent().remove_child(objetivo)
	objetivo.queue_free()
	objetivo_demoler = null
	etiqueta_demolicion.emit("")
	_mapa_modificado()
	return true


# --- Entrada --------------------------------------------------------------

func _process(_delta: float) -> void:
	if modo == Enums.ModoMapa.COLOCANDO:
		capa.queue_redraw()
	elif modo == Enums.ModoMapa.DEMOLICION:
		_actualizar_objetivo_demoler()


func _unhandled_input(event: InputEvent) -> void:
	if modal_abierto or event is not InputEventMouseButton or not event.pressed:
		return
	match event.button_index:
		MOUSE_BUTTON_RIGHT:
			if modo == Enums.ModoMapa.COLOCANDO:
				_cambiar_modo(Enums.ModoMapa.CATALOGO)
		MOUSE_BUTTON_LEFT:
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
			_clic_normal(punto, c)


func _clic_normal(punto: Vector2, c: Vector2i) -> void:
	for colono: Colono in contenedor_colonos.get_children():
		if colono.contiene(punto):
			colono_clicado.emit(colono)
			return
	if cuadricula.celdas_modulo.has(c):
		var id: String = cuadricula.celdas_modulo[c].datos.id
		if id in MODULOS_CON_MENU:
			modulo_clicado.emit(id)


func _actualizar_objetivo_demoler() -> void:
	var objetivo: Node2D = null
	var sobre_ui := get_viewport().gui_get_hovered_control() != null
	var c := GestorCuadricula.celda_desde_pixel(get_global_mouse_position())
	if not sobre_ui and not modal_abierto and GestorCuadricula.dentro_del_mapa(c):
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
					capa.draw_rect(rect, Color(0.3, 0.55, 1.0, 0.28))
				Enums.EstadoCasilla.BLOQUEADA:
					capa.draw_rect(rect, Color(0.1, 0.05, 0.05, 0.45))
			capa.draw_rect(rect, Color(1, 1, 1, 0.22), false, 1.0)
	if modo == Enums.ModoMapa.COLOCANDO:
		_dibujar_preview()
	elif modo == Enums.ModoMapa.DEMOLICION and is_instance_valid(objetivo_demoler):
		var rect := Rect2(objetivo_demoler.position, Vector2(objetivo_demoler.tam_celdas()) * lado)
		capa.draw_rect(rect, Color("#ff3b30"), false, 3.0)


func _dibujar_preview() -> void:
	var origen := origen_preview()
	var d := modulo_elegido
	var valido := cuadricula.puede_colocar(d, origen)
	var rect := Rect2(Vector2(origen) * GestorCuadricula.TAM_CELDA, Vector2(d.tam) * GestorCuadricula.TAM_CELDA)
	var tinte := Color(0.3, 1.0, 0.4, 0.55) if valido else Color(1.0, 0.25, 0.2, 0.55)
	capa.draw_rect(rect, d.color * Color(1, 1, 1, 0.45))
	capa.draw_rect(rect, tinte)
	capa.draw_rect(rect, Color(tinte, 1.0), false, 2.0)
