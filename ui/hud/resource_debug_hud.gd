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


## §78/T18: `resource_changed` só fala de saldo que existe. Um load que esvazia o estoque
## não emite nada para o recurso que zerou — sem esta leitura a linha continuaria com o
## número da partida anterior.
func refresh() -> void:
	if _stockpile == null or _tracked_resource == null:
		return
	_ore_label.text = _format(_tracked_resource.display_name,
			_stockpile.get_amount(_tracked_resource.resource_id))


func _format(display_name: String, amount: int) -> String:
	return "%s: %d" % [display_name, amount]
