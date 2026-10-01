extends Node

const RESOURCE_PILE_SCENE := preload("res://world/resources/ResourcePileRuntime.tscn")
const NEST_SCENE := preload("res://world/dungeon/rooms/nest/NestRuntime.tscn")
const BARRACKS_SCENE := preload("res://world/dungeon/rooms/barracks/BarracksRuntime.tscn")
## §17/T20: a cena da Mina entra na composition root como as outras duas obras — o
## controller recebe a cena por parâmetro e nunca procura caminho de arquivo sozinho.
const MINE_SCENE := preload("res://world/dungeon/rooms/mine/MineRuntime.tscn")
## §24/T21: a cena da Fazenda Fúngica entra na composition root pelo mesmo caminho — o
## controller recebe a cena por parâmetro e nunca procura caminho de arquivo sozinho.
const FUNGAL_FARM_SCENE := preload(
		"res://world/dungeon/rooms/fungal_farm/FungalFarmRuntime.tscn")
const WORKER_SCENE := preload("res://units/workers/WorkerRuntime.tscn")
const SOLDIER_SCENE := preload("res://units/soldiers/SoldierRuntime.tscn")
const ENEMY_SCENE := preload("res://units/enemies/EnemyRuntime.tscn")
const ROCK_SCENE := preload("res://world/dungeon/rock/RockRuntime.tscn")
## §10/§11/T18: a persistência é um controller como os outros — criado e injetado aqui,
## na raiz de composição. Ele não é Autoload, não se procura na árvore e não descobre
## caminho de arquivo sozinho (§127).
const SAVE_SCRIPT := preload("res://systems/persistence/save_game_controller.gd")

@export var core_definition: CoreDefinition
@export var worker_definition: WorkerDefinition
@export var iron_ore_definition: ResourceDefinition
@export var nest_definition: NestDefinition
@export var barracks_definition: BarracksDefinition
@export var enemy_definition: EnemyDefinition
## §3/T14: a Definition de destino da única evolução existente. Ela é um dado injetado
## na cena, exatamente como as outras — o controller nunca carrega caminho de arquivo.
@export var core_level_2_definition: CoreDefinition
## §15/T17: a chave de progressão do domínio. É um export como qualquer Definition, e o
## State que a representa nasce aqui, na raiz de composição, porque o Cristal pertence ao
## Núcleo — não ao estoque operacional do Depósito (§3).
@export var abyssal_crystal_definition: AbyssalCrystalDefinition
## §8/§9/T20: a Definition da Mina é dado injetado, como cada outra obra. O nível exigido,
## o custo e o par (montante, intervalo) do rendimento vivem no .tres, não aqui.
@export var mine_definition: MineDefinition
## §6/§24/T21: a Definition da Fazenda Fúngica é dado injetado, como cada outra obra. O
## nível exigido, o custo, o par (montante, intervalo) e o preço em Essência por ciclo vivem
## no .tres, não aqui.
@export var fungal_farm_definition: FungalFarmDefinition
## §23/T21: o recurso orgânico. É uma ResourceDefinition como o Minério e mora no MESMO
## estoque genérico — não há pilha, depósito nem State próprios para a Biomassa.
@export var biomass_definition: ResourceDefinition

@onready var _dungeon: Node3D = $World/DungeonRoot
@onready var _core: CoreRuntime = $World/DungeonRoot/MainCore
@onready var _worker: WorkerRuntime = $World/DungeonRoot/Worker001
@onready var _deposit: ResourceDepositRuntime = $World/DungeonRoot/Deposit001
@onready var _build_point: Marker3D = $World/DungeonRoot/NestBuildPoint
@onready var _barracks_build_point: Marker3D = $World/DungeonRoot/BarracksBuildPoint
@onready var _mine_build_point: Marker3D = $World/DungeonRoot/MineBuildPoint
@onready var _fungal_farm_build_point: Marker3D = $World/DungeonRoot/FungalFarmBuildPoint
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

## §14/T17: o registro de conquista do domínio. Uma instância só, ao lado do CoreState do
## Núcleo principal, entregue por referência a quem concede e a quem cobra. Não é child
## Node porque é RefCounted, e não vira dois estados separados um por consumidor.
var _abyssal_crystal_state: AbyssalCrystalState
var _save: SaveGameController


