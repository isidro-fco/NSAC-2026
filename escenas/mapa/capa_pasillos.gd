# capa_pasillos.gd
# Dibuja todos los pasillos en una capa bajo los módulos, eligiendo el sprite (recto, esquina, T o cruce) según sus vecinos.

class_name CapaPasillos
extends Node2D
## Capa de pasillos: va antes que el contenedor de módulos, así los módulos
## quedan encima. Cada pasillo elige su sprite según con qué conecta, y donde
## un pasillo llega a un módulo se dibuja una casilla más de pasillo debajo de
## él, para que parezca que el pasillo entra en el edificio.

const TEX_RECTO := preload("res://recursos/sprites/modulos/pasillo.png")    # abierto a izquierda y derecha
const TEX_CRUCE := preload("res://recursos/sprites/modulos/pasillo2.png")   # abierto a los cuatro lados
const TEX_ESQUINA := preload("res://recursos/sprites/modulos/pasillo3.png") # abierto a izquierda y abajo
const TEX_T := preload("res://recursos/sprites/modulos/pasillo4.png")       # abierto a izquierda, derecha y abajo

## Direcciones como bits: N, E, S, O.
const N := 1
const E := 2
const S := 4
const O := 8
const DIRECCIONES := {N: Vector2i.UP, E: Vector2i.RIGHT, S: Vector2i.DOWN, O: Vector2i.LEFT}
const OPUESTA := {N: S, E: O, S: N, O: E}
## Cuartos de vuelta (horario) de la esquina según los dos lados que abre.
const GIRO_ESQUINA := {O | S: 0, N | O: 1, N | E: 2, E | S: 3}
## Cuartos de vuelta (horario) de la T según los tres lados que abre.
const GIRO_T := {O | E | S: 0, N | S | O: 1, O | E | N: 2, N | S | E: 3}

var mapa: Mapa


func _ready() -> void:
	EstadoJuego.partida_terminada.connect(func(_motivo: String) -> void: queue_redraw())


func _draw() -> void:
	var tinte := Color(0.45, 0.45, 0.5) if EstadoJuego.modulos_apagados else Color.WHITE
	var lado := Vector2.ONE * GestorCuadricula.TAM_CELDA
	var pasillos := mapa.modulos_de("pasillo")
	# Primero las casillas que se meten bajo los módulos, luego los pasillos.
	for p: Modulo in pasillos:
		var conexiones := _conexiones(p.origen)
		for bit: int in DIRECCIONES:
			var vecina: Vector2i = p.origen + DIRECCIONES[bit]
			if conexiones & bit and _es_modulo(vecina):
				var giro := 1 if bit in [N, S] else 0
				Modulo.dibujar_textura(self, TEX_RECTO, Rect2(Vector2(vecina) * lado, lado), giro, tinte)
	for p: Modulo in pasillos:
		var sprite := _sprite(_conexiones(p.origen), p.rotacion)
		Modulo.dibujar_textura(self, sprite[0], Rect2(Vector2(p.origen) * lado, lado), sprite[1], tinte)


## Lados (bits N/E/S/O) por los que el pasillo de la casilla `c` conecta. Con
## otro pasillo siempre; con un módulo solo si el pasillo desemboca en él (viene
## del lado opuesto o es un pasillo suelto), para que uno que corre pegado al
## costado de un módulo no se vuelva un cruce.
func _conexiones(c: Vector2i) -> int:
	var con_pasillos := 0
	for bit: int in DIRECCIONES:
		if _es_pasillo(c + DIRECCIONES[bit]):
			con_pasillos |= bit
	var conexiones := con_pasillos
	for bit: int in DIRECCIONES:
		if _es_modulo(c + DIRECCIONES[bit]) and (con_pasillos == 0 or con_pasillos & OPUESTA[bit]):
			conexiones |= bit
	return conexiones


## [textura, cuartos de vuelta] para un pasillo con esas conexiones. Sin
## conexiones usa el giro con que se colocó (tecla Q).
static func _sprite(conexiones: int, rotacion: int) -> Array:
	if conexiones == N | E | S | O:
		return [TEX_CRUCE, 0]
	if GIRO_T.has(conexiones):
		return [TEX_T, GIRO_T[conexiones]]
	if GIRO_ESQUINA.has(conexiones):
		return [TEX_ESQUINA, GIRO_ESQUINA[conexiones]]
	if conexiones & (N | S):
		return [TEX_RECTO, 1]
	if conexiones & (E | O):
		return [TEX_RECTO, 0]
	return [TEX_RECTO, rotacion % 2]


## true si en la casilla se ve pasillo: un pasillo, o la casilla de un módulo
## donde entra un pasillo (la que se dibuja debajo del borde del módulo).
func cubre(c: Vector2i) -> bool:
	if _es_pasillo(c):
		return true
	if not _es_modulo(c):
		return false
	for bit: int in DIRECCIONES:
		var vecina: Vector2i = c - DIRECCIONES[bit]
		if _es_pasillo(vecina) and _conexiones(vecina) & bit:
			return true
	return false


func _es_pasillo(c: Vector2i) -> bool:
	var m: Modulo = mapa.cuadricula.celdas_modulo.get(c)
	return m != null and m.datos.es_pasillo()


func _es_modulo(c: Vector2i) -> bool:
	var m: Modulo = mapa.cuadricula.celdas_modulo.get(c)
	return m != null and not m.datos.es_pasillo()
