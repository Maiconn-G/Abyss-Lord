class_name WorkerRuntime
extends CharacterBody3D

@export var arrival_distance: float = 0.1

var definition: WorkerDefinition
var state: WorkerState

@onready var _selection_indicator: MeshInstance3D = $SelectionIndicator

var _target_position := Vector3.ZERO
var _has_move_target := false


func setup(worker_definition: WorkerDefinition, worker_state: WorkerState) -> void:
	definition = worker_definition
	state = worker_state


func set_selected(value: bool) -> void:
	_selection_indicator.visible = value


func move_to(target: Vector3) -> void:
	_target_position = Vector3(target.x, global_position.y, target.z)
	_has_move_target = true


func has_move_target() -> bool:
	return _has_move_target


func _physics_process(_delta: float) -> void:
	if not _has_move_target:
		return
	var offset := _target_position - global_position
	offset.y = 0.0
	if offset.length() <= arrival_distance:
		global_position = Vector3(_target_position.x, global_position.y, _target_position.z)
		velocity = Vector3.ZERO
		_has_move_target = false
		return
	velocity = offset.normalized() * definition.move_speed
	velocity.y = 0.0
	move_and_slide()
