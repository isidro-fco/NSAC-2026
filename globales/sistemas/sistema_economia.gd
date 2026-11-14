# sistema_economia.gd
# Sistema de economía: recursos, capacidad, producción, consumo, pagos e historial por sol.

class_name SistemaEconomia
extends Sistema
## Recursos de la colonia: cuánto hay, cuánto cabe y cuánto entra y sale cada sol.
## Se usa a través de EstadoJuego.economia.
## Unidades: oxígeno y comida en kg, agua en L, presupuesto en millones de USD.
## La energía tiene dos medidas: la potencia (kW) que producen los paneles y
## gastan los módulos, y la energía guardada en las baterías (kWh). Cada sol las
## baterías cambian en (producción - consumo) kW x HORAS_POR_SOL horas.

const HORAS_POR_SOL := 24.66

## Recursos que se gastan directamente cada sol (la comida va aparte: raciones primero).
const CONSUMIDOS := ["oxigeno", "agua", "energia"]
## Recursos que se producen cada sol, en este orden (importa por la capacidad del almacén).
const PRODUCIDOS := ["oxigeno", "energia", "agua", "comida", "presupuesto", "materiales"]
## Recursos que pueden quedar por debajo de 0 al consumir y se corrigen tras producir.
const NO_NEGATIVOS := ["oxigeno", "energia", "agua", "comida"]

var recursos := {}                    # "oxigeno", "agua", "comida", "raciones", ...
var investigacion := 0.0
var historial := {}                   # recurso -> [{ "sol", "valor", "cambio" }]
var producido := {}                   # recurso -> total producido en la partida
var modulos_activos: Array[String] = []   # módulos construidos que producen o gastan energía


func reiniciar() -> void:
	recursos = datos.inicial.duplicate()
	investigacion = 0.0
	historial = {}
	producido = {}
	for recurso: String in datos.recursos_comando:
		historial[recurso] = []
	modulos_activos.clear()


# --- Consultas ------------------------------------------------------------

## Cantidad que se muestra al jugador (la comida incluye las raciones).
func valor(recurso: String) -> float:
	return recursos["comida"] + recursos["raciones"] if recurso == "comida" else recursos[recurso]


## Todo lo que ocupa sitio en el almacén.
func viveres() -> float:
	return recursos["comida"] + recursos["raciones"] + recursos["agua"]


## Capacidad máxima de un recurso; INF si no tiene límite (presupuesto).
func capacidad(recurso: String) -> float:
	match recurso:
		"oxigeno":
			return datos.cap_tanques
		"energia":
			return datos.cap_bateria
		"agua", "comida", "raciones":
			return EstadoJuego.almacen.capacidad()
		"materiales":
			return EstadoJuego.almacen.capacidad_materiales()
	return INF


## Producción por sol (energía: kW). El nivel del Módulo de Comando la
## multiplica, salvo la energía (cada panel da sus 20 kW) y el agua reciclada.
func produccion(recurso: String) -> float:
	var total: float = datos.produccion_base.get(recurso, 0.0)
	for id: String in modulos_activos:
		total += DatosModulo.obtener(id).produce.get(recurso, 0.0)
	if recurso != "energia":
		total *= EstadoJuego.comando.multiplicador()
	if recurso == "agua":
		total += agua_reciclada()
	return total


## El soporte vital recicla el 80 % del agua que se consume (con uno basta: más
## no reciclan más agua de la que hay).
func agua_reciclada() -> float:
	if "soporte_vital" not in modulos_activos:
		return 0.0
	return consumo("agua") * datos.fraccion_reciclaje_agua


## Lo que se gasta por sol: la energía (kW) según los módulos construidos;
## oxígeno, agua y comida según los colonos (y la ración, salvo el oxígeno).
func consumo(recurso: String) -> float:
	match recurso:
		"energia":
			var kw := 0.0
			for id: String in modulos_activos:
				kw += DatosModulo.obtener(id).consumo_kw
			return kw
		"oxigeno":
			return datos.consumo_por_colono["oxigeno"] * EstadoJuego.tripulacion.activos()
		"agua", "comida":
			return datos.consumo_por_colono[recurso] * EstadoJuego.almacen.factor_racion() * EstadoJuego.tripulacion.activos()
	return 0.0


## Balance proyectado por sol (HU-07). Energía: kW (ver cambio_por_sol).
func balance(recurso: String) -> float:
	return produccion(recurso) - consumo(recurso)


