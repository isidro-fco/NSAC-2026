class_name DatosColono
extends RefCounted
## Datos de un colono. Su representación en el mapa es Colono (escenas/colonos).

var nombre := ""
var rol: Enums.Rol = Enums.Rol.INGENIERIA
var estado: Enums.EstadoColono = Enums.EstadoColono.DISPONIBLE
var radiacion := 0.0
var tarea: Dictionary = {}
var soles_restantes := 0
var soles_enfermo := 0
var actividad := "Descansando"
var a_la_intemperie := false


func _init(nombre_inicial: String, rol_inicial: Enums.Rol) -> void:
	nombre = nombre_inicial
	rol = rol_inicial


func iniciales() -> String:
	var partes := nombre.split(" ", false)
	if partes.size() < 2:
		return nombre.left(2).to_upper()
	return (partes[0].left(1) + partes[1].left(1)).to_upper()


func nombre_estado() -> String:
	return Enums.NOMBRE_ESTADO_COLONO[estado]


func nombre_rol() -> String:
	return Enums.NOMBRE_ROL[rol]


func color_rol() -> Color:
	return Enums.COLOR_ROL[rol]
