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


func _init(nombre_inicial: String, rol_inicial: Enums.Rol, retrato_inicial := "") -> void:
	nombre = nombre_inicial
	rol = rol_inicial
	retrato = retrato_inicial


## Foto de perfil del colono, o null si su perfil no tiene.
func textura_retrato() -> Texture2D:
	var ruta := "res://recursos/sprites/colonos/%s.png" % retrato
	return load(ruta) if retrato != "" and ResourceLoader.exists(ruta) else null


func iniciales() -> String:
	var partes := nombre.split(" ", false)
	if partes.size() < 2:
		return nombre.left(2).to_upper()
	return (partes[0].left(1) + partes[1].left(1)).to_upper()


func color_rol() -> Color:
	return Enums.COLOR_ROL[rol]
