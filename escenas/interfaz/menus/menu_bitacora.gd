# menu_bitacora.gd
# Menú de la bitácora: registro de la misión del más reciente al más antiguo, con filtro por categoría.

class_name MenuBitacora
extends MenuModulo
## HU-10: registro cronológico de la misión, de lo más reciente a lo más
## antiguo, con filtro por categoría (acciones, eventos y tripulación).

const COLOR_CATEGORIA := {
	Enums.Categoria.ACCION: UI.ACENTO,
	Enums.Categoria.EVENTO: UI.ADVERTENCIA,
	Enums.Categoria.TRIPULACION: UI.BIEN,
}
const TODAS := -1                     # filtro que muestra todas las categorías

var filtro := TODAS


func construir() -> void:
	var filtros := UI.fila(6)
	for categoria: int in [TODAS] + Enums.Categoria.values():
		var texto: String = "Todas" if categoria == TODAS else Enums.NOMBRE_CATEGORIA[categoria]
		var b := UI.boton(texto, func() -> void:
			filtro = categoria
			_pedir_reconstruccion(), true, UI.PRIMARIO if filtro == categoria else "")
		filtros.add_child(b)
	contenido.add_child(filtros)

	var lista := UI.columna(4)
	for i in range(EstadoJuego.bitacora.size() - 1, -1, -1):
		var entrada: Dictionary = EstadoJuego.bitacora[i]
		if filtro != TODAS and entrada["categoria"] != filtro:
			continue
		var f := UI.fila(12)
		var sol := UI.etiqueta("Sol %d" % entrada["sol"], 13, UI.TEXTO_SUAVE)
		sol.custom_minimum_size = Vector2(60, 0)
		f.add_child(sol)
		var categoria := UI.etiqueta(Enums.NOMBRE_CATEGORIA[entrada["categoria"]], 13, COLOR_CATEGORIA[entrada["categoria"]])
		categoria.custom_minimum_size = Vector2(100, 0)
		f.add_child(categoria)
		f.add_child(UI.expandir(UI.parrafo(entrada["texto"], 13, UI.TEXTO)))
		lista.add_child(f)
	if lista.get_child_count() == 0:
		lista.add_child(UI.parrafo("Todavía no hay registros."))
	contenido.add_child(vista_con_scroll(lista))
