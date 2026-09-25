extends SceneTree

# Tarefa 14 — Evolução do Núcleo Nv.1 → Nv.2 e vitória do MVP.
#
# A suíte prova uma única coisa grande: o Núcleo que sobreviveu à invasão é o MESMO
# Núcleo que vira Nv.2. Não existe instância nova, cena nova, State novo nem campanha
# reiniciada — existe uma Definition trocada por dentro do State que já estava lá, com
# a Population, o bônus do Ninho, o stockpile e o mundo intactos.
#
# Três blocos, nesta ordem:
#   1) números e fontes — as duas Definitions, a proibição de árvore de upgrades e o
#      input V mapeado sem KEY_V hardcoded (§52–§53, §75, §91–§95, §37);
#   2) rig isolado — CoreState, CoreRuntime e CoreEvolutionController sem GameMain:
#      transição válida, inválida, retrógrada, sinais, visual, taxas de geração e o
#      gating da vitória/derrota (§54–§75, §103);
#   3) campanha real na cena de produção — o fluxo inteiro da Tarefa 13 até VICTORY,
#      Essência medida sem nenhuma doação, V pressed de verdade, e o mundo continuando
#      depois do MVP (§76–§90, §99–§100, §87).
#
# Convenção das suítes: o input do jogador é sintético mas entra pelo InputMap e pelos
# raycasts de tela reais. §77 é literal aqui: na integração principal a Essência não é
# forçada — ela é medida, e quando falta, o teste espera a geração natural.

const MAIN_SCENE := preload("res://game/GameMain.tscn")
const CORE_SCENE := preload("res://world/dungeon/core/CoreRuntime.tscn")
const ENEMY_SCENE := preload("res://units/enemies/EnemyRuntime.tscn")
const EVOLUTION_HUD_SCENE := preload("res://ui/hud/CoreEvolutionDebugHud.tscn")

const CORE_1_PATH := "res://data/core/core_level_1.tres"
const CORE_2_PATH := "res://data/core/core_level_2.tres"
const NEST_1_PATH := "res://data/rooms/abyss_nest.tres"
const ENEMY_DEFINITION_PATH := "res://data/units/enemies/cave_beast.tres"

const CORE_DEFINITION_SOURCE := "res://core/definitions/core_definition.gd"
const CORE_STATE_SOURCE := "res://core/state/core_state.gd"
const CORE_RUNTIME_SOURCE := "res://world/dungeon/core/core_runtime.gd"
const CORE_RUNTIME_SCENE := "res://world/dungeon/core/CoreRuntime.tscn"
const CONTROLLER_SOURCE := "res://systems/progression/core_evolution_controller.gd"
const EVOLUTION_HUD_SOURCE := "res://ui/hud/core_evolution_debug_hud.gd"
const EVOLUTION_HUD_SCENE_PATH := "res://ui/hud/CoreEvolutionDebugHud.tscn"
const CORE_HUD_SOURCE := "res://ui/hud/core_debug_hud.gd"
const GAME_MAIN_SOURCE := "res://game/game_main.gd"
const PROJECT_SETTINGS := "res://project.godot"
const DATA_CORE_DIR := "res://data/core"
const CORE_DIR := "res://world/dungeon/core"
const SYSTEMS_PROGRESSION_DIR := "res://systems/progression"

const ORE := &"iron_ore"
const BEAST_HP := 48.0
const SOLDIER_HP := 80.0
const INTEGRITY_LV1 := 100.0
const INTEGRITY_LV2 := 150.0
const MAX_ESSENCE_LV1 := 50.0
const MAX_ESSENCE_LV2 := 80.0
const CAPACITY_LV1 := 8
const CAPACITY_LV2 := 12
const NEST_BONUS := 4
const COST := 25.0
const SOLDIER_COST := 15.0
const WORKER_COST := 10.0
const RATE_LV1 := 1.0
const RATE_LV2 := 1.5
const LEVEL_2_SCALE := 1.25
const TICKS := 60
## Os estados da invasão viram constantes para caberem nos lambdas de espera curtos.
const INVASION_PREPARATION := InvasionController.InvasionState.PREPARATION
const INVASION_ACTIVE := InvasionController.InvasionState.ACTIVE
const INVASION_VICTORY := InvasionController.InvasionState.VICTORY
const INVASION_DEFEAT := InvasionController.InvasionState.DEFEAT
## Duração da preparação nos rigs de gating: §69/§70 só precisam que o ciclo feche, e
## §16/T13 autoriza encurtar pelo @export — nunca por tecla de pulo.
const SHORT_PREP := 0.6

## Textos das §40–§42, copiados aqui de propósito: se a produção mudar um número, a
## linha do HUD muda junto e esta suíte acusa a diferença de interface.
const LEVEL_1_LINE := "Núcleo Nv.1"
const LOCKED_OFFER := "Evolução: bloqueada"
const LOCKED_STATUS := "Sobreviva à primeira invasão."
const OFFER_LINE := "[V] Evoluir para Nv.2 — 25 Essência"
const READY_STATUS := "Pronto para evoluir"
const INSUFFICIENT_STATUS := "Essência insuficiente"
const NV2_LINE := "NÚCLEO NV.2"
const MVP_LINE := "MVP CONCLUÍDO"
const CORE_TITLE_LV1 := "Abyssal Core Lv. 1"
const CORE_TITLE_LV2 := "Abyssal Core Lv. 2"

const NEST_POINT := Vector3(-5, 0, -5)
const BARRACKS_POINT := Vector3(-10, 0, -5)
const SOLDIER_DEFENSE := Vector3(-2.2, 0, 6.2)
const SPAWN_A := Vector3(-4, 0, 10)
const SPAWN_B := Vector3(11, 0, 0)
const CORE_HOME := Vector3(0.0, 1.0, 0.0)
const FIRST_ORE_ROCK_ID := "iron_ore_001"
const SECOND_ORE_ROCK_ID := "iron_ore_002"
## A CommonRock que sobra da campanha é o alvo de §84: minerar depois do MVP não precisa
## criar rocha nenhuma.
const SPARE_ROCK_ID := "rock_003"
## Para onde o grupo caminha em §83: o mesmo ponto que test_multi_selection já provou
## estar dentro da vista da câmera padrão e sobre chão livre. Alvo longe da vista vira
## raycast em outro lugar do mapa, e isso não é teste de nada.
const GROUP_TARGET := Vector3(0.0, 0.0, 5.0)
## Raio de chegada do §83: a formação deixa cada Worker num slot próprio, a
## group_move_spacing de distância um do outro.
const GROUP_ARRIVAL := 0.25

const GROUND_LAYER := 1
const UNIT_LAYER := 2
const DIGGABLE_LAYER := 4
const RESOURCE_LAYER := 8
const CONSTRUCTION_LAYER := 16
const CLICKABLE := GROUND_LAYER | UNIT_LAYER | DIGGABLE_LAYER | RESOURCE_LAYER \
		| CONSTRUCTION_LAYER

var _failures := 0
var _asserts := 0
var _frames := 0
var _measurements := {}

## Contadores de sinal. §58, §70 e §106 pedem "exatamente uma vez", e uma vez só se
## prova com contador alimentado pelo próprio emissor, nunca por inferência.
var _evolved_events := 0
var _evolved_args: Array[int] = []
var _integrity_events := 0
var _integrity_args: Array[float] = []
var _essence_events := 0
var _essence_args: Array[float] = []
var _capacity_events := 0
var _capacity_args: Array[int] = []
var _unlock_events := 0
var _mvp_events := 0
var _signal_order: Array[String] = []

# Rig isolado (bloco 2)
var _rig: Node
var _rig_core: CoreRuntime
var _rig_state: CoreState
var _rig_evolution: CoreEvolutionController
var _rig_invasion: InvasionController

# Cena de produção (bloco 3)
var _scene: Node
var _dungeon: Node3D
var _camera: Camera3D
var _camera_rig: Node3D
var _selection: SelectionController
var _construction: ConstructionController
var _recruitment: SoldierRecruitmentController
var _invasion: InvasionController
var _evolution: CoreEvolutionController
var _deposit: ResourceDepositRuntime
var _core: CoreRuntime
var _core_state: CoreState
var _stockpile: ResourceStockpileState
var _evolution_hud: Node
var _core_hud: Node
var _worker: WorkerRuntime
var _worker2: WorkerRuntime
var _soldier: SoldierRuntime
## §82: a régua do estoque é capturada antes da tecla V, na campanha.
var _stockpile_before := 0


func _initialize() -> void:
	_run_all()


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > 1200000:
		_check(false, "timeout: a suíte de evolução não terminou")
		_finish()
	return false


func _run_all() -> void:
	# Bloco 1 — números e fontes.
	_test_level_two_definition()
	_test_level_one_definition()
	_test_scope_guards()
	_test_input_surface()
	_test_hud_sources()

	# Bloco 2 — rig isolado, sem GameMain e sem UI.
	await _test_state_evolution()
	await _test_state_invalid_transitions()
	await _test_essence_clamp_safety()
	await _test_runtime_identity_and_visual()
	await _test_generation_rates()
	await _test_controller_pre_victory_block()
	await _test_controller_transactions()
	await _test_cost_comes_from_definition()
	await _test_defeat_does_not_unlock()
	await _test_victory_unlocks_by_signal()

	# Bloco 3 — a campanha real até a vitória e o mundo depois do MVP.
	await _boot_scene()
	await _test_boot_surface()
	await _test_v_key_does_nothing_before_victory()
	await _test_campaign_to_victory()
	await _test_evolution_offer_after_victory()
	await _test_real_input_evolves_core()
	await _test_state_after_real_evolution()
	await _test_world_preserved_after_evolution()
	await _test_hud_after_evolution()
	await _test_second_v_charges_nothing()
	await _test_world_still_runs_after_mvp()
	await _test_no_third_level()
	_free_scene()

	_print_measurements()
	_finish()


# ==================================================== Bloco 1 — Definitions e fontes


