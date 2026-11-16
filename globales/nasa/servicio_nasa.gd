# servicio_nasa.gd
# Autoload ServicioNasa: consulta NASA DONKI en vivo y, si no hay internet, usa lo último guardado o el archivo del juego.

extends Node
## De dónde salen los eventos solares reales del juego, en orden de preferencia:
##   1. EN_VIVO   consulta a DONKI de los últimos DIAS_EN_VIVO días (al arrancar).
##   2. GUARDADO  la última consulta en vivo que salió bien (user://donki_guardado.json).
##   3. ARCHIVO   datos/nasa/archivo_donki.json (descargado con herramientas/descargar_donki.py)
##                o, si no existe, datos/nasa/eventos_curados.json (curado a mano).
## Nunca se presenta como "en vivo" algo que no se acaba de consultar: la interfaz
## muestra siempre `texto_origen()`.
## La consulta en vivo va a la API de DONKI del CCMC (no pide clave). Desde el
## 30 de septiembre de 2026 está en ccmc.gsfc.nasa.gov/DONKI-API y acepta como
## máximo 60 días por consulta, así que se pide en tramos de DIAS_POR_CONSULTA.
## Si falla, prueba las direcciones viejas (kauai y api.nasa.gov) por si vuelven.
## Solo se acepta una respuesta que sea JSON (la dirección vieja de kauai ahora
## devuelve una página web).
## Con la variable de entorno NASA_SIN_RED=1 no se consulta nada (pruebas).

signal datos_actualizados

enum Origen { ARCHIVO, GUARDADO, EN_VIVO }

const DIAS_EN_VIVO := 120
const DIAS_POR_CONSULTA := 59           # la API nueva rechaza más de 60 días
const ESPERA_MAXIMA := 12.0            # segundos por consulta
const URL_CCMC := "https://ccmc.gsfc.nasa.gov/DONKI-API/get/%s?startDate=%s&endDate=%s"
const URL_CCMC_VIEJA := "https://kauai.ccmc.gsfc.nasa.gov/DONKI/WS/get/%s?startDate=%s&endDate=%s"
const URL_API_NASA := "https://api.nasa.gov/DONKI/%s?startDate=%s&endDate=%s&api_key=%s"
const ARCHIVO_DONKI := "res://datos/nasa/archivo_donki.json"
const ARCHIVO_CURADO := "res://datos/nasa/eventos_curados.json"
const GUARDADO := "user://donki_guardado.json"
const ARCHIVO_CLAVE := "res://datos/nasa/clave_api.txt"
const PAGINA_DONKI := "https://ccmc.gsfc.nasa.gov/DONKI/"

var origen := Origen.ARCHIVO
var eventos: Array[Dictionary] = []
var nombre_archivo := ""              # p. ej. "Tormentas solares de mayo de 2024" (archivo curado)
var rango_archivo: Array[String] = [] # [desde, hasta] (AAAA-MM-DD) del archivo descargado de DONKI
var fecha_datos := ""                 # día de la consulta o de la descarga (AAAA-MM-DD)
var archivo_de_donki := false         # false: archivo curado a mano (no viene de DONKI)
var consultando := false


func _ready() -> void:
	if not _cargar_guardado():
		_cargar_archivo()
	if OS.get_environment("NASA_SIN_RED") != "1":
		consultar_en_vivo()


## Línea para la interfaz: dice siempre si los datos son en vivo o no.
func texto_origen() -> String:
	match origen:
		Origen.EN_VIVO:
			return Idioma.t("NASA DONKI · en vivo (consultado hoy)")
		Origen.GUARDADO:
			return Idioma.t("NASA DONKI · guardado el %s") % Donki.fecha_texto(fecha_datos)
	if archivo_de_donki:
		return Idioma.t("NASA DONKI · archivo: %s") % (Idioma.t("%s a %s") % [
			Donki.fecha_texto(rango_archivo[0]), Donki.fecha_texto(rango_archivo[1])])
	return Idioma.t("Eventos reales · archivo: %s") % Idioma.t(nombre_archivo)


## Versión corta para el indicador plegable de abajo a la izquierda.
func texto_corto() -> String:
	match origen:
		Origen.EN_VIVO:
			return Idioma.t("en vivo · consultado hoy")
		Origen.GUARDADO:
			var p := fecha_datos.split("-")
			return Idioma.t("guardado el %s/%s/%s") % [p[2], p[1], p[0]] if p.size() == 3 else Idioma.t("guardado")
	return Idioma.t("sin conexión · archivo")


func en_vivo() -> bool:
	return origen == Origen.EN_VIVO


# --- Consulta en vivo -----------------------------------------------------

