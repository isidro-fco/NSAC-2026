extends Node
## Autoload "GestorTiempo": reloj de soles (HU-07). Solo mide el tiempo; las
## reglas de cada sol las aplica EstadoJuego al recibir sol_transcurrido.

var datos_balance: Resource = load("res://datos/balance.tres")

## Se emite al terminar un sol; `sol` es el número del sol que acaba de terminar.
signal sol_transcurrido(sol: int)
signal cambiado

var sol_actual := 1
var progreso_sol := 0.0       # 0..1 dentro del sol en curso
var en_pausa := false
var velocidad := 1            # 1 o 2
var detenido := false         # fin de partida


func reiniciar() -> void:
	sol_actual = 1
	progreso_sol = 0.0
	en_pausa = false
	velocidad = 1
	detenido = false
	cambiado.emit()


func corriendo() -> bool:
	return not en_pausa and not detenido


## Segundos de juego equivalentes a `delta` reales (0 en pausa).
func escalar(delta: float) -> float:
	return delta * velocidad if corriendo() else 0.0


func _process(delta: float) -> void:
	if not corriendo():
		return
	progreso_sol += delta * velocidad / datos_balance.segundos_por_sol
	if progreso_sol >= 1.0:
		progreso_sol -= 1.0
		avanzar_sol()


## Cierra el sol en curso al instante (también lo usan las pruebas).
func avanzar_sol() -> void:
	if detenido:
		return
	var terminado := sol_actual
	sol_actual += 1
	sol_transcurrido.emit(terminado)


func detener() -> void:
	detenido = true
	cambiado.emit()


func alternar_pausa() -> void:
	en_pausa = not en_pausa
	cambiado.emit()


func alternar_velocidad() -> void:
	velocidad = 1 if velocidad == 2 else 2
	cambiado.emit()
