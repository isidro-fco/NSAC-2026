class_name Enums
extends RefCounted
## Enumeraciones compartidas por todo el proyecto.

enum EstadoCasilla { LIBRE, OCUPADA, BLOQUEADA }
enum Rol { INGENIERIA, ASTROAGRONOMIA, SOPORTE_VITAL, CIENCIA }
enum EstadoColono { DISPONIBLE, EN_MISION, ENFERMO, RETIRADO }
enum Racion { ABUNDANTE, NORMAL, ESTRICTA }
enum ModoMapa { NORMAL, CATALOGO, COLOCANDO, DEMOLICION }

const NOMBRE_ROL := {
	Rol.INGENIERIA: "Ingeniería",
	Rol.ASTROAGRONOMIA: "Astroagronomía",
	Rol.SOPORTE_VITAL: "Soporte Vital",
	Rol.CIENCIA: "Ciencia",
}

const COLOR_ROL := {
	Rol.INGENIERIA: Color("#f2a33a"),
	Rol.ASTROAGRONOMIA: Color("#6cc36a"),
	Rol.SOPORTE_VITAL: Color("#5aa9e6"),
	Rol.CIENCIA: Color("#c58af0"),
}

const NOMBRE_ESTADO_COLONO := {
	EstadoColono.DISPONIBLE: "Disponible",
	EstadoColono.EN_MISION: "En misión",
	EstadoColono.ENFERMO: "Enfermo",
	EstadoColono.RETIRADO: "Retirado",
}

const NOMBRE_RACION := {
	Racion.ABUNDANTE: "Abundante",
	Racion.NORMAL: "Normal",
	Racion.ESTRICTA: "Estricta",
}

const NOMBRE_RECURSO := {
	"oxigeno": "Oxígeno",
	"energia": "Energía",
	"agua": "Agua",
	"comida": "Comida",
	"presupuesto": "Presupuesto",
	"materiales": "Materiales",
}
