class_name TarjetaColono
extends PanelContainer
## Tarjeta de un colono (docs/diseno/Modulo Comando.pdf):
##   ╭──────────────────────────────╮
##   │ (foto) Elena Vargas Ruiz     │   foto de perfil en un círculo
##   │        Ingeniería · Disponible
##   │        Radiación: 14.3 / 120 │
##   │        ▬▬▬▬▬───────────────  │
##   ╰──────────────────────────────╯
## - En los menús de comando (HU-02) y descanso (HU-03) es una ficha estática.
## - Como inspector (HU-06) flota abajo a la derecha, añade la ubicación y se
##   actualiza cada frame.

signal cerrado

var colono: DatosColono
var es_inspector := false
var con_mision := false
var estado_label: RichTextLabel
var radiacion_label: RichTextLabel
var barra: ProgressBar


## Con `al_enviar_a_tierra` añade el botón de regreso; con `inspector`, además el de cerrar.
func _init(c: DatosColono, al_enviar_a_tierra := Callable(), inspector := false, mision := false) -> void:
	colono = c
	es_inspector = inspector
	con_mision = mision
	var caja := UI.estilo(UI.FONDO_CLARO if inspector else UI.TARJETA, UI.BORDE, UI.RADIO, 10, 2)
	caja.content_margin_top = 8
	caja.content_margin_bottom = 8
	add_theme_stylebox_override("panel", caja)
	var f := UI.fila(10)
	add_child(f)
	f.add_child(UI.avatar(c, 40 if inspector else 34))
	var datos := UI.columna(3)
	f.add_child(UI.expandir(datos))
	datos.add_child(UI.etiqueta_pixel(c.nombre, UI.T_TEXTO))
	estado_label = UI.texto_glosario("", 11, UI.TEXTO)
	radiacion_label = UI.texto_glosario("", 11, UI.ADVERTENCIA)
	barra = UI.barra_radiacion(c.radiacion)
	barra.custom_minimum_size = Vector2(0, 4)
	for control: Control in [estado_label, radiacion_label, barra]:
		datos.add_child(control)
	if al_enviar_a_tierra.is_valid():
		var enviar := UI.boton("Enviar a la Tierra", al_enviar_a_tierra.bind(c), true, UI.PELIGRO)
		enviar.add_theme_font_size_override("font_size", UI.T_DETALLE)
		enviar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		f.add_child(enviar)
	if inspector:
		var x := UI.boton_pixel("X", cerrado.emit, false, UI.T_TEXTO)
		x.custom_minimum_size = Vector2(28, 28)
		x.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		f.add_child(x)
		custom_minimum_size = Vector2(320, 0)
		set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 12)
		grow_horizontal = Control.GROW_DIRECTION_BEGIN
		grow_vertical = Control.GROW_DIRECTION_BEGIN
		offset_top -= 60          # por encima de los botones inferiores del HUD
		offset_bottom -= 60
	_actualizar()


func _process(_delta: float) -> void:
	if es_inspector:
		_actualizar()


func _actualizar() -> void:
	var estado := "%s · %s" % [Enums.NOMBRE_ROL[colono.rol], Enums.NOMBRE_ESTADO_COLONO[colono.estado]]
	if colono.estado == Enums.EstadoColono.EN_VIAJE:
		estado += " (llega en %s)" % UI.soles(colono.soles_restantes)
	elif con_mision and colono.estado == Enums.EstadoColono.EN_MISION:
		estado += " (%s)" % UI.soles(colono.soles_restantes)
	if es_inspector:
		var lugar: String = {"exterior": "A la intemperie", "interior": "Dentro de la base",
			"refugio": "En el refugio blindado"}[colono.ubicacion]
		estado += " · %s\n%s" % [colono.actividad, lugar]
	UI.fijar_texto(estado_label, estado)
	UI.fijar_texto(radiacion_label, "Radiación: %s / %d" % [UI.num(colono.radiacion), int(EstadoJuego.datos_balance.radiacion_max)])
	barra.value = colono.radiacion
