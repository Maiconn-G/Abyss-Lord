extends SceneTree

# Tarefa 11 — Primeiro Inimigo e Combate Básico.
# A suíte dirige o GameMain real: a Fera Cavernosa nasce passiva no seu ponto, o
# Soldado recebe ATTACK por input sintético de verdade, os dois trocam golpes por
# cooldown e um dos dois morre. Nada de busca global, nada de manager: as ordens
# entram pelo ray de seleção e o dano corre nos dois Runtimes.

const MAIN_SCENE := preload("res://game/GameMain.tscn")
const ENEMY_SCENE := preload("res://units/enemies/EnemyRuntime.tscn")
const SOLDIER_SCENE := preload("res://units/soldiers/SoldierRuntime.tscn")
const PILE_SCENE := preload("res://world/resources/ResourcePileRuntime.tscn")

const ENEMY_DEFINITION_PATH := "res://data/units/enemies/cave_beast.tres"
const SOLDIER_DEFINITION_PATH := "res://data/units/soldiers/abyss_soldier.tres"
const BARRACKS_DEFINITION_PATH := "res://data/rooms/abyss_barracks.tres"
const IRON_ORE_PATH := "res://data/resources/iron_ore.tres"
const CORE_DEFINITION_PATH := "res://data/core/core_level_1.tres"

const ENEMY_RUNTIME_SOURCE_PATH := "res://units/enemies/enemy_runtime.gd"
const ENEMY_DEFINITION_SOURCE_PATH := "res://core/definitions/enemy_definition.gd"
const ENEMY_STATE_SOURCE_PATH := "res://core/state/enemy_state.gd"
const SOLDIER_RUNTIME_SOURCE_PATH := "res://units/soldiers/soldier_runtime.gd"
const SELECTION_SOURCE_PATH := "res://systems/selection/selection_controller.gd"
const CORE_STATE_SOURCE_PATH := "res://core/state/core_state.gd"
const GAME_MAIN_SOURCE_PATH := "res://game/game_main.gd"
const COMBAT_HUD_SOURCE_PATH := "res://ui/hud/combat_debug_hud.gd"

const GROUND_LAYER := 1
const UNIT_LAYER := 2
const DIGGABLE_LAYER := 4
const RESOURCE_LAYER := 8
const CONSTRUCTION_LAYER := 16
const ENEMY_LAYER := 32
const OBSTACLES := DIGGABLE_LAYER | RESOURCE_LAYER | CONSTRUCTION_LAYER
const CLICKABLE := GROUND_LAYER | UNIT_LAYER | OBSTACLES | ENEMY_LAYER

const FIRST_ORE_ROCK_ID := "iron_ore_001"
const SECOND_ORE_ROCK_ID := "iron_ore_002"
const COMMON_ROCK_ID := "rock_001"

const ENEMY_SPAWN := Vector3(-3, 0, -12)
const SOLDIER_SPAWN := Vector3(-10, 0, -1.5)
const BARRACKS_POINT := Vector3(-10, 0, -5)
const NEST_POINT := Vector3(-5, 0, -5)
const WORKER_SPAWN := Vector3(0, 0, 4)
const DEPOSIT_POINT := Vector3(-2, 0, 0)
const CORE_POINT := Vector3(0, 1, 0)
const CANCEL_POINT := Vector3(-3, 0, -3)
const PROBE_STAGING := Vector3(3, 0, -3)
const PROBE_A_SPOT := Vector3(3, 0, -8)
const PROBE_B_SPOT := Vector3(6, 0, -11)
const DEATH_STAGING := Vector3(3, 0, -6)
const DEATH_PROBE_SPOT := Vector3(3, 0, -11)
const GROUND_SPOT := Vector3(0, 0, 10)
const SITE_LEFT := Vector3(7.5, 0, 3.0)
const SITE_RIGHT := Vector3(9.0, 0, 3.0)

const ENEMY_ID := "enemy_001"
const ENEMY_KEY := "enemy_001"
const SOLDIER_KEY := "soldier_001"
const ENEMY_HP := 48.0
const SOLDIER_HP := 80.0
const SOLDIER_DAMAGE := 12.0
const SOLDIER_RANGE := 1.4
const SOLDIER_INTERVAL := 0.75
const BEAST_DAMAGE := 6.0
const BEAST_RANGE := 1.2
const BEAST_INTERVAL := 1.0
const BEAST_RADIUS := 0.6
const SOLDIER_RADIUS := 0.42
## Distância de postura esperada: raio da Fera + raio do Soldado + folga de corpo.
const STANCE_GAP := 1.12
## Distância de aproximação real entre SoldierSpawnPoint e EnemySpawnPoint.
const APPROACH_DISTANCE := 12.619
const ROCK_HALF := 1.0
const BUILD_HALF := 1.1
const BARRACKS_WORK := 6.0
const ORE := &"iron_ore"
const BEAST_NAME := "Fera Cavernosa"
const SOLDIER_LINE := "Soldado: 80 / 80 HP"
const BEAST_LINE := "Fera Cavernosa: 48 / 48 HP"

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
var _combat_hud: Node
var _core_hud: Node
var _worker: WorkerRuntime
var _worker2: WorkerRuntime
var _soldier: SoldierRuntime
var _enemy: EnemyRuntime
var _health_reference := {}
var _strike_counts := {}
var _damage_totals := {}
var _died_counts := {}
var _watched_keys: Array[String] = []
var _live_states := {}
var _death_report := {}
var _duel_report := {}
var _soldier_health_after_duel := 0.0
var _population_events: Array[String] = []
var _stockpile_events := 0


func _initialize() -> void:
	_run_all()


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > 400000:
		_check(false, "timeout: a suíte de combate não terminou")
		_finish()
	return false


func _run_all() -> void:
	_test_soldier_combat_definition()
	_test_enemy_definition()
	_test_enemy_state_initial()
	_test_enemy_damage()
	_test_enemy_clamp()
	_test_enemy_heal()
	_test_enemy_died_once()
	_test_soldier_died_once()
	_test_population_removal()
	_test_population_removal_invalid()
	_test_enemy_runtime_scene()
	_test_scope_guards()

	await _boot_scene()
	await _test_scene_composition()
	await _test_enemy_spawn_geometry()
	await _test_combat_hud_initial()
	await _test_enemy_not_selectable()
	await _prepare_army()
	await _test_enemy_passive()
	await _test_worker_rmb_enemy()
	await _test_soldier_rmb_enemy()
	await _test_approach_and_stance()
	await _test_first_hit()
	await _test_attack_interval()
	await _test_retaliation()
	await _test_cancellation()
	await _test_resume_keeps_hp()
	await _test_enemy_out_of_range()
	await _test_systems_survive_control_flow()
	_free_scene()

	await _boot_scene()
	await _prepare_army()
	await _test_default_duel()
	await _test_death_consequences()
	await _test_fps_independence()
	_free_scene()

	await _boot_scene()
	await _prepare_army()
	await _test_soldier_death()
	_free_scene()

	await _boot_scene()
	await _test_real_campaign()
	_free_scene()
	_finish()


# ------------------------------------------------------------- Definition e States


func _test_soldier_combat_definition() -> void:
	var definition := _soldier_definition()
	_check(_close(definition.attack_damage, SOLDIER_DAMAGE),
			"§53 o Soldado causa %f de dano, obtido %f" % [SOLDIER_DAMAGE, definition.attack_damage])
	_check(_close(definition.attack_range, SOLDIER_RANGE),
			"§53 o alcance do Soldado é %f, obtido %f" % [SOLDIER_RANGE, definition.attack_range])
	_check(_close(definition.attack_interval, SOLDIER_INTERVAL),
			"§53 o intervalo do Soldado é %f, obtido %f"
					% [SOLDIER_INTERVAL, definition.attack_interval])
	_check(_close(definition.max_health, SOLDIER_HP), "§53 o Soldado tem 80 de vida")
	_check(definition.resource_path == SOLDIER_DEFINITION_PATH,
			"§53 os números vêm do abyss_soldier.tres, não do Runtime")


func _test_enemy_definition() -> void:
	var definition := _enemy_definition()
	_check(definition is Resource, "§54 EnemyDefinition é Resource")
	_check(definition.resource_path == ENEMY_DEFINITION_PATH, "§54 cave_beast.tres carrega")
	_check(definition.enemy_type_id == &"cave_beast", "§54 enemy_type_id cave_beast")
	_check(definition.display_name == BEAST_NAME, "§54 display_name Fera Cavernosa")
	_check(_close(definition.max_health, ENEMY_HP), "§54 max_health 48")
	_check(_close(definition.attack_damage, BEAST_DAMAGE), "§54 attack_damage 6")
	_check(_close(definition.attack_range, BEAST_RANGE), "§54 attack_range 1.2")
	_check(_close(definition.attack_interval, BEAST_INTERVAL), "§54 attack_interval 1.0")
	var fields := _instance_fields(definition)
	_check(fields == ["enemy_type_id", "display_name", "max_health",
			"attack_damage", "attack_range", "attack_interval"],
			"§21/§54 a Definition tem exatamente os seis campos declarados, são %s" % [fields])
	for forbidden in ["move_speed", "agro_radius", "detection_radius", "armor", "defense",
			"critical_chance", "loot", "experience", "level", "respawn", "faction",
			"attack_speed", "projectile"]:
		_check(not fields.has(forbidden), "§16/§54/§93 EnemyDefinition não tem %s" % forbidden)
	for field in ["enemy_type_id", "display_name", "max_health", "attack_damage",
			"attack_range", "attack_interval"]:
		_check(_source(ENEMY_DEFINITION_SOURCE_PATH).contains("@export var " + field),
				"§21 %s é @export na Definition" % field)


func _test_enemy_state_initial() -> void:
	var state := EnemyState.new(_enemy_definition(), ENEMY_ID)
	_check(state.enemy_id == ENEMY_ID, "§55 o State carrega enemy_001")
	_check(_close(state.health, ENEMY_HP), "§55 a Fera nasce com 48 de vida, obtido %f" % state.health)
	_check(not state.is_dead(), "§55 a Fera nasce viva")
	_check(state.definition == _enemy_definition(), "§55 o State só conhece a Definition")


func _test_enemy_damage() -> void:
	var state := EnemyState.new(_enemy_definition(), ENEMY_ID)
	state.damage(SOLDIER_DAMAGE)
	_check(_close(state.health, 36.0), "§56 48 - 12 = 36, obtido %f" % state.health)
	_check(not state.is_dead(), "§56 com 36 a Fera continua viva")
	state.damage(0.0)
	state.damage(-5.0)
	_check(_close(state.health, 36.0), "§56 dano 0 ou negativo é ignorado, obtido %f" % state.health)


func _test_enemy_clamp() -> void:
	var state := EnemyState.new(_enemy_definition(), ENEMY_ID)
	state.damage(999.0)
	_check(_close(state.health, 0.0), "§57 damage(999) para em 0, obtido %f" % state.health)
	_check(state.is_dead(), "§57 health 0 é morte")
	state.damage(12.0)
	_check(_close(state.health, 0.0), "§57 a vida nunca fica negativa, obtido %f" % state.health)


