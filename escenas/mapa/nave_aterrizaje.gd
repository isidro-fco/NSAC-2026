# nave_aterrizaje.gd
# Nave que baja a la plataforma de aterrizaje, deja colonos nuevos o descarga suministros y vuelve a despegar.

class_name NaveAterrizaje
extends Node2D
## Animación de llegada desde la Tierra (HU-09). Es solo visual: los colonos y
## los recursos ya cuentan para la colonia cuando EstadoJuego avisa de su llegada.
##   DESCENSO   baja frenando, con la llama del motor y el tren de aterrizaje fuera
##   EN_TIERRA  levanta polvo, abre la compuerta y salen los colonos (o las cajas)
##   DESPEGUE   sube acelerando hasta salir de la vista y desaparece
## El tiempo sigue a GestorTiempo: se congela en pausa y va al doble con x2.

## Avisa cuando la compuerta está abierta: es el momento de sacar a los colonos.
signal compuerta_abierta(nave: NaveAterrizaje)
signal terminada

enum Tipo { TRIPULACION, CARGA }
enum Fase { DESCENSO, EN_TIERRA, DESPEGUE }

const ALTURA := 280.0                 # px sobre la plataforma al empezar a bajar
const DURACION := {
	Fase.DESCENSO: 2.4,
	Fase.EN_TIERRA: 2.2,
	Fase.DESPEGUE: 1.8,
}
const ABRIR_COMPUERTA := 0.5          # s en tierra antes de abrir
const ALTURA_TREN := 70.0             # por debajo de esta altura saca las patas

const CASCO := Color("#e9e4da")
const CASCO_SOMBRA := Color("#b9b3a8")
const CARGA_CASCO := Color("#9aa3ab")
const CARGA_SOMBRA := Color("#6f7882")
const CONTORNO := Color(0, 0, 0, 0.55)
const POLVO := Color("#f2b27a")

var tipo: Tipo = Tipo.TRIPULACION
var fase: Fase = Fase.DESCENSO
var t := 0.0                          # segundos de juego dentro de la fase
var colonos: Array[DatosColono] = []  # tripulación: salen al abrir la compuerta
var carga := {}                       # carga: recurso -> cantidad (decide el color de las cajas)
var _compuerta_avisada := false
var _polvo: Array[Dictionary] = []    # { "pos", "vel", "vida" }
var _reloj := 0.0                     # para el parpadeo de la luz y la llama


func _init(tipo_nave: Tipo, punto: Vector2) -> void:
	tipo = tipo_nave
	position = punto


## true mientras todavía no toca el suelo (se le pueden añadir colonos).
func bajando() -> bool:
	return fase == Fase.DESCENSO


func _process(delta: float) -> void:
	var dt := GestorTiempo.escalar(delta)
	if dt <= 0.0:
		return
	t += dt
	_reloj += dt
	_mover_polvo(dt)
	if fase == Fase.EN_TIERRA and not _compuerta_avisada and t >= ABRIR_COMPUERTA:
		_compuerta_avisada = true
		compuerta_abierta.emit(self)
	if t >= DURACION[fase]:
		_siguiente_fase()
	queue_redraw()


func _siguiente_fase() -> void:
	t = 0.0
	match fase:
		Fase.DESCENSO:
			fase = Fase.EN_TIERRA
			_levantar_polvo(14)
		Fase.EN_TIERRA:
			fase = Fase.DESPEGUE
			_levantar_polvo(8)
		Fase.DESPEGUE:
			terminada.emit()
			queue_free()


## Altura sobre la plataforma: frena al bajar y acelera al subir.
func altura() -> float:
	var p := clampf(t / DURACION[fase], 0.0, 1.0)
	match fase:
		Fase.DESCENSO:
			return ALTURA * pow(1.0 - p, 2.0)
		Fase.DESPEGUE:
			return ALTURA * pow(p, 2.2)
	return 0.0


## 0..1: lo abierta que está la compuerta (o lo fuera que están las cajas).
func apertura() -> float:
	if fase != Fase.EN_TIERRA:
		return 0.0
	var cerrar_en: float = DURACION[Fase.EN_TIERRA] - 0.4
	if t < ABRIR_COMPUERTA - 0.3:
		return 0.0
	if t > cerrar_en:
		return clampf(1.0 - (t - cerrar_en) / 0.3, 0.0, 1.0)
	return clampf((t - (ABRIR_COMPUERTA - 0.3)) / 0.3, 0.0, 1.0)


