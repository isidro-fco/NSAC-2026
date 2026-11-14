# hud.gd
# HUD siempre visible: barra superior de recursos y reloj, y botones inferiores (glosario, construir, bitácora).

class_name Hud
extends Control
## HU-07: barra superior y botones inferiores, siempre visibles.
## Diseño: docs/diseno/Principal.pdf. Cada dato va en su propia píldora redondeada:
##
## (Oxígeno)(Energía)(Agua)(Comida)(Materiales)(Presupuesto)(     Sol 11     )(II ▶ x2 x4)
##  ▪▪▪▪▫▫    ▪▪▪▪▫▫   ▪▪▫▫   ▪▪▪▫▫    ▪▪▪▪▫▫       1250     ▪▪▪▪▪▪▪▪▪▪▫▫▫▫▫▫
##
## (● DONKI >)        ( Glosario G ) ( Construir B ) ( Bitácora L )
## Abajo a la izquierda, plegado, de dónde salen los datos del Sol (NASA DONKI):
## con ">" se despliega hacia la derecha; el punto es verde si están en vivo.
## El estilo y las piezas comunes de la interfaz viven en UI (ui.gd).

signal accion_pedida(id: String)              # "glosario", "construir" o "bitacora"

const MARGEN := 12.0
const ALTO_PANEL := 44.0
const SEPARACION := 8
## Espacio que ocupa la barra arriba (la cámara y los paneles lo dejan libre).
const ALTO_BARRA := MARGEN + ALTO_PANEL + MARGEN
## [acción, texto, tecla, principal] de cada botón inferior (las teclas las atiende Juego).
const BOTONES_INFERIORES := [
	["glosario", "Glosario", "G", false],
	["construir", "Construir", "B", true],
	["bitacora", "Bitácora", "L", false],
]

var indicadores: Array[IndicadorRecurso] = []
var sol_label: Label
var barra_sol: BarraSegmentada
var boton_pausa: Button
var boton_reanudar: Button
var botones_velocidad := {}                   # velocidad -> Button (x2 y x4)
var botones_inferiores: HBoxContainer
var botones := {}                             # acción -> Button de la fila inferior
var panel_tierra := UI.columna(6)
var panel_donki: PanelContainer
var donki_punto: ColorRect
var donki_detalle: Label
var donki_boton: Button
var modo_normal := true


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crear_barra()
	_crear_botones_inferiores()
	_crear_panel_donki()
	var caja := PanelContainer.new()
	UI.aplicar_marco(caja, 12)
	caja.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, MARGEN)
	caja.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	caja.offset_top = ALTO_BARRA
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.add_child(panel_tierra)
	add_child(caja)
	EstadoJuego.estado_cambiado.connect(actualizar)
	ServicioNasa.datos_actualizados.connect(actualizar)
	actualizar()


func _crear_barra() -> void:
	var fila := UI.fila(SEPARACION)
	fila.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	fila.offset_left = MARGEN
	fila.offset_right = -MARGEN
	fila.offset_top = MARGEN
	fila.offset_bottom = MARGEN + ALTO_PANEL
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fila)
	for recurso: String in EstadoJuego.datos_balance.recursos_hud:
		var indicador := IndicadorRecurso.new(recurso)
		indicadores.append(indicador)
		fila.add_child(_pildora(indicador))
	fila.add_child(UI.expandir(_pildora(_reloj())))
	fila.add_child(_pildora(_controles_tiempo(), 6))


## Fondo de cada dato de la barra superior: el marco de panel de cabina (UI.estilo_marco).
static func _pildora(contenido: Control, margen := 12) -> PanelContainer:
	var pildora := PanelContainer.new()
	UI.aplicar_marco(pildora, margen)
	var caja: StyleBoxTexture = pildora.get_theme_stylebox("panel")
	caja.content_margin_top = UI.MARGEN_MARCO
	caja.content_margin_bottom = UI.MARGEN_MARCO
	pildora.mouse_filter = Control.MOUSE_FILTER_PASS
	pildora.add_child(contenido)
	return pildora


