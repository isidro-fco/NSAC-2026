# mapa.gd
# Mapa de la colonia: suelo, módulos, obstáculos, colonos y modos de construcción y demolición; avisa a la interfaz por señales.

class_name Mapa
extends Node2D
## Mapa de la colonia: suelo, módulos, obstáculos, colonos y los modos de
## construcción/demolición (HU-05). No conoce la interfaz: le habla por señales.

signal modo_cambiado(modo: Enums.ModoMapa)
signal colono_clicado(colono: Colono)
signal modulo_clicado(id: String)
## `filas` son las líneas [recurso, cambio, quedará] de la tabla del aviso (docs/diseno/aviso.png).
signal confirmacion_pedida(titulo: String, texto: String, accion: Callable, filas: Array,
		texto_confirmar: String, peligro: bool)
signal aviso_pedido(texto: String)
## Texto del coste al señalar algo en modo demolición; "" para ocultarlo.
signal etiqueta_demolicion(texto: String)

const TEX_SUELO: Array[Texture2D] = [
	preload("res://recursos/sprites/suelo/suelo1.png"), preload("res://recursos/sprites/suelo/suelo2.png"),
]
const MODULOS_CON_MENU := ["comando", "descanso", "almacen", "refugio"]
const SIN_ORIGEN := Vector2i(-1000, -1000)
## Casillas de terreno decorativo alrededor del mapa: la cámara cubre toda la
## ventana y deja ver un poco más allá del borde bajo la barra superior.
const BORDE_DECORATIVO := 8
## Radio (en fracción del tamaño del módulo) de la zona donde se paran los
## colonos: el edificio es el círculo central del sprite; las esquinas son terreno.
const RADIO_INTERIOR := 0.2
## Colores de la franja de peligro y de la grava que rodean el edificio en los
## sprites de módulos: todo eso es exterior (a_cubierto).
const COLORES_PLATAFORMA: Array[Color] = [
	Color8(255, 195, 0), Color8(51, 51, 51), Color8(51, 50, 50), Color8(79, 64, 107), Color8(105, 96, 121),
]

@export_range(0.0, 1.0) var densidad_obstaculos := 0.15
@export_range(0.0, 1.0) var fraccion_crater_grande := 0.1
@export var semilla := 0                     # 0 = aleatoria

var cuadricula := GestorCuadricula.new()
var rutas := BuscadorRutas.new()
var rng := RandomNumberGenerator.new()
var suelo := []                   # suelo[y][x] -> textura
var decorado := {}                # casilla fuera del mapa -> textura de suelo
var rocas_decorado := {}          # casilla fuera del mapa -> textura de roca (encima del suelo)
var contenedor_naves := Node2D.new()
var capa_pasillos := CapaPasillos.new()
var _mascaras := {}               # textura de módulo -> PackedByteArray (1 = edificio)
var resaltado := ResaltadoColono.new()
var viento := Viento.new()
var _nave_activa: NaveAterrizaje
var _naves_en_cola: Array[NaveAterrizaje] = []    # esperan a que la plataforma quede libre

var modo: Enums.ModoMapa = Enums.ModoMapa.NORMAL
var modulo_elegido: DatosModulo
var rotacion_pasillo := 0      # cuartos de vuelta del próximo pasillo (tecla Q)
var objetivo_demoler: ElementoMapa
var modal_abierto := false:       # menú o diálogo sobre el mapa
	set(valor):
		modal_abierto = valor
		# Al cerrarse el diálogo de confirmación, la vista previa vuelve a seguir al ratón.
		if not valor and origen_fijado != SIN_ORIGEN:
			origen_fijado = SIN_ORIGEN
			capa.queue_redraw()
## Casilla elegida con el clic mientras se espera la confirmación; así la vista
## previa se queda quieta en vez de seguir al ratón.
var origen_fijado := SIN_ORIGEN

@onready var contenedor_obstaculos: Node2D = $Obstaculos
@onready var contenedor_modulos: Node2D = $Modulos
@onready var capa: Node2D = $Capa                  # cuadrícula y previsualización
@onready var contenedor_colonos: Node2D = $Colonos


