class_name WorkerInvocationController
extends Node

const SUMMONED_UNIT_ID := "worker_002"

signal worker_summoned(worker: WorkerRuntime)

var _core_state: CoreState
var _definition: WorkerDefinition
var _scene: PackedScene
var _dungeon_root: Node3D
var _spawn_point: Node3D
var _deposit: ResourceDepositRuntime
var _summoned_worker: WorkerRuntime


func setup(
		core_state: CoreState,
		worker_definition: WorkerDefinition,
		worker_scene: PackedScene,
		dungeon_root: Node3D,
		spawn_point: Node3D) -> void:
	_core_state = core_state
	_definition = worker_definition
	_scene = worker_scene
	_dungeon_root = dungeon_root
	_spawn_point = spawn_point


func bind_delivery_deposit(deposit: ResourceDepositRuntime) -> void:
	_deposit = deposit


func summoned_worker() -> WorkerRuntime:
	return _summoned_worker


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("summon_worker"):
		summon_worker()


func summon_worker() -> bool:
	if _summoned_worker != null:
		return false
	if not _core_state.can_add_population(1):
		return false
	if _core_state.essence < _definition.summon_essence_cost:
		return false

	var worker := _scene.instantiate() as WorkerRuntime
	worker.setup(_definition, WorkerState.new(_definition, SUMMONED_UNIT_ID))
	worker.set_resource_deposit(_deposit)
	# A validação acima espelha exatamente as guardas de consume_essence() e
	# can_add_population(), então nenhum destes dois passos pode falhar aqui.
	_core_state.consume_essence(_definition.summon_essence_cost)
	_core_state.try_add_population(1)
	_dungeon_root.add_child(worker)
	worker.global_position = _spawn_point.global_position
	_summoned_worker = worker
	worker_summoned.emit(worker)
	return true
