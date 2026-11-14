# viento.gd
# Ambientación: motas de polvo y estelas que arrastra el viento marciano, con ráfagas y algún remolino de polvo.

class_name Viento
extends Node2D
## Solo visual. Las partículas viven en coordenadas del mapa, pero solo dentro
## de lo que ve la cámara: al salir por un lado reaparecen por el lado de donde
## sopla el viento, y su cantidad se ajusta al tamaño de la vista (con el zoom
## alejado hay más mapa a la vista y, por tanto, más partículas).
## El tiempo sigue a GestorTiempo: el viento se detiene en pausa y va más rápido con x2.

## Sobre el suelo naranja se leen mejor las motas casi blancas y algunas muy oscuras.
const POLVO := Color("#ffe9d2")
const POLVO_CLARO := Color("#fff6ea")
const POLVO_OSCURO := Color("#8f4220")
## Partículas por píxel² de mapa visible, y tope para no cargar el dibujo.
const DENSIDAD := 1.0 / 2600.0
const MIN_PARTICULAS := 40
const MAX_PARTICULAS := 420
## Fuerza media del viento en px/s y cuánto varía su dirección (radianes).
const FUERZA := 34.0
const OSCILACION_DIRECCION := 0.25
## Cada cuántos segundos (de juego) puede cruzar un remolino de polvo.
const ESPERA_REMOLINO := Vector2(35.0, 75.0)
const DURACION_REMOLINO := 16.0

var tiempo := 0.0
var particulas: Array[Dictionary] = []   # { "pos", "estela", "oscura", "factor", "tam", "alfa", "fase", "onda" }
var remolino := {}                       # { "pos", "vida" } mientras cruza uno
var _siguiente_remolino := 20.0


func _process(delta: float) -> void:
	var dt := GestorTiempo.escalar(delta)
	if dt <= 0.0:
		return
	tiempo += dt
	var vista := _vista()
	var viento := direccion_viento() * FUERZA * rafaga()
	_ajustar_cantidad(vista)
	for p in particulas:
		var onda: float = sin(tiempo * 2.0 + p["fase"]) * p["onda"]
		p["pos"] += (viento * p["factor"] + Vector2(0, onda)) * dt
		if not vista.grow(240.0).has_point(p["pos"]):
			_colocar(p, vista, viento, false)       # lejos (la cámara se movió): reparte por la vista
		elif not vista.grow(16.0).has_point(p["pos"]):
			_colocar(p, vista, viento, true)        # salió por un borde: entra por el otro
	_mover_remolino(dt, vista, viento)
	queue_redraw()


## Dirección del viento: casi siempre hacia la derecha, girando despacio.
func direccion_viento() -> Vector2:
	return Vector2.from_angle(0.12 + sin(tiempo * 0.05) * OSCILACION_DIRECCION)


## Intensidad de 0.45 a 1.35: dos ondas lentas que se suman dan ráfagas irregulares.
func rafaga() -> float:
	return clampf(0.8 + 0.3 * sin(tiempo * 0.37) + 0.2 * sin(tiempo * 1.13 + 1.7), 0.45, 1.35)


## Rectángulo del mapa que ve la cámara ahora mismo.
func _vista() -> Rect2:
	return get_viewport().get_canvas_transform().affine_inverse() * get_viewport_rect()


func _ajustar_cantidad(vista: Rect2) -> void:
	var objetivo := clampi(int(vista.get_area() * DENSIDAD), MIN_PARTICULAS, MAX_PARTICULAS)
	while particulas.size() < objetivo:
		var p := _nueva()
		_colocar(p, vista, Vector2.RIGHT, false)
		particulas.append(p)
	if particulas.size() > objetivo:
		particulas.resize(objetivo)


## 3 de cada 4 son motas que flotan; el resto, estelas rápidas que marcan las ráfagas.
func _nueva() -> Dictionary:
	var estela := randf() < 0.25
	return {
		"pos": Vector2.ZERO,
		"estela": estela,
		"oscura": not estela and randf() < 0.3,
		"factor": randf_range(1.3, 1.9) if estela else randf_range(0.55, 1.05),
		"tam": randf_range(10.0, 26.0) if estela else float([1, 2, 2, 3].pick_random()),
		"alfa": randf_range(0.3, 0.55) if estela else randf_range(0.4, 0.75),
		"fase": randf() * TAU,
		"onda": randf_range(2.0, 8.0),
	}


## Coloca una partícula en un punto al azar de la vista, o en el borde de donde sopla el viento.
func _colocar(p: Dictionary, vista: Rect2, viento: Vector2, en_borde: bool) -> void:
	var pos := vista.position + Vector2(randf() * vista.size.x, randf() * vista.size.y)
	if en_borde:
		if absf(viento.x) >= absf(viento.y):
			pos.x = vista.position.x - 8.0 if viento.x > 0.0 else vista.end.x + 8.0
		else:
			pos.y = vista.position.y - 8.0 if viento.y > 0.0 else vista.end.y + 8.0
	p["pos"] = pos


# --- Remolino de polvo (como los que limpiaron los paneles de Spirit y Opportunity)

func _mover_remolino(dt: float, vista: Rect2, viento: Vector2) -> void:
	if remolino.is_empty():
		_siguiente_remolino -= dt
		if _siguiente_remolino <= 0.0:
			_siguiente_remolino = randf_range(ESPERA_REMOLINO.x, ESPERA_REMOLINO.y)
			# Nace ya dentro de la vista (en el tercio de donde sopla) para que se vea cruzar.
			var inicio := vista.position + Vector2(randf_range(0.05, 0.35), randf_range(0.3, 0.85)) * vista.size
			remolino = { "pos": inicio, "vida": 0.0 }
		return
	remolino["vida"] += dt
	remolino["pos"] += (viento * 0.55 + Vector2(0, sin(tiempo * 0.8) * 6.0)) * dt
	if remolino["vida"] > DURACION_REMOLINO or remolino["pos"].x > vista.end.x + 40.0:
		remolino = {}


func _draw() -> void:
	var fuerza := rafaga()
	var dir := direccion_viento()
	for p in particulas:
		var pos: Vector2 = p["pos"]
		if p["estela"]:
			var color := Color(POLVO_CLARO, p["alfa"] * fuerza)
			draw_line(pos, pos - dir * p["tam"] * fuerza, color, 1.0)
		else:
			draw_rect(Rect2(pos, Vector2.ONE * p["tam"]), Color(POLVO_OSCURO if p["oscura"] else POLVO, p["alfa"]))
	if not remolino.is_empty():
		_dibujar_remolino()


## Columna de polvo que gira: más ancha arriba, con su sombra en el suelo.
func _dibujar_remolino() -> void:
	var vida: float = remolino["vida"]
	var alfa := clampf(minf(vida, DURACION_REMOLINO - vida) / 2.0, 0.0, 1.0)
	var base: Vector2 = remolino["pos"]
	draw_set_transform(base + Vector2(0, 4), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 16.0, Color(0, 0, 0, 0.18 * alfa))
	draw_set_transform(Vector2.ZERO)
	const PISOS := 44
	for i in PISOS:
		var altura := float(i) / PISOS
		var angulo := tiempo * 7.0 + i * 0.9
		var radio := 4.0 + altura * 18.0
		var punto := base + Vector2(cos(angulo) * radio, sin(angulo) * radio * 0.3 - altura * 54.0)
		var tam := 3.0 if i % 4 == 0 else 2.0
		var color := POLVO_OSCURO if i % 5 == 0 else POLVO
		draw_rect(Rect2(punto, Vector2.ONE * tam), Color(color, (0.85 - altura * 0.45) * alfa))
