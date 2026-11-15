# panel_tripulacion.gd
# Panel lateral con todos los colonos: nombre y dónde están. Al elegir uno se resalta en el mapa.

class_name PanelTripulacion
extends PanelContainer
## Arriba a la izquierda, bajo la barra del HUD. Una fila por colono con:
##   [foto]  Nombre                  [ícono del
##           Módulo donde está        módulo]
## La foto lleva un marco del color de su rol. Mientras camina se muestra el módulo
## al que va; "Exterior" si está afuera. Se refresca varias veces por segundo.
## Clic en una fila: lo elige (se resalta en el mapa); otro clic lo suelta.

## Avisa del colono elegido, o null si se soltó.
signal colono_elegido(datos: DatosColono)

const ANCHO := 264.0
const ALTO_FILA := 44.0
## Retratos de 32 px más 2 px de marco por lado: se ven a escala 1:1, sin suavizar.
const LADO_FOTO := 36
const MARCO_FOTO := 2
## Ícono del módulo: 24 px del sprite (o 12 px a 2x) más 2 px de marco por lado.
const LADO_ICONO := 28
const FILAS_VISIBLES := 8              # más colonos: aparece la barra de desplazamiento
const REFRESCO := 0.25                 # segundos entre actualizaciones del lugar

var mapa: Mapa
var elegido: DatosColono
var lista := UI.columna(4)
var desplazable: ScrollContainer
var titulo: Label
var filas := {}                        # DatosColono -> { "boton", "lugar": Label, "icono": Control, "modulo": DatosModulo }
var _espera := 0.0


func _init(mapa_base: Mapa) -> void:
	mapa = mapa_base


func _ready() -> void:
	UI.aplicar_marco(self, 10)
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	offset_left = Hud.MARGEN
	offset_top = Hud.ALTO_BARRA + 6
	custom_minimum_size = Vector2(ANCHO, 0)
	var columna := UI.columna(8)
	titulo = UI.etiqueta_pixel("", UI.T_TEXTO, UI.ADVERTENCIA)
	columna.add_child(titulo)
	desplazable = UI.desplazable(lista)
	columna.add_child(desplazable)
	add_child(columna)
	EstadoJuego.estado_cambiado.connect(_reconstruir)
	_reconstruir()


func _process(delta: float) -> void:
	_espera -= delta
	if _espera <= 0.0:
		_espera = REFRESCO
		_actualizar_lugares()


## Rehace las filas solo si cambió quién está en la colonia.
func _reconstruir() -> void:
	var colonos := EstadoJuego.tripulacion.colonos
	titulo.text = "TRIPULACIÓN  %d" % colonos.size()
	if elegido != null and elegido not in colonos:
		_elegir(null)
	if filas.keys() == Array(colonos):
		return
	for hijo in lista.get_children():
		hijo.queue_free()
	filas.clear()
	for c: DatosColono in colonos:
		lista.add_child(_fila(c))
	desplazable.custom_minimum_size = Vector2(0, mini(colonos.size(), FILAS_VISIBLES) * (ALTO_FILA + 4))
	_actualizar_lugares()
	_pintar_filas()


func _fila(c: DatosColono) -> Button:
	var boton := Button.new()
	boton.custom_minimum_size = Vector2(0, ALTO_FILA)
	boton.focus_mode = Control.FOCUS_NONE
	boton.pressed.connect(func() -> void: _elegir(null if elegido == c else c))
	Tooltips.registrar(boton, _contenido_tooltip.bind(c))
	var contenido := UI.fila(8)
	contenido.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	contenido.offset_left = 8
	contenido.offset_right = -6
	contenido.mouse_filter = Control.MOUSE_FILTER_IGNORE
	contenido.add_child(_foto(c))
	var textos := UI.columna(3)
	textos.alignment = BoxContainer.ALIGNMENT_CENTER
	textos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var nombre := UI.etiqueta_pixel(c.nombre, UI.T_DETALLE)
	var lugar := UI.etiqueta_pixel("", UI.T_DETALLE, UI.TEXTO_SUAVE)
	for etiqueta: Label in [nombre, lugar]:
		etiqueta.clip_text = true
		etiqueta.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		textos.add_child(etiqueta)
	contenido.add_child(UI.expandir(textos))
	var icono := _icono(c)
	contenido.add_child(icono)
	boton.add_child(contenido)
	filas[c] = { "boton": boton, "lugar": lugar, "icono": icono, "modulo": null }
	return boton


