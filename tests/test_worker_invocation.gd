extends SceneTree

const MAIN_SCENE := preload("res://game/GameMain.tscn")
const WORKER_SCENE := preload("res://units/workers/WorkerRuntime.tscn")
const INVOCATION_HUD_SCENE := preload("res://ui/hud/WorkerInvocationDebugHud.tscn")
const WORKER_DEFINITION_PATH := "res://data/units/workers/abyss_worker.tres"
const CORE_DEFINITION_PATH := "res://data/core/core_level_1.tres"
const IRON_ORE_PATH := "res://data/resources/iron_ore.tres"
const NEST_DEFINITION_PATH := "res://data/rooms/abyss_nest.tres"
const CONTROLLER_PATH := "res://systems/population/worker_invocation_controller.gd"
const HUD_PATH := "res://ui/hud/worker_invocation_debug_hud.gd"
const SELECTION_PATH := "res://systems/selection/selection_controller.gd"
const WORKER_RUNTIME_PATH := "res://units/workers/worker_runtime.gd"
const CAMERA_PATH := "res://camera/camera_controller.gd"
const CONSTRUCTION_PATH := "res://systems/construction/construction_controller.gd"

const GROUND_LAYER := 1
const UNIT_LAYER := 2
const DIGGABLE_LAYER := 4
const RESOURCE_LAYER := 8
const CONSTRUCTION_LAYER := 16
const OBSTACLES := DIGGABLE_LAYER | RESOURCE_LAYER | CONSTRUCTION_LAYER

const SPAWN_POINT := Vector3(0, 0, 4)
const WORKER001_START := Vector3(2, 0, 2)
const BUILD_POINT := Vector3(-5, 0, -5)
const ORDER_A := Vector3(2, 0, -7)
const ORDER_B := Vector3(-4, 0, 7)
const HARNESS_ORIGIN := Vector3(500, 0, 500)

const SUMMON_COST := 10.0
const BASE_CAPACITY := 8
const NEST_CAPACITY := 12
const INITIAL_ID := "worker_001"
const SUMMONED_ID := "worker_002"
const WORKER_RADIUS := 0.35
const ORE_ROCK_ID := "iron_ore_001"
const COMMON_ROCK_ID := "rock_002"
const ARRIVAL_TOLERANCE := 0.35

var _failures := 0
var _asserts := 0
var _frames := 0
var _scene: Node
var _dungeon: Node3D
var _worker: WorkerRuntime
var _worker2: WorkerRuntime
var _camera: Camera3D
var _selection: SelectionController
var _construction: ConstructionController
var _invocation: WorkerInvocationController
var _deposit: ResourceDepositRuntime
var _spawn_point: Marker3D
var _core: CoreRuntime
var _core_hud: Node
var _ore_hud: Node
var _nest_hud: Node
var _invocation_hud: Node
var _stockpile: ResourceStockpileState
var _ore_rock: RockRuntime
var _common_rock: RockRuntime
var _nest: NestRuntime
var _core_state: CoreState
var _population_events: Array[String] = []


func _initialize() -> void:
	_run_all()


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > 90000:
		_check(false, "timeout: a suíte de invocação não terminou")
		_finish()
	return false


func _run_all() -> void:
	await process_frame
	_test_worker_definition()
	_test_can_add_population()
	_test_try_add_population()
	_test_invalid_population_amount()
	_test_base_capacity()
	_test_nest_bonus()
	_test_capacity_gates()
	_test_summoned_state_defaults()
	await _test_summon_scenarios()
	await _test_capacity_unlocked_by_nest()
	await _test_transaction_is_atomic()
	await _test_invocation_hud_states()
	_boot_scene()
	await _advance(0.15)
	_test_scene_start()
	_test_spawn_point()
	await _test_capacity_full_blocks_real_input()
	await _test_real_summon()
	await _test_second_key_refuses()
	await _test_selection_independence()
	await _test_simultaneous_orders()
	await _test_worker2_excavates()
	await _test_nest_then_capacity_12()
	await _test_systems_survive()
	_test_scope_guards()
	_finish()


# ------------------------------------------------------------------- Definições


func _test_worker_definition() -> void:
	var definition := _worker_definition()
	_check(definition != null, "abyss_worker.tres carrega")
	_check(_close(definition.summon_essence_cost, SUMMON_COST), "§46 summon_essence_cost = 10.0")
	_check(typeof(definition.summon_essence_cost) == TYPE_FLOAT, "summon_essence_cost é float")
	_check(_script_fields("res://core/definitions/worker_definition.gd")
			== ["unit_type_id", "display_name", "max_health", "move_speed",
					"work_speed", "carry_capacity", "summon_essence_cost"],
			"§3 WorkerDefinition expõe exatamente os 7 campos previstos")
	_check(definition.max_health == 50.0 and definition.carry_capacity == 3,
			"§4 os campos do primeiro Worker continuam intactos")
	_check(definition == load(WORKER_DEFINITION_PATH),
			"§46 a Definition usada é o mesmo resource de abyss_worker.tres")
	_check(_core_definition().population_capacity == BASE_CAPACITY,
			"§50 core_level_1.tres continua com capacidade base 8")
	var controller_source := _source_text(CONTROLLER_PATH)
	_check(controller_source.contains("_definition.summon_essence_cost"),
			"§3 o custo é lido da Definition pelo controller")
	_check(not controller_source.contains("10.0"), "§3 nenhum custo hardcoded no controller")
	_check(not controller_source.contains("Minério")
			and not controller_source.contains("iron_ore"),
			"§2 a invocação não usa Minério, apenas Essência")


# ------------------------------------------------- API atômica de população (State)


func _test_can_add_population() -> void:
	var state := CoreState.new(_core_definition())
	state.set_population(1)
	_check(state.can_add_population(1), "§47 1/8 permite +1")
	_check(state.can_add_population(BASE_CAPACITY - 1), "§47 1/8 permite +7 (exatamente o teto)")
	_check(not state.can_add_population(BASE_CAPACITY), "§47 1/8 bloqueia +8")
	state.set_population(BASE_CAPACITY)
	_check(not state.can_add_population(1), "§47 8/8 bloqueia +1")
	_check(not state.can_add_population(2), "§47 8/8 bloqueia +2")
	state.add_population_capacity_bonus(4)
	_check(state.can_add_population(1), "§47 8/12 permite +1")
	_check(not state.can_add_population(5), "§47 8/12 bloqueia +5")