func _test_enemy_heal() -> void:
	var state := EnemyState.new(_enemy_definition(), ENEMY_ID)
	state.damage(18.0)
	_check(_close(state.health, 30.0), "§58 a Fera cai para 30, obtido %f" % state.health)
	state.heal(10.0)
	_check(_close(state.health, 40.0), "§58 heal(10) sobe para 40, obtido %f" % state.health)
	state.heal(999.0)
	_check(_close(state.health, ENEMY_HP), "§58 heal estoura no máximo 48, obtido %f" % state.health)
	state.heal(0.0)
	state.heal(-4.0)
	_check(_close(state.health, ENEMY_HP), "§58 heal 0/negativo é ignorado")


func _test_enemy_died_once() -> void:
	var state := EnemyState.new(_enemy_definition(), ENEMY_ID)
	# Lambda captura por valor: os contadores vivem em Arrays para que o signal
	# consiga acumular no mesmo estado que a função de teste lê.
	var emissions := [0]
	var changes := [0]
	state.died.connect(func() -> void: emissions[0] += 1)
	state.health_changed.connect(func(_c: float, _m: float) -> void: changes[0] += 1)
	state.damage(48.0)
	_check(emissions[0] == 1,
			"§59 died dispara exatamente 1 vez ao zerar, obtido %d" % emissions[0])
	_check(state.is_dead(), "§59 is_dead() é true na morte")
	state.damage(12.0)
	state.damage(999.0)
	_check(emissions[0] == 1,
			"§59 died não se repete em dano extra, obtido %d" % emissions[0])
	_check(changes[0] == 1,
			"§59 health_changed só mudou uma vez (48 → 0), obtido %d" % changes[0])


func _test_soldier_died_once() -> void:
	var state := SoldierState.new(_soldier_definition(), SOLDIER_KEY)
	var emissions := [0]
	state.died.connect(func() -> void: emissions[0] += 1)
	_check(not state.is_dead(), "§60 o Soldado nasce vivo")
	state.damage(SOLDIER_HP)
	_check(_close(state.health, 0.0), "§60 80 de dano zeram o Soldado")
	_check(emissions[0] == 1,
			"§60 died do Soldado dispara 1 vez, obtido %d" % emissions[0])
	state.damage(50.0)
	state.damage(50.0)
	_check(emissions[0] == 1,
			"§60 died do Soldado não se repete, obtido %d" % emissions[0])
	_check(state.is_dead(), "§60 SoldierState.is_dead() responde")


func _test_population_removal() -> void:
	var state := CoreState.new(load(CORE_DEFINITION_PATH) as CoreDefinition)
	state.try_add_population(3)
	_check(state.population == 3, "§61 população preparada em 3, obtido %d" % state.population)
	var events: Array[String] = []
	state.population_changed.connect(
			func(current: int, capacity: int) -> void:
				events.append("%d/%d" % [current, capacity]))
	_check(state.try_remove_population(1), "§61 try_remove_population(1) aceita")
	_check(state.population == 2, "§61 a população cai para 2, obtido %d" % state.population)
	_check(events == ["2/8"], "§61 o sinal emitiu 2/8 uma vez, eventos %s" % [events])


func _test_population_removal_invalid() -> void:
	var state := CoreState.new(load(CORE_DEFINITION_PATH) as CoreDefinition)
	state.try_add_population(3)
	var events := [0]
	state.population_changed.connect(func(_c: int, _m: int) -> void: events[0] += 1)
	for invalid in [0, -1, 999]:
		_check(not state.try_remove_population(invalid),
				"§62 try_remove_population(%d) é rejeitado" % invalid)
		_check(state.population == 3,
				"§62 a remoção inválida de %d não alterou a população" % invalid)
	_check(events[0] == 0, "§62 nenhum sinal saiu de uma remoção inválida, obtido %d" % events[0])
	state.try_remove_population(1)
	_check(events[0] == 1,
			"§62 a remoção válida emite o sinal, servindo de controle, obtido %d" % events[0])
	_check(not state.has_method("set_population_ignore_capacity"),
			"§62/§101 não existe atalho de população fora da API atômica")


func _test_enemy_runtime_scene() -> void:
	var probe := ENEMY_SCENE.instantiate() as EnemyRuntime
	_check(probe.get_class() == "CharacterBody3D", "§63 a Fera é CharacterBody3D")
	_check(probe.find_child("Visual", true, false) is MeshInstance3D, "§63 existe o Visual")
	var collision := probe.find_child("CollisionShape3D", true, false) as CollisionShape3D
	_check(collision != null and collision.shape is CylinderShape3D,
			"§63 existe CollisionShape3D com forma física real")
	_check(probe.collision_layer == ENEMY_LAYER,
			"§15/§63 a Fera está na camada 6 (bits %d)" % probe.collision_layer)
	_check(probe.is_in_group(&"combat_target"), "§16/§63 o grupo é combat_target")
	_check(not probe.is_in_group(&"rts_selectable"), "§16 a Fera não é selecionável")
	for absent in ["NavigationAgent3D", "DetectionArea", "AggroArea"]:
		_check(probe.find_child(absent, true, false) == null, "§63/§93 sem %s" % absent)
	for node_class in ["Area3D", "NavigationAgent3D", "NavigationRegion3D", "CPUParticles3D",
			"GPUParticles3D", "AnimationPlayer", "AudioStreamPlayer3D", "Label3D"]:
		_check(probe.find_children("*", node_class, true, false).is_empty(),
				"§93/§63 nenhum nó %s na cena da Fera" % node_class)
	_check(_primitive_meshes_only(probe), "§63/§31 a Fera usa só primitivas, sem modelo externo")
	_check(collision.shape is CylinderShape3D
			and _close((collision.shape as CylinderShape3D).radius, BEAST_RADIUS),
			"§28/§63 o collider da Fera tem raio %f" % BEAST_RADIUS)
	var methods: Array[String] = []
	for candidate in ["setup", "engage", "disengage", "combat_target", "is_engaged",
			"is_alive", "receive_damage", "body_radius", "get_enemy_id"]:
		methods.append(candidate)
		_check(probe.has_method(candidate), "§18/§35 EnemyRuntime expõe %s()" % candidate)
	for absent in ["assign_excavation_target", "collect_resource_pile",
			"assign_construction_target", "attack_target", "move_to", "set_selected"]:
		_check(not probe.has_method(absent),
				"§93/§63 a Fera não tem a API %s (ela não trabalha nem se move)" % absent)
	probe.free()
	_check(_count_files("res://units/enemies", "*.gd") == 1
			and _count_files("res://units/enemies", "*.tscn") == 1,
			"§22 existe um único Runtime de inimigo no projeto")


func _test_scope_guards() -> void:
	var enemy_source := _source(ENEMY_RUNTIME_SOURCE_PATH)
	for forbidden in ["get_nodes_in_group", "get_first_node_in_group", "find_children",
			"NavigationAgent", "NavMesh", "move_and_slide", "CombatManager", "EnemyManager",
			"ThreatManager", "TargetingComponent", "HealthComponent", "AttackComponent",
			"loot", "experience", "respawn", "patrol", "wander", "agro", "wave", "spawner"]:
		_check(not enemy_source.contains(forbidden),
				"§93/§98 EnemyRuntime não usa %s" % forbidden)
	_check(not enemy_source.contains("func _process("),
			"§33/§106 a Fera não tem loop por frame de render")
	_check(enemy_source.contains("velocity = Vector3.ZERO"),
			"§38 a Fera se fixa no chão: velocity zerada todo tick físico")
	var soldier_source := _source(SOLDIER_RUNTIME_SOURCE_PATH)
	for forbidden in ["get_nodes_in_group", "get_first_node_in_group", "find_children",
			"TargetManager", "auto_target", "nearest", "CombatManager", "loot", "experience",
			"kill_count", "respawn", "projectile"]:
		_check(not soldier_source.contains(forbidden),
				"§98/§29 SoldierRuntime não usa %s (nenhum scan de unidades)" % forbidden)
	for hardcoded in ["12.0", "1.4", "0.75", "48", "80", "6.0", "1.0"]:
		_check(not soldier_source.contains(hardcoded),
				"§4 nenhum número de combate (%s) hardcoded no Runtime do Soldado" % hardcoded)
	for signature in ["func attack_target", "func move_to", "func receive_damage",
			"enum ActionMode"]:
		_check(soldier_source.contains(signature), "§25/§29 SoldierRuntime declara %s" % signature)
	var selection_source := _source(SELECTION_SOURCE_PATH)
	for execution in ["attack_damage", "attack_interval", "receive_damage", "is_dead",
			"queue_free", "get_nodes_in_group", "get_first_node_in_group"]:
		_check(not selection_source.contains(execution),
				"§99/§100 a seleção não executa combate (%s)" % execution)
	_check(not selection_source.contains("Array[WorkerRuntime]")
			and not selection_source.contains("SoldierRuntime")
			and not selection_source.contains("EnemyRuntime"),
			"§19/§20 a seleção não conhece tipos concretos de unidade")
	var hud_source := _source(COMBAT_HUD_SOURCE_PATH)
	for forbidden in ["_process(", "get_nodes_in_group", "attack_damage", "queue_free"]:
		_check(not hud_source.contains(forbidden),
				"§51/§93 o CombatDebugHud não usa %s" % forbidden)
	var main_source := _source(GAME_MAIN_SOURCE_PATH)
	for forbidden in ["EnemySpawner", "WaveManager", "EnemyManager", "CombatManager",
			"ThreatManager", "spawn_enemy(", "for _index in 10"]:
		_check(not main_source.contains(forbidden),
				"§93/§102 GameMain não menciona %s" % forbidden)
	_check(_count_occurrences(main_source, "ENEMY_SCENE.instantiate()") == 1,
			"§24/§42 a composition root planta exatamente 1 Fera")
	for manager in ["CombatManager", "EnemyManager", "ThreatManager", "ICombatant",
			"CombatantBase", "AttackComponent", "HealthComponent", "TargetingComponent",
			"UnitStateBase", "EventBus", "UnitRegistry", "EnemyFactory", "ArmyManager"]:
		_check(not _class_exists(manager) and not _source(GAME_MAIN_SOURCE_PATH).contains(manager),
				"§96/§97/§102 nenhuma classe %s existe nem é referenciada" % manager)
	_check(_source("res://project.godot").contains("3d_physics/layer_6=\"Enemies\""),
			"§13/§15 a camada 6 se chama Enemies no projeto")
	_check(_count_occurrences(_source("res://project.godot"), "3d_physics/layer_") == 6,
			"§100 nenhuma sétima camada física foi criada")
	_check(not _source("res://project.godot").contains("[autoload]"),
			"§97/§103 nenhum autoload/EventBus global foi adicionado")
	_check(_count_files("res://data/units/enemies", "*.tres") == 1,
			"§22/§54 existe uma única Definition de inimigo")


# ------------------------------------------------------------------ Cena real #1


