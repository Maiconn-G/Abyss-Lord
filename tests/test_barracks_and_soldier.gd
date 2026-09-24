extends SceneTree

# Tarefa 10 — Quartel Abissal e primeiro Soldado Abissal.
# A suíte dirige o GameMain real: a tecla K paga Minério e abre o canteiro, dois
# Workers concluem a obra com física verdadeira, R recruta o Soldado com Essência
# controlada e o grupo misto (2 Workers + 1 Soldado) recebe ordens filtradas por
# capacidade. Termina com a campanha end-to-end completa de §100.

const MAIN_SCENE := preload("res://game/GameMain.tscn")
const SOLDIER_SCENE := preload("res://units/soldiers/SoldierRuntime.tscn")
const BARRACKS_SCENE := preload("res://world/dungeon/rooms/barracks/BarracksRuntime.tscn")
const PILE_SCENE := preload("res://world/resources/ResourcePileRuntime.tscn")

const BARRACKS_DEFINITION_PATH := "res://data/rooms/abyss_barracks.tres"
const SOLDIER_DEFINITION_PATH := "res://data/units/soldiers/abyss_soldier.tres"
const NEST_DEFINITION_PATH := "res://data/rooms/abyss_nest.tres"
const IRON_ORE_PATH := "res://data/resources/iron_ore.tres"
const ORE_ROCK_PATH := "res://data/environment/iron_ore_rock.tres"
const RECRUITMENT_SOURCE_PATH := "res://systems/population/soldier_recruitment_controller.gd"
const BARRACKS_RUNTIME_SOURCE_PATH := "res://world/dungeon/rooms/barracks/barracks_runtime.gd"
const SOLDIER_RUNTIME_SOURCE_PATH := "res://units/soldiers/soldier_runtime.gd"
const SELECTION_SOURCE_PATH := "res://systems/selection/selection_controller.gd"
const CONSTRUCTION_SOURCE_PATH := "res://systems/construction/construction_controller.gd"
const MILITARY_HUD_SOURCE_PATH := "res://ui/hud/military_debug_hud.gd"
const GAME_MAIN_SOURCE_PATH := "res://game/game_main.gd"
const WORKER_RUNTIME_SOURCE_PATH := "res://units/workers/worker_runtime.gd"

const GROUND_LAYER := 1
const UNIT_LAYER := 2
const DIGGABLE_LAYER := 4
const RESOURCE_LAYER := 8
const CONSTRUCTION_LAYER := 16
const OBSTACLES := DIGGABLE_LAYER | RESOURCE_LAYER | CONSTRUCTION_LAYER
const CLICKABLE := GROUND_LAYER | UNIT_LAYER | DIGGABLE_LAYER | RESOURCE_LAYER | CONSTRUCTION_LAYER

const FIRST_ORE_ROCK_ID := "iron_ore_001"
const SECOND_ORE_ROCK_ID := "iron_ore_002"
const COMMON_ROCK_ID := "rock_001"
const BARRACKS_POINT := Vector3(-10, 0, -5)
const SOLDIER_SPAWN := Vector3(-10, 0, -1.5)
const NEST_POINT := Vector3(-5, 0, -5)
const WORKER_SPAWN := Vector3(0, 0, 4)
const DEPOSIT_POINT := Vector3(-2, 0, 0)
const CORE_POINT := Vector3(0, 1, 0)
const GROUP_CENTER := Vector3(0, 0, 8)
const SPOT_NEAR := Vector3(0, 0, 2)
const SPOT_FAR := Vector3(0, 0, 12)
const SITE_LEFT := Vector3(7.5, 0, 3.0)
const SITE_RIGHT := Vector3(9.0, 0, 3.0)
const SOLDIER_PARK := Vector3(3, 0, 4)
const PILE_SPOT := Vector3(-2, 0, 4)
const PILE_LEFT := Vector3(-5, 0, 4)
const PILE_RIGHT := Vector3(1, 0, 4)
const CANCEL_SPOT := Vector3(-6, 0, 10)

const BARRACKS_HALF := 1.1
const SOLDIER_RADIUS := 0.42
const WORKER_RADIUS := 0.35
const ROCK_HALF := 1.0
const SPACING := 1.2
const ARRIVAL_TOLERANCE := 0.12
const WORK_TOLERANCE := 0.35
const ORE := &"iron_ore"
const BARRACKS_NAME := "Quartel Abissal"
const SOLDIER_NAME := "Soldado Abissal"
const NEST_NAME := "Ninho Abissal"
const RECRUIT_COST := 15.0
const BASE_CAPACITY := 8
const NEST_CAPACITY := 12
const BARRACKS_WORK := 6.0

var _failures := 0
var _asserts := 0
var _frames := 0
var _scene: Node
var _dungeon: Node3D
var _camera: Camera3D
var _selection: SelectionController
var _construction: ConstructionController
var _recruitment: SoldierRecruitmentController
var _invocation: WorkerInvocationController
var _deposit: ResourceDepositRuntime
var _core: CoreRuntime
var _core_state: CoreState
var _stockpile: ResourceStockpileState
var _military_hud: Node
var _core_hud: Node
var _ore_hud: Node
var _nest_hud: Node
var _worker: WorkerRuntime
var _worker2: WorkerRuntime
var _soldier: SoldierRuntime
var _barracks: BarracksRuntime
var _pile: ResourcePileRuntime
var _pile_before := 0
var _population_events: Array[String] = []
var _capacity_events: Array[String] = []
var _completions := 0
var _essence_reads: Array[float] = []
var _recruited: Array[String] = []


func _initialize() -> void:
	_run_all()


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > 200000:
		_check(false, "timeout: a suíte de Quartel e Soldado não terminou")
		_finish()
	return false


func _run_all() -> void:
	_test_input_actions()
	_test_barracks_definition()
	_test_barracks_state_initial()
	_test_barracks_apply_work()
	_test_barracks_completion_once()
	await _test_barracks_runtime_scene()
	_test_soldier_definition()
	_test_soldier_state_defaults()
	_test_soldier_health_api()
	_test_soldier_runtime_scene()
	_test_recruitment_controller_shape()
	await _boot_scene()
	await _test_layout()
	await _test_hud_before_anything()
	await _test_recruit_without_barracks()
	await _test_build_without_resources()
	await _test_build_with_three_ore()
	await _test_repeated_k()
	await _test_recruit_during_obra()
	await _test_workers_build_barracks()
	await _test_barracks_completed()
	await _test_recruit_essence_insufficient()
	await _test_recruit_capacity_full()
	await _test_recruit_valid()
	await _test_second_recruit_blocked()
	await _test_soldier_idle_at_spawn()
	await _test_individual_soldier_selection()
	await _test_shift_mixed_selection()
	await _test_box_selects_three()
	await _test_group_move_three()
	await _test_soldier_speed_is_fps_independent()
	await _test_mixed_group_excavation()
	await _test_mixed_group_construction()
	await _test_mixed_group_pile()
	await _test_mixed_group_ground()
	await _test_hud_after_cycle()
	await _test_systems_survive()
	_test_scope_guards()
	await _test_end_to_end_campaign()
	_finish()


# --------------------------------------------------------------- Testes estáticos


func _test_input_actions() -> void:
	_check(InputMap.has_action(&"build_barracks"), "§13 a ação build_barracks existe")
	_check(InputMap.has_action(&"recruit_soldier"), "§35 a ação recruit_soldier existe")
	var k := InputEventKey.new()
	k.physical_keycode = KEY_K
	_check(InputMap.event_is_action(k, &"build_barracks", false), "§13 K dispara build_barracks")
	var r := InputEventKey.new()
	r.physical_keycode = KEY_R
	_check(InputMap.event_is_action(r, &"recruit_soldier", false), "§35 R dispara recruit_soldier")
	for pair in [[KEY_A, &"camera_left"], [KEY_D, &"camera_right"],
			[KEY_W, &"camera_forward"], [KEY_S, &"camera_backward"]]:
		var wasd := InputEventKey.new()
		wasd.physical_keycode = pair[0]
		_check(not InputMap.event_is_action(wasd, &"build_barracks", false)
				and not InputMap.event_is_action(wasd, &"recruit_soldier", false),
				"§13 a tecla %s do WASD não foi reaproveitada" % pair[1])
	_check(not InputMap.event_is_action(k, &"build_nest", false)
			and not InputMap.event_is_action(k, &"summon_worker", false),
			"§13 K não se confunde com B nem com I")
	_check(not InputMap.event_is_action(r, &"summon_worker", false)
			and not InputMap.event_is_action(r, &"build_nest", false),
			"§35 R não se confunde com I nem com B")
	_check(_source("res://project.godot").contains("build_barracks="),
			"§13 build_barracks está no input map do projeto")
	_check(_source("res://project.godot").contains("recruit_soldier="),
			"§35 recruit_soldier está no input map do projeto")
	# A Tarefa 11 acrescentou a camada 6 = Enemies; nenhuma outra apareceu.
	_check(_count_occurrences(_source("res://project.godot"), "3d_physics/layer_") == 6,
			"§11/§15 T11 a única camada nova é a 6 Enemies")


func _test_barracks_definition() -> void:
	var definition := _barracks_definition()
	_check(definition is Resource, "§5 BarracksDefinition é Resource")
	_check(definition.resource_path == BARRACKS_DEFINITION_PATH, "§6 abyss_barracks.tres carrega")
	_check(definition.barracks_type_id == &"abyss_barracks", "§5 barracks_type_id abyss_barracks")
	_check(definition.display_name == BARRACKS_NAME, "§5 display_name Quartel Abissal")
	_check(definition.build_resource == _iron_ore(), "§2 o custo é Minério de Ferro")
	_check(definition.build_cost == 3, "§2 build_cost 3")
	_check(is_equal_approx(definition.work_required, BARRACKS_WORK),
			"§20 work_required 6.0, obtido %f" % definition.work_required)
	_check(definition.soldier_definition == _soldier_definition(),
			"§5 a Definition do Quartel aponta para a Definition do Soldado")
	var fields := _instance_fields(definition)
	for forbidden in ["training_speed", "upgrade_level", "maintenance",
			"garrison_capacity", "armor_bonus"]:
		_check(not fields.has(forbidden), "§5 campo antecipado ausente: %s" % forbidden)


func _test_barracks_state_initial() -> void:
	var state := BarracksState.new(_barracks_definition(), "barracks_001")
	_check(state.barracks_id == "barracks_001", "§7 barracks_id barracks_001")
	_check(is_equal_approx(state.remaining_work, BARRACKS_WORK),
			"§7 remaining_work começa em 6.0, obtido %f" % state.remaining_work)
	_check(not state.is_completed(), "§7 o canteiro nasce incompleto")
	_check(state.definition == _barracks_definition(), "§8 o State referencia a Definition")
	var fields := _instance_fields(state)
	_check(not fields.has("completed") and not fields.has("is_done"),
			"§8 nenhum boolean redundante de conclusão")
	_check(_has_signal(state, "work_changed") and _has_signal(state, "construction_completed"),
			"§8 work_changed e construction_completed existem")
	for forbidden in ["health", "population", "essence", "cargo"]:
		_check(not fields.has(forbidden), "§8 o State do Quartel não guarda %s" % forbidden)


