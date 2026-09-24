extends Node

const RESOURCE_PILE_SCENE := preload("res://world/resources/ResourcePileRuntime.tscn")
const NEST_SCENE := preload("res://world/dungeon/rooms/nest/NestRuntime.tscn")

@export var core_definition: CoreDefinition
@export var worker_definition: WorkerDefinition
@export var iron_ore_definition: ResourceDefinition
@export var nest_definition: NestDefinition

@onready var _dungeon: Node3D = $World/DungeonRoot
@onready var _core: CoreRuntime = $World/DungeonRoot/MainCore
@onready var _worker: WorkerRuntime = $World/DungeonRoot/Worker001
@onready var _deposit: ResourceDepositRuntime = $World/DungeonRoot/Deposit001
@onready var _build_point: Marker3D = $World/DungeonRoot/NestBuildPoint
@onready var _hud: CoreDebugHud = $UI/CoreDebugPanel
@onready var _resource_hud: ResourceDebugHud = $UI/ResourceDebugPanel
@onready var _construction_hud: ConstructionDebugHud = $UI/ConstructionDebugPanel
@onready var _selection: SelectionController = $Systems/SelectionController
@onready var _construction: ConstructionController = $Systems/ConstructionController


func _ready() -> void:
	print("Abyss Lord - GameMain initialized.")
	var core_state := CoreState.new(core_definition)
	_core.setup(core_definition, core_state)

	var worker_state := WorkerState.new(worker_definition, "worker_001")
	_worker.setup(worker_definition, worker_state)

	var stockpile_state := ResourceStockpileState.new()
	_deposit.setup(stockpile_state)
	_worker.set_resource_deposit(_deposit)
	_resource_hud.bind_stockpile(stockpile_state, iron_ore_definition)

	_construction.setup(stockpile_state, nest_definition, NEST_SCENE, _build_point, _dungeon)
	_construction.bind_core_state(core_state)
	_construction_hud.bind(_construction, stockpile_state, nest_definition)

	_bind_rocks()

	core_state.set_population(1)
	_hud.bind_core(core_state)
	_selection.setup($World/CameraRig/Camera3D)


func _bind_rocks() -> void:
	for child in _dungeon.get_children():
		if child is RockRuntime:
			var rock := child as RockRuntime
			rock.setup(rock.definition, RockState.new(rock.definition, rock.rock_id))
			rock.resource_drop_requested.connect(_spawn_resource_drop)


func _spawn_resource_drop(
		resource: ResourceDefinition,
		amount: int,
		world_position: Vector3,
		source_id: String) -> void:
	var pile := RESOURCE_PILE_SCENE.instantiate() as ResourcePileRuntime
	pile.position = Vector3(world_position.x, 0.0, world_position.z)
	_dungeon.add_child(pile)
	pile.setup(resource, ResourcePileState.new(resource, source_id + "_drop", amount))