func _reloj() -> Control:
	var c := UI.columna(6)
	c.alignment = BoxContainer.ALIGNMENT_CENTER
	sol_label = UI.etiqueta_pixel("", UI.T_TEXTO)
	sol_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	barra_sol = BarraSegmentada.new(20, true)
	barra_sol.color = UI.ADVERTENCIA
	c.add_child(sol_label)
	c.add_child(barra_sol)
	return c


## Pausa, reanudar y velocidad: el botón del estado actual se resalta.
## x2 y x4 se activan con un clic y vuelven a x1 con otro.
func _controles_tiempo() -> Control:
	var f := UI.fila(6)
	f.alignment = BoxContainer.ALIGNMENT_CENTER
	boton_pausa = UI.boton_pixel("II", func() -> void: GestorTiempo.en_pausa = true, false, UI.T_TEXTO)
	boton_pausa.tooltip_text = "Pausar (Espacio)"
	boton_reanudar = UI.boton_pixel("▶", func() -> void: GestorTiempo.en_pausa = false, false, UI.T_TEXTO)
	boton_reanudar.tooltip_text = "Reanudar (Espacio)"
	for v: int in [2, 4]:
		var b := UI.boton_pixel("x%d" % v, func() -> void:
			GestorTiempo.velocidad = 1 if GestorTiempo.velocidad == v else v, false, UI.T_TEXTO)
		b.tooltip_text = "Doble velocidad" if v == 2 else "Velocidad x4"
		botones_velocidad[v] = b
	for b: Button in [boton_pausa, boton_reanudar] + botones_velocidad.values():
		b.custom_minimum_size = Vector2(30, 30)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		f.add_child(b)
	return f


## Fila abajo al centro: Glosario (HU-12), Construir (HU-05, en naranja) y
## Bitácora (HU-10), cada uno con su tecla en una placa oscura.
func _crear_botones_inferiores() -> void:
	botones_inferiores = UI.fila(40)
	botones_inferiores.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 14)
	botones_inferiores.grow_horizontal = Control.GROW_DIRECTION_BOTH
	botones_inferiores.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(botones_inferiores)
	for datos: Array in BOTONES_INFERIORES:
		var principal: bool = datos[3]
		var boton := UI.boton_pixel("", accion_pedida.emit.bind(datos[0]), principal, UI.T_TEXTO)
		UI.aplicar_marco_boton(boton, principal)
		boton.custom_minimum_size = Vector2(152, 42)
		var contenido := UI.fila(10)
		contenido.alignment = BoxContainer.ALIGNMENT_CENTER
		contenido.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		contenido.mouse_filter = Control.MOUSE_FILTER_IGNORE
		contenido.add_child(UI.etiqueta_pixel(datos[1], UI.T_TEXTO))
		var tecla := PanelContainer.new()
		tecla.add_theme_stylebox_override("panel", UI.estilo(UI.FONDO, UI.FONDO, 3, 7, 0))
		tecla.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tecla.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tecla.add_child(UI.etiqueta_pixel(datos[2], UI.T_TEXTO))
		contenido.add_child(tecla)
		boton.add_child(contenido)
		botones_inferiores.add_child(boton)
		botones[datos[0]] = boton


## HU-05: el botón Construir se ve siempre (en modo construcción sirve para salir).
## Los demás se ocultan fuera del modo normal pero conservan su hueco, para que
## Construir no cambie de sitio.
## Abajo a la izquierda: [● DONKI >] plegado; [● DONKI < en vivo (consultado hoy)] desplegado.
func _crear_panel_donki() -> void:
	panel_donki = PanelContainer.new()
	UI.aplicar_marco(panel_donki, 8)
	panel_donki.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, MARGEN)
	panel_donki.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(panel_donki)
	var f := UI.fila(8)
	f.alignment = BoxContainer.ALIGNMENT_CENTER
	panel_donki.add_child(f)
	donki_punto = ColorRect.new()
	donki_punto.custom_minimum_size = Vector2(8, 8)
	donki_punto.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	donki_punto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f.add_child(donki_punto)
	f.add_child(UI.etiqueta_pixel("DONKI", UI.T_DETALLE, UI.TEXTO))
	donki_boton = UI.boton_pixel(">", _alternar_donki, false, UI.T_DETALLE)
	donki_boton.custom_minimum_size = Vector2(24, 22)
	f.add_child(donki_boton)
	donki_detalle = UI.etiqueta_pixel("", UI.T_DETALLE, UI.TEXTO_SUAVE)
	donki_detalle.visible = false
	f.add_child(donki_detalle)