func _test_barracks_apply_work() -> void:
	var state := BarracksState.new(_barracks_definition(), "barracks_001")
	var progress: Array[String] = []
	state.work_changed.connect(
			func(remaining: float, total: float) -> void:
				progress.append("%f/%f" % [remaining, total]))
	state.apply_work(1.0)
	_check(_close(state.remaining_work, 5.0), "§66 apply_work(1) leva 6.0 para 5.0")
	state.apply_work(0.0)
	_check(_close(state.remaining_work, 5.0), "§8 apply_work(0) não altera o progresso")
	state.apply_work(-2.0)
	_check(_close(state.remaining_work, 5.0), "§8 apply_work negativo não altera o progresso")
	_check(progress == ["5.000000/6.000000"],
			"§8 work_changed só em trabalho real, eventos %s" % [progress])
	state.apply_work(100.0)
	_check(_close(state.remaining_work, 0.0), "§66 apply_work(100) é clampado em 0")
	_check(state.is_completed(), "§7 is_completed quando o trabalho acaba")
	progress.clear()
	state.apply_work(1.0)
	_check(_close(state.remaining_work, 0.0) and progress.is_empty(),
			"§8 trabalho depois da conclusão não altera nem emite")


func _test_barracks_completion_once() -> void:
	var state := BarracksState.new(_barracks_definition(), "barracks_001")
	var emissions: Array[int] = []
	state.construction_completed.connect(func() -> void: emissions.append(1))
	state.apply_work(3.0)
	_check(emissions.is_empty(), "§67 meia obra ainda não concluiu")
	state.apply_work(3.0)
	_check(emissions.size() == 1, "§67/§8 a conclusão emite exatamente uma vez")
	state.apply_work(2.0)
	_check(emissions.size() == 1 and _close(state.remaining_work, 0.0),
			"§8 nenhuma conclusão extra depois do fato")


func _test_barracks_runtime_scene() -> void:
	var runtime := BARRACKS_SCENE.instantiate() as BarracksRuntime
	_check(runtime != null, "§9 BarracksRuntime.tscn instancia")
	_check(runtime.get_class() == "StaticBody3D", "§9 a raiz é StaticBody3D")
	_check(runtime.collision_layer == CONSTRUCTION_LAYER,
			"§11 o Quartel reutiliza a camada 5 Construction")
	_check(runtime.collision_mask == 0, "§9 o canteiro não empurra ninguém")
	for child_name in ["ConstructionVisual", "CompletedVisual", "CollisionShape3D"]:
		_check(runtime.find_child(child_name, true, false) != null,
				"§9 o Quartel tem %s" % child_name)
	root.add_child(runtime)
	await _advance(0.1)
	var construction := runtime.find_child("ConstructionVisual", true, false) as Node3D
	var completed := runtime.find_child("CompletedVisual", true, false) as Node3D
	_check(construction.visible and not completed.visible,
			"§10 a cena começa mostrando o canteiro")
	var collision := runtime.find_child("CollisionShape3D", true, false) as CollisionShape3D
	_check(collision != null and collision.shape is BoxShape3D,
			"§10 o collider do Quartel é uma BoxShape3D primitiva")
	runtime.setup(_barracks_definition(), BarracksState.new(_barracks_definition(), "probe"))
	_check(not runtime.is_completed(), "§9 setup mantém o canteiro incompleto")
	runtime.state.apply_work(BARRACKS_WORK)
	await _advance(0.1)
	_check(runtime.is_completed(), "§9 is_completed acompanha o State")
	_check(not construction.visible and completed.visible,
			"§21 o visual troca na conclusão")
	_check(_primitive_meshes_only(runtime), "§10 o Quartel usa apenas primitivas")
	runtime.free()


func _test_soldier_definition() -> void:
	var definition := _soldier_definition()
	_check(definition is Resource, "§23 SoldierDefinition é Resource")
	_check(definition.resource_path == SOLDIER_DEFINITION_PATH, "§24 abyss_soldier.tres carrega")
	_check(definition.unit_type_id == &"abyss_soldier", "§23 unit_type_id abyss_soldier")
	_check(definition.display_name == SOLDIER_NAME, "§23 display_name Soldado Abissal")
	_check(is_equal_approx(definition.max_health, 80.0), "§23 max_health 80")
	_check(is_equal_approx(definition.move_speed, 4.0), "§23 move_speed 4.0")
	_check(is_equal_approx(definition.recruit_essence_cost, RECRUIT_COST),
			"§23 recruit_essence_cost 15")
	var fields := _instance_fields(definition)
	for required in ["attack_damage", "attack_range", "attack_interval"]:
		_check(fields.has(required), "§3 T11 campo de combate presente: %s" % required)
	for forbidden in ["attack_speed", "armor", "defense", "agro_range",
			"critical_chance", "accuracy", "dodge"]:
		_check(not fields.has(forbidden), "§3 T11 campo de combate antecipado ausente: %s" % forbidden)


func _test_soldier_state_defaults() -> void:
	var state := SoldierState.new(_soldier_definition(), "soldier_001")
	_check(state.unit_id == "soldier_001", "§25 unit_id soldier_001")
	_check(is_equal_approx(state.health, 80.0), "§25 health começa em 80")
	_check(state.level == 1, "§25 level começa em 1")
	_check(is_equal_approx(state.experience, 0.0), "§25 experience começa em 0")
	_check(state.definition == _soldier_definition(), "§25 o State referencia a Definition")
	var fields := _instance_fields(state)
	for forbidden in ["kills", "combat_xp", "equipment", "morale", "injuries"]:
		_check(not fields.has(forbidden), "§25 campo antecipado ausente: %s" % forbidden)
	_check(_has_signal(state, "health_changed"), "§26 health_changed existe")


func _test_soldier_health_api() -> void:
	var state := SoldierState.new(_soldier_definition(), "soldier_001")
	var events: Array[String] = []
	state.health_changed.connect(
			func(current: float, maximum: float) -> void:
				events.append("%f/%f" % [current, maximum]))
	state.damage(10.0)
	_check(_close(state.health, 70.0), "§78 damage(10) leva 80 para 70")
	state.heal(5.0)
	_check(_close(state.health, 75.0), "§78 heal(5) leva 70 para 75")
	state.damage(-1.0)
	state.heal(0.0)
	_check(_close(state.health, 75.0), "§26 valores inválidos não alteram a vida")
	_check(events == ["70.000000/80.000000", "75.000000/80.000000"],
			"§26 health_changed só em mudança real, eventos %s" % [events])
	state.damage(1000.0)
	_check(_close(state.health, 0.0), "§26 clamp em 0")
	state.heal(1000.0)
	_check(_close(state.health, 80.0), "§26 clamp em max_health")
	_check(events.size() == 4, "§26 nenhuma emissão duplicada nos clamps")
	state.damage(0.0)
	_check(events.size() == 4, "§26 damage(0) não emite")


func _test_soldier_runtime_scene() -> void:
	var runtime := SOLDIER_SCENE.instantiate() as SoldierRuntime
	_check(runtime != null, "§28 SoldierRuntime.tscn instancia")
	_check(runtime.get_class() == "CharacterBody3D", "§28 a raiz é CharacterBody3D")
	for child_name in ["Visual", "CollisionShape3D", "SelectionIndicator"]:
		_check(runtime.find_child(child_name, true, false) != null,
				"§28 o Soldado tem %s" % child_name)
	_check(runtime.collision_layer == UNIT_LAYER, "§30 o Soldado usa a camada Units")
	_check(runtime.collision_mask & UNIT_LAYER == 0,
			"§30 o mask do Soldado não inclui a própria camada Units")
	_check(runtime.collision_mask == 21, "§30 o mask do Soldado é o mesmo do Worker (21)")
	_check(runtime.is_in_group(&"rts_selectable"),
			"§47 o Soldado já nasce no grupo rts_selectable")
	_check(runtime.find_child("NavigationAgent3D", true, false) == null,
			"§79 nenhuma criança de navegação na cena do Soldado")
	_check(_primitive_meshes_only(runtime), "§29 o Soldado usa apenas primitivas")
	var visual := runtime.find_child("Visual", true, false) as MeshInstance3D
	var color := _body_color(visual)
	_check(color != Color.MAGENTA, "§29 o Visual do Soldado tem material próprio")
	_check(color.r > color.g and color.r > color.b,
			"§29 a cor do Soldado é vermelha/carmesim, obtido %s" % color)
	_check(not color.is_equal_approx(_worker_visual_color()),
			"§29 a cor do Soldado difere da cor do Worker")
	var indicator := runtime.find_child("SelectionIndicator", true, false) as MeshInstance3D
	_check(not indicator.visible, "§87 o SelectionIndicator nasce escondido")
	_check(not _source(SOLDIER_RUNTIME_SOURCE_PATH).contains("NavigationAgent")
			and not _source(SOLDIER_RUNTIME_SOURCE_PATH).contains("avoidance"),
			"§102 o código do Soldado não fala com navegação nem avoidance")
	runtime.free()


func _test_recruitment_controller_shape() -> void:
	var controller := SoldierRecruitmentController.new()
	_check(controller.get_class() == "Node", "§36 o controller de recrutamento é um Node")
	_check(_has_signal(controller, "soldier_recruited"), "§61 soldier_recruited existe")
	_check(controller.soldier() == null, "§44 nenhum Soldado antes de recrutar")
	_check(controller.has_method("can_recruit"), "§39 o controller expõe can_recruit()")
	var source := _source(RECRUITMENT_SOURCE_PATH)
	_check(not source.contains("_process(") and not source.contains("_physics_process"),
			"§106 o controller de recrutamento não roda nada por frame")
	_check(not source.contains("get_first_node_in_group")
			and not source.contains("get_nodes_in_group"),
			"§37 nenhuma dependência é procurada globalmente")
	_check(source.contains("can_add_population") and source.contains("consume_essence"),
			"§40/§42 a transação usa as APIs atômicas de CoreState")
	_check(not source.contains("essence -=") and not source.contains("essence ="),
			"§40 nenhuma manipulação direta de Essência")
	_check(not source.contains("set_population"), "§45 o controller nunca clampa população")
	_check(not source.contains("15"), "§24/§40 nenhum custo numérico solto no controller")
	for forbidden in ["UnitFactory", "RecruitmentFactory", "CreatureFactory"]:
		_check(not source.contains(forbidden), "§103 nenhuma %s foi inventada" % forbidden)
	for manager in ["MilitaryManager", "ArmyManager", "UnitManager", "SoldierManager",
			"CombatManager", "UnitRegistry", "EventBus"]:
		_check(not _class_exists(manager), "§36/§102 nenhum %s criado" % manager)
	controller.free()


# ------------------------------------------------------------- Cena real: layout


func _boot_scene() -> void:
	_scene = MAIN_SCENE.instantiate()
	root.add_child(_scene)
	await _advance(0.2)
	_dungeon = _scene.get_node("World/DungeonRoot") as Node3D
	_camera = _scene.get_node("World/CameraRig/Camera3D") as Camera3D
	_selection = _scene.get_node("Systems/SelectionController") as SelectionController
	_construction = _scene.get_node("Systems/ConstructionController") as ConstructionController
	_recruitment = _scene.get_node("Systems/SoldierRecruitmentController") as SoldierRecruitmentController
	_invocation = _scene.get_node("Systems/WorkerInvocationController") as WorkerInvocationController
	_deposit = _scene.get_node("World/DungeonRoot/Deposit001") as ResourceDepositRuntime
	_core = _scene.get_node("World/DungeonRoot/MainCore") as CoreRuntime
	_worker = _scene.get_node("World/DungeonRoot/Worker001") as WorkerRuntime
	_military_hud = _scene.get_node("UI/MilitaryDebugPanel")
	_core_hud = _scene.get_node("UI/CoreDebugPanel")
	_ore_hud = _scene.get_node("UI/ResourceDebugPanel")
	_nest_hud = _scene.get_node("UI/ConstructionDebugPanel")
	_stockpile = _deposit.stockpile
	_core_state = _core.core_state()
	_core.set_process(false)
	_populate_events()