func _ready() -> void:
	capa.draw.connect(_dibujar_capa)
	if semilla == 0:
		rng.randomize()
	else:
		rng.seed = semilla
	cuadricula.reiniciar()
	for y in GestorCuadricula.ALTO:
		suelo.append(range(GestorCuadricula.ANCHO).map(func(_x: int) -> Texture2D:
			return TEX_SUELO[rng.randi_range(0, TEX_SUELO.size() - 1)]))
	GeneradorMapa.generar(self, rng)
	_generar_decorado()
	rutas.actualizar(cuadricula)
	capa_pasillos.mapa = self                      # antes de los módulos: queda debajo de ellos
	add_child(capa_pasillos)
	move_child(capa_pasillos, contenedor_modulos.get_index())
	resaltado.mapa = self
	resaltado.z_index = 2                          # como los colonos, pero dibujado antes:
	add_child(resaltado)                           # el halo queda detrás del sprite
	move_child(resaltado, contenedor_colonos.get_index())
	contenedor_naves.z_index = 3                   # por encima de los colonos
	add_child(contenedor_naves)
	viento.z_index = 4                             # el polvo pasa por encima de todo el mapa
	add_child(viento)
	for c: DatosColono in EstadoJuego.tripulacion.colonos:
		_crear_colono(c, punto_en_modulo("descanso"))
	EstadoJuego.colono_agregado.connect(_recibir_colono)
	EstadoJuego.suministros_recibidos.connect(_recibir_suministros)
	EstadoJuego.colono_retirado.connect(func(datos: DatosColono) -> void:
		for colono: Colono in contenedor_colonos.get_children():
			if colono.datos == datos:
				colono.queue_free())


func agregar_modulo(id: String, origen: Vector2i, rotacion := 0) -> void:
	var modulo := Modulo.new(origen, DatosModulo.obtener(id))
	modulo.rotacion = rotacion
	contenedor_modulos.add_child(modulo)
	cuadricula.ocupar_modulo(modulo)
	rutas.actualizar(cuadricula)          # antes de avisar: los colonos reaccionan al aviso
	EstadoJuego.economia.registrar_modulo(id)
	capa_pasillos.queue_redraw()


func agregar_obstaculo(origen: Vector2i, tam: Vector2i, textura: Texture2D) -> void:
	var obstaculo := Obstaculo.new(origen, tam, textura)
	contenedor_obstaculos.add_child(obstaculo)
	cuadricula.ocupar_obstaculo(obstaculo)


# --- Consultas (las usan los colonos) -------------------------------------

## Casilla al azar dentro del módulo `id` (o del de comando si no existe).
func celda_en_modulo(id: String) -> Vector2i:
	var modulos := modulos_de(id)
	if modulos.is_empty():
		modulos = modulos_de("comando")
	return celda_en(modulos[0] as Modulo)


func celda_en(modulo: Modulo) -> Vector2i:
	var tam := modulo.tam_celdas()
	return modulo.origen + Vector2i(rng.randi_range(0, tam.x - 1), rng.randi_range(0, tam.y - 1))


## Punto al azar (en píxeles) dentro del edificio del módulo `id`, o del de comando si no existe.
func punto_en_modulo(id: String) -> Vector2:
	var modulos := modulos_de(id)
	if modulos.is_empty():
		modulos = modulos_de("comando")
	return punto_en(modulos[0] as Modulo)


## Punto al azar (en píxeles) dentro de la zona central del módulo, donde está
## el edificio; así ningún colono se queda parado en las esquinas de tierra.
func punto_en(modulo: Modulo) -> Vector2:
	var tam := Vector2(modulo.tam_celdas()) * GestorCuadricula.TAM_CELDA
	var desvio := Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf())
	return modulo.position + tam / 2.0 + desvio * tam * RADIO_INTERIOR


func modulos_de(id: String) -> Array[Node]:
	return contenedor_modulos.get_children().filter(func(m: Modulo) -> bool: return m.datos.id == id)


## Primer módulo `id` al que se llega andando desde la casilla `desde` (o en el que
## ya está), o null si no hay ninguno conectado.
func modulo_alcanzable(id: String, desde: Vector2i) -> Modulo:
	for m: Modulo in modulos_de(id):
		if cuadricula.celdas_modulo.get(desde) == m or not rutas.ruta(desde, m.origen).is_empty():
			return m
	return null


