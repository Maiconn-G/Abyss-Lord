class_name MilitaryDebugHud
extends PanelContainer

@onready var _barracks_hint: Label = %BarracksHintLabel
@onready var _barracks_status: Label = %BarracksStatusLabel
@onready var _recruit_hint: Label = %RecruitHintLabel
@onready var _recruit_status: Label = %RecruitStatusLabel

var _construction: ConstructionController
var _recruitment: SoldierRecruitmentController
var _stockpile: ResourceStockpileState
var _core_state: CoreState
var _definition: BarracksDefinition
var _soldier_definition: SoldierDefinition
var _soldier_recruited := false


func bind(
		construction: ConstructionController,
		recruitment: SoldierRecruitmentController,
		stockpile_state: ResourceStockpileState,
		core_state: CoreState,
		barracks_definition: BarracksDefinition) -> void:
	_construction = construction
	_recruitment = recruitment
	_stockpile = stockpile_state
	_core_state = core_state
	_definition = barracks_definition
	_soldier_definition = barracks_definition.soldier_definition
	_barracks_hint.text = "[K] Construir %s — %d %s" % [
		barracks_definition.display_name,
		barracks_definition.build_cost,
		barracks_definition.build_resource.display_name]
	construction.barracks_built.connect(_on_barracks_changed)
	construction.barracks_completed.connect(_on_barracks_changed)
	recruitment.soldier_recruited.connect(_on_soldier_recruited)
	stockpile_state.resource_changed.connect(_on_resource_changed)
	core_state.essence_changed.connect(_on_core_changed)
	core_state.population_changed.connect(_on_core_changed)
	core_state.population_capacity_changed.connect(_on_core_changed)
	refresh()


## §28/§77/T18: `soldier_recruited` e os dois sinais do Quartel são conquistas, e a carga
## não os reemitiu. A flag histórica do controller e a obra que ele carrega são o que o
## painel precisa — o Quartel pode voltar inacabado ou ausente, e o Soldado pode sumir.
func refresh() -> void:
	_soldier_recruited = _recruitment.ever_recruited()
	_show_status()


func _on_barracks_changed(_barracks) -> void:
	_show_status()


func _on_soldier_recruited(_soldier: SoldierRuntime) -> void:
	_soldier_recruited = true
	_show_status()


func _on_resource_changed(resource_definition: ResourceDefinition, _new_amount: int) -> void:
	if resource_definition == _definition.build_resource:
		_show_status()


func _on_core_changed(_value_a, _value_b) -> void:
	_show_status()


func _show_status() -> void:
	var barracks := _construction.barracks()
	var completed := barracks != null and barracks.is_completed()
	if barracks == null:
		if _available_ore() >= _definition.build_cost:
			_barracks_status.text = "%s: pronto para construir" % _definition.display_name
		else:
			_barracks_status.text = "%s: recursos insuficientes" % _definition.display_name
	elif completed:
		_barracks_status.text = "%s: concluído" % _definition.display_name
	else:
		_barracks_status.text = "%s: em construção" % _definition.display_name
	if completed:
		_recruit_hint.text = "[R] Recrutar %s — %d Essência" % [
			_soldier_definition.display_name,
			roundi(_soldier_definition.recruit_essence_cost)]
	else:
		_recruit_hint.text = "[R] Recrutar %s — %s necessário" % [
			_soldier_definition.display_name, _definition.display_name]
	_recruit_status.text = _recruitment_status_of(completed)


func _recruitment_status_of(completed: bool) -> String:
	if _soldier_recruited:
		return "%s: recrutado" % _soldier_definition.display_name
	if not completed:
		return "Recrutamento: bloqueado"
	elif not _core_state.can_add_population(1):
		return "Recrutamento: capacidade cheia"
	elif _core_state.essence < _soldier_definition.recruit_essence_cost:
		return "Recrutamento: essência insuficiente"
	return "Recrutamento: pronto"


func _available_ore() -> int:
	return _stockpile.get_amount(_definition.build_resource.resource_id)