func consultar_en_vivo() -> void:
	if consultando:
		return
	consultando = true
	var hoy := Time.get_unix_time_from_system()
	var hasta := Time.get_date_string_from_unix_time(hoy)
	var desde := Time.get_date_string_from_unix_time(hoy - DIAS_EN_VIVO * 86400)
	var nuevos: Array[Dictionary] = []
	for tramo: Array in tramos(hoy - DIAS_EN_VIVO * 86400, hoy):
		for tipo: String in Donki.TIPOS:
			var lista: Variant = await _pedir_tipo(tipo, tramo[0], tramo[1])
			if lista == null:
				consultando = false
				return                   # sin conexión: se quedan los datos que había
			nuevos.append_array(Donki.normalizar(tipo, lista))
	consultando = false
	eventos = nuevos
	origen = Origen.EN_VIVO
	fecha_datos = hasta
	_guardar(desde, hasta)
	datos_actualizados.emit()


## Tramos [desde, hasta] (AAAA-MM-DD) de DIAS_POR_CONSULTA días que cubren el periodo.
static func tramos(inicio: float, fin: float) -> Array:
	var r := []
	var a := inicio
	while a < fin:
		var b := minf(a + DIAS_POR_CONSULTA * 86400.0, fin)
		r.append([Time.get_date_string_from_unix_time(int(a)), Time.get_date_string_from_unix_time(int(b))])
		a = b + 86400.0
	return r


## Un tipo de evento en un tramo: la API nueva y, si falla, las viejas.
func _pedir_tipo(tipo: String, desde: String, hasta: String) -> Variant:
	var lista: Variant = await _pedir(URL_CCMC % [tipo, desde, hasta])
	if lista == null:
		lista = await _pedir(URL_CCMC_VIEJA % [tipo, desde, hasta])
	if lista == null:
		lista = await _pedir(URL_API_NASA % [tipo, desde, hasta, _clave()])
	return lista


## Devuelve la lista del JSON, [] si DONKI respondió vacío (no hubo eventos), o null si falló.
func _pedir(url: String) -> Variant:
	var peticion := HTTPRequest.new()
	peticion.timeout = ESPERA_MAXIMA
	add_child(peticion)
	if peticion.request(url) != OK:
		peticion.queue_free()
		return null
	var respuesta: Array = await peticion.request_completed
	peticion.queue_free()
	var resultado: int = respuesta[0]
	var codigo: int = respuesta[1]
	var cuerpo: PackedByteArray = respuesta[3]
	if resultado != HTTPRequest.RESULT_SUCCESS or codigo != 200:
		return null
	var texto := cuerpo.get_string_from_utf8().strip_edges()
	if texto == "":
		return []
	var datos: Variant = JSON.parse_string(texto)
	return datos if typeof(datos) == TYPE_ARRAY else null


func _clave() -> String:
	if FileAccess.file_exists(ARCHIVO_CLAVE):
		var clave := FileAccess.get_file_as_string(ARCHIVO_CLAVE).strip_edges()
		if clave != "":
			return clave
	return "DEMO_KEY"


# --- Respaldo --------------------------------------------------------------

func _guardar(desde: String, hasta: String) -> void:
	var archivo := FileAccess.open(GUARDADO, FileAccess.WRITE)
	if archivo != null:
		archivo.store_string(JSON.stringify({ "consultado": hasta, "desde": desde, "hasta": hasta, "eventos": eventos }))


func _cargar_guardado() -> bool:
	var datos := _leer_json(GUARDADO)
	if datos.is_empty():
		return false
	eventos = _como_eventos(datos.get("eventos", []))
	origen = Origen.GUARDADO
	fecha_datos = str(datos.get("consultado", ""))
	return not eventos.is_empty()


## Archivo descargado con el script (formato crudo de DONKI) o, si no está, el curado.
func _cargar_archivo() -> void:
	origen = Origen.ARCHIVO
	var descargado := _leer_json(ARCHIVO_DONKI)
	if not descargado.is_empty():
		eventos = []
		archivo_de_donki = true
		for tipo: String in Donki.TIPOS:
			eventos.append_array(Donki.normalizar(tipo, descargado.get(tipo, [])))
		var meta: Dictionary = descargado.get("meta", {})
		fecha_datos = str(meta.get("descargado", ""))
		rango_archivo = [str(meta.get("desde", "")), str(meta.get("hasta", ""))]
		return
	archivo_de_donki = false
	var curado := _leer_json(ARCHIVO_CURADO)
	eventos = _como_eventos(curado.get("eventos", []))
	nombre_archivo = str(curado.get("meta", {}).get("nombre", "eventos reales"))


static func _leer_json(ruta: String) -> Dictionary:
	if not FileAccess.file_exists(ruta):
		return {}
	var datos: Variant = JSON.parse_string(FileAccess.get_file_as_string(ruta))
	return datos if typeof(datos) == TYPE_DICTIONARY else {}


static func _como_eventos(lista: Variant) -> Array[Dictionary]:
	var r: Array[Dictionary] = []
	for e: Variant in lista if typeof(lista) == TYPE_ARRAY else []:
		if typeof(e) == TYPE_DICTIONARY:
			r.append(e)
	return r
