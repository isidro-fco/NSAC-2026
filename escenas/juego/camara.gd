# camara.gd
# Cámara del mapa: movimiento con teclado o arrastre, zoom con la rueda y límites para no salir del mapa.

class_name CamaraJuego
extends Camera2D
## Cámara del mapa:
## - WASD o flechas para moverla.
## - Arrastre con el botón derecho o el central del ratón. Un clic derecho sin
##   arrastrar sigue llegando al mapa (cancela la colocación de un módulo).
## - Rueda del ratón para el zoom.
## El mapa ocupa toda la ventana y la interfaz flota encima: el zoom mínimo
## cubre la pantalla entera (sin barras a los lados) y se puede desplazar un poco
## más allá de los bordes para ver lo que tapan la barra superior y los botones.

const VELOCIDAD := 500.0
const ZOOM_MAX := 3.0
const PASO_ZOOM := 1.1
## Píxeles de pantalla que tapan la barra superior y los botones inferiores del HUD.
const TAPADO_ARRIBA := Hud.ALTO_BARRA
const TAPADO_ABAJO := 64.0

## Píxeles que hay que arrastrar con el botón derecho para que no cuente como clic.
const UMBRAL_ARRASTRE := 6.0

## Mientras hay un menú o un diálogo abierto, la cámara no se mueve.
var bloqueada := false
var _arrastre_derecho := 0.0          # píxeles movidos con el botón derecho pulsado


func _ready() -> void:
	get_viewport().size_changed.connect(centrar)
	centrar()


func _process(delta: float) -> void:
	if bloqueada:
		return
	var tecla := func(k: Key) -> float: return float(Input.is_physical_key_pressed(k))
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down") \
		+ Vector2(tecla.call(KEY_D) - tecla.call(KEY_A), tecla.call(KEY_S) - tecla.call(KEY_W))
	if dir != Vector2.ZERO:
		position = _limitar(position + dir.limit_length() * VELOCIDAD * delta / zoom.x)


func _unhandled_input(event: InputEvent) -> void:
	if bloqueada:
		return
	if event is InputEventMouseMotion and event.button_mask & (MOUSE_BUTTON_MASK_MIDDLE | MOUSE_BUTTON_MASK_RIGHT):
		if event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			_arrastre_derecho += event.relative.length()
		position = _limitar(position - event.relative / zoom)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			_arrastre_derecho = 0.0
		elif _arrastre_derecho > UMBRAL_ARRASTRE:
			# Fue un arrastre, no un clic: el mapa no debe cancelar la colocación.
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_cambiar_zoom(PASO_ZOOM)
			MOUSE_BUTTON_WHEEL_DOWN:
				_cambiar_zoom(1.0 / PASO_ZOOM)


## Vuelve a mostrar el mapa entero, centrado.
func centrar() -> void:
	zoom = Vector2.ONE * _zoom_minimo()
	position = _limitar(_tam_mapa() / 2.0)


## Desliza la cámara suavemente hasta un punto del mapa.
func enfocar(punto: Vector2) -> void:
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", _limitar(punto), 0.4)


func _cambiar_zoom(factor: float) -> void:
	var nuevo := clampf(zoom.x * factor, _zoom_minimo(), ZOOM_MAX)
	zoom = Vector2(nuevo, nuevo)
	position = _limitar(position)


func _tam_mapa() -> Vector2:
	return Vector2(GestorCuadricula.ANCHO, GestorCuadricula.ALTO) * GestorCuadricula.TAM_CELDA


## Zoom con el que el mapa cubre toda la ventana (no se puede alejar más).
func _zoom_minimo() -> float:
	var vista := get_viewport_rect().size
	var mapa_px := _tam_mapa()
	return maxf(vista.x / mapa_px.x, vista.y / mapa_px.y)


## Corrige una posición para que la cámara no se salga del mapa. Arriba y abajo
## deja asomar el terreno decorativo lo justo para que el HUD no tape casillas.
func _limitar(posicion: Vector2) -> Vector2:
	var vista := get_viewport_rect().size / zoom
	var mapa_px := _tam_mapa()
	var min_pos := Vector2(vista.x / 2.0, vista.y / 2.0 - TAPADO_ARRIBA / zoom.y)
	var max_pos := Vector2(mapa_px.x - vista.x / 2.0, mapa_px.y - vista.y / 2.0 + TAPADO_ABAJO / zoom.y)
	var limitada := posicion
	limitada.x = mapa_px.x / 2.0 if min_pos.x > max_pos.x else clampf(posicion.x, min_pos.x, max_pos.x)
	limitada.y = (min_pos.y + max_pos.y) / 2.0 if min_pos.y > max_pos.y else clampf(posicion.y, min_pos.y, max_pos.y)
	return limitada
