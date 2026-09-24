class_name ConstructionController
extends Node

signal nest_built(nest: NestRuntime)
signal nest_completed(nest: NestRuntime)
signal barracks_built(barracks: BarracksRuntime)
signal barracks_completed(barracks: BarracksRuntime)

const NEST_INSTANCE_ID := "nest_001"
const BARRACKS_INSTANCE_ID := "barracks_001"

var _stockpile: ResourceStockpileState
var _definition: NestDefinition
var _scene: PackedScene
var _build_point: Node3D
var _dungeon_root: Node3D
var _core_state: CoreState
var _nest: NestRuntime
var _barracks_definition: BarracksDefinition
var _barracks_scene: PackedScene
var _barracks_build_point: Node3D
var _barracks: BarracksRuntime


func setup(
		stockpile_state: ResourceStockpileState,
		nest_definition: NestDefinition,
		nest_scene: PackedScene,
		build_point: Node3D,
		dungeon_root: Node3D,
		barracks_definition: BarracksDefinition = null,
		barracks_scene: PackedScene = null,
		barracks_build_point: Node3D = null) -> void:
	_stockpile = stockpile_state
	_definition = nest_definition
	_scene = nest_scene
	_build_point = build_point
	_dungeon_root = dungeon_root
	_barracks_definition = barracks_definition
	_barracks_scene = barracks_scene
	_barracks_build_point = barracks_build_point


func bind_core_state(core_state: CoreState) -> void:
	_core_state = core_state


func nest() -> NestRuntime:
	return _nest


func barracks() -> BarracksRuntime:
	return _barracks


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("build_nest"):
		build_nest()
	elif event.is_action_pressed("build_barracks"):
		build_barracks()


func build_nest() -> bool:
	if _nest != null:
		return false
	if not _consume_build_cost(_definition):
		return false
	_nest = _instantiate_site(_scene, _definition, NEST_INSTANCE_ID, _build_point)
	_nest.state.construction_completed.connect(_on_nest_completed.bind(_nest))
	nest_built.emit(_nest)
	return true


func build_barracks() -> bool:
	if _barracks != null or _barracks_definition == null:
		return false
	if not _consume_build_cost(_barracks_definition):
		return false
	_barracks = _instantiate_site(_barracks_scene, _barracks_definition,
			BARRACKS_INSTANCE_ID, _barracks_build_point)
	_barracks.state.construction_completed.connect(_on_barracks_completed.bind(_barracks))
	barracks_built.emit(_barracks)
	return true


# O consumo é atômico porque ResourceStockpileState.consume_resource() só desconta
# quando o saldo cobre o custo inteiro.
func _consume_build_cost(definition) -> bool:
	return _stockpile.consume_resource(definition.build_resource, definition.build_cost)


func _instantiate_site(
		scene: PackedScene,
		definition,
		instance_id: String,
		build_point: Node3D) -> Node3D:
	var site = scene.instantiate()
	_dungeon_root.add_child(site)
	site.global_position = build_point.global_position
	site.setup(definition, _make_state(definition, instance_id))
	return site


func _make_state(definition, instance_id: String):
	if definition is BarracksDefinition:
		return BarracksState.new(definition, instance_id)
	return NestState.new(definition, instance_id)


func _on_nest_completed(nest: NestRuntime) -> void:
	_core_state.add_population_capacity_bonus(_definition.population_capacity_bonus)
	nest_completed.emit(nest)


func _on_barracks_completed(barracks: BarracksRuntime) -> void:
	barracks_completed.emit(barracks)
