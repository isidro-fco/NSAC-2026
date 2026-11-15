# sistema_tripulacion.gd
# Sistema de tripulación: colonos, salud y radiación, cuartos, regreso a la Tierra y reclutamiento.

class_name SistemaTripulacion
extends Sistema
## Colonos (HU-03): quién vive en la base, su salud y radiación, los cuartos
## del módulo de descanso y el reclutamiento de candidatos.
## Se usa a través de EstadoJuego.tripulacion.

var colonos: Array[DatosColono] = []      # en la colonia
var en_viaje: Array[DatosColono] = []     # contratados que vienen de la Tierra (HU-09)
var retirados: Array[DatosColono] = []    # enviados a la Tierra
var candidatos: Array[Dictionary] = []    # se pueden contratar
var cuartos := 0
var soles_sin_vitales := 0                # soles seguidos sin oxígeno, agua o comida
var soles_para_renovar := 0               # soles hasta cambiar los candidatos
var perfiles: DatosCandidatos:
	get: return EstadoJuego.datos_candidatos


func reiniciar() -> void:
	colonos.clear()
	en_viaje.clear()
	retirados.clear()
	cuartos = datos.cuartos_base
	soles_sin_vitales = 0
	soles_para_renovar = perfiles.soles_renovar_candidatos
	for perfil: Dictionary in perfiles.colonos_iniciales:
		colonos.append(DatosColono.new(perfil["nombre"], perfil["rol"], perfil.get("retrato", "")))
	_generar_candidatos()


func activos() -> int:
	return colonos.size()


## Los que vienen de viaje ya tienen su cuarto reservado.
func cuartos_libres() -> int:
	return cuartos - colonos.size() - en_viaje.size()


# --- Salud ----------------------------------------------------------------

## Se llama una vez por sol: enferma o cura a los colonos según la situación.
func actualizar_salud() -> void:
	var sin_vitales := not EstadoJuego.economia.vitales_agotados().is_empty()
	soles_sin_vitales = soles_sin_vitales + 1 if sin_vitales else 0

	var riesgo := 0.0
	if EstadoJuego.almacen.soles_estricta >= datos.soles_estricta_para_riesgo:
		riesgo = datos.prob_enfermar_estricta
	if sin_vitales:
		riesgo = datos.prob_enfermar_sin_vitales

	for c: DatosColono in colonos:
		if c.estado == Enums.EstadoColono.ENFERMO:
			_recuperar(c, sin_vitales)
		elif EstadoJuego.rng.randf() < riesgo:
			enfermar(c)


func _recuperar(c: DatosColono, sin_vitales: bool) -> void:
	if sin_vitales or c.radiacion >= datos.radiacion_enfermedad:
		return
	var necesarios: int = datos.soles_recuperacion
	if EstadoJuego.almacen.racion == Enums.Racion.ABUNDANTE:
		necesarios -= 1
	c.soles_enfermo += 1
	if c.soles_enfermo >= necesarios:
		c.estado = Enums.EstadoColono.DISPONIBLE
		EstadoJuego.registrar(Enums.Categoria.TRIPULACION, "%s se ha recuperado" % c.nombre)


func enfermar(c: DatosColono) -> void:
	EstadoJuego.curiosidades.disparar("colono:enfermo")
	if c.estado == Enums.EstadoColono.EN_MISION:
		EstadoJuego.registrar(Enums.Categoria.TRIPULACION, "Diagnóstico: %s enfermó y abandonó %s" % [c.nombre, c.tarea["titulo"]])
	else:
		EstadoJuego.registrar(Enums.Categoria.TRIPULACION, "Diagnóstico: %s ha enfermado" % c.nombre)
	c.estado = Enums.EstadoColono.ENFERMO
	c.tarea = {}
	c.soles_enfermo = 0


func anadir_radiacion(c: DatosColono, cantidad: float) -> void:
	var antes := c.radiacion
	c.radiacion = minf(c.radiacion + cantidad, datos.radiacion_max)
	# Pico de radiación: al cruzar la mitad del umbral de enfermedad.
	var umbral := datos.radiacion_enfermedad / 2.0
	if antes < umbral and c.radiacion >= umbral:
		EstadoJuego.registrar(Enums.Categoria.TRIPULACION, "Pico de radiación: %s supera %d de dosis" % [c.nombre, int(umbral)])
	if c.radiacion >= datos.radiacion_enfermedad and c.estado != Enums.EstadoColono.ENFERMO:
		enfermar(c)


