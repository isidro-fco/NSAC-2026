# sistema_almacen.gd
# Sistema del almacén: capacidad del depósito, racionamiento, productividad y recetas de cocina.

class_name SistemaAlmacen
extends Sistema
## Almacén y cocina (HU-04): capacidad del depósito, racionamiento y recetas.
## Se usa a través de EstadoJuego.almacen.

var nivel := 1
var racion: Enums.Racion = Enums.Racion.NORMAL
var soles_estricta := 0               # soles seguidos con ración estricta


func reiniciar() -> void:
	nivel = 1
	racion = Enums.Racion.NORMAL
	soles_estricta = 0


## Víveres: agua + comida + raciones, en kg (1 L de agua pesa 1 kg).
func capacidad() -> float:
	return datos.cap_almacen_base + (nivel - 1) * datos.cap_almacen_por_nivel


func capacidad_materiales() -> float:
	return datos.cap_materiales_base + (nivel - 1) * datos.cap_materiales_por_nivel


# --- Racionamiento --------------------------------------------------------

func factor_racion() -> float:
	return datos.factor_racion[racion]


func fijar_racion(nueva: Enums.Racion) -> void:
	racion = nueva
	EstadoJuego.estado_cambiado.emit()


## Se llama una vez por sol para contar cuánto dura la ración estricta.
func contar_sol() -> void:
	soles_estricta = soles_estricta + 1 if racion == Enums.Racion.ESTRICTA else 0


## true si la ración estricta ya dura tanto que debilita a la tripulación.
func racion_debilita() -> bool:
	return racion == Enums.Racion.ESTRICTA and soles_estricta >= datos.soles_estricta_para_riesgo


## Multiplicador de las recompensas de las tareas según la ración.
func productividad() -> float:
	if racion == Enums.Racion.ABUNDANTE:
		return datos.productividad_abundante
	if racion_debilita():
		return datos.productividad_debil
	return 1.0


# --- Cocina ---------------------------------------------------------------

## Texto del recurso que impide cocinar la receta, o "" si se puede.
func falta_para_receta(receta: Dictionary) -> String:
	var recursos: Dictionary = EstadoJuego.economia.recursos
	if recursos["comida"] < receta["comida"]:
		return Idioma.t("Falta comida")
	if recursos["agua"] < receta["agua"]:
		return Idioma.t("Falta agua")
	var neto: float = receta["raciones"] - receta["comida"] - receta["agua"]
	if EstadoJuego.economia.viveres() + neto > capacidad():
		return Idioma.t("Falta espacio en el almacén")
	return ""


func cocinar(receta: Dictionary) -> bool:
	if falta_para_receta(receta) != "":
		return false
	var economia := EstadoJuego.economia
	economia.restar("comida", receta["comida"])
	economia.restar("agua", receta["agua"])
	economia.recursos["raciones"] += receta["raciones"]
	EstadoJuego.estado_cambiado.emit()
	return true


# --- Expansión ------------------------------------------------------------

func puede_expandir() -> bool:
	return nivel < datos.nivel_almacen_max \
		and EstadoJuego.economia.puede_pagar(datos.expandir_almacen_dinero, datos.expandir_almacen_materiales)


func expandir() -> bool:
	if not puede_expandir():
		return false
	nivel += 1
	EstadoJuego.economia.pagar(datos.expandir_almacen_dinero, datos.expandir_almacen_materiales)
	EstadoJuego.registrar(Enums.Categoria.ACCION, Idioma.t("Almacén ampliado al nivel %d") % nivel, false)
	return true
