extends Node
## Autoload "EstadoJuego": estado de la partida y reglas (recursos, tripulación,
## tareas, cocina y expansiones). No conoce la interfaz ni el mapa: estos
## reaccionan a sus señales. El paso de los soles lo marca GestorTiempo.

signal estado_cambiado
signal sol_terminado
signal colono_agregado(colono: DatosColono)
signal colono_retirado(colono: DatosColono)
signal aviso(texto: String)
signal partida_terminada(motivo: String)

## Valores de balance y perfiles de colonos, editables desde el inspector.
var datos_balance: Resource = load("res://datos/balance.tres")
var datos_candidatos: Resource = load("res://datos/candidatos.tres")
const VITALES := ["oxigeno", "agua", "comida"]

var rng := RandomNumberGenerator.new()

var terminado := false
var modulos_apagados := false

var recursos := {}
var investigacion := 0.0
var historial := {}           # recurso -> [{ "sol", "valor", "cambio" }], máx. 30 soles

var colonos: Array[DatosColono] = []
var retirados: Array[DatosColono] = []
var candidatos: Array[Dictionary] = []
var cuartos: int = datos_balance.cuartos_base
var nivel_almacen := 1
var racion: Enums.Racion = Enums.Racion.NORMAL
var modulos_activos: Array[String] = []

var soles_estricta := 0
var soles_sin_vitales := 0
var soles_para_renovar: int = datos_candidatos.soles_renovar_candidatos


func _ready() -> void:
	GestorTiempo.sol_transcurrido.connect(terminar_sol)
	GestorTiempo.cambiado.connect(estado_cambiado.emit)
	nueva_partida()


func nueva_partida() -> void:
	rng.randomize()
	GestorTiempo.reiniciar()
	terminado = false
	modulos_apagados = false
	recursos = datos_balance.inicial.duplicate()
	investigacion = 0.0
	historial = {}
	for recurso: String in datos_balance.recursos_comando:
		historial[recurso] = []
	colonos.clear()
	retirados.clear()
	cuartos = datos_balance.cuartos_base
	nivel_almacen = 1
	racion = Enums.Racion.NORMAL
	modulos_activos.clear()
	soles_estricta = 0
	soles_sin_vitales = 0
	soles_para_renovar = datos_candidatos.soles_renovar_candidatos
	for perfil: Dictionary in datos_candidatos.colonos_iniciales:
		colonos.append(DatosColono.new(perfil["nombre"], perfil["rol"]))
	_generar_candidatos()


# --- Consultas de recursos ------------------------------------------------

func comida_total() -> float:
	return recursos["comida"] + recursos["raciones"]


func valor(recurso: String) -> float:
	return comida_total() if recurso == "comida" else recursos[recurso]


func capacidad_almacen() -> float:
	return datos_balance.cap_almacen_base + (nivel_almacen - 1) * datos_balance.cap_almacen_por_nivel


func viveres() -> float:
	return recursos["comida"] + recursos["raciones"] + recursos["agua"]


## Capacidad máxima de un recurso; INF si no tiene límite (presupuesto).
func capacidad(recurso: String) -> float:
	match recurso:
		"oxigeno", "energia":
			return datos_balance.cap_tanques
		"agua", "comida", "raciones", "materiales":
			return capacidad_almacen()
	return INF


func colonos_activos() -> int:
	return colonos.size()


func cuartos_libres() -> int:
	return cuartos - colonos.size()


func factor_racion() -> float:
	return datos_balance.factor_racion[racion]


## Unidades de oxígeno, comida o agua que la tripulación consume por sol.
func consumo_vital(recurso: String) -> float:
	var por_colono: float = datos_balance.consumo_por_colono
	if recurso != "oxigeno":
		por_colono *= factor_racion()
	return por_colono * colonos_activos()


func consumo_energia() -> float:
	return modulos_activos.size() * datos_balance.energia_por_modulo


func produccion(recurso: String) -> float:
	var total: float = datos_balance.produccion_base.get(recurso, 0.0)
	for id: String in modulos_activos:
		total += DatosModulo.obtener(id).produce.get(recurso, 0.0)
	return total


func consumo(recurso: String) -> float:
	match recurso:
		"energia":
			return consumo_energia()
		"oxigeno", "agua", "comida":
			return consumo_vital(recurso)
	return 0.0


