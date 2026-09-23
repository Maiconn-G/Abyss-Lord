extends Node

@export var core_definition: CoreDefinition
@export var worker_definition: WorkerDefinition
@export var rock_definition: RockDefinition

const ROCK_IDS := ["rock_001", "rock_002", "rock_003"]

@onready var _dungeon: Node3D = $World/DungeonRoot
@onready var _core: CoreRuntime = $World/DungeonRoot/MainCore
@onready var _worker: WorkerRuntime = $World/DungeonRoot/Worker001
@onready var _hud: CoreDebugHud = $UI/CoreDebugPanel
@onready var _selection: SelectionController = $Systems/SelectionController


func _ready() -> void:
	print("Abyss Lord - GameMain initialized.")
	var core_state := CoreState.new(core_definition)
	_core.setup(core_definition, core_state)

	var worker_state := WorkerState.new(worker_definition, "worker_001")
	_worker.setup(worker_definition, worker_state)

	_bind_rocks()

	core_state.set_population(1)
	_hud.bind_core(core_state)
	_selection.setup($World/CameraRig/Camera3D)


func _bind_rocks() -> void:
	var index := 0
	for child in _dungeon.get_children():
		if child is RockRuntime and index < ROCK_IDS.size():
			var rock := child as RockRuntime
			rock.setup(rock_definition, RockState.new(rock_definition, ROCK_IDS[index]))
			index += 1
