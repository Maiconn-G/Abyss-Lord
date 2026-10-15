class_name DisputeController
extends Node

## Tarefa 27 — a primeira disputa entre Povos Nativos: o Salão contra as Raízes.
##
## A Guarda Decapitada quer cavar fortificações na galeria onde os Elfos Cinzentos guardam as
## raízes do antigo domínio. Não há resposta certa (GDD §70): favorecer um povo custa
## Legitimidade com o outro, e a decisão é uma só.
##
## A disputa se abre quando os dois povos já foram encontrados e ainda não foi decidida. "Aberta"
## não é estado guardado: é a leitura de "os dois encontrados e nada decidido". O que vai para o
## Save é só a decisão.
##
## O que este controller NÃO é: sistema de eventos, de diplomacia ou fila de dilemas. É uma
## disputa entre dois povos, com os dois controllers de povo entregues por injeção.

enum Resolution { UNRESOLVED, FIRST, SECOND }

const RESOLUTION_NAMES: Array[String] = ["UNRESOLVED", "FIRST", "SECOND"]

signal dispute_opened
signal dispute_resolved(resolution: Resolution)

var _definition: DisputeDefinition
var _first: NativePeopleController
var _second: NativePeopleController
var _resolution: Resolution = Resolution.UNRESOLVED
var _announced := false


func setup(definition: DisputeDefinition, first: NativePeopleController,
		second: NativePeopleController) -> void:
	_definition = definition
	_first = first
	_second = second
	first.people_discovered.connect(_on_people_discovered)
	second.people_discovered.connect(_on_people_discovered)


func definition() -> DisputeDefinition:
	return _definition


func first_people() -> NativePeopleController:
	return _first


func second_people() -> NativePeopleController:
	return _second


func resolution() -> Resolution:
	return _resolution


func is_open() -> bool:
	return _resolution == Resolution.UNRESOLVED and _first.is_discovered() \
			and _second.is_discovered()


func _on_people_discovered() -> void:
	if is_open() and not _announced:
		_announced = true
		dispute_opened.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("dispute_favor_first"):
		resolve(Resolution.FIRST)
	elif event.is_action_pressed("dispute_favor_second"):
		resolve(Resolution.SECOND)


## Decidir é uma vez só. O favorecido ganha, o outro perde — e o ganho pode levar um povo ao
## juramento, pela regra viva do próprio controller dele.
func resolve(side: Resolution) -> bool:
	if not is_open() or side == Resolution.UNRESOLVED:
		return false
	_resolution = side
	var favored := _first if side == Resolution.FIRST else _second
	var slighted := _second if side == Resolution.FIRST else _first
	slighted.legitimacy().remove(_definition.legitimacy_swing)
	favored.legitimacy().add(_definition.legitimacy_swing)
	dispute_resolved.emit(side)
	return true


## A decisão volta como dado: nenhuma Legitimidade é movida de novo e nenhum sinal é
## reemitido. Uma disputa já aberta numa campanha carregada não é reanunciada.
func restore_dispute(saved: Resolution) -> bool:
	if saved < Resolution.UNRESOLVED or saved > Resolution.SECOND:
		return false
	_resolution = saved
	_announced = _first.is_discovered() and _second.is_discovered()
	return true
