class_name ResourcePileRuntime
extends StaticBody3D

var definition: ResourceDefinition
var state: ResourcePileState

@onready var _visual: MeshInstance3D = $Visual
@onready var _collision: CollisionShape3D = $CollisionShape3D


func setup(resource_definition: ResourceDefinition, resource_state: ResourcePileState) -> void:
	definition = resource_definition
	state = resource_state
	state.depleted.connect(_on_depleted)


func _on_depleted() -> void:
	_collision.disabled = true
	_visual.visible = false
	queue_free()