func _populate_events() -> void:
	_core_state.population_changed.connect(
			func(current: int, capacity: int) -> void:
				_population_events.append("%d/%d" % [current, capacity]))
	_core_state.population_capacity_changed.connect(
			func(current: int, capacity: int) -> void:
				_capacity_events.append("%d/%d" % [current, capacity]))
	_core_state.essence_changed.connect(
			func(current: float, _maximum: float) -> void: _essence_reads.append(current))
	_construction.barracks_completed.connect(
			func(_b: BarracksRuntime) -> void: _completions += 1)
	_recruitment.soldier_recruited.connect(
			func(soldier: SoldierRuntime) -> void: _recruited.append(soldier.get_unit_id()))


func _test_layout() -> void:
	_check(_workers_in_scene().size() == 1, "a cena real começa com um Worker")
	_check(_rocks_in_scene().size() == 5, "§3 a cena tem exatamente 5 rochas, não 4")
	var first := _rock_with_id(FIRST_ORE_ROCK_ID)
	var second := _rock_with_id(SECOND_ORE_ROCK_ID)
	_check(first != null and second != null, "§63 as duas rochas de minério existem")
	_check(first.definition == second.definition, "§63/§3 as duas rochas compartilham a Definition")
	_check(first.definition == load(ORE_ROCK_PATH),
			"§63/§3 a Definition compartilhada é iron_ore_rock.tres")
	_check(first.rock_id != second.rock_id, "§63 os IDs das rochas são distintos")
	_check(second.rock_id == SECOND_ORE_ROCK_ID, "§3 a segunda rocha é iron_ore_002")
	_check(_count_files("res://data/environment", "*.tres") == 2,
			"§3 nenhuma segunda Definition de rocha foi criada")
	_check(is_equal_approx(first.definition.work_required, second.definition.work_required)
			and first.definition.yield_amount == 3,
			"§3 a segunda rocha exige e rende o mesmo que a primeira")
	_check(second.global_position.is_equal_approx(Vector3(-12, 1, 2)),
			"§4 IronOreRock002 em (-12, 1, 2)")
	_check(_planar_gap(second.global_position, first.global_position) > 2.2,
			"§4 as duas rochas de minério não se tocam")
	var build_point := _dungeon.get_node("BarracksBuildPoint") as Node3D
	_check(build_point.get_class() == "Marker3D", "§12 BarracksBuildPoint é um Marker3D")
	_check(build_point.get_children().is_empty(), "§12 o canteiro não traz coliders próprios")
	_check(build_point.global_position.is_equal_approx(BARRACKS_POINT),
			"§12 BarracksBuildPoint em (-10, 0, -5)")
	var soldier_point := _dungeon.get_node("SoldierSpawnPoint") as Node3D
	_check(soldier_point.get_class() == "Marker3D", "§34 SoldierSpawnPoint é um Marker3D")
	_check(soldier_point.get_children().is_empty(), "§34 o spawn do Soldado não tem collider")
	_check(soldier_point.global_position.is_equal_approx(SOLDIER_SPAWN),
			"§34 SoldierSpawnPoint em (-10, 0, -1.5), junto do Quartel")
	_check(_planar_gap(SOLDIER_SPAWN, BARRACKS_POINT) > BARRACKS_HALF + SOLDIER_RADIUS,
			"§34 o spawn fica fora do footprint do Quartel")
	_check(_planar_gap(BARRACKS_POINT, SOLDIER_SPAWN) > 3.0,
			"§12 canteiro e spawn do Soldado têm separação clara")
	_check(_shape_clear_at(BARRACKS_POINT, BARRACKS_HALF + 0.4, OBSTACLES),
			"§12 nenhuma forma física sólida ocupa o BarracksBuildPoint")
	_check(_shape_clear_at(SOLDIER_SPAWN, SOLDIER_RADIUS + 0.4, OBSTACLES),
			"§34 nenhuma forma física sólida ocupa o SoldierSpawnPoint")
	_check(_ground_body_at(BARRACKS_POINT) == "TestFloorBody",
			"§12 o ray vertical do canteiro cai no chão")
	_check(_ground_body_at(SOLDIER_SPAWN) == "TestFloorBody",
			"§34 o ray vertical do spawn do Soldado cai no chão")
	for anchor in [BARRACKS_POINT, SOLDIER_SPAWN]:
		_check(_planar_gap(anchor, NEST_POINT) > 2.5,
				"§4/§12 %s longe do NestBuildPoint" % _name_of(anchor))
		_check(_planar_gap(anchor, WORKER_SPAWN) > 2.5,
				"§4/§34 %s longe do WorkerSpawnPoint" % _name_of(anchor))
		_check(_planar_gap(anchor, DEPOSIT_POINT) > 2.5,
				"§4/§34 %s longe do depósito" % _name_of(anchor))
		_check(_planar_gap(anchor, CORE_POINT) > 2.5,
				"§4/§34 %s longe do Núcleo" % _name_of(anchor))
		for rock in _rocks_in_scene():
			_check(_planar_gap(anchor, rock.global_position) > ROCK_HALF + 1.2,
					"§4 %s longe de %s" % [_name_of(anchor), rock.rock_id])
	_check(_straight_route_clear(second.global_position, DEPOSIT_POINT, SECOND_ORE_ROCK_ID),
			"§4 a rota reta da segunda rocha até o depósito é livre de rochas")
	_check(_straight_route_clear(BARRACKS_POINT, DEPOSIT_POINT, ""),
			"§12 a rota reta do depósito até o canteiro é livre de rochas")
	_check(_route_clear_of_sites(second.global_position, DEPOSIT_POINT),
			"§4 nenhum canteiro bloqueia a rota da segunda rocha")
	_check(_route_clear_of_sites(BARRACKS_POINT, DEPOSIT_POINT),
			"§12 nenhum canteiro bloqueia a rota do canteiro do Quartel")
	for point in [BARRACKS_POINT, SOLDIER_SPAWN, Vector3(second.global_position.x, 0,
			second.global_position.z)]:
		_check(Rect2(Vector2.ZERO, Vector2(root.size)).has_point(_screen(point)),
				"§12/§34 %s está dentro do campo da câmera" % _name_of(point))
	_check(_barracks_in_scene().is_empty() and _nests_in_scene().is_empty(),
			"a cena começa sem Ninho nem Quartel")
	_check(_stockpile.get_amount(ORE) == 0, "o estoque começa vazio")
	_check(_soldier_in_scene() == null, "§44 a cena começa sem Soldado")
	_check(_core_state.population == 1, "§41 Population começa em 1")
	_check(_core_state.get_population_capacity() == BASE_CAPACITY,
			"§22 a capacidade base é 8 antes de qualquer prédio")
	_check(_worker.is_in_group(&"rts_selectable"),
			"§47 o Worker pertence ao grupo rts_selectable")
	_check(_selection.unit_container == _dungeon, "§15 a seleção continua apontando ao DungeonRoot")


