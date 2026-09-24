class_name SoldierState
extends RefCounted

signal health_changed(current: float, maximum: float)

var definition: SoldierDefinition
var unit_id: String
var health: float
var level: int = 1
var experience: float = 0.0


func _init(soldier_definition: SoldierDefinition, id: String) -> void:
	definition = soldier_definition
	unit_id = id
	health = soldier_definition.max_health


func damage(amount: float) -> void:
	if amount <= 0.0:
		return
	_apply_health(health - amount)


func heal(amount: float) -> void:
	if amount <= 0.0:
		return
	_apply_health(health + amount)


func _apply_health(value: float) -> void:
	var maximum := definition.max_health
	var next := clampf(value, 0.0, maximum)
	if is_equal_approx(next, health):
		return
	health = next
	health_changed.emit(health, maximum)
