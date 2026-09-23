extends Node

@export var core_definition: CoreDefinition
@export var worker_definition: WorkerDefinition

@onready var _core: CoreRuntime = $World/DungeonRoot/MainCore
@onready var _worker: WorkerRuntime = $World/DungeonRoot/Worker001
@onready var _hud: CoreDebugHud = $UI/CoreDebugPanel


func _ready() -> void:
	print("Abyss Lord - GameMain initialized.")
	var core_state := CoreState.new(core_definition)
	_core.setup(core_definition, core_state)

	var worker_state := WorkerState.new(worker_definition, "worker_001")
	_worker.setup(worker_definition, worker_state)

	core_state.set_population(1)
	_hud.bind_core(core_state)