## HU-08: refugio al que debe ir el colono durante una tormenta solar, o null.
## Cada refugio acoge a `capacidad_refugio` colonos, por orden de la tripulación.
func refugio_para(datos: DatosColono) -> Modulo:
	if not EstadoJuego.eventos.tormenta_activa():
		return null
	# Solo los refugios a los que se puede llegar andando desde la base.
	var comando := celda_en_modulo("comando")
	var refugios := modulos_de("refugio").filter(
		func(r: Modulo) -> bool: return not rutas.ruta(comando, r.origen).is_empty())
	var plazas: int = EstadoJuego.datos_balance.capacidad_refugio
	var i := EstadoJuego.tripulacion.colonos.find(datos)
	return refugios[i / plazas] as Modulo if i >= 0 and i < refugios.size() * plazas else null


## true si el punto (píxeles del mapa) cae sobre lo que se ve techado: un
## pasillo o el edificio de un módulo (dentro de su contorno negro; la grava,
## la franja de peligro y las esquinas son exterior). Afuera los colonos se ven
## con traje. Solo es visual: la radiación sigue usando ubicacion().
func a_cubierto(punto: Vector2) -> bool:
	var c := GestorCuadricula.celda_desde_pixel(punto)
	if capa_pasillos.cubre(c):
		return true
	var m: Modulo = cuadricula.celdas_modulo.get(c)
	return m != null and _sobre_edificio(m, punto)


## true si el punto cae dentro del contorno negro del edificio de un módulo
## (sin contar pasillos ni la plataforma, que son de paso): ahí el colono entró
## al edificio y no se ve, esté quieto o de pasada.
func dentro_de_edificio(punto: Vector2) -> bool:
	var m: Modulo = cuadricula.celdas_modulo.get(GestorCuadricula.celda_desde_pixel(punto))
	return m != null and m.datos.id not in Colono.MODULOS_DE_PASO and _sobre_edificio(m, punto)


## true si el punto cae sobre el edificio del sprite de `m` (ver _mascara_edificio).
func _sobre_edificio(m: Modulo, punto: Vector2) -> bool:
	if m.datos.textura == null:
		return true
	var textura := m.datos.textura
	if not _mascaras.has(textura):
		_mascaras[textura] = _mascara_edificio(textura.get_image())
	var ancho := textura.get_width()
	var tam_px := Vector2(m.tam_celdas()) * GestorCuadricula.TAM_CELDA
	var p := Vector2i((punto - m.position) * Vector2(textura.get_size()) / tam_px)
	p = p.clamp(Vector2i.ZERO, Vector2i(textura.get_size()) - Vector2i.ONE)
	return _mascaras[textura][p.y * ancho + p.x] == 1


## Máscara (1 por píxel del edificio) de un sprite de módulo: la mayor pieza de
## lo que no es transparente, franja ni grava, con sus huecos rellenos. Así el
## límite es el contorno del edificio aunque tenga líneas negras por dentro.
static func _mascara_edificio(imagen: Image) -> PackedByteArray:
	var ancho := imagen.get_width()
	var alto := imagen.get_height()
	var total := ancho * alto
	var plataforma := {}
	for color in COLORES_PLATAFORMA:
		plataforma[Vector3i(color.r8, color.g8, color.b8)] = true
	var candidato := PackedByteArray()
	candidato.resize(total)
	for y in alto:
		for x in ancho:
			var p := imagen.get_pixel(x, y)
			candidato[y * ancho + x] = 1 if p.a > 0.0 and not plataforma.has(Vector3i(p.r8, p.g8, p.b8)) else 0
	# Pieza más grande (el edificio): descarta banderas, antenas y motas.
	var pieza := PackedInt32Array()
	pieza.resize(total)
	var mayor := 0
	var tam_mayor := 0
	var cuenta := 0
	for i in total:
		if candidato[i] == 0 or pieza[i] != 0:
			continue
		cuenta += 1
		pieza[i] = cuenta
		var tam := 0
		var pila: Array[int] = [i]
		while not pila.is_empty():
			var j: int = pila.pop_back()
			tam += 1
			for v in _vecinos(j, ancho, alto):
				if candidato[v] == 1 and pieza[v] == 0:
					pieza[v] = cuenta
					pila.append(v)
		if tam > tam_mayor:
			mayor = cuenta
			tam_mayor = tam
	# Rellenar huecos: es exterior solo lo que se alcanza desde el borde sin cruzar el edificio.
	var mascara := PackedByteArray()
	mascara.resize(total)
	mascara.fill(1)
	var pendientes: Array[int] = []
	for x in ancho:
		pendientes.append(x)
		pendientes.append((alto - 1) * ancho + x)
	for y in alto:
		pendientes.append(y * ancho)
		pendientes.append(y * ancho + ancho - 1)
	while not pendientes.is_empty():
		var j: int = pendientes.pop_back()
		if mascara[j] == 0 or pieza[j] == mayor:
			continue
		mascara[j] = 0
		pendientes.append_array(_vecinos(j, ancho, alto))
	return mascara


