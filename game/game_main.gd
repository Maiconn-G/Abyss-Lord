extends Node

const RESOURCE_PILE_SCENE := preload("res://world/resources/ResourcePileRuntime.tscn")
const NEST_SCENE := preload("res://world/dungeon/rooms/nest/NestRuntime.tscn")
const BARRACKS_SCENE := preload("res://world/dungeon/rooms/barracks/BarracksRuntime.tscn")
const WORKER_SCENE := preload("res://units/workers/WorkerRuntime.tscn")
const SOLDIER_SCENE := preload("res://units/soldiers/SoldierRuntime.tscn")
const ENEMY_SCENE := preload("res://units/enemies/EnemyRuntime.tscn")

@export var core_definition: CoreDefinition
@export var worker_definition: WorkerDefinition
@export var iron_ore_definition: ResourceDefinition
@export var nest_definition: NestDefinition
@export var barracks_definition: BarracksDefinition
@export var enemy_definition: EnemyDefinition
## §3/T14: a Definition de destino da única evolução existente. Ela é um dado injetado
## na cena, exatamente como as outras — o controller nunca carrega caminho de arquivo.
@export var core_level_2_definition: CoreDefinition

@onready var _dungeon: Node3D = $World/DungeonRoot
@onready var _core: CoreRuntime = $World/DungeonRoot/MainCore
@onready var _worker: WorkerRuntime = $World/DungeonRoot/Worker001
@onready var _deposit: ResourceDepositRuntime = $World/DungeonRoot/Deposit001
@onready var _build_point: Marker3D = $World/DungeonRoot/NestBuildPoint
@onready var _barracks_build_point: Marker3D = $World/DungeonRoot/BarracksBuildPoint
@onready var _spawn_point: Marker3D = $World/DungeonRoot/WorkerSpawnPoint
@onready var _soldier_spawn_point: Marker3D = $World/DungeonRoot/SoldierSpawnPoint
@onready var _invasion_point_a: Marker3D = $World/DungeonRoot/InvasionSpawnPointA
@onready var _invasion_point_b: Marker3D = $World/DungeonRoot/InvasionSpawnPointB
@onready var _hud: CoreDebugHud = $UI/CoreDebugPanel
@onready var _resource_hud: ResourceDebugHud = $UI/ResourceDebugPanel
@onready var _construction_hud: ConstructionDebugHud = $UI/ConstructionDebugPanel
@onready var _invocation_hud: WorkerInvocationDebugHud = $UI/WorkerInvocationDebugPanel
@onready var _military_hud: MilitaryDebugHud = $UI/MilitaryDebugPanel
@onready var _combat_hud: CombatDebugHud = $UI/CombatDebugPanel
@onready var _invasion_hud: InvasionDebugHud = $UI/InvasionDebugPanel
@onready var _invasion_warning_hud: InvasionWarningHud = $UI/InvasionWarningPanel
@onready var _evolution_hud: CoreEvolutionDebugHud = $UI/CoreEvolutionDebugPanel
@onready var _selection_box: SelectionBox = $UI/SelectionBox
@onready var _selection: SelectionController = $Systems/SelectionController
@onready var _construction: ConstructionController = $Systems/ConstructionController
@onready var _invocation: WorkerInvocationController = $Systems/WorkerInvocationController
@onready var _recruitment: SoldierRecruitmentController = $Systems/SoldierRecruitmentController
@onready var _invasion: InvasionController = $Systems/InvasionController
@onready var _evolution: CoreEvolutionController = $Systems/CoreEvolutionController


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

	_construction.setup(
			stockpile_state,
			nest_definition,
			NEST_SCENE,
			_build_point,
			_dungeon,
			barracks_definition,
			BARRACKS_SCENE,
			_barracks_build_point)
	_construction.bind_core_state(core_state)
	_construction_hud.bind(_construction, stockpile_state, nest_definition)

	_invocation.setup(core_state, worker_definition, WORKER_SCENE, _dungeon, _spawn_point)
	_invocation.bind_delivery_deposit(_deposit)

	_recruitment.setup(
			core_state,
			barracks_definition.soldier_definition,
			SOLDIER_SCENE,
			_dungeon,
			_soldier_spawn_point,
			_construction)
	_military_hud.bind(_construction, _recruitment, stockpile_state, core_state, barracks_definition)

	# §32: a partida abre sem nenhum inimigo. Quem planta Feras no mundo agora é a
	# invasão, e ela recebe tudo pronto por injeção — nada de lookup global.
	_invasion.setup(
			enemy_definition,
			ENEMY_SCENE,
			_dungeon,
			_core,
			[_invasion_point_a, _invasion_point_b])
	_invasion.invasion_started.connect(_on_invasion_started)
	_invasion_hud.bind(_invasion)
	_invasion_warning_hud.bind(_invasion)
	_combat_hud.bind_recruitment(_recruitment, barracks_definition.soldier_definition)

	# §27/T14: a vitória da invasão é o que destrava a evolução, e a passagem acontece
	# aqui, por signal. O controller de progressão não conhece o InvasionController, não
	# pergunta estado da invasão, não procura o Núcleo na árvore e não roda por frame.
	_evolution.setup(_core, core_state, core_level_2_definition)
	_invasion.invasion_victory.connect(_evolution.unlock_after_victory)
	_evolution_hud.bind(_evolution, core_state)

	# §6/§33/T13: o Ninho concluído é o que anuncia a ameaça. A conexão é uma linha,
	# feita aqui, sobre um signal que o ConstructionController já emitia — a invasão
	# não procura Ninho nenhum na árvore e não existe sistema de eventos.
	_construction.nest_completed.connect(_on_nest_completed)

	_bind_rocks()

	core_state.try_add_population(1)
	_hud.bind_core(core_state)
	_invocation_hud.bind(_invocation, core_state, worker_definition)
	_selection.setup($World/CameraRig/Camera3D, _dungeon, _selection_box)


## A Fera deixou de ser plantada aqui (§32): a invasão é dona das criaturas de
## produção. O que a composition root ainda faz é apresentar os invasores ao painel
## de combate, para que o duelo em si continue visível durante a defesa.
func _on_invasion_started(invaders: Array) -> void:
	for enemy in invaders:
		_combat_hud.bind_enemy(enemy)


## §6/T13: o primeiro Ninho concluído é o momento em que o domínio passa a ser visto.
## Aqui só existe a passagem — quem conta os 60 segundos é o InvasionController.
func _on_nest_completed(_nest: NestRuntime) -> void:
	_invasion.begin_preparation()


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
