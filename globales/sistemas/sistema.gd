# sistema.gd
# Clase base de los sistemas de EstadoJuego: acceso a los datos de balance y reinicio de la partida.

class_name Sistema
extends RefCounted
## Base de los sistemas de globales/sistemas/. Cada sistema guarda sus datos y
## sus reglas y se usa a través de EstadoJuego (p. ej. EstadoJuego.economia).

## Valores de balance compartidos (datos/balance.tres).
var datos: DatosBalance:
	get: return EstadoJuego.datos_balance


## Deja el sistema como al empezar una partida. Cada sistema lo redefine si lo necesita.
func reiniciar() -> void:
	pass
