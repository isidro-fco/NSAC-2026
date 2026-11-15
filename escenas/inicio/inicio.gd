# inicio.gd
# Menú de inicio: fondo pixel art, título y botones Jugar, Opciones y Salir.

class_name Inicio
extends Control
## Primera pantalla del juego (escena principal del proyecto).
## El fondo es recursos/sprites/interfaz/fondo_inicio.png, la versión pixel art
## de fondo.jpeg (ver herramientas/generar_fondo_inicio.py): se dibuja cubriendo
## toda la ventana, sin suavizado.
##   LITTLE BIG STEPS
##   COLONIA EN MARTE
##
##   [      JUGAR      ]
##   [    OPCIONES     ]      Opciones abre el mismo menú que Esc en la partida.
##   [      SALIR      ]

const FONDO := preload("res://recursos/sprites/interfaz/fondo_inicio.png")
const ESCENA_JUEGO := "res://escenas/juego/juego.tscn"
const ANCHO_BOTONES := 300
const MARGEN := 56
const ESTRELLAS := 34

var opciones: MenuOpciones
var _reloj := 0.0
var _estrellas: Array[Vector3] = []      # x, y (0..1 de la ventana) y desfase del parpadeo


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UI.tema()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	MenuOpciones.aplicar_pantalla()
	GestorTiempo.en_pausa = true          # nada corre hasta pulsar Jugar
	GestorAudio.iniciar_ambiente()
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	for i in ESTRELLAS:
		_estrellas.append(Vector3(rng.randf(), rng.randf(), rng.randf() * TAU))

	var columna := UI.columna(10)
	columna.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, MARGEN)
	columna.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(columna)
	columna.add_child(_titulo("LITTLE BIG STEPS", 40, UI.TEXTO))
	columna.add_child(_titulo("COLONIA EN MARTE", 16, UI.ACENTO))
	var hueco := Control.new()
	hueco.custom_minimum_size = Vector2(0, 22)
	columna.add_child(hueco)
	# Los botones no se estiran al ancho del título.
	for boton: Button in [
			Cabina.boton_grande("Jugar", "Fundar una colonia nueva", _jugar),
			MenuOpciones.boton_apagado("Opciones", "Sonido, pantalla y controles", _abrir_opciones),
			MenuOpciones.boton_apagado("Salir", "Cerrar el juego", get_tree().quit, UI.CRITICO)]:
		boton.custom_minimum_size.x = ANCHO_BOTONES
		boton.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		columna.add_child(boton)

	# Flechas + Enter: los botones de la columna, o el menú de opciones si está abierto.
	add_child(NavegacionTeclado.new(func() -> Control: return opciones if opciones != null else columna))
	var pie := UI.etiqueta_pixel("ESC: OPCIONES  ·  FLECHAS Y ENTER: ELEGIR", UI.T_DETALLE, UI.TEXTO_SUAVE)
	pie.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 16)
	pie.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	pie.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_sombrear(pie, 2)
	add_child(pie)


func _process(delta: float) -> void:
	_reloj += delta
	queue_redraw()


## Fondo cubriendo la ventana (recorta lo que sobre) y estrellas que parpadean
## solo donde el fondo es cielo oscuro.
func _draw() -> void:
	var tam := Vector2(FONDO.get_size())
	var escala := maxf(size.x / tam.x, size.y / tam.y)
	var destino := Rect2((size - tam * escala) / 2.0, tam * escala)
	draw_texture_rect(FONDO, destino, false)
	# Degradado oscuro a la izquierda para que el título y los botones se lean.
	var pasos := 24
	for i in pasos:
		# Franjas con bordes enteros: si se solapan se ven rayas verticales.
		var desde := floorf(size.x * 0.5 * i / pasos)
		var hasta := floorf(size.x * 0.5 * (i + 1) / pasos)
		draw_rect(Rect2(desde, 0, hasta - desde, size.y), Color(0.02, 0.03, 0.05, 0.55 * (1.0 - float(i) / pasos)))
	var imagen := _imagen_fondo()
	var lado := escala                  # cada estrella ocupa justo un píxel del fondo
	for e in _estrellas:
		var pixel := Vector2i(Vector2(e.x, e.y) * (tam - Vector2.ONE))
		if imagen.get_pixelv(pixel).v > 0.12:
			continue                        # encima de Marte o del astronauta no hay estrellas
		var brillo := 0.35 + 0.65 * absf(sin(_reloj * 1.3 + e.z))
		draw_rect(Rect2(destino.position + Vector2(pixel) * escala, Vector2(lado, lado)), Color(1, 1, 1, brillo))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if opciones != null:
			opciones.cerrar()
		else:
			_abrir_opciones()
		get_viewport().set_input_as_handled()


func _jugar() -> void:
	EstadoJuego.nueva_partida()
	get_tree().change_scene_to_file(ESCENA_JUEGO)


func _abrir_opciones() -> void:
	if opciones != null:
		return
	opciones = MenuOpciones.new()
	add_child(opciones)
	opciones.tree_exited.connect(func() -> void: opciones = null)
	opciones.iniciar(null, "Opciones")


static var _imagen: Image

static func _imagen_fondo() -> Image:
	if _imagen == null:
		_imagen = FONDO.get_image()
	return _imagen


func _titulo(texto: String, tam: int, color: Color) -> Label:
	var etiqueta := UI.etiqueta_pixel(texto, tam, color)
	_sombrear(etiqueta, 4 if tam > 16 else 2)
	return etiqueta


## Sombra dura abajo a la derecha, como en los rótulos de los juegos de 16 bits.
func _sombrear(etiqueta: Label, desplazamiento: int) -> void:
	etiqueta.add_theme_color_override("font_shadow_color", Color("#05080c"))
	etiqueta.add_theme_constant_override("shadow_offset_x", desplazamiento)
	etiqueta.add_theme_constant_override("shadow_offset_y", desplazamiento)
