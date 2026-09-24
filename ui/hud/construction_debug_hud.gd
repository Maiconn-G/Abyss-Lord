class_name ConstructionDebugHud
extends PanelContainer

@onready var _hint_label: Label = %HintLabel
@onready var _status_label: Label = %StatusLabel

var _definition: NestDefinition
var _nest_exists := false


func bind(
		controller: ConstructionController,
		stockpile: ResourceStockpileState,
		definition: NestDefinition) -> void:
	_definition = definition
	_hint_label.text = "[B] Construir %s — %d %s" % [
		definition.display_name, definition.build_cost, definition.build_resource.display_name]
	controller.nest_built.connect(_on_nest_built)
	controller.nest_completed.connect(_on_nest_completed)
	stockpile.resource_changed.connect(_on_resource_changed)
	_show_availability(stockpile.get_amount(definition.build_resource.resource_id))


func _on_resource_changed(
		resource_definition: ResourceDefinition, new_amount: int) -> void:
	if _nest_exists or resource_definition != _definition.build_resource:
		return
	_show_availability(new_amount)


func _show_availability(amount: int) -> void:
	if amount >= _definition.build_cost:
		_status_label.text = "%s: pronto para construir" % _definition.display_name
	else:
		_status_label.text = "%s: recursos insuficientes" % _definition.display_name


func _on_nest_built(_nest: NestRuntime) -> void:
	_nest_exists = true
	_status_label.text = "%s: em construção" % _definition.display_name


func _on_nest_completed(_nest: NestRuntime) -> void:
	_status_label.text = "%s: concluído" % _definition.display_name
