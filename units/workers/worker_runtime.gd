class_name WorkerRuntime
extends CharacterBody3D

enum ActionMode { IDLE, MOVE, EXCAVATE, COLLECT, DELIVER }

@export var arrival_distance: float = 0.1
@export var work_range: float = 1.8
@export var pickup_range: float = 0.8
@export var deposit_range: float = 0.8

var definition: WorkerDefinition
var state: WorkerState

@onready var _selection_indicator: MeshInstance3D = $SelectionIndicator
@onready var _carry_indicator: MeshInstance3D = $CarryIndicator

var _mode: ActionMode = ActionMode.IDLE
var _target_position := Vector3.ZERO
var _has_move_target := false
var _excavation_target: RockRuntime
var _collection_target: ResourcePileRuntime
var _deposit: ResourceDepositRuntime


func setup(worker_definition: WorkerDefinition, worker_state: WorkerState) -> void:
	definition = worker_definition
	state = worker_state


func set_resource_deposit(deposit: ResourceDepositRuntime) -> void:
	_deposit = deposit


func set_selected(value: bool) -> void:
	_selection_indicator.visible = value


func move_to(target: Vector3) -> void:
	if _is_delivering():
		return
	_clear_targets()
	_mode = ActionMode.MOVE
	_target_position = Vector3(target.x, global_position.y, target.z)
	_has_move_target = true


func assign_excavation_target(rock: RockRuntime) -> void:
	if _is_delivering():
		return
	_clear_targets()
	_excavation_target = rock
	_mode = ActionMode.EXCAVATE
	_target_position = _approach_point(rock.global_position, work_range)
	_has_move_target = true


func collect_resource_pile(pile: ResourcePileRuntime) -> void:
	if _is_delivering():
		return
	_clear_targets()
	_collection_target = pile
	_mode = ActionMode.COLLECT
	_target_position = _approach_point(pile.global_position, pickup_range)
	_has_move_target = true


func has_move_target() -> bool:
	return _has_move_target


func is_excavating() -> bool:
	return _mode == ActionMode.EXCAVATE and is_instance_valid(_excavation_target)


func current_excavation_target() -> RockRuntime:
	return _excavation_target


func action_mode() -> ActionMode:
	return _mode


func _physics_process(delta: float) -> void:
	_invalidate_dead_targets()
	if _mode == ActionMode.EXCAVATE and _in_range_of(_excavation_target.global_position, work_range):
		_stop_walking()
		_excavation_target.state.apply_work(definition.work_speed * delta)
		return
	if _mode == ActionMode.COLLECT and _in_range_of(_collection_target.global_position, pickup_range):
		_take_from_pile()
		return
	if _mode == ActionMode.DELIVER and _in_range_of(_deposit.deposit_point_position(), deposit_range):
		_deliver_cargo()
		return
	if not _has_move_target:
		return
	var offset := _planar_offset(_target_position)
	if offset.length() <= arrival_distance:
		global_position = Vector3(_target_position.x, global_position.y, _target_position.z)
		_stop_walking()
		return
	velocity = offset.normalized() * definition.move_speed
	velocity.y = 0.0
	move_and_slide()


func _take_from_pile() -> void:
	var resource := _collection_target.definition
	var taken := _collection_target.state.take(definition.carry_capacity)
	_stop_walking()
	_collection_target = null
	if taken <= 0:
		_mode = ActionMode.IDLE
		return
	state.set_cargo(resource, taken)
	_carry_indicator.visible = true
	_mode = ActionMode.DELIVER
	_target_position = _deposit.deposit_point_position()
	_target_position.y = global_position.y
	_has_move_target = true


func _deliver_cargo() -> void:
	_deposit.deposit(state.carried_resource, state.carried_amount)
	state.clear_cargo()
	_carry_indicator.visible = false
	_stop_walking()
	_mode = ActionMode.IDLE


func _invalidate_dead_targets() -> void:
	if _mode == ActionMode.EXCAVATE and not is_instance_valid(_excavation_target):
		_cancel_action()
	elif _mode == ActionMode.COLLECT and not is_instance_valid(_collection_target):
		_cancel_action()


func _cancel_action() -> void:
	_clear_targets()
	_stop_walking()
	_mode = ActionMode.IDLE


func _clear_targets() -> void:
	_excavation_target = null
	_collection_target = null


func _is_delivering() -> bool:
	return _mode == ActionMode.DELIVER


func _stop_walking() -> void:
	velocity = Vector3.ZERO
	_has_move_target = false


func _in_range_of(target: Vector3, distance: float) -> bool:
	return _planar_offset(target).length() <= distance


func _approach_point(target: Vector3, distance: float) -> Vector3:
	var to_target := _planar_offset(target)
	if to_target.length() <= 0.0001:
		return global_position
	return Vector3(target.x, global_position.y, target.z) \
			- to_target.normalized() * (distance - arrival_distance)


func _planar_offset(target: Vector3) -> Vector3:
	var offset := target - global_position
	offset.y = 0.0
	return offset