static func _vecinos(i: int, ancho: int, alto: int) -> Array[int]:
	var x := i % ancho
	var y := i / ancho
	var lista: Array[int] = []
	if x > 0: lista.append(i - 1)
	if x < ancho - 1: lista.append(i + 1)
	if y > 0: lista.append(i - ancho)
	if y < alto - 1: lista.append(i + ancho)
	return lista


## "interior", "exterior" o "refugio" según la casilla.
func ubicacion(c: Vector2i) -> String:
	if not cuadricula.es_estructura(c):
		return "exterior"
	return "refugio" if cuadricula.celdas_modulo[c].datos.id == "refugio" else "interior"


## Nodo en el mapa del colono `datos`, o null si todavía viene en la nave.
func colono_de(datos: DatosColono) -> Colono:
	for colono: Colono in contenedor_colonos.get_children():
		if colono.datos == datos:
			return colono
	return null


## Módulo del colono para el panel de tripulación: en el que está, o al que va
## si está caminando; la plataforma si todavía viene en la nave; null si está en
## el exterior.
func modulo_de(datos: DatosColono) -> Modulo:
	var colono := colono_de(datos)
	if colono == null:
		var plataformas := modulos_de("plataforma")
		return null if plataformas.is_empty() else plataformas[0] as Modulo
	return cuadricula.celdas_modulo.get(colono.destino if colono.en_camino() else colono.celda)


## Resalta en amarillo al colono (o a su módulo si está dentro); null lo quita.
func resaltar(datos: DatosColono) -> void:
	resaltado.resaltar(datos)


func _crear_colono(datos: DatosColono, punto: Vector2) -> void:
	var colono := Colono.new()
	contenedor_colonos.add_child(colono)
	colono.configurar(datos, self, punto)


# --- Llegadas desde la Tierra (HU-09) -------------------------------------

## Un colono contratado llegó: viene en una nave que aterriza en la plataforma.
## Si ya hay una nave de tripulación bajando o esperando, viaja en ella.
func _recibir_colono(datos: DatosColono) -> void:
	for nave in [_nave_activa] + _naves_en_cola:      # sin tipo: _nave_activa puede ser null
		if is_instance_valid(nave) and nave.tipo == NaveAterrizaje.Tipo.TRIPULACION and nave.bajando():
			nave.colonos.append(datos)
			return
	var nueva := NaveAterrizaje.new(NaveAterrizaje.Tipo.TRIPULACION, _punto_aterrizaje())
	EstadoJuego.curiosidades.disparar("nave:colonos")
	nueva.colonos.append(datos)
	_encolar_nave(nueva)


## Llegaron víveres, materiales u oxígeno: los trae una nave de carga.
func _recibir_suministros(_nombre: String, contenido: Dictionary) -> void:
	var nueva := NaveAterrizaje.new(NaveAterrizaje.Tipo.CARGA, _punto_aterrizaje())
	nueva.carga = contenido
	_encolar_nave(nueva)


## Una sola nave en la plataforma a la vez: las demás esperan su turno.
func _encolar_nave(nave: NaveAterrizaje) -> void:
	nave.colono_desembarcado.connect(_desembarcar)
	nave.terminada.connect(_siguiente_nave)
	if is_instance_valid(_nave_activa):
		_naves_en_cola.append(nave)
	else:
		_lanzar_nave(nave)


func _lanzar_nave(nave: NaveAterrizaje) -> void:
	_nave_activa = nave
	contenedor_naves.add_child(nave)


func _siguiente_nave() -> void:
	_nave_activa = null
	if not _naves_en_cola.is_empty():
		_lanzar_nave(_naves_en_cola.pop_front())


## Un colono bajó la rampa de la nave: desde ahí ya camina por su cuenta
## (salvo que se haya vuelto a la Tierra mientras bajaba).
func _desembarcar(datos: DatosColono, punto: Vector2) -> void:
	if EstadoJuego.tripulacion.colonos.has(datos):
		_crear_colono(datos, punto)


