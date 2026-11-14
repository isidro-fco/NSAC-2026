# sistema_clima_espacial.gd
# Clima espacial real: convierte los eventos de NASA DONKI en eventos del juego, en orden cronológico.

class_name SistemaClimaEspacial
extends Sistema
## Los eventos del Sol del juego no se inventan: salen de ServicioNasa (DONKI en
## vivo, guardado o archivo) en el mismo orden en que ocurrieron. Cada pocos
## soles llega el siguiente:
##   - Importantes (abren una ventana con dos opciones):
##       FLR clase X, CME rápida, SEP y GST con Kp >= 7.
##   - Noticias (solo bitácora, sin pausar): llamaradas M5+, GST Kp 5-6, CME más
##     lentas, IPS, HSS, MPC y RBE.
## Cada ventana separa "lo que pasó de verdad" (fecha, valor y fuente) de
## "lo que pasa en la colonia" (el efecto de juego).
## Una CME no llega al instante: con su velocidad real se calcula en cuántos
## soles llega a Marte (tormenta_pendiente) y la tormenta solar empieza entonces.
## Con la variable de entorno NASA_DESACTIVADO=1 no hace nada (pruebas).
## Se usa a través de EstadoJuego.clima.

const PRIMER_EVENTO := 3              # soles hasta el primer evento real
const ESPERA_IMPORTANTE := Vector2i(4, 9)
const ESPERA_NOTICIA := 1
const MAX_IMPORTANTES := 25
const MAX_NOTICIAS := 15
const DURACION_TORMENTA := 2          # soles de radiación alta tras una CME o SEP
const VELOCIDAD_CME_IMPORTANTE := 800.0
const VELOCIDAD_CME_NOTICIA := 500.0

var baraja: Array[Dictionary] = []    # eventos reales que faltan, del más antiguo al más reciente
var mostrados := 0
var soles_para_real := PRIMER_EVENTO
## { "soles", "duracion", "blindaje", "titulo" } mientras una CME viaja hacia Marte.
var tormenta_pendiente: Dictionary = {}


func _init() -> void:
	ServicioNasa.datos_actualizados.connect(_al_llegar_datos)


func reiniciar() -> void:
	mostrados = 0
	soles_para_real = PRIMER_EVENTO
	tormenta_pendiente = {}
	_armar_baraja()


func activo() -> bool:
	return OS.get_environment("NASA_DESACTIVADO") != "1"


## true si la tormenta solar ya viene de datos reales (y no debe salir al azar).
func usa_datos_reales() -> bool:
	return activo() and (mostrados > 0 or not baraja.is_empty())


## Si llegan datos en vivo y aún no se mostró ningún evento real, se usan esos.
func _al_llegar_datos() -> void:
	if mostrados == 0:
		_armar_baraja()
		EstadoJuego.estado_cambiado.emit()


func _armar_baraja() -> void:
	baraja.clear()
	if not activo():
		return
	var importantes: Array[Dictionary] = []
	var noticias: Array[Dictionary] = []
	for e: Dictionary in ServicioNasa.eventos:
		if es_importante(e):
			importantes.append(e)
		elif es_noticia(e):
			noticias.append(e)
	var orden := func(a: Dictionary, b: Dictionary) -> bool:
		return a["fecha"] + a["hora"] < b["fecha"] + b["hora"]
	importantes.sort_custom(orden)
	noticias.sort_custom(orden)
	baraja.append_array(_repartidos(importantes, MAX_IMPORTANTES))
	baraja.append_array(_repartidos(noticias, MAX_NOTICIAS))
	baraja.sort_custom(orden)


## Hasta `maximo` elementos repartidos a lo largo de toda la lista (no solo los primeros).
static func _repartidos(lista: Array[Dictionary], maximo: int) -> Array[Dictionary]:
	if lista.size() <= maximo:
		return lista
	var r: Array[Dictionary] = []
	for i in maximo:
		r.append(lista[int(i * lista.size() / float(maximo))])
	return r