## §52: o Nv.2 é dado, não código. Cada número abaixo existe uma vez no repositório.
func _test_level_two_definition() -> void:
	_check(ResourceLoader.exists(CORE_2_PATH), "§52 core_level_2.tres existe")
	var definition := load(CORE_2_PATH) as CoreDefinition
	_check(definition != null, "§52 o recurso carrega como CoreDefinition")
	if definition == null:
		return
	# §106: nenhuma classe nova — o Nv.2 reusa a Definition que já existia.
	var script := definition.get_script() as Script
	_check(script != null and script.resource_path == CORE_DEFINITION_SOURCE,
			"§106 o Nv.2 usa a CoreDefinition existente, obtido %s"
					% (script.resource_path if script != null else "<sem script>"))
	_check(definition.level == 2, "§52 level == 2, obtido %d" % definition.level)
	_check(_close(definition.max_integrity, INTEGRITY_LV2),
			"§52 max_integrity == 150, obtido %f" % definition.max_integrity)
	_check(_close(definition.max_essence, MAX_ESSENCE_LV2),
			"§52 max_essence == 80, obtido %f" % definition.max_essence)
	_check(_close(definition.starting_essence, 30.0),
			"§52 starting_essence == 30, obtido %f" % definition.starting_essence)
	_check(definition.population_capacity == CAPACITY_LV2,
			"§52 population_capacity == 12, obtido %d" % definition.population_capacity)
	_check(_close(definition.essence_generation_rate, RATE_LV2),
			"§52 essence_generation_rate == 1.5, obtido %f" % definition.essence_generation_rate)
	_check(_close(definition.evolution_essence_cost, COST),
			"§52/§32 evolution_essence_cost == 25, obtido %f" % definition.evolution_essence_cost)
	_check(_source(CORE_2_PATH).contains("evolution_essence_cost = 25.0"),
			"§75 o preço está escrito no .tres de destino")


## §53/§6: o Nv.1 é o mesmo de sempre, inclusive o custo zero — evoluir PARA ele não é
## uma coisa que exista, e 0.0 deixa isso explícito no dado em vez de ausente.
func _test_level_one_definition() -> void:
	var definition := load(CORE_1_PATH) as CoreDefinition
	_check(definition != null, "§53 core_level_1.tres continua carregando")
	if definition == null:
		return
	_check(definition.level == 1, "§53 level == 1, obtido %d" % definition.level)
	_check(_close(definition.max_integrity, INTEGRITY_LV1),
			"§53 max_integrity == 100, obtido %f" % definition.max_integrity)
	_check(_close(definition.max_essence, MAX_ESSENCE_LV1),
			"§53 max_essence == 50, obtido %f" % definition.max_essence)
	_check(_close(definition.starting_essence, 20.0),
			"§53 starting_essence == 20, obtido %f" % definition.starting_essence)
	_check(definition.population_capacity == CAPACITY_LV1,
			"§53 population_capacity == 8, obtido %d" % definition.population_capacity)
	_check(_close(definition.essence_generation_rate, RATE_LV1),
			"§53 essence_generation_rate == 1, obtido %f" % definition.essence_generation_rate)
	_check(_close(definition.evolution_essence_cost, 0.0),
			"§53 evolution_essence_cost == 0, obtido %f" % definition.evolution_essence_cost)
	_check(_source(CORE_DEFINITION_SOURCE).contains("@export var evolution_essence_cost: float"),
			"§32 o custo é @export float na Definition")
	# §6: o Ninho não foi tocado para compensar nada.
	var nest := load(NEST_1_PATH) as NestDefinition
	_check(nest != null and nest.population_capacity_bonus == NEST_BONUS,
			"§6 abyss_nest.tres continua com bonus 4, obtido %d"
					% (nest.population_capacity_bonus if nest != null else -1))
	# §91/§106: nada de Nv.3 escondido no diretório de dados.
	var core_files := _files_in(DATA_CORE_DIR, ".tres")
	_check(core_files == ["core_level_1.tres", "core_level_2.tres"],
			"§91 data/core tem exatamente os dois níveis, obtido %s" % [core_files])


## §91–§95, §26–§29: a fronteira do que não foi feito. A varredura é de fonte crua, com
## comentário incluso, porque um Manager novo sempre começa pelo nome.
func _test_scope_guards() -> void:
	var sources := _collect_gd_files("res://")
	_check(not sources.is_empty(), "§104 a varredura achou os fontes de produção")
	for forbidden in ["ProgressionManager", "UpgradeManager", "TechTreeManager",
			"MilestoneManager", "TechTree", "UpgradeTree", "EvolutionTree", "EvolutionManager",
			"next_definition", "previous_definition", "reload_current_scene",
			"CoreRuntimeLevel2", "CoreLevel2", "EventBus", "GameOverScreen", "VictoryScreen",
			"repair_core", "heal_core", "auto_aggro", "WaveManager", "EnemySpawner",
			"AutoBuild", "AutoRecruit", "SpeedToggle"]:
		var offenders := _files_containing(sources, forbidden)
		_check(offenders.is_empty(),
				"§91–§95 nenhum fonte contém %s, achado em %s" % [forbidden, offenders])
	# §92/§26: um degrau, uma transição — um controller só.
	_check(_collect_gd_files(SYSTEMS_PROGRESSION_DIR).size() == 1,
			"§92 systems/progression tem exatamente um script, obtido %d"
					% _collect_gd_files(SYSTEMS_PROGRESSION_DIR).size())
	# §25/§94: nenhum CoreRuntimeLevel2.tscn, nenhuma cena nova de Núcleo.
	_check(ResourceLoader.exists(CORE_RUNTIME_SCENE), "§94 a cena CoreRuntime continua lá")
	var core_scenes := _files_in(CORE_DIR, ".tscn")
	_check(core_scenes == ["CoreRuntime.tscn"],
			"§25/§94 só existe a cena CoreRuntime, obtido %s" % [core_scenes])
	# §29: o controller não pergunta nada por frame nem por estado alheio.
	var controller_code := _code_of(CONTROLLER_SOURCE)
	for forbidden in ["func _process(", "func _physics_process(", "invasion_state",
			"preparation_time_remaining", "InvasionController", "get_nodes_in_group",
			"get_first_node_in_group"]:
		_check(not controller_code.contains(forbidden),
				"§29/§74 o controller de evolução não contém %s" % forbidden)
	# §75: o preço não mora no código.
	_check(not controller_code.contains("25"), "§75 o controller não hardcodeia 25")
	_check(controller_code.contains("evolution_essence_cost"),
			"§75 o controller lê o custo da Definition de destino")
	# §16/§22: o Runtime não cria instância nenhuma.
	var runtime_code := _code_of(CORE_RUNTIME_SOURCE)
	for forbidden in ["instantiate", "add_child", "queue_free", "CoreRuntime.tscn"]:
		_check(not runtime_code.contains(forbidden),
				"§16/§22 core_runtime.gd não contém %s" % forbidden)
	# §97: nada readiciona o bônus do Ninho durante a evolução. A guarda é no corpo de
	# evolve_to, não no arquivo inteiro — a API pública de bônus existe desde a Tarefa 07
	# e mora nesse mesmo arquivo; o que §97 proíbe é a evolução chamá-la.
	var state_code := _code_of(CORE_STATE_SOURCE)
	var evolve_body := _evolve_to_body(state_code)
	_check(not evolve_body.is_empty(), "§97 evolve_to existe em core_state.gd")
	_check(not evolve_body.contains("add_population_capacity_bonus"),
			"§97/§51 o caminho de evolução não readiciona bônus de capacidade")
	# §91: nenhuma regra de repair/heal apareceu junto da restauração de Integrity.
	for forbidden in ["heal", "repair", "regen", "integrity +"]:
		_check(not state_code.to_lower().contains(forbidden),
				"§13/§91 core_state.gd não contém %s" % forbidden)
	# §95: ninguém reinicia a partida.
	_check(not _code_of(GAME_MAIN_SOURCE).contains("reload_current_scene"),
			"§95 game_main.gd não recarrega a cena")
	# §28/§29: a única ponte entre invasão e progressão é uma linha de composition root.
	var main := _code_of(GAME_MAIN_SOURCE)
	_check(main.contains("invasion_victory.connect(_evolution.unlock_after_victory)"),
			"§27/§28 a vitória chega ao controller por signal explícito")
	_check(main.contains("setup(_core, core_state, core_level_2_definition)"),
			"§27/§93 o destino é injetado, não procurado")


## §37/§38: a tecla existe como ação, e o controller só conhece a ação.
func _test_input_surface() -> void:
	_check(InputMap.has_action("evolve_core"), "§37 a ação evolve_core existe")
	if not InputMap.has_action("evolve_core"):
		return
	var mapped_v := false
	for event in InputMap.action_get_events("evolve_core"):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_V:
			mapped_v = true
	_check(mapped_v, "§37 evolve_core está mapeada em V")
	_check(_source(PROJECT_SETTINGS).contains("evolve_core"),
			"§37 o mapeamento está no project.godot")
	var code := _code_of(CONTROLLER_SOURCE)
	_check(code.contains("is_action_pressed(\"evolve_core\")"),
			"§37 o controller testa a ação, não a tecla")
	_check(not code.contains("KEY_V") and not code.contains("physical_keycode"),
			"§37 nenhum KEY_V hardcoded no controller")


## §43/§87/§105: HUD sem loop, sem busca global e sem interceptar mouse.
func _test_hud_sources() -> void:
	var hud_code := _code_of(EVOLUTION_HUD_SOURCE)
	_check(not hud_code.contains("func _process(")
			and not hud_code.contains("func _physics_process("),
			"§43 o painel de evolução não roda nada por frame")
	_check(not hud_code.contains("get_nodes_in_group")
			and not hud_code.contains("get_first_node_in_group")
			and not hud_code.contains("find_children"),
			"§27/§43 nada do painel é procurado na árvore")
	_check(not hud_code.contains("InvasionController"),
			"§29/§43 o painel não conhece a invasão")
	_check(hud_code.contains("evolution_unlocked.connect")
			and hud_code.contains("essence_changed.connect")
			and hud_code.contains("evolved.connect"),
			"§43 o painel só anda por evolution_unlocked/essence_changed/evolved")
	_check(not hud_code.contains("25") and not hud_code.contains("\"Nv.2\""),
			"§45 o painel não hardcodeia preço nem nível de destino")
	# §44: o título antigo do CoreDebugHud continua orientado a signal, sem loop novo.
	var core_hud_code := _code_of(CORE_HUD_SOURCE)
	_check(core_hud_code.contains("integrity_changed.connect"),
			"§44 o CoreDebugHud continua plugado em integrity_changed")
	_check(core_hud_code.contains("evolved.connect"),
			"§44 o título do CoreDebugHud ouviu evolved")
	_check(not core_hud_code.contains("func _process("),
			"§44 o CoreDebugHud não ganhou loop por frame")
	# A cena do painel: todo Control declara IGNORE, inclusive os que nascem ocultos.
	var scene_text := _source(EVOLUTION_HUD_SCENE_PATH)
	_check(not scene_text.contains("Button") and not scene_text.contains("LineEdit"),
			"§87 o painel de evolução não tem controle interativo")
	_check(scene_text.count("mouse_filter = 2") >= 5,
			"§87 os Controls do painel declaram IGNORE na cena, obtido %d"
					% scene_text.count("mouse_filter = 2"))
	var panel := EVOLUTION_HUD_SCENE.instantiate() as Control
	_check(panel is PanelContainer, "§40 o painel é um PanelContainer")
	panel.free()


# ===================================================== Bloco 2 — State, Runtime, rig


