# sistema_curiosidades.gd
# Datos curiosos de STEM: cada uno aparece una sola vez por partida, cuando el jugador ve algo nuevo relacionado.

class_name SistemaCuriosidades
extends Sistema
## Los datos están en datos/curiosidades.tres (ver DatosCuriosidades). El juego
## llama a disparar("construir:agricultura"), disparar("sol:3"), etc. cuando
## pasa algo; si hay un dato para eso que no se ha mostrado, se emite
## EstadoJuego.curiosidad_nueva y el HUD lo enseña (PanelCuriosidades).
## Si varios datos tienen el mismo disparador, sale uno cada vez que pasa
## (p. ej. uno con la primera nave de colonos y otro con la segunda).

const DATOS: DatosCuriosidades = preload("res://datos/curiosidades.tres")

var mostradas := {}                    # id -> true


func reiniciar() -> void:
	mostradas.clear()


func disparar(disparador: String) -> void:
	for dato: Dictionary in DATOS.curiosidades:
		if dato["disparador"] == disparador and not mostradas.has(dato["id"]):
			mostradas[dato["id"]] = true
			EstadoJuego.curiosidad_nueva.emit(dato)
			# Queda en la página "Curiosidad" de la bitácora (clic en la tarjeta lleva ahí).
			EstadoJuego.registrar(Enums.Categoria.CURIOSIDAD, "%s: %s" % [dato["titulo"], dato["texto"]], false, { "dato": dato })
			return
