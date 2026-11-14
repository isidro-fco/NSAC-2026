# sistema_eventos.gd
# Sistema de eventos: incidentes aleatorios con dos opciones y tormentas solares que aumentan la radiación.

class_name SistemaEventos
extends Sistema
## Incidentes (HU-08): un evento pausa el juego y ofrece dos opciones con
## costes distintos. Hay dos fuentes:
##   - Eventos reales del Sol (EstadoJuego.clima, datos de NASA DONKI): tienen
##     prioridad y traen la tormenta solar, que dispara la radiación durante unos
##     soles salvo en el refugio blindado.
##   - Incidentes al azar de datos/balance.tres (campo "eventos") cada 5 a 20
##     soles. Si hay datos reales, la "tormenta_solar" de esa lista ya no sale.
## Claves de una opción: "recursos", "radiacion", "enfermar", "tormenta" (soles),
## "blindaje", "tormenta_en" (soles hasta que empieza) y "retraso_envios".
## Se usa a través de EstadoJuego.eventos.

var soles_para_evento := 0
var evento: Dictionary = {}           # evento que espera la decisión del jugador
var pausa_previa := false             # estado de la pausa antes del evento
var tormenta_soles := 0               # soles que le quedan a la tormenta solar
var blindaje := 1.0                   # factor de la dosis interior durante la tormenta


func reiniciar() -> void:
	soles_para_evento = _intervalo()
	evento = {}
	tormenta_soles = 0
	blindaje = 1.0


func _intervalo() -> int:
	return EstadoJuego.rng.randi_range(datos.soles_evento_min, datos.soles_evento_max)


func tormenta_activa() -> bool:
	return tormenta_soles > 0


## Radiación por sol según dónde esté el colono: "exterior", "interior" o "refugio".
func tasa_radiacion(ubicacion: String) -> float:
	if ubicacion == "refugio":
		return 0.0
	if not tormenta_activa():
		return datos.radiacion_intemperie_por_sol if ubicacion == "exterior" else 0.0
	if ubicacion == "exterior":
		return datos.radiacion_tormenta_exterior
	return datos.radiacion_tormenta_interior * blindaje


## Se llama una vez por sol.
func avanzar_tormenta() -> void:
	if tormenta_soles > 0:
		tormenta_soles -= 1
		if tormenta_soles == 0:
			blindaje = 1.0
			EstadoJuego.registrar(Enums.Categoria.EVENTO, "La tormenta solar ha terminado")


## Se llama una vez por sol: true si toca un evento (queda en `evento` y el juego se pausa).
## Primero los eventos reales del Sol; si no toca ninguno, los incidentes al azar.
func toca_evento() -> bool:
	var real := EstadoJuego.clima.siguiente()
	if not real.is_empty():
		_abrir(real)
		return true
	soles_para_evento -= 1
	if soles_para_evento > 0:
		return false
	soles_para_evento = _intervalo()
	_abrir(_incidente_al_azar())
	return true


func _abrir(nuevo: Dictionary) -> void:
	evento = nuevo
	pausa_previa = GestorTiempo.en_pausa
	GestorTiempo.en_pausa = true


func _incidente_al_azar() -> Dictionary:
	var posibles: Array = datos.eventos
	if EstadoJuego.clima.usa_datos_reales():
		posibles = posibles.filter(func(e: Dictionary) -> bool: return e["id"] != "tormenta_solar")
	return posibles[EstadoJuego.rng.randi_range(0, posibles.size() - 1)]


## Aplica la opción elegida del evento en curso y devuelve la pausa a como estaba.
func resolver(indice: int) -> void:
	var opcion: Dictionary = evento["opciones"][indice]
	var economia := EstadoJuego.economia
	var tripulacion := EstadoJuego.tripulacion
	for recurso: String in opcion.get("recursos", {}):
		var cantidad: float = opcion["recursos"][recurso]
		if cantidad >= 0.0:
			economia.sumar(recurso, cantidad)
		else:
			economia.restar(recurso, -cantidad)
	for c: DatosColono in tripulacion.colonos.duplicate():
		tripulacion.anadir_radiacion(c, opcion.get("radiacion", 0.0))
		if EstadoJuego.rng.randf() < opcion.get("enfermar", 0.0) and c.estado != Enums.EstadoColono.ENFERMO:
			tripulacion.enfermar(c)
	if opcion.has("tormenta"):
		if opcion.get("tormenta_en", 0) > 0:
			# La nube de plasma todavía viaja: la tormenta empieza al llegar.
			EstadoJuego.clima.programar_tormenta(opcion["tormenta_en"], opcion["tormenta"], opcion.get("blindaje", 1.0))
		else:
			tormenta_soles = opcion["tormenta"]
			blindaje = opcion.get("blindaje", 1.0)
	if opcion.has("retraso_envios"):
		EstadoJuego.tierra.retrasar(opcion["retraso_envios"])
	EstadoJuego.registrar(Enums.Categoria.EVENTO, "%s: %s" % [evento["titulo"], opcion["texto"]])
	evento = {}
	GestorTiempo.en_pausa = pausa_previa
	EstadoJuego.estado_cambiado.emit()