func _test_hud_before_anything() -> void:
	_check(_military_hud is Control, "§59 MilitaryDebugHud é um Control")
	_check((_military_hud as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"§60 o painel militar usa mouse_filter IGNORE")
	_check(_controls_not_ignoring(_scene.get_node("UI")).is_empty(),
			"§60 nenhum controle do HUD captura o mouse")
	_check(_text_of(_military_hud, "BarracksHintLabel")
			== "[K] Construir %s — 3 Minério de Ferro" % BARRACKS_NAME,
			"§59 HUD mostra o atalho K com o custo vindo da Definition")
	_check(_text_of(_military_hud, "BarracksStatusLabel")
			== "%s: recursos insuficientes" % BARRACKS_NAME,
			"§59 com estoque 0 o HUD diz recursos insuficientes")
	_check(_text_of(_military_hud, "RecruitHintLabel")
			== "[R] Recrutar %s — %s necessário" % [SOLDIER_NAME, BARRACKS_NAME],
			"§59 sem Quartel a dica de recruta pede o prédio")
	_check(_text_of(_military_hud, "RecruitStatusLabel") == "Recrutamento: bloqueado",
			"§59 o recrutamento começa bloqueado")
	_check(_text_of(_core_hud, "PopulationLabel") == "Population: 1 / 8",
			"§41 o HUD do núcleo começa em 1 / 8")


func _test_recruit_without_barracks() -> void:
	_set_essence(50.0)
	_population_events.clear()
	_essence_reads.clear()
	_recruited.clear()
	await _advance(0.05)
	_check(_core_state.essence >= RECRUIT_COST and _core_state.can_add_population(1),
			"§80 Essência 50 e capacidade livre estão disponíveis")
	_check(_construction.barracks() == null, "§80 nenhum Quartel existe")
	_press_key(KEY_R)
	await _advance(0.2)
	_check(_soldier_in_scene() == null, "§80 R sem Quartel não cria Soldado")
	_check(_recruitment.soldier() == null, "§80 o controller não registrou unidade")
	_check(_close(_core_state.essence, 50.0), "§80 nenhuma Essência foi gasta")
	_check(_core_state.population == 1, "§80 Population intacta")
	_check(_population_events.is_empty(), "§80 nenhum sinal de população na recusa")
	_check(_recruited.is_empty(), "§61 soldier_recruited não disparou")
	_check(not _recruitment.can_recruit(), "§39 can_recruit() é false sem Quartel")


func _test_build_without_resources() -> void:
	_stockpile.add_resource(_iron_ore(), 2)
	await _advance(0.05)
	_check(_stockpile.get_amount(ORE) == 2, "o estoque tem 2 Minério")
	_check(_text_of(_military_hud, "BarracksStatusLabel")
			== "%s: recursos insuficientes" % BARRACKS_NAME,
			"§59 com 2 de 3 o HUD ainda diz recursos insuficientes")
	_press_key(KEY_K)
	await _advance(0.2)
	_check(_barracks_in_scene().is_empty(), "§70 K com 2 Minério não cria o Quartel")
	_check(_stockpile.get_amount(ORE) == 2, "§70 o estoque continua 2 na recusa")
	_check(_construction.barracks() == null, "§70 o controller não registrou canteiro")
	_check(_nests_in_scene().is_empty(), "§70 nenhuma outra obra nasceu da recusa")


func _test_build_with_three_ore() -> void:
	_stockpile.add_resource(_iron_ore(), 1)
	await _advance(0.05)
	_check(_text_of(_military_hud, "BarracksStatusLabel")
			== "%s: pronto para construir" % BARRACKS_NAME,
			"§59 com 3 Minério o HUD libera a obra")
	_press_key(KEY_K)
	await _advance(0.2)
	var built := _barracks_in_scene()
	_check(built.size() == 1, "§71 K com 3 Minério cria exatamente 1 canteiro")
	if built.is_empty():
		_check(false, "§71 sem canteiro os testes de obra não podem continuar")
		_finish()
		return
	_barracks = built[0]
	_check(_stockpile.get_amount(ORE) == 0, "§71 o estoque cai para 0")
	_check(_barracks.global_position.is_equal_approx(BARRACKS_POINT),
			"§12 o Quartel nasceu no BarracksBuildPoint")
	_check(_barracks.state.barracks_id == "barracks_001", "§7 a instância é barracks_001")
	_check(_barracks.state.definition == _barracks_definition(),
			"§6 o State veio da Definition, sem número hardcoded no Runtime")
	_check(_barracks.get_parent() == _dungeon, "§9 o Quartel entrou no DungeonRoot")
	_check(is_equal_approx(_barracks.state.remaining_work, BARRACKS_WORK),
			"§20 o canteiro exige 6.0 de trabalho")
	_check(_barracks.definition == _barracks_definition(),
			"§6 o Runtime referencia a mesma Definition compartilhada")
	_completions = 0
	_essence_reads.clear()


func _test_repeated_k() -> void:
	_press_key(KEY_K)
	_press_key(KEY_K)
	await _advance(0.2)
	_check(_barracks_in_scene().size() == 1, "§72/§17 K repetido não cria um segundo Quartel")
	_check(_stockpile.get_amount(ORE) == 0, "§17 nenhuma cobrança extra em K repetido")
	_check(not _recruitment.can_recruit(), "§18 mesmo com K repetido não se pode recrutar")


func _test_recruit_during_obra() -> void:
	_set_essence(50.0)
	_essence_reads.clear()
	await _advance(0.05)
	_check(_barracks != null and not _barracks.is_completed(), "a obra ainda está de pé")
	_check(_core_state.essence >= RECRUIT_COST and _core_state.can_add_population(1),
			"§81 Essência e capacidade não faltam neste momento")
	_check(not _recruitment.barracks_completed(), "§39 canteiro não conta como Quartel")
	_check(_barracks.state.remaining_work > 0.0, "§39 remaining_work ainda é positivo")
	var essence_before := _core_state.essence
	_press_key(KEY_R)
	await _advance(0.2)
	_check(_soldier_in_scene() == null, "§81/§39 R durante a obra não recruta")
	_check(_close(_core_state.essence, essence_before), "§39 nenhuma cobrança durante a obra")
	_check(_core_state.population == 1, "§39 Population intacta durante a obra")
	_check(_text_of(_military_hud, "BarracksStatusLabel")
			== "%s: em construção" % BARRACKS_NAME, "§59 HUD mostra a obra em andamento")


func _test_workers_build_barracks() -> void:
	_invoke_second_worker()
	await _advance(0.4)
	_worker2 = _invocation.summoned_worker()
	_check(_worker2 != null and _workers_in_scene().size() == 2, "I invocou o segundo Worker")
	_check(_core_state.population == 2, "§41 Population é 2 antes de recrutar")
	_place(_worker, SITE_LEFT)
	_place(_worker2, SITE_RIGHT)
	_essence_reads.clear()
	await _advance(0.1)
	_selection.clear_selection()
	await _click_select(_worker)
	await _shift_click_select(_worker2)
	_check(_selection.selected_units.size() == 2, "os dois Workers estão selecionados")
	var hit := _screen_hit(_screen(BARRACKS_POINT), CLICKABLE)
	_check(not hit.is_empty() and hit.collider == _barracks,
			"§19 o raycast reconhece o Quartel pela camada Construction")
	_right_click(BARRACKS_POINT)
	await _advance(0.1)
	_check(_worker.is_building() and _worker2.is_building(),
			"§73/§19 os dois Workers constroem o mesmo Quartel")
	_check(_worker.current_construction_target() == _barracks
			and _worker2.current_construction_target() == _barracks,
			"§14 o alvo de construção dos dois é o Quartel, sem branch por nome")
	var in_range := await _wait_until(func() -> bool:
		return _in_build_range(_worker) and _in_build_range(_worker2), 10.0)
	_check(in_range, "§20 os dois Workers entraram em build_range do Quartel")
	await _wait_until(func() -> bool:
		return _worker.velocity == Vector3.ZERO and _worker2.velocity == Vector3.ZERO, 5.0)
	_check(_worker.velocity == Vector3.ZERO and _worker2.velocity == Vector3.ZERO,
			"§20 os dois pararam ao lado do canteiro antes de trabalhar")
	_check(not _construction_touches_unit(_worker) and not _construction_touches_unit(_worker2),
			"§23 nenhum Worker ficou preso dentro do collider do Quartel")


func _test_barracks_completed() -> void:
	var before := _barracks.state.remaining_work
	var elapsed := await _time_until(func() -> bool: return _barracks.is_completed(), 20.0)
	var applied := before - _barracks.state.remaining_work
	_check(_barracks.is_completed(), "§20 o Quartel foi concluído pelo trabalho conjunto")
	_check(_close(before, BARRACKS_WORK, 0.05),
			"§20 a medição de trabalho puro partiu de 6.0, obtido %f" % before)
	_check(absf(applied - BARRACKS_WORK) <= WORK_TOLERANCE,
			"§74 o trabalho total aplicado é 6.0, obtido %f" % applied)
	_check(absf(elapsed - 3.0) <= WORK_TOLERANCE,
			"§74/§20 dois Workers concluem 6.0 em ~3 s, obtido %f s" % elapsed)
	_check(_completions == 1, "§67 a conclusão chegou exatamente uma vez na cena real")
	_check(_essence_reads.is_empty(), "§21 nenhuma cobrança de Essência ao concluir")
	_check(_capacity_events.is_empty(), "§22 o Quartel não mexeu na capacidade")
	_check(_core_state.get_population_capacity() == BASE_CAPACITY,
			"§75 a capacidade continua 8 depois de concluir")
	_check(_core_state.population_capacity_bonus == 0,
			"§22 nenhum population_capacity_bonus veio do Quartel")
	_check(_text_of(_core_hud, "PopulationLabel") == "Population: 2 / 8",
			"§75 o HUD do núcleo continua 2 / 8")
	var construction := _barracks.find_child("ConstructionVisual", true, false) as Node3D
	var completed := _barracks.find_child("CompletedVisual", true, false) as Node3D
	_check(not construction.visible and completed.visible, "§21 o visual do Quartel mudou")
	_check(is_instance_valid(_barracks) and _barracks.get_parent() == _dungeon,
			"§21 o prédio concluído continua na cena")
	_check(_barracks.collision_layer == CONSTRUCTION_LAYER,
			"§11 o prédio concluído permanece na camada Construction")
	_selection.clear_selection()
	await _click_select(_worker)
	_right_click(BARRACKS_POINT)
	await _advance(0.15)
	_check(not _worker.is_building(), "§21 o Quartel concluído recusa nova ordem BUILD")
	_check(_worker.current_construction_target() == null,
			"§21 o Worker não ficou preso num alvo concluído")
	_check(_barracks.state.remaining_work == 0.0, "§21 o trabalho não recomeça")


func _test_recruit_essence_insufficient() -> void:
	_check(_recruitment.barracks_completed(), "o pré-requisito do teste é o Quartel concluído")
	_set_essence(14.0)
	_population_events.clear()
	_recruited.clear()
	await _advance(0.05)
	_check(_close(_core_state.essence, 14.0), "§82 Essência exatamente 14 antes de R")
	_check(not _recruitment.can_recruit(), "§43 Essência 14 bloqueia o recrutamento")
	_press_key(KEY_R)
	await _advance(0.2)
	_check(_soldier_in_scene() == null, "§82 nenhum Soldado com Essência 14")
	_check(_close(_core_state.essence, 14.0), "§82/§43 Essência continua 14")
	_check(_core_state.population == 2, "§43 Population intacta")
	_check(_recruitment.soldier() == null, "§43 o controller não registrou nada")
	_check(_recruited.is_empty(), "§61 nenhum sinal de recruta")
	_check(_text_of(_military_hud, "RecruitStatusLabel")
			== "Recrutamento: essência insuficiente", "§59 HUD mostra essência insuficiente")


func _test_recruit_capacity_full() -> void:
	_set_essence(50.0)
	_core_state.set_population(BASE_CAPACITY)
	_population_events.clear()
	await _advance(0.05)
	_check(_core_state.essence >= RECRUIT_COST, "§83 Essência sobrando no teste de capacidade")
	_check(not _core_state.can_add_population(1), "§83 8/8 não tem espaço")
	_check(not _recruitment.can_recruit(), "§42 can_recruit respeita a capacidade cheia")
	_press_key(KEY_R)
	await _advance(0.2)
	_check(_soldier_in_scene() == null, "§83 nenhum Soldado acima da capacidade")
	_check(_close(_core_state.essence, 50.0), "§83/§42 Essência intacta na recusa")
	_check(_core_state.population == BASE_CAPACITY, "§42 Population continua 8")
	_check(_text_of(_military_hud, "RecruitStatusLabel")
			== "Recrutamento: capacidade cheia", "§59 HUD mostra capacidade cheia")
	_check(not _source(RECRUITMENT_SOURCE_PATH).contains("population_capacity"),
			"§42 o controller nunca lê CoreDefinition.population_capacity")
	_core_state.set_population(2)
	await _advance(0.05)


func _test_recruit_valid() -> void:
	_set_essence(20.0)
	_population_events.clear()
	_essence_reads.clear()
	_recruited.clear()
	await _advance(0.05)
	_check(_recruitment.can_recruit(), "§84 todas as condições de recrutamento passaram")
	_press_key(KEY_R)
	await _advance(0.2)
	_soldier = _recruitment.soldier()
	_check(_soldier != null, "§84 Soldier001 foi criado pela tecla real R")
	if _soldier == null:
		_finish()
		return
	_check(_soldier_in_scene() == _soldier, "§84 o Soldado está no DungeonRoot")
	_check(_soldier.get_parent() == _dungeon, "§37 o pai injetado é o DungeonRoot")
	_check(_soldier.state.unit_id == "soldier_001", "§25 o primeiro Soldado é soldier_001")
	_check(_soldier.definition == _soldier_definition(), "§24 o Soldado usa a Definition única")
	_check(_close(_core_state.essence, 5.0),
			"§84 Essência 20 -> 5 exato, obtido %f" % _core_state.essence)
	_check(_essence_reads == [5.0], "§45 a Essência é debitada uma única vez, direto para 5")
	_check(_core_state.population == 3, "§84/§41 Population 2 -> 3")
	_check(_population_events == ["3/8"],
			"§88 population_changed emitiu exatamente 3/8, eventos %s" % [_population_events])
	_check(_recruited == ["soldier_001"], "§61 soldier_recruited levou a unidade recrutada")
	_check(_soldier.global_position.is_equal_approx(SOLDIER_SPAWN),
			"§34 o Soldado nasceu no SoldierSpawnPoint, junto do Quartel")
	_check(_text_of(_core_hud, "PopulationLabel") == "Population: 3 / 8",
			"§88 o HUD do núcleo acompanhou o recruta")
	_check(_soldier.scene_file_path == "res://units/soldiers/SoldierRuntime.tscn",
			"§28 o recruta reutiliza a cena única do Soldado")


func _test_second_recruit_blocked() -> void:
	_set_essence(50.0)
	_population_events.clear()
	_recruited.clear()
	await _advance(0.05)
	_check(not _recruitment.can_recruit(), "§44 can_recruit é false com um Soldado existente")
	_press_key(KEY_R)
	await _advance(0.2)
	_check(_soldiers_in_scene().size() == 1, "§44 R de novo não cria soldier_002")
	_check(_soldiers_in_scene()[0] == _soldier, "§44 o Soldado da cena continua o mesmo")
	_check(_close(_core_state.essence, 50.0), "§44 nenhuma cobrança extra no segundo R")
	_check(_core_state.population == 3, "§44 Population continua 3")
	_check(_population_events.is_empty(), "§45 nenhuma população alterada sem Soldado novo")
	_check(_recruited.is_empty(), "§61 nenhum sinal de recruta duplicado")
	_set_essence(5.0)
	await _advance(0.05)


func _test_soldier_idle_at_spawn() -> void:
	await _advance(0.3)
	_check(_soldier.velocity == Vector3.ZERO, "§87 o Soldado nasce parado")
	_check(not _soldier.has_move_target(), "§87 o Soldado nasce sem alvo de movimento")
	_check(not _indicator(_soldier).visible, "§87 o SelectionIndicator do Soldado está escondido")
	_check(not _soldier.is_physics_processing(), "§106 o Soldado parado nem roda física")
	_check(_close(_soldier.state.health, 80.0), "§26 o Soldado recrutado nasce com 80 de vida")
	_check(_soldier.state.level == 1 and is_equal_approx(_soldier.state.experience, 0.0),
			"§25 o nível e a experiência iniciais do Soldado recrutado")
	# Tarefa 11 §23 deu ao Soldado uma máquina de ações própria, mas só de combate:
	# as quatro ações de trabalho do Worker continuam ausentes.
	_check(_soldier.action_mode() == SoldierRuntime.ActionMode.IDLE
			and SoldierRuntime.ActionMode.size() == 3,
			"§23 T11 o Soldado tem a máquina de ações IDLE/MOVE/ATTACK")
	for work_method in ["assign_excavation_target", "collect_resource_pile",
			"assign_construction_target"]:
		_check(not _soldier.has_method(work_method),
				"§33 a API de trabalho %s não existe no Soldado" % work_method)


func _test_individual_soldier_selection() -> void:
	_selection.clear_selection()
	await _advance(0.05)
	await _click_select(_soldier)
	_check(_selection.selected_units.size() == 1, "§89 LMB no Soldado seleciona exatamente 1")
	_check(_selection.selected_unit == _soldier, "§89 selected_unit é o Soldier001")
	_check(_selection.selected_unit == _selection.selected_units[0],
			"§48 selected_unit continua sendo selected_units[0]")
	_check(_indicator(_soldier).visible, "§89 o indicador do Soldado apareceu")
	_check(_visible_indicators() == 1, "§89 nenhum outro indicador ficou aceso")
	await _click_select(_worker)
	_check(_selection.selected_units.size() == 1
			and _selection.selected_units[0] == _worker,
			"§48 clicar no Worker substitui o Soldado")
	_check(not _indicator(_soldier).visible, "§48 o Soldado perdeu o indicador")


func _test_shift_mixed_selection() -> void:
	await _park_three()
	_selection.clear_selection()
	await _advance(0.05)
	await _click_select(_worker)
	await _shift_click_select(_worker2)
	await _shift_click_select(_soldier)
	_check(_selection.selected_units.size() == 3, "§90 Shift acumula Worker, Worker e Soldado")
	_check(_unit_ids() == ["worker_001", "worker_002", "soldier_001"],
			"§90 a ordem de Shift é a ordem dos cliques, obtido %s" % [_unit_ids()])
	_check(_visible_indicators() == 3, "§90 os três indicadores estão acesos")
	await _shift_click_select(_soldier)
	_check(_selection.selected_units.size() == 2
			and not _selection.selected_units.has(_soldier),
			"§90 Shift no Soldado selecionado o remove do grupo")
	await _shift_click_select(_soldier)
	_check(_selection.selected_units.size() == 3, "§90 Shift readiciona o Soldado")


func _test_box_selects_three() -> void:
	await _park_three()
	_selection.clear_selection()
	await _drag_over_three()
	_check(_selection.selected_units.size() == 3, "§91 a caixa seleciona os três")
	_check(_unit_ids() == ["soldier_001", "worker_001", "worker_002"],
			"§51 a caixa ordena por unit_id de forma determinística, obtido %s" % [_unit_ids()])
	_check(_selection.selected_units[0] is SoldierRuntime,
			"§91 selected_units não é mais uma lista só de Workers")
	_check(_visible_indicators() == 3, "§91 os três indicadores acenderam pela caixa")
	_check(not (_selection.selected_unit is WorkerRuntime),
			"§91 a primeira unidade da seleção ordenada é o Soldado")


func _test_group_move_three() -> void:
	await _park_three()
	_selection.clear_selection()
	await _drag_over_three()
	_check(_selection.selected_units.size() == 3, "a caixa pegou os três de novo")
	var order := _unit_ids()
	_right_click(GROUP_CENTER)
	await _advance(0.05)
	_check(_worker.has_move_target() and _soldier.has_move_target(),
			"§57/§92 Workers e Soldado receberam ordem de movimento")
	var settled := await _wait_until(func() -> bool:
		return not _worker.has_move_target() and not _worker2.has_move_target() \
				and not _soldier.has_move_target(), 15.0)
	_check(settled, "§92 as três unidades chegaram e pararam")
	var targets := _expected_line(order)
	_check(_close_planar(_soldier.global_position, targets["soldier_001"]),
			"§53 o Soldado foi para o offset determinístico da posição %d"
					% order.find("soldier_001"))
	_check(_close_planar(_worker.global_position, targets["worker_001"]),
			"§53 Worker001 ficou no centro da linha")
	_check(_close_planar(_worker2.global_position, targets["worker_002"]),
			"§53 Worker002 ficou no outro extremo da linha")
	_check(absf(_planar_gap(_worker.global_position, _soldier.global_position) - SPACING)
			<= ARRIVAL_TOLERANCE, "§92 vizinhos a ~1.2 de distância")
	_check(absf(_planar_gap(_worker2.global_position, _worker.global_position) - SPACING)
			<= ARRIVAL_TOLERANCE, "§92 a outra vizinhança também está a ~1.2")
	_check(_planar_gap(_soldier.global_position, _worker2.global_position) > SPACING * 1.9,
			"§53 nenhuma unidade terminou sobreposta")


func _test_soldier_speed_is_fps_independent() -> void:
	var distance := _planar_gap(SPOT_NEAR, SPOT_FAR)
	_place(_soldier, SPOT_NEAR)
	await _advance(0.1)
	_soldier.move_to(SPOT_FAR)
	var first := await _time_until(func() -> bool: return not _soldier.has_move_target(), 10.0)
	var speed_60 := distance / first
	_check(absf(speed_60 - 4.0) < 0.2,
			"§93 o Soldado anda a ~4.0 u/s a 60 Hz, obtido %f" % speed_60)
	Engine.set_physics_ticks_per_second(120)
	await _advance(0.1)
	_place(_soldier, SPOT_NEAR)
	await _advance(0.1)
	_soldier.move_to(SPOT_FAR)
	var second := await _time_until(func() -> bool: return not _soldier.has_move_target(), 10.0)
	Engine.set_physics_ticks_per_second(60)
	await _advance(0.1)
	var speed_120 := distance / second
	_check(absf(speed_120 - 4.0) < 0.2,
			"§93 a 120 Hz a velocidade continua ~4.0 u/s, obtido %f" % speed_120)
	_check(absf(first - second) < 0.1,
			"§93 o tempo de jornada independe do FPS (%f vs %f)" % [first, second])
	_check(_soldier.global_position.is_equal_approx(SPOT_FAR),
			"§32 o Soldado parou exatamente no alvo, sem overshoot nem oscilação")
	_check(_soldier.velocity == Vector3.ZERO and not _soldier.is_physics_processing(),
			"§32 ao chegar o Soldado zera a velocidade e desliga a própria física")


func _test_mixed_group_excavation() -> void:
	var rock := _rock_with_id(COMMON_ROCK_ID)
	_check(rock != null, "a rocha comum do teste existe")
	_place(_worker, SITE_LEFT)
	_place(_worker2, SITE_RIGHT)
	_place(_soldier, SOLDIER_PARK)
	await _advance(0.1)
	await _select_three()
	var soldier_spot := _soldier.global_position
	_right_click(rock.global_position)
	await _advance(0.05)
	_check(_worker.is_excavating() and _worker2.is_excavating(),
			"§94 os dois Workers passaram a EXCAVATE na mesma rocha")
	_check(_worker.current_excavation_target() == rock
			and _worker2.current_excavation_target() == rock,
			"§94 as duas ordens de escavação apontam para a mesma rocha")
	_check(not _soldier.has_move_target(), "§54 o Soldado não transformou a rocha em Move")
	_check(_soldier.global_position.is_equal_approx(soldier_spot),
			"§54 o Soldado ficou exatamente onde estava")
	_check(_soldier.velocity == Vector3.ZERO, "§54 o Soldado não se moveu")
	var in_range := await _wait_until(func() -> bool:
		return _worker.velocity == Vector3.ZERO and _worker2.velocity == Vector3.ZERO, 6.0)
	_check(in_range, "os dois Workers alcançaram a rocha")
	var before := rock.state.remaining_work
	await _advance(1.0)
	var applied := before - rock.state.remaining_work
	_check(absf(applied - 2.0) < WORK_TOLERANCE,
			"§94 exatamente dois Workers trabalham a rocha (~2.0 em 1 s, obtido %f)" % applied)
	_check(rock.state.remaining_work > 0.0, "a rocha ainda tem trabalho para o resto do teste")
	await _send_workers_away()


func _test_mixed_group_construction() -> void:
	_check(_text_of(_nest_hud, "StatusLabel") == "%s: recursos insuficientes" % NEST_NAME,
			"§14 o HUD do Ninho continua independente do Quartel")
	_stockpile.add_resource(_iron_ore(), 3)
	await _advance(0.05)
	_press_key(KEY_B)
	await _advance(0.2)
	var nests := _nests_in_scene()
	_check(nests.size() == 1, "§14/§99 B continua criando o Ninho com o Quartel já pronto")
	if nests.is_empty():
		_finish()
		return
	var nest := nests[0]
	_check(nest.global_position.is_equal_approx(NEST_POINT),
			"§99 o Ninho foi para o NestBuildPoint de sempre")
	_check(_barracks_in_scene().size() == 1, "§14 Ninho e Quartel coexistem na cena")
	_check(_stockpile.get_amount(ORE) == 0, "§99 o Ninho cobrou os 3 Minério do estoque")
	_place(_worker, Vector3(NEST_POINT.x + 1.5, 0.0, NEST_POINT.z + 0.9))
	_place(_worker2, Vector3(NEST_POINT.x + 1.5, 0.0, NEST_POINT.z - 0.9))
	_place(_soldier, SOLDIER_PARK)
	await _advance(0.1)
	await _select_three()
	_right_click(nest.global_position)
	await _advance(0.15)
	_check(_worker.is_building() and _worker2.is_building(),
			"§95 os Workers entraram em BUILD no canteiro do Ninho")
	_check(_worker.current_construction_target() == nest,
			"§95 o alvo de construção é o Ninho, um prédio de outro tipo")
	_check(not _soldier.has_method("assign_construction_target"),
			"§58/§98 o Soldado não tem API de construção")
	_check(not _soldier.has_move_target(), "§55 o Soldado ignorou o canteiro")
	_check(_soldier.global_position.is_equal_approx(SOLDIER_PARK),
			"§55 o Soldado permaneceu no lugar durante a ordem de obra")
	_check(nest.state.remaining_work < nest.definition.work_required,
			"§95 a obra do Ninho realmente avançou")
	await _send_workers_away()


func _test_mixed_group_pile() -> void:
	_place(_worker, PILE_LEFT)
	_place(_worker2, PILE_RIGHT)
	_place(_soldier, SOLDIER_PARK)
	await _advance(0.1)
	_pile = PILE_SCENE.instantiate() as ResourcePileRuntime
	_pile.position = PILE_SPOT
	_dungeon.add_child(_pile)
	_pile.setup(_iron_ore(), ResourcePileState.new(_iron_ore(), "barracks_test_pile", 3))
	await _advance(0.15)
	await _select_three()
	_pile_before = _stockpile.get_amount(ORE)
	_right_click(_pile.global_position)
	await _advance(0.05)
	var settled := await _wait_until(func() -> bool: return _ore_recovered() >= 3, 20.0)
	_check(settled, "§96 os Workers tiraram os 3 da pilha, fora do chão %d" % _ore_recovered())
	_check(_ore_recovered() == 3, "§96 nenhum recurso foi duplicado na coleta")
	_check(not is_instance_valid(_pile) or _pile.is_queued_for_deletion(),
			"§96 a pilha vazia saiu da cena")
	_check(_not_collecting(_worker) and _not_collecting(_worker2),
			"§96 nenhum Worker ficou preso em COLLECT")
	_check(not _soldier.has_move_target(), "§56 o Soldado ignorou a pilha")
	_check(_soldier.global_position.is_equal_approx(SOLDIER_PARK),
			"§56 o Soldado não se moveu para a pilha")
	var delivered := await _wait_until(func() -> bool: return _total_cargo() == 0, 40.0)
	_check(delivered, "§99 a entrega dos dois Workers terminou")
	_check(_stockpile.get_amount(ORE) - _pile_before == 3,
			"§99 o estoque cresceu exatamente +3, obtido +%d"
					% (_stockpile.get_amount(ORE) - _pile_before))


func _test_mixed_group_ground() -> void:
	await _park_three()
	_selection.clear_selection()
	await _drag_over_three()
	_check(_selection.selected_units.size() == 3, "o grupo dos três está pronto")
	var order := _unit_ids()
	_right_click(GROUP_CENTER)
	await _advance(0.05)
	_check(_soldier.has_move_target(), "§97 o Soldado recebeu MOVE do chão")
	var arrived := await _wait_until(func() -> bool:
		return not _worker.has_move_target() and not _worker2.has_move_target() \
				and not _soldier.has_move_target(), 15.0)
	_check(arrived, "§97 os três obedeceram à ordem de grupo")
	var targets := _expected_line(order)
	_check(_close_planar(_soldier.global_position, targets["soldier_001"]),
			"§57 o Soldado participou dos offsets de grupo")
	_check(_close_planar(_worker.global_position, targets["worker_001"])
			and _close_planar(_worker2.global_position, targets["worker_002"]),
			"§97 os Workers terminaram nos destinos da mesma linha")
	_check(_selection.selected_units.size() == 3, "a ordem de movimento não desfez a seleção")


func _test_hud_after_cycle() -> void:
	_check(_text_of(_military_hud, "BarracksStatusLabel") == "%s: concluído" % BARRACKS_NAME,
			"§59 HUD mostra o Quartel concluído")
	_check(_text_of(_military_hud, "RecruitHintLabel")
			== "[R] Recrutar %s — 15 Essência" % SOLDIER_NAME,
			"§59 depois da conclusão a dica mostra o custo de Essência")
	_check(_text_of(_military_hud, "RecruitStatusLabel")
			== "%s: recrutado" % SOLDIER_NAME, "§59 HUD informa o Soldado recrutado")
	_check(_text_of(_nest_hud, "StatusLabel") == "%s: em construção" % NEST_NAME,
			"§99 o HUD do Ninho voltou ao seu próprio estado")
	_check(_text_of(_ore_hud, "OreLabel") == "Minério de Ferro: 3",
			"§99 o HUD de recurso continua coerente com o estoque")
	var hud_source := _source(MILITARY_HUD_SOURCE_PATH)
	_check(not hud_source.contains("_process(") and not hud_source.contains("_physics_process"),
			"§60 o HUD militar não pollinga por frame")
	_check(not hud_source.contains("get_nodes_in_group")
			and not hud_source.contains("find_children"),
			"§60 o HUD militar não varre a árvore")
	_check(not _source("res://ui/hud/MilitaryDebugHud.tscn").contains("Button"),
			"§59 nenhum botão interativo no HUD militar")


func _test_systems_survive() -> void:
	_core.set_process(true)
	var essence_before := _core_state.essence
	await _advance(1.0)
	_check(_core_state.essence > essence_before,
			"§99 a geração de Essência continua viva (%f -> %f)" % [essence_before, _core_state.essence])
	_core.set_process(false)
	_check(_camera.global_position.length() > 5.0, "§99 a câmera continua no rig")
	var camera_before := _camera.global_position
	_selection.clear_selection()
	_place(_worker, SPOT_NEAR)
	await _advance(0.1)
	await _click_select(_worker)
	_check(_selection.selected_unit == _worker, "§99 a seleção de Worker continua igual")
	_right_click(SPOT_FAR)
	await _advance(0.1)
	_check(_worker.action_mode() == WorkerRuntime.ActionMode.MOVE,
			"§99 o Worker continua obedecendo MOVE")
	_check(camera_before == _camera.global_position, "§99 nenhuma ordem moveu a câmera")
	_check(_construction.nest() != null and _construction.barracks() != null,
			"§99 Ninho e Quartel convivem no mesmo ConstructionController")
	_check(_nest_definition().population_capacity_bonus == 4,
			"§22/§99 o bônus de capacidade continua sendo atribuição do Ninho")
	_check(_barracks_definition() != _nest_definition(),
			"§14 Ninho e Quartel têm Definitions separadas")
	_check(_invocation.summoned_worker() == _worker2, "§99 a invocação continua rastreável")
	_check(_worker2.state.unit_id == "worker_002", "§99 o segundo Worker segue worker_002")


func _test_scope_guards() -> void:
	var soldier_source := _source(SOLDIER_RUNTIME_SOURCE_PATH)
	for forbidden in ["assign_excavation_target", "collect_resource_pile",
			"assign_construction_target", "carry_capacity", "work_speed", "cargo"]:
		_check(not soldier_source.contains(forbidden),
				"§98/§33 SoldierRuntime não conhece %s" % forbidden)
	var probe := SOLDIER_SCENE.instantiate() as SoldierRuntime
	for method in ["assign_excavation_target", "collect_resource_pile",
			"assign_construction_target"]:
		_check(not probe.has_method(method),
				"§33 a API de trabalho %s não existe no Soldado" % method)
	_check(probe.has_method("set_selected") and probe.has_method("move_to")
			and probe.has_method("has_move_target") and probe.has_method("get_unit_id"),
			"§49 o Soldado tem exatamente a API comum de unidade RTS")
	probe.free()
	for base_name in ["RTSUnitBase", "UnitRuntimeBase", "CharacterRuntimeBase",
			"UnitStateBase", "CharacterState", "CombatUnitState", "UnitDefinition",
			"BuildingDefinition", "BuildingFactory", "GenericBuildingRuntime",
			"RoomRegistry", "EffectSystem", "EventBus", "UnitRegistry", "CombatManager"]:
		_check(not _class_exists(base_name), "§50/§102/§104 nenhuma classe %s" % base_name)
	for manager in ["UnitFactory", "RecruitmentFactory", "CreatureFactory", "ArmyManager",
			"MilitaryManager", "BarracksConstructionManager", "BuildingManager", "RoomManager"]:
		_check(not _source(GAME_MAIN_SOURCE_PATH).contains(manager),
				"§14/§36/§103 GameMain não menciona %s" % manager)
	var selection_source := _source(SELECTION_SOURCE_PATH)
	_check(not selection_source.contains("Array[WorkerRuntime]")
			and not selection_source.contains(": WorkerRuntime")
			and not selection_source.contains("is WorkerRuntime")
			and not selection_source.contains("as WorkerRuntime"),
			"§48 o SelectionController não está mais amarrado ao tipo WorkerRuntime")
	_check(selection_source.contains("rts_selectable"),
			"§47 a seleção é guiada pelo grupo rts_selectable")
	# A Tarefa 11 §20 autorizou a seleção a reconhecer o inimigo e entregar a ordem de
	# ataque. Ela continua sem nenhuma regra de economia, recrutamento ou EXECUÇÃO de
	# combate: quem calcula dano, cooldown e morte são os dois Runtimes.
	_check(selection_source.contains("attack_target")
			and selection_source.contains("ENEMY_LAYER"),
			"§20 T11 a seleção reconhece o inimigo e entrega attack_target")
	for economy in ["recruit", "essence", "stockpile"]:
		_check(not selection_source.contains(economy),
				"§105/§99 a seleção não conhece a economia (%s)" % economy)
	for execution in ["attack_damage", "attack_interval", "receive_damage", "queue_free",
			"is_dead", "get_nodes_in_group", "get_first_node_in_group"]:
		_check(not selection_source.contains(execution),
				"§99 a seleção não executa combate (%s)" % execution)
	_check(not selection_source.contains("soldier"),
			"§19 a seleção não tem branch pelo nome do Soldado")
	var construction_source := _source(CONSTRUCTION_SOURCE_PATH)
	_check(construction_source.contains("_consume_build_cost"),
			"§15 a duplicação real de custo virou uma função compartilhada")
	_check(not construction_source.contains("_process(")
			and not construction_source.contains("_physics_process"),
			"§106 o ConstructionController continua sem loop por frame")
	_check(not construction_source.contains("BuildingFactory")
			and not construction_source.contains("RoomRegistry")
			and not construction_source.contains("BuildingDefinition"),
			"§15 nenhuma abstração genérica de prédio foi criada")
	_check(not _source(WORKER_RUNTIME_SOURCE_PATH).contains("BarracksRuntime")
			and not _source(WORKER_RUNTIME_SOURCE_PATH).contains("NestRuntime"),
			"§19 o Worker não conhece tipos concretos de prédio")
	var barracks_source := _source(BARRACKS_RUNTIME_SOURCE_PATH)
	_check(not barracks_source.contains("_process(")
			and not barracks_source.contains("_physics_process"),
			"§106 o BarracksRuntime é passivo")
	_check(not barracks_source.contains("6.0") and not barracks_source.contains("apply_work("),
			"§6 o Runtime do Quartel não hardcode nem aplica trabalho sozinho")
	# §3 da Tarefa 11 pediu exatamente estes três números na Definition, vindos do .tres.
	var soldier_definition_source := _source("res://core/definitions/soldier_definition.gd")
	for stat in ["attack_damage", "attack_range", "attack_interval"]:
		_check(soldier_definition_source.contains(stat),
				"§3 T11 SoldierDefinition declara %s" % stat)
	for hardcoded in ["12.0", "1.4", "0.75"]:
		_check(not _source("res://units/soldiers/soldier_runtime.gd").contains(hardcoded),
				"§4 nenhum número de ataque (%s) hardcoded no Runtime" % hardcoded)
	var soldier_state_source := _source("res://core/state/soldier_state.gd")
	for forbidden in ["func die", "func _die", "func kill", "death_",
			"respawn", "resurrect", "heal_ai"]:
		_check(not soldier_state_source.contains(forbidden),
				"§26 SoldierState não implementa '%s'" % forbidden)
	_check(_has_signal(SoldierState.new(_soldier_definition(), "probe"), "died")
			and SoldierState.new(_soldier_definition(), "probe").has_method("is_dead"),
			"§10 T11 SoldierState ganhou died e is_dead")
	_check(not _source("res://units/soldiers/SoldierRuntime.tscn").contains("glb")
			and not _source("res://world/dungeon/rooms/barracks/BarracksRuntime.tscn")
					.contains("glb"),
			"§10/§29 nenhum asset externo importado")


# --------------------------------------------------------------- Campanha (§100)


func _test_end_to_end_campaign() -> void:
	_free_scene()
	await _advance(0.1)
	await _boot_scene()
	var ore := _iron_ore()
	_check(_core_state.population == 1 and _workers_in_scene().size() == 1,
			"§100-0 a campanha começa com 1 Worker")
	_check(_stockpile.get_amount(ore.resource_id) == 0, "§100-0 estoque 0")
	_check(_rock_with_id(SECOND_ORE_ROCK_ID) != null, "§100 a segunda rocha está na cena")

	_invoke_second_worker()
	await _advance(0.4)
	_worker2 = _invocation.summoned_worker()
	_check(_worker2 != null and _core_state.population == 2,
			"§100-1 I criou o segundo Worker e Population 2")

	await _mine_with_two_workers(_rock_with_id(FIRST_ORE_ROCK_ID))
	_check(_stockpile.get_amount(ore.resource_id) == 3,
			"§100-2 a primeira rocha de minério rendeu 3 Minério, obtido %d"
					% _stockpile.get_amount(ore.resource_id))

	_press_key(KEY_B)
	await _advance(0.2)
	var nest := _construction.nest()
	_check(nest != null, "§100-3 B abriu o canteiro do Ninho")
	if nest == null:
		_finish()
		return
	_check(_stockpile.get_amount(ore.resource_id) == 0, "§100-3 o Ninho consumiu os 3 Minério")
	_place(_worker, Vector3(NEST_POINT.x + 1.5, 0.0, NEST_POINT.z + 0.9))
	_place(_worker2, Vector3(NEST_POINT.x + 1.5, 0.0, NEST_POINT.z - 0.9))
	await _advance(0.1)
	_selection.clear_selection()
	await _click_select(_worker)
	await _shift_click_select(_worker2)
	_right_click(nest.global_position)
	var nest_done := await _wait_until(func() -> bool: return nest.is_completed(), 25.0)
	_check(nest_done, "§100-3 os dois Workers concluíram o Ninho")
	_check(_core_state.get_population_capacity() == NEST_CAPACITY,
			"§100-4 a capacidade passou a 12 com o Ninho")
	_check(_core_state.population == 2, "§41 Population ainda 2 antes do Quartel")

	await _mine_with_two_workers(_rock_with_id(SECOND_ORE_ROCK_ID))
	_check(_stockpile.get_amount(ore.resource_id) == 3,
			"§100-5 a segunda rocha de minério rendeu 3 Minério, obtido %d"
					% _stockpile.get_amount(ore.resource_id))

	_set_essence(20.0)
	_press_key(KEY_K)
	await _advance(0.2)
	_barracks = _construction.barracks()
	_check(_barracks != null and not _barracks.is_completed(),
			"§100-6 K abriu o canteiro do Quartel")
	if _barracks == null:
		_finish()
		return
	_check(_stockpile.get_amount(ore.resource_id) == 0, "§100-6 o estoque voltou a 0")
	_check(_barracks.global_position.is_equal_approx(BARRACKS_POINT),
			"§100 o Quartel ficou no canteiro planejado")
	_check(_construction.nest() != null and _barracks != null,
			"§14 a campanha tem Ninho e Quartel ao mesmo tempo")
	_place(_worker, Vector3(BARRACKS_POINT.x + 1.5, 0.0, BARRACKS_POINT.z + 0.9))
	_place(_worker2, Vector3(BARRACKS_POINT.x + 1.5, 0.0, BARRACKS_POINT.z - 0.9))
	await _advance(0.1)
	_selection.clear_selection()
	await _click_select(_worker)
	await _shift_click_select(_worker2)
	_right_click(_barracks.global_position)
	var barracks_done := await _wait_until(func() -> bool: return _barracks.is_completed(), 25.0)
	_check(barracks_done, "§100-7 o Quartel foi concluído pelos dois Workers")
	_check(_core_state.get_population_capacity() == NEST_CAPACITY,
			"§100-7/§22 a capacidade continua 12 depois do Quartel")

	_check(_recruitment.can_recruit(), "§100-8 Quartel, capacidade e Essência liberados")
	_population_events.clear()
	_press_key(KEY_R)
	await _advance(0.3)
	_soldier = _recruitment.soldier()
	_check(_soldier != null and _soldier.state.unit_id == "soldier_001",
			"§100-8 R recrutou soldier_001 na campanha real")
	if _soldier == null:
		_finish()
		return
	_check(_core_state.population == 3
			and _core_state.get_population_capacity() == NEST_CAPACITY,
			"§100-9 Population 3 / 12 na campanha")
	_check(_population_events == ["3/12"],
			"§100-9 o sinal de população da campanha foi 3/12, eventos %s" % [_population_events])
	_check(_close(_core_state.essence, 5.0),
			"§100-8 Essência caiu de 20 para 5, obtido %f" % _core_state.essence)
	_check(_soldier.global_position.is_equal_approx(SOLDIER_SPAWN),
			"§100 o Soldado apareceu ao lado do Quartel")

	await _park_three()
	_selection.clear_selection()
	await _drag_over_three()
	_check(_selection.selected_units.size() == 3
			and _unit_ids() == ["soldier_001", "worker_001", "worker_002"],
			"§100-10 a caixa da campanha selecionou os três, ordem %s" % [_unit_ids()])
	var order := _unit_ids()
	_right_click(GROUP_CENTER)
	var arrived := await _wait_until(func() -> bool:
		return not _worker.has_move_target() and not _worker2.has_move_target() \
				and not _soldier.has_move_target(), 15.0)
	_check(arrived, "§100-11 as três unidades marcharam juntas")
	var targets := _expected_line(order)
	_check(_close_planar(_soldier.global_position, targets["soldier_001"])
			and _close_planar(_worker.global_position, targets["worker_001"])
			and _close_planar(_worker2.global_position, targets["worker_002"]),
			"§100-11 os três terminaram na linha determinística de 1.2")
	_check(_text_of(_military_hud, "RecruitStatusLabel")
			== "%s: recrutado" % SOLDIER_NAME, "§100 o HUD militar fechou o ciclo")
	_check(_text_of(_core_hud, "PopulationLabel") == "Population: 3 / 12",
			"§100 o HUD do núcleo mostra 3 / 12 no fim da campanha")
	_check(_barracks.find_child("CompletedVisual", true, false).visible
			and not _barracks.find_child("ConstructionVisual", true, false).visible,
			"§100 o Quartel da campanha terminou com o visual concluído")


## Um turno completo: esgotar a rocha, coletar a pilha e entregar no depósito.
func _mine_with_two_workers(rock: RockRuntime) -> void:
	if rock == null:
		_check(false, "§100 a rocha da campanha não foi encontrada")
		return
	# A rocha se remove ao esgotar, então o teste acompanha só o id dela.
	var rock_id := rock.rock_id
	var rock_position := rock.global_position
	_place(_worker, Vector3(rock_position.x + 2.5, 0.0, rock_position.z + 1.0))
	_place(_worker2, Vector3(rock_position.x + 2.5, 0.0, rock_position.z - 1.0))
	await _advance(0.1)
	_selection.clear_selection()
	await _click_select(_worker)
	await _shift_click_select(_worker2)
	_right_click(rock_position)
	var depleted := await _wait_until(
			func() -> bool: return not _rock_present(rock_id), 40.0)
	_check(depleted, "§100 a rocha %s foi esgotada pelos dois Workers" % rock_id)
	var pile := await _wait_for_pile(6.0)
	_check(pile != null, "§100 a rocha virou uma pilha de minério")
	if pile == null:
		return
	_right_click(pile.global_position)
	var loaded := await _wait_until(func() -> bool: return _total_cargo() == 3, 25.0)
	_check(loaded, "§100 os Workers encheram a carga de 3, obtido %d" % _total_cargo())
	var delivered := await _wait_until(func() -> bool: return _total_cargo() == 0, 40.0)
	_check(delivered, "§100 a carga chegou ao depósito")


# ------------------------------------------------------------------- Helpers


func _barracks_definition() -> BarracksDefinition:
	return load(BARRACKS_DEFINITION_PATH) as BarracksDefinition


func _soldier_definition() -> SoldierDefinition:
	return load(SOLDIER_DEFINITION_PATH) as SoldierDefinition


func _nest_definition() -> NestDefinition:
	return load(NEST_DEFINITION_PATH) as NestDefinition


func _iron_ore() -> ResourceDefinition:
	return load(IRON_ORE_PATH) as ResourceDefinition


func _set_essence(value: float) -> void:
	var difference := value - _core_state.essence
	if difference > 0.0:
		_core_state.add_essence(difference)
	elif difference < 0.0:
		_core_state.consume_essence(-difference)


func _invoke_second_worker() -> void:
	_set_essence(20.0)
	_press_key(KEY_I)


func _free_scene() -> void:
	if _scene != null and is_instance_valid(_scene):
		_scene.free()
	_scene = null
	_dungeon = null
	_camera = null
	_worker = null
	_worker2 = null
	_soldier = null
	_barracks = null
	_pile = null
	_selection = null
	_construction = null
	_recruitment = null
	_invocation = null
	_core = null
	_core_state = null
	_stockpile = null
	_population_events.clear()
	_capacity_events.clear()
	_essence_reads.clear()
	_recruited.clear()
	_completions = 0


func _barracks_in_scene() -> Array[BarracksRuntime]:
	var found: Array[BarracksRuntime] = []
	for child in _dungeon.get_children():
		if child is BarracksRuntime:
			found.append(child as BarracksRuntime)
	return found


func _nests_in_scene() -> Array[NestRuntime]:
	var found: Array[NestRuntime] = []
	for child in _dungeon.get_children():
		if child is NestRuntime:
			found.append(child as NestRuntime)
	return found


func _workers_in_scene() -> Array[WorkerRuntime]:
	var workers: Array[WorkerRuntime] = []
	for child in _dungeon.get_children():
		if child is WorkerRuntime:
			workers.append(child as WorkerRuntime)
	return workers


func _soldiers_in_scene() -> Array[SoldierRuntime]:
	var soldiers: Array[SoldierRuntime] = []
	for child in _dungeon.get_children():
		if child is SoldierRuntime:
			soldiers.append(child as SoldierRuntime)
	return soldiers


func _soldier_in_scene() -> SoldierRuntime:
	var soldiers := _soldiers_in_scene()
	return soldiers[0] if soldiers.size() == 1 else null


func _rocks_in_scene() -> Array[RockRuntime]:
	var rocks: Array[RockRuntime] = []
	for child in _dungeon.get_children():
		if child is RockRuntime:
			rocks.append(child as RockRuntime)
	return rocks


func _rock_with_id(id: String) -> RockRuntime:
	for child in _dungeon.get_children():
		if child is RockRuntime and (child as RockRuntime).rock_id == id:
			return child as RockRuntime
	return null


func _rock_present(id: String) -> bool:
	for child in _dungeon.get_children():
		if child is RockRuntime and (child as RockRuntime).rock_id == id \
				and not child.is_queued_for_deletion():
			return true
	return false


func _unit_ids() -> Array[String]:
	var ids: Array[String] = []
	for unit in _selection.selected_units:
		ids.append(unit.get_unit_id())
	return ids


func _indicator(unit) -> MeshInstance3D:
	return unit.find_child("SelectionIndicator", true, false) as MeshInstance3D


func _visible_indicators() -> int:
	var count := 0
	for unit in [_worker, _worker2, _soldier]:
		if unit != null and is_instance_valid(unit) and _indicator(unit).visible:
			count += 1
	return count


func _total_cargo() -> int:
	var total := 0
	for worker in _workers_in_scene():
		total += worker.state.carried_amount
	return total


## Recurso que já saiu do chão: carga em trânsito somada ao que chegou ao estoque.
func _ore_recovered() -> int:
	return _total_cargo() + _stockpile.get_amount(ORE) - _pile_before


func _not_collecting(worker: WorkerRuntime) -> bool:
	return worker.action_mode() != WorkerRuntime.ActionMode.COLLECT


func _in_build_range(worker: WorkerRuntime) -> bool:
	return _planar_gap(worker.global_position, _barracks.global_position) <= worker.build_range


func _construction_touches_unit(unit: Node3D) -> bool:
	return _planar_gap(_barracks.global_position, unit.global_position) < BARRACKS_HALF + 0.3


func _park_three() -> void:
	_place(_worker, SITE_LEFT)
	_place(_worker2, SPOT_FAR)
	_place(_soldier, SOLDIER_PARK)
	await _advance(0.15)


func _select_three() -> void:
	_selection.clear_selection()
	await _click_select(_worker)
	await _shift_click_select(_worker2)
	await _shift_click_select(_soldier)


func _send_workers_away() -> void:
	_selection.clear_selection()
	await _click_select(_worker)
	await _shift_click_select(_worker2)
	_right_click(CANCEL_SPOT)
	await _advance(0.4)


func _screen(world_position: Vector3) -> Vector2:
	return _camera.unproject_position(world_position)


func _screen_hit(screen_position: Vector2, mask: int) -> Dictionary:
	var origin := _camera.project_ray_origin(screen_position)
	var direction := _camera.project_ray_normal(screen_position)
	return _scene.get_viewport().world_3d.direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(origin, origin + direction * 1000.0, mask))


