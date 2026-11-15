# menu_modulo.gd
# Clase base de los menús de módulo: ventana, título, botón de cerrar y reconstrucción al cambiar el estado.

class_name MenuModulo
extends Control
## Base de los menús de módulo (comando, descanso, almacén): ventana redondeada
## con título pixel y botón X naranja (docs/diseno/Almacen y cocina.pdf), y
## reconstrucción del contenido cuando cambia EstadoJuego.
## Cada menú solo implementa construir() y, si tiene subvistas, atras().

const TAM_MENU := Vector2(1040, 580)

var interfaz: Juego           # abre diálogos y cierra el menú
var contenido: VBoxContainer
var scrolls: Array[ScrollContainer] = []
var reconstruccion_pendiente := false
var con_cabecera := true      # título y X arriba (el de comando pone la X en la esquina del marco)
var marco_comando := true     # marco de la sala de comandos (placa con perillas, fondo gris liso)


func iniciar(juego: Juego, titulo: String) -> void:
	interfaz = juego
	contenido = _montar_marco(titulo)
	EstadoJuego.estado_cambiado.connect(_pedir_reconstruccion)
	_reconstruir()


func cerrar() -> void:
	interfaz.cerrar_menu()


## Llena `contenido`. Lo implementa cada menú.
func construir() -> void:
	pass


## Escape: devuelve true si cerró una subvista en lugar del menú entero.
func atras() -> bool:
	return false


## Cabecera de una subvista (historial, reclutamiento): botón "< Volver" y título.
func cabecera_subvista(titulo: String, al_volver: Callable) -> void:
	var cabecera := UI.fila()
	cabecera.add_child(UI.boton("< Volver", al_volver))
	var etiqueta := UI.seccion(titulo)
	etiqueta.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cabecera.add_child(etiqueta)
	contenido.add_child(cabecera)


## Lista con scroll cuya posición se conserva al reconstruir.
func vista_con_scroll(interior: Control) -> ScrollContainer:
	var scroll := UI.desplazable(interior)
	scrolls.append(scroll)
	return scroll


func _pedir_reconstruccion() -> void:
	if not reconstruccion_pendiente:
		reconstruccion_pendiente = true
		_reconstruir.call_deferred()


## Vacía `contenido`, lo vuelve a construir y restaura el scroll de las listas.
func _reconstruir() -> void:
	reconstruccion_pendiente = false
	var posiciones: Array[int] = []
	for scroll in scrolls:
		posiciones.append(scroll.scroll_vertical)
	scrolls.clear()
	for hijo in contenido.get_children():
		contenido.remove_child(hijo)
		hijo.queue_free()
	construir()
	if scrolls.size() != posiciones.size() or not is_inside_tree():
		return
	await get_tree().process_frame
	for i in scrolls.size():
		if is_instance_valid(scrolls[i]):
			scrolls[i].scroll_vertical = posiciones[i]


## Monta fondo oscurecido, ventana, título y botón X.
## Devuelve el contenedor donde el menú pone su contenido.
##   ╭───────────────────────────────────────────╮
##   │ Almacén y Cocina                      [X] │
##   │ (contenido)                               │
##   ╰───────────────────────────────────────────╯
func _montar_marco(titulo: String) -> VBoxContainer:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var fondo := ColorRect.new()
	fondo.color = Color(0, 0, 0, 0.6)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centro.offset_top = Hud.ALTO_BARRA - Hud.MARGEN
	centro.offset_bottom = -50
	add_child(centro)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = TAM_MENU
	UI.aplicar_marco_ventana(panel, 10, marco_comando)
	if marco_comando:
		# La X va sobre la placa, en la esquina de arriba a la derecha, fuera de la pantalla.
		var caja := Control.new()
		caja.custom_minimum_size = TAM_MENU
		centro.add_child(caja)
		panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		caja.add_child(panel)
		# La caja crece con el panel si el contenido pide más que TAM_MENU.
		panel.minimum_size_changed.connect(func() -> void:
			caja.custom_minimum_size = panel.get_combined_minimum_size())
		var x := UI.boton_cerrar(cerrar)
		x.anchor_left = 1.0
		x.anchor_right = 1.0
		x.offset_left = -MarcoVentana.LADO_COMANDO / 2.0 - 20
		x.offset_right = x.offset_left + 40
		x.offset_top = 12
		x.offset_bottom = 52
		caja.add_child(x)
	else:
		panel.get_theme_stylebox("panel").content_margin_top = UI.MARGEN_VENTANA + 6
		centro.add_child(panel)
	var marco := UI.columna(10)
	panel.add_child(marco)
	if con_cabecera:
		var cabecera := UI.fila(10)
		marco.add_child(cabecera)
		var etiqueta := UI.titulo(titulo)
		etiqueta.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cabecera.add_child(UI.expandir(etiqueta))
		# Con el marco de comando la X ya va en la esquina de la placa.
		if not marco_comando:
			cabecera.add_child(UI.boton_cerrar(cerrar))
	var caja_contenido := UI.columna(10)
	caja_contenido.size_flags_vertical = Control.SIZE_EXPAND_FILL
	marco.add_child(caja_contenido)
	return caja_contenido