## Centro de la plataforma de aterrizaje.
func _punto_aterrizaje() -> Vector2:
	var plataformas := modulos_de("plataforma")
	if plataformas.is_empty():
		return GestorCuadricula.centro_celda(GestorCuadricula.centro_mapa())
	var plataforma := plataformas[0] as Modulo
	return plataforma.position + Vector2(plataforma.tam_celdas()) * GestorCuadricula.TAM_CELDA / 2.0


func _mapa_modificado() -> void:
	rutas.actualizar(cuadricula)
	for colono: Colono in contenedor_colonos.get_children():
		colono.replanificar()
	capa.queue_redraw()
	capa_pasillos.queue_redraw()


# --- Modos de construcción (HU-05) ----------------------------------------

func cambiar_modo(nuevo: Enums.ModoMapa) -> void:
	modo = nuevo
	origen_fijado = SIN_ORIGEN
	if modo != Enums.ModoMapa.COLOCANDO:
		modulo_elegido = null
	if modo != Enums.ModoMapa.DEMOLICION:
		objetivo_demoler = null
		etiqueta_demolicion.emit("")
	capa.queue_redraw()
	modo_cambiado.emit(modo)


func alternar_construccion() -> void:
	cambiar_modo(Enums.ModoMapa.CATALOGO if modo == Enums.ModoMapa.NORMAL else Enums.ModoMapa.NORMAL)


func elegir_modulo(id: String) -> void:
	modulo_elegido = DatosModulo.obtener(id)
	cambiar_modo(Enums.ModoMapa.COLOCANDO)


## Responde a Escape cuando no hay ningún menú abierto.
func cancelar_modo() -> void:
	cambiar_modo(Enums.ModoMapa.CATALOGO if modo == Enums.ModoMapa.COLOCANDO else Enums.ModoMapa.NORMAL)


func origen_preview() -> Vector2i:
	if origen_fijado != SIN_ORIGEN:
		return origen_fijado
	var celda := GestorCuadricula.celda_desde_pixel(get_global_mouse_position())
	return celda - (modulo_elegido.tam - Vector2i.ONE) / 2


func _se_puede_construir(d: DatosModulo, origen: Vector2i) -> bool:
	return cuadricula.puede_colocar(d, origen) and EstadoJuego.economia.puede_pagar(d.dinero, d.materiales)


func _pedir_construccion(origen: Vector2i) -> void:
	var d := modulo_elegido
	if not _se_puede_construir(d, origen):
		GestorAudio.reproducir("casilla_invalida")
		return
	origen_fijado = origen
	capa.queue_redraw()
	var filas := [
		UI.fila_cambio(Idioma.t("Presupuesto"), "presupuesto", -d.dinero),
		UI.fila_cambio(Idioma.t("Materiales"), "materiales", -d.materiales),
	]
	var economia := EstadoJuego.economia
	var cambio_kw: float = d.produce.get("energia", 0.0) - d.consumo_kw
	if cambio_kw != 0.0:
		var antes := economia.balance("energia")
		filas.append([(Idioma.t("Energía producida") if cambio_kw > 0.0 else Idioma.t("Energía que gasta")), UI.kw(cambio_kw, true),
			Idioma.t("balance %s a %s") % [UI.kw(antes, true), UI.kw(antes + cambio_kw, true)]])
	confirmacion_pedida.emit(Idioma.t("¿Construir %s?") % d.nombre, Idioma.t("Ocupa %dx%d casillas") % [d.tam.x, d.tam.y],
		construir.bind(d, origen), filas, Idioma.t("Construir"), false)


func construir(d: DatosModulo, origen: Vector2i) -> void:
	if not _se_puede_construir(d, origen):
		return
	EstadoJuego.economia.pagar(d.dinero, d.materiales)
	agregar_modulo(d.id, origen, rotacion_pasillo if d.es_pasillo() else 0)
	EstadoJuego.curiosidades.disparar("construir:" + d.id)
	GestorAudio.reproducir("poner_modulo")
	EstadoJuego.modulos_construidos += 1
	if not d.es_pasillo():
		EstadoJuego.registrar(Enums.Categoria.ACCION, Idioma.t("Construido: %s") % d.nombre, false)
	_mapa_modificado()
	# Los pasillos se trazan por tramos: se sigue colocando mientras alcance.
	if modo == Enums.ModoMapa.COLOCANDO \
			and (not d.es_pasillo() or not EstadoJuego.economia.puede_pagar(d.dinero, d.materiales)):
		cambiar_modo(Enums.ModoMapa.CATALOGO)


