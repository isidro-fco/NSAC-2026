# gestor_cuadricula.gd
# Cuadrícula del mapa: estado de cada casilla, qué la ocupa y conversiones entre casillas y píxeles.

class_name GestorCuadricula
extends RefCounted
## Estado de las 32x18 casillas del mapa y qué módulo u obstáculo ocupa cada una.

const ANCHO := 32
const ALTO := 18
const TAM_CELDA := 32
const TAM_ZONA_PROTEGIDA := 13

var estados := []                 # estados[y][x] -> Enums.EstadoCasilla
var celdas_modulo := {}           # Vector2i -> Modulo
var celdas_obstaculo := {}        # Vector2i -> Obstaculo


func reiniciar() -> void:
	estados.clear()
	celdas_modulo.clear()
	celdas_obstaculo.clear()
	for y in ALTO:
		var fila := []
		fila.resize(ANCHO)
		fila.fill(Enums.EstadoCasilla.LIBRE)
		estados.append(fila)


# --- Geometría ------------------------------------------------------------

static func dentro_del_mapa(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < ANCHO and c.y < ALTO


static func celda_desde_pixel(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / TAM_CELDA), floori(pos.y / TAM_CELDA))


static func centro_celda(c: Vector2i) -> Vector2:
	return (Vector2(c) + Vector2(0.5, 0.5)) * TAM_CELDA


static func celdas_de(origen: Vector2i, tam: Vector2i) -> Array[Vector2i]:
	var lista: Array[Vector2i] = []
	for dy in tam.y:
		for dx in tam.x:
			lista.append(origen + Vector2i(dx, dy))
	return lista


## 32x18 no tiene celda central exacta; se usa (15, 8).
static func centro_mapa() -> Vector2i:
	return Vector2i(ANCHO / 2 - 1, ALTO / 2 - 1)


static func en_zona_protegida(c: Vector2i) -> bool:
	var centro := centro_mapa()
	var radio := TAM_ZONA_PROTEGIDA / 2
	return absi(c.x - centro.x) <= radio and absi(c.y - centro.y) <= radio


# --- Consultas ------------------------------------------------------------

func estado(c: Vector2i) -> Enums.EstadoCasilla:
	return estados[c.y][c.x]


func es_construible(c: Vector2i) -> bool:
	return dentro_del_mapa(c) and estado(c) == Enums.EstadoCasilla.LIBRE


func es_estructura(c: Vector2i) -> bool:
	return celdas_modulo.has(c)


## Reglas de HU-05: casillas libres y 1 casilla de separación entre módulos.
## Los pasillos quedan exentos: su función es justamente unir módulos.
func puede_colocar(datos: DatosModulo, origen: Vector2i) -> bool:
	for c in celdas_de(origen, datos.tam):
		if not es_construible(c):
			return false
	if datos.es_pasillo():
		return true
	for c in celdas_de(origen - Vector2i.ONE, datos.tam + Vector2i(2, 2)):
		if celdas_modulo.has(c) and not celdas_modulo[c].datos.es_pasillo():
			return false
	return true


## Lo que se puede demoler en la casilla: un obstáculo o un módulo
## construido (los iniciales no). null si no hay nada.
func objetivo_en(c: Vector2i) -> ElementoMapa:
	if celdas_obstaculo.has(c):
		return celdas_obstaculo[c]
	if celdas_modulo.has(c) and not celdas_modulo[c].datos.es_base:
		return celdas_modulo[c]
	return null


# --- Cambios --------------------------------------------------------------

func ocupar_modulo(modulo: Modulo) -> void:
	for c in celdas_de(modulo.origen, modulo.tam_celdas()):
		assert(es_construible(c), "Módulo mal colocado")
		estados[c.y][c.x] = Enums.EstadoCasilla.OCUPADA
		celdas_modulo[c] = modulo


func ocupar_obstaculo(obstaculo: Obstaculo) -> void:
	for c in celdas_de(obstaculo.origen, obstaculo.tam_celdas()):
		estados[c.y][c.x] = Enums.EstadoCasilla.BLOQUEADA
		celdas_obstaculo[c] = obstaculo


func liberar(origen: Vector2i, tam: Vector2i) -> void:
	for c in celdas_de(origen, tam):
		estados[c.y][c.x] = Enums.EstadoCasilla.LIBRE
		celdas_modulo.erase(c)
		celdas_obstaculo.erase(c)
