# gestor_audio.gd
# Autoload GestorAudio: efectos de sonido de la interfaz, de los módulos y de la nave de aterrizaje.

extends Node
## Uso: GestorAudio.reproducir("poner_modulo").
## Los botones suenan solos: cada BaseButton que entra al árbol reproduce "clic"
## al pulsarse (para silenciar uno: button.set_meta("sin_sonido", true)).
## Hay varios reproductores para que los sonidos se puedan encimar.
## Aparte, un reproductor de ambiente (viento de Marte) suena en bucle durante
## la partida: GestorAudio.iniciar_ambiente() / detener_ambiente().

## Rutas de los sonidos (se cargan en _ready: un preload fallaría la primera
## vez que se abre el proyecto, antes de que Godot importe los .ogg).
const RUTAS := {
	# Interfaz
	"clic": "res://recursos/audio/efectos/interfaz/clic.ogg",
	# Módulos
	"poner_modulo": "res://recursos/audio/efectos/modulos/poner_modulo.ogg",
	"quitar_modulo": "res://recursos/audio/efectos/modulos/quitar_modulo.ogg",
	"casilla_invalida": "res://recursos/audio/efectos/modulos/casilla_invalida.ogg",
	# Nave
	"aterrizaje": "res://recursos/audio/efectos/nave/aterrizaje.ogg",
	"despegue": "res://recursos/audio/efectos/nave/despegue.ogg",
	"caja_cayendo": "res://recursos/audio/efectos/nave/caja_cayendo.ogg",
}
## Volumen de cada sonido (dB) para que ninguno tape a los demás.
const VOLUMEN := {
	"clic": -6.0,
	"poner_modulo": 0.0,
	"quitar_modulo": 2.0,
	"casilla_invalida": -3.0,
	"aterrizaje": -2.0,
	"despegue": -2.0,
	"caja_cayendo": -4.0,
}
const REPRODUCTORES := 8
const AMBIENTE := "res://recursos/audio/ambiente/viento.ogg"
const VOLUMEN_AMBIENTE := -8.0        # dB
const FUNDIDO_AMBIENTE := 2.5         # s para subir o bajar el volumen

var _sonidos := {}                    # nombre -> AudioStream
var _reproductores: Array[AudioStreamPlayer] = []
var _siguiente := 0
var _ambiente := AudioStreamPlayer.new()
var _fundido: Tween
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


func _al_agregar_nodo(nodo: Node) -> void:
	# La marca evita conectar dos veces un botón que sale y vuelve a entrar al árbol.
	if nodo is BaseButton and not nodo.has_meta("_suena"):
		nodo.set_meta("_suena", true)
		(nodo as BaseButton).pressed.connect(func() -> void:
			if not nodo.has_meta("sin_sonido"):
				reproducir("clic"))
