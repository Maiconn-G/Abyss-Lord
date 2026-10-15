class_name NotorietyState
extends RefCounted

## Tarefa 23 — a Notoriedade é a faceta da Ameaça voltada para a superfície (GDD §58.1).
## Ela mede o quanto as guildas humanas sabem que este Núcleo voltou a pulsar.
##
## Não é moeda: não se gasta e não mora no estoque. Ela sobe por fatos da campanha
## (evolução do Núcleo, saqueadores mortos, saqueadores que escapam) e é o gatilho das
## Incursões da Superfície. O dono dos números de cada fato é quem o provoca — este State
## só guarda o valor e diz em que faixa ele está.

signal notoriety_changed(current: int, maximum: int)

const MAXIMUM := 100

## As cinco faixas do GDD §13, aplicadas à superfície.
enum Band { UNKNOWN, OBSERVED, RELEVANT, REGIONAL_THREAT, SURFACE_TARGET }

var value: int = 0


func add(amount: int) -> void:
	if amount <= 0:
		return
	var next := mini(value + amount, MAXIMUM)
	if next == value:
		return
	value = next
	notoriety_changed.emit(value, MAXIMUM)


func band() -> Band:
	if value <= 20:
		return Band.UNKNOWN
	if value <= 40:
		return Band.OBSERVED
	if value <= 60:
		return Band.RELEVANT
	if value <= 80:
		return Band.REGIONAL_THREAT
	return Band.SURFACE_TARGET


## Restaurar não é jogar: o valor volta como o arquivo o escreveu, com um único sinal de
## valor. Fora da faixa, nada é tocado.
func restore(saved_value: int) -> bool:
	if saved_value < 0 or saved_value > MAXIMUM:
		return false
	value = saved_value
	notoriety_changed.emit(value, MAXIMUM)
	return true
