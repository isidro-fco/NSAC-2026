class_name IndicadorRecurso
extends VBoxContainer
## Medidor del HUD (HU-07): nombre, reserva/capacidad y balance por sol.
## Se pinta en amarillo si el balance es negativo y en rojo si es crítico.

const ESCENA := "res://escenas/interfaz/componentes/indicador_recurso.tscn"

var recurso := ""
var nombre_label: Label
var valor_label: Label
var saldo_label: Label



static func crear(id_recurso: String) -> IndicadorRecurso:
	var indicador: IndicadorRecurso = load(ESCENA).instantiate()
	indicador.configurar(id_recurso)
	return indicador


func configurar(id_recurso: String) -> void:
	recurso = id_recurso
	add_theme_constant_override("separation", 0)
	custom_minimum_size = Vector2(122, 0)
	nombre_label = Hud.etiqueta(Enums.NOMBRE_RECURSO[recurso], 12, Hud.TEXTO_SUAVE)
	valor_label = Hud.etiqueta("", 15)
	saldo_label = Hud.etiqueta("", 11, Hud.TEXTO_SUAVE)
	var fila_valor := Hud.fila(6)
	fila_valor.add_child(valor_label)
	fila_valor.add_child(saldo_label)
	add_child(nombre_label)
	add_child(fila_valor)
	actualizar()


func actualizar() -> void:
	var cap := EstadoJuego.capacidad(recurso)
	var saldo := EstadoJuego.balance(recurso)
	var texto := Hud.num(EstadoJuego.valor(recurso))
	if not is_inf(cap):
		texto += "/%d" % int(cap)
	valor_label.text = texto
	saldo_label.text = "%s/sol" % Hud.con_signo(saldo)

	var color := Hud.TEXTO
	var marca := ""
	if EstadoJuego.es_critico(recurso):
		color = Hud.CRITICO
		marca = " (!)"
	elif saldo < 0.0:
		color = Hud.ADVERTENCIA
		marca = " (!)"
	nombre_label.text = Enums.NOMBRE_RECURSO[recurso] + marca
	valor_label.add_theme_color_override("font_color", color)
	saldo_label.add_theme_color_override("font_color", color if color != Hud.TEXTO else Hud.TEXTO_SUAVE)
