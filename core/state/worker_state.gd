class_name WorkerState
extends RefCounted

signal health_changed(current: float, maximum: float)

var definition: WorkerDefinition
var unit_id: String
var health: float
var level: int = 1
var experience: float = 0.0
var carried_resource: ResourceDefinition
var carried_amount: int = 0


func _init(worker_definition: WorkerDefinition, id: String) -> void:
	definition = worker_definition
	unit_id = id
	health = worker_definition.max_health


func damage(amount: float) -> void:
	if amount <= 0.0:
		return
	_apply_health(health - amount)


func heal(amount: float) -> void:
	if amount <= 0.0:
		return
	_apply_health(health + amount)


func set_cargo(resource_definition: ResourceDefinition, amount: int) -> void:
	if resource_definition == null or amount <= 0:
		return
	if carried_resource != null and carried_resource != resource_definition:
		return
	carried_resource = resource_definition
	carried_amount = mini(amount, definition.carry_capacity)


func clear_cargo() -> void:
	carried_resource = null
	carried_amount = 0


func has_cargo() -> bool:
	return carried_amount > 0


func _apply_health(value: float) -> void:
	var maximum := definition.max_health
	var next := clampf(value, 0.0, maximum)
	if is_equal_approx(next, health):
		return
	health = next
	health_changed.emit(health, maximum)
