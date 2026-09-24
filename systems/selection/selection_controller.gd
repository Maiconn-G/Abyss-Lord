class_name SelectionController
extends Node

const GROUND_LAYER := 1
const UNIT_LAYER := 2
const DIGGABLE_LAYER := 4
const RESOURCE_PICKUP_LAYER := 8
const CONSTRUCTION_LAYER := 16
const CLICKABLE_LAYERS := GROUND_LAYER | UNIT_LAYER | DIGGABLE_LAYER \
		| RESOURCE_PICKUP_LAYER | CONSTRUCTION_LAYER
const RAY_LENGTH := 1000.0

@export var drag_threshold: float = 8.0
@export var group_move_spacing: float = 1.2

var camera: Camera3D
var unit_container: Node
var selection_box: SelectionBox
var selected_units: Array[WorkerRuntime] = []

var _drag_pending := false
var _drag_box_active := false
var _drag_origin := Vector2.ZERO

var selected_unit: WorkerRuntime:
	get = _primary_unit


func setup(
		camera_reference: Camera3D,
		container: Node = null,
		box: SelectionBox = null) -> void:
	camera = camera_reference
	unit_container = container
	selection_box = box


func clear_selection() -> void:
	_replace_selection([])


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("select_unit"):
		_begin_selection(event.position)
	elif event.is_action_released("select_unit"):
		_finish_selection(event.position)
	elif event is InputEventMouseMotion and _drag_pending:
		_update_drag(event.position)
	elif event.is_action_pressed("command_move"):
		_command_at(event.position)


func _begin_selection(screen_position: Vector2) -> void:
	var additive := Input.is_action_pressed("selection_additive")
	var hit := _ray_hit(screen_position, CLICKABLE_LAYERS)
	if not hit.is_empty() and hit.collider is WorkerRuntime:
		_drag_pending = false
		_click_select(hit.collider, additive)
		return
	if not additive:
		clear_selection()
	_drag_pending = true
	_drag_origin = screen_position


func _update_drag(screen_position: Vector2) -> void:
	if not _drag_box_active and screen_position.distance_to(_drag_origin) < drag_threshold:
		return
	if not _drag_box_active:
		_drag_box_active = true
		if selection_box != null:
			selection_box.begin_drag(_drag_origin)
	if selection_box != null:
		selection_box.update_drag(screen_position)


func _finish_selection(screen_position: Vector2) -> void:
	if not _drag_box_active:
		_drag_pending = false
		return
	if selection_box != null:
		selection_box.end_drag()
	var rect := Rect2(_drag_origin, screen_position - _drag_origin).abs()
	_apply_box_selection(_units_in_rect(rect), Input.is_action_pressed("selection_additive"))
	_drag_pending = false
	_drag_box_active = false


func _click_select(worker: WorkerRuntime, additive: bool) -> void:
	if not additive:
		_replace_selection([worker])
		return
	if selected_units.has(worker):
		_replace_selection(_without(worker))
	else:
		selected_units.append(worker)
		worker.set_selected(true)


func _apply_box_selection(units: Array, additive: bool) -> void:
	if not additive:
		_replace_selection(units)
		return
	for unit in units:
		if not selected_units.has(unit):
			selected_units.append(unit)
			(unit as WorkerRuntime).set_selected(true)


func _units_in_rect(rect: Rect2) -> Array[WorkerRuntime]:
	var found: Array[WorkerRuntime] = []
	if camera == null or unit_container == null:
		return found
	for child in unit_container.get_children():
		var worker := child as WorkerRuntime
		if worker == null:
			continue
		var screen := _screen_position_of(worker)
		if screen != Vector2.INF and rect.has_point(screen):
			found.append(worker)
	found.sort_custom(_by_unit_id)
	return found


func _screen_position_of(worker: WorkerRuntime) -> Vector2:
	var local := camera.global_transform.affine_inverse() * worker.global_position
	if local.z >= 0.0:
		return Vector2.INF
	return camera.unproject_position(worker.global_position)


func _by_unit_id(a: WorkerRuntime, b: WorkerRuntime) -> bool:
	return a.state.unit_id < b.state.unit_id


func _without(worker: WorkerRuntime) -> Array[WorkerRuntime]:
	var remaining: Array[WorkerRuntime] = []
	for unit in selected_units:
		if unit != worker:
			remaining.append(unit)
	return remaining


func _replace_selection(units: Array) -> void:
	var previous := selected_units.duplicate()
	selected_units.clear()
	selected_units.append_array(units)
	for unit in previous:
		if not selected_units.has(unit):
			unit.set_selected(false)
	for unit in selected_units:
		unit.set_selected(true)


func _select(unit: WorkerRuntime) -> void:
	if unit == null:
		clear_selection()
		return
	_replace_selection([unit])


func _primary_unit() -> WorkerRuntime:
	return selected_units[0] if not selected_units.is_empty() else null


func _command_at(screen_position: Vector2) -> void:
	if selected_units.is_empty():
		return
	var hit := _ray_hit(screen_position, CLICKABLE_LAYERS)
	if hit.is_empty():
		return
	var collider: Object = hit.collider
	if collider is NestRuntime:
		for unit in selected_units:
			unit.assign_construction_target(collider)
	elif collider is RockRuntime:
		for unit in selected_units:
			unit.assign_excavation_target(collider)
	elif collider is ResourcePileRuntime:
		for unit in selected_units:
			unit.collect_resource_pile(collider)
	elif collider is StaticBody3D:
		_move_group_to(hit.position)


func _move_group_to(center: Vector3) -> void:
	var count := selected_units.size()
	for index in count:
		selected_units[index].move_to(_group_target(center, index, count))


# Offsets determinísticos: a mesma seleção e o mesmo ponto produzem sempre os mesmos
# alvos, o que impede os Workers de terminarem sobrepostos.
func _group_target(center: Vector3, index: int, count: int) -> Vector3:
	if count <= 1:
		return center
	var shift := (float(index) - float(count - 1) * 0.5) * group_move_spacing
	return center + Vector3(shift, 0.0, 0.0)


func _ray_hit(screen_position: Vector2, mask: int) -> Dictionary:
	if camera == null:
		return {}
	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * RAY_LENGTH, mask)
	return get_viewport().world_3d.direct_space_state.intersect_ray(query)
