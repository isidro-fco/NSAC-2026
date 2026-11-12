class_name SistemaComando
extends RefCounted
## Niveles del Módulo de Comando (HU-02): cada mejora cuesta dinero y
## materiales, tarda unos soles y multiplica la producción de la base.
## Completar el nivel máximo gana la partida (HU-11).
## Se usa a través de EstadoJuego.comando. Costes y multiplicadores en
## datos/balance.tres (mejoras_comando, multiplicador_comando).

var nivel := 1
var soles_mejora := 0                 # soles que faltan para terminar la mejora; 0 = ninguna

var datos: DatosBalance:
	get: return EstadoJuego.datos_balance


func reiniciar() -> void:
	nivel = 1
	soles_mejora = 0


func nivel_max() -> int:
	return datos.multiplicador_comando.size()


func multiplicador() -> float:
	return datos.multiplicador_comando[nivel - 1]


## Coste de pasar al siguiente nivel: { "dinero", "materiales", "soles" }.
func siguiente_mejora() -> Dictionary:
	return datos.mejoras_comando[nivel - 1] if nivel < nivel_max() else {}


func puede_mejorar() -> bool:
	var mejora := siguiente_mejora()
	return soles_mejora == 0 and not mejora.is_empty() \
		and EstadoJuego.economia.puede_pagar(mejora["dinero"], mejora["materiales"])


func mejorar() -> void:
	if puede_mejorar():
		var mejora := siguiente_mejora()
		soles_mejora = mejora["soles"]
		EstadoJuego.economia.pagar(mejora["dinero"], mejora["materiales"])
		EstadoJuego.registrar("Acción", "Mejora del Módulo de Comando al nivel %d iniciada (%d soles)" % [nivel + 1, soles_mejora], false)


## Se llama una vez por sol: avanza la mejora en curso.
func avanzar_mejora() -> void:
	if soles_mejora == 0:
		return
	soles_mejora -= 1
	if soles_mejora == 0:
		nivel += 1
		EstadoJuego.registrar("Acción", "Módulo de Comando mejorado a nivel %d (x%s producción)" % [nivel, UI.num(multiplicador())])
