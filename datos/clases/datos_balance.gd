# datos_balance.gd
# Recurso con todos los valores de balance del juego (recursos iniciales, producción, consumo, radiación, costos, eventos y tareas).

class_name DatosBalance
extends Resource
## Valores de balance del juego (HU-01..07). Ajustables desde el inspector.

@export var recursos_hud: Array
@export var recursos_comando: Array
@export var segundos_por_sol: float
@export var soles_historial: int
@export var inicial: Dictionary
## Unidades: oxígeno y comida en kg, agua en L, energía guardada en kWh
## (producción y consumo de energía en kW), presupuesto en millones de USD.
## Tanques de oxígeno (kg).
@export var cap_tanques: float
## Baterías (kWh).
@export var cap_bateria: float
## Víveres del almacén: agua + comida + raciones (kg; 1 L de agua = 1 kg).
@export var cap_almacen_base: float
@export var cap_almacen_por_nivel: float
@export var cap_materiales_base: float
@export var cap_materiales_por_nivel: float
@export var nivel_almacen_max: int
@export var fraccion_critica: float
@export var presupuesto_critico: float
## Producción por sol de la base inicial (energía: kW; 100 kW = 2 reactores
## de fisión de 40 kW + 1 panel solar de 20 kW).
@export var produccion_base: Dictionary
## Consumo de cada colono por sol: { "oxigeno": kg, "agua": L, "comida": kg }.
@export var consumo_por_colono: Dictionary
## El soporte vital recicla esta fracción del agua que se consume cada sol.
@export var fraccion_reciclaje_agua: float
@export var factor_racion: Dictionary
@export var soles_estricta_para_riesgo: int
@export var prob_enfermar_estricta: float
@export var prob_enfermar_sin_vitales: float
@export var soles_sin_vitales_derrota: int
@export var productividad_abundante: float
@export var productividad_debil: float
@export var soles_recuperacion: int
@export var radiacion_enfermedad: float
@export var radiacion_max: float
@export var radiacion_intemperie_por_sol: float
@export var cuartos_base: int
@export var cuartos_max: int
@export var expandir_descanso_dinero: int
@export var expandir_descanso_materiales: int
@export var expandir_almacen_dinero: int
@export var expandir_almacen_materiales: int
@export var demoler_obstaculo_dinero: int
@export var demoler_obstaculo_materiales: int
@export var recetas: Array
@export var tareas: Array
@export var fraccion_coste_demoler: float
@export var catalogo: Array
## Multiplicador de producción por nivel del Módulo de Comando (su tamaño es el nivel máximo).
@export var multiplicador_comando: Array
## Coste de cada mejora del Módulo de Comando: [{ "dinero", "materiales", "soles" }], una por nivel.
@export var mejoras_comando: Array
## HU-08: eventos aleatorios cada soles_evento_min..max soles. Cada evento:
## { "id", "titulo", "descripcion", "opciones": [2 x { "texto", "recursos"?: {recurso: +/-n},
##   "radiacion"?: dosis a cada colono, "enfermar"?: probabilidad, "tormenta"?: soles, "blindaje"?: factor } ] }
@export var soles_evento_min: int
@export var soles_evento_max: int
@export var eventos: Array
## Radiación por sol durante una tormenta solar (en el refugio blindado: 0).
@export var radiacion_tormenta_exterior: float
@export var radiacion_tormenta_interior: float
@export var capacidad_refugio: int
## HU-09: latencias con la Tierra (en soles).
@export var soles_viaje_colono: int
@export var latencia_fondos: int
@export var transferencia_cada: int
@export var transferencia_dinero: int
@export var transferencia_soles: int
## Pedidos de suministros: [{ "nombre", "contenido": {recurso: n}, "dinero", "soles" }]
@export var pedidos: Array
