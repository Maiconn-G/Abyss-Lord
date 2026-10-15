class_name RaiderState
extends EnemyState

## Tarefa 23 — o estado lógico de um Saqueador de Guilda. A vida é a do EnemyState; aqui
## mora o que o arquivo de campanha precisa para reconstruir um saque no meio do caminho:
## a fase da incursão e o que ele carrega.
##
## O saque é estado, não configuração: a capacidade vem da RaiderDefinition, mas "levando 2
## de Biomassa" é um fato desta unidade, e é ele que volta ao estoque se ela morrer.

enum Phase { APPROACH, LOOT, RETREAT }

signal loot_changed(total: int)

var phase: Phase = Phase.APPROACH
## resource_id → quantidade carregada.
var loot: Dictionary = {}


func raider_definition() -> RaiderDefinition:
	return definition as RaiderDefinition


func carried_total() -> int:
	var total := 0
	for resource_id in loot:
		total += int(loot[resource_id])
	return total


func has_room() -> bool:
	return carried_total() < raider_definition().loot_capacity


func carry(resource_id: StringName, amount: int) -> bool:
	if amount <= 0 or carried_total() + amount > raider_definition().loot_capacity:
		return false
	loot[resource_id] = int(loot.get(resource_id, 0)) + amount
	loot_changed.emit(carried_total())
	return true


## Entrega o saque inteiro a quem o pede (o estoque, se o saqueador morreu) e esvazia a
## carga. Devolve o que havia, para o chamador decidir o destino.
func drop_loot() -> Dictionary:
	var dropped := loot.duplicate()
	loot.clear()
	loot_changed.emit(0)
	return dropped


func should_retreat() -> bool:
	return health <= raider_definition().max_health * raider_definition().retreat_health_ratio


## Restaurar não é jogar: fase e saque voltam como o arquivo os escreveu. A faixa é a da
## própria Definition — saque acima da capacidade é campanha impossível.
func restore_raid(saved_phase: Phase, saved_loot: Dictionary) -> bool:
	if saved_phase < Phase.APPROACH or saved_phase > Phase.RETREAT:
		return false
	var total := 0
	for resource_id in saved_loot:
		var amount := int(saved_loot[resource_id])
		if amount <= 0:
			return false
		total += amount
	if total > raider_definition().loot_capacity:
		return false
	phase = saved_phase
	loot = {}
	for resource_id in saved_loot:
		loot[StringName(resource_id)] = int(saved_loot[resource_id])
	loot_changed.emit(carried_total())
	return true