## §54–§61, §98: a transição inteira dentro do State, com os sinais contados e na ordem
## da §21. O State é criado à mão, sem cena, porque a transição é regra de dado.
func _test_state_evolution() -> void:
	var lv1 := load(CORE_1_PATH) as CoreDefinition
	var lv2 := load(CORE_2_PATH) as CoreDefinition
	var state := CoreState.new(lv1)
	var state_id := state.get_instance_id()
	state.try_add_population(1)
	state.try_add_population(1)
	state.try_add_population(1)
	state.add_population_capacity_bonus(NEST_BONUS)
	state.damage(60.0)
	state.consume_essence(5.0)
	_reset_capture()
	_capture_state(state)

	# O retrato de antes, exatamente o da §54.
	_check(state.core_id == "main_core", "§54 core_id é main_core")
	_check(state.population == 3, "§54 population 3, obtido %d" % state.population)
	_check(state.population_capacity_bonus == NEST_BONUS,
			"§98 bônus antes da evolução é 4, obtido %d" % state.population_capacity_bonus)
	_check(_close(state.integrity, 40.0), "§54 integrity 40, obtido %f" % state.integrity)
	_check(_close(state.essence, 15.0), "§54 essence 15, obtido %f" % state.essence)
	_check(state.get_population_capacity() == CAPACITY_LV1 + NEST_BONUS,
			"§55 capacidade efetiva antes: 8 + 4 = 12, obtido %d"
					% state.get_population_capacity())
	_check(state.definition == lv1, "§54 a Definition de antes é a Lv.1")

	_check(state.evolve_to(lv2), "§54 evolve_to(Lv.2) aceitou")
	_check(_signal_order == ["integrity", "essence", "capacity", "evolved"],
			"§21 a ordem emitida foi os valores e depois evolved, obtido %s" % [_signal_order])
	_check(state.get_instance_id() == state_id, "§63 o State é a mesma instância")
	_check(state.core_id == "main_core", "§54/§2 o core_id continua main_core")
	_check(state.level == 2, "§54/§106 level virou 2, obtido %d" % state.level)
	_check(state.definition == lv2, "§54 a Definition agora é a Lv.2")
	_check(state.population == 3,
			"§54/§51 population preservada em 3, obtido %d" % state.population)
	_check(state.population_capacity_bonus == NEST_BONUS,
			"§98/§97 bônus depois da evolução continua 4, obtido %d"
					% state.population_capacity_bonus)
	_check(state.get_population_capacity() == CAPACITY_LV2 + NEST_BONUS,
			"§55 capacidade efetiva depois: 12 + 4 = 16, obtido %d"
					% state.get_population_capacity())
	_check(_close(state.integrity, INTEGRITY_LV2),
			"§12/§106 integrity virou o teto novo 150, obtido %f" % state.integrity)
	_check(_close(state.essence, 15.0),
			"§14/§106 essence restante preservada, obtido %f" % state.essence)
	_check(not _close(state.essence, lv2.starting_essence),
			"§14 starting_essence do Nv.2 não foi reaplicada")
	_check(_evolved_events == 1, "§58 evolved exatamente uma vez, %d" % _evolved_events)
	_check(_evolved_args == [1, 2], "§58 evolved(1, 2), obtido %s" % [_evolved_args])
	_check(_integrity_args == [INTEGRITY_LV2, INTEGRITY_LV2],
			"§59 integrity_changed levou o teto novo, obtido %s" % [_integrity_args])
	_check(_essence_args == [15.0, MAX_ESSENCE_LV2],
			"§60 essence_changed levou o teto novo 80, obtido %s" % [_essence_args])
	_check(_capacity_args == [3, 16],
			"§61 population_capacity_changed levou 3 / 16, obtido %s" % [_capacity_args])
	_check(not state.is_destroyed(), "§12 o Núcleo evolui vivo")


## §8/§56/§57: as transições que não existem. Todas devolvem false antes de qualquer
## escrita, então o retrato do State tem de continuar idêntico.
func _test_state_invalid_transitions() -> void:
	var lv1 := load(CORE_1_PATH) as CoreDefinition
	var lv2 := load(CORE_2_PATH) as CoreDefinition
	var state := CoreState.new(lv1)
	state.try_add_population(1)
	state.add_population_capacity_bonus(NEST_BONUS)
	_reset_capture()
	_capture_state(state)
	state.evolve_to(lv2)
	_reset_capture()
	_capture_state(state)
	var snapshot := _snapshot(state)

	_check(not state.can_evolve_to(lv2), "§8 mesmo nível não é evolução")
	_check(not state.evolve_to(lv2), "§56 Lv.2 → Lv.2 devolve false")
	_check(not state.can_evolve_to(lv1), "§8 nível menor não é evolução")
	_check(not state.evolve_to(lv1), "§57 Lv.2 → Lv.1 devolve false")
	_check(not state.can_evolve_to(null), "§8 Definition nula não é evolução")
	_check(not state.evolve_to(null), "§8/§56 evolve_to(null) devolve false")
	_check(_snapshot(state) == snapshot,
			"§56/§57 nenhuma transição inválida alterou um campo do State")
	_check(_evolved_events == 0,
			"§56 nenhum evolved saiu de transição inválida, %d" % _evolved_events)
	_check(_integrity_events == 0 and _essence_events == 0 and _capacity_events == 0,
			"§56 transição inválida não emitiu sinal de valor nenhum")
	_check(state.population_capacity_bonus == NEST_BONUS,
			"§98 o bônus sobreviveu às tentativas inválidas em 4")


## §15: o clamp é uma linha e a exigência é que ele nunca possa machucar. Aqui o teto
## novo é menor que a Essência, o único caso em que min() faz alguma coisa.
func _test_essence_clamp_safety() -> void:
	var lv1 := load(CORE_1_PATH) as CoreDefinition
	var lv2 := load(CORE_2_PATH) as CoreDefinition
	var state := CoreState.new(lv1)
	_reset_capture()
	_capture_state(state)
	# Acima do teto do Nv.2 de propósito — só o harness escreve aqui, nunca a produção.
	state.essence = 90.0
	_check(state.evolve_to(lv2), "§15 evoluir com Essência acima do teto novo é aceito")
	_check(_close(state.essence, MAX_ESSENCE_LV2),
			"§15 essence clampada no teto novo, obtido %f" % state.essence)
	_check(not is_nan(state.essence) and state.essence >= 0.0,
			"§15 o clamp não produziu valor inválido")
	_check(_essence_args == [MAX_ESSENCE_LV2, MAX_ESSENCE_LV2],
			"§15/§60 o sinal saiu com o valor já clampado, obtido %s" % [_essence_args])
	# O caso comum: abaixo do teto, nada muda.
	var other := CoreState.new(lv1)
	other.essence = 12.0
	other.evolve_to(lv2)
	_check(_close(other.essence, 12.0), "§14/§15 essência abaixo do teto fica intacta")


## §62/§63/§64: o Runtime é o mesmo Node3D, na mesma posição, crescendo por dentro.
func _test_runtime_identity_and_visual() -> void:
	var lv1 := load(CORE_1_PATH) as CoreDefinition
	var lv2 := load(CORE_2_PATH) as CoreDefinition
	_rig = Node3D.new()
	_rig.name = "RuntimeRig"
	root.add_child(_rig)
	_rig_core = CORE_SCENE.instantiate() as CoreRuntime
	_rig.add_child(_rig_core)
	await process_frame
	_rig_state = CoreState.new(lv1)
	_rig_core.setup(lv1, _rig_state)
	await process_frame
	var core_id := _rig_core.get_instance_id()
	var state_id := _rig_state.get_instance_id()
	var position_before := _rig_core.global_position
	var detail := _rig_core.get_node_or_null("Level2Detail") as MeshInstance3D

	_check(detail != null, "§64 o detalhe do Nv.2 já mora na cena, escondido")
	_check(detail != null and not detail.visible, "§64 antes da evolução o anel está hidden")
	_check(_close(_rig_core.scale.x, 1.0) and _close(_rig_core.scale.y, 1.0),
			"§64 o corpo abre com escala 1, obtido %s" % [_rig_core.scale])

	_check(_rig_core.evolve_to(lv2), "§64 o Runtime aceitou a evolução")
	_check(_rig_core.get_instance_id() == core_id,
			"§62 o CoreRuntime é a mesma instância depois (%d)" % core_id)
	_check(_rig_state.get_instance_id() == state_id,
			"§63 o CoreState é o mesmo objeto referenciado")
	_check(_rig_core.core_state() == _rig_state, "§63/§16 o Runtime não trocou de State")
	_check(_rig_core.definition() == lv2, "§16 o Runtime passou a ler a Definition nova")
	_check(_rig_core.global_position.distance_to(position_before) < 0.001,
			"§62/§106 o Núcleo continuou no mesmo lugar (%s → %s)"
					% [str(position_before), str(_rig_core.global_position)])
	_check(_close(_rig_core.scale.x, LEVEL_2_SCALE, 0.001)
			and _close(_rig_core.scale.y, LEVEL_2_SCALE, 0.001),
			"§64 a escala numérica virou %f, obtido %s" % [LEVEL_2_SCALE, str(_rig_core.scale)])
	_check(_rig_core.scale.x > 1.0, "§64 o corpo ficou maior, %f" % _rig_core.scale.x)
	_check(detail != null and detail.visible, "§64 o anel do Nv.2 acendeu")

	# A recusa também é do Runtime: nada de acender visual em transição inválida.
	var scale_before := _rig_core.scale
	_check(not _rig_core.evolve_to(lv2), "§56 o Runtime rejeita Lv.2 → Lv.2")
	_check(_rig_core.scale == scale_before, "§56 rejeitar não mexeu na escala")
	_check(_rig_core.definition() == lv2, "§57/§16 a referência continua a Lv.2")
	_free_rig()


