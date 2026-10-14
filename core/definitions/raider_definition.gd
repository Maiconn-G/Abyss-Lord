class_name RaiderDefinition
extends EnemyDefinition

## Tarefa 23 — o Saqueador de Guilda, o primeiro invasor da superfície (GDD §58.1).
##
## O corpo de combate (vida, velocidade, dano, alcance e intervalo) é herdado de
## EnemyDefinition, e é por isso que o Soldado o enfrenta sem saber que é outro tipo de
## inimigo. O que vive aqui é o que faz dele um saqueador e não uma fera: quanto carrega,
## em que ritmo rouba, a ordem de preferência do saque e o ponto de vida em que desiste.

## Unidades de recurso que um saqueador consegue carregar.
@export var loot_capacity: int = 3
## Segundos entre duas unidades roubadas no Depósito.
@export var steal_interval: float = 1.0
## Fração da vida máxima abaixo da qual o saqueador recua, com ou sem saque.
@export_range(0.0, 1.0) var retreat_health_ratio: float = 0.35
## Ordem de preferência do saque. O primeiro recurso com saldo é o próximo a ser levado.
@export var loot_priority: Array[ResourceDefinition] = []
## Distância do Depósito em que o saque começa.
@export var loot_range: float = 1.6