func _test_scene_composition() -> void:
	_enemy = _dungeon.get_node_or_null("Enemy001") as EnemyRuntime
	_check(_enemy != null, "§24 GameMain instancia Enemy001")
	_check(_enemies_in_scene().size() == 1, "§42/§24 a cena tem exatamente 1 Fera, não uma onda")
	if _enemy == null:
		_finish()
		return
	_check(_enemy.state.enemy_id == ENEMY_ID, "§24 o State da Fera é enemy_001")
	_check(_enemy.definition == _enemy_definition(),
			"§5/§24 a Fera recebeu a Definition cave_beast.tres")
	_check(_scene.get("enemy_definition") == _enemy.definition,
			"§24 GameMain exporta a Definition e a injeta, sem new() de números")
	_check(_enemy.global_position.is_equal_approx(ENEMY_SPAWN),
			"§24 a Fera nasceu no EnemySpawnPoint (-3, 0, -12)")
	_check(_enemy.get_parent() == _dungeon, "§24 a Fera entrou no DungeonRoot")
	_check(_close(_enemy.state.health, ENEMY_HP) and _enemy.is_alive(), "§42 a Fera está com 48")
	_check(_enemy.collision_layer == ENEMY_LAYER and _enemy.collision_mask == 0,
			"§15 a Fera ocupa a camada Enemies e não empurra nada (mask 0)")
	_check(not _enemy.is_in_group(&"rts_selectable")
			and _enemy.is_in_group(&"combat_target"), "§16/§63 grupos da Fera")
	_check(not _enemy.is_physics_processing() and _enemy.velocity == Vector3.ZERO,
			"§33/§38 a Fera começa passiva: física desligada e sem velocidade")
	_check(_enemy.combat_target() == null and not _enemy.is_engaged(),
			"§35 sem ordem a Fera não tem combat_target")
	_check(_enemy.find_child("Visual", true, false).visible, "§42 a Fera está visível")
	_check(_close(_enemy.body_radius(), BEAST_RADIUS),
			"§28/§63 em cena, body_radius lê o próprio collider (%f)" % _enemy.body_radius())
	_check(_dungeon.get_node_or_null("EnemySpawnPoint") != null, "§24 EnemySpawnPoint existe")
	_check((_dungeon.get_node("EnemySpawnPoint") as Node3D).get_children().is_empty(),
			"§24 o ponto de spawn não traz coliders próprios")


func _test_enemy_spawn_geometry() -> void:
	var point := (_dungeon.get_node("EnemySpawnPoint") as Node3D).global_position
	_check(point.is_equal_approx(ENEMY_SPAWN), "§24 EnemySpawnPoint em (-3, 0, -12)")
	_check(_ground_body_at(ENEMY_SPAWN) == "TestFloorBody",
			"§87 o ray vertical do spawn cai no chão, obtido %s" % _ground_body_at(ENEMY_SPAWN))
	_check(_shape_clear_at(ENEMY_SPAWN, BEAST_RADIUS + 0.4, OBSTACLES | UNIT_LAYER),
			"§87 nenhuma forma sólida ocupa o EnemySpawnPoint")
	_check(_planar_gap(ENEMY_SPAWN, SOLDIER_SPAWN) > APPROACH_DISTANCE - 0.02
			and _planar_gap(ENEMY_SPAWN, SOLDIER_SPAWN) < APPROACH_DISTANCE + 0.02,
			"§42/§87 a Fera fica a %f do spawn do Soldado"
					% _planar_gap(ENEMY_SPAWN, SOLDIER_SPAWN))
	_check(_planar_gap(ENEMY_SPAWN, SOLDIER_SPAWN) > BEAST_RANGE + 2.0,
			"§87/§68 o Soldado nasce muito fora de qualquer alcance")
	for anchor in [DEPOSIT_POINT, CORE_POINT, WORKER_SPAWN, NEST_POINT, BARRACKS_POINT]:
		_check(_planar_gap(ENEMY_SPAWN, anchor) > 2.5,
				"§88/§87 a Fera está longe de %s" % _name_of(anchor))
	_check(_straight_route_clear(SOLDIER_SPAWN, ENEMY_SPAWN, ""),
			"§87 a rota reta do Soldado até a Fera não cruza nenhuma rocha, folga %f"
					% _route_rock_margin(SOLDIER_SPAWN, ENEMY_SPAWN))
	_check(_route_clear_of_sites(SOLDIER_SPAWN, ENEMY_SPAWN),
			"§87 a rota do Soldado não cruza nenhum canteiro, folga %f"
					% _route_site_margin(SOLDIER_SPAWN, ENEMY_SPAWN))
	_check(_route_clear_of_sites(ENEMY_SPAWN, DEPOSIT_POINT),
			"§88 a rota da Fera até o depósito não cruza nenhum canteiro, folga %f"
					% _route_site_margin(ENEMY_SPAWN, DEPOSIT_POINT))
	for rock in _rocks_in_scene():
		_check(_planar_gap(ENEMY_SPAWN, rock.global_position) > ROCK_HALF + BEAST_RADIUS + 0.4,
				"§87 %s não encosta na Fera (%f)"
						% [rock.rock_id, _planar_gap(ENEMY_SPAWN, rock.global_position)])
	var screen := _body_screen(ENEMY_SPAWN)
	_check(Rect2(Vector2.ZERO, Vector2(root.size)).has_point(screen),
			"§87 a Fera está dentro do campo da câmera (%s de %s)"
					% [str(screen), str(root.size)])
	var hit := _screen_hit(screen, CLICKABLE)
	_check(not hit.is_empty() and hit.collider == _enemy,
			"§20/§87 o ray de clique na Fera devolve a própria Fera")
	_check((_screen_hit(screen, CLICKABLE).collider as CollisionObject3D)
			.get_collision_layer() == ENEMY_LAYER,
			"§20 a ordem de ataque nasce da camada 32, nunca do nome do nó")