## §65/§66/§67/§96: a geração não tem timer para reiniciar — é a taxa lida da
## Definition no instante do delta. É exatamente isso que as duas janelas abaixo medem.
func _test_generation_rates() -> void:
	var lv1 := load(CORE_1_PATH) as CoreDefinition
	var lv2 := load(CORE_2_PATH) as CoreDefinition
	_rig = Node3D.new()
	_rig.name = "RateRig"
	root.add_child(_rig)
	_rig_core = CORE_SCENE.instantiate() as CoreRuntime
	_rig.add_child(_rig_core)
	await process_frame
	_rig_state = CoreState.new(lv1)
	_rig_core.setup(lv1, _rig_state)
	await process_frame

	var before_lv1 := _rig_state.essence
	await _advance_real(1.0)
	var gain_lv1 := _rig_state.essence - before_lv1
	_measurements["lv1_gain_1s"] = gain_lv1
	_check(_close(gain_lv1, RATE_LV1, 0.3),
			"§65 Lv.1 gerou ~1.0 em um segundo real, obtido %f" % gain_lv1)

	_check(_rig_core.evolve_to(lv2), "§66 a evolução do rig aconteceu")
	_check(_rig_state.essence < MAX_ESSENCE_LV2 - 5.0,
			"§66 a janela do Lv.2 começa longe do teto, %f" % _rig_state.essence)
	var before_lv2 := _rig_state.essence
	await _advance_real(1.0)
	var gain_lv2 := _rig_state.essence - before_lv2
	_measurements["lv2_gain_1s"] = gain_lv2
	_check(_close(gain_lv2, RATE_LV2, 0.35),
			"§66/§96 Lv.2 gerou ~1.5 no mesmo relógio, obtido %f" % gain_lv2)
	_check(gain_lv2 > gain_lv1,
			"§66 a taxa realmente subiu (%f → %f)" % [gain_lv1, gain_lv2])

	# §67: encher o tanque novo e continuar deixando o relógio rodar.
	_rig_state.add_essence(MAX_ESSENCE_LV2)
	await _advance_real(2.0)
	_check(_close(_rig_state.essence, MAX_ESSENCE_LV2, 0.01),
			"§67 a Essência parou em 80, obtido %f" % _rig_state.essence)
	_check(_rig_state.essence <= MAX_ESSENCE_LV2 + 0.0001,
			"§67 nunca passou do teto, %f" % _rig_state.essence)
	_free_rig()


## §68/§30/§102: antes da vitória a tecla não tem efeito nenhum, nem com Essência
## sobrando no tanque. A Essência aqui é posta pelo harness porque §68 é um retrato do
## "dinheiro na mão sem permissão" — a campanha do §77 é o lugar da Essência real.
func _test_controller_pre_victory_block() -> void:
	var rig := await _make_rig(false, SHORT_PREP)
	var evolution := rig["evolution"] as CoreEvolutionController
	var state := rig["state"] as CoreState
	_reset_capture()
	_capture_controller(evolution)
	_set_essence_to(state, MAX_ESSENCE_LV1)
	await process_frame
	_check(state.essence >= MAX_ESSENCE_LV1 - 0.5,
			"§68 a cena isolada tem Essência de sobra, %f" % state.essence)
	_check(not evolution.is_unlocked(), "§68 ainda não houve vitória")
	_check(not evolution.can_evolve(), "§68/§30 can_evolve é false antes da vitória")
	_check(_close(evolution.evolution_cost(), COST), "§68 o preço lido é 25")
	_press_key(KEY_V)
	await _advance(0.2)
	_check(state.level == 1, "§68/§102 V antes da vitória deixou o Núcleo em Lv.1")
	_check(_close(state.integrity, INTEGRITY_LV1), "§68 a Integrity continua 100")
	_check(state.essence > MAX_ESSENCE_LV1 - COST,
			"§68 nenhuma Essência foi cobrada antes da hora, %f" % state.essence)
	_check(_mvp_events == 0 and _unlock_events == 0,
			"§68 nenhum sinal de progressão saiu, %d/%d" % [_unlock_events, _mvp_events])
	_free_rig()


## §71/§72/§73/§74: a transação em três pontos exatos da curva. O rig deste bloco fica
## fora da árvore de propósito: sem `_process` rodando, a Essência não anda entre o
## ajuste e a tecla, então "0" e "15" podem ser cobrados ao centésimo (§72/§73).
func _test_controller_transactions() -> void:
	var rig := await _make_detached_rig()
	var evolution := rig["evolution"] as CoreEvolutionController
	var state := rig["state"] as CoreState
	var core := rig["core"] as CoreRuntime
	evolution.unlock_after_victory()

	# §71/§103: um ponto abaixo do preço.
	_set_essence_to(state, 24.0)
	_check(not evolution.can_evolve(), "§71 com 24 de Essência can_evolve é false")
	_press_key(KEY_V)
	await _advance(0.2)
	_check(state.level == 1 and _close(state.essence, 24.0),
			"§71/§103 V com Essência insuficiente não evoluiu nem cobrou (level %d, %f)"
					% [state.level, state.essence])

	# §72: o preço exato.
	_set_essence_to(state, COST)
	_check(evolution.can_evolve(), "§72 com exatamente 25 can_evolve é true")
	_press_key(KEY_V)
	await _advance(0.2)
	_check(state.level == 2, "§72 a tecla levou o Núcleo ao Lv.2")
	_check(_close(state.essence, 0.0, 0.01),
			"§72/§106 custo aplicado uma vez, essência %f" % state.essence)
	_check(_close(state.integrity, INTEGRITY_LV2),
			"§72/§12 a Integrity do Lv.2 abriu no teto, %f" % state.integrity)
	_check(core.definition() == load(CORE_2_PATH), "§72/§16 o Runtime trocou a referência")

	# §74: o segundo V. Nada de segunda cobrança, nada de Level 3.
	var after_first := _snapshot(state)
	_press_key(KEY_V)
	await _advance(0.2)
	_check(_snapshot(state) == after_first,
			"§74/§38 o segundo V não alterou level, essence nem integrity")
	_check(state.level == 2, "§91/§74 continua Lv.2, não existe Lv.3")
	_check(_mvp_events == 1, "§88 mvp_completed uma única vez, %d" % _mvp_events)
	_free_rig()


## §75/§32: o preço é dado da Definition de destino. Trocar o .tres troca o controller —
## é a única forma de provar que não existe um 25 escrito no meio do caminho.
func _test_cost_comes_from_definition() -> void:
	var lv1 := load(CORE_1_PATH) as CoreDefinition
	var lv2 := load(CORE_2_PATH) as CoreDefinition
	var custom := lv2.duplicate() as CoreDefinition
	custom.evolution_essence_cost = 7.0
	var core := CORE_SCENE.instantiate() as CoreRuntime
	var state := CoreState.new(lv1)
	var controller := CoreEvolutionController.new()
	controller.name = "EvolutionProbe"
	root.add_child(controller)
	await process_frame
	controller.setup(core, state, custom)
	_check(_close(controller.evolution_cost(), 7.0),
			"§75 o custo veio da Definition injetada, obtido %f" % controller.evolution_cost())
	custom.evolution_essence_cost = 33.0
	_check(_close(controller.evolution_cost(), 33.0),
			"§75/§32 o preço é lido na hora, não congelado no setup, %f"
					% controller.evolution_cost())
	custom.evolution_essence_cost = 41.0
	_check(_close(controller.evolution_cost(), 41.0),
			"§75/§101 o HUD e o controller compartilham o mesmo número lido, %f"
					% controller.evolution_cost())
	_check(_close(lv2.evolution_essence_cost, COST),
			"§75 a probe não contaminou o recurso real, %f" % lv2.evolution_essence_cost)
	controller.free()
	core.free()


## §69/§31: DEFEAT não libera nada. A derrota é a da Tarefa 12, atingida do jeito que o
## jogo a atinge — o Núcleo cai — e a tecla continua sem efeito depois dela.
func _test_defeat_does_not_unlock() -> void:
	var rig := await _make_rig(true, SHORT_PREP)
	var evolution := rig["evolution"] as CoreEvolutionController
	var invasion := rig["invasion"] as InvasionController
	var state := rig["state"] as CoreState
	_reset_capture()
	_capture_controller(evolution)
	_press_key(KEY_F)
	_check(await _wait_until(
			func() -> bool: return _invasion_is(invasion, INVASION_ACTIVE), 20.0),
			"§69 o rig de derrota chegou a ACTIVE")
	_set_essence_to(state, MAX_ESSENCE_LV1)
	state.damage(INTEGRITY_LV1 * 10.0)
	await _advance(0.2)
	_check(invasion.invasion_state() == InvasionController.InvasionState.DEFEAT,
			"§69 o desfecho foi DERROTA")
	_check(not evolution.is_unlocked(), "§69/§31 derrota nenhuma liberou evolução")
	_press_key(KEY_V)
	await _advance(0.2)
	_check(state.level == 1, "§69 V depois de DEFEAT não evolui")
	_check(state.essence > MAX_ESSENCE_LV1 - COST,
			"§69/§31 e não cobrou nada, %f" % state.essence)
	_check(_mvp_events == 0, "§69/§88 sem vitória não existe MVP, %d" % _mvp_events)
	_free_rig()


## §70/§28/§29: a vitória chega por signal, exatamente uma vez, e é ela que liga a
## chave — o controller nunca olhou para o estado da invasão.
func _test_victory_unlocks_by_signal() -> void:
	var rig := await _make_rig(true, SHORT_PREP)
	var evolution := rig["evolution"] as CoreEvolutionController
	var invasion := rig["invasion"] as InvasionController
	var state := rig["state"] as CoreState
	_reset_capture()
	_capture_controller(evolution)
	_capture_state(state)
	_press_key(KEY_F)
	_check(await _wait_until(
			func() -> bool: return _invasion_is(invasion, INVASION_ACTIVE), 20.0),
			"§70 o rig de vitória largou a invasão")
	_check(not evolution.is_unlocked(), "§70 durante ACTIVE ainda está bloqueado")
	_press_key(KEY_V)
	await _advance(0.2)
	_check(state.level == 1, "§70/§30 V em ACTIVE não faz nada")
	for invader in invasion.invaders():
		invader.receive_damage(BEAST_HP * 2.0)
	await _advance(0.3)
	_check(invasion.invasion_state() == InvasionController.InvasionState.VICTORY,
			"§70 o rig venceu")
	_check(_unlock_events == 1, "§70 evolution_unlocked uma emissão, %d" % _unlock_events)
	_check(evolution.is_unlocked(), "§70 is_unlocked é true depois de invasion_victory")
	_check(_mvp_events == 0, "§88 destravar não é concluir, %d" % _mvp_events)
	# §39/§70: a vitória repetida não reemite nada.
	evolution.unlock_after_victory()
	await _advance(0.1)
	_check(_unlock_events == 1, "§39/§70 unlock idempotente, %d" % _unlock_events)
	_check(_evolved_events == 0, "§70 destravar sozinho não evoluiu nada")
	_set_essence_to(state, COST)
	_press_key(KEY_V)
	await _advance(0.4)
	_check(state.level == 2, "§70/§28 o mesmo signal que abriu a porta fecha o ciclo")
	_check(_mvp_events == 1, "§88 mvp_completed exatamente uma vez, %d" % _mvp_events)
	_check(_evolved_events == 1, "§58 no rig evolved saiu exatamente uma vez, %d"
			% _evolved_events)
	_check(invasion.invasion_state() == InvasionController.InvasionState.VICTORY,
			"§46/§81 evoluir não polarizou o estado da invasão")
	_free_rig()


# ====================================================== Bloco 3 — a campanha real


