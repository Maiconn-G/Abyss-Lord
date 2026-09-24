class_name SoldierRuntime
extends CharacterBody3D

@export var arrival_distance: float = 0.1

var definition: SoldierDefinition
var state: SoldierState

@onready var _selection_indicator: MeshInstance3D = $SelectionIndicator

var _target_position := Vector3.ZERO
var _has_move_target := false


func _ready() -> void:
	# Fora de movimento o Soldado não consome física nenhuma.
	if not _has_move_target:
		set_physics_process(false)


func setup(soldier_definition: SoldierDefinition, soldier_state: SoldierState) -> void:
	definition = soldier_definition
	state = soldier_state


func get_unit_id() -> String:
	return state.unit_id


func set_selected(value: bool) -> void:
	_selection_indicator.visible = value


func move_to(target: Vector3) -> void:
	_target_position = Vector3(target.x, global_position.y, target.z)
	_has_move_target = true
	if is_inside_tree():
		set_physics_process(true)


func has_move_target() -> bool:
	return _has_move_target


func _physics_process(_delta: float) -> void:
	if not _has_move_target:
		set_physics_process(false)
		return
	var offset := _planar_offset(_target_position)
	if offset.length() <= arrival_distance:
		global_position = Vector3(_target_position.x, global_position.y, _target_position.z)
		velocity = Vector3.ZERO
		_has_move_target = false
		set_physics_process(false)
		return
	velocity = offset.normalized() * definition.move_speed
	velocity.y = 0.0
	move_and_slide()


func _planar_offset(target: Vector3) -> Vector3:
	var offset := target - global_position
	offset.y = 0.0
	return offset