func _test_try_add_population() -> void:
	var state := CoreState.new(_core_definition())
	var events: Array[String] = []
	state.population_changed.connect(
			func(current: int, capacity: int) -> void: events.append("%d/%d" % [current, capacity]))
	state.set_population(1)
	events.clear()
	_check(state.try_add_population(1), "§48 try_add_population(1) devolve true")
	_check(state.population == 2, "§48 população subiu de 1 para 2")
	_check(events == ["2/8"], "§48 population_changed emite (população, capacidade)")
	state.set_population(BASE_CAPACITY - 1)
	events.clear()
	_check(state.try_add_population(1), "§48 7/8 permite crescer até o teto")
	_check(state.population == BASE_CAPACITY and events == ["8/8"],
			"§48 para exatamente em 8/8 com um único sinal")
	events.clear()
	_check(not state.try_add_population(1), "§48 tentar de novo em 8/8 devolve false")
	_check(state.population == BASE_CAPACITY, "§48 população travada em 8 após a recusa")
	_check(events.is_empty(), "§48 recusa não emite sinal de população")


func _test_invalid_population_amount() -> void:
	var state := CoreState.new(_core_definition())
	var events: Array[int] = []
	state.population_changed.connect(
			func(_current: int, _capacity: int) -> void: events.append(1))
	state.set_population(1)
	events.clear()
	_check(not state.can_add_population(0), "§49 can_add_population(0) devolve false")
	_check(not state.can_add_population(-1), "§49 can_add_population(-1) devolve false")
	_check(not state.try_add_population(0), "§49 try_add_population(0) devolve false")
	_check(not state.try_add_population(-1), "§49 try_add_population(-1) devolve false")
	_check(not state.try_add_population(-99), "try_add_population(-99) é recusada")
	_check(state.population == 1, "§49 valores inválidos não alteram a população")
	_check(events.is_empty(), "§49 valores inválidos não emitem sinal")


func _test_base_capacity() -> void:
	var state := CoreState.new(_core_definition())
	_check(state.population_capacity_bonus == 0, "§50 bônus inicial 0")
	_check(state.get_population_capacity() == BASE_CAPACITY, "§50 8 + 0 = 8 efetiva")
	_check(SUMMON_COST < state.definition.max_essence,
			"§2 o custo de 10 Essência cabe no teto de 50")
	_check(state.definition.essence_generation_rate > 0.0,
			"§32 a geração de Essência da Definition continua ativa")


func _test_nest_bonus() -> void:
	var state := CoreState.new(_core_definition())
	state.add_population_capacity_bonus(_nest_definition().population_capacity_bonus)
	_check(state.population_capacity_bonus == 4, "§51 bônus do Ninho = 4")
	_check(state.get_population_capacity() == NEST_CAPACITY, "§51 8 + 4 = 12 efetiva")
	_check(_nest_definition().population_capacity_bonus == 4,
			"§51 o bônus vem da NestDefinition, não do controller")


func _test_capacity_gates() -> void:
	var state := CoreState.new(_core_definition())
	state.set_population(BASE_CAPACITY)
	_check(not state.try_add_population(1), "§52/§26 8/8 + summon = false")
	_check(state.population == BASE_CAPACITY, "§52 população continua 8, sem clampar calado")
	state.add_population_capacity_bonus(4)
	_check(state.try_add_population(1), "§53/§27 8/12 + summon = true")
	_check(state.population == 9, "§53 população vira 9: o espaço do Ninho é utilizável")
	state.set_population(NEST_CAPACITY)
	_check(not state.try_add_population(1), "§54/§28 12/12 + summon = false")
	_check(state.population == NEST_CAPACITY, "§28 população nunca passa de 12")
	_check(not state.try_add_population(100), "§28 tentativa de +100 é recusada inteira")
	_check(state.population == NEST_CAPACITY, "§28 recusa não vira clamp para 13")
	state.set_population(NEST_CAPACITY + 1)
	_check(state.population == NEST_CAPACITY,
			"§7 set_population continua clampando (compatibilidade) enquanto summon falha")


func _test_summoned_state_defaults() -> void:
	var definition := _worker_definition()
	var state := WorkerState.new(definition, SUMMONED_ID)
	_check(state.unit_id == SUMMONED_ID, "§19 unit_id = worker_002")
	_check(state.definition == definition, "§19 o State aponta para a Definition compartilhada")
	_check(_close(state.health, 50.0), "§19 health inicia em 50")
	_check(_close(state.definition.max_health, 50.0), "§19 o máximo vem da Definition")
	_check(state.level == 1, "§19 level inicia em 1")
	_check(_close(state.experience, 0.0), "§19 experience inicia em 0")
	_check(state.carried_resource == null, "§19 carried_resource inicia nulo")
	_check(state.carried_amount == 0, "§19 carried_amount inicia 0")
	_check(state.has_signal("health_changed"), "WorkerState mantém o sinal de health")


# ------------------------------------------ Controller real: harness isolado


func _harness(essence: float, population: int) -> Dictionary:
	var host := Node3D.new()
	host.name = "InvocationHarness"
	root.add_child(host)
	host.global_position = HARNESS_ORIGIN
	var dungeon := Node3D.new()
	dungeon.name = "HarnessDungeon"
	host.add_child(dungeon)
	var spawn := Marker3D.new()
	spawn.name = "HarnessSpawnPoint"
	host.add_child(spawn)
	var core_state := CoreState.new(_core_definition())
	if essence < core_state.essence:
		core_state.consume_essence(core_state.essence - essence)
	if population > 0:
		core_state.set_population(population)
	var controller := WorkerInvocationController.new()
	controller.name = "HarnessInvocationController"
	host.add_child(controller)
	controller.setup(core_state, _worker_definition(), WORKER_SCENE, dungeon, spawn)
	return {
		"host": host,
		"dungeon": dungeon,
		"spawn": spawn,
		"controller": controller,
		"core_state": core_state,
	}