func _alternar_donki() -> void:
	donki_detalle.visible = not donki_detalle.visible
	donki_boton.text = "<" if donki_detalle.visible else ">"
	panel_donki.reset_size()
	_actualizar_panel_donki()


func _actualizar_panel_donki() -> void:
	panel_donki.visible = modo_normal and EstadoJuego.clima.activo()
	var vivo := ServicioNasa.en_vivo()
	donki_punto.color = UI.BIEN if vivo else UI.TEXTO_SUAVE
	donki_detalle.text = ServicioNasa.texto_corto()
	donki_detalle.add_theme_color_override("font_color", UI.BIEN if vivo else UI.TEXTO_SUAVE)
	panel_donki.tooltip_text = "Datos del Sol: " + ServicioNasa.texto_origen()


func mostrar_modo_normal(normal: bool) -> void:
	modo_normal = normal
	_actualizar_panel_donki()
	for id: String in botones:
		if id == "construir":
			continue
		var b: Button = botones[id]
		b.modulate.a = 1.0 if normal else 0.0
		b.disabled = not normal
		b.mouse_filter = Control.MOUSE_FILTER_STOP if normal else Control.MOUSE_FILTER_IGNORE
	botones["construir"].tooltip_text = "Construir (B)" if normal else "Salir del modo construcción (B)"


## HU-08 y HU-09: arriba a la derecha, el clima espacial (tormenta solar en
## curso y nube del Sol en camino) y lo que
## viene de camino desde la Tierra (con los soles que faltan).
func _actualizar_panel_tierra() -> void:
	for hijo in panel_tierra.get_children():
		hijo.queue_free()
	var lineas: Array[Label] = []
	if EstadoJuego.eventos.tormenta_activa():
		lineas.append(UI.etiqueta_pixel("TORMENTA SOLAR: " + UI.soles(EstadoJuego.eventos.tormenta_soles), 8, UI.CRITICO))
	var nube := EstadoJuego.clima.tormenta_pendiente
	if not nube.is_empty():
		lineas.append(UI.etiqueta_pixel("NUBE DEL SOL: llega en " + UI.soles(nube["soles"]), 8, UI.ADVERTENCIA))
	if not EstadoJuego.tierra.envios.is_empty():
		lineas.append(UI.etiqueta_pixel("DESDE LA TIERRA", 8, UI.TEXTO_SUAVE))
	for envio: Dictionary in EstadoJuego.tierra.envios:
		lineas.append(UI.etiqueta_pixel("%s · %s" % [envio["nombre"], UI.soles(envio["soles"])]))
	for linea in lineas:
		panel_tierra.add_child(linea)
	panel_tierra.get_parent().visible = not lineas.is_empty()


func actualizar() -> void:
	for indicador in indicadores:
		indicador.actualizar()
	sol_label.text = "Sol %d" % GestorTiempo.sol_actual
	UI.pintar_boton_pixel(boton_pausa, GestorTiempo.en_pausa, UI.ACENTO, UI.SILENCIADO, 4)
	UI.pintar_boton_pixel(boton_reanudar, not GestorTiempo.en_pausa, UI.ACENTO, UI.SILENCIADO, 4)
	for v: int in botones_velocidad:
		UI.pintar_boton_pixel(botones_velocidad[v], GestorTiempo.velocidad == v, UI.ACENTO, UI.SILENCIADO, 4)
	_actualizar_panel_tierra()
	_actualizar_panel_donki()


func _process(_delta: float) -> void:
	barra_sol.proporcion = GestorTiempo.progreso_sol