# --- Polvo ----------------------------------------------------------------

func _levantar_polvo(n: int) -> void:
	for i in n:
		var dir := Vector2.from_angle(TAU * i / n + randf() * 0.4)
		_polvo.append({ "pos": Vector2(dir.x * 10.0, 6.0 + dir.y * 4.0),
			"vel": Vector2(dir.x * 46.0, dir.y * 14.0), "vida": 1.0 })


func _mover_polvo(dt: float) -> void:
	for p in _polvo:
		p["pos"] += p["vel"] * dt
		p["vel"] *= 0.92
		p["vida"] -= dt * 1.1
	_polvo = _polvo.filter(func(p: Dictionary) -> bool: return p["vida"] > 0.0)


# --- Dibujo ---------------------------------------------------------------

func _draw() -> void:
	var h := altura()
	_dibujar_sombra(h)
	for p in _polvo:
		draw_circle(p["pos"], 2.0 + (1.0 - p["vida"]) * 4.0, Color(POLVO, p["vida"] * 0.6))
	if tipo == Tipo.CARGA:
		_dibujar_cajas()
	var base := Vector2(0, 6.0 - h)       # donde apoyan las patas
	var empuje := 0.0
	if fase == Fase.DESCENSO:
		empuje = 0.6 + 0.4 * (1.0 - h / ALTURA)     # frena más cerca del suelo
	elif fase == Fase.DESPEGUE:
		empuje = 1.0
	if empuje > 0.0:
		_dibujar_llama(base + Vector2(0, -8), empuje)
	_dibujar_patas(base, h)
	if tipo == Tipo.TRIPULACION:
		_dibujar_capsula(base)
	else:
		_dibujar_carguero(base)


func _dibujar_sombra(h: float) -> void:
	var cerca := 1.0 - clampf(h / ALTURA, 0.0, 1.0)
	draw_set_transform(Vector2(0, 7), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 8.0 + 12.0 * cerca, Color(0, 0, 0, 0.12 + 0.25 * cerca))
	draw_set_transform(Vector2.ZERO)


func _dibujar_llama(boca: Vector2, empuje: float) -> void:
	var largo := (10.0 + sin(_reloj * 38.0) * 2.5) * empuje + 4.0
	draw_colored_polygon(PackedVector2Array([boca + Vector2(-5, 0), boca + Vector2(5, 0), boca + Vector2(0, largo)]), UI.ACENTO)
	draw_colored_polygon(PackedVector2Array([boca + Vector2(-2.5, 0), boca + Vector2(2.5, 0), boca + Vector2(0, largo * 0.6)]), UI.ADVERTENCIA)


func _dibujar_patas(base: Vector2, h: float) -> void:
	var fuera := clampf(1.0 - (h - 10.0) / ALTURA_TREN, 0.0, 1.0)    # 1 = tren desplegado
	var ancho := 12.0 + 6.0 * fuera
	for lado: float in [-1.0, 1.0]:
		var cadera := base + Vector2(lado * 9.0, -10.0)
		var pie := base + Vector2(lado * ancho, -2.0 * (1.0 - fuera))
		draw_line(cadera, pie, CARGA_SOMBRA, 2.0)
		draw_rect(Rect2(pie + Vector2(-2.5, -1.0), Vector2(5, 2)), CARGA_SOMBRA)


