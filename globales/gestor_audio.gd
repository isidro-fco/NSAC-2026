# gestor_audio.gd
# Autoload GestorAudio: efectos de sonido de la interfaz, de los módulos y de la nave de aterrizaje.

extends Node
## Uso: GestorAudio.reproducir("poner_modulo").
## Los botones suenan solos: cada BaseButton que entra al árbol reproduce "clic"
## al pulsarse (para silenciar uno: button.set_meta("sin_sonido", true)).
## Hay varios reproductores para que los sonidos se puedan encimar.
## Aparte, un reproductor de ambiente (viento de Marte) suena en bucle durante
## la partida: GestorAudio.iniciar_ambiente() / detener_ambiente().
## Los pasos de los colonos van por su cuenta: GestorAudio.reproducir_paso(punto)
## (ver Colono), con un volumen que depende de qué tan cerca está la cámara.

## Rutas de los sonidos (se cargan en _ready: un preload fallaría la primera
## vez que se abre el proyecto, antes de que Godot importe los .ogg).
const RUTAS := {
	# Interfaz
	"clic": "res://recursos/audio/efectos/interfaz/clic.ogg",
	# Módulos
	"poner_modulo": "res://recursos/audio/efectos/modulos/poner_modulo.ogg",
	"quitar_modulo": "res://recursos/audio/efectos/modulos/quitar_modulo.ogg",
	"quitar_piedra": "res://recursos/audio/efectos/modulos/quitar_piedra.ogg",
	"casilla_invalida": "res://recursos/audio/efectos/modulos/casilla_invalida.ogg",
	# Nave
	"aterrizaje": "res://recursos/audio/efectos/nave/aterrizaje.ogg",
	"despegue": "res://recursos/audio/efectos/nave/despegue.ogg",
	"caja_cayendo": "res://recursos/audio/efectos/nave/caja_cayendo.ogg",
}
## Volumen de cada sonido (dB) para que ninguno tape a los demás.
const VOLUMEN := {
	"clic": -6.0,
	"poner_modulo": -4.0,
	"quitar_modulo": 2.0,
	"quitar_piedra": -4.0,
	"casilla_invalida": -3.0,
	"aterrizaje": -6.0,
	"despegue": -6.0,
	"caja_cayendo": -4.0,
}
const REPRODUCTORES := 8

## Pasos de los colonos. Un solo paso que se repite al ritmo de la caminata.
const PASO := "res://recursos/audio/efectos/colonos/paso.ogg"
const VOLUMEN_PASO := -6.0            # dB con la cámara pegada al colono y el zoom al máximo
const REPRODUCTORES_PASO := 6         # pasos que pueden sonar a la vez
## Por debajo de este volumen (0 a 1) el paso no se reproduce: así de lejos no se oye nada.
const PASO_MINIMO := 0.04
## Qué tanto del zoom hace falta para empezar a oír pasos (0 = zoom mínimo, 1 = máximo).
const PASO_ZOOM_DESDE := 0.15
## Hasta dónde se oye un paso, en mitades de pantalla desde el centro (1 = el borde).
const PASO_ALCANCE := 1.1
const AMBIENTE := "res://recursos/audio/ambiente/viento.ogg"
const VOLUMEN_AMBIENTE := -8.0        # dB
const FUNDIDO_AMBIENTE := 2.5         # s para subir o bajar el volumen

var _sonidos := {}                    # nombre -> AudioStream
var _reproductores: Array[AudioStreamPlayer] = []
var _siguiente := 0
var _ambiente := AudioStreamPlayer.new()
var _fundido: Tween
var _paso: AudioStream
var _reproductores_paso: Array[AudioStreamPlayer] = []
var _siguiente_paso := 0
## Volúmenes del menú de opciones (0 = silencio, 1 = normal). Se guardan en user://ajustes.cfg.
var volumen_efectos := 1.0
var volumen_ambiente := 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var ajustes := ConfigFile.new()
	if ajustes.load("user://ajustes.cfg") == OK:
		volumen_efectos = clampf(ajustes.get_value("opciones", "volumen_efectos", 1.0), 0.0, 1.0)
		volumen_ambiente = clampf(ajustes.get_value("opciones", "volumen_ambiente", 1.0), 0.0, 1.0)
	for nombre: String in RUTAS:
		_sonidos[nombre] = load(RUTAS[nombre])
	for i in REPRODUCTORES:
		var reproductor := AudioStreamPlayer.new()
		add_child(reproductor)
		_reproductores.append(reproductor)
	get_tree().node_added.connect(_al_agregar_nodo)
	_paso = load(PASO)
	for i in REPRODUCTORES_PASO:
		var reproductor := AudioStreamPlayer.new()
		add_child(reproductor)
		_reproductores_paso.append(reproductor)
	var stream: AudioStream = load(AMBIENTE)
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true     # el archivo ya empalma su final con su inicio
	_ambiente.stream = stream
	_ambiente.volume_db = -80.0
	add_child(_ambiente)