func _test_summon_scenarios() -> void:
	var blocked := _harness(9.0, 1)
	var blocked_controller: WorkerInvocationController = blocked.controller
	var blocked_state: CoreState = blocked.core_state
	_check(not blocked_controller.summon_worker(), "§65 Essência 9 < 10 bloqueia a invocação")
	_check(blocked.dungeon.get_child_count() == 0, "§65 nenhum Worker foi criado")
	_check(blocked_controller.summoned_worker() == null, "§65 o controller não registrou unidade")
	_check(_close(blocked_state.essence, 9.0), "§29/§65 Essência continua exatamente 9")
	_check(blocked_state.population == 1, "§29/§65 Population continua 1")
	blocked.host.free()

	var full := _harness(20.0, BASE_CAPACITY)
	var full_controller: WorkerInvocationController = full.controller
	var full_state: CoreState = full.core_state
	_check(not full_controller.summon_worker(), "§66 8/8 bloqueia mesmo com Essência sobrando")
	_check(_close(full_state.essence, 20.0), "§30/§66 Essência não é gasta na recusa")
	_check(full_state.population == BASE_CAPACITY, "§66 Population continua 8")
	_check(full.dungeon.get_child_count() == 0, "§66 nenhum Worker acima da capacidade")
	full.host.free()

	var scene := _harness(20.0, 1)
	var controller: WorkerInvocationController = scene.controller
	var core_state: CoreState = scene.core_state
	var events: Array[String] = []
	core_state.population_changed.connect(
			func(current: int, capacity: int) -> void: events.append("%d/%d" % [current, capacity]))
	_check(controller.summon_worker(), "§31 cenário padrão invoca")
	_check(_close(core_state.essence, 10.0, 0.0001),
			"§62 Essência 20 -> 10 exato, sem 9.999 nem 10.001")
	_check(core_state.population == 2, "§63 Population 1 -> 2")
	_check(events == ["2/8"], "§63 um único sinal de população por invocação")
	_check(controller.summoned_worker() != null, "§12 o controller expõe o Worker invocado")

	var worker := controller.summoned_worker()
	_check(worker.get_class() == "CharacterBody3D", "§21 o Runtime é um WorkerRuntime")
	_check(worker.state.unit_id == SUMMONED_ID, "§58 id do segundo Worker é worker_002")
	_check(worker.definition == _worker_definition(), "§20 Definition compartilhada")
	_check(worker.global_position.is_equal_approx(HARNESS_ORIGIN),
			"§8 Worker002 nasce exatamente no WorkerSpawnPoint")
	_check(worker.velocity == Vector3.ZERO, "§22 nasce parado")
	_check(worker.action_mode() == WorkerRuntime.ActionMode.IDLE, "§22 nasce em IDLE")
	_check(not worker.has_move_target(), "§22 sem alvo de movimento")
	_check(not worker.is_excavating(), "§22 sem alvo de escavação")
	_check(not worker.is_building(), "§22 sem alvo de construção")
	_check(worker.current_construction_target() == null, "current_construction_target é nulo")
	_check(worker.state.carried_amount == 0 and worker.state.carried_resource == null,
			"§22 nasce sem cargo")
	_check(not worker.find_child("CarryIndicator", true, false).visible,
			"§22 CarryIndicator escondido ao surgir")
	_check(not worker.find_child("SelectionIndicator", true, false).visible,
			"§22 SelectionIndicator escondido ao surgir")
	_check(worker.get_parent() == scene.dungeon,
			"§13 o Worker invocado entra no DungeonRoot injetado")
	_check(worker.scene_file_path == "res://units/workers/WorkerRuntime.tscn",
			"§21 reutiliza WorkerRuntime.tscn, sem cena variante")

	_check(not controller.summon_worker(), "§15 segundo I não invoca worker_003")
	_check(scene.dungeon.get_child_count() == 1, "§43 continua exatamente 1 Worker invocado")
	_check(_close(core_state.essence, 10.0, 0.0001), "§15 nenhuma Essência extra cobrada")
	_check(core_state.population == 2, "§15 Population continua 2")
	_check(events.size() == 1, "§63 nenhum sinal de população na recusa")
	scene.host.free()


func _test_capacity_unlocked_by_nest() -> void:
	var harness := _harness(20.0, BASE_CAPACITY)
	var controller: WorkerInvocationController = harness.controller
	var core_state: CoreState = harness.core_state
	_check(core_state.get_population_capacity() == BASE_CAPACITY, "§67 capacidade começa 8")
	_check(not controller.summon_worker(), "§67 com 8/8 a invocação é bloqueada")
	_check(harness.dungeon.get_child_count() == 0, "§67 nenhum Worker na recusa por capacidade")
	_check(_close(core_state.essence, 20.0), "§67 Essência intacta na recusa")
	core_state.add_population_capacity_bonus(_nest_definition().population_capacity_bonus)
	_check(core_state.get_population_capacity() == NEST_CAPACITY, "§67 o Ninho eleva para 12")
	_check(controller.summon_worker(), "§67 com 8/12 a mesma invocação agora passa")
	_check(core_state.population == 9, "§67 população vira 9")
	_check(_close(core_state.essence, 10.0, 0.0001),
			"§67 cobrança exata de 10 após liberar o espaço")
	_check(harness.dungeon.get_child_count() == 1, "§67 exatamente um Worker novo no mundo")
	harness.host.free()


func _test_transaction_is_atomic() -> void:
	var harness := _harness(20.0, 1)
	var controller: WorkerInvocationController = harness.controller
	var core_state: CoreState = harness.core_state
	var essence_reads: Array[float] = []
	core_state.essence_changed.connect(
			func(current: float, _maximum: float) -> void: essence_reads.append(current))
	controller.summon_worker()
	_check(essence_reads == [10.0], "§17 a Essência é debitada uma única vez, direto para 10")
	_check(harness.dungeon.get_child_count() == 1, "§17 existe Worker na cena do harness")
	_check(core_state.population == 2, "§17 existe população contabilizada")
	_check(controller.summoned_worker().get_parent() == harness.dungeon,
			"§17 o Worker está anexado ao mundo, não solto em memória")
	_check(_close(core_state.essence, 10.0, 0.0001),
			"§17 o débito e a criação acontecem juntos, sem estado parcial")
	harness.host.free()


func _test_invocation_hud_states() -> void:
	var harness := _harness(20.0, 1)
	var controller: WorkerInvocationController = harness.controller
	var core_state: CoreState = harness.core_state
	var hud := INVOCATION_HUD_SCENE.instantiate() as WorkerInvocationDebugHud
	harness.host.add_child(hud)
	hud.bind(controller, core_state, _worker_definition())
	_check(_text_of(hud, "HintLabel") == "[I] Invocar Trabalhador Abissal — 10 Essência",
			"§38 a dica mostra os 10 de custo lidos da Definition")
	_check(_text_of(hud, "StatusLabel") == "Pronto", "§74 estado inicial do HUD é Pronto")
	core_state.consume_essence(15.0)
	_check(_text_of(hud, "StatusLabel") == "Essência insuficiente",
			"§74 HUD reage a essence_changed com Essência insuficiente")
	core_state.add_essence(20.0)
	_check(_text_of(hud, "StatusLabel") == "Pronto", "§74 recuperar Essência devolve Pronto")
	core_state.set_population(BASE_CAPACITY)
	_check(_text_of(hud, "StatusLabel") == "Capacidade cheia", "§74 HUD mostra Capacidade cheia")
	core_state.add_population_capacity_bonus(4)
	_check(_text_of(hud, "StatusLabel") == "Pronto",
			"§74 liberar espaço pelo Ninho devolve Pronto")
	controller.summon_worker()
	_check(_text_of(hud, "StatusLabel") == "Segundo trabalhador invocado",
			"§74 HUD registra a invocação pelo sinal do controller")
	_check(hud.get_class() == "PanelContainer", "§38 o HUD é um PanelContainer")
	harness.host.free()


