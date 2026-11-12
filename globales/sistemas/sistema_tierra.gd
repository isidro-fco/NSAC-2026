class_name SistemaTierra
extends RefCounted
## Latencia con la Tierra (HU-09): nada de lo que viene de la Tierra llega al
## instante. Los colonos contratados, los pedidos de suministros y los fondos
## viajan unos soles antes de llegar. Se usa a través de EstadoJuego.tierra.

## [{ "nombre", "soles", "contenido": {recurso: cantidad}, "colono": DatosColono o null }]
var envios: Array[Dictionary] = []
var soles_para_transferencia := 0

var datos: DatosBalance:
	get: return EstadoJuego.datos_balance


func reiniciar() -> void:
	envios.clear()
	soles_para_transferencia = datos.transferencia_cada


func enviar(nombre: String, soles: int, contenido := {}, colono: DatosColono = null) -> void:
	envios.append({ "nombre": nombre, "soles": soles, "contenido": contenido, "colono": colono })
	EstadoJuego.estado_cambiado.emit()


func pedir(pedido: Dictionary) -> void:
	if EstadoJuego.economia.puede_pagar(pedido["dinero"], 0):
		EstadoJuego.economia.pagar(pedido["dinero"], 0)
		enviar(pedido["nombre"], pedido["soles"], pedido["contenido"])
		EstadoJuego.registrar("Acción", "Pedido a la Tierra: %s (llega en %d soles)" % [pedido["nombre"], pedido["soles"]])


## Se llama una vez por sol: acerca los envíos, entrega los que llegan y
## cada cierto tiempo la Tierra aprueba una transferencia de fondos.
func avanzar() -> void:
	for envio: Dictionary in envios.duplicate():
		envio["soles"] -= 1
		if envio["colono"] != null:
			envio["colono"].soles_restantes = envio["soles"]
		if envio["soles"] <= 0:
			envios.erase(envio)
			_entregar(envio)
	soles_para_transferencia -= 1
	if soles_para_transferencia <= 0:
		soles_para_transferencia = datos.transferencia_cada
		enviar("Transferencia de fondos", datos.transferencia_soles, { "presupuesto": datos.transferencia_dinero })
		EstadoJuego.registrar("Evento", "La Tierra aprobó una transferencia de $%d (llegará en %d soles)" % [
			datos.transferencia_dinero, datos.transferencia_soles])


func _entregar(envio: Dictionary) -> void:
	if envio["colono"] != null:
		EstadoJuego.tripulacion.llegar(envio["colono"])
		return
	var partes := PackedStringArray()
	for recurso: String in envio["contenido"]:
		var cantidad: float = envio["contenido"][recurso]
		var entra := EstadoJuego.economia.sumar(recurso, cantidad)
		var texto := "+%s %s" % [UI.num(entra), Enums.NOMBRE_RECURSO[recurso]]
		if entra < cantidad:
			texto += " (%s no cupieron en el almacén)" % UI.num(cantidad - entra)
		partes.append(texto)
	EstadoJuego.registrar("Evento", "Llegó desde la Tierra: %s: %s" % [envio["nombre"], ", ".join(partes)])