func _test_combat_hud_initial() -> void:
	_check(_combat_hud is Control, "§49/§63 CombatDebugHud é um Control")
	_check((_combat_hud as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"§63/§90 o painel usa mouse_filter IGNORE")
	_check(_controls_not_ignoring(_combat_hud).is_empty(),
			"§90 100% dos Controls do CombatDebugHud ignoram o mouse")
	_check(_controls_not_ignoring(_scene.get_node("UI")).is_empty(),
			"§90 nenhum controle da UI captura o mouse")
	_check(not _combat_hud.is_processing() and not _combat_hud.is_physics_processing(),
			"§51/§106 o HUD não tem loop por frame")
	_check(_text_of(_combat_hud, "SoldierLabel") == SOLDIER_LINE,
			"§49/§89 antes do recruta o HUD já mostra %s, obtido %s"
					% [SOLDIER_LINE, _text_of(_combat_hud, "SoldierLabel")])
	_check(_text_of(_combat_hud, "EnemyLabel") == BEAST_LINE,
			"§89 no início o HUD mostra %s, obtido %s"
					% [BEAST_LINE, _text_of(_combat_hud, "EnemyLabel")])


func _test_enemy_not_selectable() -> void:
	_selection.clear_selection()
	_place(_worker, GROUND_SPOT)
	await _advance(0.2)
	_selection.clear_selection()
	var center := _body_screen(ENEMY_SPAWN)
	var worker_screen := _screen(_worker.global_position)
	_check(worker_screen.distance_to(center) > 28.0,
			"§16 a caixa isola a Fera: Worker a %f px, viewport %s"
					% [worker_screen.distance_to(center), str(root.size)])
	_press(MOUSE_BUTTON_LEFT, center - Vector2(10, 10))
	_motion(center)
	_motion(center + Vector2(10, 10))
	_release(MOUSE_BUTTON_LEFT, center + Vector2(10, 10))
	await _advance(0.05)
	_check(_selection.selected_units.is_empty(),
			"§16/§63 a caixa sobre a Fera não seleciona nada, seleção %s" % [_unit_ids()])
	_check(not _selection.selected_units.has(_enemy),
			"§16/§63 a Fera nunca entra em selected_units")
	_check(_worker != null and not _indicator(_worker).visible,
			"§63 a Fera não contamina a seleção existente")


# ----------------------------------------------------------------------- Exército


## Exército do teste: segundo Worker invocado, Quartel pago e concluído pelo State
## (obra real fica coberta na campanha §91) e Soldado recrutado com Essência.
func _prepare_army() -> void:
	_set_essence(20.0)
	_press_key(KEY_I)
	await _advance(0.4)
	_worker2 = _workers_in_scene()[1] if _workers_in_scene().size() == 2 else null
	_check(_worker2 != null and _core_state.population == 2, "a campanha de teste tem 2 Workers")
	_stockpile.add_resource(_iron_ore(), 3)
	_press_key(KEY_K)
	await _advance(0.2)
	var barracks := _construction.barracks()
	if barracks == null:
		_check(false, "o Quartel de teste não abriu")
		_finish()
		return
	barracks.state.apply_work(BARRACKS_WORK)
	await _advance(0.1)
	_check(barracks.is_completed(), "o Quartel de teste foi concluído")
	_set_essence(20.0)
	_press_key(KEY_R)
	await _advance(0.3)
	_soldier = _recruitment.soldier()
	if _soldier == null:
		_check(false, "o Soldado de teste não nasceu")
		_finish()
		return
	_watch_soldier(_soldier.state, SOLDIER_KEY)
	_watch_enemy(_enemy.state, ENEMY_KEY)
	var hit := _screen_hit(_body_screen(ENEMY_SPAWN), CLICKABLE)
	_check(hit.get("collider", null) == _enemy,
			"§20 com Quartel e Ninho do mundo o ray ainda entrega a Fera")
	_check(_core_state.population == 3, "população 3 antes do combate")
	# O exército em si é preparação, não parte do fluxo que cada cena mede depois.
	_population_events.clear()
	_stockpile_events = 0


# ----------------------------------------------------------------------- Combate


func _test_enemy_passive() -> void:
	_place(_soldier, ENEMY_SPAWN + Vector3(STANCE_GAP, 0.0, 0.0))
	await _advance(0.1)
	_reset_watch(ENEMY_KEY)
	_reset_watch(SOLDIER_KEY)
	_check(_soldier.action_mode() == SoldierRuntime.ActionMode.IDLE,
			"§64 o Soldado está ao lado da Fera sem ordem (IDLE)")
	_check(_planar_gap(_soldier.global_position, _enemy.global_position) <= BEAST_RANGE,
			"§64 ele está até dentro do alcance da Fera")
	await _advance(2.0)
	_check(_close(_enemy.state.health, ENEMY_HP) and _close(_soldier.state.health, SOLDIER_HP),
			"§64 sem ordem ninguém perde vida: Fera %f, Soldado %f"
					% [_enemy.state.health, _soldier.state.health])
	_check(_strike_count(ENEMY_KEY) == 0 and _strike_count(SOLDIER_KEY) == 0,
			"§64/§93 nenhum ataque automático aconteceu")
	_check(not _enemy.is_engaged() and _enemy.combat_target() == null,
			"§35/§64 a Fera não se auto-engajou")
	_check(not _enemy.is_physics_processing(),
			"§33 a Fera continua sem executar física nenhuma")
	_check(_enemy.velocity == Vector3.ZERO
			and _enemy.global_position.is_equal_approx(ENEMY_SPAWN),
			"§38/§93 a Fera não saiu do lugar")


func _test_worker_rmb_enemy() -> void:
	_place(_worker, SITE_LEFT)
	_place(_worker2, SITE_RIGHT)
	_place(_soldier, SOLDIER_SPAWN)
	await _advance(0.1)
	_selection.clear_selection()
	await _click_select(_worker)
	await _shift_click_select(_worker2)
	_check(_unit_ids() == ["worker_001", "worker_002"],
			"§65 a seleção é só dos dois Workers, ordem %s" % [_unit_ids()])
	var before_left := _worker.global_position
	var before_right := _worker2.global_position
	var soldier_before := _soldier.global_position
	# Worker para de andar sem trocar de ActionMode (herança das tarefas 5-10), então
	# o que §65 exige é estado idêntico ao de antes da ordem, não um modo específico.
	var mode_left := _worker.action_mode()
	var mode_right := _worker2.action_mode()
	_reset_watch(ENEMY_KEY)
	_reset_watch(SOLDIER_KEY)
	_right_click(_body_screen_position(ENEMY_SPAWN))
	await _advance(1.0)
	_check(not _worker.has_move_target() and not _worker2.has_move_target(),
			"§65 os Workers não receberam MOVE ao clicar na Fera")
	_check(_worker.global_position.is_equal_approx(before_left)
			and _worker2.global_position.is_equal_approx(before_right),
			"§65 os Workers ficaram exatamente onde estavam")
	_check(_worker.action_mode() == mode_left and _worker2.action_mode() == mode_right,
			"§65 os Workers mantiveram o próprio estado antes e depois da ordem (%d e %d)"
					% [_worker.action_mode(), _worker2.action_mode()])
	_check(not _worker.is_excavating() and not _worker.is_building()
			and _worker.action_mode() != WorkerRuntime.ActionMode.COLLECT,
			"§65 os Workers não receberam trabalho nenhum")
	_check(not _enemy.is_engaged() and _strike_count(ENEMY_KEY) == 0
			and _strike_count(SOLDIER_KEY) == 0,
			"§65 a Fera não entrou em combate com os Workers")
	_check(_soldier.action_mode() == SoldierRuntime.ActionMode.IDLE
			and _soldier.global_position.is_equal_approx(soldier_before),
			"§65 o Soldado, fora da seleção, não atacou sozinho")


func _test_soldier_rmb_enemy() -> void:
	_place(_soldier, SOLDIER_SPAWN)
	await _advance(0.1)
	_selection.clear_selection()
	await _click_select(_soldier)
	_check(_unit_ids() == [SOLDIER_KEY],
			"§66 a seleção é exatamente o Soldado, obtido %s" % [_unit_ids()])
	_reset_watch(ENEMY_KEY)
	_right_click(_body_screen_position(ENEMY_SPAWN))
	await _advance(0.05)
	_check(_soldier.action_mode() == SoldierRuntime.ActionMode.ATTACK,
			"§66/§20 RMB real sobre a Fera pôs o Soldado em ATTACK")
	_check(_soldier.current_attack_target() == _enemy,
			"§26/§66 o alvo registrado é a própria EnemyRuntime")
	_check(_enemy.is_engaged() and _enemy.combat_target() == _soldier,
			"§35 a ordem fez a Fera adotar o Soldado como combat_target")
	_check(_soldier.is_physics_processing() and _enemy.is_physics_processing(),
			"§29/§36 os dois passaram a executar física")
	_check(_close(_soldier.attack_cooldown(), SOLDIER_INTERVAL),
			"§30/§71 o cooldown arma cheio (%f), obtido %f"
					% [SOLDIER_INTERVAL, _soldier.attack_cooldown()])
	_check(_close(_enemy.state.health, ENEMY_HP),
			"§66 nenhum golpe instantâneo na ordem: Fera %f" % _enemy.state.health)
	_check(_strike_count(ENEMY_KEY) == 0, "§66/§99 a seleção só entregou a ordem, não calculou dano")


func _test_approach_and_stance() -> void:
	var start := _soldier.global_position
	_check(_planar_gap(start, ENEMY_SPAWN) > SOLDIER_RANGE,
			"§68 o Soldado começa fora do alcance (%f)" % _planar_gap(start, ENEMY_SPAWN))
	await _advance(0.4)
	var moved := _planar_gap(start, _soldier.global_position)
	_check(moved > 0.5, "§68 a posição do Soldado mudou %f rumo à Fera" % moved)
	_check(_soldier.velocity.length() > 3.0,
			"§68 ele anda na velocidade da Definition, obtido %f" % _soldier.velocity.length())
	var stance_gap := _planar_gap(_soldier.global_position, _enemy.global_position)
	_check(stance_gap < _planar_gap(start, ENEMY_SPAWN),
			"§68 a distância até a Fera caiu para %f" % stance_gap)
	var arrived := await _wait_until(func() -> bool: return _is_in_stance(_soldier, _enemy), 8.0)
	_check(arrived, "§68/§69 o Soldado parou na postura de golpe")
	if not arrived:
		_finish()
		return
	var stance := _soldier.global_position
	_check(_planar_gap(stance, _enemy.global_position) <= SOLDIER_RANGE + 0.05,
			"§68 a parada é dentro de attack_range + tolerância (%f)"
					% _planar_gap(stance, _enemy.global_position))
	_check(_close(_planar_gap(stance, _enemy.global_position), STANCE_GAP, 0.05),
			"§28/§69 a postura ficou a %f da Fera, esperado %f"
					% [_planar_gap(stance, _enemy.global_position), STANCE_GAP])
	_check(_soldier.velocity == Vector3.ZERO, "§69 ao entrar em alcance a velocidade é ZERO")
	await _advance(0.1)
	_check(_strike_count(ENEMY_KEY) == 0,
			"§71/§30 ainda não houve golpe: o intervalo de %f não completou" % SOLDIER_INTERVAL)
	_check(_soldier.velocity == Vector3.ZERO,
			"§69 durante a troca de golpes a velocidade continua ZERO, obtido %s"
					% str(_soldier.velocity))
	_check(_soldier.global_position.is_equal_approx(stance),
			"§69 o Soldado não empurra contra a Fera: ficou em %s" % str(_soldier.global_position))
	_check(not _sphere_hits(_soldier.global_position + Vector3(0.0, 0.4, 0.0),
			_soldier.body_radius(), ENEMY_LAYER),
			"§70/§28 query física: nenhum collider da Fera dentro do corpo do Soldado")
	_check(_planar_gap(_soldier.global_position, _enemy.global_position)
			>= BEAST_RADIUS + SOLDIER_RADIUS,
			"§70 distância dos centros maior que a soma dos raios (%f)"
					% _planar_gap(_soldier.global_position, _enemy.global_position))


func _test_first_hit() -> void:
	await _advance(0.5)
	_check(_close(_enemy.state.health, ENEMY_HP),
			"§71 aos 0.6 s do alcance a Fera ainda tem 48, obtido %f" % _enemy.state.health)
	_check(_text_of(_combat_hud, "EnemyLabel") == BEAST_LINE,
			"§89 o HUD ainda mostra a Fera inteira, obtido %s"
					% _text_of(_combat_hud, "EnemyLabel"))
	await _advance(0.3)
	_check(_close(_enemy.state.health, 36.0),
			"§71 depois de 0.75 s a Fera cai para 36, obtido %f" % _enemy.state.health)
	_check(_strike_count(ENEMY_KEY) == 1,
			"§71 exatamente 1 golpe no primeiro intervalo, obtido %d" % _strike_count(ENEMY_KEY))
	_check(_close(_damage_total(ENEMY_KEY), SOLDIER_DAMAGE),
			"§53/§71 o golpe trouxe 12 de dano da Definition, obtido %f"
					% _damage_total(ENEMY_KEY))
	_check(_close(_soldier.state.health, SOLDIER_HP),
			"§74/§34 a Fera ainda não revidou antes do próprio intervalo de 1.0 s")
	_check(_text_of(_combat_hud, "EnemyLabel") == "Fera Cavernosa: 36 / 48 HP",
			"§89/§51 o HUD mudou por signal para 36 / 48, obtido %s"
					% _text_of(_combat_hud, "EnemyLabel"))


func _test_attack_interval() -> void:
	_reset_watch(ENEMY_KEY)
	_reset_watch(SOLDIER_KEY)
	await _advance(1.5)
	var ticks := int(1.5 * Engine.get_physics_ticks_per_second())
	_check(_strike_count(ENEMY_KEY) == 2,
			"§72 em mais 1.5 s de postura o Soldado deu 2 golpes (um por 0.75 s), obtido %d"
					% _strike_count(ENEMY_KEY))
	_check(_strike_count(ENEMY_KEY) < ticks,
			"§72/§31 nunca 1 golpe por frame: %d golpes em %d ticks"
					% [_strike_count(ENEMY_KEY), ticks])
	_check(_close(_damage_total(ENEMY_KEY), 24.0),
			"§72 o dano da janela é 2 × 12 = 24, obtido %f" % _damage_total(ENEMY_KEY))
	_check(_close(_enemy.state.health, 12.0),
			"§72 a Fera ficou com 12 de vida, obtido %f" % _enemy.state.health)
	_check(_enemy.is_alive() and _soldier.state.health > 0.0,
			"§72 ninguém morreu ainda: o duelo continua controlável")
	_check(_planar_gap(_soldier.global_position, _enemy.global_position)
			<= SOLDIER_RANGE + 0.05, "§72 a postura se manteve durante toda a janela")


func _test_retaliation() -> void:
	_check(_enemy.is_engaged() and _enemy.combat_target() == _soldier,
			"§35/§36 a Fera continua com o Soldado como combat_target")
	_check(_planar_gap(_soldier.global_position, _enemy.global_position) <= BEAST_RANGE,
			"§74 o Soldado está dentro do alcance de 1.2 da Fera (%f)"
					% _planar_gap(_soldier.global_position, _enemy.global_position))
	_check(_strike_count(SOLDIER_KEY) == 2,
			"§74 na mesma janela a Fera revidou 2 vezes (intervalo de 1.0 s), obtido %d"
					% _strike_count(SOLDIER_KEY))
	_check(_close(_damage_total(SOLDIER_KEY), 12.0),
			"§74/§54 a retaliação somou 12 de dano, obtido %f" % _damage_total(SOLDIER_KEY))
	_check(_close(_damage_total(SOLDIER_KEY) / maxf(1.0, float(_strike_count(SOLDIER_KEY))),
			BEAST_DAMAGE),
			"§74/§54 cada golpe da Fera vale exatamente 6, obtido %f"
					% (_damage_total(SOLDIER_KEY) / float(_strike_count(SOLDIER_KEY))))
	_check(_close(_soldier.state.health, 68.0),
			"§74/§43 o Soldado caiu de 80 para 68, obtido %f" % _soldier.state.health)
	_check(_text_of(_combat_hud, "SoldierLabel") == "Soldado: 68 / 80 HP",
			"§89 o HUD mostra o Soldado ferido, obtido %s"
					% _text_of(_combat_hud, "SoldierLabel"))
	_check(_enemy.velocity == Vector3.ZERO, "§38/§93 a Fera revida sem se mover")


func _test_cancellation() -> void:
	var enemy_health := _enemy.state.health
	var soldier_health := _soldier.state.health
	_check(enemy_health < ENEMY_HP and soldier_health < SOLDIER_HP,
			"§76 o cancelamento parte de um combate real (%f vs %f)"
					% [enemy_health, soldier_health])
	_selection.clear_selection()
	await _click_select(_soldier)
	_right_click(CANCEL_POINT)
	await _advance(0.05)
	_check(_soldier.action_mode() == SoldierRuntime.ActionMode.MOVE,
			"§76/§37 RMB no chão devolve o Soldado para MOVE")
	_check(_soldier.current_attack_target() == null,
			"§37/§76 o attack target do Soldado foi limpo")
	_check(not _enemy.is_engaged() and _enemy.combat_target() == null,
			"§37/§76 a Fera limpou o próprio combat_target")
	_check(not _enemy.is_physics_processing(), "§37 a Fera voltou a não executar física")
	_reset_watch(ENEMY_KEY)
	_reset_watch(SOLDIER_KEY)
	await _advance(2.0)
	_check(_strike_count(ENEMY_KEY) == 0 and _strike_count(SOLDIER_KEY) == 0,
			"§76/§37 nenhum golpe depois do cancelamento (%d e %d)"
					% [_strike_count(ENEMY_KEY), _strike_count(SOLDIER_KEY)])
	_check(_close(_enemy.state.health, enemy_health)
			and _close(_soldier.state.health, soldier_health),
			"§76 as duas vidas congelaram no cancelamento")
	var away := await _wait_until(func() -> bool: return not _soldier.has_move_target(), 6.0)
	_check(away, "§76 o Soldado terminou a marcha de fuga")
	_check(_planar_gap(_soldier.global_position, _enemy.global_position) > SOLDIER_RANGE,
			"§76 ele ficou fora de alcance (%f)"
					% _planar_gap(_soldier.global_position, _enemy.global_position))


func _test_resume_keeps_hp() -> void:
	var enemy_health := _enemy.state.health
	var soldier_health := _soldier.state.health
	_check(enemy_health > 0.0 and enemy_health < ENEMY_HP,
			"§77 a Fera está ferida e viva (%f)" % enemy_health)
	_selection.clear_selection()
	await _click_select(_soldier)
	_right_click(_body_screen_position(ENEMY_SPAWN))
	await _advance(0.05)
	_check(_soldier.action_mode() == SoldierRuntime.ActionMode.ATTACK,
			"§77/§26 a nova ordem reabriu ATTACK")
	_check(_soldier.current_attack_target() == _enemy and _enemy.is_engaged(),
			"§77 os dois voltaram a se apontar")
	_check(_close(_enemy.state.health, enemy_health),
			"§77 a Fera mantém o HP anterior, não reseta para 48: %f vs %f"
					% [_enemy.state.health, enemy_health])
	_check(_close(_soldier.state.health, soldier_health),
			"§77 o Soldado mantém o HP anterior, não reseta para 80: %f" % _soldier.state.health)
	_check(not _is_in_stance(_soldier, _enemy),
			"§77/§68 o recomeço obriga nova aproximação")
	# Uma Fera de 48 de vida morreria no duelo de controle antes das cenas seguintes.
	# O heal vem do próprio EnemyState (§55) e é chamado pelo harness, não por uma IA
	# de cura — manter a Fera viva é o que permite provar §75 e §77 até o fim.
	_enemy.state.heal(24.0)
	_check(_close(_enemy.state.health, 36.0),
			"§77/§55 o harness devolveu vida pela API do State, obtido %f"
					% _enemy.state.health)
	_reset_watch(ENEMY_KEY)
	_reset_watch(SOLDIER_KEY)


func _test_enemy_out_of_range() -> void:
	var gap := _planar_gap(_soldier.global_position, _enemy.global_position)
	_check(_enemy.is_engaged(), "§75 a Fera está engajada por ordem legítima")
	_check(gap > BEAST_RANGE + 1.0,
			"§75 e o Soldado está a %f, bem fora do alcance de 1.2" % gap)
	await _advance(0.8)
	_check(_strike_count(SOLDIER_KEY) == 0,
			"§75/§36 fora de alcance a Fera não causa dano nenhum")
	_check(_strike_count(ENEMY_KEY) == 0,
			"§75/§27 fora de alcance o Soldado também não golpeia")
	_check(_close(_soldier.state.health, SOLDIER_HP - 12.0),
			"§75 a vida do Soldado não mudou na reaproximação, obtido %f"
					% _soldier.state.health)
	var arrived := await _wait_until(func() -> bool: return _is_in_stance(_soldier, _enemy), 8.0)
	_check(arrived, "§77 o combate reiniciado chegou de fato à troca de golpes")
	_reset_watch(ENEMY_KEY)
	_reset_watch(SOLDIER_KEY)
	await _advance(1.6)
	_check(_strike_count(ENEMY_KEY) == 2 and _strike_count(SOLDIER_KEY) == 1,
			"§77 retomada produziu golpes dos dois lados (%d do Soldado, %d da Fera)"
					% [_strike_count(ENEMY_KEY), _strike_count(SOLDIER_KEY)])
	_check(_close(_enemy.state.health, 12.0) and _enemy.is_alive(),
			"§77/§75 a Fera ferida segue viva no duelo retomado, obtido %f"
					% _enemy.state.health)
	_check(_close(_soldier.state.health, SOLDIER_HP - 18.0),
			"§74 a retaliação retomada tirou mais 6 do Soldado, obtido %f"
					% _soldier.state.health)


func _test_systems_survive_control_flow() -> void:
	_check(_core_state.population == 3, "§105 a população não mudou durante o vai-e-vem")
	_check(_population_events.is_empty(),
			"§105 nenhum evento de população no controle, eventos %s" % [_population_events])
	_check(_stockpile_events == 0, "§105 nenhum recurso apareceu por combate")
	_check(_close(_core_state.essence, 5.0),
			"§105 a Essência continua a mesma do recruta, obtido %f" % _core_state.essence)
	_check(_nests_in_scene().is_empty(), "§105/§93 a Fera não invocou prédios nem nada")
	_check(_worker.is_in_group(&"rts_selectable")
			and _soldier.is_in_group(&"rts_selectable"),
			"§105 Workers e Soldado seguem selecionáveis")
	await _click_select(_worker)
	_right_click(GROUND_SPOT)
	await _advance(0.4)
	_check(_worker.action_mode() == WorkerRuntime.ActionMode.MOVE
			or _worker.has_move_target(),
			"§105 o comando de movimento do Worker segue vivo")


# --------------------------------------------------------------- Cena real #2: duelo


func _test_default_duel() -> void:
	_place(_soldier, SOLDIER_SPAWN)
	await _advance(0.1)
	_selection.clear_selection()
	await _click_select(_soldier)
	_reset_watch(ENEMY_KEY)
	_reset_watch(SOLDIER_KEY)
	_death_report.clear()
	_capture_enemy_death(_enemy)
	_stockpile_events = 0
	var essence_before := _core_state.essence
	var population_before := _core_state.population
	var stockpile_before := _stockpile.get_amount(ORE)
	_population_events.clear()
	var start := _soldier.global_position
	_right_click(_body_screen_position(ENEMY_SPAWN))
	await _advance(0.05)
	_check(_soldier.action_mode() == SoldierRuntime.ActionMode.ATTACK,
			"§85 o duelo padrão começa pela ordem do jogador")
	var approach := await _time_until(func() -> bool: return _is_in_stance(_soldier, _enemy), 8.0)
	_check(approach > 0.5 and approach < 4.0,
			"§85/§42 aproximação medida em %f s para %f unidades"
					% [approach, _planar_gap(start, ENEMY_SPAWN)])
	_check(_close(_planar_gap(_soldier.global_position, _enemy.global_position),
			STANCE_GAP, 0.05), "§85/§28 o duelo começa da postura %f" % STANCE_GAP)
	_reset_watch(ENEMY_KEY)
	_reset_watch(SOLDIER_KEY)
	var combat_time := await _time_until(
			func() -> bool: return _died_count(ENEMY_KEY) > 0, 12.0)
	_check(_died_count(ENEMY_KEY) == 1,
			"§78/§59 died da Fera chegou a 1, obtido %d" % _died_count(ENEMY_KEY))
	_check(combat_time > 2.5 and combat_time < 3.6,
			"§85 tempo puro de combate %f s (4 golpes de 0.75 s)" % combat_time)
	_check(_strike_count(ENEMY_KEY) == 4,
			"§85/§72 o Soldado deu 4 golpes para somar 48, obtido %d"
					% _strike_count(ENEMY_KEY))
	_check(_damage_total(ENEMY_KEY) == ENEMY_HP,
			"§85 o dano total do duelo é exatamente a vida da Fera, obtido %f"
					% _damage_total(ENEMY_KEY))
	_check(_strike_count(SOLDIER_KEY) == 2 or _strike_count(SOLDIER_KEY) == 3,
			"§85/§74 a Fera revidou 2 ou 3 vezes no scheduling, obtido %d"
					% _strike_count(SOLDIER_KEY))
	_check(_soldier.state != null and is_instance_valid(_soldier),
			"§86 o Soldado sobreviveu ao duelo padrão")
	_check(_soldier.state.health > 60.0 and _soldier.state.health < SOLDIER_HP,
			"§85/§86 HP final do Soldado entre 60 e 80, obtido %f" % _soldier.state.health)
	# O Node se liberta ao morrer; o State continua vivo porque a watch o referencia,
	# então §78 é provado pelo State e não por acesso a objeto freed.
	var final_enemy_state := _live_states.get(ENEMY_KEY) as EnemyState
	_check(final_enemy_state != null and final_enemy_state.health <= 0.0
			and final_enemy_state.is_dead(), "§78 a Fera zerou")
	_soldier_health_after_duel = _soldier.state.health
	_duel_report = {
		"approach": approach, "combat": combat_time,
		"soldier_strikes": _strike_count(ENEMY_KEY),
		"beast_strikes": _strike_count(SOLDIER_KEY),
		"final_hp": _soldier.state.health,
		"essence": essence_before, "population": population_before,
		"stockpile": stockpile_before,
	}
	_check(_death_report.get("visual_hidden", false), "§78/§41 o visual da Fera foi escondido")
	_check(_death_report.get("collider_disabled", false), "§78/§41 o collider da Fera foi desativado")
	_check(_death_report.get("layer_zero", false), "§15/§78 a camada da Fera virou 0")
	_check(_death_report.get("still_engaged", true) == false,
			"§37/§78 a Fera se desengajou ao morrer")


func _test_death_consequences() -> void:
	await _advance(0.3)
	_check(_enemies_in_scene().is_empty(), "§78 o EnemyRuntime foi removido da cena")
	_check(not is_instance_valid(_enemy), "§78/§41 a instância da Fera se libertou")
	var only_friends: bool = _selection.selected_units.is_empty() \
			or (_selection.selected_units.size() == 1
					and _selection.selected_units[0] == _soldier)
	_check(only_friends,
			"§63/§98 a seleção só guarda unidades amigas, nunca a Fera (%d itens)"
					% _selection.selected_units.size())
	_check(_soldier.action_mode() == SoldierRuntime.ActionMode.IDLE,
			"§79/§40 ATTACK virou IDLE quando o alvo sumiu")
	_check(_soldier.velocity == Vector3.ZERO and not _soldier.has_move_target(),
			"§79 o Soldado parou no lugar, sem velocidade nem destino")
	_check(_soldier.current_attack_target() == null, "§79/§40 nenhum attack target pendurado")
	_check(not _soldier.is_physics_processing(),
			"§29/§106 sem alvo o Soldado desliga a própria física")
	_check(_soldier.is_in_group(&"rts_selectable"), "§79 o Soldado continua selecionável")
	_check(_piles_in_scene().is_empty(),
			"§80/§93 nenhuma pilha de loot nasceu da morte, obtido %d"
					% _piles_in_scene().size())
	_check(_stockpile_events == 0, "§80/§93 o estoque não recebeu recurso da morte")
	_check(_stockpile.get_amount(ORE) == _duel_report.get("stockpile", 0),
			"§80 o estoque continua %d" % _duel_report.get("stockpile", 0))
	_check(_close(_core_state.essence, float(_duel_report.get("essence", 0.0))),
			"§80/§93 nenhuma recompensa de Essência, obtido %f" % _core_state.essence)
	_check(_core_state.population == _duel_report.get("population", 0),
			"§81/§43 Population continua %d depois de matar a Fera" % _core_state.population)
	_check(_population_events.is_empty(),
			"§81 nenhum sinal de população na morte do inimigo, eventos %s"
					% [_population_events])
	await _advance(1.0)
	_check(_died_count(ENEMY_KEY) == 1, "§59/§78 died continuou 1, obtido %d" % _died_count(ENEMY_KEY))
	_check(_text_of(_combat_hud, "EnemyLabel") == "Fera Cavernosa: derrotada",
			"§89/§49/§50 o HUD fechou com 'derrotada' por signal, obtido %s"
					% _text_of(_combat_hud, "EnemyLabel"))
	_check(_text_of(_combat_hud, "SoldierLabel")
			== "Soldado: %d / 80 HP" % roundi(_soldier_health_after_duel),
			"§89 a linha do Soldado reflete o HP real, obtido %s"
					% _text_of(_combat_hud, "SoldierLabel"))
	_check(_text_of(_core_hud, "PopulationLabel") == "Population: 3 / 8",
			"§105 o HUD do núcleo continua coerente, obtido %s"
					% _text_of(_core_hud, "PopulationLabel"))
	_selection.clear_selection()
	await _click_select(_soldier)
	_right_click(GROUND_SPOT)
	await _advance(0.6)
	_check(_soldier.action_mode() == SoldierRuntime.ActionMode.MOVE
			or _soldier.has_move_target(),
			"§79 depois do duelo o Soldado ainda aceita ordem de movimento")
	_check(_enemies_in_scene().is_empty() and _dungeon.get_children().size() > 0,
			"§79 sem Fera o resto do mundo segue intacto")


func _test_fps_independence() -> void:
	var at_30 := await _duel_sample_at(30, PROBE_A_SPOT)
	var at_120 := await _duel_sample_at(120, PROBE_B_SPOT)
	Engine.set_physics_ticks_per_second(60)
	await _advance(0.2)
	var dealt_30 := float(at_30["dealt"])
	var dealt_120 := float(at_120["dealt"])
	var received_30 := float(at_30["received"])
	var received_120 := float(at_120["received"])
	var strikes_30 := int(at_30["strikes"])
	var strikes_120 := int(at_120["strikes"])
	_check(dealt_30 > 0.0 and dealt_120 > 0.0,
			"§73 os dois rates produziram dano real (%f e %f)" % [dealt_30, dealt_120])
	_check(_close(dealt_30, dealt_120),
			"§73 o dano causado em 2.4 s é igual a 30 Hz e 120 Hz (%f vs %f)"
					% [dealt_30, dealt_120])
	_check(_close(received_30, received_120),
			"§73/§32 a retaliação na mesma janela é igual (%f vs %f)"
					% [received_30, received_120])
	_check(strikes_30 == strikes_120,
			"§73 contagem de golpes equivalente (%d vs %d)" % [strikes_30, strikes_120])
	_check(_close(dealt_30, 36.0) and _close(received_30, 12.0),
			"§73 o resultado esperado é 36 causado e 12 recebido, obtido %f/%f"
					% [dealt_30, received_30])


## Uma Fera-irmã criada só pelo teste, com a Definition real, para medir a mesma
## janela de combate em outro rate físico.
func _duel_sample_at(ticks_per_second: int, spot: Vector3) -> Dictionary:
	Engine.set_physics_ticks_per_second(ticks_per_second)
	await _advance(0.15)
	var key := "fps_probe_%d" % ticks_per_second
	var probe := _spawn_probe_enemy(key, spot)
	_place(_soldier, PROBE_STAGING)
	await _advance(0.15)
	_selection.clear_selection()
	await _click_select(_soldier)
	_watch_enemy(probe.state, key)
	_reset_watch(key)
	_watch_soldier(_soldier.state, SOLDIER_KEY)
	_reset_watch(SOLDIER_KEY)
	_right_click(_body_screen_position(spot))
	await _advance(0.05)
	var arrived := await _wait_until(func() -> bool: return _is_in_stance(_soldier, probe), 12.0)
	_check(arrived, "§73 a postura foi alcançada a %d Hz" % ticks_per_second)
	_reset_watch(key)
	_reset_watch(SOLDIER_KEY)
	await _advance(2.4)
	var result := {
		"dealt": _damage_total(key),
		"received": _damage_total(SOLDIER_KEY),
		"strikes": _strike_count(key),
	}
	_selection.clear_selection()
	await _click_select(_soldier)
	_right_click(GROUND_SPOT)
	await _advance(0.4)
	_dungeon.remove_child(probe)
	probe.free()
	return result


# ------------------------------------------------------------ Cena real #3: morte


func _test_soldier_death() -> void:
	_check(_core_state.population == 3 and _core_state.get_population_capacity() == 8,
			"§84 o duelo de morte começa com Population 3 / 8, obtido %d / %d"
					% [_core_state.population, _core_state.get_population_capacity()])
	var definition := EnemyDefinition.new()
	definition.enemy_type_id = &"test_beast"
	definition.display_name = "Fera de Teste"
	definition.max_health = 400.0
	definition.attack_damage = 999.0
	definition.attack_range = 1.5
	definition.attack_interval = 0.5
	var key := "death_probe"
	var probe := ENEMY_SCENE.instantiate() as EnemyRuntime
	probe.name = "DeathProbe"
	probe.setup(definition, EnemyState.new(definition, key))
	_dungeon.add_child(probe)
	probe.global_position = DEATH_PROBE_SPOT
	await _advance(0.15)
	_watch_enemy(probe.state, key)
	_place(_soldier, DEATH_STAGING)
	await _advance(0.15)
	_death_report.clear()
	_capture_soldier_death(_soldier)
	var soldier_state := _soldier.state
	_population_events.clear()
	_selection.clear_selection()
	await _click_select(_soldier)
	await _shift_click_select(_worker)
	var aimed := _screen_hit(_body_screen(DEATH_PROBE_SPOT), ENEMY_LAYER)
	_check(aimed.get("collider") == probe,
			"§82/§98 o ray do RMB cai exatamente sobre a Fera de teste, obtido %s"
					% str(aimed.get("collider")))
	_right_click(_body_screen_position(DEATH_PROBE_SPOT))
	await _advance(0.05)
	_check(_soldier.action_mode() == SoldierRuntime.ActionMode.ATTACK,
			"§82 o Soldado atacou a Fera forte de teste")
	var died := await _wait_until(func() -> bool: return _died_count(SOLDIER_KEY) > 0, 10.0)
	_check(died, "§82/§60 o Soldado morreu pelo fluxo real de combate")
	if not died:
		_finish()
		return
	_check(_close(soldier_state.health, 0.0) and soldier_state.is_dead(), "§82 a vida zerou")
	_check(_died_count(SOLDIER_KEY) == 1,
			"§82/§60 died do Soldado disparou uma única vez, obtido %d"
					% _died_count(SOLDIER_KEY))
	_check(_death_report.get("soldier_visual_hidden", false), "§82 o visual sumiu")
	_check(_death_report.get("soldier_collider_disabled", false), "§82 o collider foi desativado")
	_check(_death_report.get("soldier_layer_zero", false), "§82 a camada do Soldado virou 0")
	_check(_death_report.get("soldier_indicator_off", false),
			"§83 o indicador de seleção do Soldado apagou na morte")
	_check(_death_report.get("soldier_unselected_group", false),
			"§83/§48 o Soldado saiu do grupo rts_selectable ao morrer")
	await _advance(0.3)
	_check(_soldiers_in_scene().is_empty(), "§82/§45 o SoldierRuntime saiu da cena")
	_check(not is_instance_valid(_soldier), "§82 a instância se libertou")
	_check(_core_state.population == 2,
			"§82/§43 Population caiu de 3 para 2, obtido %d" % _core_state.population)
	_check(_population_events == ["2/8"],
			"§84/§46 o único evento de população foi 2/8, eventos %s" % [_population_events])
	_check(not probe.is_engaged() and probe.combat_target() == null,
			"§82/§37 a Fera largou o combat_target morto")
	_check(not probe.is_physics_processing(), "§33/§37 sem alvo válido a Fera desliga a física")
	_check(_died_count(ENEMY_KEY) == 0, "§82 a Fera real nunca se envolveu")
	_check(_close(_enemy.state.health, ENEMY_HP),
			"§82 a Fera real segue com 48, obtido %f" % _enemy.state.health)
	_check(_piles_in_scene().is_empty(), "§93 nenhuma pilha de loot na morte do Soldado")
	# §83: a seleção ainda segura referências derrotadas até o próximo input.
	var held := 0
	for unit in _selection.selected_units:
		if is_instance_valid(unit):
			held += 1
	_check(_selection.selected_units.size() > held,
			"§83 antes do próximo input a lista ainda tem a referência morta")
	_right_click(GROUND_SPOT)
	await _advance(0.1)
	var clean := true
	for unit in _selection.selected_units:
		if not is_instance_valid(unit):
			clean = false
	_check(clean, "§83/§48 nenhum objeto inválido ficou em selected_units")
	_check(_selection.selected_units.size() == 1,
			"§83 só o Worker sobreviveu à limpeza, obtido %d"
					% _selection.selected_units.size())
	_right_click(GROUND_SPOT)
	await _advance(0.5)
	_check(_worker.has_move_target()
			or _worker.action_mode() == WorkerRuntime.ActionMode.MOVE,
			"§83/§45 RMB no chão depois da morte não gera erro e segue funcionando")
	soldier_state.damage(50.0)
	soldier_state.damage(50.0)
	await _advance(1.0)
	_check(_died_count(SOLDIER_KEY) == 1,
			"§84/§60 died não se repetiu com dano extra, obtido %d" % _died_count(SOLDIER_KEY))
	_check(_core_state.population == 2,
			"§84 Population continua 2 depois de frames extras, obtido %d"
					% _core_state.population)
	_check(_population_events == ["2/8"],
			"§84 nenhum sinal novo de população, eventos %s" % [_population_events])
	_check(not _recruitment.can_recruit(),
			"§47/§82 a morte não libera um Soldado substituto nesta tarefa")
	_press_key(KEY_R)
	await _advance(0.3)
	_check(_soldiers_in_scene().is_empty(), "§47/§82 R depois da morte não cria outro Soldado")
	_check(_core_state.population == 2, "§82 a população continua 2 após R recusado")
	_dungeon.remove_child(probe)
	probe.free()


# --------------------------------------------------------- Cena real #4: campanha


func _test_real_campaign() -> void:
	var ore := _iron_ore()
	_check(_enemies_in_scene().size() == 1 and _core_state.population == 1,
			"§91 a campanha começa com 1 Worker e 1 Fera passiva")
	_check(_close(_stockpile.get_amount(ORE), 0), "§91 estoque 0")

	_invoke_second_worker()
	await _advance(0.4)
	_worker2 = _workers_in_scene()[1] if _workers_in_scene().size() == 2 else null
	_check(_worker2 != null and _core_state.population == 2, "§91-1 o segundo Worker foi criado")

	await _mine_with_two_workers(_rock_with_id(FIRST_ORE_ROCK_ID))
	_check(_stockpile.get_amount(ORE) == 3,
			"§91-2 a primeira rocha rendeu 3 Minério com a Fera no mundo, obtido %d"
					% _stockpile.get_amount(ORE))

	_press_key(KEY_B)
	await _advance(0.2)
	var nest := _construction.nest()
	_check(nest != null, "§91-3 B abriu o canteiro do Ninho com a Fera presente")
	if nest == null:
		_finish()
		return
	_place(_worker, Vector3(NEST_POINT.x + 1.5, 0.0, NEST_POINT.z + 0.9))
	_place(_worker2, Vector3(NEST_POINT.x + 1.5, 0.0, NEST_POINT.z - 0.9))
	await _advance(0.1)
	_selection.clear_selection()
	await _click_select(_worker)
	await _shift_click_select(_worker2)
	_right_click(nest.global_position)
	var nest_done := await _wait_until(func() -> bool: return nest.is_completed(), 30.0)
	_check(nest_done, "§91-3 os Workers concluíram o Ninho sem a Fera bloquear a obra")
	_check(_core_state.get_population_capacity() == 12, "§91-4 a capacidade virou 12")

	await _mine_with_two_workers(_rock_with_id(SECOND_ORE_ROCK_ID))
	_check(_stockpile.get_amount(ORE) == 3,
			"§91-5 a segunda rocha rendeu 3 Minério, obtido %d" % _stockpile.get_amount(ORE))

	_set_essence(20.0)
	_press_key(KEY_K)
	await _advance(0.2)
	var barracks := _construction.barracks()
	_check(barracks != null, "§91-6 K abriu o canteiro do Quartel")
	if barracks == null:
		_finish()
		return
	_place(_worker, Vector3(BARRACKS_POINT.x + 1.5, 0.0, BARRACKS_POINT.z + 0.9))
	_place(_worker2, Vector3(BARRACKS_POINT.x + 1.5, 0.0, BARRACKS_POINT.z - 0.9))
	await _advance(0.1)
	_selection.clear_selection()
	await _click_select(_worker)
	await _shift_click_select(_worker2)
	_right_click(barracks.global_position)
	var barracks_done := await _wait_until(func() -> bool: return barracks.is_completed(), 30.0)
	_check(barracks_done, "§91-7 a obra do Quartel terminou com a Fera no mapa")

	_press_key(KEY_R)
	await _advance(0.4)
	_soldier = _recruitment.soldier()
	_check(_soldier != null and _core_state.population == 3, "§91-8 R recrutou o Soldado")
	if _soldier == null:
		_finish()
		return
	_check(_close(_core_state.essence, 5.0),
			"§91-8 Essência 5 depois do recruta, obtido %f" % _core_state.essence)

	_watch_soldier(_soldier.state, SOLDIER_KEY)
	_watch_enemy(_enemy.state, ENEMY_KEY)
	_death_report.clear()
	_capture_enemy_death(_enemy)
	_selection.clear_selection()
	await _click_select(_soldier)
	_check(_unit_ids() == [SOLDIER_KEY], "§91-9 o Soldado foi selecionado na campanha real")
	var essence_before := _core_state.essence
	var stockpile_before := _stockpile.get_amount(ORE)
	var piles_before := _piles_in_scene().size()
	_stockpile_events = 0
	_population_events.clear()
	_reset_watch(ENEMY_KEY)
	_reset_watch(SOLDIER_KEY)

	_right_click(_body_screen_position(ENEMY_SPAWN))
	await _advance(0.05)
	_check(_soldier.action_mode() == SoldierRuntime.ActionMode.ATTACK,
			"§91-10 RMB na Fera abriu ATTACK na campanha real")
	var approached := await _wait_until(
			func() -> bool: return _is_in_stance(_soldier, _enemy), 12.0)
	_check(approached, "§91-11 o Soldado aproximou pela rota real até a Fera")
	await _advance(1.2)
	_check(_strike_count(SOLDIER_KEY) >= 1,
			"§91-12 o Soldado perdeu vida na troca real, golpes %d" % _strike_count(SOLDIER_KEY))
	_check(_strike_count(ENEMY_KEY) >= 1,
			"§91-12 a Fera perdeu vida na troca real, golpes %d" % _strike_count(ENEMY_KEY))
	var killed := await _wait_until(func() -> bool: return _died_count(ENEMY_KEY) > 0, 20.0)
	_check(killed, "§91-13 a Fera chegou a 0 na campanha real")
	_check(_died_count(ENEMY_KEY) == 1, "§91-13 died uma única vez, obtido %d" % _died_count(ENEMY_KEY))
	await _advance(0.4)
	_check(_enemies_in_scene().is_empty(), "§91-14 a Fera saiu da cena")
	_check(_soldier.action_mode() == SoldierRuntime.ActionMode.IDLE
			and _soldier.current_attack_target() == null,
			"§91-15 o Soldado voltou a IDLE sem alvo")
	_check(_core_state.population == 3 and _core_state.get_population_capacity() == 12,
			"§91 Population continua 3 / 12, obtido %d / %d"
					% [_core_state.population, _core_state.get_population_capacity()])
	_check(_population_events.is_empty(),
			"§91 nenhum evento de população na morte da Fera, eventos %s" % [_population_events])
	_check(_piles_in_scene().size() == piles_before,
			"§91/§80 nenhuma pilha nova, contagem %d" % _piles_in_scene().size())
	_check(_stockpile.get_amount(ORE) == stockpile_before and _stockpile_events == 0,
			"§91/§80 o estoque não recebeu loot (%d → %d)"
					% [stockpile_before, _stockpile.get_amount(ORE)])
	_check(_close(_core_state.essence, essence_before),
			"§91/§80 nenhuma recompensa de Essência (%f → %f)"
					% [essence_before, _core_state.essence])
	_check(_text_of(_combat_hud, "EnemyLabel") == "Fera Cavernosa: derrotada",
			"§91/§89 o HUD da campanha fechou com derrotada, obtido %s"
					% _text_of(_combat_hud, "EnemyLabel"))
	_check(_text_of(_core_hud, "PopulationLabel") == "Population: 3 / 12",
			"§91 o HUD do núcleo mostra 3 / 12, obtido %s"
					% _text_of(_core_hud, "PopulationLabel"))

	# §88: com a Fera no mapa, mineração e hauling continuam funcionando.
	var rock := _rock_with_id(COMMON_ROCK_ID)
	_check(rock != null, "§88 a rocha comum do teste existe")
	if rock == null:
		return
	_place(_worker, SITE_LEFT)
	_place(_worker2, SITE_RIGHT)
	await _advance(0.1)
	_selection.clear_selection()
	await _click_select(_worker)
	await _shift_click_select(_worker2)
	_right_click(rock.global_position)
	await _advance(1.0)
	_check(rock.state.remaining_work < rock.definition.work_required,
			"§88/§91 a escavação seguiu funcionando depois do combate, sobra %f"
					% rock.state.remaining_work)
	# Grupo misto depois do duelo: os dois Workers e o Soldado voltam a ser selecionados
	# juntos e cada um responde só à ordem que lhe pertence.
	_place(_soldier, SOLDIER_SPAWN)
	_place(_worker, SITE_LEFT)
	_place(_worker2, SITE_RIGHT)
	await _advance(0.1)
	_selection.clear_selection()
	await _click_select(_worker)
	await _shift_click_select(_worker2)
	await _shift_click_select(_soldier)
	_check(_unit_ids() == ["worker_001", "worker_002", SOLDIER_KEY],
			"§88/§91 o grupo misto de três segue selecionável, ids %s" % [_unit_ids()])
	# A janela é curta e o State é referenciado aqui: se a rocha esgotar o Node se
	# liberta, mas o RockState sobrevive e continua mostrando o trabalho consumido.
	var rock_state := rock.state
	var work_before := rock_state.remaining_work
	var soldier_health_before := _soldier.state.health
	_right_click(rock.global_position)
	await _advance(0.5)
	_check(rock_state.remaining_work < work_before,
			"§88 a escavação em grupo continuou depois do duelo, %f → %f"
					% [work_before, rock_state.remaining_work])
	_check(_close(_soldier.state.health, soldier_health_before)
			and _soldier.action_mode() == SoldierRuntime.ActionMode.IDLE
			and not _soldier.has_move_target(),
			"§88/§98 na ordem de grupo o Soldado ignorou a escavação e não auto-atacou (%s)"
					% str(_soldier.action_mode()))
	_check(_nests_in_scene().size() == 1 and _barracks_in_scene().size() == 1,
			"§105 Ninho e Quartel seguem de pé depois do combate")


# ------------------------------------------------------------------------ Helpers


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
	_enemy = _dungeon.get_node_or_null("Enemy001") as EnemyRuntime
	_combat_hud = _scene.get_node("UI/CombatDebugPanel")
	_core_hud = _scene.get_node("UI/CoreDebugPanel")
	_stockpile = _deposit.stockpile
	_core_state = _core.core_state()
	_core.set_process(false)
	_populate_events()


func _populate_events() -> void:
	_core_state.population_changed.connect(
			func(current: int, capacity: int) -> void:
				_population_events.append("%d/%d" % [current, capacity]))
	_stockpile.resource_changed.connect(
			func(_definition: ResourceDefinition, _amount: int) -> void:
				_stockpile_events += 1)


func _free_scene() -> void:
	if _scene != null and is_instance_valid(_scene):
		_scene.free()
	_scene = null
	_dungeon = null
	_camera = null
	_selection = null
	_construction = null
	_recruitment = null
	_invocation = null
	_deposit = null
	_core = null
	_core_state = null
	_stockpile = null
	_combat_hud = null
	_core_hud = null
	_worker = null
	_worker2 = null
	_soldier = null
	_enemy = null
	_population_events.clear()
	_death_report.clear()
	_live_states.clear()
	_watched_keys.clear()
	_health_reference.clear()
	_strike_counts.clear()
	_damage_totals.clear()
	_died_counts.clear()
	_stockpile_events = 0
	_soldier_health_after_duel = 0.0


## Um turno completo: esgotar a rocha, coletar a pilha e entregar no depósito.
func _mine_with_two_workers(rock: RockRuntime) -> void:
	if rock == null:
		_check(false, "§91 a rocha da campanha não foi encontrada")
		return
	var rock_id := rock.rock_id
	var rock_position := rock.global_position
	_place(_worker, Vector3(rock_position.x + 2.5, 0.0, rock_position.z + 1.0))
	_place(_worker2, Vector3(rock_position.x + 2.5, 0.0, rock_position.z - 1.0))
	await _advance(0.1)
	_selection.clear_selection()
	await _click_select(_worker)
	await _shift_click_select(_worker2)
	_right_click(rock_position)
	var depleted := await _wait_until(func() -> bool: return not _rock_present(rock_id), 40.0)
	_check(depleted, "§91 a rocha %s foi esgotada pelos dois Workers" % rock_id)
	var pile := await _wait_for_pile(6.0)
	_check(pile != null, "§91 a rocha %s virou uma pilha" % rock_id)
	if pile == null:
		return
	_right_click(pile.global_position)
	var loaded := await _wait_until(func() -> bool: return _total_cargo() == 3, 25.0)
	_check(loaded, "§91 os Workers encheram a carga de 3, obtido %d" % _total_cargo())
	var delivered := await _wait_until(func() -> bool: return _total_cargo() == 0, 40.0)
	_check(delivered, "§91 a carga chegou ao depósito")


func _spawn_probe_enemy(key: String, spot: Vector3) -> EnemyRuntime:
	var probe := ENEMY_SCENE.instantiate() as EnemyRuntime
	probe.name = "Probe%s" % key
	probe.setup(_enemy_definition(), EnemyState.new(_enemy_definition(), key))
	_dungeon.add_child(probe)
	probe.global_position = spot
	return probe


func _watch_soldier(state: SoldierState, key: String) -> void:
	if _watched_keys.has(key):
		return
	_watch_open(key, state, state.health)
	state.health_changed.connect(
			func(current: float, _maximum: float) -> void: _record(key, current))
	state.died.connect(func() -> void: _note_death(key))


func _watch_enemy(state: EnemyState, key: String) -> void:
	if _watched_keys.has(key):
		return
	_watch_open(key, state, state.health)
	state.health_changed.connect(
			func(current: float, _maximum: float) -> void: _record(key, current))
	state.died.connect(func() -> void: _note_death(key))


func _watch_open(key: String, state: Object, health: float) -> void:
	_watched_keys.append(key)
	_live_states[key] = state
	_health_reference[key] = health
	_strike_counts[key] = 0
	_damage_totals[key] = 0.0
	_died_counts[key] = 0


func _record(key: String, current: float) -> void:
	var previous := float(_health_reference[key])
	_health_reference[key] = current
	if current >= previous:
		return
	_strike_counts[key] = int(_strike_counts[key]) + 1
	_damage_totals[key] = float(_damage_totals[key]) + (previous - current)


func _note_death(key: String) -> void:
	_died_counts[key] = int(_died_counts[key]) + 1


func _reset_watch(key: String) -> void:
	_strike_counts[key] = 0
	_damage_totals[key] = 0.0
	_health_reference[key] = float(_live_states[key].health)


func _strike_count(key: String) -> int:
	return int(_strike_counts.get(key, 0))


func _damage_total(key: String) -> float:
	return float(_damage_totals.get(key, 0.0))


func _died_count(key: String) -> int:
	return int(_died_counts.get(key, 0))


func _capture_enemy_death(enemy: EnemyRuntime) -> void:
	enemy.enemy_died.connect(func(defeated: EnemyRuntime) -> void:
		_death_report["visual_hidden"] = not _visual_of(defeated).visible
		_death_report["collider_disabled"] = _collider_of(defeated).disabled
		_death_report["layer_zero"] = defeated.collision_layer == 0
		_death_report["still_engaged"] = defeated.is_engaged())


func _capture_soldier_death(soldier: SoldierRuntime) -> void:
	soldier.soldier_died.connect(func(defeated: SoldierRuntime) -> void:
		_death_report["soldier_visual_hidden"] = not _visual_of(defeated).visible
		_death_report["soldier_collider_disabled"] = _collider_of(defeated).disabled
		_death_report["soldier_layer_zero"] = defeated.collision_layer == 0
		_death_report["soldier_indicator_off"] = not _indicator(defeated).visible
		_death_report["soldier_unselected_group"] = not defeated.is_in_group(&"rts_selectable"))


func _visual_of(node: Node) -> MeshInstance3D:
	return node.find_child("Visual", true, false) as MeshInstance3D


func _collider_of(node: Node) -> CollisionShape3D:
	return node.find_child("CollisionShape3D", true, false) as CollisionShape3D


func _indicator(unit) -> MeshInstance3D:
	return unit.find_child("SelectionIndicator", true, false) as MeshInstance3D


func _is_in_stance(unit: SoldierRuntime, target: EnemyRuntime) -> bool:
	return unit.action_mode() == SoldierRuntime.ActionMode.ATTACK \
			and not unit.has_move_target() \
			and _planar_gap(unit.global_position, target.global_position) \
			<= STANCE_GAP + 0.06


func _enemy_definition() -> EnemyDefinition:
	return load(ENEMY_DEFINITION_PATH) as EnemyDefinition


func _soldier_definition() -> SoldierDefinition:
	return load(SOLDIER_DEFINITION_PATH) as SoldierDefinition


func _barracks_definition() -> BarracksDefinition:
	return load(BARRACKS_DEFINITION_PATH) as BarracksDefinition


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


func _enemies_in_scene() -> Array[EnemyRuntime]:
	var found: Array[EnemyRuntime] = []
	for child in _dungeon.get_children():
		if child is EnemyRuntime and not child.is_queued_for_deletion():
			found.append(child as EnemyRuntime)
	return found


func _soldiers_in_scene() -> Array[SoldierRuntime]:
	var found: Array[SoldierRuntime] = []
	for child in _dungeon.get_children():
		if child is SoldierRuntime and not child.is_queued_for_deletion():
			found.append(child as SoldierRuntime)
	return found


func _workers_in_scene() -> Array[WorkerRuntime]:
	var found: Array[WorkerRuntime] = []
	for child in _dungeon.get_children():
		if child is WorkerRuntime and not child.is_queued_for_deletion():
			found.append(child as WorkerRuntime)
	return found


func _nests_in_scene() -> Array[NestRuntime]:
	var found: Array[NestRuntime] = []
	for child in _dungeon.get_children():
		if child is NestRuntime:
			found.append(child as NestRuntime)
	return found


func _barracks_in_scene() -> Array[BarracksRuntime]:
	var found: Array[BarracksRuntime] = []
	for child in _dungeon.get_children():
		if child is BarracksRuntime:
			found.append(child as BarracksRuntime)
	return found


func _piles_in_scene() -> Array[ResourcePileRuntime]:
	var found: Array[ResourcePileRuntime] = []
	for child in _dungeon.get_children():
		if child is ResourcePileRuntime and not child.is_queued_for_deletion():
			found.append(child as ResourcePileRuntime)
	return found


func _rocks_in_scene() -> Array[RockRuntime]:
	var found: Array[RockRuntime] = []
	for child in _dungeon.get_children():
		if child is RockRuntime and not child.is_queued_for_deletion():
			found.append(child as RockRuntime)
	return found


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


func _find_pile() -> ResourcePileRuntime:
	var piles := _piles_in_scene()
	return piles[0] if piles.size() == 1 else null


func _wait_for_pile(max_seconds: float) -> ResourcePileRuntime:
	var found := await _wait_until(func() -> bool: return _find_pile() != null, max_seconds)
	return _find_pile() if found else null


func _unit_ids() -> Array[String]:
	var ids: Array[String] = []
	for unit in _selection.selected_units:
		ids.append(unit.get_unit_id())
	return ids


func _total_cargo() -> int:
	var total := 0
	for worker in _workers_in_scene():
		total += worker.state.carried_amount
	return total


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


func _screen_of_body(unit) -> Vector2:
	return _screen(unit.global_position + Vector3(0.0, 0.8, 0.0))


## A Fera tem 0.8 de altura: o meio do corpo fica a 0.4, não a 0.8.
func _body_screen_position(point: Vector3) -> Vector3:
	return point + Vector3(0.0, 0.4, 0.0)


func _body_screen(point: Vector3) -> Vector2:
	return _screen(_body_screen_position(point))


func _screen(world_position: Vector3) -> Vector2:
	return _camera.unproject_position(world_position)


func _screen_hit(screen_position: Vector2, mask: int) -> Dictionary:
	var origin := _camera.project_ray_origin(screen_position)
	var direction := _camera.project_ray_normal(screen_position)
	return _scene.get_viewport().world_3d.direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(origin, origin + direction * 1000.0, mask))


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


