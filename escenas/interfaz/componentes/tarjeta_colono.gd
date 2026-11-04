class_name TarjetaColono
extends PanelContainer
## Tarjeta de un colono: avatar, nombre, rol, estado y radiación.
## - En los menús de comando (HU-02) y descanso (HU-03) es una ficha estática.
## - Como inspector (HU-06) flota abajo a la derecha y se actualiza cada frame.

signal cerrado
signal regreso_pedido(colono: DatosColono)

const ESCENA := "res://escenas/interfaz/componentes/tarjeta_colono.tscn"

var colono: DatosColono
var es_inspector := false
var estado_label: Label
var ubicacion_label: Label
var radiacion_label: Label
var barra: ProgressBar


## Ficha para listas. Con `al_enviar_a_tierra` añade el botón de regreso.
static func crear(c: DatosColono, con_mision := false, al_enviar_a_tierra := Callable()) -> TarjetaColono:
	var tarjeta: TarjetaColono = load(ESCENA).instantiate()
	tarjeta.configurar(c, con_mision, al_enviar_a_tierra)
	return tarjeta


## Inspector flotante del colono seleccionado en el mapa.
static func crear_inspector(c: DatosColono) -> TarjetaColono:
	var tarjeta: TarjetaColono = load(ESCENA).instantiate()
	tarjeta.configurar_inspector(c)
	return tarjeta


func configurar(c: DatosColono, con_mision := false, al_enviar_a_tierra := Callable()) -> void:
	colono = c
	add_theme_stylebox_override("panel", Hud.estilo(Hud.FONDO_CLARO, Hud.BORDE, Hud.RADIO, 12))
	var f := Hud.fila(10)
	add_child(f)
	f.add_child(Hud.avatar(c))
	var datos := Hud.columna(2)
	f.add_child(Hud.expandir(datos))
	datos.add_child(Hud.etiqueta(c.nombre))
	var estado := c.nombre_estado()
	if con_mision and c.estado == Enums.EstadoColono.EN_MISION:
		estado += " (%d soles)" % c.soles_restantes
	datos.add_child(Hud.etiqueta("%s · %s" % [c.nombre_rol(), estado], 12, Hud.TEXTO_SUAVE))
	datos.add_child(Hud.etiqueta(Hud.texto_radiacion(c.radiacion), 12, Hud.TEXTO_SUAVE))
	datos.add_child(Hud.barra_radiacion(c.radiacion))
	if al_enviar_a_tierra.is_valid():
		f.add_child(Hud.boton("Enviar a la Tierra", al_enviar_a_tierra.bind(c), true, Hud.PELIGRO))


func configurar_inspector(c: DatosColono) -> void:
	colono = c
	es_inspector = true
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_left = -12
	offset_right = -12
	offset_top = -12
	offset_bottom = -12
	custom_minimum_size = Vector2(300, 0)

	var col := Hud.columna(5)
	add_child(col)
	var cabecera := Hud.fila()
	col.add_child(cabecera)
	cabecera.add_child(Hud.avatar(c))
	var nombre := Hud.columna(1)
	cabecera.add_child(Hud.expandir(nombre))
	nombre.add_child(Hud.etiqueta(c.nombre, 15))
	nombre.add_child(Hud.insignia(c.nombre_rol(), c.color_rol()))
	cabecera.add_child(Hud.boton("X", cerrado.emit, true, Hud.FANTASMA))

	estado_label = Hud.etiqueta("", 13, Hud.TEXTO_SUAVE)
	ubicacion_label = Hud.etiqueta("", 13, Hud.TEXTO_SUAVE)
	radiacion_label = Hud.etiqueta("", 13, Hud.TEXTO_SUAVE)
	barra = Hud.barra_radiacion(c.radiacion)
	for control: Control in [estado_label, ubicacion_label, radiacion_label, barra]:
		col.add_child(control)
	col.add_child(Hud.boton("Enviar a la Tierra", func() -> void: regreso_pedido.emit(colono), true, Hud.PELIGRO))
	_actualizar_inspector()


func _process(_delta: float) -> void:
	if es_inspector:
		_actualizar_inspector()


func _actualizar_inspector() -> void:
	estado_label.text = "Estado: %s · %s" % [colono.nombre_estado(), colono.actividad]
	ubicacion_label.text = "Ubicación: %s" % (
		"A la intemperie" if colono.a_la_intemperie else "Dentro de la base")
	radiacion_label.text = Hud.texto_radiacion(colono.radiacion)
	barra.value = colono.radiacion