## Empieza el viento de fondo subiendo el volumen poco a poco.
func iniciar_ambiente() -> void:
	if _ambiente.stream == null:
		return
	if not _ambiente.playing:
		_ambiente.volume_db = -40.0
		_ambiente.play()
	_fundir_a(_db_ambiente())


func fijar_volumen_efectos(valor: float) -> void:
	volumen_efectos = clampf(valor, 0.0, 1.0)


## Cambia el volumen del viento al momento (sin fundido).
func fijar_volumen_ambiente(valor: float) -> void:
	volumen_ambiente = clampf(valor, 0.0, 1.0)
	if _ambiente.playing:
		if _fundido != null:
			_fundido.kill()
		_ambiente.volume_db = _db_ambiente()


func _db_ambiente() -> float:
	return VOLUMEN_AMBIENTE + linear_to_db(volumen_ambiente) if volumen_ambiente > 0.0 else -80.0


func detener_ambiente() -> void:
	_fundir_a(-60.0, true)


func _fundir_a(volumen: float, parar := false) -> void:
	if _fundido != null:
		_fundido.kill()
	_fundido = create_tween()
	_fundido.tween_property(_ambiente, "volume_db", volumen, FUNDIDO_AMBIENTE)
	if parar:
		_fundido.tween_callback(_ambiente.stop)


func reproducir(nombre: String) -> void:
	if _sonidos.get(nombre) == null:
		push_warning("Sonido desconocido: %s" % nombre)
		return
	if volumen_efectos <= 0.0:
		return
	# Primero uno libre; si todos suenan, el que lleva más tiempo.
	var reproductor := _reproductores[_siguiente]
	for r in _reproductores:
		if not r.playing:
			reproductor = r
			break
	_siguiente = (_siguiente + 1) % REPRODUCTORES
	reproductor.stream = _sonidos[nombre]
	reproductor.volume_db = VOLUMEN.get(nombre, 0.0) + linear_to_db(volumen_efectos)
	reproductor.play()


## Un paso de un colono en `punto` (coordenadas del mapa). Suena más fuerte
## mientras más cerca del centro de la pantalla está y mientras más zoom tiene
## la cámara: con el mapa entero a la vista no se oye, y al acercarse a un
## colono se le oye caminar. Si está fuera de la pantalla, tampoco se oye.
func reproducir_paso(punto: Vector2) -> void:
	if _paso == null or volumen_efectos <= 0.0:
		return
	var cercania := cercania_paso(punto)
	if cercania < PASO_MINIMO:
		return
	# Primero uno libre; si todos suenan, el que lleva más tiempo.
	var reproductor := _reproductores_paso[_siguiente_paso]
	for r in _reproductores_paso:
		if not r.playing:
			reproductor = r
			break
	_siguiente_paso = (_siguiente_paso + 1) % REPRODUCTORES_PASO
	reproductor.stream = _paso
	reproductor.volume_db = VOLUMEN_PASO + linear_to_db(cercania * volumen_efectos)
	reproductor.pitch_scale = randf_range(0.92, 1.08)      # que no suenen todos idénticos
	reproductor.play()


## Volumen (0 a 1) de un paso en `punto` según la cámara del mapa.
func cercania_paso(punto: Vector2) -> float:
	var camara := get_viewport().get_camera_2d()
	if camara == null:
		return 0.0
	var zoom := camara.zoom.x
	var zoom_min := (camara as CamaraJuego)._zoom_minimo() if camara is CamaraJuego else 1.0
	var zoom_max := CamaraJuego.ZOOM_MAX
	# Zoom: 0 con el mapa entero a la vista, 1 con el zoom al máximo.
	var t := clampf(inverse_lerp(zoom_min, zoom_max, zoom), 0.0, 1.0) if zoom_max > zoom_min else 1.0
	var por_zoom := smoothstep(PASO_ZOOM_DESDE, 1.0, t)
	# Distancia: 1 en el centro de la pantalla, 0 un poco más allá del borde.
	var media_pantalla := get_viewport().get_visible_rect().size.y / 2.0 / zoom
	var d := punto.distance_to(camara.get_screen_center_position()) / media_pantalla
	var por_distancia := clampf(1.0 - d / PASO_ALCANCE, 0.0, 1.0)
	return por_zoom * por_distancia * por_distancia


func _al_agregar_nodo(nodo: Node) -> void:
	# La marca evita conectar dos veces un botón que sale y vuelve a entrar al árbol.
	if nodo is BaseButton and not nodo.has_meta("_suena"):
		nodo.set_meta("_suena", true)
		(nodo as BaseButton).pressed.connect(func() -> void:
			if not nodo.has_meta("sin_sonido"):
				reproducir("clic"))