func _planar_gap(from: Vector3, to: Vector3) -> float:
	var offset := to - from
	offset.y = 0.0
	return offset.length()


func _name_of(point: Vector3) -> String:
	if point.is_equal_approx(BARRACKS_POINT):
		return "BarracksBuildPoint"
	if point.is_equal_approx(SOLDIER_SPAWN):
		return "SoldierSpawnPoint"
	if point.is_equal_approx(NEST_POINT):
		return "NestBuildPoint"
	if point.is_equal_approx(DEPOSIT_POINT):
		return "depósito"
	if point.is_equal_approx(CORE_POINT):
		return "Núcleo"
	if point.is_equal_approx(WORKER_SPAWN):
		return "WorkerSpawnPoint"
	return str(point)


func _shape_clear_at(point: Vector3, radius: float, mask: int) -> bool:
	return not _sphere_hits(Vector3(point.x, 0.8, point.z), radius, mask)


func _sphere_hits(point: Vector3, radius: float, mask: int) -> bool:
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	var parameters := PhysicsShapeQueryParameters3D.new()
	parameters.shape = sphere
	parameters.transform = Transform3D(Basis.IDENTITY, point)
	parameters.collision_mask = mask
	return not (_scene.get_viewport().world_3d.direct_space_state
			.intersect_shape(parameters, 8).is_empty())