static func es_importante(e: Dictionary) -> bool:
	match e["tipo"]:
		"FLR":
			return str(e["valor"]).begins_with("X")
		"CME":
			return e["velocidad"] >= VELOCIDAD_CME_IMPORTANTE or e["llega_marte"] != "" or e["llega_tierra"] != ""
		"SEP":
			return true
		"GST":
			return e["kp"] >= 7.0
	return false


static func es_noticia(e: Dictionary) -> bool:
	match e["tipo"]:
		"FLR":
			var valor := str(e["valor"])
			return valor.begins_with("M") and valor.substr(1).to_float() >= 5.0
		"CME":
			return e["velocidad"] >= VELOCIDAD_CME_NOTICIA
		"GST":
			return e["kp"] >= 5.0
		"IPS", "HSS", "MPC", "RBE":
			return true
	return false


# --- Cada sol -----------------------------------------------------------------

## La nube de plasma se acerca a Marte; al llegar empieza la tormenta solar.
func avanzar() -> void:
	if tormenta_pendiente.is_empty():
		return
	tormenta_pendiente["soles"] -= 1
	if tormenta_pendiente["soles"] > 0:
		return
	var eventos := EstadoJuego.eventos
	eventos.tormenta_soles = tormenta_pendiente["duracion"]
	eventos.blindaje = tormenta_pendiente["blindaje"]
	EstadoJuego.registrar(Enums.Categoria.EVENTO, "¡Llegó la nube del Sol! Tormenta solar durante %s" % UI.soles(eventos.tormenta_soles))
	tormenta_pendiente = {}


func programar_tormenta(soles: int, duracion: int, blindaje: float) -> void:
	tormenta_pendiente = { "soles": soles, "duracion": duracion, "blindaje": blindaje }


## Evento real que toca este sol para mostrar en una ventana, o {} si no toca
## (las noticias van directo a la bitácora).
func siguiente() -> Dictionary:
	if not activo():
		return {}
	if baraja.is_empty() and mostrados > 0:
		_armar_baraja()              # se acabaron: vuelven a empezar (siguen siendo reales)
	if baraja.is_empty():
		return {}
	soles_para_real -= 1
	if soles_para_real > 0:
		return {}
	var e: Dictionary = baraja.pop_front()
	mostrados += 1
	if not es_importante(e):
		EstadoJuego.registrar(Enums.Categoria.EVENTO, "Dato real NASA (%s): %s" % [Donki.fecha_texto(e["fecha"]), _texto_noticia(e)], false)
		soles_para_real = ESPERA_NOTICIA
		return {}
	soles_para_real = EstadoJuego.rng.randi_range(ESPERA_IMPORTANTE.x, ESPERA_IMPORTANTE.y)
	return crear_evento(e)


# --- Textos (para niños de 7 a 12 años) --------------------------------------------

## Evento con el formato de datos/balance.tres más la clave "real" para la ventana.
static func crear_evento(e: Dictionary) -> Dictionary:
	var evento: Dictionary
	match e["tipo"]:
		"FLR":
			evento = _llamarada(e)
		"CME":
			evento = _nube_de_plasma(e)
		"SEP":
			evento = _lluvia_de_particulas(e)
		_:
			evento = _tormenta_magnetica(e)
	evento["id"] = "real_%s_%s" % [e["tipo"], e["fecha"]]
	evento["real"]["fecha"] = Donki.fecha_texto(e["fecha"]) + (" a las %s (hora universal)" % e["hora"] if e["hora"] != "" else "")
	evento["real"]["fuente"] = e.get("fuente", "NASA DONKI (Centro de Modelado Coordinado de la Comunidad, CCMC)")
	evento["real"]["enlace"] = e["enlace"] if e["enlace"] != "" else ServicioNasa.PAGINA_DONKI
	evento["real"]["origen"] = ServicioNasa.texto_origen()
	evento["real"]["de_nasa"] = not e.has("fuente") or "NASA" in str(e["fuente"])
	return evento


