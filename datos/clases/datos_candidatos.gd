# datos_candidatos.gd
# Recurso con la tripulación inicial y los perfiles que pueden aparecer como candidatos para contratar.

class_name DatosCandidatos
extends Resource
## Tripulación inicial y perfiles que pueden aparecer como candidatos (HU-03).

@export var max_candidatos: int
@export var soles_renovar_candidatos: int
@export var coste_contrato: Dictionary
@export var colonos_iniciales: Array
@export var pool_perfiles: Array
