# idioma.gd
# Idioma del juego (español o inglés): lo elige el jugador, se guarda en los ajustes y traduce los textos.

class_name Idioma
extends RefCounted
## Los textos del código y de los datos están en español: son la "clave" de la
## traducción. El inglés está en traducciones/en.po (registrado en
## project.godot); si un texto no está ahí, se queda en español.
##   Idioma.t("Sol %d") % 3      -> "Sol 3" (el formato va después de traducir)
## Las etiquetas y botones cuyo texto coincide exacto con una entrada del .po
## los traduce Godot solo; Idioma.t() hace falta para lo que se arma con
## formatos, se dibuja a mano o pasa por Cabina.mayus().
## El idioma se elige en Opciones, desde el menú de inicio: los textos que ya
## se escribieron en la bitácora de una partida no se vuelven a traducir.

const ESPANOL := "es"
const INGLES := "en"
const CODIGOS: Array[String] = [ESPANOL, INGLES]
const ARCHIVO := "user://ajustes.cfg"
const SECCION := "opciones"
const CLAVE := "idioma"

static var _listo := false


## Texto en el idioma elegido.
static func t(texto: String) -> String:
	if not _listo:
		iniciar()
	return TranslationServer.translate(texto) if texto != "" else ""


## Código del idioma en uso: "es" o "en".
static func actual() -> String:
	if not _listo:
		iniciar()
	return INGLES if TranslationServer.get_locale().begins_with(INGLES) else ESPANOL


static func en_ingles() -> bool:
	return actual() == INGLES


## Carga el idioma guardado; la primera vez arranca en inglés (se cambia en Opciones).
static func iniciar() -> void:
	if _listo:
		return
	_listo = true
	var config := ConfigFile.new()
	config.load(ARCHIVO)
	var codigo := str(config.get_value(SECCION, CLAVE, INGLES))
	TranslationServer.set_locale(codigo if codigo in CODIGOS else INGLES)


## Cambia el idioma y lo guarda en los ajustes.
static func fijar(codigo: String) -> void:
	_listo = true
	TranslationServer.set_locale(codigo if codigo in CODIGOS else INGLES)
	var config := ConfigFile.new()
	config.load(ARCHIVO)
	config.set_value(SECCION, CLAVE, actual())
	config.save(ARCHIVO)
