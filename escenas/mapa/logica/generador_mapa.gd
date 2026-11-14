# generador_mapa.gd
# Genera el mapa inicial: coloca los módulos base, la plataforma de aterrizaje y los obstáculos.

class_name GeneradorMapa
extends RefCounted
## HU-01: coloca los módulos iniciales y siembra obstáculos fuera de la
## zona protegida de 13x13 alrededor del centro. La plataforma de aterrizaje
## (HU-09) va en perpendicular al eje descanso-comando-almacén.

const SEPARACION := 2
const TEX_OBSTACULOS: Array[Texture2D] = [
	preload("res://recursos/sprites/obstaculos/obstaculo1.png"),
	preload("res://recursos/sprites/obstaculos/obstaculo2.png"),
	preload("res://recursos/sprites/obstaculos/crater1.png"),
]
const TEX_CRATER_GRANDE := preload("res://recursos/sprites/obstaculos/crater2.png")


static func generar(mapa: Mapa, rng: RandomNumberGenerator) -> void:
	var origen_comando := GestorCuadricula.centro_mapa() - Vector2i.ONE
	mapa.agregar_modulo("comando", origen_comando)
	var dir: Vector2i = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT][rng.randi_range(0, 3)]
	var paso: int = DatosModulo.obtener("comando").tam.x + SEPARACION
	mapa.agregar_modulo("descanso", origen_comando + dir * paso)
	mapa.agregar_modulo("almacen", origen_comando - dir * paso)
	var perpendicular := Vector2i(dir.y, dir.x) * (1 if rng.randf() < 0.5 else -1)
	mapa.agregar_modulo("plataforma", origen_comando + perpendicular * paso)

	for y in GestorCuadricula.ALTO:
		for x in GestorCuadricula.ANCHO:
			var c := Vector2i(x, y)
			if not _libre(c, mapa.cuadricula) or rng.randf() >= mapa.densidad_obstaculos:
				continue
			var grande := Vector2i(2, 2)
			if rng.randf() < mapa.fraccion_crater_grande \
					and GestorCuadricula.celdas_de(c, grande).all(_libre.bind(mapa.cuadricula)):
				mapa.agregar_obstaculo(c, grande, TEX_CRATER_GRANDE)
			else:
				mapa.agregar_obstaculo(c, Vector2i.ONE, TEX_OBSTACULOS[rng.randi_range(0, TEX_OBSTACULOS.size() - 1)])


static func _libre(c: Vector2i, cuadricula: GestorCuadricula) -> bool:
	return cuadricula.es_construible(c) and not GestorCuadricula.en_zona_protegida(c)
