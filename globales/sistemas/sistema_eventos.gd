# sistema_eventos.gd
# Sistema de eventos: incidentes aleatorios con dos opciones y tormentas solares que aumentan la radiación.

class_name SistemaEventos
extends Sistema
## Incidentes aleatorios (HU-08): cada 5 a 20 soles salta un evento que pausa
## el juego y ofrece dos opciones con costes distintos. Uno de ellos es la
## tormenta solar, que dispara la radiación durante unos soles salvo en el
## refugio blindado. Se usa a través de EstadoJuego.eventos.
## Los eventos están en datos/balance.tres (campo "eventos").

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
func toca_evento() -> bool:
	soles_para_evento -= 1
	if soles_para_evento > 0:
		return false
	soles_para_evento = _intervalo()
	evento = datos.eventos[EstadoJuego.rng.randi_range(0, datos.eventos.size() - 1)]
	pausa_previa = GestorTiempo.en_pausa
	GestorTiempo.en_pausa = true
	return true


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
		tormenta_soles = opcion["tormenta"]
		blindaje = opcion.get("blindaje", 1.0)
	EstadoJuego.registrar(Enums.Categoria.EVENTO, "%s: %s" % [evento["titulo"], opcion["texto"]])
	evento = {}
	GestorTiempo.en_pausa = pausa_previa
	EstadoJuego.estado_cambiado.emit()