func _drag_over_three() -> void:
	var corners := Rect2(Vector2(100000.0, 100000.0), Vector2.ZERO)
	for unit in [_worker, _worker2, _soldier]:
		var screen := _screen(unit.global_position)
		corners = corners.expand(screen)
	var from := corners.position - Vector2(6.0, 6.0)
	var to := corners.end + Vector2(6.0, 6.0)
	_press(MOUSE_BUTTON_LEFT, from)
	_motion(from.lerp(to, 0.5))
	_motion(to)
	_release(MOUSE_BUTTON_LEFT, to)
	await _advance(0.05)


func _expected_line(order: Array[String]) -> Dictionary:
	var targets := {}
	for index in order.size():
		var shift := (float(index) - float(order.size() - 1) * 0.5) * SPACING
		targets[order[index]] = GROUP_CENTER + Vector3(shift, 0.0, 0.0)
	return targets


func _close_planar(from: Vector3, to: Vector3) -> bool:
	return _planar_gap(from, to) <= ARRIVAL_TOLERANCE


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


func _ground_body_at(point: Vector3) -> String:
	var hit := (_scene.get_viewport().world_3d.direct_space_state
			.intersect_ray(PhysicsRayQueryParameters3D.create(
					Vector3(point.x, 6.0, point.z), Vector3(point.x, 0.0, point.z), GROUND_LAYER)))
	return String(hit.collider.name) if not hit.is_empty() else "<nada>"