func _test_boot_surface() -> void:
	_check(_core_state.level == 1, "§106 a partida abre no Lv.1")
	_check(_close(_core_state.integrity, INTEGRITY_LV1), "§106 Integrity 100")
	_check(_close(_core_state.definition.max_essence, MAX_ESSENCE_LV1),
			"§106 teto de Essência 50")
	_check(_close(_evolution.evolution_cost(), COST), "§75 o custo na cena real vem do .tres")
	_check(not _evolution.is_unlocked(), "§40 a evolução abre bloqueada")
	_check(_text_of(_evolution_hud, "LevelLabel") == LEVEL_1_LINE,
			"§40 a primeira linha é \"%s\", obtido %s"
					% [LEVEL_1_LINE, _text_of(_evolution_hud, "LevelLabel")])
	_check(_text_of(_evolution_hud, "OfferLabel") == LOCKED_OFFER,
			"§40 a segunda linha é \"%s\", obtido %s"
					% [LOCKED_OFFER, _text_of(_evolution_hud, "OfferLabel")])
	_check(_text_of(_evolution_hud, "StatusLabel") == LOCKED_STATUS,
			"§40 a terceira linha é \"%s\", obtido %s"
					% [LOCKED_STATUS, _text_of(_evolution_hud, "StatusLabel")])
	_check(not _evolution_hud.find_child("StatsLabel", true, false).visible,
			"§42 as estatísticas do Nv.2 só aparecem depois da evolução")
	_check(_text_of(_core_hud, "TitleLabel") == CORE_TITLE_LV1,
			"§44 o título do CoreDebugHud abre como \"%s\", obtido %s"
					% [CORE_TITLE_LV1, _text_of(_core_hud, "TitleLabel")])
	_check(_text_of(_core_hud, "IntegrityLabel") == "Integrity: 100 / 100",
			"§85 antes: Integrity 100 / 100, obtido %s"
					% _text_of(_core_hud, "IntegrityLabel"))
	_check(_text_of(_core_hud, "EssenceLabel") == "Essence: 20 / 50",
			"§85 antes: Essence 20 / 50, obtido %s"
					% _text_of(_core_hud, "EssenceLabel"))
	_check(_text_of(_core_hud, "PopulationLabel") == "Population: 1 / 8",
			"§85 antes: Population 1 / 8, obtido %s"
					% _text_of(_core_hud, "PopulationLabel"))
	var offenders := _controls_not_ignoring(_scene.get_node("UI"))
	_check(offenders.is_empty(),
			"§87/§43 nenhum Control da UI intercepta mouse, %s" % [offenders])


## §68/§102 na cena de produção: a campanha inteira está bloqueada antes da vitória,
## inclusive com Essência suficiente no tanque.
func _test_v_key_does_nothing_before_victory() -> void:
	var essence_before := _core_state.essence
	_press_key(KEY_V)
	await _advance(0.2)
	_check(_core_state.level == 1, "§102 o Núcleo permanece Nv.1")
	_check(_core_state.essence >= essence_before - 0.001,
			"§68 V não cobrou nada na campanha (%f → %f)"
					% [essence_before, _core_state.essence])
	_check(_text_of(_core_hud, "TitleLabel") == CORE_TITLE_LV1,
			"§102 o título continua \"%s\", obtido %s"
					% [CORE_TITLE_LV1, _text_of(_core_hud, "TitleLabel")])
	_check(_text_of(_evolution_hud, "OfferLabel") == LOCKED_OFFER,
			"§102 o painel continua mostrando \"%s\"" % LOCKED_OFFER)


## §76: o fluxo completo da Tarefa 13, tecla por tecla, sem nenhuma doação de Essência
## (§77). O Soldado só é recrutado quando a geração natural paga a conta.
func _test_campaign_to_victory() -> void:
	_check(_core_state.essence >= WORKER_COST,
			"§77 a campanha começa com Essência para o segundo Worker, %f" % _core_state.essence)
	_press_key(KEY_I)
	await _advance(0.4)
	var workers := _workers_in_scene()
	_worker2 = workers[1] if workers.size() == 2 else null
	_check(_worker2 != null, "§76 o Worker002 chegou pela tecla I")
	_check(_core_state.population == 2,
			"§76 população 2 após a invocação, obtido %d" % _core_state.population)
	_measurements["essence_after_worker"] = _core_state.essence

	await _mine_with_two_workers(_rock_with_id(FIRST_ORE_ROCK_ID))
	_check(_stockpile.get_amount(ORE) == 3,
			"§76 a primeira rocha pagou o Ninho, %d no depósito" % _stockpile.get_amount(ORE))
	_press_key(KEY_B)
	await _advance(0.2)
	var nest := _construction.nest()
	_check(nest != null, "§76 B abriu o canteiro do Ninho")
	if nest == null:
		return
	_place(_worker, Vector3(NEST_POINT.x + 1.5, 0.0, NEST_POINT.z + 0.9))
	_place(_worker2, Vector3(NEST_POINT.x + 1.5, 0.0, NEST_POINT.z - 0.9))
	await _advance(0.1)
	_selection.clear_selection()
	await _click_select(_worker)
	await _shift_click_select(_worker2)
	await _right_click(nest.global_position)
	_check(await _wait_until(func() -> bool: return nest.is_completed(), 40.0),
			"§76 o Ninho foi construído pelos dois Workers")
	_check(_core_state.get_population_capacity() == CAPACITY_LV1 + NEST_BONUS,
			"§76/§55 capacidade 12 com o Ninho, obtido %d"
					% _core_state.get_population_capacity())

	await _mine_with_two_workers(_rock_with_id(SECOND_ORE_ROCK_ID))
	_place(_worker, Vector3(BARRACKS_POINT.x + 1.5, 0.0, BARRACKS_POINT.z + 0.9))
	_place(_worker2, Vector3(BARRACKS_POINT.x + 1.5, 0.0, BARRACKS_POINT.z - 0.9))
	await _advance(0.1)
	_press_key(KEY_K)
	await _advance(0.2)
	var barracks := _construction.barracks()
	_check(barracks != null, "§76 K criou o Quartel")
	if barracks == null:
		return
	_selection.clear_selection()
	await _click_select(_worker)
	await _shift_click_select(_worker2)
	await _right_click(barracks.global_position)
	_check(await _wait_until(func() -> bool: return barracks.is_completed(), 40.0),
			"§76 o Quartel ficou pronto")

	# §77: nada de Essência de graça — se faltar, o teste espera a geração natural.
	var paid := await _wait_until_real(
			func() -> bool: return _core_state.essence >= SOLDIER_COST, 90.0)
	_measurements["essence_before_soldier"] = _core_state.essence
	_check(paid, "§77 a geração natural pagou o Soldado, %f" % _core_state.essence)
	_press_key(KEY_R)
	await _advance(0.4)
	_soldier = _recruitment.soldier()
	_check(_soldier != null, "§76 R recrutou o Soldado")
	_check(_core_state.population == 3,
			"§50/§76 população 3 no ciclo normal, obtido %d" % _core_state.population)
	if _soldier == null:
		return
	_check(_close(_soldier.state.health, SOLDIER_HP),
			"§76 o Soldado chegou inteiro, %f" % _soldier.state.health)
	_selection.clear_selection()
	await _click_select(_soldier)
	await _right_click(SOLDIER_DEFENSE)
	await _wait_until(func() -> bool: return not _soldier.has_move_target(), 20.0)

	_check(_invasion.invasion_state() == InvasionController.InvasionState.PREPARATION,
			"§76 a invasão ainda está em preparação antes do zero")
	_check(not _evolution.is_unlocked(), "§76 antes da vitória continua bloqueado")
	_check(_text_of(_evolution_hud, "OfferLabel") == LOCKED_OFFER,
			"§76/§40 nem Ninho, nem Quartel, nem Soldado destravam a evolução")
	var launched := await _wait_until(
			func() -> bool: return _invasion_is(_invasion, INVASION_ACTIVE), 90.0)
	_check(launched, "§76 o cronômetro de 60 s largou a invasão sozinho")
	var invaders := _invasion.invaders()
	_check(invaders.size() == 2, "§76 as duas Feras da Tarefa 12")
	_selection.clear_selection()
	await _click_select(_soldier)
	await _right_click(_body_screen_position(invaders[0].global_position))
	await _advance(0.05)
	var first_id := invaders[0].get_instance_id()
	_check(await _wait_until(
			func() -> bool: return not is_instance_id_valid(first_id), 60.0),
			"§76 o Soldado derrubou o Invader001")
	await _right_click(_body_screen_position(invaders[1].global_position))
	await _advance(0.05)
	var second_id := invaders[1].get_instance_id()
	_check(await _wait_until(
			func() -> bool: return not is_instance_id_valid(second_id), 60.0),
			"§76 o Soldado derrubou o Invader002")
	_check(_invasion.invasion_state() == InvasionController.InvasionState.VICTORY,
			"§76 a campanha real terminou em VICTORY")
	_check(_core_state.integrity > 0.0,
			"§76 o Núcleo sobreviveu para evoluir, %f" % _core_state.integrity)
	_measurements["integrity_at_victory"] = _core_state.integrity


## §41/§86: o painel da vitória. A oferta aparece sem ninguém pedir, e o preço mostrado
## é o preço da Definition.
func _test_evolution_offer_after_victory() -> void:
	_check(_evolution.is_unlocked(), "§70/§86 a vitória chegou ao painel por signal")
	_check(_text_of(_evolution_hud, "LevelLabel") == LEVEL_1_LINE,
			"§41 antes de evoluir a primeira linha ainda é \"%s\", obtido %s"
					% [LEVEL_1_LINE, _text_of(_evolution_hud, "LevelLabel")])
	_check(_text_of(_evolution_hud, "OfferLabel") == OFFER_LINE,
			"§41/§101 a oferta mostra o preço da Definition, obtido %s"
					% _text_of(_evolution_hud, "OfferLabel"))
	var status := _text_of(_evolution_hud, "StatusLabel")
	var enough := _core_state.essence >= COST
	_check(status == (READY_STATUS if enough else INSUFFICIENT_STATUS),
			"§41 o status acompanha a conta real (%f Essência → %s, obtido %s)"
					% [_core_state.essence,
							READY_STATUS if enough else INSUFFICIENT_STATUS, status])
	_measurements["essence_at_victory"] = _core_state.essence
	print("[INFO] §77 Essência medida no instante da vitória: %f (custo %f)."
			% [_core_state.essence, COST])


