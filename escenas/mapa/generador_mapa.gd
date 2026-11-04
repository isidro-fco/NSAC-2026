class_name GeneradorMapa
extends RefCounted
## HU-01: coloca los módulos iniciales y siembra obstáculos fuera de la
## zona protegida de 13x13 alrededor del centro.

const SEPARACION := 2
const TEX_OBSTACULOS: Array[Texture2D] = [
	preload("res://recursos/sprites/obstaculos/obstaculo1.png"),
	preload("res://recursos/sprites/obstaculos/obstaculo2.png"),
	preload("res://recursos/sprites/obstaculos/crater1.png"),
]
const TEX_CRATER_GRANDE := preload("res://recursos/sprites/obstaculos/crater2.png")

var densidad_obstaculos := 0.15
var fraccion_crater_grande := 0.1


func generar(mapa: Mapa, rng: RandomNumberGenerator) -> void:
	_colocar_modulos_iniciales(mapa, rng)
	_generar_obstaculos(mapa, rng)


func _colocar_modulos_iniciales(mapa: Mapa, rng: RandomNumberGenerator) -> void:
	var origen_comando := GestorCuadricula.centro_mapa() - Vector2i.ONE
	mapa.agregar_modulo("comando", origen_comando)
	var direcciones := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	var dir: Vector2i = direcciones[rng.randi_range(0, 3)]
	var paso: int = DatosModulo.obtener("comando").tam.x + SEPARACION
	mapa.agregar_modulo("descanso", origen_comando + dir * paso)
	mapa.agregar_modulo("almacen", origen_comando - dir * paso)


func _generar_obstaculos(mapa: Mapa, rng: RandomNumberGenerator) -> void:
	var cuadricula := mapa.cuadricula
	for y in GestorCuadricula.ALTO:
		for x in GestorCuadricula.ANCHO:
			var c := Vector2i(x, y)
			if not cuadricula.es_construible(c) or GestorCuadricula.en_zona_protegida(c):
				continue
			if rng.randf() >= densidad_obstaculos:
				continue
			if rng.randf() < fraccion_crater_grande and _cabe_crater(cuadricula, c):
				mapa.agregar_obstaculo(c, Vector2i(2, 2), TEX_CRATER_GRANDE)
			else:
				var textura := TEX_OBSTACULOS[rng.randi_range(0, TEX_OBSTACULOS.size() - 1)]
				mapa.agregar_obstaculo(c, Vector2i.ONE, textura)


func _cabe_crater(cuadricula: GestorCuadricula, origen: Vector2i) -> bool:
	for c in GestorCuadricula.celdas_de(origen, Vector2i(2, 2)):
		if not cuadricula.es_construible(c) or GestorCuadricula.en_zona_protegida(c):
			return false
	return true
