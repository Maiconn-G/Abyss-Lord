class_name SoldierRecruitmentController
extends Node

const RECRUITED_UNIT_ID := "soldier_001"

signal soldier_recruited(soldier: SoldierRuntime)

var _core_state: CoreState
var _definition: SoldierDefinition
var _scene: PackedScene
var _dungeon_root: Node3D
var _spawn_point: Node3D
var _construction: ConstructionController
var _soldier: SoldierRuntime


func setup(
		core_state: CoreState,
		soldier_definition: SoldierDefinition,
		soldier_scene: PackedScene,
		dungeon_root: Node3D,
		spawn_point: Node3D,
		construction: ConstructionController) -> void:
	_core_state = core_state
	_definition = soldier_definition
	_scene = soldier_scene
	_dungeon_root = dungeon_root
	_spawn_point = spawn_point
	_construction = construction


func soldier() -> SoldierRuntime:
	return _soldier


func barracks_completed() -> bool:
	var barracks := _construction.barracks()
	return barracks != null and barracks.is_completed()


func can_recruit() -> bool:
	if _soldier != null:
		return false
	if not barracks_completed():
		return false
	if not _core_state.can_add_population(1):
		return false
	return _core_state.essence >= _definition.recruit_essence_cost


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("recruit_soldier"):
		recruit_soldier()


func recruit_soldier() -> bool:
	if not can_recruit():
		return false
	var soldier := _scene.instantiate() as SoldierRuntime
	soldier.setup(_definition, SoldierState.new(_definition, RECRUITED_UNIT_ID))
	# can_recruit() espelha exatamente as guardas de consume_essence() e
	# can_add_population(), então nenhum destes dois passos pode falhar aqui.
	_core_state.consume_essence(_definition.recruit_essence_cost)
	_core_state.try_add_population(1)
	_dungeon_root.add_child(soldier)
	soldier.global_position = _spawn_point.global_position
	_soldier = soldier
	soldier_recruited.emit(soldier)
	return true