## Balance proyectado por sol (HU-07).
func balance(recurso: String) -> float:
	return produccion(recurso) - consumo(recurso)


func es_critico(recurso: String) -> bool:
	if recurso == "presupuesto":
		return recursos[recurso] < datos_balance.presupuesto_critico
	return valor(recurso) <= capacidad(recurso) * datos_balance.fraccion_critica


## Soles hasta agotar un recurso con el balance actual; INF si no se agota.
func soles_restantes(recurso: String) -> float:
	var saldo := balance(recurso)
	if saldo >= 0.0:
		return INF
	return valor(recurso) / -saldo


func puede_pagar(dinero: float, materiales: float) -> bool:
	return recursos["presupuesto"] >= dinero and recursos["materiales"] >= materiales


func pagar(dinero: float, materiales: float) -> void:
	recursos["presupuesto"] -= dinero
	recursos["materiales"] -= materiales
	estado_cambiado.emit()


## Suma respetando capacidades; devuelve lo que entró realmente.
func sumar(recurso: String, cantidad: float) -> float:
	var espacio := INF
	match recurso:
		"agua", "comida", "raciones":
			espacio = capacidad_almacen() - viveres()
		"oxigeno", "energia", "materiales":
			espacio = capacidad(recurso) - recursos[recurso]
	var entra := minf(cantidad, maxf(espacio, 0.0))
	recursos[recurso] += entra
	return entra


func _restar(recurso: String, cantidad: float) -> void:
	recursos[recurso] = maxf(recursos[recurso] - cantidad, 0.0)


# --- Ciclo del sol --------------------------------------------------------

func terminar_sol(sol: int) -> void:
	if terminado:
		return
	var antes := {}
	for recurso: String in datos_balance.recursos_comando:
		antes[recurso] = valor(recurso)

	_consumir()
	_producir()
	_avanzar_misiones()
	_actualizar_salud()
	_renovar_candidatos()

	for recurso: String in datos_balance.recursos_comando:
		var serie: Array = historial[recurso]
		serie.append({ "sol": sol, "valor": valor(recurso), "cambio": valor(recurso) - antes[recurso] })
		if serie.size() > datos_balance.soles_historial:
			serie.pop_front()

	_comprobar_derrota()
	sol_terminado.emit()
	estado_cambiado.emit()


## Se permite bajar de 0 hasta producir: así se aplica el saldo neto del sol y
## una reserva con balance negativo sí llega a agotarse.
func _consumir() -> void:
	for recurso: String in ["oxigeno", "agua", "energia"]:
		recursos[recurso] -= consumo(recurso)
	# Primero se comen las raciones preparadas y después la comida cruda.
	var hambre := consumo("comida")
	var de_raciones := minf(hambre, recursos["raciones"])
	recursos["raciones"] -= de_raciones
	recursos["comida"] -= hambre - de_raciones


func _producir() -> void:
	for recurso: String in ["oxigeno", "energia", "agua", "comida", "presupuesto", "materiales"]:
		sumar(recurso, produccion(recurso))
	for recurso: String in ["oxigeno", "energia", "agua", "comida"]:
		recursos[recurso] = maxf(recursos[recurso], 0.0)


func _avanzar_misiones() -> void:
	for c: DatosColono in colonos.duplicate():
		if c.estado != Enums.EstadoColono.EN_MISION:
			continue
		var tarea: Dictionary = c.tarea
		c.soles_restantes -= 1
		if tarea["exterior"]:
			anadir_radiacion(c, tarea["radiacion"] / tarea["soles"])
		# La radiación puede haberlo enfermado, lo que aborta la misión.
		if c.estado == Enums.EstadoColono.EN_MISION and c.soles_restantes <= 0:
			_completar_tarea(c, tarea)


func _completar_tarea(c: DatosColono, tarea: Dictionary) -> void:
	var factor := productividad()
	for recurso: String in tarea["recompensa"]:
		var cantidad: float = tarea["recompensa"][recurso] * factor
		if recurso == "investigacion":
			investigacion += cantidad
		else:
			sumar(recurso, cantidad)
	c.estado = Enums.EstadoColono.DISPONIBLE
	c.tarea = {}
	aviso.emit("%s completó: %s" % [c.nombre, tarea["titulo"]])