## Quién lo registró: los eventos de DONKI son de la NASA; los del archivo
## curado dicen su propia fuente (que puede no ser la NASA).
static func _quien(e: Dictionary) -> String:
	return "La NASA" if not e.has("fuente") or "NASA" in str(e["fuente"]) else "Un observatorio"


static func _llamarada(e: Dictionary) -> Dictionary:
	var que_paso := "%s registró esta llamarada de clase %s." % [_quien(e), e["valor"]]
	if e["nota"] != "":
		que_paso += " " + e["nota"]
	return {
		"titulo": "¡Llamarada solar clase %s!" % e["valor"],
		"descripcion": "Una llamarada solar es un destello gigante en el Sol. Las de clase X son las más fuertes que existen. Su luz llega a Marte en unos 13 minutos y estorba las antenas de la base.",
		"real": { "tipo": "Llamarada solar (FLR)", "valor": e["valor"], "que_paso": que_paso },
		"opciones": [
			{ "texto": "Esperar a que pase la interferencia", "retraso_envios": 1 },
			{ "texto": "Gastar energía en reforzar la señal", "recursos": { "energia": -500 } },
		],
	}


static func _nube_de_plasma(e: Dictionary) -> Dictionary:
	var calculo := calcular_llegada(e)
	var que_paso := "%s vio salir del Sol esta nube" % _quien(e)
	que_paso += " a %d km/s." % roundi(e["velocidad"]) if e["velocidad"] > 0.0 else "."
	if e["nota"] != "":
		que_paso += " " + e["nota"]
	que_paso += "\n" + calculo["cuenta"]
	if e["llega_marte"] != "":
		que_paso += "\nLa simulación WSA-ENLIL de la NASA calculó que esta nube también llegaría a Marte."
	else:
		que_paso += "\nEn el juego imaginamos que viaja hacia nuestra base en Marte."
	var soles: int = calculo["soles"]
	return {
		"titulo": "¡Una nube del Sol viene en camino!",
		"descripcion": "El Sol lanzó una eyección de masa coronal (CME): una nube enorme de plasma. Cuando llegue a Marte, la radiación subirá durante %s." % UI.soles(DURACION_TORMENTA),
		"real": { "tipo": "Eyección de masa coronal (CME)", "valor": e["valor"], "que_paso": que_paso },
		"opciones": [
			{ "texto": "Preparar el blindaje desde ya", "recursos": { "energia": -1000 }, "tormenta": DURACION_TORMENTA, "tormenta_en": soles, "blindaje": 0.5 },
			{ "texto": "Seguir trabajando y refugiarse al llegar", "tormenta": DURACION_TORMENTA, "tormenta_en": soles },
		],
	}


static func _lluvia_de_particulas(e: Dictionary) -> Dictionary:
	var que_paso := "%s registró partículas energéticas solares (SEP)." % _quien(e)
	if e["nota"] != "":
		que_paso += " " + e["nota"]
	if e["llega_marte"] == "" and e["lugar"] != "Marte":
		que_paso += "\nLas midieron naves que vigilan el Sol, no en Marte. En el juego imaginamos que también llegan a Marte."
	return {
		"titulo": "¡Lluvia de partículas del Sol!",
		"descripcion": "Partículas del Sol llegaron a Marte casi a la velocidad de la luz. Marte no tiene un escudo magnético como la Tierra, así que la radiación sube de golpe. ¡Al refugio blindado!",
		"real": { "tipo": "Partículas energéticas solares (SEP)", "valor": e["valor"], "que_paso": que_paso },
		"opciones": [
			{ "texto": "Reforzar el blindaje de los módulos", "recursos": { "energia": -1000 }, "tormenta": DURACION_TORMENTA, "blindaje": 0.5 },
			{ "texto": "Mantener la operación normal", "tormenta": DURACION_TORMENTA },
		],
	}


