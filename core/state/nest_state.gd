class_name NestState
extends RefCounted

signal work_changed(remaining: float, total: float)
signal construction_completed

var definition: NestDefinition
var nest_id: String
var remaining_work: float


func _init(nest_definition: NestDefinition, id: String) -> void:
	definition = nest_definition
	nest_id = id
	remaining_work = nest_definition.work_required


func apply_work(amount: float) -> void:
	if amount <= 0.0 or is_completed():
		return
	remaining_work = maxf(remaining_work - amount, 0.0)
	work_changed.emit(remaining_work, definition.work_required)
	if remaining_work <= 0.0:
		construction_completed.emit()


func is_completed() -> bool:
	return remaining_work <= 0.0