## Cápsula de tripulación: casco claro, franja naranja, ventanilla y compuerta.
func _dibujar_capsula(base: Vector2) -> void:
	var cuerpo := PackedVector2Array([base + Vector2(-11, -26), base + Vector2(11, -26),
		base + Vector2(15, -9), base + Vector2(-15, -9)])
	draw_colored_polygon(cuerpo, CASCO)
	draw_colored_polygon(PackedVector2Array([base + Vector2(4, -26), base + Vector2(11, -26),
		base + Vector2(15, -9), base + Vector2(6, -9)]), CASCO_SOMBRA)
	draw_rect(Rect2(base + Vector2(-14, -14), Vector2(28, 3)), UI.ACENTO)
	_contorno(cuerpo)
	# Cúpula, antena y luz roja como la de los módulos.
	draw_circle(base + Vector2(0, -27), 9.0, CASCO)
	draw_arc(base + Vector2(0, -27), 9.0, PI, TAU, 16, CONTORNO, 1.0)
	draw_line(base + Vector2(6, -34), base + Vector2(9, -42), CARGA_SOMBRA, 1.0)
	var luz := UI.CRITICO if fmod(_reloj, 0.8) < 0.4 else UI.CRITICO.darkened(0.5)
	draw_circle(base + Vector2(9, -43), 1.8, luz)
	draw_circle(base + Vector2(0, -27), 4.5, UI.FONDO_CLARO)
	draw_circle(base + Vector2(-1.5, -28.5), 1.5, UI.BIEN)
	# Compuerta: se abre hacia abajo como una rampa.
	var abre := apertura()
	var puerta := Rect2(base + Vector2(-5, -22), Vector2(10, 11))
	draw_rect(puerta, UI.FONDO.lerp(Color("#3a4f62"), 1.0 - abre) if abre > 0.0 else CASCO_SOMBRA)
	if abre > 0.0:
		draw_rect(Rect2(base + Vector2(-5, -11), Vector2(10, 9.0 * abre)), CARGA_SOMBRA)
	draw_rect(puerta, CONTORNO, false, 1.0)


## Carguero: más ancho y gris, con franjas amarillas y una bodega.
func _dibujar_carguero(base: Vector2) -> void:
	var cuerpo := PackedVector2Array([base + Vector2(-15, -30), base + Vector2(15, -30),
		base + Vector2(18, -9), base + Vector2(-18, -9)])
	draw_colored_polygon(cuerpo, CARGA_CASCO)
	draw_colored_polygon(PackedVector2Array([base + Vector2(6, -30), base + Vector2(15, -30),
		base + Vector2(18, -9), base + Vector2(8, -9)]), CARGA_SOMBRA)
	for i in 4:
		draw_rect(Rect2(base + Vector2(-16 + i * 9, -13), Vector2(5, 3)), UI.ADVERTENCIA)
	_contorno(cuerpo)
	draw_rect(Rect2(base + Vector2(-6, -36), Vector2(12, 6)), CARGA_CASCO)
	draw_rect(Rect2(base + Vector2(-6, -36), Vector2(12, 6)), CONTORNO, false, 1.0)
	draw_rect(Rect2(base + Vector2(-3, -34), Vector2(6, 2)), UI.FONDO_CLARO)
	var luz := UI.ADVERTENCIA if fmod(_reloj, 0.8) < 0.4 else UI.ADVERTENCIA.darkened(0.5)
	draw_circle(base + Vector2(0, -38), 1.6, luz)
	# Bodega: se ve oscura mientras está abierta.
	var bodega := Rect2(base + Vector2(-8, -26), Vector2(16, 11))
	draw_rect(bodega, CARGA_SOMBRA.lerp(UI.FONDO, apertura()))
	draw_rect(bodega, CONTORNO, false, 1.0)


## Cajas que salen de la bodega con el color de cada recurso y se desvanecen
## al final (se guardan en el almacén).
func _dibujar_cajas() -> void:
	if fase != Fase.EN_TIERRA or t < ABRIR_COMPUERTA:
		return
	var colores: Array[Color] = []
	for recurso: String in carga:
		colores.append(UI.COLOR_RECURSO.get(recurso, UI.ACENTO))
	if colores.is_empty():
		colores.append(UI.ACENTO)
	var huecos := [Vector2(-22, 12), Vector2(22, 12), Vector2(-10, 20), Vector2(10, 20)]
	var salida := clampf((t - ABRIR_COMPUERTA) / 0.5, 0.0, 1.0)
	var fin: float = DURACION[Fase.EN_TIERRA]
	var alfa := clampf((fin - t) / 0.5, 0.0, 1.0)
	for i in huecos.size():
		var pos: Vector2 = Vector2(0, 2).lerp(huecos[i], salida)
		var color: Color = colores[i % colores.size()].darkened(0.15)
		var caja := Rect2(pos + Vector2(-5, -5), Vector2(10, 9))
		draw_rect(caja, Color(color, alfa))
		draw_line(caja.position + Vector2(0, 4), caja.position + Vector2(10, 4), Color(0, 0, 0, 0.35 * alfa), 1.0)
		draw_rect(caja, Color(0, 0, 0, 0.5 * alfa), false, 1.0)


func _contorno(puntos: PackedVector2Array) -> void:
	var cerrado := puntos.duplicate()
	cerrado.append(puntos[0])
	draw_polyline(cerrado, CONTORNO, 1.0)
