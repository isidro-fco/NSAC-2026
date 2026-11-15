# enums.gd
# Enumeraciones y nombres/colores compartidos por todo el proyecto (roles, estados, raciones, modos del mapa).

class_name Enums
extends RefCounted
## Enumeraciones compartidas por todo el proyecto.

enum EstadoCasilla { LIBRE, OCUPADA, BLOQUEADA }
enum Rol { INGENIERIA, ASTROAGRONOMIA, SOPORTE_VITAL, CIENCIA }
enum EstadoColono { DISPONIBLE, EN_MISION, ENFERMO, RETIRADO, EN_VIAJE }
enum Racion { ABUNDANTE, NORMAL, ESTRICTA }
enum ModoMapa { NORMAL, CATALOGO, COLOCANDO, DEMOLICION }
## Categorías de las entradas de la bitácora (HU-10).
enum Categoria { ACCION, EVENTO, TRIPULACION, CURIOSIDAD }

const NOMBRE_CATEGORIA := {
	Categoria.ACCION: "Acción",
	Categoria.EVENTO: "Evento",
	Categoria.TRIPULACION: "Tripulación",
	Categoria.CURIOSIDAD: "Curiosidad",
}

const NOMBRE_ROL := {
	Rol.INGENIERIA: "Ingeniería",
	Rol.ASTROAGRONOMIA: "Astroagronomía",
	Rol.SOPORTE_VITAL: "Soporte Vital",
	Rol.CIENCIA: "Ciencia",
}

const COLOR_ROL := {
	Rol.INGENIERIA: Color("#F2C66D"),
	Rol.ASTROAGRONOMIA: Color("#36C2B4"),
	Rol.SOPORTE_VITAL: Color("#F5F1E8"),
	Rol.CIENCIA: Color("#D98B5F"),
}

const NOMBRE_ESTADO_COLONO := {
	EstadoColono.DISPONIBLE: "Disponible",
	EstadoColono.EN_MISION: "En misión",
	EstadoColono.ENFERMO: "Enfermo",
	EstadoColono.RETIRADO: "Retirado",
	EstadoColono.EN_VIAJE: "En viaje",
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