# --- Salidas y contrataciones ---------------------------------------------

func enviar_a_la_tierra(c: DatosColono) -> void:
	if not colonos.has(c):
		return
	c.estado = Enums.EstadoColono.RETIRADO
	c.tarea = {}
	colonos.erase(c)
	retirados.append(c)
	EstadoJuego.colono_retirado.emit(c)
	EstadoJuego.registrar(Enums.Categoria.ACCION, "%s regresó a la Tierra" % c.nombre)
	EstadoJuego.estado_cambiado.emit()


func _nombre_usado(nombre: String) -> bool:
	for c: DatosColono in colonos + en_viaje + retirados:
		if c.nombre == nombre:
			return true
	return false


## Baraja `lista` en su sitio con el azar de la partida (Array.shuffle() usa el
## generador global y rompería las partidas con semilla).
static func _barajar(lista: Array) -> void:
	for i in range(lista.size() - 1, 0, -1):
		var j := EstadoJuego.rng.randi_range(0, i)
		var temporal: Variant = lista[i]
		lista[i] = lista[j]
		lista[j] = temporal


func _generar_candidatos() -> void:
	candidatos.clear()
	var pool: Array = perfiles.pool_perfiles.duplicate()
	_barajar(pool)
	for perfil: Dictionary in pool:
		if candidatos.size() >= perfiles.max_candidatos:
			break
		if not _nombre_usado(perfil["nombre"]):
			var candidato := perfil.duplicate()
			candidato["coste"] = perfiles.coste_contrato[perfil["rol"]]
			candidatos.append(candidato)


## Se llama una vez por sol: cada cierto tiempo cambian los candidatos.
func renovar_candidatos() -> void:
	soles_para_renovar -= 1
	if soles_para_renovar <= 0:
		soles_para_renovar = perfiles.soles_renovar_candidatos
		_generar_candidatos()


func contratar(candidato: Dictionary) -> bool:
	if cuartos_libres() <= 0 or not candidatos.has(candidato):
		return false
	if not EstadoJuego.economia.puede_pagar(candidato["coste"], 0):
		return false
	candidatos.erase(candidato)
	var c := DatosColono.new(candidato["nombre"], candidato["rol"], candidato.get("retrato", ""))
	c.estado = Enums.EstadoColono.EN_VIAJE
	c.soles_restantes = datos.soles_viaje_colono
	en_viaje.append(c)
	EstadoJuego.economia.pagar(candidato["coste"], 0)
	EstadoJuego.tierra.enviar(c.nombre, c.soles_restantes, {}, c)
	EstadoJuego.registrar(Enums.Categoria.ACCION, "Contratado: %s (llegará en %d soles)" % [c.nombre, c.soles_restantes])
	return true


## HU-09: el colono contratado aterriza en la plataforma y ya puede trabajar.
func llegar(c: DatosColono) -> void:
	en_viaje.erase(c)
	c.estado = Enums.EstadoColono.DISPONIBLE
	colonos.append(c)
	EstadoJuego.colono_agregado.emit(c)
	EstadoJuego.registrar(Enums.Categoria.TRIPULACION, "%s llegó a la plataforma de aterrizaje" % c.nombre)


# --- Cuartos del módulo de descanso ---------------------------------------

func puede_ampliar_cuartos() -> bool:
	return cuartos < datos.cuartos_max \
		and EstadoJuego.economia.puede_pagar(datos.expandir_descanso_dinero, datos.expandir_descanso_materiales)


func ampliar_cuartos() -> bool:
	if not puede_ampliar_cuartos():
		return false
	cuartos += 1
	EstadoJuego.economia.pagar(datos.expandir_descanso_dinero, datos.expandir_descanso_materiales)
	EstadoJuego.registrar(Enums.Categoria.ACCION, "Módulo de descanso ampliado a %d cuartos" % cuartos, false)
	return true