func _straight_route_clear(from: Vector3, to: Vector3, source_id: String) -> bool:
	var start := _route_start(from, to, ROCK_HALF)
	for rock in _rocks_in_scene():
		if rock.rock_id == source_id:
			continue
		if not _segment_clear_of(start, WORKER_RADIUS, to, rock.global_position, ROCK_HALF):
			return false
	return true


func _route_clear_of_sites(from: Vector3, to: Vector3) -> bool:
	var start := _route_start(from, to, BARRACKS_HALF)
	for site in [NEST_POINT, BARRACKS_POINT]:
		if site.is_equal_approx(from):
			continue
		if not _segment_clear_of(start, WORKER_RADIUS, to, site, BARRACKS_HALF):
			return false
	return true


## O transporte começa na borda do obstáculo de origem, nunca no centro dele.
func _route_start(from: Vector3, to: Vector3, from_radius: float) -> Vector3:
	var direction := to - from
	direction.y = 0.0
	return from + direction.normalized() * (from_radius + WORKER_RADIUS)


func _segment_clear_of(from: Vector3, radius: float, to: Vector3,
		obstacle: Vector3, obstacle_radius: float) -> bool:
	var samples := 24
	for i in samples + 1:
		var point := from.lerp(to, float(i) / float(samples))
		if _planar_gap(obstacle, point) < radius + obstacle_radius:
			return false
	return true


