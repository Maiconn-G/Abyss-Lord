class_name RockRuntime
extends StaticBody3D

signal resource_drop_requested(
		resource: ResourceDefinition,
		amount: int,
		world_position: Vector3,
		source_id: String)

@export var rock_id: String = ""
@export var definition: RockDefinition

var state: RockState

@onready var _visual: MeshInstance3D = $Visual
@onready var _collision: CollisionShape3D = $CollisionShape3D


func setup(rock_definition: RockDefinition, rock_state: RockState) -> void:
	definition = rock_definition
	state = rock_state
	state.excavated.connect(_on_excavated)


func _on_excavated() -> void:
	if definition.yield_resource != null and definition.yield_amount > 0:
		resource_drop_requested.emit(
				definition.yield_resource, definition.yield_amount, global_position, state.rock_id)
	_collision.disabled = true
	_visual.visible = false
	queue_free()
