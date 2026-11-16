# obstaculo.gd
# Roca o cráter que bloquea casillas; se puede demoler a cambio de materiales.

class_name Obstaculo
extends ElementoMapa
## Roca o cráter que bloquea casillas. Se puede demoler para obtener materiales.

var tam := Vector2i.ONE
var textura: Texture2D


func _init(origen_celda: Vector2i, tam_celdas_: Vector2i, textura_: Texture2D) -> void:
	tam = tam_celdas_
	textura = textura_
	_colocar_en(origen_celda)


func tam_celdas() -> Vector2i:
	return tam


func coste_demoler() -> int:
	return EstadoJuego.datos_balance.demoler_obstaculo_dinero


func materiales_al_demoler() -> int:
	return tam.x * tam.y * EstadoJuego.datos_balance.demoler_obstaculo_materiales


## Los cráteres usan las texturas crater*.png; el resto son rocas.
func es_crater() -> bool:
	return textura != null and textura.resource_path.get_file().begins_with("crater")


func nombre() -> String:
	return Idioma.t("Obstáculo natural")


func _draw() -> void:
	draw_texture(textura, Vector2.ZERO)
