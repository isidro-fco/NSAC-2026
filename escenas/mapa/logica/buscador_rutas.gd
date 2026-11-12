class_name BuscadorRutas
extends RefCounted
## HU-06: AStarGrid2D que prefiere módulos y pasillos. Los colonos solo pisan
## el exterior si no hay ruta interior, y nunca a más de 2 casillas de la base.

const MARGEN_EXTERIOR := 2
const PESO_EXTERIOR := 1000.0

var astar := AStarGrid2D.new()


func _init() -> void:
	astar.region = Rect2i(0, 0, GestorCuadricula.ANCHO, GestorCuadricula.ALTO)
	astar.cell_size = Vector2(GestorCuadricula.TAM_CELDA, GestorCuadricula.TAM_CELDA)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()


func actualizar(cuadricula: GestorCuadricula) -> void:
	var cerca := {}
	for c: Vector2i in cuadricula.celdas_modulo:
		for dy in range(-MARGEN_EXTERIOR, MARGEN_EXTERIOR + 1):
			for dx in range(-MARGEN_EXTERIOR, MARGEN_EXTERIOR + 1):
				cerca[c + Vector2i(dx, dy)] = true
	for y in GestorCuadricula.ALTO:
		for x in GestorCuadricula.ANCHO:
			var c := Vector2i(x, y)
			astar.set_point_solid(c, cuadricula.celdas_obstaculo.has(c) or not cerca.has(c))
			astar.set_point_weight_scale(c, 1.0 if cuadricula.es_estructura(c) else PESO_EXTERIOR)


func es_transitable(c: Vector2i) -> bool:
	return GestorCuadricula.dentro_del_mapa(c) and not astar.is_point_solid(c)


## Casillas a recorrer, sin incluir la de partida.
func ruta(desde: Vector2i, hasta: Vector2i) -> Array[Vector2i]:
	var resultado: Array[Vector2i] = []
	if not es_transitable(desde) or not es_transitable(hasta):
		return resultado
	var camino := astar.get_id_path(desde, hasta)
	for i in range(1, camino.size()):
		resultado.append(camino[i])
	return resultado


func casilla_transitable_cercana(c: Vector2i) -> Vector2i:
	var mejor := c
	var mejor_distancia := INF
	for y in GestorCuadricula.ALTO:
		for x in GestorCuadricula.ANCHO:
			var candidata := Vector2i(x, y)
			if es_transitable(candidata):
				var distancia := Vector2(candidata - c).length_squared()
				if distancia < mejor_distancia:
					mejor = candidata
					mejor_distancia = distancia
	return mejor


## Casillas transitables fuera de la base (trabajos de exterior).
func casillas_exteriores(cuadricula: GestorCuadricula) -> Array[Vector2i]:
	var opciones: Array[Vector2i] = []
	for y in GestorCuadricula.ALTO:
		for x in GestorCuadricula.ANCHO:
			var c := Vector2i(x, y)
			if es_transitable(c) and not cuadricula.es_estructura(c):
				opciones.append(c)
	return opciones
