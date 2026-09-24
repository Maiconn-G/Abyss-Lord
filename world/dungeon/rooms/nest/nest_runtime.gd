class_name NestRuntime
extends StaticBody3D

@export var definition: NestDefinition

var state: NestState

@onready var _construction_visual: Node3D = $ConstructionVisual
@onready var _completed_visual: Node3D = $CompletedVisual


func setup(nest_definition: NestDefinition, nest_state: NestState) -> void:
	definition = nest_definition
	state = nest_state
	_show_progress()
	state.construction_completed.connect(_show_progress)


func is_completed() -> bool:
	return state != null and state.is_completed()


func _show_progress() -> void:
	var completed := is_completed()
	_construction_visual.visible = not completed
	_completed_visual.visible = completed
