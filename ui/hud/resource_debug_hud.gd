class_name ResourceDebugHud
extends PanelContainer

@onready var _ore_label: Label = %OreLabel

var _stockpile: ResourceStockpileState
var _tracked_resource: ResourceDefinition


func bind_stockpile(
		state: ResourceStockpileState, resource_definition: ResourceDefinition) -> void:
	_stockpile = state
	_tracked_resource = resource_definition
	_ore_label.text = _format(resource_definition.display_name,
			state.get_amount(resource_definition.resource_id))
	state.resource_changed.connect(_on_resource_changed)


func _on_resource_changed(resource_definition: ResourceDefinition, new_amount: int) -> void:
	if resource_definition != _tracked_resource:
		return
	_ore_label.text = _format(resource_definition.display_name, new_amount)


func _format(display_name: String, amount: int) -> String:
	return "%s: %d" % [display_name, amount]
