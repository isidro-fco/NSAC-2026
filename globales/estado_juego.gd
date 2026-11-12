extends Node
## Autoload "EstadoJuego": el corazón de la partida.
##
## No guarda casi nada él mismo: reparte el trabajo entre sistemas
## (en globales/sistemas/), cada uno con sus datos y sus reglas:
##   EstadoJuego.economia     -> recursos, producción, consumo y pagos
##   EstadoJuego.almacen      -> capacidad del depósito, raciones y cocina
##   EstadoJuego.tripulacion  -> colonos, salud, cuartos y reclutamiento
##   EstadoJuego.tareas       -> tareas y misiones
##   EstadoJuego.comando      -> niveles del Módulo de Comando (y la victoria)
##   EstadoJuego.eventos      -> incidentes aleatorios y tormentas solares (HU-08)
##   EstadoJuego.tierra       -> envíos y fondos con retraso desde la Tierra (HU-09)
##   EstadoJuego.glosario     -> términos técnicos descubiertos (HU-12)
##
## Aquí quedan las señales (para que la interfaz y el mapa se enteren de los
## cambios), la bitácora (HU-10), el inicio de la partida y lo que ocurre al
## terminar cada sol. No conoce la interfaz ni el mapa. El paso de los soles lo
## marca GestorTiempo.

signal estado_cambiado                          # algo cambió: redibujar la interfaz
signal sol_terminado
signal colono_agregado(colono: DatosColono)     # llegó a la base
signal colono_retirado(colono: DatosColono)
signal aviso(texto: String)                     # mensaje corto para el jugador
signal partida_terminada(motivo: String)
signal victoria                                 # HU-11: Módulo de Comando al nivel máximo
signal evento_iniciado(evento: Dictionary)      # HU-08: hay que elegir una opción
signal glosario_pedido(id: String)              # HU-12: clic en un término resaltado

const VITALES := ["oxigeno", "agua", "comida"]
const CATEGORIAS := ["Acción", "Evento", "Tripulación"]

## Valores de balance y perfiles de colonos, editables desde el inspector.
var datos_balance: DatosBalance = load("res://datos/balance.tres")
var datos_candidatos: DatosCandidatos = load("res://datos/candidatos.tres")

var economia := SistemaEconomia.new()
var almacen := SistemaAlmacen.new()
var tripulacion := SistemaTripulacion.new()
var tareas := SistemaTareas.new()
var comando := SistemaComando.new()
var eventos := SistemaEventos.new()
var tierra := SistemaTierra.new()
var glosario := SistemaGlosario.new()

var rng := RandomNumberGenerator.new()          # azar de la partida
var terminado := false
var modulos_apagados := false                   # sin energía: la base a oscuras
var modulos_construidos := 0                    # por el jugador (resumen de victoria)
## HU-10: [{ "sol", "categoria", "texto" }], de la más antigua a la más reciente.
var bitacora: Array[Dictionary] = []


func _ready() -> void:
	GestorTiempo.sol_transcurrido.connect(terminar_sol)
	GestorTiempo.cambiado.connect(estado_cambiado.emit)
	nueva_partida()


func nueva_partida() -> void:
	rng.randomize()
	GestorTiempo.reiniciar()
	terminado = false
	modulos_apagados = false
	modulos_construidos = 0
	bitacora.clear()
	for sistema: RefCounted in [comando, economia, almacen, tripulacion, eventos, tierra, glosario]:
		sistema.reiniciar()


## Anota en la bitácora (categoría de CATEGORIAS) y, si `avisar`, lo muestra como aviso.
func registrar(categoria: String, texto: String, avisar := true) -> void:
	bitacora.append({ "sol": GestorTiempo.sol_actual, "categoria": categoria, "texto": texto })
	if avisar:
		aviso.emit(texto)


# --- Ciclo del sol --------------------------------------------------------

## Lo que pasa al terminar cada sol, en orden.
func terminar_sol(sol: int) -> void:
	if terminado:
		return
	var antes := economia.foto()

	economia.consumir()
	economia.producir()
	tareas.avanzar_misiones()
	almacen.contar_sol()
	tripulacion.actualizar_salud()
	tripulacion.renovar_candidatos()
	tierra.avanzar()
	eventos.avanzar_tormenta()
	var nivel_antes := comando.nivel
	comando.avanzar_mejora()

	economia.anotar_historial(sol, antes)
	_comprobar_derrota()
	if not terminado and comando.nivel > nivel_antes and comando.nivel == comando.nivel_max():
		registrar("Evento", "Misión cumplida: la colonia es autosuficiente", false)
		GestorTiempo.en_pausa = true
		victoria.emit()
	elif not terminado and eventos.toca_evento():
		evento_iniciado.emit(eventos.evento)
	sol_terminado.emit()
	estado_cambiado.emit()


func _comprobar_derrota() -> void:
	if economia.recursos["energia"] <= 0.0 and economia.balance("energia") < 0.0:
		modulos_apagados = true
		_terminar("La energía se agotó: la base ha quedado a oscuras.")
	elif tripulacion.soles_sin_vitales >= datos_balance.soles_sin_vitales_derrota:
		_terminar("%d soles sin soporte vital: la colonia se ha perdido." % tripulacion.soles_sin_vitales)


func _terminar(motivo: String) -> void:
	terminado = true
	registrar("Evento", motivo, false)
	GestorTiempo.detenido = true
	partida_terminada.emit(motivo)
