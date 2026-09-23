class_name SelectionController
extends Node

const GROUND_LAYER := 1
const UNIT_LAYER := 2
const DIGGABLE_LAYER := 4
const CLICKABLE_LAYERS := GROUND_LAYER | UNIT_LAYER | DIGGABLE_LAYER
const RAY_LENGTH := 1000.0

var camera: Camera3D
var selected_unit: WorkerRuntime


func setup(camera_reference: Camera3D) -> void:
	camera = camera_reference


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("select_unit"):
		_select_at(event.position)
	elif event.is_action_pressed("command_move"):
		_command_move_at(event.position)


func _select_at(screen_position: Vector2) -> void:
	var hit := _ray_hit(screen_position, CLICKABLE_LAYERS)
	if not hit.is_empty() and hit.collider is WorkerRuntime:
		_select(hit.collider)
	else:
		_select(null)


func _command_move_at(screen_position: Vector2) -> void:
	if selected_unit == null:
		return
	var hit := _ray_hit(screen_position, CLICKABLE_LAYERS)
	if hit.is_empty():
		return
	if hit.collider is RockRuntime:
		selected_unit.assign_excavation_target(hit.collider)
	elif hit.collider is StaticBody3D:
		selected_unit.move_to(hit.position)


func _select(unit: WorkerRuntime) -> void:
	if selected_unit == unit:
		return
	if selected_unit != null:
		selected_unit.set_selected(false)
	selected_unit = unit
	if selected_unit != null:
		selected_unit.set_selected(true)


func _ray_hit(screen_position: Vector2, mask: int) -> Dictionary:
	if camera == null:
		return {}
	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * RAY_LENGTH, mask)
	return get_viewport().world_3d.direct_space_state.intersect_ray(query)
