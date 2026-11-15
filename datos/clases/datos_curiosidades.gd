# datos_curiosidades.gd
# Recurso con los datos curiosos de STEM: texto para niños, cuándo aparecen y su fuente.

class_name DatosCuriosidades
extends Resource
## Cada dato: { "id", "disparador", "titulo", "texto", "fuente", "enlace" }.
## `disparador` dice cuándo aparece (una sola vez por partida):
##   "sol:N"          al empezar el sol N
##   "construir:<id>" la primera vez que se construye ese módulo
##   "evento:<id>"    la primera vez que llega ese incidente (datos/balance.tres)
##   "real:<TIPO>"    el primer evento real de DONKI de ese tipo (FLR, CME, SEP, GST)
##   "tormenta"       la primera tormenta solar
##   "nave:colonos"   la primera nave con colonos nuevos
##   "colono:enfermo" la primera vez que alguien enferma
##   "tarea:<id>"     la primera vez que se asigna esa tarea (datos/balance.tres)
##   "pedido:enviado" el primer pedido de suministros a la Tierra
## Si dos datos comparten disparador, el segundo sale la segunda vez que pasa.
## Todos los números salen de la fuente indicada (o de una cuenta con ellos).

@export var curiosidades: Array