func _name_of(point: Vector3) -> String:
	if point.is_equal_approx(BARRACKS_POINT):
		return "BarracksBuildPoint"
	if point.is_equal_approx(SOLDIER_SPAWN):
		return "SoldierSpawnPoint"
	return str(point)


func _primitive_meshes_only(node: Node) -> bool:
	for child in node.get_children():
		if child is MeshInstance3D:
			if not (child.mesh is BoxMesh or child.mesh is CylinderMesh
					or child.mesh is CapsuleMesh or child.mesh is SphereMesh):
				return false
			if child.mesh.resource_path.contains(".glb") \
					or child.mesh.resource_path.contains(".obj"):
				return false
		if child.get_child_count() > 0 and not _primitive_meshes_only(child):
			return false
	return true


func _body_color(visual: MeshInstance3D) -> Color:
	if visual == null:
		return Color.MAGENTA
	var material: StandardMaterial3D = null
	if visual.material_override is StandardMaterial3D:
		material = visual.material_override as StandardMaterial3D
	elif visual.mesh != null and visual.mesh.material is StandardMaterial3D:
		material = visual.mesh.material as StandardMaterial3D
	if material == null:
		return Color.MAGENTA
	return material.albedo_color


func _worker_visual_color() -> Color:
	var probe: Node = load("res://units/workers/WorkerRuntime.tscn").instantiate()
	var visual := probe.find_child("Visual", true, false) as MeshInstance3D
	var color := _body_color(visual)
	probe.free()
	return color