# ---------------------------------------------------------------------------- Cena


func _boot_scene() -> void:
	_scene = MAIN_SCENE.instantiate()
	root.add_child(_scene)
	_dungeon = _scene.get_node("World/DungeonRoot") as Node3D
	_worker = _scene.get_node("World/DungeonRoot/Worker001") as WorkerRuntime
	_camera = _scene.get_node("World/CameraRig/Camera3D") as Camera3D
	_selection = _scene.get_node("Systems/SelectionController") as SelectionController
	_construction = _scene.get_node("Systems/ConstructionController") as ConstructionController
	_invocation = _scene.get_node("Systems/WorkerInvocationController") as WorkerInvocationController
	_deposit = _scene.get_node("World/DungeonRoot/Deposit001") as ResourceDepositRuntime
	_spawn_point = _scene.get_node("World/DungeonRoot/WorkerSpawnPoint") as Marker3D
	_core = _scene.get_node("World/DungeonRoot/MainCore") as CoreRuntime
	_core_hud = _scene.get_node("UI/CoreDebugPanel")
	_ore_hud = _scene.get_node("UI/ResourceDebugPanel")
	_nest_hud = _scene.get_node("UI/ConstructionDebugPanel")
	_invocation_hud = _scene.get_node("UI/WorkerInvocationDebugPanel")
	_core_state = _core.core_state()
	_stockpile = _deposit.stockpile
	for child in _dungeon.get_children():
		if child is RockRuntime:
			var rock := child as RockRuntime
			if rock.rock_id == ORE_ROCK_ID:
				_ore_rock = rock
			elif rock.rock_id == COMMON_ROCK_ID:
				_common_rock = rock


func _test_scene_start() -> void:
	_check(_workers_in_scene().size() == 1, "§56 a cena inicia com exatamente 1 WorkerRuntime")
	_check(_worker.state.unit_id == INITIAL_ID, "§56 o primeiro Worker continua worker_001")
	_check(_core_state.population == 1, "§24 a partida inicia com Population 1")
	_check(_core_state.get_population_capacity() == BASE_CAPACITY, "§50 capacidade 8 no início")
	_check(_close(_core_state.essence, 20.0, 0.5), "§31/§73 Essência inicia ~20")
	_check(_text_of(_core_hud, "PopulationLabel") == "Population: 1 / 8",
			"§72 HUD de Population começa 1 / 8")
	_check(_text_of(_core_hud, "EssenceLabel") == "Essence: %d / 50" % roundi(_core_state.essence),
			"§73 HUD de Essence espelha o State desde o início")
	_check(_text_of(_invocation_hud, "StatusLabel") == "Pronto",
			"§74 HUD de invocação da cena começa Pronto")
	_check(_text_of(_invocation_hud, "HintLabel")
			== "[I] Invocar Trabalhador Abissal — 10 Essência",
			"§38 a dica da cena mostra o custo de 10 Essência")
	_check(_invocation.summoned_worker() == null, "§44 nenhum Worker invocado pendente")
	_check(not _source_text("res://game/game_main.gd").contains("set_population"),
			"§24 a composição inicial usa try_add_population, não set_population")


func _test_spawn_point() -> void:
	_check(_spawn_point.get_class() == "Marker3D", "§55 WorkerSpawnPoint é um Marker3D")
	_check(_spawn_point.is_inside_tree(), "§55 o spawn point está na cena")
	_check(_spawn_point.global_position.is_equal_approx(SPAWN_POINT),
			"§8 WorkerSpawnPoint em (0, 0, 4), junto do Núcleo")
	_check(_spawn_point.get_children().is_empty(), "§8 o spawn point não traz coliders próprios")
	_check(_shape_clear_at(SPAWN_POINT, WORKER_RADIUS + 0.15, OBSTACLES),
			"§55 nenhuma forma física sólida sob o ponto de spawn")
	var floor_hit := _ray_from_above(SPAWN_POINT, GROUND_LAYER)
	_check(not floor_hit.is_empty() and String(floor_hit.collider.name) == "TestFloorBody",
			"§55 o raycast do spawn cai no chão sem obstrução")
	_check(_planar_gap(SPAWN_POINT, WORKER001_START) > 2.0,
			"§9 Worker001 e o ponto de spawn têm separação clara")
	_check(_planar_gap(SPAWN_POINT, _deposit.global_position) > 2.0,
			"§8 o spawn não sobrepõe o depósito")
	_check(_planar_gap(SPAWN_POINT, BUILD_POINT) > 3.0,
			"§8 o spawn não sobrepõe o NestBuildPoint")
	_check(_planar_gap(SPAWN_POINT, _core.global_position) > 3.0,
			"§8 o spawn não sobrepõe o Núcleo")
	for rock in _rocks_in_scene():
		_check(_planar_gap(SPAWN_POINT, rock.global_position) > 2.2,
				"§8 o spawn não sobrepõe %s" % rock.rock_id)
	_check(_segment_clear_of(SPAWN_POINT, WORKER_RADIUS, ORDER_B, Vector3(6, 0, 8), 1.0)
			and _segment_clear_of(SPAWN_POINT, WORKER_RADIUS, ORDER_B, Vector3(6, 0, 2), 1.0),
			"§8 a rota reta a partir do spawn passa livre entre as rochas")
	_check(Rect2(Vector2.ZERO, Vector2(root.size))
			.has_point(_camera.unproject_position(SPAWN_POINT)),
			"§8 o spawn point está dentro do campo da câmera")


func _test_capacity_full_blocks_real_input() -> void:
	_core_state.set_population(BASE_CAPACITY)
	await _advance(0.05)
	_check(_text_of(_invocation_hud, "StatusLabel") == "Capacidade cheia",
			"§74 o HUD da cena mostra Capacidade cheia em 8/8")
	var essence_before := _core_state.essence
	_press_summon_key()
	await _advance(0.15)
	_check(_workers_in_scene().size() == 1,
			"§30 tecla I real com capacidade cheia não cria Worker na cena")
	_check(_core_state.population == BASE_CAPACITY, "§30 Population continua 8 na recusa")
	_check(_core_state.essence >= essence_before - 0.001,
			"§30 a ordem de validação impede desperdício de Essência")
	_check(_invocation.summoned_worker() == null, "§30 nada foi registrado no controller")
	_core_state.set_population(1)
	await _advance(0.05)
	_check(_text_of(_invocation_hud, "StatusLabel") == "Pronto",
			"§74 liberar espaço devolve o HUD da cena a Pronto")