## Retrato cuadrado con marco de píxeles del color del rol. Sin retrato, sus
## iniciales con la fuente pixel sobre el color del rol oscurecido.
func _foto(c: DatosColono) -> Control:
	var foto := Control.new()
	foto.custom_minimum_size = Vector2(LADO_FOTO, LADO_FOTO)
	foto.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foto.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	foto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var textura := c.textura_retrato()
	foto.draw.connect(func() -> void:
		var marco := Rect2(Vector2.ZERO, Vector2(LADO_FOTO, LADO_FOTO))
		var interior := marco.grow(-MARCO_FOTO)
		foto.draw_rect(marco, c.color_rol())
		if textura != null:
			foto.draw_rect(interior, UI.FONDO)
			foto.draw_texture_rect(textura, interior, false)
		else:
			foto.draw_rect(interior, c.color_rol().darkened(0.5))
			foto.draw_string(UI.fuente_pixel(), Vector2(MARCO_FOTO, LADO_FOTO / 2.0 + 4.0), c.iniciales(),
				HORIZONTAL_ALIGNMENT_CENTER, interior.size.x, UI.T_DETALLE, UI.TEXTO)
		# Línea oscura por dentro del marco, como el relieve de los botones pixel.
		foto.draw_rect(interior.grow(1), Color(0, 0, 0, 0.45), false, 1.0))
	return foto


## Emblema del centro del sprite del módulo donde está el colono, a escala
## entera para que se vea pixelado y nítido. Vacío si está en el exterior.
func _icono(c: DatosColono) -> Control:
	var icono := Control.new()
	icono.custom_minimum_size = Vector2(LADO_ICONO, LADO_ICONO)
	icono.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icono.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icono.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icono.draw.connect(func() -> void:
		var marco := Rect2(Vector2.ZERO, Vector2(LADO_ICONO, LADO_ICONO))
		icono.draw_rect(marco, UI.FONDO)
		var datos: DatosModulo = filas[c]["modulo"] if filas.has(c) else null
		if datos != null:
			_dibujar_emblema(icono, datos, marco.grow(-2))
		icono.draw_rect(marco.grow(-1), UI.BORDE, false, 2.0))
	return icono


func _dibujar_emblema(icono: Control, datos: DatosModulo, area: Rect2) -> void:
	if datos.textura == null:
		# Módulo sin sprite (p. ej. el refugio): su color y su letra.
		icono.draw_rect(area, datos.color)
		icono.draw_string(UI.fuente_pixel(), Vector2(area.position.x, area.get_center().y + 4.0), datos.letra,
			HORIZONTAL_ALIGNMENT_CENTER, area.size.x, UI.T_DETALLE, UI.FONDO)
		return
	var region := datos.region_del_icono()
	var escala := maxf(1.0, floorf(area.size.x / region.size.x))
	var lado := region.size * escala
	icono.draw_texture_rect_region(datos.textura, Rect2(area.get_center() - lado / 2.0, lado), region)


func _elegir(c: DatosColono) -> void:
	elegido = c
	_pintar_filas()
	colono_elegido.emit(c)


## Filas pixel art; la elegida lleva contorno amarillo, como el resaltado del mapa.
func _pintar_filas() -> void:
	for c: DatosColono in filas:
		var boton: Button = filas[c]["boton"]
		var activo := c == elegido
		# Bloque pixel art; la fila elegida lleva el contorno amarillo.
		UI.vestir_boton_pixel(boton, UI.TARJETA, UI.ADVERTENCIA, 6, 6)
		if activo:
			boton.add_theme_stylebox_override("normal", UI.estilo_boton_pixel(UI.TARJETA, UI.ADVERTENCIA, false, 6, 6))


## Tooltip de la fila: quién es, qué hace, dónde está y cuánta radiación lleva.
func _contenido_tooltip(c: DatosColono) -> Dictionary:
	var datos := EstadoJuego.datos_balance
	var lineas := PackedStringArray([
		"Rol: %s" % Enums.NOMBRE_ROL[c.rol],
		"Estado: %s" % Enums.NOMBRE_ESTADO_COLONO[c.estado],
	])
	if not c.tarea.is_empty():
		lineas.append("Tarea: %s (le faltan %s)" % [c.tarea["titulo"], UI.soles(c.soles_restantes)])
	var lugar: String = filas[c]["lugar"].text if filas.has(c) else ""
	if lugar != "":
		lineas.append("Está en: %s" % lugar)
	lineas.append("Radiación: %s de %d. A los %d enferma." % [UI.num(c.radiacion), int(datos.radiacion_max), int(datos.radiacion_enfermedad)])
	if c.estado == Enums.EstadoColono.ENFERMO:
		lineas.append("Se recupera en %s si no le faltan oxígeno, agua ni comida." % UI.soles(c.soles_enfermo))
	return { "titulo": c.nombre, "texto": "\n".join(lineas), "pie": "Clic: señalarlo en el mapa" }


func _actualizar_lugares() -> void:
	for c: DatosColono in filas:
		var modulo := mapa.modulo_de(c)
		var datos: DatosModulo = modulo.datos if modulo != null else null
		filas[c]["lugar"].text = datos.nombre if datos != null else "Exterior"
		if filas[c]["modulo"] != datos:
			filas[c]["modulo"] = datos
			filas[c]["icono"].queue_redraw()