func _place(unit, position_at: Vector3) -> void:
	unit.velocity = Vector3.ZERO
	unit.global_position = position_at
	unit.move_to(position_at)


func _click_select(unit) -> void:
	await _press_release(MOUSE_BUTTON_LEFT, _screen_of_body(unit))


func _shift_click_select(unit) -> void:
	Input.action_press(&"selection_additive")
	await _press_release(MOUSE_BUTTON_LEFT, _screen_of_body(unit))
	Input.action_release(&"selection_additive")


## O clique mira o meio do corpo: o ray da câmera sempre atravessa a cápsula da
## unidade, enquanto o ponto dos pés é tangente em posições afastadas do centro.
func _screen_of_body(unit) -> Vector2:
	return _screen(unit.global_position + Vector3(0.0, 0.8, 0.0))


func _right_click(world_position: Vector3) -> void:
	var screen := _screen(world_position)
	_press(MOUSE_BUTTON_RIGHT, screen)
	_release(MOUSE_BUTTON_RIGHT, screen)
	await _advance(0.05)


func _press_release(button: int, screen: Vector2) -> void:
	_press(button, screen)
	_release(button, screen)
	await _advance(0.05)


func _press(button: int, screen: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	event.position = screen
	event.global_position = screen
	root.push_input(event)


func _release(button: int, screen: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = false
	event.position = screen
	event.global_position = screen
	root.push_input(event)


func _motion(screen: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = screen
	event.global_position = screen
	root.push_input(event)


func _press_key(physical_keycode: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = physical_keycode
	event.pressed = true
	root.push_input(event)
	event.pressed = false
	root.push_input(event)


func _wait_for_pile(max_seconds: float) -> ResourcePileRuntime:
	var found := await _wait_until(func() -> bool: return _find_pile() != null, max_seconds)
	return _find_pile() if found else null


func _find_pile() -> ResourcePileRuntime:
	for child in _dungeon.get_children():
		if child is ResourcePileRuntime and not child.is_queued_for_deletion():
			return child as ResourcePileRuntime
	return null


func _text_of(root_node: Node, label_name: String) -> String:
	var label := root_node.find_child(label_name, true, false) as Label
	if label == null:
		return "<ausente>"
	return label.text


func _controls_not_ignoring(node: Node) -> Array[String]:
	var offenders: Array[String] = []
	for child in node.find_children("*", "Control", true, false):
		var control := child as Control
		if control.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			offenders.append(String(control.name))
	return offenders


func _has_signal(emitter: Object, signal_name: String) -> bool:
	for signal_info in emitter.get_signal_list():
		if String(signal_info.name) == signal_name:
			return true
	return false


func _instance_fields(instance: Object) -> Array[String]:
	var fields: Array[String] = []
	for property in instance.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			fields.append(String(property.name))
	return fields


func _class_exists(candidate: String) -> bool:
	return ClassDB.class_exists(candidate)


func _count_files(path: String, pattern: String) -> int:
	var directory := DirAccess.open(path)
	if directory == null:
		return -1
	directory.list_dir_begin()
	var count := 0
	var entry := directory.get_next()
	while not entry.is_empty():
		if not directory.current_is_dir() and entry.match(pattern):
			count += 1
		entry = directory.get_next()
	directory.list_dir_end()
	return count


func _source(path: String) -> String:
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


func _close(a: float, b: float, tolerance: float = 0.001) -> bool:
	return absf(a - b) <= tolerance


func _advance(seconds: float) -> void:
	var ticks := int(ceil(seconds * Engine.get_physics_ticks_per_second()))
	for _tick in maxi(ticks, 1):
		await physics_frame


func _wait_until(condition: Callable, max_seconds: float) -> bool:
	var limit := int(max_seconds * Engine.get_physics_ticks_per_second())
	var guard := 0
	while not condition.call() and guard < limit:
		await physics_frame
		guard += 1
	return condition.call()


func _time_until(condition: Callable, max_seconds: float) -> float:
	var ticks := 0
	var limit := int(max_seconds * Engine.get_physics_ticks_per_second())
	while not condition.call() and ticks < limit:
		await physics_frame
		ticks += 1
	return float(ticks) / float(Engine.get_physics_ticks_per_second())


func _check(condition: bool, label: String) -> void:
	_asserts += 1
	if condition:
		print("[PASS] %s" % label)
	else:
		_failures += 1
		print("[FAIL] %s" % label)


func _finish() -> void:
	print("---- barracks and soldier tests finished: %d asserts, %d failure(s) ----"
			% [_asserts, _failures])
	quit(1 if _failures > 0 else 0)
