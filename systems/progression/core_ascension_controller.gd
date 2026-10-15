class_name CoreAscensionController
extends Node

## Tarefa 26 — a Ascensão: Núcleo Nv.2 → Nv.3 ("Masmorra", GDD §8). O CoreEvolutionController
## continua sendo o degrau histórico do MVP (vitória da primeira invasão, Cristal, Essência) e
## não foi tocado; este controller é o degrau seguinte, com outra porta e outro preço.
##
## A conta tem três metades, todas lidas da Definition de destino:
## * o **Cristal Abissal** prova a conquista — o segundo vem da primeira guilda da superfície
##   repelida sem nenhuma fuga (SurfaceIncursionController);
## * a **Essência** paga a energia;
## * a **Biomassa** sustenta o corpo maior do Núcleo.
##
## Mesma tecla do MVP (V). O Godot entrega `_unhandled_input` do último nó para o primeiro, e
## este controller vem depois do CoreEvolutionController em Systems: ele lê a tecla antes e só
## age no Nv.2. No Nv.1 ele recusa e o MVP evolui; no Nv.2 ele ascende e o MVP já não tem para
## onde ir. A mesma tecla nunca sobe dois níveis.

enum Gate { READY, NOT_AT_SOURCE, ALREADY_ASCENDED, CRYSTAL, ESSENCE, BIOMASS }

signal ascension_completed(new_level: int)

var _core: CoreRuntime
var _state: CoreState
var _target: CoreDefinition
var _crystal: AbyssalCrystalState
var _stockpile: ResourceStockpileState
var _biomass: ResourceDefinition


## Tudo por injeção na raiz de composição.
func setup(
		core: CoreRuntime,
		state: CoreState,
		target_definition: CoreDefinition,
		crystal: AbyssalCrystalState,
		stockpile: ResourceStockpileState,
		biomass: ResourceDefinition) -> void:
	_core = core
	_state = state
	_target = target_definition
	_crystal = crystal
	_stockpile = stockpile
	_biomass = biomass


func target_definition() -> CoreDefinition:
	return _target


## O recurso de Biomassa que a Ascensão cobra — o painel lê o nome dele daqui.
func biomass_resource() -> ResourceDefinition:
	return _biomass


func source_level() -> int:
	return _target.level - 1


## A primeira porta fechada, na ordem de conferência. O painel lê esta mesma resposta.
func gate() -> Gate:
	if _state.level >= _target.level:
		return Gate.ALREADY_ASCENDED
	if _state.level != source_level():
		return Gate.NOT_AT_SOURCE
	if _target.evolution_crystal_cost > 0 \
			and (_crystal == null or not _crystal.has(_target.evolution_crystal_cost)):
		return Gate.CRYSTAL
	if _state.essence < _target.evolution_essence_cost:
		return Gate.ESSENCE
	if _target.evolution_biomass_cost > 0 \
			and _stockpile.get_amount(_biomass.resource_id) < _target.evolution_biomass_cost:
		return Gate.BIOMASS
	return Gate.READY


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("evolve_core"):
		try_ascend()


## A transação inteira é validada por `gate()` antes de qualquer consumo. Se ainda assim o
## Núcleo recusar a transição, as três metades voltam juntas.
func try_ascend() -> bool:
	if gate() != Gate.READY:
		return false
	var essence_cost := _target.evolution_essence_cost
	var crystal_cost := _target.evolution_crystal_cost
	var biomass_cost := _target.evolution_biomass_cost
	_state.consume_essence(essence_cost)
	if crystal_cost > 0:
		_crystal.consume(crystal_cost)
	if biomass_cost > 0:
		_stockpile.consume_resource(_biomass, biomass_cost)
	if not _core.evolve_to(_target):
		_state.add_essence(essence_cost)
		if crystal_cost > 0:
			_crystal.add(crystal_cost)
		if biomass_cost > 0:
			_stockpile.add_resource(_biomass, biomass_cost)
		return false
	ascension_completed.emit(_state.level)
	return true