## §76/§77: a tecla V real, com a Essência que a partida produziu. Se ainda faltar, o
## teste espera a geração natural — nunca doa recurso.
func _test_real_input_evolves_core() -> void:
	var waited := true
	if _core_state.essence < COST:
		waited = await _wait_until_real(
				func() -> bool: return _core_state.essence >= COST, 90.0)
	_check(waited, "§77 a Essência chegou a 25 por geração natural, %f" % _core_state.essence)
	var essence_before := _core_state.essence
	var integrity_before := _core_state.integrity
	var core_id := _core.get_instance_id()
	var state_id := _core_state.get_instance_id()
	var scene_id := _scene.get_instance_id()
	_stockpile_before = _stockpile.get_amount(ORE)
	_measurements["essence_before_evolution"] = essence_before
	_measurements["integrity_before_evolution"] = integrity_before

	_press_key(KEY_V)
	_check(await _wait_until(func() -> bool: return _core_state.level == 2, 5.0),
			"§76 V atravessou o input real e evoluiu o Núcleo")
	_check(_core.get_instance_id() == core_id, "§62 na campanha o CoreRuntime é o mesmo")
	_check(_core_state.get_instance_id() == state_id, "§63 na campanha o State é o mesmo")
	_check(_scene.get_instance_id() == scene_id,
			"§95/§89 a partida não foi recarregada nem trocada")
	_check(_close(_core_state.essence, essence_before - COST, 0.5),
			"§101/§73 a Essência caiu exatamente o preço (%f → %f)"
					% [essence_before, _core_state.essence])
	_check(integrity_before < INTEGRITY_LV2,
			"§12 a Integrity de antes estava abaixo do teto novo, %f" % integrity_before)
	_check(_mvp_events == 1, "§88 o MVP foi anunciado uma vez na cena real, %d" % _mvp_events)
	_measurements["essence_after_evolution"] = _core_state.essence


## §78: o retrato completo depois da evolução real, impresso e cobrado campo a campo.
func _test_state_after_real_evolution() -> void:
	var definition := _core.definition()
	_check(_core_state.level == 2, "§78 Core level 2")
	_check(definition == load(CORE_2_PATH), "§78/§16 a Definition lida é a Lv.2")
	_check(_close(_core_state.integrity, INTEGRITY_LV2),
			"§78/§12 Integrity 150, obtido %f" % _core_state.integrity)
	_check(_core_state.essence >= 0.0 and _core_state.essence <= MAX_ESSENCE_LV2,
			"§78 Essence dentro do tanque novo, %f" % _core_state.essence)
	_check(_close(definition.max_essence, MAX_ESSENCE_LV2),
			"§78 Max Essence 80, obtido %f" % definition.max_essence)
	_check(_close(definition.essence_generation_rate, RATE_LV2),
			"§78/§96 generation rate 1.5, obtido %f" % definition.essence_generation_rate)
	_check(_core_state.population == 3, "§78/§51 Population 3 preservada")
	_check(definition.population_capacity == CAPACITY_LV2,
			"§78 Base Capacity 12, obtido %d" % definition.population_capacity)
	_check(_core_state.population_capacity_bonus == NEST_BONUS,
			"§98/§78 Nest bonus continua 4, obtido %d" % _core_state.population_capacity_bonus)
	_check(_core_state.get_population_capacity() == CAPACITY_LV2 + NEST_BONUS,
			"§55/§78 Effective Capacity 16, obtido %d"
					% _core_state.get_population_capacity())
	_check(_core_state.core_id == "main_core", "§106/§2 core_id main_core na campanha")
	_measurements["after_evolution"] = _snapshot(_core_state)


## §79–§84, §99, §100: nada foi recriado, removido nem respawnado pelo Nv.2.
func _test_world_preserved_after_evolution() -> void:
	_check(_count_type("NestRuntime") == 1, "§99 exatamente 1 Ninho, obtido %d"
			% _count_type("NestRuntime"))
	_check(_count_type("BarracksRuntime") == 1, "§99 exatamente 1 Quartel, obtido %d"
			% _count_type("BarracksRuntime"))
	_check(_count_type("CoreRuntime") == 1, "§99/§94 exatamente 1 Núcleo, obtido %d"
			% _count_type("CoreRuntime"))
	_check(_workers_in_scene().size() == 2, "§100 continuam 2 Workers, obtido %d"
			% _workers_in_scene().size())
	_check(_count_type("SoldierRuntime") == 1, "§100 continua 1 Soldier, obtido %d"
			% _count_type("SoldierRuntime"))
	_check(_enemies_in_scene().is_empty(), "§91/§29 a evolução não chamou segunda invasão")
	_check(_deposit == _scene.get_node("World/DungeonRoot/Deposit001"),
			"§47 o depósito é a mesma instância")
	_check(_construction.nest() != null and _construction.nest().is_inside_tree(),
			"§47 o Ninho continua na cena")
	_check(_construction.barracks() != null and _construction.barracks().is_inside_tree(),
			"§47 o Quartel continua na cena")
	_check(_soldier != null and _soldier.is_inside_tree(),
			"§48 o Soldado continua no mapa, sem respawn")
	var health := _soldier.state.health if _soldier != null else -1.0
	_check(health > 0.0 and health <= SOLDIER_HP,
			"§48 o Soldado não foi resetado nem imunizado pela evolução, %f" % health)
	_check(_core.global_position.distance_to(CORE_HOME) < 0.001,
			"§101 o Núcleo está onde sempre esteve, %s" % str(_core.global_position))
	_check(_close(_core.scale.x, LEVEL_2_SCALE, 0.001),
			"§101 o corpo cresceu na cena real, escala %s" % str(_core.scale))
	_check(_core.get_node("Level2Detail").visible, "§64/§101 o anel do Nv.2 está visível")
	_check(_stockpile.get_amount(ORE) == _stockpile_before,
			"§82 o minério armazenado não mudou com a evolução (%d → %d)"
					% [_stockpile_before, _stockpile.get_amount(ORE)])
	_check(_invasion.invasion_state() == InvasionController.InvasionState.VICTORY,
			"§46/§81 InvasionController continua VICTORY")
	# §81/§91: `invaders()` é o registro da onda, não a lista dos vivos — as duas Feras
	# mortas continuam ali como memória da partida. O que a evolução não pode fazer é
	# acordar alguém ou chamar onda nova: zero ativos e a mesma onda de sempre.
	var survivors := 0
	for invader in _invasion.invaders():
		if is_instance_valid(invader):
			survivors += 1
	_check(_invasion.active_invaders() == 0,
			"§81/§91 nenhum invasor ativo depois da evolução, %d"
					% _invasion.active_invaders())
	_check(survivors == 0 and _invasion.invaders().size() == 2,
			"§81/§91 a onda continua as mesmas duas Feras, sem viva nenhuma (%d vivas, %d na onda)"
					% [survivors, _invasion.invaders().size()])


## §44/§45/§85/§86: os dois painéis depois do Nv.2.
func _test_hud_after_evolution() -> void:
	_check(_text_of(_core_hud, "TitleLabel") == CORE_TITLE_LV2,
			"§44 o título virou \"%s\", obtido %s"
					% [CORE_TITLE_LV2, _text_of(_core_hud, "TitleLabel")])
	_check(_text_of(_core_hud, "IntegrityLabel") == "Integrity: 150 / 150",
			"§85/§59 o painel mostra 150 / 150, obtido %s"
					% _text_of(_core_hud, "IntegrityLabel"))
	_check(_text_of(_core_hud, "EssenceLabel").contains(" / 80"),
			"§60/§85 o teto novo apareceu na linha de Essência, obtido %s"
					% _text_of(_core_hud, "EssenceLabel"))
	_check(_text_of(_core_hud, "PopulationLabel") == "Population: 3 / 16",
			"§61/§45 Population 3 / 16 no painel, obtido %s"
					% _text_of(_core_hud, "PopulationLabel"))
	_check(_text_of(_evolution_hud, "LevelLabel") == NV2_LINE,
			"§42 a primeira linha virou \"%s\", obtido %s"
					% [NV2_LINE, _text_of(_evolution_hud, "LevelLabel")])
	_check(_text_of(_evolution_hud, "OfferLabel") == MVP_LINE,
			"§42/§86 o painel anuncia \"%s\", obtido %s"
					% [MVP_LINE, _text_of(_evolution_hud, "OfferLabel")])
	var stats_label := _evolution_hud.find_child("StatsLabel", true, false) as Label
	var stats := stats_label.text if stats_label != null else "<ausente>"
	_check(stats_label != null and stats_label.visible,
			"§42 as estatísticas do Nv.2 entraram na tela")
	_check(stats.contains("Integrity: 150") and stats.contains("Essence Capacity: 80")
			and stats.contains("Generation: 1.5/s") and stats.contains("Population Base: 12"),
			"§42 a legenda lê a Definition nova, obtido %s" % stats)
	# §87: clicar atravessando o retângulo do painel é clique no mundo.
	_selection.clear_selection()
	await _click_select(_worker)
	var worker_point := _screen_of_body(_worker)
	var panel := _evolution_hud as Control
	var inside := panel.global_position + panel.size * 0.5
	_check(worker_point.distance_to(inside) > 8.0,
			"§87 o ponto do painel não é o ponto do Worker (%s vs %s)"
					% [str(worker_point), str(inside)])
	_press(MOUSE_BUTTON_LEFT, inside)
	_release(MOUSE_BUTTON_LEFT, inside)
	await _advance(0.1)
	_check(_unit_ids() != ["worker_001"],
			"§87 o clique dentro do painel chegou ao mundo em vez de ser engolido, %s"
					% [_unit_ids()])
	_check(panel.visible, "§87 o painel continua visível, sem bloquear input")


## §74/§106: depois do MVP a mesma tecla não cobra de novo, e não existe nível seguinte.
func _test_second_v_charges_nothing() -> void:
	var essence_before := _core_state.essence
	var integrity_before := _core_state.integrity
	_press_key(KEY_V)
	await _advance(0.2)
	_check(_core_state.level == 2, "§74/§91 o segundo V não criou Lv.3")
	_check(_close(_core_state.integrity, integrity_before),
			"§74 a Integrity não mudou, %f" % _core_state.integrity)
	_check(_core_state.essence >= essence_before - 0.001,
			"§106 nenhuma cobrança duplicada aconteceu (%f → %f)"
					% [essence_before, _core_state.essence])
	_check(_mvp_events == 1, "§88 o MVP não foi reanunciado, %d" % _mvp_events)
	_check(_evolved_events == 1, "§58 na campanha evolved saiu uma vez, %d" % _evolved_events)
	_check(not _evolution.can_evolve(), "§39 can_evolve fechou a porta")


