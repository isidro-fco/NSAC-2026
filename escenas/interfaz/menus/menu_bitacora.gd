# menu_bitacora.gd
# Menú de la bitácora: registro de la misión del más reciente al más antiguo, con filtro por categoría.

class_name MenuBitacora
extends MenuModulo
## HU-10: registro cronológico de la misión, de lo más reciente a lo más
## antiguo, con filtro por categoría (acciones, eventos y tripulación).
## Estilo de cabina del Módulo de Comando (ver Cabina):
##   [TODAS 12] [ACCION 5] [EVENTO 4] [TRIPULACION 3]
##   REGISTRO [12]                                    SOL 1 - SOL 7
##   ╔══════════════════════════════════════════════════════════════╗
##   ║ ──────────────────────── SOL 7 ─────────────────────────────  ║
##   ║ ┃ [ACCION]  Tarea asignada: Limpiar paneles solares a Elena   ║
##   ╚══════════════════════════════════════════════════════════════╝

const COLOR_CATEGORIA := {
	Enums.Categoria.ACCION: UI.ACENTO,
	Enums.Categoria.EVENTO: UI.ADVERTENCIA,
	Enums.Categoria.TRIPULACION: UI.BIEN,
}
const TODAS := -1                     # filtro que muestra todas las categorías

var filtro := TODAS


func _init() -> void:
	con_cabecera = false     # sin título: como la sala de comandos


func construir() -> void:
	var bitacora: Array = EstadoJuego.bitacora
	var cuentas := { TODAS: bitacora.size() }
	for categoria: int in Enums.Categoria.values():
		cuentas[categoria] = 0
	for entrada: Dictionary in bitacora:
		cuentas[entrada["categoria"]] += 1

	var filtros := UI.fila(6)
	for categoria: int in [TODAS] + Enums.Categoria.values():
		var texto: String = "Todas" if categoria == TODAS else Enums.NOMBRE_CATEGORIA[categoria]
		var b := Cabina.boton_opcion("%s  %d" % [texto, cuentas[categoria]], func() -> void:
			filtro = categoria
			_pedir_reconstruccion(), filtro == categoria)
		if categoria != TODAS and filtro != categoria:
			b.add_theme_color_override("font_color", COLOR_CATEGORIA[categoria])
		filtros.add_child(UI.expandir(b))
	contenido.add_child(filtros)

	var entradas := bitacora.filter(func(e: Dictionary) -> bool: return filtro == TODAS or e["categoria"] == filtro)
	var rango := ""
	if not entradas.is_empty():
		rango = "Sol %d - Sol %d" % [entradas[0]["sol"], entradas[-1]["sol"]]
	contenido.add_child(Cabina.encabezado("Registro", entradas.size(), rango))
	var pantalla := Cabina.pantalla()
	contenido.add_child(pantalla)
	var lista := UI.columna(4)
	var sol_actual := -1
	for i in range(entradas.size() - 1, -1, -1):
		var entrada: Dictionary = entradas[i]
		if entrada["sol"] != sol_actual:
			sol_actual = entrada["sol"]
			lista.add_child(Cabina.separador("Sol %d" % sol_actual))
		lista.add_child(_fila(entrada))
	if entradas.is_empty():
		lista.add_child(Cabina.vacio("Todavía no hay registros."))
	pantalla.add_child(vista_con_scroll(Cabina.con_margen_scroll(lista)))


## Entrada: franja y etiqueta del color de su categoría, y el texto.
func _fila(entrada: Dictionary) -> Control:
	var color: Color = COLOR_CATEGORIA[entrada["categoria"]]
	var tarjeta := Cabina.tarjeta(color, 5)
	var f := UI.fila(10)
	tarjeta.add_child(f)
	var etiqueta := Cabina.pildora(Cabina.mayus(Enums.NOMBRE_CATEGORIA[entrada["categoria"]]), color, false)
	etiqueta.custom_minimum_size = Vector2(96, 0)
	(etiqueta.get_child(0) as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	f.add_child(etiqueta)
	f.add_child(UI.expandir(UI.parrafo(entrada["texto"], 13, UI.TEXTO)))
	return tarjeta
