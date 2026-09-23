class_name ResourcePileState
extends RefCounted

signal amount_changed(current_amount: int)
signal depleted

var definition: ResourceDefinition
var pile_id: String
var amount: int


func _init(resource_definition: ResourceDefinition, id: String, initial_amount: int) -> void:
	definition = resource_definition
	pile_id = id
	amount = maxi(initial_amount, 0)


func take(requested_amount: int) -> int:
	if requested_amount <= 0 or amount <= 0:
		return 0
	var taken: int = mini(requested_amount, amount)
	amount -= taken
	amount_changed.emit(amount)
	if amount == 0:
		depleted.emit()
	return taken


func is_depleted() -> bool:
	return amount <= 0
