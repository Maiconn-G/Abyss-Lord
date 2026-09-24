class_name ResourceStockpileState
extends RefCounted

signal resource_changed(resource_definition: ResourceDefinition, new_amount: int)

var _amounts: Dictionary[StringName, int] = {}


func get_amount(resource_id: StringName) -> int:
	return _amounts.get(resource_id, 0)


func add_resource(resource_definition: ResourceDefinition, amount: int) -> void:
	if resource_definition == null or amount <= 0:
		return
	var next_amount := get_amount(resource_definition.resource_id) + amount
	_amounts[resource_definition.resource_id] = next_amount
	resource_changed.emit(resource_definition, next_amount)


func consume_resource(resource_definition: ResourceDefinition, amount: int) -> bool:
	if resource_definition == null or amount <= 0:
		return false
	var resource_id := resource_definition.resource_id
	var available := get_amount(resource_id)
	if available < amount:
		return false
	var next_amount := available - amount
	_amounts[resource_id] = next_amount
	resource_changed.emit(resource_definition, next_amount)
	return true
