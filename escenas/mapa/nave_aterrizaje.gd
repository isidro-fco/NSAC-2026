# nave_aterrizaje.gd
# Nave que baja a la plataforma de aterrizaje, deja colonos nuevos o descarga suministros y vuelve a despegar.

class_name NaveAterrizaje
extends Node2D
## Animación de llegada desde la Tierra (HU-09). Es solo visual: los colonos y
## los recursos ya cuentan para la colonia cuando EstadoJuego avisa de su llegada.
##   DESCENSO   baja frenando, con la llama del motor y el tren de aterrizaje fuera
##   EN_TIERRA  levanta polvo, abre la compuerta y los colonos salen de uno en uno
##              por la escotilla y bajan la rampa (o salen las cajas); espera al último
##   DESPEGUE   sube acelerando hasta salir de la vista y desaparece
## El tiempo sigue a GestorTiempo: se congela en pausa y va al doble con x2.
## Sonidos: aterrizaje al empezar a bajar, despegue al subir y, en la nave de
## carga, las cajas al caer.

## Un colono terminó de bajar la rampa: `punto` es dónde queda, en coordenadas del mapa.
signal colono_desembarcado(datos: DatosColono, punto: Vector2)
signal terminada

enum Tipo { TRIPULACION, CARGA }
enum Fase { DESCENSO, EN_TIERRA, DESPEGUE }

const ALTURA := 280.0                 # px sobre la plataforma al empezar a bajar
const DURACION := {
	Fase.DESCENSO: 2.4,
	Fase.EN_TIERRA: 2.2,
	Fase.DESPEGUE: 1.8,
}
const ABRIR_COMPUERTA := 0.5          # s en tierra hasta que la compuerta está abierta del todo
const SALIDA_INTERVALO := 0.55        # s entre un colono y el siguiente
const BAJADA := 0.9                   # s que tarda un colono de la escotilla al suelo
const ESPERA_CIERRE := 0.6            # s con la compuerta abierta tras bajar el último
const ESCOTILLA := Vector2(0, -11)    # pies del colono al asomar (con la nave en tierra)
const PIE_RAMPA := Vector2(0, -3)
const ESCALA_ESCOTILLA := 0.55        # el colono sale pequeño y crece al acercarse
const ALTURA_TREN := 70.0             # por debajo de esta altura saca las patas

const SPRITE_CAPSULA := preload("res://recursos/sprites/modulos/capsula_orion.png")
const CAPSULA_ORIGEN := Vector2(-16, -39)    # esquina del sprite: el escudo térmico queda en base.y - 9
const CARGA_CASCO := Color("#9aa3ab")
const CARGA_SOMBRA := Color("#6f7882")
const CONTORNO := Color(0, 0, 0, 0.55)
const POLVO := Color("#f2b27a")

var tipo: Tipo = Tipo.TRIPULACION
var fase: Fase = Fase.DESCENSO
var t := 0.0                          # segundos de juego dentro de la fase
var colonos: Array[DatosColono] = []  # tripulación: salen al abrir la compuerta
var _desembarcados := 0               # cuántos colonos ya bajaron la rampa
var carga := {}                       # carga: recurso -> cantidad (decide el color de las cajas)
var _cajas_sonaron := false
var _polvo: Array[Dictionary] = []    # { "pos", "vel", "vida" }
var _reloj := 0.0                     # para el parpadeo de la luz y la llama


func _init(tipo_nave: Tipo, punto: Vector2) -> void:
	tipo = tipo_nave
	position = punto


func _ready() -> void:
	GestorAudio.reproducir("aterrizaje")


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
	if fase == Fase.EN_TIERRA:
		_avisar_desembarcos()
	if tipo == Tipo.CARGA and fase == Fase.EN_TIERRA and not _cajas_sonaron and t >= ABRIR_COMPUERTA + 0.4:
		_cajas_sonaron = true
		GestorAudio.reproducir("caja_cayendo")
	if t >= duracion():
		_siguiente_fase()
	queue_redraw()


func _siguiente_fase() -> void:
	t = 0.0
	match fase:
		Fase.DESCENSO:
			fase = Fase.EN_TIERRA
			_levantar_polvo(14)
			# Los que se volvieron a la Tierra durante el viaje no bajan.
			colonos = colonos.filter(func(c: DatosColono) -> bool:
				return EstadoJuego.tripulacion.colonos.has(c))
		Fase.EN_TIERRA:
			fase = Fase.DESPEGUE
			_levantar_polvo(8)
			GestorAudio.reproducir("despegue")
		Fase.DESPEGUE:
			terminada.emit()
			queue_free()


