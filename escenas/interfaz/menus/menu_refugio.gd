# menu_refugio.gd
# Menú del refugio blindado: colonos resguardados y capacidad durante una tormenta solar.

class_name MenuRefugio
extends MenuModulo
## HU-08: colonos dentro de los refugios blindados y su capacidad (ej. 2 / 5).

var refugiados: Array[DatosColono] = []


func construir() -> void:
	var plazas: int = EstadoJuego.datos_balance.capacidad_refugio * interfaz.mapa.modulos_de("refugio").size()
	var cabecera := UI.fila()
	var estado := "Tormenta solar en curso: la tripulación se refugia aquí." \
		if EstadoJuego.eventos.tormenta_activa() else "Sin tormenta solar: el refugio está en reserva."
	cabecera.add_child(UI.expandir(UI.parrafo(estado)))
	cabecera.add_child(UI.seccion("%d / %d colonos refugiados" % [refugiados.size(), plazas]))
	contenido.add_child(cabecera)
	var lista := UI.columna(6)
	for c in refugiados:
		lista.add_child(TarjetaColono.new(c))
	if refugiados.is_empty():
		lista.add_child(UI.parrafo("No hay nadie dentro del refugio."))
	contenido.add_child(vista_con_scroll(lista))


## Los colonos entran y salen andando: se rehace la lista cuando cambia quién está dentro.
func _process(_delta: float) -> void:
	var dentro := EstadoJuego.tripulacion.colonos.filter(
		func(c: DatosColono) -> bool: return c.ubicacion == "refugio")
	if dentro != refugiados:
		refugiados.assign(dentro)
		_pedir_reconstruccion()
