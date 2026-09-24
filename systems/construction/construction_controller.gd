class_name ConstructionController
extends Node

signal nest_built(nest: NestRuntime)
signal nest_completed(nest: NestRuntime)

const NEST_INSTANCE_ID := "nest_001"

var _stockpile: ResourceStockpileState
var _definition: NestDefinition
var _scene: PackedScene
var _build_point: Node3D
var _dungeon_root: Node3D
var _core_state: CoreState
var _nest: NestRuntime


func setup(
		stockpile_state: ResourceStockpileState,
		nest_definition: NestDefinition,
		nest_scene: PackedScene,
		build_point: Node3D,
		dungeon_root: Node3D) -> void:
	_stockpile = stockpile_state
	_definition = nest_definition
	_scene = nest_scene
	_build_point = build_point
	_dungeon_root = dungeon_root


func bind_core_state(core_state: CoreState) -> void:
	_core_state = core_state


func nest() -> NestRuntime:
	return _nest


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("build_nest"):
		build_nest()


func build_nest() -> bool:
	if _nest != null:
		return false
	if not _stockpile.consume_resource(_definition.build_resource, _definition.build_cost):
		return false
	var nest := _scene.instantiate() as NestRuntime
	_dungeon_root.add_child(nest)
	nest.global_position = _build_point.global_position
	var state := NestState.new(_definition, NEST_INSTANCE_ID)
	nest.setup(_definition, state)
	state.construction_completed.connect(_on_construction_completed.bind(nest))
	_nest = nest
	nest_built.emit(nest)
	return true


func _on_construction_completed(nest: NestRuntime) -> void:
	_core_state.add_population_capacity_bonus(_definition.population_capacity_bonus)
	nest_completed.emit(nest)
