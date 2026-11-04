class_name Colono
extends Node2D
## NPC autónomo: se mueve entre módulos según el estado de su DatosColono.
## Actividades: descansar, comer, trabajar y en tránsito (HU-06).

const VELOCIDAD_PX := 48.0
const RADIO_CLIC := 14.0

var datos: DatosColono
var mapa: Mapa
var ruta: Array[Vector2i] = []
var celda := Vector2i.ZERO
var espera := 0.0
var ultimo_estado := -1
var ultima_tarea := ""
var destino_actividad := "Descansando"
var ir_a_descanso := true
var tiempo := 0.0


func configurar(datos_colono: DatosColono, mapa_base: Mapa, celda_inicial: Vector2i) -> void:
	datos = datos_colono
	mapa = mapa_base
	celda = celda_inicial
	position = mapa.centro_celda(celda)
	EstadoJuego.estado_cambiado.connect(_reevaluar)
	_reevaluar()


func _process(delta: float) -> void:
	var escala := GestorTiempo.escalar(delta)
	if escala <= 0.0 or EstadoJuego.terminado:
		return
	tiempo += escala
	queue_redraw()
	datos.a_la_intemperie = not mapa.es_estructura(celda)
	if datos.a_la_intemperie:
		var soles: float = escala / EstadoJuego.datos_balance.segundos_por_sol
		EstadoJuego.anadir_radiacion(datos, EstadoJuego.datos_balance.radiacion_intemperie_por_sol * soles)
	if not ruta.is_empty():
		_avanzar(escala)
	elif datos.estado == Enums.EstadoColono.DISPONIBLE:
		espera -= escala
		if espera <= 0.0:
			_elegir_paseo()


func _avanzar(escala: float) -> void:
	var objetivo := mapa.centro_celda(ruta[0])
	position = position.move_toward(objetivo, VELOCIDAD_PX * escala)
	if position.is_equal_approx(objetivo):
		celda = ruta.pop_front()
		if ruta.is_empty():
			datos.actividad = destino_actividad
			espera = randf_range(6.0, 12.0)


func _reevaluar() -> void:
	var tarea_id: String = datos.tarea.get("id", "")
	if datos.estado == ultimo_estado and tarea_id == ultima_tarea:
		return
	ultimo_estado = datos.estado
	ultima_tarea = tarea_id
	match datos.estado:
		Enums.EstadoColono.EN_MISION:
			_ir_a(_estacion_de_trabajo(), "Trabajando")
		Enums.EstadoColono.ENFERMO:
			_ir_a(mapa.celda_en_modulo("descanso"), "Descansando")
		Enums.EstadoColono.DISPONIBLE:
			_elegir_paseo()


func _estacion_de_trabajo() -> Vector2i:
	if datos.tarea["exterior"]:
		return mapa.celda_exterior_aleatoria()
	return mapa.celda_en_modulo(datos.tarea["modulo"])


func _elegir_paseo() -> void:
	ir_a_descanso = not ir_a_descanso
	if ir_a_descanso:
		_ir_a(mapa.celda_en_modulo("descanso"), "Descansando")
	else:
		_ir_a(mapa.celda_en_modulo("almacen"), "Comiendo")


func _ir_a(destino: Vector2i, actividad: String) -> void:
	destino_actividad = actividad
	# Si estaba entre dos casillas, primero termina de llegar a la siguiente.
	var desde := celda if ruta.is_empty() else ruta[0]
	var nueva := mapa.ruta(desde, destino)
	if not ruta.is_empty():
		nueva.push_front(desde)
	ruta = nueva
	if ruta.is_empty():
		datos.actividad = actividad
		espera = randf_range(6.0, 12.0)
	else:
		datos.actividad = "En tránsito"


## El mapa cambió: recalcula el trayecto hacia el mismo destino.
func replanificar() -> void:
	if not mapa.es_transitable(celda):
		celda = mapa.casilla_transitable_cercana(celda)
		position = mapa.centro_celda(celda)
		ruta.clear()
	if not ruta.is_empty():
		_ir_a(ruta[-1], destino_actividad)


func contiene(punto: Vector2) -> bool:
	return position.distance_to(punto) <= RADIO_CLIC


func _draw() -> void:
	var color := datos.color_rol()
	if datos.estado == Enums.EstadoColono.ENFERMO:
		color = color.darkened(0.45)
	var salto := absf(sin(tiempo * 8.0)) * 1.5 if not ruta.is_empty() else 0.0
	var base := Vector2(0, -salto)
	draw_circle(Vector2(0, 7), 5.0, Color(0, 0, 0, 0.3))
	draw_rect(Rect2(base + Vector2(-5, -2), Vector2(10, 9)), color)
	draw_circle(base + Vector2(0, -6), 5.0, Color("#eef1f5"))
	draw_circle(base + Vector2(0, -6), 3.0, Color("#26303c"))
	draw_rect(Rect2(base + Vector2(-5, -2), Vector2(10, 9)), Color(0, 0, 0, 0.45), false, 1.0)
