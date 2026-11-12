class_name SistemaGlosario
extends RefCounted
## Glosario técnico (HU-12): cada término empieza oculto y se descubre la
## primera vez que aparece en un texto de la interfaz (ver UI.etiqueta).
## Se usa a través de EstadoJuego.glosario. Los términos están en datos/glosario.tres.

var terminos: Array = (load("res://datos/glosario.tres") as DatosGlosario).terminos
var descubiertos := {}                # id -> true, en el orden en que se descubrieron
var _por_palabra := {}                # palabra en minúsculas -> id
var _regex := RegEx.new()


func _init() -> void:
	var palabras: Array[String] = []
	for termino: Dictionary in terminos:
		for palabra: String in termino["palabras"]:
			_por_palabra[palabra.to_lower()] = termino["id"]
			palabras.append(palabra.to_lower())
	# Las más largas primero ("tormenta solar" antes que "tormenta"); sin letras pegadas a los lados.
	palabras.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())
	_regex.compile("(?<![\\p{L}])(%s)(?![\\p{L}])" % "|".join(palabras))


func reiniciar() -> void:
	descubiertos.clear()


func termino(id: String) -> Dictionary:
	for t: Dictionary in terminos:
		if t["id"] == id:
			return t
	return {}


## BBCode del texto con los términos marcados como enlaces (y descubiertos),
## o "" si no contiene ninguno.
func resaltar(texto: String) -> String:
	# Se busca en minúsculas (la RegEx no pliega tildes: "Ó" ≠ "ó"); la longitud no cambia.
	var coincidencias := _regex.search_all(texto.to_lower())
	if coincidencias.is_empty():
		return ""
	var bbcode := ""
	var desde := 0
	for m: RegExMatch in coincidencias:
		var id: String = _por_palabra[m.get_string()]
		var palabra := texto.substr(m.get_start(), m.get_end() - m.get_start())
		descubiertos[id] = true
		bbcode += texto.substr(desde, m.get_start() - desde).replace("[", "[lb]")
		bbcode += "[url=%s][color=#%s]%s[/color][/url]" % [id, UI.ADVERTENCIA.to_html(false), palabra]
		desde = m.get_end()
	return bbcode + texto.substr(desde).replace("[", "[lb]")