func _ground_body_at(point: Vector3) -> String:
	var hit := (_scene.get_viewport().world_3d.direct_space_state
			.intersect_ray(PhysicsRayQueryParameters3D.create(
					Vector3(point.x, 6.0, point.z), Vector3(point.x, 0.0, point.z), GROUND_LAYER)))
	return String(hit.collider.name) if not hit.is_empty() else "<nada>"


func _straight_route_clear(from: Vector3, to: Vector3, source_id: String) -> bool:
	var start := _route_start(from, to, SOLDIER_RADIUS)
	for rock in _rocks_in_scene():
		if rock.rock_id == source_id:
			continue
		if not _segment_clear_of(start, SOLDIER_RADIUS, to, rock.global_position, ROCK_HALF):
			return false
	return true


func _route_clear_of_sites(from: Vector3, to: Vector3) -> bool:
	var start := _route_start(from, to, SOLDIER_RADIUS)
	for site in [NEST_POINT, BARRACKS_POINT]:
		if not _segment_clear_of(start, SOLDIER_RADIUS, to, site, BUILD_HALF):
			return false
	return true


func _route_start(from: Vector3, to: Vector3, from_radius: float) -> Vector3:
	var direction := to - from
	direction.y = 0.0
	return from + direction.normalized() * (from_radius + SOLDIER_RADIUS)


