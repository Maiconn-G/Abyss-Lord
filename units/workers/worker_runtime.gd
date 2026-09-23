class_name WorkerRuntime
extends CharacterBody3D

@export var arrival_distance: float = 0.1
@export var work_range: float = 1.8

var definition: WorkerDefinition
var state: WorkerState

@onready var _selection_indicator: MeshInstance3D = $SelectionIndicator

var _target_position := Vector3.ZERO
var _has_move_target := false
var _excavation_target: RockRuntime


func setup(worker_definition: WorkerDefinition, worker_state: WorkerState) -> void:
	definition = worker_definition
	state = worker_state


func set_selected(value: bool) -> void:
	_selection_indicator.visible = value


func move_to(target: Vector3) -> void:
	_excavation_target = null
	_target_position = Vector3(target.x, global_position.y, target.z)
	_has_move_target = true


func assign_excavation_target(rock: RockRuntime) -> void:
	_excavation_target = rock
	_target_position = _approach_point(rock)
	_has_move_target = true


func has_move_target() -> bool:
	return _has_move_target


func is_excavating() -> bool:
	return _excavation_target != null


func current_excavation_target() -> RockRuntime:
	return _excavation_target


func _physics_process(delta: float) -> void:
	if _excavation_target != null and not is_instance_valid(_excavation_target):
		_excavation_target = null
		velocity = Vector3.ZERO
		_has_move_target = false
	if _excavation_target != null:
		var to_rock := _planar_offset(_excavation_target.global_position)
		if to_rock.length() <= work_range:
			velocity = Vector3.ZERO
			_has_move_target = false
			_excavation_target.state.apply_work(definition.work_speed * delta)
			return
	if not _has_move_target:
		return
	var offset := _planar_offset(_target_position)
	if offset.length() <= arrival_distance:
		global_position = Vector3(_target_position.x, global_position.y, _target_position.z)
		velocity = Vector3.ZERO
		_has_move_target = false
		return
	velocity = offset.normalized() * definition.move_speed
	velocity.y = 0.0
	move_and_slide()


func _approach_point(rock: RockRuntime) -> Vector3:
	var to_rock := _planar_offset(rock.global_position)
	if to_rock.length() <= 0.0001:
		return global_position
	var rock_position := rock.global_position
	return Vector3(rock_position.x, global_position.y, rock_position.z) \
			- to_rock.normalized() * (work_range - arrival_distance)


func _planar_offset(target: Vector3) -> Vector3:
	var offset := target - global_position
	offset.y = 0.0
	return offset