func _test_real_summon() -> void:
	_population_events.clear()
	_core_state.population_changed.connect(_on_population_changed)
	var essence_before := _core_state.essence
	_press_summon_key()
	await _advance(0.15)
	_worker2 = _invocation.summoned_worker()
	_check(_workers_in_scene().size() == 2, "§57 a ação summon_worker pela tecla I invoca")
	_check(_worker2 != null and is_instance_valid(_worker2), "§57 Worker002 está vivo na cena")
	_check(_worker2.get_parent() == _dungeon, "§13 Worker002 entrou no DungeonRoot injetado")
	_check(_worker2.state.unit_id == SUMMONED_ID, "§58 o segundo Worker é worker_002")
	_check(_worker.state.unit_id == INITIAL_ID, "§58 o primeiro Worker segue sendo worker_001")
	_check(_worker.state != _worker2.state, "§59 cada Worker tem State próprio")
	_check(_worker.definition == _worker2.definition, "§20/§59 os dois compartilham a Definition")
	_check(_worker != _worker2, "§59 são dois Runtimes diferentes")
	_check(_worker2.scene_file_path == "res://units/workers/WorkerRuntime.tscn",
			"§21 mesma cena, sem WorkerRuntime2")
	_check(_close(essence_before - _core_state.essence, SUMMON_COST, 0.35),
			"§62 a cobrança foi exatamente o custo de 10")
	_check(_core_state.essence >= 9.9 and _core_state.essence <= 11.0,
			"§73 Essência caiu para ~10 na cena real")
	_check(_core_state.population == 2, "§23 Population 1 -> 2 na cena real")
	_check(_population_events == ["2/8"], "§63 sinal de população emitido uma única vez")
	_check(_worker2.global_position.is_equal_approx(SPAWN_POINT),
			"§76 Worker002 aparece no WorkerSpawnPoint")
	_check(_planar_gap(_worker2.global_position, _worker.global_position) > 2.0,
			"§9 os dois Workers não nasceram sobrepostos")
	_check(_worker2.velocity == Vector3.ZERO and not _worker2.has_move_target(),
			"§22 Worker002 surge parado, sem alvo de movimento")
	_check(_worker2.action_mode() == WorkerRuntime.ActionMode.IDLE,
			"§22 Worker002 surge em IDLE, sem comportamento automático")
	_check(_close(_worker2.state.health, 50.0) and _close(_worker.state.health, 50.0),
			"§19 cada um começa com 50 de HP")
	_check(_text_of(_core_hud, "PopulationLabel") == "Population: 2 / 8",
			"§72 HUD de Population passa a 2 / 8 por sinal")
	_check(_essence_label_value() <= 11 and _essence_label_value() >= 10,
			"§73 HUD de Essence mostra ~10 logo após invocar")
	_check(_text_of(_invocation_hud, "StatusLabel") == "Segundo trabalhador invocado",
			"§74 HUD de invocação da cena registra o segundo trabalhador")
	_check(_worker.state.carried_amount == 0, "§61 Worker001 continua sem cargo")
	_worker2.state.damage(10.0)
	_check(_close(_worker2.state.health, 40.0), "§60 dano em Worker002 leva seu HP a 40")
	_check(_close(_worker.state.health, 50.0), "§60 o HP de Worker001 permanece 50")
	_worker2.state.set_cargo(_iron_ore(), 2)
	_check(_worker2.state.carried_amount == 2, "§61 Worker002 pode carregar cargo próprio")
	_check(_worker.state.carried_amount == 0 and _worker.state.carried_resource == null,
			"§61 o cargo de Worker002 não vaza para Worker001")
	_worker2.state.clear_cargo()
	_check(_worker2.state.carried_amount == 0, "§61 o cargo de Worker002 é isolado e limpo")


func _test_second_key_refuses() -> void:
	var essence_before := _core_state.essence
	_press_summon_key()
	_press_summon_key()
	await _advance(0.2)
	_check(_workers_in_scene().size() == 2, "§64 pressionar I de novo não cria worker_003")
	_check(_core_state.population == 2, "§64 Population continua 2")
	_check(_core_state.essence >= essence_before - 0.001,
			"§64 a segunda tecla não cobra Essência nova")
	_check(_invocation.summoned_worker() == _worker2,
			"o mesmo Worker002 permanece registrado como o único invocado")
	var grown_from := _core_state.essence
	await _advance(1.5)
	_check(_core_state.essence > grown_from, "§32 a geração de Essência continua após invocar")
	_check(_core_state.essence <= _core_state.definition.max_essence,
			"§32 a Essência respeita o teto de 50")
	_check(_essence_label_value() >= 10, "§73 o HUD de Essence volta a crescer")


func _test_selection_independence() -> void:
	_click(MOUSE_BUTTON_LEFT, _worker.global_position)
	await _advance(0.05)
	_check(_selection.selected_unit == _worker, "§34 LMB em Worker001 seleciona Worker001")
	_check(_indicator(_worker).visible and not _indicator(_worker2).visible,
			"§34 apenas Worker001 mostra o indicador de seleção")
	_click(MOUSE_BUTTON_LEFT, _worker2.global_position)
	await _advance(0.05)
	_check(_selection.selected_unit == _worker2, "§33/§68 LMB em Worker002 o seleciona")
	_check(_indicator(_worker2).visible, "§68 Worker002 exibe o próprio indicador")
	_check(not _indicator(_worker).visible, "§33 Worker001 perde o indicador")
	_check(_selected_count() == 1, "§34 continua exatamente 1 unidade selecionada")
	_click(MOUSE_BUTTON_LEFT, _worker.global_position)
	await _advance(0.05)
	_check(_selection.selected_unit == _worker, "§34 re-selecionar Worker001 funciona")
	_check(_indicator(_worker).visible and not _indicator(_worker2).visible,
			"§34 os indicadores acompanham a troca de seleção")
	_click(MOUSE_BUTTON_LEFT, _worker2.global_position)
	await _advance(0.05)
	_click(MOUSE_BUTTON_LEFT, SPAWN_POINT + Vector3(3, 0, 0))
	await _advance(0.05)
	_check(_selection.selected_unit == null, "§34 clicar o chão limpa a seleção")
	_check(_selected_count() == 0, "§34 nenhum indicador fica aceso sem seleção")


