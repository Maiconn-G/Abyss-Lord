extends Node

@export var core_definition: CoreDefinition

@onready var _core: CoreRuntime = $World/DungeonRoot/MainCore
@onready var _hud: CoreDebugHud = $UI/CoreDebugPanel


func _ready() -> void:
	print("Abyss Lord - GameMain initialized.")
	var state := CoreState.new(core_definition)
	_core.setup(core_definition, state)
	_hud.bind_core(state)
