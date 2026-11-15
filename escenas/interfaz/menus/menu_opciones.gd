# menu_opciones.gd
# Menú de opciones (solo con Esc): volumen, pantalla completa, controles, tutorial, nueva partida y salir.

class_name MenuOpciones
extends MenuModulo
## Menú de opciones. En la partida no tiene botón: se abre con Esc cuando no
## hay nada más que cerrar (ver Juego._escape) y se cierra con Esc o la X.
## También lo abre el menú de inicio (Inicio); ahí `interfaz` es null y la
## columna de la partida solo ofrece volver.
## Mientras está abierto el tiempo queda en pausa. Los ajustes se guardan en
## user://ajustes.cfg, sección [opciones].
##   SONIDO                                PARTIDA
##   ┌ EFECTOS   [-] ■■■■■■■□□□ [+]  70% ┐ [      CONTINUAR      ]
##   └ AMBIENTE  [-] ■■■■■□□□□□ [+]  50% ┘ [     VER TUTORIAL    ]
##   PANTALLA                              [    NUEVA PARTIDA    ]
##   ┌ [ VENTANA ▓ | COMPLETA ]          ┐ [   SALIR DEL JUEGO   ]
##   CONTROLES
##   ┌ [WASD] MOVER LA CAMARA  ...       ┐

const RUTA_AJUSTES := "user://ajustes.cfg"
const SECCION := "opciones"
const PASOS_VOLUMEN := 10
const ANCHO_PARTIDA := 330
const ESCENA_INICIO := "res://escenas/inicio/inicio.tscn"
## [tecla, lo que hace]
const CONTROLES := [
	["WASD", "Mover la cámara"], ["CLIC DER.", "Arrastrar la cámara"],
	["RUEDA", "Acercar o alejar"], ["ESPACIO", "Pausar o reanudar"],
	["B", "Construir o cancelar"], ["G", "Glosario"],
	["L", "Bitácora"], ["F1", "Tutorial"],
	["ESC", "Cerrar o abrir opciones"], ["Q", "Girar el pasillo"],
	["FLECHAS", "Moverse en los paneles"], ["ENTER", "Elegir en los paneles"],
]

var pausa_previa := false
var _pausa_restaurada := false


func _init() -> void:
	con_cabecera = false     # sin título: como la sala de comandos


func iniciar(juego: Juego, titulo: String) -> void:
	pausa_previa = GestorTiempo.en_pausa
	GestorTiempo.en_pausa = true
	super(juego, titulo)


## En el menú de inicio no hay Juego que lo cierre.
func cerrar() -> void:
	if interfaz != null:
		interfaz.cerrar_menu()
	else:
		queue_free()


func _exit_tree() -> void:
	_restaurar_pausa()


