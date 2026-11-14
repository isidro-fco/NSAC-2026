# gestor_tiempo.gd
# Autoload GestorTiempo: reloj de soles con pausa y velocidad; avisa cuando termina cada sol.

extends Node
## Autoload "GestorTiempo": reloj de soles (HU-07). Solo mide el tiempo; las
## reglas de cada sol las aplica EstadoJuego al recibir sol_transcurrido.

## Se emite al terminar un sol; `sol` es el número del sol que acaba de terminar.
signal sol_transcurrido(sol: int)
signal cambiado

var datos_balance: DatosBalance = load("res://datos/balance.tres")
var sol_actual := 1
var progreso_sol := 0.0       # 0..1 dentro del sol en curso
var en_pausa := false:
	set(valor):
		en_pausa = valor
		cambiado.emit()
var velocidad := 1:           # 1, 2 o 4
	set(valor):
		velocidad = valor
		cambiado.emit()
var detenido := false:        # fin de partida
	set(valor):
		detenido = valor
		cambiado.emit()


func reiniciar() -> void:
	sol_actual = 1
	progreso_sol = 0.0
	en_pausa = false
	velocidad = 1
	detenido = false


func corriendo() -> bool:
	return not en_pausa and not detenido


## Segundos de juego equivalentes a `delta` reales (0 en pausa).
func escalar(delta: float) -> float:
	return delta * velocidad if corriendo() else 0.0


func _process(delta: float) -> void:
	progreso_sol += escalar(delta) / datos_balance.segundos_por_sol
	if progreso_sol >= 1.0:
		progreso_sol -= 1.0
		avanzar_sol()


## Cierra el sol en curso al instante (también lo usan las pruebas).
func avanzar_sol() -> void:
	if not detenido:
		sol_actual += 1
		sol_transcurrido.emit(sol_actual - 1)
