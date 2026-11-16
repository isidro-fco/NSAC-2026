# donki.gd
# Convierte las respuestas de NASA DONKI (FLR, CME, SEP, GST, IPS, HSS, MPC, RBE) a un formato común del juego.

class_name Donki
extends RefCounted
## DONKI (Space Weather Database Of Notifications, Knowledge, Information) es la
## base de datos de clima espacial de la NASA (CCMC, Goddard). Cada tipo de
## evento llega con campos distintos; aquí se pasan todos a un evento común:
##   { "tipo", "id", "fecha": "AAAA-MM-DD", "hora": "HH:MM" (UTC), "valor",
##     "velocidad" (km/s), "kp", "llega_marte" (ISO), "llega_tierra" (AAAA-MM-DD),
##     "lugar", "nota", "enlace" }
## Los campos que no aplican quedan vacíos ("" o 0). El archivo curado
## (datos/nasa/eventos_curados.json) ya viene en este formato.

const TIPOS := ["FLR", "CME", "SEP", "GST", "IPS", "HSS", "MPC", "RBE"]
const MESES := ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio",
	"agosto", "septiembre", "octubre", "noviembre", "diciembre"]
## Distancia media Sol-Marte (1.52 unidades astronómicas) y duración de un sol.
const KM_SOL_MARTE := 227_900_000.0
const HORAS_POR_SOL := 24.66


## Pasa la lista de un endpoint de DONKI (ya leída del JSON) a eventos comunes.
static func normalizar(tipo: String, lista: Variant) -> Array[Dictionary]:
	var eventos: Array[Dictionary] = []
	if typeof(lista) != TYPE_ARRAY:
		return eventos                   # DONKI responde vacío cuando no hubo eventos
	for crudo: Variant in lista:
		if typeof(crudo) != TYPE_DICTIONARY:
			continue
		var e := _evento_vacio(tipo)
		var d: Dictionary = crudo
		e["enlace"] = str(d.get("link", ""))
		match tipo:
			"FLR":
				e["id"] = str(d.get("flrID", ""))
				_poner_fecha(e, d["peakTime"] if d.get("peakTime") != null else d.get("beginTime"))
				e["valor"] = str(d.get("classType", ""))
				e["nota"] = Idioma.t("Región activa %s") % d["activeRegionNum"] if d.get("activeRegionNum") != null else ""
			"CME":
				e["id"] = str(d.get("activityID", ""))
				_poner_fecha(e, d.get("startTime", ""))
				_leer_analisis_cme(e, d.get("cmeAnalyses", []))
			"SEP":
				e["id"] = str(d.get("sepID", ""))
				_poner_fecha(e, d.get("eventTime", ""))
				e["nota"] = _instrumentos(d)
			"GST":
				e["id"] = str(d.get("gstID", ""))
				_poner_fecha(e, d.get("startTime", ""))
				for kp: Variant in _lista(d.get("allKpIndex")):
					if typeof(kp) == TYPE_DICTIONARY and kp.get("kpIndex") != null:
						e["kp"] = maxf(e["kp"], float(kp["kpIndex"]))
				e["valor"] = "Kp %s" % _num(e["kp"])
			"IPS":
				e["id"] = str(d.get("activityID", ""))
				_poner_fecha(e, d.get("eventTime", ""))
				e["lugar"] = str(d.get("location", ""))
			"HSS", "MPC", "RBE":
				var claves := { "HSS": "hssID", "MPC": "mpcID", "RBE": "rbeID" }
				e["id"] = str(d.get(claves[tipo], ""))
				_poner_fecha(e, d.get("eventTime", ""))
				e["nota"] = _instrumentos(d)
		if e["fecha"] != "":
			eventos.append(e)
	return eventos


static func _evento_vacio(tipo: String) -> Dictionary:
	return { "tipo": tipo, "id": "", "fecha": "", "hora": "", "valor": "", "velocidad": 0.0,
		"kp": 0.0, "llega_marte": "", "llega_tierra": "", "lugar": "", "nota": "", "enlace": "" }


## "2024-05-14T16:51Z" -> fecha "2024-05-14" y hora "16:51".
static func _poner_fecha(e: Dictionary, iso: Variant) -> void:
	var texto := str(iso) if iso != null else ""
	if texto.length() >= 10:
		e["fecha"] = texto.substr(0, 10)
	if texto.length() >= 16:
		e["hora"] = texto.substr(11, 5)


## Velocidad del análisis más preciso y, si la simulación WSA-ENLIL la calculó,
## la llegada prevista a Marte (y a la Tierra).
static func _leer_analisis_cme(e: Dictionary, analisis: Variant) -> void:
	for a: Variant in _lista(analisis):
		if typeof(a) != TYPE_DICTIONARY:
			continue
		var preciso: bool = a.get("isMostAccurate", false) == true
		if a.get("speed") != null and (preciso or e["velocidad"] == 0.0):
			e["velocidad"] = float(a["speed"])
			e["valor"] = "%d km/s" % roundi(e["velocidad"])
		for simulacion: Variant in _lista(a.get("enlilList")):
			if typeof(simulacion) != TYPE_DICTIONARY:
				continue
			var tierra: Variant = simulacion.get("estimatedShockArrivalTime")
			if tierra != null and e["llega_tierra"] == "":
				e["llega_tierra"] = str(tierra).substr(0, 10)
			for impacto: Variant in _lista(simulacion.get("impactList")):
				if typeof(impacto) == TYPE_DICTIONARY and "mars" in str(impacto.get("location", "")).to_lower():
					e["llega_marte"] = str(impacto.get("arrivalTime", ""))


## DONKI pone null donde no hay datos: se trata como lista vacía.
static func _lista(valor: Variant) -> Array:
	return valor if typeof(valor) == TYPE_ARRAY else []


static func _instrumentos(d: Dictionary) -> String:
	var nombres := PackedStringArray()
	for i: Variant in _lista(d.get("instruments")):
		if typeof(i) == TYPE_DICTIONARY and i.has("displayName"):
			nombres.append(str(i["displayName"]))
	return Idioma.t("Lo midió: %s.") % ", ".join(nombres) if not nombres.is_empty() else ""


# --- Utilidades para los textos -------------------------------------------

## "2024-05-14" -> "14 de mayo de 2024" (en inglés, "May 14, 2024").
static func fecha_texto(fecha: String) -> String:
	var partes := fecha.split("-")
	if partes.size() != 3:
		return fecha
	var mes := Idioma.t(MESES[clampi(int(partes[1]) - 1, 0, 11)])
	if Idioma.en_ingles():
		return "%s %d, %s" % [mes, int(partes[2]), partes[0]]
	return "%d de %s de %s" % [int(partes[2]), mes, partes[0]]


## Horas entre dos fechas ISO ("2024-05-09T09:36Z" o "2024-05-10").
static func horas_entre(desde: String, hasta: String) -> float:
	var a := Time.get_unix_time_from_datetime_string(_iso_completo(desde))
	var b := Time.get_unix_time_from_datetime_string(_iso_completo(hasta))
	return (b - a) / 3600.0


static func _iso_completo(texto: String) -> String:
	var limpio := texto.replace("Z", "")
	if limpio.length() == 10:
		limpio += "T00:00:00"
	elif limpio.length() == 16:
		limpio += ":00"
	return limpio


static func _num(valor: float) -> String:
	return str(int(valor)) if is_equal_approx(valor, roundf(valor)) else "%.2f" % valor
