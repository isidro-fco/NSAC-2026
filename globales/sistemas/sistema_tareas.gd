# sistema_tareas.gd
# Sistema de tareas: lista de tareas disponibles, asignación a colonos y avance de las misiones cada sol.

class_name SistemaTareas
extends Sistema
## Tareas y misiones (HU-02): qué tareas hay, quién puede hacerlas y cómo
## avanzan cada sol. Se usa a través de EstadoJuego.tareas.
## La lista de tareas está en datos/balance.tres (campo "tareas").


func en_curso(id: String) -> bool:
	for c: DatosColono in EstadoJuego.tripulacion.colonos:
		if c.estado == Enums.EstadoColono.EN_MISION and c.tarea["id"] == id:
			return true
	return false


## Tareas que nadie está haciendo ahora.
func disponibles() -> Array[Dictionary]:
	var lista: Array[Dictionary] = []
	for tarea: Dictionary in datos.tareas:
		if not en_curso(tarea["id"]):
			lista.append(tarea)
	return lista


## Colonos libres con el rol que pide la tarea.
func colonos_para(tarea: Dictionary) -> Array[DatosColono]:
	var lista: Array[DatosColono] = []
	for c: DatosColono in EstadoJuego.tripulacion.colonos:
		if c.estado == Enums.EstadoColono.DISPONIBLE and c.rol == tarea["rol"]:
			lista.append(c)
	return lista


func asignar(tarea: Dictionary, c: DatosColono) -> bool:
	if not colonos_para(tarea).has(c) or en_curso(tarea["id"]):
		return false
	c.estado = Enums.EstadoColono.EN_MISION
	c.tarea = tarea
	c.soles_restantes = tarea["soles"]
	EstadoJuego.registrar(Enums.Categoria.ACCION, "Tarea asignada: %s a %s" % [tarea["titulo"], c.nombre], false)
	EstadoJuego.estado_cambiado.emit()
	return true


## Se llama una vez por sol: descuenta un sol a cada misión y entrega las que acaban.
func avanzar_misiones() -> void:
	for c: DatosColono in EstadoJuego.tripulacion.colonos.duplicate():
		if c.estado != Enums.EstadoColono.EN_MISION:
			continue
		var tarea: Dictionary = c.tarea
		c.soles_restantes -= 1
		if tarea["exterior"]:
			EstadoJuego.tripulacion.anadir_radiacion(c, tarea["radiacion"] / tarea["soles"])
		# La radiación puede haberlo enfermado, lo que aborta la misión.
		if c.estado == Enums.EstadoColono.EN_MISION and c.soles_restantes <= 0:
			_completar(c, tarea)


func _completar(c: DatosColono, tarea: Dictionary) -> void:
	var factor := EstadoJuego.almacen.productividad()
	for recurso: String in tarea["recompensa"]:
		var cantidad: float = tarea["recompensa"][recurso] * factor
		if recurso == "investigacion":
			EstadoJuego.economia.investigacion += cantidad
		elif recurso == "presupuesto":
			# HU-09: el pago de la Tierra llega con retraso.
			EstadoJuego.tierra.enviar("Pago: %s" % tarea["titulo"], datos.latencia_fondos, { "presupuesto": cantidad })
		else:
			EstadoJuego.economia.sumar(recurso, cantidad)
	c.estado = Enums.EstadoColono.DISPONIBLE
	c.tarea = {}
	EstadoJuego.registrar(Enums.Categoria.TRIPULACION, "%s completó: %s" % [c.nombre, tarea["titulo"]])
