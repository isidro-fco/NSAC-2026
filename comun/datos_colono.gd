# datos_colono.gd
# Datos de un colono: nombre, rol, estado, radiación, tarea y retrato.

class_name DatosColono
extends RefCounted
## Datos de un colono. Su representación en el mapa es Colono (escenas/colonos).

var nombre := ""
var rol: Enums.Rol = Enums.Rol.INGENIERIA
var estado: Enums.EstadoColono = Enums.EstadoColono.DISPONIBLE
var radiacion := 0.0
var tarea: Dictionary = {}
var soles_restantes := 0               # de la misión o del viaje desde la Tierra
var soles_enfermo := 0
var actividad := "Descansando"
var ubicacion := "interior"           # "interior", "exterior" o "refugio"
var retrato := ""                     # recursos/sprites/colonos/<retrato>.png
var _hoja_civil: Texture2D            # caché de hoja_civil()
var _hoja_civil_lista := false

## Tonos de piel de los retratos (del más claro al más oscuro); el índice + 1
## es el número de la hoja civiles/<hombre|mujer>_piel<N>.png.
const TONOS_PIEL: Array[Color] = [
	Color8(255, 219, 172), Color8(241, 194, 125), Color8(224, 172, 105),
	Color8(198, 134, 66), Color8(141, 85, 36), Color8(92, 58, 30),
]


func _init(nombre_inicial: String, rol_inicial: Enums.Rol, retrato_inicial := "") -> void:
	nombre = nombre_inicial
	rol = rol_inicial
	retrato = retrato_inicial


## Foto de perfil del colono, o null si su perfil no tiene.
func textura_retrato() -> Texture2D:
	var ruta := "res://recursos/sprites/colonos/%s.png" % retrato
	return load(ruta) if retrato != "" and ResourceLoader.exists(ruta) else null


## Hoja de caminata sin traje (polo, pantalón y zapatos) del género y tono de
## piel de su retrato, o null si no tiene retrato. La usa dentro de módulos y pasillos.
func hoja_civil() -> Texture2D:
	if not _hoja_civil_lista:
		_hoja_civil_lista = true
		var textura := textura_retrato()
		if textura != null:
			var genero := "mujer" if retrato.begins_with("mujeres/") else "hombre"
			_hoja_civil = load("res://recursos/sprites/colonos/civiles/%s_piel%d.png"
				% [genero, _tono_piel(textura.get_image()) + 1])
	return _hoja_civil


## Índice en TONOS_PIEL del tono que más se repite en la cara del retrato.
static func _tono_piel(imagen: Image) -> int:
	var cuenta := []
	cuenta.resize(TONOS_PIEL.size())
	cuenta.fill(0)
	for y in range(10, 22):
		for x in range(8, 24):
			var i := TONOS_PIEL.find(imagen.get_pixel(x, y))
			if i >= 0:
				cuenta[i] += 1
	return cuenta.find(cuenta.max())


func iniciales() -> String:
	var partes := nombre.split(" ", false)
	if partes.size() < 2:
		return nombre.left(2).to_upper()
	return (partes[0].left(1) + partes[1].left(1)).to_upper()


func color_rol() -> Color:
	return Enums.COLOR_ROL[rol]