## Cuánto cambia la reserva en un sol: igual al balance, salvo la energía,
## que pasa de kW a kWh guardados en las baterías.
func cambio_por_sol(recurso: String) -> float:
	return balance(recurso) * (HORAS_POR_SOL if recurso == "energia" else 1.0)


## HU-07: crítico si la reserva está baja o si el balance por sol es negativo.
func es_critico(recurso: String) -> bool:
	if balance(recurso) < 0.0:
		return true
	if recurso == "presupuesto":
		return recursos[recurso] < datos.presupuesto_critico
	return valor(recurso) <= capacidad(recurso) * datos.fraccion_critica


## Soles hasta agotar un recurso con el balance actual; INF si no se agota.
func soles_restantes(recurso: String) -> float:
	var saldo := cambio_por_sol(recurso)
	if saldo >= 0.0:
		return INF
	return valor(recurso) / -saldo


## Recursos vitales (oxígeno, agua, comida) que ya están a cero.
func vitales_agotados() -> Array[String]:
	var agotados: Array[String] = []
	for recurso: String in EstadoJuego.VITALES:
		if valor(recurso) <= 0.0:
			agotados.append(recurso)
	return agotados


# --- Pagos y cambios ------------------------------------------------------

func puede_pagar(dinero: float, materiales: float) -> bool:
	return recursos["presupuesto"] >= dinero and recursos["materiales"] >= materiales


func pagar(dinero: float, materiales: float) -> void:
	recursos["presupuesto"] -= dinero
	recursos["materiales"] -= materiales
	EstadoJuego.estado_cambiado.emit()


## Suma respetando capacidades; devuelve lo que entró realmente.
func sumar(recurso: String, cantidad: float) -> float:
	var espacio := INF
	match recurso:
		"agua", "comida", "raciones":
			espacio = capacidad(recurso) - viveres()
		"oxigeno", "energia", "materiales":
			espacio = capacidad(recurso) - recursos[recurso]
	var entra := minf(cantidad, maxf(espacio, 0.0))
	recursos[recurso] += entra
	return entra


## Resta sin bajar de cero.
func restar(recurso: String, cantidad: float) -> void:
	recursos[recurso] = maxf(recursos[recurso] - cantidad, 0.0)


# --- Ciclo del sol --------------------------------------------------------

## Se permite bajar de 0 hasta producir: así se aplica el saldo neto del sol y
## una reserva con balance negativo sí llega a agotarse.
func consumir() -> void:
	for recurso: String in CONSUMIDOS:
		recursos[recurso] -= consumo(recurso) * _horas(recurso)
	# Primero se comen las raciones preparadas y después la comida cruda.
	var hambre := consumo("comida")
	var de_raciones := minf(hambre, recursos["raciones"])
	recursos["raciones"] -= de_raciones
	recursos["comida"] -= hambre - de_raciones


func producir() -> void:
	for recurso: String in PRODUCIDOS:
		producido[recurso] = producido.get(recurso, 0.0) + sumar(recurso, produccion(recurso) * _horas(recurso))
	for recurso: String in NO_NEGATIVOS:
		recursos[recurso] = maxf(recursos[recurso], 0.0)


## Horas que dura la producción o el consumo de un sol: la energía va en kW
## y se guarda en kWh; lo demás ya viene por sol.
func _horas(recurso: String) -> float:
	return HORAS_POR_SOL if recurso == "energia" else 1.0


## Valores actuales de los recursos que se guardan en el historial.
func foto() -> Dictionary:
	var valores := {}
	for recurso: String in datos.recursos_comando:
		valores[recurso] = valor(recurso)
	return valores


## Apunta en el historial cómo terminó el sol, comparando con `antes` (ver foto()).
func anotar_historial(sol: int, antes: Dictionary) -> void:
	for recurso: String in datos.recursos_comando:
		var serie: Array = historial[recurso]
		serie.append({ "sol": sol, "valor": valor(recurso), "cambio": valor(recurso) - antes[recurso] })
		if serie.size() > datos.soles_historial:
			serie.pop_front()


# --- Módulos del mapa -----------------------------------------------------

func registrar_modulo(id: String) -> void:
	if id not in ["pasillo", "plataforma"]:
		modulos_activos.append(id)
	EstadoJuego.estado_cambiado.emit()


func quitar_modulo(id: String) -> void:
	modulos_activos.erase(id)
	EstadoJuego.estado_cambiado.emit()