func _test_simultaneous_orders() -> void:
	_click(MOUSE_BUTTON_LEFT, _worker.global_position)
	await _advance(0.05)
	_click(MOUSE_BUTTON_RIGHT, ORDER_A)
	await _advance(0.05)
	_click(MOUSE_BUTTON_LEFT, _worker2.global_position)
	await _advance(0.05)
	_click(MOUSE_BUTTON_RIGHT, ORDER_B)
	await _advance(0.1)
	_check(_worker.has_move_target() and _worker2.has_move_target(),
			"§70 os dois executam um deslocamento ao mesmo tempo")
	_check(_worker.current_excavation_target() == null
			and _worker2.current_excavation_target() == null,
			"§35 nenhum dos dois ganha alvo de escavação")
	var arrived := await _wait_until(
			func() -> bool:
				return not _worker.has_move_target() and not _worker2.has_move_target(), 15.0)
	_check(arrived, "§35 os dois concluem as próprias ordens")
	_check(_planar_gap(_worker.global_position, ORDER_A) <= ARRIVAL_TOLERANCE,
			"§70 Worker001 termina no ponto A")
	_check(_planar_gap(_worker2.global_position, ORDER_B) <= ARRIVAL_TOLERANCE,
			"§70 Worker002 termina no ponto B")
	_check(_planar_gap(_worker2.global_position, ORDER_A) > 1.0
			and _planar_gap(_worker.global_position, ORDER_B) > 1.0,
			"§35 nenhum dos dois foi para o destino do outro")
	_check(_worker.velocity == Vector3.ZERO and _worker2.velocity == Vector3.ZERO,
			"§70 ambos param depois de chegar")


func _test_worker2_excavates() -> void:
	_click(MOUSE_BUTTON_LEFT, _worker2.global_position)
	await _advance(0.05)
	_click(MOUSE_BUTTON_RIGHT, _common_rock.global_position)
	await _advance(0.1)
	_check(_worker2.is_excavating(), "§71 Worker002 aceita ordem de escavação")
	_check(_worker2.current_excavation_target() == _common_rock,
			"§71 o alvo de escavação é a Rocha Comum")
	_check(not _worker.has_move_target() and not _worker.is_excavating(),
			"§36/§71 a ordem de Worker002 não move Worker001")
	var remaining := _common_rock.state.remaining_work
	_check(_close(remaining, 4.0, 0.0001), "§71 a Rocha Comum começa com 4.0 de trabalho")
	var progressed := await _wait_until(
			func() -> bool: return _common_rock.state.remaining_work <= 2.0, 20.0)
	_check(progressed, "§71 Worker002 remove trabalho real da Rocha Comum")
	_check(is_instance_valid(_common_rock), "§71 a rocha ainda existe durante a escavação")
	_click(MOUSE_BUTTON_LEFT, _worker2.global_position)
	await _advance(0.05)
	_click(MOUSE_BUTTON_RIGHT, ORDER_B)
	await _advance(0.1)
	_check(not _worker2.is_excavating(), "§36 mover Worker002 cancela a escavação dele")
	await _wait_until(func() -> bool: return not _worker2.has_move_target(), 15.0)


func _test_nest_then_capacity_12() -> void:
	_click(MOUSE_BUTTON_LEFT, _worker.global_position)
	await _advance(0.05)
	_click(MOUSE_BUTTON_RIGHT, _ore_rock.global_position)
	await _advance(0.1)
	_check(_worker.is_excavating(), "§42 Worker001 vai minerar a Rocha de Minério")
	var mined := await _wait_until(
			func() -> bool: return not is_instance_valid(_ore_rock), 45.0)
	_check(mined, "§42 a Rocha de Minério é destruída pelo trabalho de Worker001")
	var pile := await _wait_for_pile(5.0)
	_check(pile != null, "§42 a pilha de minério aparece no mundo")
	_check(_stockpile.get_amount(&"iron_ore") == 0, "§42 estoque ainda 0 com a pilha no chão")
	_click(MOUSE_BUTTON_LEFT, _worker.global_position)
	await _advance(0.05)
	_click(MOUSE_BUTTON_RIGHT, pile.global_position)
	var carried := await _wait_until(
			func() -> bool: return _worker.state.carried_amount == 3, 25.0)
	_check(carried, "§42 Worker001 carrega os 3 minérios")
	var delivered := await _wait_until(
			func() -> bool: return _stockpile.get_amount(&"iron_ore") == 3, 30.0)
	_check(delivered, "§42 o estoque chega a 3 antes de gastar")
	var essence_before := _core_state.essence
	_press_build_key()
	await _advance(0.2)
	_nest = _construction.nest()
	_check(_nest != null, "§42 B cria o canteiro do Ninho")
	_check(_stockpile.get_amount(&"iron_ore") == 0, "§42 o minério foi gasto na obra")
	_check(_core_state.get_population_capacity() == BASE_CAPACITY,
			"§42 a capacidade ainda é 8 com o canteiro de pé")
	_check(_core_state.population == 2, "§25 o Ninho não conta como população")
	_click(MOUSE_BUTTON_LEFT, _worker.global_position)
	await _advance(0.05)
	_click(MOUSE_BUTTON_RIGHT, _nest.global_position)
	await _advance(0.05)
	_click(MOUSE_BUTTON_LEFT, _worker2.global_position)
	await _advance(0.05)
	_click(MOUSE_BUTTON_RIGHT, _nest.global_position)
	await _advance(0.2)
	_check(_worker.is_building() and _worker2.is_building(),
			"§36 os dois Workers podem construir o mesmo Ninho")
	var built := await _wait_until(func() -> bool: return _nest.state.is_completed(), 20.0)
	_check(built, "§42 o Ninho é concluído")
	await _advance(0.1)
	_check(_core_state.population_capacity_bonus == 4, "§42 o bônus de +4 foi aplicado")
	_check(_core_state.get_population_capacity() == NEST_CAPACITY, "§42/§83 capacidade virou 12")
	_check(_core_state.population == 2, "§25/§42 Population continua 2, agora sobre 12")
	_check(_text_of(_core_hud, "PopulationLabel") == "Population: 2 / 12",
			"§72/§42 o HUD mostra Population 2 / 12")
	_check(_core_state.essence >= essence_before - 0.001,
			"§42 construir o Ninho não gasta Essência")
	_check(_text_of(_nest_hud, "StatusLabel").contains("concluído"),
			"§42 o HUD de construção reporta o Ninho concluído")
	_check(_text_of(_ore_hud, "OreLabel") == "Minério de Ferro: 0",
			"§42 o HUD de recurso segue acompanhando o estoque")
	_check(not _worker.is_building() and not _worker2.is_building(),
			"§42 ao concluir, os dois liberam o alvo de construção")


