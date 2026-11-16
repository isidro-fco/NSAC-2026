# menu_bitacora.gd
# Menú de la bitácora: registro de la misión del más reciente al más antiguo, con filtro por categoría.

class_name MenuBitacora
extends MenuModulo
## HU-10: registro cronológico de la misión, de lo más reciente a lo más
## antiguo, con filtro por categoría (acciones, eventos, tripulación y curiosidades).
## La página "Curiosidad" guarda los datos "¿Sabías que...?" que ya salieron,
## con su título y su fuente; al hacer clic en una tarjeta del HUD se abre ahí
## con ese dato marcado (mostrar_curiosidad).
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
	Enums.Categoria.CURIOSIDAD: Color("#B48CFF"),
}
const TODAS := -1                     # filtro que muestra todas las categorías

var filtro := TODAS
var resaltada := ""                   # id de la curiosidad marcada
var _desplazar_a_resaltada := false   # bajar la lista hasta ella (solo una vez)


## Abre la página de curiosidades con el dato `id` marcado y a la vista.
func mostrar_curiosidad(id: String) -> void:
	filtro = Enums.Categoria.CURIOSIDAD
	resaltada = id
	_desplazar_a_resaltada = true
	_pedir_reconstruccion()


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
		var texto: String = Idioma.t("Todas") if categoria == TODAS else Idioma.t(Enums.NOMBRE_CATEGORIA[categoria])
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
	contenido.add_child(Cabina.encabezado(Idioma.t("Registro"), entradas.size(), rango))
	var pantalla := Cabina.pantalla()
	contenido.add_child(pantalla)
	var lista := UI.columna(4)
	var sol_actual := -1
	var marcada: Control = null
	for i in range(entradas.size() - 1, -1, -1):
		var entrada: Dictionary = entradas[i]
		if entrada["sol"] != sol_actual:
			sol_actual = entrada["sol"]
			lista.add_child(Cabina.separador("Sol %d" % sol_actual))
		var fila := _fila(entrada)
		lista.add_child(fila)
		if resaltada != "" and str(entrada.get("dato", {}).get("id", "")) == resaltada:
			marcada = fila
	if entradas.is_empty():
		var vacio := Idioma.t("Todavía no hay datos curiosos: aparecen al jugar.") if filtro == Enums.Categoria.CURIOSIDAD \
			else Idioma.t("Todavía no hay registros.")
		lista.add_child(Cabina.vacio(vacio))
	var scroll := vista_con_scroll(Cabina.con_margen_scroll(lista))
	pantalla.add_child(scroll)
	if marcada != null and _desplazar_a_resaltada:
		_desplazar_a_resaltada = false
		_desplazar.call_deferred(scroll, marcada)


## Baja la lista hasta la fila marcada, después de que se acomode (y de que
## _reconstruir devuelva la barra a donde estaba).
func _desplazar(scroll: ScrollContainer, fila: Control) -> void:
	for i in 3:
		await get_tree().process_frame
	if is_instance_valid(scroll) and is_instance_valid(fila):
		scroll.ensure_control_visible(fila)


## Entrada: etiqueta del color de su categoría y el texto.
func _fila(entrada: Dictionary) -> Control:
	if entrada.has("dato"):
		return _fila_curiosidad(entrada)
	var color: Color = COLOR_CATEGORIA[entrada["categoria"]]
	var tarjeta := Cabina.tarjeta(color, 5)
	var f := UI.fila(10)
	tarjeta.add_child(f)
	var etiqueta := Cabina.pildora(Cabina.mayus(Idioma.t(Enums.NOMBRE_CATEGORIA[entrada["categoria"]])), color, false)
	etiqueta.custom_minimum_size = Vector2(96, 0)
	(etiqueta.get_child(0) as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	f.add_child(etiqueta)
	f.add_child(UI.expandir(UI.parrafo(entrada["texto"], 13, UI.TEXTO)))
	return tarjeta


## Dato curioso: título, texto (con las palabras del glosario) y fuente.
## La que se abrió desde el HUD lleva un borde de su color.
func _fila_curiosidad(entrada: Dictionary) -> Control:
	var dato: Dictionary = entrada["dato"]
	var color: Color = COLOR_CATEGORIA[Enums.Categoria.CURIOSIDAD]
	var tarjeta := Cabina.tarjeta(color, 8)
	var caja := (tarjeta.get_theme_stylebox("panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
	caja.content_margin_bottom = 12        # aire bajo la línea de la fuente
	if str(dato.get("id", "")) == resaltada:
		caja.border_color = color
		caja.set_border_width_all(2)
	tarjeta.add_theme_stylebox_override("panel", caja)
	var f := UI.fila(10)
	tarjeta.add_child(f)
	var etiqueta := Cabina.pildora(Cabina.mayus(Idioma.t(Enums.NOMBRE_CATEGORIA[Enums.Categoria.CURIOSIDAD])), color, false)
	etiqueta.custom_minimum_size = Vector2(96, 0)
	etiqueta.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	(etiqueta.get_child(0) as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	f.add_child(etiqueta)
	var c := UI.columna(4)
	c.add_child(UI.etiqueta_simple(Idioma.t(str(dato["titulo"])), 14, UI.ADVERTENCIA))
	var traducido := Idioma.t(str(dato["texto"]))
	var bbcode := EstadoJuego.glosario.resaltar(traducido)
	var texto := UI.texto_glosario(bbcode if bbcode != "" else traducido.replace("[", "[lb]"), 13, UI.TEXTO)
	texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.add_child(texto)
	var fuente := UI.enlace_fuente(str(dato["fuente"]), str(dato.get("enlace", "")), 12)
	fuente.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.add_child(fuente)
	f.add_child(UI.expandir(c))
	return tarjeta