func productividad() -> float:
	if racion == Enums.Racion.ABUNDANTE:
		return datos_balance.productividad_abundante
	if racion == Enums.Racion.ESTRICTA and soles_estricta >= datos_balance.soles_estricta_para_riesgo:
		return datos_balance.productividad_debil
	return 1.0


func vitales_agotados() -> Array[String]:
	var agotados: Array[String] = []
	for recurso: String in VITALES:
		if valor(recurso) <= 0.0:
			agotados.append(recurso)
	return agotados


func _actualizar_salud() -> void:
	soles_estricta = soles_estricta + 1 if racion == Enums.Racion.ESTRICTA else 0
	var sin_vitales := not vitales_agotados().is_empty()
	soles_sin_vitales = soles_sin_vitales + 1 if sin_vitales else 0

	var riesgo := 0.0
	if soles_estricta >= datos_balance.soles_estricta_para_riesgo:
		riesgo = datos_balance.prob_enfermar_estricta
	if sin_vitales:
		riesgo = datos_balance.prob_enfermar_sin_vitales

	for c: DatosColono in colonos:
		if c.estado == Enums.EstadoColono.ENFERMO:
			_recuperar(c, sin_vitales)
		elif rng.randf() < riesgo:
			enfermar(c)


func _recuperar(c: DatosColono, sin_vitales: bool) -> void:
	if sin_vitales or c.radiacion >= datos_balance.radiacion_enfermedad:
		return
	var necesarios: int = datos_balance.soles_recuperacion
	if racion == Enums.Racion.ABUNDANTE:
		necesarios -= 1
	c.soles_enfermo += 1
	if c.soles_enfermo >= necesarios:
		c.estado = Enums.EstadoColono.DISPONIBLE
		aviso.emit("%s se ha recuperado" % c.nombre)


func enfermar(c: DatosColono) -> void:
	if c.estado == Enums.EstadoColono.EN_MISION:
		aviso.emit("%s enfermó y abandonó: %s" % [c.nombre, c.tarea["titulo"]])
	else:
		aviso.emit("%s ha enfermado" % c.nombre)
	c.estado = Enums.EstadoColono.ENFERMO
	c.tarea = {}
	c.soles_enfermo = 0


func anadir_radiacion(c: DatosColono, cantidad: float) -> void:
	c.radiacion = minf(c.radiacion + cantidad, datos_balance.radiacion_max)
	if c.radiacion >= datos_balance.radiacion_enfermedad and c.estado != Enums.EstadoColono.ENFERMO:
		enfermar(c)


func _comprobar_derrota() -> void:
	if recursos["energia"] <= 0.0 and balance("energia") < 0.0:
		modulos_apagados = true
		_terminar("La energía se agotó: la base ha quedado a oscuras.")
	elif soles_sin_vitales >= datos_balance.soles_sin_vitales_derrota:
		_terminar("%d soles sin soporte vital: la colonia se ha perdido." % soles_sin_vitales)


func _terminar(motivo: String) -> void:
	terminado = true
	GestorTiempo.detener()
	partida_terminada.emit(motivo)


# --- Tareas (HU-02) -------------------------------------------------------

func tarea_por_id(id: String) -> Dictionary:
	for tarea: Dictionary in datos_balance.tareas:
		if tarea["id"] == id:
			return tarea
	return {}


func tarea_en_curso(id: String) -> bool:
	for c: DatosColono in colonos:
		if c.estado == Enums.EstadoColono.EN_MISION and c.tarea["id"] == id:
			return true
	return false


func tareas_disponibles() -> Array[Dictionary]:
	var lista: Array[Dictionary] = []
	for tarea: Dictionary in datos_balance.tareas:
		if not tarea_en_curso(tarea["id"]):
			lista.append(tarea)
	return lista


func colonos_para_tarea(tarea: Dictionary) -> Array[DatosColono]:
	var lista: Array[DatosColono] = []
	for c: DatosColono in colonos:
		if c.estado == Enums.EstadoColono.DISPONIBLE and c.rol == tarea["rol"]:
			lista.append(c)
	return lista


