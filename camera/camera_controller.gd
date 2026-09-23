extends Node3D
class_name CameraController

@export var move_speed: float = 12.0
@export var zoom_step: float = 2.0
@export var min_zoom_distance: float = 8.0
@export var max_zoom_distance: float = 28.0
@export var initial_zoom_distance: float = 20.0
@export var tilt_degrees: float = 45.0
@export var movement_bound: float = 15.0

@onready var _camera: Camera3D = $Camera3D

var _zoom_distance: float = 20.0


func _ready() -> void:
	_zoom_distance = clampf(initial_zoom_distance, min_zoom_distance, max_zoom_distance)
	_apply_camera_transform()


func _process(delta: float) -> void:
	_move(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("camera_zoom_in"):
		_step_zoom(-zoom_step)
	elif event.is_action_pressed("camera_zoom_out"):
		_step_zoom(zoom_step)


func _move(delta: float) -> void:
	var input_axis := Input.get_vector("camera_left", "camera_right", "camera_forward", "camera_backward")
	if input_axis == Vector2.ZERO:
		return
	global_position.x = clampf(global_position.x + input_axis.x * move_speed * delta, -movement_bound, movement_bound)
	global_position.z = clampf(global_position.z + input_axis.y * move_speed * delta, -movement_bound, movement_bound)


func _step_zoom(delta_distance: float) -> void:
	var distance := clampf(_zoom_distance + delta_distance, min_zoom_distance, max_zoom_distance)
	if is_equal_approx(distance, _zoom_distance):
		return
	_zoom_distance = distance
	_apply_camera_transform()


func _apply_camera_transform() -> void:
	var tilt := deg_to_rad(tilt_degrees)
	_camera.position = Vector3(0.0, sin(tilt), cos(tilt)) * _zoom_distance
	_camera.rotation_degrees = Vector3(-tilt_degrees, 0.0, 0.0)