func construir() -> void:
	var f := UI.fila(12)
	f.size_flags_vertical = Control.SIZE_EXPAND_FILL
	contenido.add_child(f)

	var izquierda := UI.columna(6)
	f.add_child(UI.expandir(izquierda))
	izquierda.add_child(Cabina.encabezado("Sonido"))
	var sonido := Cabina.pantalla()
	sonido.size_flags_vertical = Control.SIZE_FILL
	var filas := UI.columna(10)
	filas.add_child(_fila_volumen("Efectos", GestorAudio.volumen_efectos, GestorAudio.fijar_volumen_efectos, "volumen_efectos"))
	filas.add_child(_fila_volumen("Ambiente", GestorAudio.volumen_ambiente, GestorAudio.fijar_volumen_ambiente, "volumen_ambiente"))
	sonido.add_child(filas)
	izquierda.add_child(sonido)

	izquierda.add_child(Cabina.encabezado("Pantalla"))
	var textos: Array[String] = ["VENTANA", "COMPLETA"]
	var colores: Array[Color] = [UI.BIEN, UI.ACENTO]
	var interruptor := InterruptorPixel.new(textos, colores, 1 if pantalla_completa() else 0)
	interruptor.cambiado.connect(func(indice: int) -> void:
		guardar("pantalla_completa", indice == 1)
		aplicar_pantalla())
	izquierda.add_child(interruptor)

	izquierda.add_child(Cabina.encabezado("Controles"))
	var controles := Cabina.pantalla()
	var rejilla := GridContainer.new()
	rejilla.columns = 4
	rejilla.add_theme_constant_override("h_separation", 10)
	rejilla.add_theme_constant_override("v_separation", 10)
	for control: Array in CONTROLES:
		var tecla := Cabina.pildora(control[0], Cabina.NARANJA, false)
		tecla.custom_minimum_size = Vector2(84, 20)
		(tecla.get_child(0) as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rejilla.add_child(tecla)
		var texto := UI.etiqueta_pixel(Cabina.mayus(control[1]), UI.T_DETALLE, UI.TEXTO)
		texto.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rejilla.add_child(UI.expandir(texto))
	controles.add_child(rejilla)
	izquierda.add_child(controles)

	var derecha := UI.columna(8)
	derecha.custom_minimum_size = Vector2(ANCHO_PARTIDA, 0)
	f.add_child(derecha)
	if interfaz == null:
		# Abierto desde el menú de inicio: no hay partida en curso.
		derecha.add_child(Cabina.encabezado("Menu"))
		derecha.add_child(Cabina.boton_grande("Volver", "Al menú de inicio", cerrar))
		derecha.add_child(_relleno())
		var aviso: Array = Cabina.celda(0, 44)
		aviso[1].add_child(Cabina.centrada("LOS AJUSTES SE GUARDAN SOLOS", UI.TEXTO_SUAVE, UI.T_DETALLE))
		aviso[1].add_child(Cabina.centrada("ESC PARA VOLVER", UI.TEXTO_SUAVE, UI.T_DETALLE))
		derecha.add_child(aviso[0])
		return
	derecha.add_child(Cabina.encabezado("Partida", -1, "Sol %d" % GestorTiempo.sol_actual))
	derecha.add_child(Cabina.boton_grande("Continuar", "Volver a la colonia", cerrar))
	derecha.add_child(boton_apagado("Ver tutorial", "Repasar cómo se juega", _ver_tutorial))
	derecha.add_child(boton_apagado("Nueva partida", "Se pierde la colonia actual", _pedir_nueva_partida))
	derecha.add_child(boton_apagado("Menu de inicio", "Se pierde la colonia actual", _pedir_menu_inicio))
	derecha.add_child(boton_apagado("Salir del juego", "Cerrar Little Big Steps", _pedir_salir, UI.CRITICO))
	derecha.add_child(_relleno())
	var nota: Array = Cabina.celda(0, 44)
	nota[1].add_child(Cabina.centrada("TIEMPO EN PAUSA", UI.ADVERTENCIA, UI.T_DETALLE))
	nota[1].add_child(Cabina.centrada("ESC PARA VOLVER", UI.TEXTO_SUAVE, UI.T_DETALLE))
	derecha.add_child(nota[0])


## "EFECTOS  [-] ■■■■■■■□□□ [+]  70%": sube o baja el volumen de 10 en 10.
func _fila_volumen(nombre: String, valor: float, fijar: Callable, clave: String) -> Control:
	var paso := roundi(valor * PASOS_VOLUMEN)
	var cambiar := func(nuevo: int) -> void:
		var v := clampi(nuevo, 0, PASOS_VOLUMEN) / float(PASOS_VOLUMEN)
		fijar.call(v)
		guardar(clave, v)
		_pedir_reconstruccion()
	var f := UI.fila(10)
	var etiqueta := UI.etiqueta_pixel(Cabina.mayus(nombre), UI.T_TEXTO)
	etiqueta.custom_minimum_size = Vector2(100, 0)
	etiqueta.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	f.add_child(etiqueta)
	f.add_child(_boton_paso("-", cambiar.bind(paso - 1), paso > 0))
	var marcas := Cabina.marcas(paso, PASOS_VOLUMEN, Cabina.NARANJA if paso > 0 else Cabina.ROJO, 26)
	marcas.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	f.add_child(marcas)
	f.add_child(_boton_paso("+", cambiar.bind(paso + 1), paso < PASOS_VOLUMEN))
	var porcentaje := UI.etiqueta_pixel("%d%%" % (paso * 10) if paso > 0 else "SILENCIO", UI.T_DETALLE,
		UI.TEXTO_SUAVE if paso > 0 else UI.CRITICO)
	porcentaje.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	f.add_child(porcentaje)
	return f


func _boton_paso(texto: String, accion: Callable, habilitado: bool) -> Button:
	var b := Cabina.boton(texto, accion, habilitado)
	b.add_theme_font_size_override("font_size", UI.T_TEXTO)
	b.custom_minimum_size = Vector2(34, 30)
	return b


## Botón ancho de dos líneas, apagado (el naranja queda para Continuar).
## Al pasar el ratón el contorno toma `color`.
static func boton_apagado(titulo: String, detalle: String, accion: Callable, color := UI.ACENTO) -> Button:
	var b := Cabina.boton_grande(titulo, detalle, accion)
	UI.vestir_boton_pixel(b, Cabina.TARJETA.lightened(0.04), color, 0, 0)
	var etiquetas := b.get_child(0).get_children()
	(etiquetas[0] as Label).add_theme_color_override("font_color", color if color != UI.ACENTO else UI.TEXTO)
	(etiquetas[1] as Label).add_theme_color_override("font_color", UI.TEXTO_SUAVE)
	return b


func _relleno() -> Control:
	var hueco := Control.new()
	hueco.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return hueco


# --- Acciones -------------------------------------------------------------

func _ver_tutorial() -> void:
	var tutorial := interfaz.tutorial
	_restaurar_pausa()               # antes de que el tutorial guarde la pausa
	cerrar()
	if tutorial.activo():
		tutorial.terminar()
	tutorial.iniciar()


func _pedir_nueva_partida() -> void:
	interfaz.confirmar("Nueva partida", "La colonia actual se perderá y empezarás de nuevo en el sol 1.", func() -> void:
		_pausa_restaurada = true     # la partida nueva decide su propia pausa
		EstadoJuego.nueva_partida()
		get_tree().reload_current_scene(), [], "Empezar de nuevo", true)


func _pedir_menu_inicio() -> void:
	interfaz.confirmar("Volver al menú de inicio", "La partida no se guarda: se pierde la colonia actual.", func() -> void:
		_pausa_restaurada = true     # el menú de inicio deja el tiempo en pausa
		get_tree().change_scene_to_file(ESCENA_INICIO), [], "Ir al menú", true)


func _pedir_salir() -> void:
	interfaz.confirmar("Salir del juego", "La partida no se guarda: al salir se pierde la colonia actual.",
		func() -> void: get_tree().quit(), [], "Salir", true)


func _restaurar_pausa() -> void:
	if not _pausa_restaurada:
		_pausa_restaurada = true
		GestorTiempo.en_pausa = pausa_previa


# --- Ajustes guardados ------------------------------------------------------

static func leer(clave: String, defecto: Variant) -> Variant:
	var ajustes := ConfigFile.new()
	if ajustes.load(RUTA_AJUSTES) != OK:
		return defecto
	return ajustes.get_value(SECCION, clave, defecto)


static func guardar(clave: String, valor: Variant) -> void:
	var ajustes := ConfigFile.new()
	ajustes.load(RUTA_AJUSTES)
	ajustes.set_value(SECCION, clave, valor)
	ajustes.save(RUTA_AJUSTES)


static func pantalla_completa() -> bool:
	return leer("pantalla_completa", false)


## Pone la ventana como diga el ajuste guardado (al arrancar y al cambiarlo).
static func aplicar_pantalla() -> void:
	var modo := DisplayServer.WINDOW_MODE_FULLSCREEN if pantalla_completa() else DisplayServer.WINDOW_MODE_MAXIMIZED
	var actual := DisplayServer.window_get_mode()
	if actual == modo:
		return
	if actual == DisplayServer.WINDOW_MODE_FULLSCREEN:
		# De pantalla completa no se puede pasar directo a maximizada (se queda
		# en completa): primero ventana normal y, unos cuadros después, maximizada.
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var arbol := Engine.get_main_loop() as SceneTree
		await arbol.create_timer(0.15).timeout
		if pantalla_completa():
			return                       # lo volvieron a cambiar mientras tanto
	DisplayServer.window_set_mode(modo)