func _test_systems_survive() -> void:
	var essence_before := _core_state.essence
	await _advance(1.5)
	_check(_core_state.essence > essence_before, "§32/§69 a Essência continua sendo gerada")
	_check(_core_state.population == 2, "§69 Population permanece 2")
	_check(_core_state.get_population_capacity() == NEST_CAPACITY,
			"§69 a capacidade permanece 12")
	_check(is_instance_valid(_worker) and is_instance_valid(_worker2),
			"§69 os dois Workers continuam válidos")
	var camera_before := (_scene.get_node("World/CameraRig") as Node3D).global_position
	Input.action_press("camera_forward")
	await _advance(0.6)
	Input.action_release("camera_forward")
	await _advance(0.1)
	var camera_after := (_scene.get_node("World/CameraRig") as Node3D).global_position
	_check(camera_before.distance_to(camera_after) > 0.5,
			"§69 a câmera continua funcionando (%f)" % camera_before.distance_to(camera_after))
	_click(MOUSE_BUTTON_LEFT, _worker.global_position)
	await _advance(0.05)
	var destination := Vector3(-6, 0, 2)
	_click(MOUSE_BUTTON_RIGHT, destination)
	await _advance(0.1)
	_check(_worker.has_move_target(), "§69 Worker001 ainda aceita movimento")
	var settled := await _wait_until(func() -> bool: return not _worker.has_move_target(), 25.0)
	_check(settled and _planar_gap(_worker.global_position, destination) <= ARRIVAL_TOLERANCE,
			"§69 o movimento RTS comum continua exato")
	_check(not _worker2.has_move_target() and _worker2.velocity == Vector3.ZERO,
			"§69 Worker002 não foi arrastado pela ordem de Worker001")
	_press_build_key()
	_press_summon_key()
	await _advance(0.2)
	_check(_workers_in_scene().size() == 2, "§69 spam de I e B não duplica nada")
	_check(_nests_in_scene().size() == 1, "continua exatamente 1 Ninho")
	_check(_core_state.population == 2, "§69 Population inalterada pelo spam de teclas")


func _test_scope_guards() -> void:
	var controller_source := _source_text(CONTROLLER_PATH)
	var hud_source := _source_text(HUD_PATH)
	var state_source := _source_text("res://core/state/core_state.gd")
	_check(not controller_source.contains("_process(")
			and not controller_source.contains("_physics_process"),
			"§80 o controller de invocação não roda nada por frame")
	_check(not hud_source.contains("_process(") and not hud_source.contains("_physics_process"),
			"§39 o HUD de invocação não pollinga por frame")
	_check(not controller_source.contains("get_first_node_in_group")
			and not controller_source.contains("get_nodes_in_group"),
			"§13 nenhuma dependência é procurada globalmente")
	_check(not hud_source.contains("get_nodes_in_group")
			and not hud_source.contains("find_children"),
			"§81 a população do HUD não vem de varredura da árvore")
	_check(state_source.contains("try_add_population")
			and state_source.contains("can_add_population"),
			"§5 a API atômica vive no CoreState")
	_check(not controller_source.contains("set_population"),
			"§7 o controller jamais clampa população para invocar")
	_check(controller_source.contains("consume_essence"),
			"§18 a cobrança usa a API existente consume_essence()")
	_check(not controller_source.contains("essence -=")
			and not controller_source.contains("essence ="),
			"§18 nenhuma manipulação direta de Essência")
	for path in [SELECTION_PATH, WORKER_RUNTIME_PATH, CAMERA_PATH, CONSTRUCTION_PATH,
			CONTROLLER_PATH, HUD_PATH]:
		_check(not _source_text(path).contains("worker_001")
				and not _source_text(path).contains("Worker001"),
				"§37 %s não trata Worker001 como condição" % path.get_file())
	_check(not controller_source.contains("randi") and not controller_source.contains("uuid"),
			"§14 sem UUID nem nome aleatório")
	_check(controller_source.contains("can_add_population"),
			"§83 a validação passa pela capacidade efetiva do CoreState")
	_check(not controller_source.contains("definition.population_capacity"),
			"§83 o controller nunca lê a capacidade base da Definition")
	_check(controller_source.contains("SUMMONED_UNIT_ID"),
			"§14 o id do segundo Worker é a constante worker_002")
	_check(_instance_fields(_invocation)
			== ["_core_state", "_definition", "_scene", "_dungeon_root", "_spawn_point",
					"_deposit", "_summoned_worker"],
			"§44 o controller guarda apenas o Worker invocado, sem roster global")
	for field in _instance_fields(_invocation):
		_check(not field.ends_with("_list") and not field.ends_with("_roster")
				and not field.ends_with("_registry") and not field.ends_with("_units"),
				"§44 %s não é uma coleção de unidades" % field)
	_check(_source_text("res://project.godot").contains("summon_worker="),
			"§11 a ação summon_worker existe no input map")
	_check(InputMap.has_action(&"summon_worker"), "§11 summon_worker está registrada no runtime")
	_check(InputMap.event_is_action(_summon_key_event(), &"summon_worker", false),
			"§11 a tecla I dispara a ação summon_worker")
	_check(not controller_source.contains("\"I\"") and not controller_source.contains("KEY_I"),
			"§11 nenhuma tecla física hardcoded no controller")
	# §10 da Tarefa 08 vetava camada extra por antecipação; a Tarefa 11 criou a camada
	# 6 = Enemies de verdade, então a contagem exata passa a ser 6 e nenhuma além dela.
	_check(_count_occurrences(_source_text("res://project.godot"), "3d_physics/layer_") == 6,
			"§10/§15 T11 exatamente a camada 6 Enemies foi adicionada")
	_check(String(ProjectSettings.get_setting("layer_names/3d_physics/layer_6")) == "Enemies",
			"§10/§15 T11 a camada 6 existe e se chama Enemies")
	_check(String(ProjectSettings.get_setting("layer_names/3d_physics/layer_7")).is_empty(),
			"§10 continua sem sétima camada")
	_check(_worker.collision_mask & UNIT_LAYER == 0
			and _worker2.collision_mask & UNIT_LAYER == 0,
			"§10 nenhum Worker colide com unidades: sem Unit vs Unit nesta tarefa")
	_check(_worker.collision_layer == UNIT_LAYER and _worker2.collision_layer == UNIT_LAYER,
			"§10 os dois Workers continuam na camada Units")
	_check(WorkerRuntime.ActionMode.size() == 6, "§12 nenhum modo de ação novo foi criado")
	_check(WorkerRuntime.ActionMode.IDLE == 0 and WorkerRuntime.ActionMode.BUILD == 5,
			"a enumeração de ActionMode continua a mesma")
	var autoloads: Dictionary = ProjectSettings.get_setting("autoload", {})
	_check(autoloads.is_empty(), "§12 nenhum autoload/singleton foi adicionado")
	var node_names: Array[String] = []
	for node in _scene.find_children("*", "*", true, false):
		node_names.append(String(node.name))
	for forbidden in ["PopulationManager", "UnitManager", "SpawnManager", "ArmyManager",
			"CreatureFactory", "UnitFactory", "UnitRegistry", "WorkerRoster",
			"PopulationRegistry", "DragSelection", "ControlGroup", "Formation",
			"NavigationAgent", "NavigationRegion", "SpawnEffect", "SummonQueue"]:
		_check(not node_names.has(forbidden), "§78 nenhum nó %s na cena" % forbidden)
	_check(_scene.find_children("*", "BaseButton", true, false).is_empty(),
			"§38 nenhum botão clicável foi introduzido")
	_check(_workers_in_scene().size() == 2, "§43 a cena termina com exatamente 2 Workers")
	for control in _controls_in_ui():
		_check(control.mouse_filter == Control.MOUSE_FILTER_IGNORE,
				"§75 %s usa mouse_filter IGNORE" % control.name)


