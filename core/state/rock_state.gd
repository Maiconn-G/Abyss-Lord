class_name RockState
extends RefCounted

signal work_changed(remaining: float, total: float)
signal excavated

var definition: RockDefinition
var rock_id: String
var remaining_work: float


func _init(rock_definition: RockDefinition, id: String) -> void:
	definition = rock_definition
	rock_id = id
	remaining_work = rock_definition.work_required


func apply_work(amount: float) -> void:
	if amount <= 0.0 or is_excavated():
		return
	remaining_work = maxf(remaining_work - amount, 0.0)
	work_changed.emit(remaining_work, definition.work_required)
	if remaining_work <= 0.0:
		excavated.emit()


func is_excavated() -> bool:
	return remaining_work <= 0.0