func _pedir_demolicion(objetivo: ElementoMapa) -> void:
	var coste := objetivo.coste_demoler()
	if not EstadoJuego.economia.puede_pagar(coste, 0):
		aviso_pedido.emit(Idioma.t("No hay dinero para la demolición"))
		return
	var filas := [UI.fila_cambio(Idioma.t("Costo del trabajo"), "presupuesto", -coste)]
	if objetivo.materiales_al_demoler() > 0:
		filas.append(UI.fila_cambio(Idioma.t("Materiales obtenidos"), "materiales", objetivo.materiales_al_demoler()))
	confirmacion_pedida.emit(_titulo_demolicion(objetivo), objetivo.nombre(), demoler.bind(objetivo), filas, Idioma.t("Demoler"), true)


func _titulo_demolicion(objetivo: ElementoMapa) -> String:
	if objetivo is Obstaculo:
		return Idioma.t("¿Allanar este cráter?") if (objetivo as Obstaculo).es_crater() else Idioma.t("¿Excavar esta roca?")
	return Idioma.t("¿Demoler este módulo?")


func demoler(objetivo: ElementoMapa) -> void:
	if not is_instance_valid(objetivo) or not EstadoJuego.economia.puede_pagar(objetivo.coste_demoler(), 0):
		return
	EstadoJuego.economia.pagar(objetivo.coste_demoler(), 0)
	GestorAudio.reproducir("quitar_piedra" if objetivo is Obstaculo else "quitar_modulo")
	EstadoJuego.registrar(Enums.Categoria.ACCION, Idioma.t("Demolido: %s") % objetivo.nombre(), false)
	cuadricula.liberar(objetivo.origen, objetivo.tam_celdas())
	if objetivo is Modulo:
		EstadoJuego.economia.quitar_modulo((objetivo as Modulo).datos.id)
	else:
		EstadoJuego.economia.sumar("materiales", objetivo.materiales_al_demoler())
		EstadoJuego.estado_cambiado.emit()
	objetivo.get_parent().remove_child(objetivo)
	objetivo.queue_free()
	objetivo_demoler = null
	etiqueta_demolicion.emit("")
	_mapa_modificado()


# --- Entrada --------------------------------------------------------------

func _process(_delta: float) -> void:
	if modo == Enums.ModoMapa.COLOCANDO:
		capa.queue_redraw()
	elif modo == Enums.ModoMapa.DEMOLICION:
		_actualizar_objetivo_demoler()


func _unhandled_input(event: InputEvent) -> void:
	# Q gira el pasillo que se está colocando (horizontal <-> vertical).
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_Q \
			and not modal_abierto and modo == Enums.ModoMapa.COLOCANDO and modulo_elegido.es_pasillo():
		rotacion_pasillo = (rotacion_pasillo + 1) % 4
		capa.queue_redraw()
		get_viewport().set_input_as_handled()
		return
	if modal_abierto or event is not InputEventMouseButton:
		return
	# El clic derecho cancela al soltar: si hubo arrastre, la cámara ya se quedó el evento.
	if event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed and modo == Enums.ModoMapa.COLOCANDO:
		cambiar_modo(Enums.ModoMapa.CATALOGO)
	elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_clic_izquierdo()


func _clic_izquierdo() -> void:
	var punto := get_global_mouse_position()
	var c := GestorCuadricula.celda_desde_pixel(punto)
	match modo:
		Enums.ModoMapa.COLOCANDO:
			_pedir_construccion(origen_preview())
		Enums.ModoMapa.DEMOLICION:
			if GestorCuadricula.dentro_del_mapa(c) and cuadricula.objetivo_en(c) != null:
				_pedir_demolicion(cuadricula.objetivo_en(c))
		Enums.ModoMapa.NORMAL:
			for colono: Colono in contenedor_colonos.get_children():
				# Los que están dentro de un módulo no se ven: el clic va al módulo.
				if not colono.oculto() and colono.position.distance_to(punto) <= Colono.RADIO_CLIC:
					colono_clicado.emit(colono)
					return
			if cuadricula.celdas_modulo.has(c) and cuadricula.celdas_modulo[c].datos.id in MODULOS_CON_MENU:
				modulo_clicado.emit(cuadricula.celdas_modulo[c].datos.id)