func _ready() -> void:
	print("Abyss Lord - GameMain initialized.")
	var core_state := CoreState.new(core_definition)
	_core.setup(core_definition, core_state)
	_abyssal_crystal_state = AbyssalCrystalState.new(abyssal_crystal_definition)

	var worker_state := WorkerState.new(worker_definition, "worker_001")
	_worker.setup(worker_definition, worker_state)

	var stockpile_state := ResourceStockpileState.new()
	_deposit.setup(stockpile_state)
	_worker.set_resource_deposit(_deposit)
	# §38/T21: o painel de recursos passa a acompanhar os dois recursos operacionais. A
	# assinatura antiga de um recurso continua valendo; a Biomassa entra pelo segundo slot.
	_resource_hud.bind_stockpile(stockpile_state, iron_ore_definition, biomass_definition)

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
	# §26/T20: a Mina chega por vinculação própria, depois do Núcleo estar vinculado — é o
	# nível do CoreState que abre a porta dela, e o controller já o tem.
	_construction.bind_mine(mine_definition, MINE_SCENE, _mine_build_point)
	# §24/§31/T21: a Fazenda Fúngica chega por vinculação própria, depois do Núcleo e da Mina
	# — a porta dela tem as duas condições, e o controller já conhece ambas.
	_construction.bind_fungal_farm(
			fungal_farm_definition, FUNGAL_FARM_SCENE, _fungal_farm_build_point)
	_construction_hud.bind(
			_construction, stockpile_state, nest_definition, core_state,
			mine_definition, fungal_farm_definition)

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
	# §15/§17/T17: quem vence é quem entrega a chave. O State vinculado aqui é o mesmo
	# objeto que a evolução vai cobrar — não existe cópia, nem segundo registro.
	_invasion.bind_abyssal_crystal_state(_abyssal_crystal_state)
	_invasion_hud.bind(_invasion)
	_invasion_warning_hud.bind(_invasion)
	_combat_hud.bind_recruitment(_recruitment, barracks_definition.soldier_definition)

	# §27/T14: a vitória da invasão é o que destrava a evolução, e a passagem acontece
	# aqui, por signal. O controller de progressão não conhece o InvasionController, não
	# pergunta estado da invasão, não procura o Núcleo na árvore e não roda por frame.
	_evolution.setup(_core, core_state, core_level_2_definition)
	_evolution.bind_abyssal_crystal_state(_abyssal_crystal_state)
	_invasion.invasion_victory.connect(_evolution.unlock_after_victory)
	# §15/§49/T17: o painel lê o mesmo State, por isso o terceiro parâmetro — sem cópia e
	# sem polling. A assinatura continua compatível com quem chama bind() com dois.
	_evolution_hud.bind(_evolution, core_state, _abyssal_crystal_state)

	# §6/§33/T13: o Ninho concluído é o que anuncia a ameaça. A conexão é uma linha,
	# feita aqui, sobre um signal que o ConstructionController já emitia — a invasão
	# não procura Ninho nenhum na árvore e não existe sistema de eventos.
	_construction.nest_completed.connect(_on_nest_completed)

	_setup_save(stockpile_state, core_state)
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


## §37/§39/T18: apresentar as Rochas canônicas ao Save é o que as torna conhecidas mesmo
## depois de o Runtime virar monte e sair da cena. O State que o ledger guarda é o do
## próprio Runtime, entregue por `register_rock` — a cena não cria State de Rocha a mais.
func _bind_rocks() -> void:
	for child in _dungeon.get_children():
		var rock := child as RockRuntime
		if rock != null:
			_save.register_rock(rock)


## §10/§11/§16/T18: o controller de persistência nasce aqui e recebe tudo por parâmetro —
## os States que ele fotografa, os controllers que ele restaura e a whitelist de Definition
## e cenas com que a campanha foi montada. Ele não é Autoload, não se procura na árvore e
## não escolhe caminho de arquivo (§127).
func _setup_save(stockpile_state: ResourceStockpileState, core_state: CoreState) -> void:
	_save = SAVE_SCRIPT.new()
	_save.name = "SaveGameController"
	$Systems.add_child(_save)
	_save.setup(
			_core,
			core_state,
			_abyssal_crystal_state,
			stockpile_state,
			_dungeon,
			_selection,
			_construction,
			_invocation,
			_recruitment,
			_invasion,
			_evolution)
	_save.bind_restore_materials(
			worker_definition,
			barracks_definition.soldier_definition,
			enemy_definition,
			nest_definition,
			barracks_definition,
			mine_definition,
			fungal_farm_definition,
			[core_definition, core_level_2_definition],
			_resource_materials(),
			ROCK_SCENE,
			RESOURCE_PILE_SCENE)
	# §77/§80/T18: a carga não emite os sinais de conquista — ela devolve números. É aqui
	# que os painéis são realinhados com a campanha que o arquivo descreve.
	_save.load_succeeded.connect(_on_load_succeeded)


## §71/T18/T21: as Resources que a campanha conhece são as únicas que um load pode resolver,
## e elas vêm da própria cena — o recurso do Depósito, o rendimento de cada Rocha e, agora, a
## Biomassa da Fazenda Fúngica (§96/T21). A Fazenda deposita Biomassa no mesmo estoque
## genérico, então o id `biomass` precisa estar registrado aqui ou o save o recusaria como
## recurso desconhecido.
func _resource_materials() -> Array:
	var materials: Array = [iron_ore_definition]
	if biomass_definition != null and not materials.has(biomass_definition):
		materials.append(biomass_definition)
	for child in _dungeon.get_children():
		var rock := child as RockRuntime
		if rock != null and rock.definition.yield_resource != null \
				and not materials.has(rock.definition.yield_resource):
			materials.append(rock.definition.yield_resource)
	return materials


## §74/§77/T18: o último passo da ordem de restauração é a UI. Cada painel relê o estado
## que já foi aplicado; nenhum refresh reconstitui campanha.
func _on_load_succeeded(_path: String) -> void:
	var core_state := _core.core_state()
	_hud.refresh(core_state)
	_resource_hud.refresh()
	_construction_hud.refresh()
	_invocation_hud.refresh()
	_military_hud.refresh()
	_combat_hud.refresh_units(_recruitment.soldier(), _invasion.invaders())
	_invasion_hud.refresh(_invasion)
	_invasion_warning_hud.refresh(_invasion)
	_evolution_hud.refresh()
