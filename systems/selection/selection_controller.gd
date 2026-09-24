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
const RTS_SELECTABLE_GROUP := &"rts_selectable"

@export var drag_threshold: float = 8.0
@export var group_move_spacing: float = 1.2

var camera: Camera3D
var unit_container: Node
var selection_box: SelectionBox

# selected_units guarda qualquer unidade do grupo rts_selectable (WorkerRuntime,
# SoldierRuntime). A ordem é sempre estável: arrasto e Shift produzem o mesmo
# resultado para o mesmo estado do mundo, ordenado por get_unit_id().
var selected_units: Array = []

var _drag_pending := false
var _drag_box_active := false
var _drag_origin := Vector2.ZERO

var selected_unit:
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
	if not hit.is_empty() and _is_selectable(hit.collider):
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


func _is_selectable(candidate) -> bool:
	return candidate is Node3D and (candidate as Node3D).is_in_group(RTS_SELECTABLE_GROUP)


func _click_select(unit, additive: bool) -> void:
	if not additive:
		_replace_selection([unit])
		return
	if selected_units.has(unit):
		_replace_selection(_without(unit))
	else:
		selected_units.append(unit)
		unit.set_selected(true)


func _apply_box_selection(units: Array, additive: bool) -> void:
	if not additive:
		_replace_selection(units)
		return
	for unit in units:
		if not selected_units.has(unit):
			selected_units.append(unit)
			unit.set_selected(true)


func _units_in_rect(rect: Rect2) -> Array:
	var found: Array = []
	if camera == null or unit_container == null:
		return found
	for child in unit_container.get_children():
		if not _is_selectable(child):
			continue
		var screen := _screen_position_of(child)
		if screen != Vector2.INF and rect.has_point(screen):
			found.append(child)
	found.sort_custom(_by_unit_id)
	return found


func _screen_position_of(unit) -> Vector2:
	var local: Vector3 = camera.global_transform.affine_inverse() * unit.global_position
	if local.z >= 0.0:
		return Vector2.INF
	return camera.unproject_position(unit.global_position)


func _by_unit_id(a, b) -> bool:
	return a.get_unit_id() < b.get_unit_id()


func _without(unit) -> Array:
	var remaining: Array = []
	for selected in selected_units:
		if selected != unit:
			remaining.append(selected)
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


func _select(unit) -> void:
	if unit == null:
		clear_selection()
		return
	_replace_selection([unit])


func _primary_unit():
	return selected_units[0] if not selected_units.is_empty() else null


# O alvo é classificado pela camada física que devolveu o ray, nunca pelo nome do
# nó. Unidades sem a capacidade do comando simplesmente não o recebem.
func _command_at(screen_position: Vector2) -> void:
	if selected_units.is_empty():
		return
	var hit := _ray_hit(screen_position, CLICKABLE_LAYERS)
	if hit.is_empty():
		return
	var collider := hit.collider as CollisionObject3D
	if collider == null:
		_move_group_to(hit.position)
		return
	var layer := collider.get_collision_layer()
	if layer & CONSTRUCTION_LAYER != 0:
		_give_work_order(&"assign_construction_target", collider)
	elif layer & DIGGABLE_LAYER != 0:
		_give_work_order(&"assign_excavation_target", collider)
	elif layer & RESOURCE_PICKUP_LAYER != 0:
		_give_work_order(&"collect_resource_pile", collider)
	else:
		_move_group_to(hit.position)


func _give_work_order(work_method: StringName, target: CollisionObject3D) -> void:
	for unit in selected_units:
		if unit.has_method(work_method):
			unit.call(work_method, target)


func _move_group_to(center: Vector3) -> void:
	var count := selected_units.size()
	for index in count:
		selected_units[index].move_to(_group_target(center, index, count))


# Offsets determinísticos: a mesma seleção e o mesmo ponto produzem sempre os mesmos
# alvos, o que impede as unidades de terminarem sobrepostas.
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