func _actualizar_objetivo_demoler() -> void:
	var objetivo: ElementoMapa = null
	var c := GestorCuadricula.celda_desde_pixel(get_global_mouse_position())
	if get_viewport().gui_get_hovered_control() == null and not modal_abierto and GestorCuadricula.dentro_del_mapa(c):
		objetivo = cuadricula.objetivo_en(c)
	if objetivo == null:
		etiqueta_demolicion.emit("")
	else:
		var extra := ""
		if objetivo.materiales_al_demoler() > 0:
			extra = "  +%d mat." % objetivo.materiales_al_demoler()
		etiqueta_demolicion.emit(Idioma.t("Demoler: %s%s") % [UI.dinero(objetivo.coste_demoler()), extra])
	if objetivo != objetivo_demoler:
		objetivo_demoler = objetivo
		capa.queue_redraw()


# --- Render top-down ------------------------------------------------------

func _draw() -> void:
	for y in GestorCuadricula.ALTO:
		for x in GestorCuadricula.ANCHO:
			draw_texture(suelo[y][x], Vector2(x, y) * GestorCuadricula.TAM_CELDA)
	for c: Vector2i in decorado:
		draw_texture(decorado[c], Vector2(c) * GestorCuadricula.TAM_CELDA)
	for c: Vector2i in rocas_decorado:
		draw_texture(rocas_decorado[c], Vector2(c) * GestorCuadricula.TAM_CELDA)


## Terreno y rocas alrededor del mapa jugable (solo se dibujan; no se pueden
## pisar ni demoler). Usa su propio azar para no alterar el mapa de la partida.
func _generar_decorado() -> void:
	var azar := RandomNumberGenerator.new()
	azar.seed = rng.seed + 1
	var b := BORDE_DECORATIVO
	for y in range(-b, GestorCuadricula.ALTO + b):
		for x in range(-b, GestorCuadricula.ANCHO + b):
			var c := Vector2i(x, y)
			if GestorCuadricula.dentro_del_mapa(c):
				continue
			decorado[c] = TEX_SUELO[azar.randi_range(0, TEX_SUELO.size() - 1)]
			if azar.randf() < densidad_obstaculos:
				var rocas := GeneradorMapa.TEX_OBSTACULOS
				rocas_decorado[c] = rocas[azar.randi_range(0, rocas.size() - 1)]


func _dibujar_capa() -> void:
	if modo == Enums.ModoMapa.NORMAL:
		return
	var lado := GestorCuadricula.TAM_CELDA
	for y in GestorCuadricula.ALTO:
		for x in GestorCuadricula.ANCHO:
			var c := Vector2i(x, y)
			var rect := Rect2(Vector2(c) * lado, Vector2.ONE * lado)
			match cuadricula.estado(c):
				Enums.EstadoCasilla.OCUPADA:
					capa.draw_rect(rect, Color(UI.BIEN, 0.28))
				Enums.EstadoCasilla.BLOQUEADA:
					capa.draw_rect(rect, Color(UI.FONDO, 0.55))
			capa.draw_rect(rect, Color(1, 1, 1, 0.22), false, 1.0)
	if modo == Enums.ModoMapa.COLOCANDO:
		var d := modulo_elegido
		var origen := origen_preview()
		var tinte := UI.BIEN if cuadricula.puede_colocar(d, origen) else UI.CRITICO
		var rect := Rect2(Vector2(origen) * lado, Vector2(d.tam) * lado)
		# Sprite del módulo medio transparente y teñido de verde (válido) o rojo (inválido).
		if d.textura:
			Modulo.dibujar_textura(capa, d.textura, rect, rotacion_pasillo if d.es_pasillo() else 0,
				Color(Color.WHITE.lerp(tinte, 0.45), 0.6))
		else:
			capa.draw_rect(rect, d.color * Color(1, 1, 1, 0.45))
		capa.draw_rect(rect, Color(tinte, 0.25))
		capa.draw_rect(rect, tinte, false, 2.0)
	elif modo == Enums.ModoMapa.DEMOLICION and is_instance_valid(objetivo_demoler):
		var rect := Rect2(objetivo_demoler.position, Vector2(objetivo_demoler.tam_celdas()) * lado)
		capa.draw_rect(rect, UI.CRITICO, false, 3.0)
