# gestor_audio.gd
# Autoload GestorAudio: efectos de sonido de la interfaz, de los módulos y de la nave de aterrizaje.

extends Node
## Uso: GestorAudio.reproducir("poner_modulo").
## Los botones suenan solos: cada BaseButton que entra al árbol reproduce "clic"
## al pulsarse (para silenciar uno: button.set_meta("sin_sonido", true)).
## Hay varios reproductores para que los sonidos se puedan encimar.

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

var _sonidos := {}                    # nombre -> AudioStream
var _reproductores: Array[AudioStreamPlayer] = []
var _siguiente := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for nombre: String in RUTAS:
		_sonidos[nombre] = load(RUTAS[nombre])
	for i in REPRODUCTORES:
		var reproductor := AudioStreamPlayer.new()
		add_child(reproductor)
		_reproductores.append(reproductor)
	get_tree().node_added.connect(_al_agregar_nodo)


func reproducir(nombre: String) -> void:
	if _sonidos.get(nombre) == null:
		push_warning("Sonido desconocido: %s" % nombre)
		return
	# Primero uno libre; si todos suenan, el que lleva más tiempo.
	var reproductor := _reproductores[_siguiente]
	for r in _reproductores:
		if not r.playing:
			reproductor = r
			break
	_siguiente = (_siguiente + 1) % REPRODUCTORES
	reproductor.stream = _sonidos[nombre]
	reproductor.volume_db = VOLUMEN.get(nombre, 0.0)
	reproductor.play()


func _al_agregar_nodo(nodo: Node) -> void:
	# La marca evita conectar dos veces un botón que sale y vuelve a entrar al árbol.
	if nodo is BaseButton and not nodo.has_meta("_suena"):
		nodo.set_meta("_suena", true)
		(nodo as BaseButton).pressed.connect(func() -> void:
			if not nodo.has_meta("sin_sonido"):
				reproducir("clic"))
