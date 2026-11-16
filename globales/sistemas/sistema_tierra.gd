# sistema_tierra.gd
# Sistema de la Tierra: envíos de colonos, suministros y fondos que llegan con retraso.

class_name SistemaTierra
extends Sistema
## Latencia con la Tierra (HU-09): nada de lo que viene de la Tierra llega al
## instante. Los colonos contratados, los pedidos de suministros y los fondos
## viajan unos soles antes de llegar. Se usa a través de EstadoJuego.tierra.

## [{ "nombre", "soles", "contenido": {recurso: cantidad}, "colono": DatosColono o null }]
var envios: Array[Dictionary] = []
var soles_para_transferencia := 0


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
		EstadoJuego.registrar(Enums.Categoria.ACCION, Idioma.t("Pedido a la Tierra: %s (llega en %d soles)") % [Idioma.t(pedido["nombre"]), pedido["soles"]])
		EstadoJuego.curiosidades.disparar("pedido:enviado")


## El clima espacial interrumpe las comunicaciones: todo lo que viene en camino tarda más.
func retrasar(soles: int) -> void:
	for envio: Dictionary in envios:
		envio["soles"] += soles
		if envio["colono"] != null:
			envio["colono"].soles_restantes = envio["soles"]
	if not envios.is_empty():
		EstadoJuego.registrar(Enums.Categoria.EVENTO, Idioma.t("Los envíos de la Tierra se retrasan %s") % UI.soles(soles), false)


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
		enviar(Idioma.t("Transferencia de fondos"), datos.transferencia_soles, { "presupuesto": datos.transferencia_dinero })
		EstadoJuego.registrar(Enums.Categoria.EVENTO, Idioma.t("La Tierra aprobó una transferencia de %s (llegará en %d soles)") % [
			UI.dinero(datos.transferencia_dinero), datos.transferencia_soles])


func _entregar(envio: Dictionary) -> void:
	if envio["colono"] != null:
		EstadoJuego.tripulacion.llegar(envio["colono"])
		return
	var partes := PackedStringArray()
	for recurso: String in envio["contenido"]:
		var cantidad: float = envio["contenido"][recurso]
		var entra := EstadoJuego.economia.sumar(recurso, cantidad)
		var texto := "+%s %s" % [UI.cantidad(recurso, entra), Idioma.t(Enums.NOMBRE_RECURSO[recurso])]
		if entra < cantidad:
			texto += Idioma.t(" (%s no cupieron en el almacén)") % UI.cantidad(recurso, cantidad - entra)
		partes.append(texto)
	EstadoJuego.registrar(Enums.Categoria.EVENTO, Idioma.t("Llegó desde la Tierra: %s: %s") % [Idioma.t(envio["nombre"]), ", ".join(partes)])
	# El dinero llega por transferencia; lo demás baja en una nave de carga.
	if envio["contenido"].keys().any(func(recurso: String) -> bool: return recurso != "presupuesto"):
		EstadoJuego.suministros_recibidos.emit(envio["nombre"], envio["contenido"])
