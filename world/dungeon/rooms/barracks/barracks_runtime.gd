class_name BarracksRuntime
extends StaticBody3D

@export var definition: BarracksDefinition

var state: BarracksState

@onready var _construction_visual: Node3D = $ConstructionVisual
@onready var _completed_visual: Node3D = $CompletedVisual


func setup(barracks_definition: BarracksDefinition, barracks_state: BarracksState) -> void:
	definition = barracks_definition
	state = barracks_state
	_show_progress()
	state.construction_completed.connect(_show_progress)


func is_completed() -> bool:
	return state != null and state.is_completed()


func _show_progress() -> void:
	var completed := is_completed()
	_construction_visual.visible = not completed
	_completed_visual.visible = completed