# ------------------------------------------------------------------- Helpers


func _worker_definition() -> WorkerDefinition:
	return load(WORKER_DEFINITION_PATH) as WorkerDefinition


func _core_definition() -> CoreDefinition:
	return load(CORE_DEFINITION_PATH) as CoreDefinition


func _nest_definition() -> NestDefinition:
	return load(NEST_DEFINITION_PATH) as NestDefinition


func _iron_ore() -> ResourceDefinition:
	return load(IRON_ORE_PATH) as ResourceDefinition


func _check(condition: bool, label: String) -> void:
	_asserts += 1
	if condition:
		print("[PASS] %s" % label)
	else:
		_failures += 1
		print("[FAIL] %s" % label)


func _close(a: float, b: float, tolerance: float = 0.001) -> bool:
	return absf(a - b) <= tolerance


func _advance(seconds: float) -> void:
	var ticks := int(ceil(seconds * Engine.get_physics_ticks_per_second()))
	for i in ticks:
		await physics_frame


func _wait_until(condition: Callable, max_seconds: float) -> bool:
	var limit := int(max_seconds * Engine.get_physics_ticks_per_second())
	var guard := 0
	while not condition.call() and guard < limit:
		await physics_frame
		guard += 1
	return condition.call()


func _on_population_changed(current: int, capacity: int) -> void:
	_population_events.append("%d/%d" % [current, capacity])


func _script_fields(script_path: String) -> Array[String]:
	var fields: Array[String] = []
	for property in (load(script_path) as GDScript).new().get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			fields.append(String(property.name))
	return fields


func _instance_fields(instance: Object) -> Array[String]:
	var fields: Array[String] = []
	for property in instance.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			fields.append(String(property.name))
	return fields


func _workers_in_scene() -> Array[WorkerRuntime]:
	var workers: Array[WorkerRuntime] = []
	for child in _dungeon.get_children():
		if child is WorkerRuntime:
			workers.append(child as WorkerRuntime)
	return workers


func _rocks_in_scene() -> Array[RockRuntime]:
	var rocks: Array[RockRuntime] = []
	for child in _dungeon.get_children():
		if child is RockRuntime:
			rocks.append(child as RockRuntime)
	return rocks


func _nests_in_scene() -> Array[NestRuntime]:
	var nests: Array[NestRuntime] = []
	for child in _dungeon.get_children():
		if child is NestRuntime:
			nests.append(child as NestRuntime)
	return nests


func _controls_in_ui() -> Array[Control]:
	var controls: Array[Control] = []
	for control in (_scene.get_node("UI") as Node).find_children("*", "Control", true, false):
		controls.append(control as Control)
	return controls


func _indicator(worker: WorkerRuntime) -> MeshInstance3D:
	return worker.find_child("SelectionIndicator", true, false) as MeshInstance3D


func _selected_count() -> int:
	var count := 0
	for worker in _workers_in_scene():
		if _indicator(worker).visible:
			count += 1
	return count


func _essence_label_value() -> int:
	var parts := _text_of(_core_hud, "EssenceLabel").split(" ")
	if parts.size() < 2:
		return -1
	return int(parts[1])


func _text_of(root: Node, label_name: String) -> String:
	var label := root.find_child(label_name, true, false) as Label
	if label == null:
		return "<ausente>"
	return label.text


func _source_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func _count_occurrences(text: String, needle: String) -> int:
	var count := 0
	var index := text.find(needle)
	while index != -1:
		count += 1
		index = text.find(needle, index + needle.length())
	return count


func _planar_gap(from: Vector3, to: Vector3) -> float:
	var offset := to - from
	offset.y = 0.0
	return offset.length()


func _shape_clear_at(point: Vector3, radius: float, mask: int) -> bool:
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	var parameters := PhysicsShapeQueryParameters3D.new()
	parameters.shape = sphere
	parameters.transform = Transform3D(Basis.IDENTITY, Vector3(point.x, 0.8, point.z))
	parameters.collision_mask = mask
	return (_scene.get_viewport().world_3d.direct_space_state
			.intersect_shape(parameters, 8).is_empty())


func _ray_from_above(point: Vector3, mask: int) -> Dictionary:
	var origin := Vector3(point.x, 6.0, point.z)
	return (_scene.get_viewport().world_3d.direct_space_state
			.intersect_ray(PhysicsRayQueryParameters3D.create(origin, Vector3(point.x, 0.0, point.z), mask)))


func _segment_clear_of(from: Vector3, radius: float, to: Vector3,
		obstacle: Vector3, obstacle_radius: float) -> bool:
	var samples := 24
	for i in samples + 1:
		var point := from.lerp(to, float(i) / float(samples))
		if _planar_gap(obstacle, point) < radius + obstacle_radius:
			return false
	return true


func _click(button: int, world_position: Vector3) -> void:
	var screen_position := _camera.unproject_position(world_position)
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	event.position = screen_position
	event.global_position = screen_position
	root.push_input(event)


func _summon_key_event() -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_I
	event.pressed = true
	return event


func _press_summon_key() -> void:
	root.push_input(_summon_key_event())
	var released := InputEventKey.new()
	released.physical_keycode = KEY_I
	released.pressed = false
	root.push_input(released)


func _press_build_key() -> void:
	var pressed := InputEventKey.new()
	pressed.physical_keycode = KEY_B
	pressed.pressed = true
	root.push_input(pressed)
	var released := InputEventKey.new()
	released.physical_keycode = KEY_B
	released.pressed = false
	root.push_input(released)


func _wait_for_pile(max_seconds: float) -> ResourcePileRuntime:
	var limit := int(max_seconds * Engine.get_physics_ticks_per_second())
	var guard := 0
	while guard < limit:
		await physics_frame
		guard += 1
		for child in _dungeon.get_children():
			if child is ResourcePileRuntime:
				return child as ResourcePileRuntime
	return null


func _finish() -> void:
	print("---- worker invocation tests finished: %d asserts, %d failure(s) ----"
			% [_asserts, _failures])
	quit(1 if _failures > 0 else 0)