## §83/§84/§90: o mundo continua sendo um RTS depois da celebração.
func _test_world_still_runs_after_mvp() -> void:
	# §90: a Essência segue o relógio novo, sem timer reiniciado.
	var before := _core_state.essence
	await _advance_real(1.0)
	var gained := _core_state.essence - before
	_measurements["post_mvp_gain_1s"] = gained
	_check(_close(gained, RATE_LV2, 0.35),
			"§90/§96 depois do MVP a geração é 1.5/s, obtido %f" % gained)

	# §90: a câmera responde ao input do jogador.
	var rig_position := _camera_rig.global_position
	Input.action_press("camera_forward")
	await _advance_real(0.4)
	Input.action_release("camera_forward")
	await _advance_real(0.1)
	_check(_camera_rig.global_position.z < rig_position.z - 0.2,
			"§90 a câmera continua andado (%s → %s)"
					% [str(rig_position), str(_camera_rig.global_position)])

	# §83: seleção de grupo e ordem de movimento continuam funcionando. §90 mexeu na
	# vista para provar o pan; aqui o alvo precisa estar dentro da tela, então o rig volta
	# para a origem — e a chegada é medida no ponto que o raycast realmente acertou.
	_camera_rig.global_position = Vector3.ZERO
	await _advance_real(0.1)
	_selection.clear_selection()
	await _click_select(_worker)
	await _shift_click_select(_worker2)
	_check(_unit_ids().size() == 2, "§83 os dois Workers continuam selecionáveis, %s"
			% [_unit_ids()])
	var hit := _ground_hit(GROUP_TARGET)
	_check(hit.get("collider", null) is StaticBody3D,
			"§83 o alvo do grupo está em chão livre, obtido %s" % [hit.get("collider", null)])
	var clicked: Vector3 = hit.get("position", Vector3.ZERO)
	var spacing := _selection.group_move_spacing
	var left := clicked + Vector3(-spacing * 0.5, 0.0, 0.0)
	var right := clicked + Vector3(spacing * 0.5, 0.0, 0.0)
	var parked_a := _worker.global_position
	var parked_b := _worker2.global_position
	await _right_click(GROUP_TARGET)
	_check(_worker.has_move_target() and _worker2.has_move_target(),
			"§83 os dois Workers receberam destino depois do Nv.2")
	_check(await _wait_until(_group_stopped, 45.0),
			"§83 o grupo andou e parou depois do Nv.2 (%s, %s)"
					% [str(_worker.global_position), str(_worker2.global_position)])
	# §83: cada um no seu slot da formação, sem assumir em que ordem a seleção chegou.
	var a_left := _planar_gap(_worker.global_position, left) < GROUP_ARRIVAL
	var a_right := _planar_gap(_worker.global_position, right) < GROUP_ARRIVAL
	var b_left := _planar_gap(_worker2.global_position, left) < GROUP_ARRIVAL
	var b_right := _planar_gap(_worker2.global_position, right) < GROUP_ARRIVAL
	_check((a_left and b_right) or (a_right and b_left),
			"§83 os dois pararam nos slots da formação, erros %f / %f / %f / %f"
					% [_planar_gap(_worker.global_position, left),
							_planar_gap(_worker.global_position, right),
							_planar_gap(_worker2.global_position, left),
							_planar_gap(_worker2.global_position, right)])
	_check(_planar_gap(parked_a, _worker.global_position) > 1.0
			and _planar_gap(parked_b, _worker2.global_position) > 1.0,
			"§83 os dois caminharam de verdade, %f e %f"
					% [_planar_gap(parked_a, _worker.global_position),
							_planar_gap(parked_b, _worker2.global_position)])

	# §84: escavar continua. A CommonRock que sobrou da campanha é o alvo.
	var rock := _rock_with_id(SPARE_ROCK_ID)
	_check(rock != null, "§84 a rocha comum da campanha ainda está lá")
	if rock != null:
		var work_before := rock.state.remaining_work
		_place(_worker, Vector3(rock.global_position.x + 2.5, 0.0, rock.global_position.z))
		await _advance(0.1)
		_selection.clear_selection()
		await _click_select(_worker)
		await _right_click(rock.global_position)
		_check(await _wait_until(
				func() -> bool: return rock.state.remaining_work < work_before, 20.0),
				"§84 o Worker voltou a escavar depois da evolução (%f → %f)"
						% [work_before, rock.state.remaining_work])

	# §89: nada pausou, fechou nem trocou de cena no caminho.
	_check(_scene.is_inside_tree() and not _scene.is_queued_for_deletion(),
			"§89 a partida continua aberta depois do MVP")
	_check(not paused, "§89 nenhum pause foi acionado")


## §8/§91: a escada para aqui. Não existe terceiro degrau, nem para trás.
func _test_no_third_level() -> void:
	var lv1 := load(CORE_1_PATH) as CoreDefinition
	var lv2 := load(CORE_2_PATH) as CoreDefinition
	_check(not _core_state.can_evolve_to(lv2), "§8 Lv.2 → Lv.2 não existe")
	_check(not _core_state.can_evolve_to(lv1), "§8/§57 voltar ao Lv.1 não existe")
	_check(not _core.evolve_to(lv2), "§22 o Runtime também recusa")
	_check(not _evolution.try_evolve(), "§39/§74 o controller também recusa")
	_check(_core_state.level == 2 and _close(_core_state.integrity, INTEGRITY_LV2),
			"§91 nada mudou depois das recusas (level %d, integrity %f)"
					% [_core_state.level, _core_state.integrity])
	_check(_files_in(DATA_CORE_DIR, ".tres").size() == 2,
			"§91 não existe Core Lv.3 em data/core")


# ==================================================================== Infraestrutura


func _reset_capture() -> void:
	_evolved_events = 0
	_evolved_args = []
	_integrity_events = 0
	_integrity_args = []
	_essence_events = 0
	_essence_args = []
	_capacity_events = 0
	_capacity_args = []
	_unlock_events = 0
	_mvp_events = 0
	_signal_order = []


## O State é o emissor de tudo que a §21 ordena; ligar os quatro sinais aqui é o que
## permite cobrar a ordem e a contagem, não só o valor final.
func _capture_state(state: CoreState) -> void:
	# Capturar é idempotente: os contadores é que zeram entre testes, as ligações
	# permanecem. Reconectar o mesmo callable no mesmo State encheria o log de ERROR.
	if not state.integrity_changed.is_connected(_on_integrity_changed):
		state.integrity_changed.connect(_on_integrity_changed)
	if not state.essence_changed.is_connected(_on_essence_changed):
		state.essence_changed.connect(_on_essence_changed)
	if not state.population_capacity_changed.is_connected(_on_capacity_changed):
		state.population_capacity_changed.connect(_on_capacity_changed)
	if not state.evolved.is_connected(_on_evolved):
		state.evolved.connect(_on_evolved)


func _capture_controller(controller: CoreEvolutionController) -> void:
	if not controller.evolution_unlocked.is_connected(_on_evolution_unlocked):
		controller.evolution_unlocked.connect(_on_evolution_unlocked)
	if not controller.mvp_completed.is_connected(_on_mvp_completed):
		controller.mvp_completed.connect(_on_mvp_completed)


func _on_integrity_changed(current: float, maximum: float) -> void:
	_integrity_events += 1
	_integrity_args = [current, maximum]
	_signal_order.append("integrity")


func _on_essence_changed(current: float, maximum: float) -> void:
	_essence_events += 1
	_essence_args = [current, maximum]
	_signal_order.append("essence")


func _on_capacity_changed(current_population: int, new_capacity: int) -> void:
	_capacity_events += 1
	_capacity_args = [current_population, new_capacity]
	_signal_order.append("capacity")


func _on_evolved(old_level: int, new_level: int) -> void:
	_evolved_events += 1
	_evolved_args = [old_level, new_level]
	_signal_order.append("evolved")


func _on_evolution_unlocked() -> void:
	_unlock_events += 1


func _on_mvp_completed() -> void:
	_mvp_events += 1


## Rig com CoreRuntime na árvore + InvasionController + CoreEvolutionController ligados
## exatamente como o GameMain liga (§27). `with_invasion` decide se existe invasão para
## vencer ou perder; sem ela o bloco testa só o gating da tecla.
func _make_rig(with_invasion: bool, preparation: float) -> Dictionary:
	_reset_capture()
	_rig = Node3D.new()
	_rig.name = "EvolutionRig"
	root.add_child(_rig)
	var dungeon := Node3D.new()
	dungeon.name = "DungeonRoot"
	_rig.add_child(dungeon)
	_rig_core = CORE_SCENE.instantiate() as CoreRuntime
	dungeon.add_child(_rig_core)
	_rig_core.global_position = CORE_HOME
	_rig_state = CoreState.new(load(CORE_1_PATH) as CoreDefinition)
	_rig_core.setup(load(CORE_1_PATH) as CoreDefinition, _rig_state)
	_rig_evolution = CoreEvolutionController.new()
	_rig_evolution.name = "CoreEvolutionController"
	_rig.add_child(_rig_evolution)
	await process_frame
	_rig_evolution.setup(_rig_core, _rig_state, load(CORE_2_PATH) as CoreDefinition)
	var out := {"core": _rig_core, "state": _rig_state, "evolution": _rig_evolution}
	if with_invasion:
		var point_a := Marker3D.new()
		point_a.name = "InvasionSpawnPointA"
		dungeon.add_child(point_a)
		var point_b := Marker3D.new()
		point_b.name = "InvasionSpawnPointB"
		dungeon.add_child(point_b)
		await process_frame
		point_a.global_position = SPAWN_A
		point_b.global_position = SPAWN_B
		_rig_invasion = InvasionController.new()
		_rig_invasion.name = "InvasionController"
		_rig.add_child(_rig_invasion)
		await process_frame
		_rig_invasion.setup(
				load(ENEMY_DEFINITION_PATH) as EnemyDefinition,
				ENEMY_SCENE,
				dungeon,
				_rig_core,
				[point_a, point_b])
		_rig_invasion.preparation_duration = preparation
		# A mesma linha da composition root de produção — nada aqui é polling.
		_rig_invasion.invasion_victory.connect(_rig_evolution.unlock_after_victory)
		out["invasion"] = _rig_invasion
	await process_frame
	return out


## Versão fora da árvore para as transações de centavo exato: sem `_process` no Runtime,
## a Essência não anda entre o ajuste do harness e o clique em V.
func _make_detached_rig() -> Dictionary:
	_reset_capture()
	_rig = Node3D.new()
	_rig.name = "DetachedRig"
	_rig_core = CORE_SCENE.instantiate() as CoreRuntime
	_rig.add_child(_rig_core)
	_rig_state = CoreState.new(load(CORE_1_PATH) as CoreDefinition)
	_rig_core.setup(load(CORE_1_PATH) as CoreDefinition, _rig_state)
	_rig_evolution = CoreEvolutionController.new()
	_rig_evolution.name = "DetachedEvolution"
	root.add_child(_rig_evolution)
	await process_frame
	_rig_evolution.setup(_rig_core, _rig_state, load(CORE_2_PATH) as CoreDefinition)
	_capture_controller(_rig_evolution)
	return {"core": _rig_core, "state": _rig_state, "evolution": _rig_evolution}


func _free_rig() -> void:
	_rig_invasion = null
	if _rig_evolution != null and is_instance_valid(_rig_evolution):
		if _rig_evolution.get_parent() != null:
			_rig_evolution.get_parent().remove_child(_rig_evolution)
		_rig_evolution.free()
	_rig_evolution = null
	_rig_core = null
	_rig_state = null
	if _rig != null and is_instance_valid(_rig):
		if _rig.is_inside_tree():
			root.remove_child(_rig)
		_rig.free()
	_rig = null


