# colono.gd
# Colono en el mapa: se mueve solo entre módulos según su estado (descansar, comer, trabajar, refugiarse).

class_name Colono
extends Node2D
## NPC autónomo: se mueve entre módulos según el estado de su DatosColono.
## Actividades: descansar, comer, trabajar y en tránsito (HU-06). Durante una
## tormenta solar se refugia en el refugio blindado que le toque (HU-08).
## Con una tarea asignada va con prisa a su estación (el módulo de la tarea, o
## el Módulo de Comando si no está construido) y, al llegar, se anima trabajando.
## Camina casilla a casilla y al final se acerca a un punto exacto dentro del
## edificio, para no quedarse en las esquinas de tierra del módulo.

const VELOCIDAD_PX := 48.0
## Multiplicador de velocidad al ir a la estación de su tarea.
const FACTOR_PRISA := 1.4
## Módulo al que va si la estación de su tarea no existe o no tiene camino.
const ESTACION_POR_DEFECTO := "comando"
const RADIO_CLIC := 14.0
# Hoja de caminata: 6 fotogramas por fila, filas = abajo, izquierda, derecha, arriba.
const HOJA := preload("res://recursos/sprites/colonos/astronauta.png")
const HOJA_ACENTO := preload("res://recursos/sprites/colonos/astronauta_acento.png")
const TAM_FOTOGRAMA := 32
const FOTOGRAMAS := 6
const FPS_CAMINATA := 10.0
const DESFASE_SPRITE := Vector2(-16, -20)   # pies del sprite sobre la sombra
enum Direccion { ABAJO, IZQUIERDA, DERECHA, ARRIBA }

var datos: DatosColono
var mapa: Mapa
var ruta: Array[Vector2i] = []
var celda := Vector2i.ZERO
var destino := Vector2i.ZERO         # casilla a la que se dirige (para replanificar)
var punto_destino := Vector2.ZERO    # punto exacto al que quiere llegar
var punto_final := Vector2.ZERO      # punto donde se detendrá (el destino, o donde se quedó sin camino)
var espera := 0.0
var ultima_situacion := []           # [estado, tarea, refugio]: si cambia, se busca otro destino
var refugio: Modulo
var destino_actividad := "Descansando"
var ir_a_descanso := true
var con_prisa := false               # va hacia la estación de su tarea
var tiempo := 0.0
var direccion := Direccion.ABAJO


## `punto` es donde aparece: en su módulo al empezar la partida o al pie de la nave.
func configurar(datos_colono: DatosColono, mapa_base: Mapa, punto: Vector2) -> void:
	datos = datos_colono
	mapa = mapa_base
	position = punto
	celda = GestorCuadricula.celda_desde_pixel(punto)
	destino = celda
	punto_destino = punto
	punto_final = punto
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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
	if en_camino():
		_avanzar(VELOCIDAD_PX * (FACTOR_PRISA if con_prisa else 1.0) * escala)
	elif datos.estado == Enums.EstadoColono.DISPONIBLE and refugio == null:
		espera -= escala
		if espera <= 0.0:
			_elegir_paseo()


func en_camino() -> bool:
	return not ruta.is_empty() or not position.is_equal_approx(punto_final)


## Se mueve `paso` píxeles: primero por las casillas de la ruta y después hasta el punto final.
func _avanzar(paso: float) -> void:
	var objetivo := GestorCuadricula.centro_celda(ruta[0]) if not ruta.is_empty() else punto_final
	_orientar(objetivo - position)
	position = position.move_toward(objetivo, paso)
	if not position.is_equal_approx(objetivo):
		return
	if not ruta.is_empty():
		celda = ruta.pop_front()
	if not en_camino():
		_llegar()


## true mientras está en su estación haciendo la tarea (no en camino ni refugiado).
func trabajando() -> bool:
	return datos.estado == Enums.EstadoColono.EN_MISION and not en_camino() and refugio == null


func _llegar() -> void:
	con_prisa = false
	datos.actividad = destino_actividad
	espera = randf_range(6.0, 12.0)


func _reevaluar() -> void:
	refugio = mapa.refugio_para(datos)
	var situacion := [datos.estado, datos.tarea.get("id", ""), refugio]
	if situacion == ultima_situacion:
		return
	ultima_situacion = situacion
	if refugio != null:
		_ir_a(mapa.punto_en(refugio), "Refugiado")
		return
	match datos.estado:
		Enums.EstadoColono.EN_MISION:
			_ir_a_estacion()
		Enums.EstadoColono.ENFERMO:
			_ir_a(mapa.punto_en_modulo("descanso"), "Descansando")
		Enums.EstadoColono.DISPONIBLE:
			_elegir_paseo()