static func _tormenta_magnetica(e: Dictionary) -> Dictionary:
	var que_paso := "%s registró esta tormenta geomagnética con índice Kp %s (la escala va de 0 a 9)." % [_quien(e), Donki._num(e["kp"])]
	if e["nota"] != "":
		que_paso += " " + e["nota"]
	return {
		"titulo": "Tormenta magnética en la Tierra (Kp %s)" % Donki._num(e["kp"]),
		"descripcion": "El viento del Sol sacudió el escudo magnético de la Tierra y se vieron auroras. Marte no tiene ese escudo: por eso la colonia necesita refugios. Los satélites de la Tierra están ocupados y los envíos pueden tardar.",
		"real": { "tipo": "Tormenta geomagnética (GST)", "valor": e["valor"], "que_paso": que_paso },
		"opciones": [
			{ "texto": "Esperar a que se calmen los satélites", "retraso_envios": 1 },
			{ "texto": "Pagar un canal de emergencia", "recursos": { "presupuesto": -60 } },
		],
	}


## Soles que tarda la nube en llegar a Marte y la cuenta para mostrarla:
## con su velocidad, con la llegada prevista a Marte, o escalando lo que tardó
## en llegar a la Tierra (Marte está 1.5 veces más lejos del Sol).
static func calcular_llegada(e: Dictionary) -> Dictionary:
	var horas := 0.0
	var cuenta := ""
	if e["llega_marte"] != "":
		horas = maxf(Donki.horas_entre(e["fecha"] + "T" + (e["hora"] if e["hora"] != "" else "00:00"), e["llega_marte"]), 1.0)
		cuenta = "Según la simulación, tardaría unas %d horas en llegar a Marte." % roundi(horas)
	elif e["velocidad"] > 0.0:
		horas = Donki.KM_SOL_MARTE / e["velocidad"] / 3600.0
		cuenta = "Cuenta: 228 millones de km ÷ %d km/s ≈ %d horas de viaje hasta Marte." % [roundi(e["velocidad"]), roundi(horas)]
	elif e["llega_tierra"] != "":
		var dias := maxf(roundf(Donki.horas_entre(e["fecha"], e["llega_tierra"]) / 24.0), 1.0)
		horas = dias * 24.0 * 1.5
		cuenta = "Tardó %d %s en llegar a la Tierra. Marte está 1.5 veces más lejos del Sol: %d × 1.5 ≈ %d horas." % [
			dias, "día" if dias == 1.0 else "días", roundi(dias * 24.0), roundi(horas)]
	else:
		horas = 48.0
		cuenta = "No se midió su velocidad; en el juego tarda unas 48 horas."
	var soles := clampi(ceili(horas / Donki.HORAS_POR_SOL), 1, 5)
	cuenta += " Eso es %s en Marte." % UI.soles(soles)
	return { "soles": soles, "horas": horas, "cuenta": cuenta }


static func _texto_noticia(e: Dictionary) -> String:
	match e["tipo"]:
		"FLR":
			return "llamarada solar clase %s. Más débil que una X, pero igual brilla muchísimo." % e["valor"]
		"CME":
			return "salió del Sol una nube de plasma a %d km/s." % roundi(e["velocidad"])
		"GST":
			return "tormenta magnética en la Tierra con Kp %s. Hubo auroras." % Donki._num(e["kp"])
		"IPS":
			return "una onda de choque del viento solar pasó por %s." % (e["lugar"] if e["lugar"] != "" else "el espacio")
		"HSS":
			return "viento solar muy rápido salió de un agujero coronal del Sol."
		"MPC":
			return "el viento solar empujó el escudo magnético de la Tierra y algunos satélites quedaron fuera de él."
		"RBE":
			return "los cinturones de radiación que rodean la Tierra se llenaron de partículas."
	return "actividad en el Sol."