func _boot_scene() -> void:
	_scene = MAIN_SCENE.instantiate()
	root.add_child(_scene)
	await _advance(0.2)
	_dungeon = _scene.get_node("World/DungeonRoot") as Node3D
	_camera = _scene.get_node("World/CameraRig/Camera3D") as Camera3D
	_camera_rig = _scene.get_node("World/CameraRig") as Node3D
	_selection = _scene.get_node("Systems/SelectionController") as SelectionController
	_construction = _scene.get_node("Systems/ConstructionController") as ConstructionController
	_recruitment = _scene.get_node(
			"Systems/SoldierRecruitmentController") as SoldierRecruitmentController
	_invasion = _scene.get_node("Systems/InvasionController") as InvasionController
	_evolution = _scene.get_node("Systems/CoreEvolutionController") as CoreEvolutionController
	_deposit = _scene.get_node("World/DungeonRoot/Deposit001") as ResourceDepositRuntime
	_core = _scene.get_node("World/DungeonRoot/MainCore") as CoreRuntime
	_worker = _scene.get_node("World/DungeonRoot/Worker001") as WorkerRuntime
	_core_hud = _scene.get_node("UI/CoreDebugPanel")
	_evolution_hud = _scene.get_node("UI/CoreEvolutionDebugPanel")
	_stockpile = _deposit.stockpile
	_core_state = _core.core_state()
	_stockpile_before = _stockpile.get_amount(ORE)
	Engine.set_physics_ticks_per_second(TICKS)
	_reset_capture()
	_capture_state(_core_state)
	_capture_controller(_evolution)


func _free_scene() -> void:
	_soldier = null
	_worker2 = null
	if _scene != null and is_instance_valid(_scene):
		_scene.free()
	_scene = null
	_dungeon = null
	_camera = null
	_camera_rig = null
	_selection = null
	_construction = null
	_recruitment = null
	_invasion = null
	_evolution = null
	_deposit = null
	_core = null
	_core_state = null
	_stockpile = null
	_core_hud = null
	_evolution_hud = null
	_worker = null


## §77: ajustar Essência no rig é cena de ensaio; na campanha isto nunca é chamado.
func _set_essence_to(state: CoreState, value: float) -> void:
	var difference := value - state.essence
	if difference > 0.0:
		state.add_essence(difference)
	elif difference < 0.0:
		state.consume_essence(-difference)


func _snapshot(state: CoreState) -> Dictionary:
	return {
		"core_id": state.core_id,
		"level": state.level,
		"population": state.population,
		"bonus": state.population_capacity_bonus,
		"capacity": state.get_population_capacity(),
		"integrity": state.integrity,
		"essence": state.essence,
	}


func _count_type(type_name: String) -> int:
	return _dungeon.find_children("*", type_name, true, false).size()


func _workers_in_scene() -> Array[WorkerRuntime]:
	var found: Array[WorkerRuntime] = []
	for child in _dungeon.get_children():
		if child is WorkerRuntime and not child.is_queued_for_deletion():
			found.append(child as WorkerRuntime)
	return found


func _enemies_in_scene() -> Array[EnemyRuntime]:
	var found: Array[EnemyRuntime] = []
	for child in _dungeon.get_children():
		if child is EnemyRuntime and not child.is_queued_for_deletion():
			found.append(child as EnemyRuntime)
	return found


func _rock_with_id(id: String) -> RockRuntime:
	for child in _dungeon.get_children():
		if child is RockRuntime and (child as RockRuntime).rock_id == id \
				and not child.is_queued_for_deletion():
			return child as RockRuntime
	return null


func _rock_present(id: String) -> bool:
	return _rock_with_id(id) != null


## §69/§70/§76: um lambda de uma linha não pode quebrar o corpo em duas linhas no
## GDScript, e a comparação do enum de invasão é comprida demais para caber numa
## chamada de espera. A comparação mora aqui; as waiters só a chamam.
func _invasion_is(controller: InvasionController, target: int) -> bool:
	return controller.invasion_state() == target


## §83: os dois Workers sem destino. A chegada em si é medida por distância, no slot da
## formação; aqui a espera só precisa saber quando o movimento terminou.
func _group_stopped() -> bool:
	return not _worker.has_move_target() and not _worker2.has_move_target()


## §83: o chão real sob um ponto do mundo, pelo raycast da câmera — a mesma régua que
## test_multi_selection usa para descobrir onde o clique do jogador efetivamente caiu.
func _ground_hit(world_position: Vector3) -> Dictionary:
	var origin := _camera.project_ray_origin(_screen(world_position))
	var direction := _camera.project_ray_normal(_screen(world_position))
	var space := _scene.get_viewport().world_3d.direct_space_state
	return space.intersect_ray(
			PhysicsRayQueryParameters3D.create(origin, origin + direction * 1000.0, CLICKABLE))


## §97: o corpo de evolve_to, isolado. core_state.gd define a API pública de bônus do
## Ninho desde a Tarefa 07, então a guarda de "não readicionar bônus" tem que olhar o
## caminho de evolução, não o arquivo inteiro.
func _evolve_to_body(source: String) -> String:
	var at := source.find("func evolve_to(")
	if at < 0:
		return ""
	var next := source.find("\nfunc ", at + 1)
	if next < 0:
		return source.substr(at)
	return source.substr(at, next - at)


func _piles_in_scene() -> Array[ResourcePileRuntime]:
	var found: Array[ResourcePileRuntime] = []
	for child in _dungeon.get_children():
		if child is ResourcePileRuntime and not child.is_queued_for_deletion():
			found.append(child as ResourcePileRuntime)
	return found


func _find_pile() -> ResourcePileRuntime:
	var piles := _piles_in_scene()
	return piles[0] if piles.size() == 1 else null


func _total_cargo() -> int:
	var total := 0
	for worker in _workers_in_scene():
		total += worker.state.carried_amount
	return total


func _unit_ids() -> Array[String]:
	var ids: Array[String] = []
	for unit in _selection.selected_units:
		ids.append(unit.get_unit_id())
	return ids


## Um turno completo de mineração, igual ao das suítes anteriores: esgotar a rocha,
## coletar a pilha e entregar no depósito — tudo com a campanha correndo.
func _mine_with_two_workers(rock: RockRuntime) -> void:
	if rock == null:
		_check(false, "§76 a rocha de minério da campanha não foi encontrada")
		return
	var rock_id := rock.rock_id
	var rock_position := rock.global_position
	_place(_worker, Vector3(rock_position.x + 2.5, 0.0, rock_position.z + 1.0))
	_place(_worker2, Vector3(rock_position.x + 2.5, 0.0, rock_position.z - 1.0))
	await _advance(0.1)
	_selection.clear_selection()
	await _click_select(_worker)
	await _shift_click_select(_worker2)
	await _right_click(rock_position)
	_check(await _wait_until(func() -> bool: return not _rock_present(rock_id), 60.0),
			"§76 a rocha %s foi esgotada pelos dois Workers" % rock_id)
	_check(await _wait_until(func() -> bool: return _find_pile() != null, 10.0),
			"§76 a rocha %s virou uma pilha" % rock_id)
	if _find_pile() == null:
		return
	await _right_click(_find_pile().global_position)
	_check(await _wait_until(func() -> bool: return _total_cargo() == 3, 40.0),
			"§76 os Workers encheram a carga de 3, obtido %d" % _total_cargo())
	_check(await _wait_until(func() -> bool: return _total_cargo() == 0, 60.0),
			"§76 a carga chegou ao depósito")


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


func _body_screen_position(point: Vector3) -> Vector3:
	return point + Vector3(0.0, 0.4, 0.0)


func _screen(world_position: Vector3) -> Vector2:
	return _camera.unproject_position(world_position)


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


func _press_key(physical_keycode: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = physical_keycode
	event.pressed = true
	root.push_input(event)
	event.pressed = false
	root.push_input(event)


func _advance(seconds: float) -> void:
	var ticks := int(ceil(seconds * Engine.get_physics_ticks_per_second()))
	for _tick in maxi(ticks, 1):
		await physics_frame


func _advance_real(seconds: float) -> void:
	var target := int(seconds * 1000.0)
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < target:
		await process_frame


func _wait_until(condition: Callable, max_seconds: float) -> bool:
	var limit := int(max_seconds * Engine.get_physics_ticks_per_second())
	var guard := 0
	while not condition.call() and guard < limit:
		await physics_frame
		guard += 1
	return condition.call()


func _wait_until_real(condition: Callable, max_seconds: float) -> bool:
	var limit := int(max_seconds * 1000.0) + 4000
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < limit:
		if condition.call():
			return true
		await process_frame
	return condition.call()


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


func _code_of(path: String) -> String:
	var kept: Array[String] = []
	for line in _source(path).split("\n"):
		var comment_at := line.find("#")
		kept.append(line.substr(0, comment_at) if comment_at >= 0 else line)
	return "\n".join(kept)


func _source(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func _files_in(path: String, extension: String) -> Array[String]:
	var found: Array[String] = []
	var directory := DirAccess.open(path)
	if directory == null:
		return found
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if not directory.current_is_dir() and entry.ends_with(extension):
			found.append(entry)
		entry = directory.get_next()
	directory.list_dir_end()
	found.sort()
	return found


func _collect_gd_files(path: String) -> Array[String]:
	var found: Array[String] = []
	_collect_gd_files_into(path, found)
	return found


func _collect_gd_files_into(path: String, into: Array[String]) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if entry != "tests" and entry != ".godot":
			var full := path.path_join(entry)
			if directory.current_is_dir():
				_collect_gd_files_into(full, into)
			elif entry.ends_with(".gd"):
				into.append(full)
		entry = directory.get_next()
	directory.list_dir_end()


func _files_containing(sources: Array[String], needle: String) -> Array[String]:
	var offenders: Array[String] = []
	for path in sources:
		if _source(path).contains(needle):
			offenders.append(path)
	return offenders


func _close(a: float, b: float, tolerance := 0.001) -> bool:
	return absf(a - b) <= tolerance


func _planar_gap(from: Vector3, to: Vector3) -> float:
	var offset := to - from
	offset.y = 0.0
	return offset.length()


func _print_measurements() -> void:
	print("[INFO] medições da evolução: %s" % [_measurements])


func _check(condition: bool, label: String) -> void:
	_asserts += 1
	if condition:
		print("[PASS] %s" % label)
	else:
		_failures += 1
		print("[FAIL] %s" % label)


func _finish() -> void:
	print("---- core evolution tests finished: %d asserts, %d failure(s) ----"
			% [_asserts, _failures])
	quit(1 if _failures > 0 else 0)