## Módulo donde se hace la tarea en curso: el que indica la tarea si está
## construido y se puede llegar andando; si no, el Módulo de Comando.
func _modulo_estacion() -> Modulo:
	var modulo := mapa.modulo_alcanzable(datos.tarea.get("modulo", ESTACION_POR_DEFECTO), celda)
	return modulo if modulo != null else mapa.modulo_alcanzable(ESTACION_POR_DEFECTO, celda)


## Va con prisa a su estación de trabajo.
func _ir_a_estacion() -> void:
	var modulo := _modulo_estacion()
	var punto := mapa.punto_en(modulo) if modulo != null else mapa.punto_en_modulo(ESTACION_POR_DEFECTO)
	_ir_a(punto, "Trabajando", true)


func _elegir_paseo() -> void:
	ir_a_descanso = not ir_a_descanso
	if ir_a_descanso:
		_ir_a(mapa.punto_en_modulo("descanso"), "Descansando")
	else:
		_ir_a(mapa.punto_en_modulo("almacen"), "Comiendo")


func _ir_a(punto: Vector2, actividad: String, prisa := false) -> void:
	destino = GestorCuadricula.celda_desde_pixel(punto)
	punto_destino = punto
	destino_actividad = actividad
	con_prisa = prisa
	# Si estaba entre dos casillas, primero termina de llegar a la siguiente.
	var desde := celda if ruta.is_empty() else ruta[0]
	var nueva := mapa.rutas.ruta(desde, destino)
	if desde == destino or not nueva.is_empty():
		punto_final = punto
	else:
		punto_final = GestorCuadricula.centro_celda(desde)    # sin camino: se queda donde está
	if not ruta.is_empty():
		nueva.push_front(desde)
	ruta = nueva
	if en_camino():
		datos.actividad = "En tránsito"
	else:
		_llegar()


## El mapa cambió: recalcula el trayecto hacia el mismo destino.
func replanificar() -> void:
	if not mapa.rutas.es_transitable(celda):
		celda = mapa.rutas.casilla_transitable_cercana(celda)
		position = GestorCuadricula.centro_celda(celda)
		punto_final = position
		ruta.clear()
	if datos.estado == Enums.EstadoColono.EN_MISION and refugio == null:
		# Si se construyó, conectó o demolió su estación, o no había camino, vuelve a buscarla.
		if celda != destino or not _destino_en_estacion():
			_ir_a_estacion()
	# También si no había camino (p. ej. el refugio se acaba de construir).
	elif celda != destino:
		_ir_a(punto_destino, destino_actividad)


func _destino_en_estacion() -> bool:
	var modulo := _modulo_estacion()
	return modulo == null or mapa.cuadricula.celdas_modulo.get(destino) == modulo


func _orientar(mov: Vector2) -> void:
	if mov.is_zero_approx():
		return
	if absf(mov.x) > absf(mov.y):
		direccion = Direccion.IZQUIERDA if mov.x < 0.0 else Direccion.DERECHA
	else:
		direccion = Direccion.ARRIBA if mov.y < 0.0 else Direccion.ABAJO


func _draw() -> void:
	var tinte := Color.WHITE
	if datos.estado == Enums.EstadoColono.ENFERMO:
		tinte = Color(0.6, 0.75, 0.6)
	var base := Vector2.ZERO
	if trabajando():
		# Trabajando: se balancea un poco y golpea suave, como si usara una herramienta.
		base = Vector2(sin(tiempo * 3.0) * 1.0, -absf(sin(tiempo * 6.0)) * 0.8)
	# Al caminar anima la hoja; con prisa, más rápido.
	var fps := FPS_CAMINATA * (FACTOR_PRISA if con_prisa else 1.0)
	var fotograma := int(tiempo * fps) % FOTOGRAMAS if en_camino() else 0
	var region := Rect2(fotograma * TAM_FOTOGRAMA, direccion * TAM_FOTOGRAMA, TAM_FOTOGRAMA, TAM_FOTOGRAMA)
	var destino_rect := Rect2(base + DESFASE_SPRITE, Vector2(TAM_FOTOGRAMA, TAM_FOTOGRAMA))
	draw_set_transform(Vector2(0, 7), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 6.0, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO)
	draw_texture_rect_region(HOJA, destino_rect, region, tinte)
	draw_texture_rect_region(HOJA_ACENTO, destino_rect, region, datos.color_rol() * tinte)
	if trabajando():
		_dibujar_herramienta(base)


## Brazo que sube y baja con una chispa al golpear.
func _dibujar_herramienta(base: Vector2) -> void:
	var golpe := absf(sin(tiempo * 6.0))
	var mano := base + Vector2(8, -1 - golpe * 3.0)
	draw_line(base + Vector2(5, 1), mano, UI.TEXTO, 2.0)
	if golpe < 0.25:
		draw_circle(mano + Vector2(2, -1), 1.5, UI.ADVERTENCIA)
