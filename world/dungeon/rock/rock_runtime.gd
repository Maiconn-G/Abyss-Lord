class_name RockRuntime
extends StaticBody3D

var definition: RockDefinition
var state: RockState

@onready var _visual: MeshInstance3D = $Visual
@onready var _collision: CollisionShape3D = $CollisionShape3D


func setup(rock_definition: RockDefinition, rock_state: RockState) -> void:
	definition = rock_definition
	state = rock_state
	state.excavated.connect(_on_excavated)


func _on_excavated() -> void:
	_collision.disabled = true
	_visual.visible = false
	queue_free()