func _segment_clear_of(from: Vector3, radius: float, to: Vector3,
		obstacle: Vector3, obstacle_radius: float) -> bool:
	var samples := 24
	for i in samples + 1:
		var point := from.lerp(to, float(i) / float(samples))
		if _planar_gap(obstacle, point) < radius + obstacle_radius:
			return false
	return true


## Menor folga entre os dois corpos ao longo do trecho; negativa significa invadido.
func _segment_margin(from: Vector3, radius: float, to: Vector3,
		obstacle: Vector3, obstacle_radius: float) -> float:
	var least := INF
	var samples := 24
	for i in samples + 1:
		var point := from.lerp(to, float(i) / float(samples))
		least = minf(least, _planar_gap(obstacle, point) - radius - obstacle_radius)
	return least


func _route_site_margin(from: Vector3, to: Vector3) -> float:
	var start := _route_start(from, to, SOLDIER_RADIUS)
	var least := INF
	for site in [NEST_POINT, BARRACKS_POINT]:
		least = minf(least,
				_segment_margin(start, SOLDIER_RADIUS, to, site, BUILD_HALF))
	return least


func _route_rock_margin(from: Vector3, to: Vector3) -> float:
	var start := _route_start(from, to, SOLDIER_RADIUS)
	var least := INF
	for rock in _rocks_in_scene():
		least = minf(least,
				_segment_margin(start, SOLDIER_RADIUS, to, rock.global_position, ROCK_HALF))
	return least


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
	print("---- combat tests finished: %d asserts, %d failure(s) ----"
			% [_asserts, _failures])
	quit(1 if _failures > 0 else 0)