func asignar_tarea(tarea: Dictionary, c: DatosColono) -> bool:
	if not colonos_para_tarea(tarea).has(c) or tarea_en_curso(tarea["id"]):
		return false
	c.estado = Enums.EstadoColono.EN_MISION
	c.tarea = tarea
	c.soles_restantes = tarea["soles"]
	estado_cambiado.emit()
	return true


# --- Módulo de descanso (HU-03) -------------------------------------------

func enviar_a_la_tierra(c: DatosColono) -> void:
	if not colonos.has(c):
		return
	c.estado = Enums.EstadoColono.RETIRADO
	c.tarea = {}
	colonos.erase(c)
	retirados.append(c)
	colono_retirado.emit(c)
	aviso.emit("%s regresó a la Tierra" % c.nombre)
	estado_cambiado.emit()


func _nombre_usado(nombre: String) -> bool:
	for c: DatosColono in colonos + retirados:
		if c.nombre == nombre:
			return true
	return false


func _generar_candidatos() -> void:
	candidatos.clear()
	var pool: Array = datos_candidatos.pool_perfiles.duplicate()
	# Array.shuffle() usa el generador global: se baraja con el de la partida.
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temporal: Variant = pool[i]
		pool[i] = pool[j]
		pool[j] = temporal
	for perfil: Dictionary in pool:
		if candidatos.size() >= datos_candidatos.max_candidatos:
			break
		if not _nombre_usado(perfil["nombre"]):
			var candidato := perfil.duplicate()
			candidato["coste"] = datos_candidatos.coste_contrato[perfil["rol"]]
			candidatos.append(candidato)


func _renovar_candidatos() -> void:
	soles_para_renovar -= 1
	if soles_para_renovar <= 0:
		soles_para_renovar = datos_candidatos.soles_renovar_candidatos
		_generar_candidatos()


func contratar(candidato: Dictionary) -> bool:
	if cuartos_libres() <= 0 or not candidatos.has(candidato):
		return false
	if not puede_pagar(candidato["coste"], 0):
		return false
	candidatos.erase(candidato)
	var c := DatosColono.new(candidato["nombre"], candidato["rol"])
	colonos.append(c)
	pagar(candidato["coste"], 0)
	colono_agregado.emit(c)
	aviso.emit("%s se unió a la colonia" % c.nombre)
	return true


func puede_expandir_descanso() -> bool:
	return cuartos < datos_balance.cuartos_max \
		and puede_pagar(datos_balance.expandir_descanso_dinero, datos_balance.expandir_descanso_materiales)


func expandir_descanso() -> bool:
	if not puede_expandir_descanso():
		return false
	cuartos += 1
	pagar(datos_balance.expandir_descanso_dinero, datos_balance.expandir_descanso_materiales)
	return true


# --- Almacén y cocina (HU-04) ---------------------------------------------

func fijar_racion(nueva: Enums.Racion) -> void:
	racion = nueva
	estado_cambiado.emit()


## Texto del recurso que impide cocinar la receta, o "" si se puede.
func falta_para_receta(receta: Dictionary) -> String:
	if recursos["comida"] < receta["comida"]:
		return "Falta comida"
	if recursos["agua"] < receta["agua"]:
		return "Falta agua"
	var neto: float = receta["raciones"] - receta["comida"] - receta["agua"]
	if viveres() + neto > capacidad_almacen():
		return "Falta espacio en el almacén"
	return ""


func cocinar(receta: Dictionary) -> bool:
	if falta_para_receta(receta) != "":
		return false
	_restar("comida", receta["comida"])
	_restar("agua", receta["agua"])
	recursos["raciones"] += receta["raciones"]
	estado_cambiado.emit()
	return true


func puede_expandir_almacen() -> bool:
	return nivel_almacen < datos_balance.nivel_almacen_max \
		and puede_pagar(datos_balance.expandir_almacen_dinero, datos_balance.expandir_almacen_materiales)


func expandir_almacen() -> bool:
	if not puede_expandir_almacen():
		return false
	nivel_almacen += 1
	pagar(datos_balance.expandir_almacen_dinero, datos_balance.expandir_almacen_materiales)
	return true


# --- Módulos del mapa -----------------------------------------------------

func registrar_modulo(id: String) -> void:
	if id != "pasillo":
		modulos_activos.append(id)
	estado_cambiado.emit()


func quitar_modulo(id: String) -> void:
	modulos_activos.erase(id)
	estado_cambiado.emit()
