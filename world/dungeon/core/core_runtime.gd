class_name CoreRuntime
extends Node3D

var _definition: CoreDefinition
var _state: CoreState


func _ready() -> void:
	set_process(false)


func setup(definition: CoreDefinition, state: CoreState) -> void:
	_definition = definition
	_state = state
	set_process(true)


func core_state() -> CoreState:
	return _state


func _process(delta: float) -> void:
	_state.add_essence(_definition.essence_generation_rate * delta)
