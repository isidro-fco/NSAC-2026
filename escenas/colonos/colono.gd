class_name Colono
extends Node2D
## NPC autónomo: se mueve entre módulos según el estado de su DatosColono.
## Actividades: descansar, comer, trabajar y en tránsito (HU-06). Durante una
## tormenta solar se refugia en el refugio blindado que le toque (HU-08).

const VELOCIDAD_PX := 48.0
const RADIO_CLIC := 14.0

var datos: DatosColono
var mapa: Mapa
var ruta: Array[Vector2i] = []
var celda := Vector2i.ZERO
var destino := Vector2i.ZERO         # casilla a la que se dirige (para replanificar)
var espera := 0.0
var ultima_situacion := []           # [estado, tarea, refugio]: si cambia, se busca otro destino
var refugio: Modulo
var destino_actividad := "Descansando"
var ir_a_descanso := true
var tiempo := 0.0


func configurar(datos_colono: DatosColono, mapa_base: Mapa, celda_inicial: Vector2i) -> void:
	datos = datos_colono
	mapa = mapa_base
	celda = celda_inicial
	destino = celda
	position = GestorCuadricula.centro_celda(celda)
	EstadoJuego.estado_cambiado.connect(_reevaluar)
	_reevaluar()


func _process(delta: float) -> void:
	var escala := GestorTiempo.escalar(delta)
	if escala <= 0.0 or EstadoJuego.terminado:
		return
	tiempo += escala
	queue_redraw()
	datos.ubicacion = mapa.ubicacion(celda)
	var tasa := EstadoJuego.eventos.tasa_radiacion(datos.ubicacion)
	if tasa > 0.0:
		EstadoJuego.tripulacion.anadir_radiacion(datos, tasa * escala / EstadoJuego.datos_balance.segundos_por_sol)
	if not ruta.is_empty():
		position = position.move_toward(GestorCuadricula.centro_celda(ruta[0]), VELOCIDAD_PX * escala)
		if position.is_equal_approx(GestorCuadricula.centro_celda(ruta[0])):
			celda = ruta.pop_front()
			if ruta.is_empty():
				_llegar()
	elif datos.estado == Enums.EstadoColono.DISPONIBLE and refugio == null:
		espera -= escala
		if espera <= 0.0:
			_elegir_paseo()


func _llegar() -> void:
	datos.actividad = destino_actividad
	espera = randf_range(6.0, 12.0)


func _reevaluar() -> void:
	refugio = mapa.refugio_para(datos)
	var situacion := [datos.estado, datos.tarea.get("id", ""), refugio]
	if situacion == ultima_situacion:
		return
	ultima_situacion = situacion
	if refugio != null:
		_ir_a(mapa.celda_en(refugio), "Refugiado")
		return
	match datos.estado:
		Enums.EstadoColono.EN_MISION:
			_ir_a(mapa.celda_exterior_aleatoria() if datos.tarea["exterior"]
				else mapa.celda_en_modulo(datos.tarea["modulo"]), "Trabajando")
		Enums.EstadoColono.ENFERMO:
			_ir_a(mapa.celda_en_modulo("descanso"), "Descansando")
		Enums.EstadoColono.DISPONIBLE:
			_elegir_paseo()


func _elegir_paseo() -> void:
	ir_a_descanso = not ir_a_descanso
	if ir_a_descanso:
		_ir_a(mapa.celda_en_modulo("descanso"), "Descansando")
	else:
		_ir_a(mapa.celda_en_modulo("almacen"), "Comiendo")


func _ir_a(hasta: Vector2i, actividad: String) -> void:
	destino = hasta
	destino_actividad = actividad
	# Si estaba entre dos casillas, primero termina de llegar a la siguiente.
	var desde := celda if ruta.is_empty() else ruta[0]
	var nueva := mapa.rutas.ruta(desde, hasta)
	if not ruta.is_empty():
		nueva.push_front(desde)
	ruta = nueva
	if ruta.is_empty():
		_llegar()
	else:
		datos.actividad = "En tránsito"


## El mapa cambió: recalcula el trayecto hacia el mismo destino.
func replanificar() -> void:
	if not mapa.rutas.es_transitable(celda):
		celda = mapa.rutas.casilla_transitable_cercana(celda)
		position = GestorCuadricula.centro_celda(celda)
		ruta.clear()
	# También si no había camino (p. ej. el refugio se acaba de construir).
	if celda != destino:
		_ir_a(destino, destino_actividad)


func _draw() -> void:
	var color := datos.color_rol()
	if datos.estado == Enums.EstadoColono.ENFERMO:
		color = color.darkened(0.45)
	var base := Vector2(0, -absf(sin(tiempo * 8.0)) * 1.5 if not ruta.is_empty() else 0.0)
	draw_circle(Vector2(0, 7), 5.0, Color(0, 0, 0, 0.3))
	draw_rect(Rect2(base + Vector2(-5, -2), Vector2(10, 9)), color)
	draw_circle(base + Vector2(0, -6), 5.0, UI.TEXTO)
	draw_circle(base + Vector2(0, -6), 3.0, UI.FONDO_CLARO)
	draw_rect(Rect2(base + Vector2(-5, -2), Vector2(10, 9)), Color(0, 0, 0, 0.45), false, 1.0)