## Altura sobre la plataforma: frena al bajar y acelera al subir.
func altura() -> float:
	var p := clampf(t / duracion(), 0.0, 1.0)
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
	var cerrar_en: float = duracion() - 0.4
	if t < ABRIR_COMPUERTA - 0.3:
		return 0.0
	if t > cerrar_en:
		return clampf(1.0 - (t - cerrar_en) / 0.3, 0.0, 1.0)
	return clampf((t - (ABRIR_COMPUERTA - 0.3)) / 0.3, 0.0, 1.0)


## Segundos de la fase actual; en tierra, la tripulación alarga la espera hasta que baja el último.
func duracion() -> float:
	if fase != Fase.EN_TIERRA or colonos.is_empty():
		return DURACION[fase]
	var ultimo := _salida(colonos.size() - 1) + BAJADA + ESPERA_CIERRE
	return maxf(DURACION[Fase.EN_TIERRA], ultimo)


# --- Desembarco -----------------------------------------------------------

## Momento (s en tierra) en que el colono `i` asoma por la escotilla.
func _salida(i: int) -> float:
	return ABRIR_COMPUERTA + i * SALIDA_INTERVALO


## 0..1: cuánto ha bajado el colono `i` (fuera de rango si no ha salido o ya bajó).
func _progreso_bajada(i: int) -> float:
	return (t - _salida(i)) / BAJADA


## Dónde se queda el colono `i` al pie de la nave, repartidos en fila.
func _punto_final(i: int) -> Vector2:
	return Vector2((i - (colonos.size() - 1) / 2.0) * 9.0, 10.0)


func _avisar_desembarcos() -> void:
	while _desembarcados < colonos.size() and _progreso_bajada(_desembarcados) >= 1.0:
		colono_desembarcado.emit(colonos[_desembarcados], position + _punto_final(_desembarcados))
		_desembarcados += 1


## Colonos que están bajando: salen por la escotilla, bajan la rampa y caminan
## hasta su sitio. Al terminar, el mapa crea el Colono de verdad en ese punto.
func _dibujar_colonos_bajando() -> void:
	for i in range(_desembarcados, colonos.size()):
		var p := _progreso_bajada(i)
		if p < 0.0 or p >= 1.0:
			continue
		var pos: Vector2
		if p < 0.55:
			pos = ESCOTILLA.lerp(PIE_RAMPA, p / 0.55)
		else:
			pos = PIE_RAMPA.lerp(_punto_final(i), (p - 0.55) / 0.45)
		var escala := lerpf(ESCALA_ESCOTILLA, 1.0, smoothstep(0.0, 0.7, p))
		var fotograma := int((t - _salida(i)) * Colono.FPS_CAMINATA) % Colono.FOTOGRAMAS
		var region := Rect2(fotograma * Colono.TAM_FOTOGRAMA, Colono.Direccion.ABAJO * Colono.TAM_FOTOGRAMA,
			Colono.TAM_FOTOGRAMA, Colono.TAM_FOTOGRAMA)
		var rect := Rect2(Colono.DESFASE_SPRITE, Vector2(Colono.TAM_FOTOGRAMA, Colono.TAM_FOTOGRAMA))
		draw_set_transform(pos, 0.0, Vector2(escala, escala))
		draw_texture_rect_region(Colono.HOJA, rect, region)
		draw_texture_rect_region(Colono.HOJA_ACENTO, rect, region, colonos[i].color_rol())
	draw_set_transform(Vector2.ZERO)


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
		_dibujar_colonos_bajando()
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


## Cápsula de tripulación inspirada en la Orion: sprite de 32x32 con la escotilla
## lateral; la compuerta abierta y la luz se pintan encima.
func _dibujar_capsula(base: Vector2) -> void:
	draw_texture(SPRITE_CAPSULA, base + CAPSULA_ORIGEN)
	var luz := UI.CRITICO if fmod(_reloj, 0.8) < 0.4 else UI.CRITICO.darkened(0.5)
	draw_circle(base + Vector2(0, -39), 1.2, luz)
	# Compuerta: el hueco se oscurece y cae una rampa hacia abajo.
	var abre := apertura()
	if abre > 0.0:
		var hueco := Rect2(base + Vector2(-3, -24), Vector2(6, 7))
		draw_rect(hueco, UI.FONDO.lerp(Color("#3a4f62"), 1.0 - abre))
		draw_rect(Rect2(base + Vector2(-4, -17), Vector2(8, 8.0 * abre)), CARGA_SOMBRA)
		draw_rect(Rect2(base + Vector2(-4, -17), Vector2(8, 8.0 * abre)), CONTORNO, false, 1.0)


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
	var fin := duracion()
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
