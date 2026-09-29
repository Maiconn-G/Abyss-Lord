extends SceneTree

# Tarefa 17 — Cristal Abissal: recompensa da primeira invasão e alinhamento da evolução.
#
# A suíte prova uma coisa em duas metades que precisam se encontrar. O Cristal é a marca
# que a primeira invasão deixa no domínio (não um recurso que se carrega), e a evolução
# Nv.1 → Nv.2 só fecha quando a vitória, a chave e a Essência existem juntas — cobradas na
# mesma transação.
#
# Quatro blocos, nesta ordem:
#   1) dados e fontes — a Definition, o .tres, o que o Cristal deliberately NÃO é
#      (estoque operacional, pilha, gerência, RewardManager) (§54–§55, §96–§98, §101);
#   2) API do State — add/consume/has, recusas, sinal só quando o número muda
#      (§56–§61, §9–§12);
#   3) rig de invasão e de evolução, sem GameMain — o ciclo da recompensa (primeiro kill,
#      VICTORY, idempotência, DEFEAT, combate isolado) e a matriz de atomicidade da
#      evolução (§16–§23, §31–§42, §65–§79);
#   4) campanha real na cena de produção — painel antes e depois, nenhum pile, estoque de
#      Iron intacto e o MVP canônico fechado com V de verdade e Essência natural
#      (§64, §72–§73, §81–§87).
#
# §82 é a regra deste arquivo inteiro: no caminho principal a Essência é medida e
# esperada, nunca doada. Valores fixos só aparecem nos rigs de ensaio, onde o que se
# testa é a conta, não a partida.

const MAIN_SCENE := preload("res://game/GameMain.tscn")
const CORE_SCENE := preload("res://world/dungeon/core/CoreRuntime.tscn")
const ENEMY_SCENE := preload("res://units/enemies/EnemyRuntime.tscn")
const EVOLUTION_HUD_SCENE := preload("res://ui/hud/CoreEvolutionDebugHud.tscn")

const CORE_1_PATH := "res://data/core/core_level_1.tres"
const CORE_2_PATH := "res://data/core/core_level_2.tres"
const CRYSTAL_PATH := "res://data/progression/abyssal_crystal.tres"
const ENEMY_DEFINITION_PATH := "res://data/units/enemies/cave_beast.tres"

const CRYSTAL_DEFINITION_SOURCE := "res://core/definitions/abyssal_crystal_definition.gd"
const CRYSTAL_STATE_SOURCE := "res://core/state/abyssal_crystal_state.gd"
const CORE_DEFINITION_SOURCE := "res://core/definitions/core_definition.gd"
const CONTROLLER_SOURCE := "res://systems/progression/core_evolution_controller.gd"
const INVASION_SOURCE := "res://systems/combat/invasion_controller.gd"
const GAME_MAIN_SOURCE := "res://game/game_main.gd"
const EVOLUTION_HUD_SOURCE := "res://ui/hud/core_evolution_debug_hud.gd"
const EVOLUTION_HUD_SCENE_PATH := "res://ui/hud/CoreEvolutionDebugHud.tscn"
const RESOURCE_HUD_SOURCE := "res://ui/hud/resource_debug_hud.gd"

const DATA_PROGRESSION_DIR := "res://data/progression"
const DATA_RESOURCES_DIR := "res://data/resources"
const SYSTEMS_DIR := "res://systems"

const ORE := &"iron_ore"
const CRYSTAL_ID := &"abyssal_crystal"
const CRYSTAL_NAME := "Cristal Abissal"
const CRYSTAL_LV2_COST := 1
const CRYSTAL_LV1_COST := 0
const REWARD := 1
const COST := 25.0
const SOLDIER_COST := 15.0
const WORKER_COST := 10.0
const BEAST_HP := 48.0
const INTEGRITY_LV1 := 100.0
const MAX_ESSENCE_LV1 := 50.0
const INVASION_ACTIVE := InvasionController.InvasionState.ACTIVE
const INVASION_VICTORY := InvasionController.InvasionState.VICTORY
const INVASION_DEFEAT := InvasionController.InvasionState.DEFEAT
## §16/T13: os rigs encurtam o aviso pelo @export de produção — nunca por tecla de pulo.
## Na campanha do bloco 4 o cronômetro também é encurtado pela mesma razão: o que este
## arquivo testa é a recompensa, e o tempo em si já é provado em test_invasion_preparation.
const SHORT_PREP := 0.6
const TICKS := 60

const NEST_POINT := Vector3(-5, 0, -5)
const BARRACKS_POINT := Vector3(-10, 0, -5)
const SOLDIER_DEFENSE := Vector3(-2.2, 0, 6.2)
const SPAWN_A := Vector3(-4, 0, 10)
const SPAWN_B := Vector3(11, 0, 0)
const CORE_HOME := Vector3(0.0, 1.0, 0.0)
const FIRST_ORE_ROCK_ID := "iron_ore_001"
const SECOND_ORE_ROCK_ID := "iron_ore_002"

## Textos do painel (§44–§48), copiados aqui de propósito: se a produção mudar o número
## lido da Definition, a linha muda junto e esta suíte acusa a diferença de interface.
const CRYSTAL_BEFORE_LINE := "Cristal Abissal: 0 / 1"
const CRYSTAL_AFTER_VICTORY_LINE := "Cristal Abissal: 1 / 1"
const CRYSTAL_STATUS := "Cristal Abissal necessário"
const READY_STATUS := "Pronto para evoluir"
const INSUFFICIENT_STATUS := "Essência insuficiente"
const NV2_LINE := "NÚCLEO NV.2"
const MVP_LINE := "MVP CONCLUÍDO"

var _failures := 0
var _asserts := 0
var _frames := 0
var _measurements := {}

## Contador do sinal do Cristal. §12/§57/§68 pedem "emitir só quando muda", e isso só se
## prova com o número de emissões e com a lista de valores, nunca olhando o montante final.
var _crystal_events: Array[int] = []

## §68/§72/§73 na campanha: a régua do que não pode mudar, tirada antes do último kill, e
## o rastro de sinal do Cristal do mesmo instante em diante.
var _iron_before := 0
var _piles_before := 0
var _crystal_events_before_victory: Array[int] = []

# Rig isolado (blocos 3)
var _rig: Node3D
var _rig_core: CoreRuntime
var _rig_state: CoreState
var _rig_evolution: CoreEvolutionController
var _rig_invasion: InvasionController

# Cena de produção (bloco 4)
var _scene: Node
var _dungeon: Node3D
var _camera: Camera3D
var _selection: SelectionController
var _construction: ConstructionController
var _recruitment: SoldierRecruitmentController
var _invasion: InvasionController
var _evolution: CoreEvolutionController
var _evolution_hud: Node
var _deposit: ResourceDepositRuntime
var _stockpile: ResourceStockpileState
var _core: CoreRuntime
var _core_state: CoreState
var _crystal: AbyssalCrystalState
var _worker: WorkerRuntime
var _worker2: WorkerRuntime
var _soldier: SoldierRuntime


func _initialize() -> void:
	_run_all()


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > 1200000:
		_check(false, "timeout: a suíte de Cristal Abissal não terminou")
		_finish()
	return false


func _run_all() -> void:
	# Bloco 1 — dados e fontes.
	_test_crystal_definition()
	_test_crystal_is_not_an_operating_resource()
	_test_evolution_costs_live_in_the_definitions()
	_test_scope_guards()

	# Bloco 2 — API do State.
	_test_state_starts_empty()
	_test_state_add()
	_test_state_rejects_invalid_amounts()
	_test_state_consume()
	_test_state_consume_insufficient()
	_test_state_has()
	_test_state_holds_more_than_one()

	# Bloco 3 — recompensa e transação, sem GameMain.
	# Os dois blocos acima são leitura de dado e de fonte, e rodam dentro de `_initialize`.
	# Um rig precisa da árvore de verdade: global_position só existe num Node3D dentro
	# dela, e o primeiro frame é o que abre essa janela.
	await process_frame
	await _test_reward_follows_invasion_lifecycle()
	await _test_reward_is_not_duplicated()
	await _test_defeat_grants_nothing()
	await _test_isolated_combat_grants_nothing()
	await _test_evolution_needs_all_three()
	await _test_exact_transaction()
	await _test_transaction_with_remainder()
	await _test_second_press_charges_nothing()
	await _test_hud_missing_crystal_harness()

	# Bloco 4 — a partida real.
	await _boot_scene()
	await _test_game_starts_without_crystal()
	await _test_hud_before_victory()
	await _test_campaign_to_victory()
	await _test_reward_and_hud_after_victory()
	await _test_no_crystal_touches_the_operating_economy()
	await _test_canonical_mvp_closes_with_real_input()
	await _test_hud_after_evolution()
	_free_scene()

	_print_measurements()
	_finish()


# ======================================================== Bloco 1 — Definition e escopo


## §54: a chave existe como dado, com id e nome, e é carregada do caminho de progressão.
func _test_crystal_definition() -> void:
	_check(ResourceLoader.exists(CRYSTAL_PATH), "§54 data/progression/abyssal_crystal.tres existe")
	var definition := load(CRYSTAL_PATH) as AbyssalCrystalDefinition
	_check(definition != null, "§54 o recurso carrega como AbyssalCrystalDefinition")
	if definition == null:
		return
	_check(definition.crystal_id == CRYSTAL_ID,
			"§54 crystal_id == abyssal_crystal, obtido %s" % definition.crystal_id)
	_check(definition.display_name == CRYSTAL_NAME,
			"§54 display_name == \"%s\", obtido %s" % [CRYSTAL_NAME, definition.display_name])
	var script := definition.get_script() as Script
	_check(script != null and script.resource_path == CRYSTAL_DEFINITION_SOURCE,
			"§4 a Definition vem de core/definitions/abyssal_crystal_definition.gd, obtido %s"
					% (script.resource_path if script != null else "<sem script>"))
	# §96: um tipo de cristal. O diretório de progressão tem a chave e mais nada.
	_check(_files_in(DATA_PROGRESSION_DIR, ".tres") == ["abyssal_crystal.tres"],
			"§96 data/progression tem exatamente o Cristal Abissal, obtido %s"
					% [_files_in(DATA_PROGRESSION_DIR, ".tres")])


## §55/§6/§3: o Cristal não é material da economia operacional — nem por tipo, nem por
## arquivo, nem por engano de quem olha o estoque.
func _test_crystal_is_not_an_operating_resource() -> void:
	var definition := load(CRYSTAL_PATH)
	_check(definition != null and not (definition is ResourceDefinition),
			"§55 AbyssalCrystalDefinition não herda ResourceDefinition")
	_check(load(CRYSTAL_PATH) is Resource, "§4 ainda é um Resource, só que de progressão")
	# §5/§99: o estoque operacional continua com um item só. Cristal ali seria contaminação.
	_check(_files_in(DATA_RESOURCES_DIR, ".tres") == ["iron_ore.tres"],
			"§99 data/resources continua só com iron_ore.tres, obtido %s"
					% [_files_in(DATA_RESOURCES_DIR, ".tres")])
	# §52: o painel de recursos não aprendeu a falar de Cristal.
	var resource_hud := _code_of(RESOURCE_HUD_SOURCE)
	for forbidden in ["Cristal", "crystal", "Crystal"]:
		_check(not resource_hud.contains(forbidden),
				"§52 ResourceDebugHud não menciona %s" % forbidden)
	# §3/§7: o State do Cristal não conhece pilha, carga, depósito nem estoque.
	var state_code := _code_of(CRYSTAL_STATE_SOURCE)
	for forbidden in ["ResourceStockpileState", "ResourcePileState", "ResourcePileRuntime",
			"ResourceDepositRuntime", "carried_amount", "resource_changed", "Dictionary"]:
		_check(not state_code.contains(forbidden),
				"§3/§7 AbyssalCrystalState não contém %s" % forbidden)


## §24–§26/§62–§63: os dois preços vivem na Definition de destino, nas duas moedas.
func _test_evolution_costs_live_in_the_definitions() -> void:
	var lv2 := load(CORE_2_PATH) as CoreDefinition
	var lv1 := load(CORE_1_PATH) as CoreDefinition
	_check(lv2 != null and lv1 != null, "§62 as duas Definitions de Núcleo carregam")
	if lv2 == null or lv1 == null:
		return
	_check(_close(lv2.evolution_essence_cost, COST),
			"§62 Nv.2 evolution_essence_cost == 25, obtido %f" % lv2.evolution_essence_cost)
	_check(lv2.evolution_crystal_cost == CRYSTAL_LV2_COST,
			"§62/§26 Nv.2 evolution_crystal_cost == 1, obtido %d" % lv2.evolution_crystal_cost)
	_check(lv1.evolution_essence_cost == 0.0,
			"§63 Nv.1 evolution_essence_cost == 0, obtido %f" % lv1.evolution_essence_cost)
	_check(lv1.evolution_crystal_cost == CRYSTAL_LV1_COST,
			"§63/§25 Nv.1 evolution_crystal_cost == 0, obtido %d" % lv1.evolution_crystal_cost)
	_check(_source(CORE_2_PATH).contains("evolution_crystal_cost = 1"),
			"§26 o preço do Cristal está escrito no .tres de destino")
	_check(_source(CORE_DEFINITION_SOURCE).contains("@export var evolution_crystal_cost: int"),
			"§24 evolution_crystal_cost é @export int na CoreDefinition")


## §13/§96–§100: o que não foi feito. A varredura é de código sem comentário, porque é o
## comentário que registra a decisão de não criar tais sistemas — "não existe
## RewardManager" escrito num arquivo proibido não pode denunciar o próprio arquivo. O
## nome é varrido à parte: um gerente genérico sempre começa por se anunciar no caminho.
func _test_scope_guards() -> void:
	var sources := _collect_gd_files("res://")
	_check(not sources.is_empty(), "§102 a varredura achou os fontes de produção")
	for forbidden in ["CrystalManager", "ProgressionResourceManager", "RewardManager",
			"InvementManager", "InventoryManager", "ProgressionManager", "RewardDefinition",
			"CostDefinition", "CostEntry", "ResourceCostArray", "TransactionManager",
			"LootTable", "SaveSystem", "LoadSystem", "Mina", "Biomassa", "Worker003",
			"CoreLevel3", "SecondInvasion", "CrystalPile", "CrystalMining", "CrystalShop",
			"EventBus"]:
		var offenders := _files_containing(sources, forbidden)
		_check(offenders.is_empty(),
				"§13/§96/§98 nenhum código contém %s, achado em %s" % [forbidden, offenders])
		var named := _files_named(sources, forbidden)
		_check(named.is_empty(),
				"§96/§97 nenhum fonte de produção tem %s no nome, achado em %s"
						% [forbidden, named])

	# §13: o Cristal não trouxe um controller junto. systems/ continua com seis.
	# §98/T18: a pasta passou a ter sete controllers e um contrato de schema porque a
	# persistência da campanha é um sistema real da campanha (SaveGameController, §10/§11)
	# e CampaignSnapshot é o contrato do arquivo (§6), não um Manager genérico.
	_check(_collect_gd_files(SYSTEMS_DIR).size() == 8,
			"§13/T18 systems/ tem sete controllers e o contrato de schema, obtido %d"
					% _collect_gd_files(SYSTEMS_DIR).size())
	# §101: State RefCounted, sem polling.
	var state_code := _code_of(CRYSTAL_STATE_SOURCE)
	_check(state_code.contains("extends RefCounted"), "§101 AbyssalCrystalState é RefCounted")
	for forbidden in ["func _process(", "func _physics_process(", "extends Node"]:
		_check(not state_code.contains(forbidden),
				"§101 o State do Cristal não contém %s" % forbidden)
	# §27: o controller lê o preço da Definition em vez de escrever 1 no caminho.
	var controller_code := _code_of(CONTROLLER_SOURCE)
	_check(controller_code.contains("evolution_crystal_cost"),
			"§27 o controller lê evolution_crystal_cost da Definition de destino")
	_check(not controller_code.contains("crystal >= 1"),
			"§27 o controller não espalha a comparação com 1")
	_check(not controller_code.contains("func _process("),
			"§29 o controller de evolução continua sem loop por frame")
	# §19: a recompensa é uma constante local do dono do ciclo, não um sistema.
	var invasion_code := _code_of(INVASION_SOURCE)
	_check(invasion_code.contains("FIRST_VICTORY_CRYSTAL_REWARD"),
			"§19 a recompensa é a constante local do InvasionController")
	# §18/§30: as assinaturas antigas continuam de pé — nada foi quebrar harness.
	_check(_code_of(INVASION_SOURCE).contains("func setup("),
			"§18 InvasionController.setup manteve a assinatura")
	_check(_code_of(CONTROLLER_SOURCE).contains("func setup(core: CoreRuntime,"),
			"§30 CoreEvolutionController.setup manteve a assinatura")
	# §15: uma instância só, criada na raiz de composição e passada adiante.
	var main := _code_of(GAME_MAIN_SOURCE)
	_check(main.contains("_abyssal_crystal_state = AbyssalCrystalState.new("),
			"§14/§15 o State do Cristal nasce em GameMain")
	_check(main.count("AbyssalCrystalState.new(") == 1,
			"§15 existe uma única criação de State de Cristal, obtido %d"
					% main.count("AbyssalCrystalState.new("))
	for consumer in ["_invasion.bind_abyssal_crystal_state(_abyssal_crystal_state)",
			"_evolution.bind_abyssal_crystal_state(_abyssal_crystal_state)",
			"_evolution_hud.bind(_evolution, core_state, _abyssal_crystal_state)"]:
		_check(main.contains(consumer), "§15 o mesmo State chega a %s" % consumer)
	# §43/§50: o Cristal entrou no painel que já existia, e não virou painel novo.
	_check(not ResourceLoader.exists("res://ui/hud/AbyssalCrystalDebugHud.tscn"),
			"§50 não existe painel novo de Cristal")
	_check(_source(EVOLUTION_HUD_SCENE_PATH).contains("CrystalLabel"),
			"§43 o painel de evolução ganhou a linha do Cristal")
	_check(not _code_of(EVOLUTION_HUD_SOURCE).contains("func _process("),
			"§49 o painel continua sem loop por frame")


# ============================================================ Bloco 2 — API do State


## §56: o domínio começa sem conquista nenhuma.
func _test_state_starts_empty() -> void:
	var state := _new_crystal()
	_reset_capture()
	state.amount_changed.connect(_on_crystal_changed)
	_check(state.amount == 0, "§56 amount inicial é 0, obtido %d" % state.amount)
	_check(state.definition == load(CRYSTAL_PATH), "§7 o State carrega a Definition")
	_check(_crystal_events.is_empty(), "§12 criar o State não emite sinal, %s" % [_crystal_events])


## §57/§9: adicionar um valor válido soma e emite exatamente uma vez.
func _test_state_add() -> void:
	var state := _new_crystal()
	_reset_capture()
	state.amount_changed.connect(_on_crystal_changed)
	_check(state.add(1), "§57 add(1) devolveu true")
	_check(state.amount == 1, "§57 amount virou 1, obtido %d" % state.amount)
	_check(_crystal_events == [1], "§57/§12 amount_changed levou 1 uma vez, %s" % [_crystal_events])


## §58/§9: nada que não é ganho entra, e rejeição não emite sinal nenhum.
func _test_state_rejects_invalid_amounts() -> void:
	var state := _new_crystal()
	_reset_capture()
	state.amount_changed.connect(_on_crystal_changed)
	_check(not state.add(0), "§58 add(0) devolve false")
	_check(not state.add(-1), "§58 add(-1) devolve false")
	_check(not state.add(-50), "§9 adicionar quantidade negativa devolve false")
	_check(state.amount == 0, "§58 nenhuma adição inválida alterou o montante, %d" % state.amount)
	_check(_crystal_events.is_empty(),
			"§58/§12 rejeição não emite amount_changed, %s" % [_crystal_events])


## §59: consumir com saldo é uma subtração e um sinal.
func _test_state_consume() -> void:
	var state := _new_crystal()
	state.add(2)
	_reset_capture()
	state.amount_changed.connect(_on_crystal_changed)
	_check(state.consume(1), "§59 consume(1) com saldo devolve true")
	_check(state.amount == 1, "§59 2 → 1, obtido %d" % state.amount)
	_check(_crystal_events == [1], "§59/§12 o sinal levou o valor novo, %s" % [_crystal_events])


## §60/§10: sem saldo não existe meio consumo.
func _test_state_consume_insufficient() -> void:
	var state := _new_crystal()
	_reset_capture()
	state.amount_changed.connect(_on_crystal_changed)
	_check(not state.consume(1), "§60 consume(1) com 0 devolve false")
	_check(state.amount == 0, "§60 o montante continuou 0, obtido %d" % state.amount)
	_check(_crystal_events.is_empty(),
			"§60/§10 consumo recusado não emite sinal, %s" % [_crystal_events])
	state.add(1)
	_reset_capture()
	_check(not state.consume(2), "§10 consumir mais do que há devolve false")
	_check(state.amount == 1, "§10 a recusa não tocou no saldo, %d" % state.amount)
	_check(not state.consume(0), "§9 consume(0) devolve false")
	_check(not state.consume(-3), "§9 consume negativo devolve false")
	_check(_crystal_events.is_empty(),
			"§10 nenhuma recusa emitiu sinal, %s" % [_crystal_events])


## §61: a pergunta de saldo é uma comparação, não um booleano.
func _test_state_has() -> void:
	var state := _new_crystal()
	state.add(2)
	_check(state.has(1), "§61 has(1) com saldo 2 é true")
	_check(state.has(2), "§61 has(2) com saldo 2 é true")
	_check(not state.has(3), "§61 has(3) com saldo 2 é false")
	_check(state.has(), "§8 has() sem argumento pergunta a chave única")


## §11: o contador comporta marcos futuros sem virar outro tipo.
func _test_state_holds_more_than_one() -> void:
	var state := _new_crystal()
	_reset_capture()
	state.amount_changed.connect(_on_crystal_changed)
	state.add(1)
	state.add(1)
	state.add(1)
	_check(state.amount == 3, "§11 três cristais somam 3, obtido %d" % state.amount)
	_check(_crystal_events == [1, 2, 3],
			"§11/§12 um sinal por mudança útil, %s" % [_crystal_events])
	_check(not _code_of(CRYSTAL_STATE_SOURCE).contains("has_crystal"),
			"§11 não existe booleano has_crystal no State")


# ================================================= Bloco 3 — recompensa e transação


## §65–§67: o Ciclo da marca. Nada antes do último invasor cair, e o Cristal aparece no
## exato instante em que o estado vira VICTORY.
func _test_reward_follows_invasion_lifecycle() -> void:
	var rig := await _make_invasion_rig()
	var invasion := rig["invasion"] as InvasionController
	var crystal := rig["crystal"] as AbyssalCrystalState
	_reset_capture()
	crystal.amount_changed.connect(_on_crystal_changed)

	_check(crystal.amount == 0, "§65 NOT_STARTED começa sem cristal, %d" % crystal.amount)
	_press_key(KEY_F)
	_check(await _wait_until(
			func() -> bool: return invasion.invasion_state() == INVASION_ACTIVE, 20.0),
			"§65 o rig chegou a ACTIVE")
	_check(crystal.amount == 0, "§65 ACTIVE não dá nada, %d" % crystal.amount)
	_check(_crystal_events.is_empty(), "§65/§12 durante ACTIVE nenhum sinal saiu, %s"
			% [_crystal_events])

	var invaders := invasion.invaders()
	_check(invaders.size() == 2, "§90/T12 a invasão continua com duas Feras, %d"
			% invaders.size())
	# §66: o primeiro kill é metade de uma vitória, e metade não paga nada.
	invaders[0].receive_damage(BEAST_HP * 2.0)
	_check(await _wait_until(
			func() -> bool: return invasion.active_invaders() == 1, 20.0),
			"§66 o primeiro invasor caiu (2 → 1)")
	_check(crystal.amount == 0,
			"§66/§22 matar um invasor não concede o Cristal, %d" % crystal.amount)
	_check(invasion.invasion_state() == INVASION_ACTIVE,
			"§66 com um vivo o ciclo ainda é ACTIVE, %s" % invasion.invasion_state())

	# §67: o último cai e a transição para VICTORY é o que concede.
	invaders[1].receive_damage(BEAST_HP * 2.0)
	_check(await _wait_until(
			func() -> bool: return invasion.invasion_state() == INVASION_VICTORY, 20.0),
			"§67 ACTIVE → VICTORY aconteceu")
	_check(crystal.amount == REWARD,
			"§67/§16 a vitória levou o Cristal de 0 a %d, obtido %d" % [REWARD, crystal.amount])
	# §68: o sinal saiu uma vez, com o valor final, e nada mais.
	_check(_crystal_events == [REWARD],
			"§68 amount_changed registrou exatamente [%d], obtido %s" % [REWARD, _crystal_events])
	_measurements["crystal_after_victory"] = crystal.amount
	_free_rig()


## §20/§69: uma marca, uma vez. Depois da vitória o ciclo está fechado, e qualquer
## callback redundante, frame extra ou nova tentativa de largada tem de não somar nada.
func _test_reward_is_not_duplicated() -> void:
	var rig := await _make_invasion_rig()
	var invasion := rig["invasion"] as InvasionController
	var crystal := rig["crystal"] as AbyssalCrystalState
	_press_key(KEY_F)
	_check(await _wait_until(
			func() -> bool: return invasion.invasion_state() == INVASION_ACTIVE, 20.0),
			"§69 o rig de idempotência largou a invasão")
	for invader in invasion.invaders():
		invader.receive_damage(BEAST_HP * 2.0)
	_check(await _wait_until(
			func() -> bool: return invasion.invasion_state() == INVASION_VICTORY, 20.0),
			"§69 o rig venceu")
	_reset_capture()
	crystal.amount_changed.connect(_on_crystal_changed)

	# O caminho que a spec nomeia: _on_invader_died chamado de novo depois de VICTORY.
	invasion._on_invader_died(null)
	invasion._on_invader_died(null)
	# E os que o jogador pode realmente fazer: frames a mais, tecla F, largada direta.
	await _advance(1.0)
	_press_key(KEY_F)
	var restarted := invasion.start_invasion()
	await _advance(0.5)
	_check(not restarted, "§20 depois de VICTORY não existe segunda largada")
	_check(crystal.amount == REWARD,
			"§20/§69 callback redundante não duplicou a recompensa, %d" % crystal.amount)
	_check(_crystal_events.is_empty(),
			"§20/§12 nenhuma emissão saiu do pós-vitória, %s" % [_crystal_events])
	_free_rig()


## §21/§70: DEFEAT não deixa marca. O Núcleo cai e o registro continua vazio.
func _test_defeat_grants_nothing() -> void:
	var rig := await _make_invasion_rig()
	var invasion := rig["invasion"] as InvasionController
	var crystal := rig["crystal"] as AbyssalCrystalState
	var state := rig["state"] as CoreState
	_press_key(KEY_F)
	_check(await _wait_until(
			func() -> bool: return invasion.invasion_state() == INVASION_ACTIVE, 20.0),
			"§70 o rig de derrota chegou a ACTIVE")
	state.damage(INTEGRITY_LV1 * 10.0)
	_check(await _wait_until(
			func() -> bool: return invasion.invasion_state() == INVASION_DEFEAT, 20.0),
			"§70 ACTIVE → DEFEAT")
	_check(crystal.amount == 0, "§21/§70 derrota não concede Cristal, %d" % crystal.amount)
	# A derrota também não abre a porta da evolução por nenhum outro caminho.
	_check(not (rig["evolution"] as CoreEvolutionController).is_unlocked(),
			"§70/§42 sem vitória a evolução continua travada")
	_free_rig()


## §22/§71: a recompensa pertence à vitória da invasão, não à morte de qualquer Fera.
func _test_isolated_combat_grants_nothing() -> void:
	var rig := await _make_invasion_rig()
	var invasion := rig["invasion"] as InvasionController
	var crystal := rig["crystal"] as AbyssalCrystalState
	var dungeon := rig["dungeon"] as Node3D
	# Uma Fera criada à margem do ciclo: ninguém a largou, ninguém a registrou. A montagem
	# é a mesma das sondas de test_invasion — setup antes de entrar na árvore.
	var definition := load(ENEMY_DEFINITION_PATH) as EnemyDefinition
	var stray := ENEMY_SCENE.instantiate() as EnemyRuntime
	stray.name = "StrayBeast"
	stray.setup(definition, EnemyState.new(definition, "stray_001"))
	dungeon.add_child(stray)
	stray.global_position = SPAWN_A
	await process_frame
	_check(invasion.invasion_state() != INVASION_ACTIVE,
			"§71 o ciclo continua fechado enquanto a Fera isolada vive, %s"
					% invasion.invasion_state())
	stray.receive_damage(BEAST_HP * 2.0)
	await _advance(0.3)
	_check(not is_instance_valid(stray), "§71 a Fera isolada morreu de verdade")
	_check(crystal.amount == 0,
			"§22/§71 combate fora da invasão não concede Cristal, %d" % crystal.amount)
	_check(invasion.invaders().size() == 0,
			"§71 a Fera avulsa nunca entrou na onda da invasão, %d" % invasion.invaders().size())
	_free_rig()


## §31–§34/§74–§76: cada metade sozinha não fecha a conta. Os quatro pontos abaixo são a
## matriz inteira: falta uma coisa, não evolui; faltam duas, idem; com tudo, evolui.
func _test_evolution_needs_all_three() -> void:
	# §74: chave na mão, tanque cheio, vitória nenhuma.
	var rig := await _make_detached_rig()
	var evolution := rig["evolution"] as CoreEvolutionController
	var state := rig["state"] as CoreState
	var crystal := rig["crystal"] as AbyssalCrystalState
	_set_essence_to(state, MAX_ESSENCE_LV1)
	crystal.add(REWARD)
	_check(not evolution.can_evolve(), "§74/§32 sem vitória can_evolve é false")
	_press_key(KEY_V)
	await _advance(0.2)
	_check(state.level == 1, "§74/§42 sem vitória V não evolui")
	_check(crystal.amount == REWARD, "§74 sem vitória o Cristal não foi cobrado, %d"
			% crystal.amount)
	_check(_close(state.essence, MAX_ESSENCE_LV1),
			"§74 sem vitória a Essência não foi cobrada, %f" % state.essence)
	_free_rig()

	# §75: venceu e tem Essência de sobra, mas nunca venceu a primeira invasão de verdade
	# — o registro do domínio está vazio.
	rig = await _make_detached_rig()
	evolution = rig["evolution"] as CoreEvolutionController
	state = rig["state"] as CoreState
	crystal = rig["crystal"] as AbyssalCrystalState
	evolution.unlock_after_victory()
	_set_essence_to(state, MAX_ESSENCE_LV1)
	_check(not evolution.can_evolve(), "§75/§33 sem Cristal can_evolve é false")
	_press_key(KEY_V)
	await _advance(0.2)
	_check(state.level == 1, "§33/§75 Victory + Essência sem chave não evolui")
	_check(_close(state.essence, MAX_ESSENCE_LV1),
			"§33/§75 e a Essência de sobra permanece %f" % state.essence)
	_check(crystal.amount == 0, "§75 nada apareceu no registro, %d" % crystal.amount)
	_free_rig()

	# §76: a chave existe e a vitória aconteceu, mas falta 1 de Essência.
	rig = await _make_detached_rig()
	evolution = rig["evolution"] as CoreEvolutionController
	state = rig["state"] as CoreState
	crystal = rig["crystal"] as AbyssalCrystalState
	evolution.unlock_after_victory()
	crystal.add(REWARD)
	_set_essence_to(state, 24.0)
	_check(not evolution.can_evolve(), "§76/§34 com 24 de Essência can_evolve é false")
	_press_key(KEY_V)
	await _advance(0.2)
	_check(state.level == 1, "§34/§76 Essência insuficiente não evolui")
	_check(crystal.amount == REWARD,
			"§34/§76 a tentativa recusada não gastou o Cristal, %d" % crystal.amount)
	_check(_close(state.essence, 24.0), "§34 a Essência continua 24, %f" % state.essence)
	_free_rig()


## §35/§77: o preço exato, cobrado das duas moedas de uma vez.
func _test_exact_transaction() -> void:
	var rig := await _make_detached_rig()
	var evolution := rig["evolution"] as CoreEvolutionController
	var state := rig["state"] as CoreState
	var core := rig["core"] as CoreRuntime
	var crystal := rig["crystal"] as AbyssalCrystalState
	evolution.unlock_after_victory()
	crystal.add(REWARD)
	_set_essence_to(state, COST)
	_check(evolution.can_evolve(), "§35/§77 vitória + chave + 25 fecha a conta")
	_check(_close(evolution.evolution_cost(), COST),
			"§77 o preço de Essência lido é 25, %f" % evolution.evolution_cost())
	_check(evolution.evolution_crystal_cost() == CRYSTAL_LV2_COST,
			"§27/§77 o preço de Cristal lido da Definition é 1, %d"
					% evolution.evolution_crystal_cost())
	var essence_before := state.essence
	var crystal_before := crystal.amount
	_press_key(KEY_V)
	await _advance(0.3)
	_check(state.level == 2, "§35/§77 o Núcleo virou Lv.2")
	_check(core.definition() == load(CORE_2_PATH), "§77 o Runtime trocou a Definition")
	_check(_close(state.essence, essence_before - COST, 0.01),
			"§77 a Essência caiu exatamente o preço (%f → %f)" % [essence_before, state.essence])
	_check(crystal.amount == crystal_before - REWARD,
			"§35/§77 o Cristal caiu exatamente 1 (%d → %d)" % [crystal_before, crystal.amount])
	_measurements["exact_transaction"] = {
		"essence_before": essence_before, "essence_after": state.essence,
		"crystal_before": crystal_before, "crystal_after": crystal.amount,
	}
	_free_rig()


## §36/§78: pagar o preço com sobra devolve a sobra — dos dois lados da conta.
func _test_transaction_with_remainder() -> void:
	var rig := await _make_detached_rig()
	var evolution := rig["evolution"] as CoreEvolutionController
	var state := rig["state"] as CoreState
	var crystal := rig["crystal"] as AbyssalCrystalState
	evolution.unlock_after_victory()
	crystal.add(2)
	# O tanque do Lv.1 comporta 50, então "40" é ajuste de harness pelo caminho público
	# do State — nunca uma doação acima do teto, que viraria clamp silencioso.
	_set_essence_to(state, 40.0)
	_check(crystal.amount == 2, "§78 o rig abriu com 2 cristais, %d" % crystal.amount)
	_check(_close(state.essence, 40.0, 0.01),
			"§78 e 40 de Essência no tanque do Lv.1, %f" % state.essence)
	_press_key(KEY_V)
	await _advance(0.3)
	_check(state.level == 2, "§78 a evolução aconteceu")
	_check(crystal.amount == 1, "§36/§78 sobrou 1 Cristal, obtido %d" % crystal.amount)
	_check(_close(state.essence, 15.0, 0.01),
			"§36/§78 sobrou 15 de Essência, obtido %f" % state.essence)
	_free_rig()


## §41/§79: o segundo V não cobra nada de novo, nem de uma moeda nem da outra.
func _test_second_press_charges_nothing() -> void:
	var rig := await _make_detached_rig()
	var evolution := rig["evolution"] as CoreEvolutionController
	var state := rig["state"] as CoreState
	var crystal := rig["crystal"] as AbyssalCrystalState
	evolution.unlock_after_victory()
	crystal.add(2)
	_set_essence_to(state, 40.0)
	_press_key(KEY_V)
	await _advance(0.3)
	_check(state.level == 2, "§79 a primeira tecla evoluiu")
	_check(crystal.amount == 1 and _close(state.essence, 15.0, 0.01),
			"§79 o rig começou a segunda fase com 1 cristal e 15 de Essência, %d / %f"
					% [crystal.amount, state.essence])
	var crystal_after := crystal.amount
	var essence_after := state.essence
	_press_key(KEY_V)
	await _advance(0.3)
	_check(crystal.amount == crystal_after,
			"§79/§41 o segundo V não cobrou Cristal (%d → %d)" % [crystal_after, crystal.amount])
	_check(_close(state.essence, essence_after, 0.01),
			"§79/§41 o segundo V não cobrou Essência (%f → %f)"
					% [essence_after, state.essence])
	_check(state.level == 2, "§79 continua Lv.2, %d" % state.level)
	_free_rig()


# ===================================================== Bloco 4 — a partida real


func _test_game_starts_without_crystal() -> void:
	_check(_crystal != null, "§64 a cena real abre com um registro de Cristal")
	_check(_crystal.amount == 0, "§64 a partida começa sem chave, %d" % _crystal.amount)
	_check(_crystal.definition == load(CRYSTAL_PATH),
			"§15 o State da cena carrega a Definition do recurso")
	# §15: a alça abaixo vem do controller de evolução, e a prova de que é um State único
	# é comportamental: quem escreve é o InvasionController (§67) e quem mostra é o painel
	# (§84), ambos enxergando este mesmo objeto. Com um State por consumidor, o painel
	# continuaria em "0 / 1" depois da vitória e o bloco 4 inteiro desabaria.
	_check(_evolution.abyssal_crystal_state() == _crystal,
			"§15 a alça da campanha é o State que o controller de evolução segura")


func _test_hud_before_victory() -> void:
	# §44: a linha existe antes de qualquer vitória, mostrando o que falta.
	_check(_text_of(_evolution_hud, "CrystalLabel") == CRYSTAL_BEFORE_LINE,
			"§44/§83 antes da vitória o painel mostra \"%s\", obtido %s"
					% [CRYSTAL_BEFORE_LINE, _text_of(_evolution_hud, "CrystalLabel")])
	_check(_text_of(_evolution_hud, "OfferLabel") == "Evolução: bloqueada",
			"§83 a oferta continua bloqueada no começo, obtido %s"
					% _text_of(_evolution_hud, "OfferLabel"))
	_check(_text_of(_evolution_hud, "StatusLabel") == "Sobreviva à primeira invasão.",
			"§83 o status aponta a invasão, obtido %s"
					% _text_of(_evolution_hud, "StatusLabel"))


## §81: o loop canônico inteiro, tecla por tecla, com a Essência que a partida produz.
func _test_campaign_to_victory() -> void:
	_check(_crystal.amount == 0, "§81 o ciclo começa sem chave, %d" % _crystal.amount)
	_check(_core_state.essence >= WORKER_COST,
			"§81 a campanha abre com Essência para o segundo Worker, %f" % _core_state.essence)
	_press_key(KEY_I)
	await _advance(0.4)
	var workers := _workers_in_scene()
	_worker2 = workers[1] if workers.size() == 2 else null
	_check(_worker2 != null, "§81 Worker002 chegou pela tecla I")

	await _mine_with_two_workers(_rock_with_id(FIRST_ORE_ROCK_ID))
	_check(_stockpile.get_amount(ORE) == 3,
			"§81 a primeira rocha pagou o Ninho, %d no depósito" % _stockpile.get_amount(ORE))
	_press_key(KEY_B)
	await _advance(0.2)
	var nest := _construction.nest()
	_check(nest != null, "§81 B abriu o canteiro do Ninho")
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
			"§81 o Ninho ficou pronto")

	await _mine_with_two_workers(_rock_with_id(SECOND_ORE_ROCK_ID))
	_place(_worker, Vector3(BARRACKS_POINT.x + 1.5, 0.0, BARRACKS_POINT.z + 0.9))
	_place(_worker2, Vector3(BARRACKS_POINT.x + 1.5, 0.0, BARRACKS_POINT.z - 0.9))
	await _advance(0.1)
	_press_key(KEY_K)
	await _advance(0.2)
	var barracks := _construction.barracks()
	_check(barracks != null, "§81 K criou o Quartel")
	if barracks == null:
		return
	_selection.clear_selection()
	await _click_select(_worker)
	await _shift_click_select(_worker2)
	await _right_click(barracks.global_position)
	_check(await _wait_until(func() -> bool: return barracks.is_completed(), 40.0),
			"§81 o Quartel ficou pronto")

	# §82: nada de Essência de graça — se faltar, o teste espera a geração natural.
	var paid := await _wait_until_real(
			func() -> bool: return _core_state.essence >= SOLDIER_COST, 90.0)
	_check(paid, "§82 a geração natural pagou o Soldado, %f" % _core_state.essence)
	_press_key(KEY_R)
	await _advance(0.4)
	_soldier = _recruitment.soldier()
	_check(_soldier != null, "§81 R recrutou o Soldado")
	if _soldier == null:
		return
	_selection.clear_selection()
	await _click_select(_soldier)
	await _right_click(SOLDIER_DEFENSE)
	await _wait_until(func() -> bool: return not _soldier.has_move_target(), 20.0)

	_check(_crystal.amount == 0, "§65 PREPARATION não dá nada, %d" % _crystal.amount)
	_check(await _wait_until(
			func() -> bool: return _invasion.invasion_state() == INVASION_ACTIVE, 90.0),
			"§81 o cronômetro de aviso largou a invasão")
	# §72/§73 antes da vitória: a régua do que não pode mudar.
	_iron_before = _stockpile.get_amount(ORE)
	_piles_before = _piles_in_scene().size()
	_crystal_events_before_victory.clear()
	_crystal.amount_changed.connect(_on_campaign_crystal_changed)

	var invaders := _invasion.invaders()
	_check(invaders.size() == 2, "§90/T12 as duas Feras da Tarefa 12 na cena real")
	_selection.clear_selection()
	await _click_select(_soldier)
	await _right_click(_body_screen_position(invaders[0].global_position))
	var first_id := invaders[0].get_instance_id()
	_check(await _wait_until(func() -> bool: return not is_instance_id_valid(first_id), 60.0),
			"§81 o Soldado derrubou o Invader001")
	_check(_crystal.amount == 0,
			"§66/§103 o primeiro kill não deu nada na campanha, %d" % _crystal.amount)
	await _right_click(_body_screen_position(invaders[1].global_position))
	var second_id := invaders[1].get_instance_id()
	_check(await _wait_until(func() -> bool: return not is_instance_id_valid(second_id), 60.0),
			"§81 o Soldado derrubou o Invader002")
	_check(_invasion.invasion_state() == INVASION_VICTORY,
			"§81 a campanha real terminou em VICTORY")
	_check(_core_state.integrity > 0.0,
			"§81 o Núcleo sobreviveu para evoluir, %f" % _core_state.integrity)


## §45/§67/§84: a marca aparece imediatamente, e o painel lê o mesmo State.
func _test_reward_and_hud_after_victory() -> void:
	_check(_crystal.amount == REWARD,
			"§67/§81 imediatamente após a vitória o Cristal é 1, obtido %d" % _crystal.amount)
	_check(_text_of(_evolution_hud, "CrystalLabel") == CRYSTAL_AFTER_VICTORY_LINE,
			"§45/§84 o painel mostra \"%s\", obtido %s"
					% [CRYSTAL_AFTER_VICTORY_LINE, _text_of(_evolution_hud, "CrystalLabel")])
	# §68 na cena real: uma emissão útil, com o valor final.
	_check(_crystal_events_before_victory == [REWARD],
			"§68 na campanha amount_changed registrou exatamente [%d], obtido %s"
					% [REWARD, _crystal_events_before_victory])
	_check(_evolution.is_unlocked(), "§81 a vitória chegou ao controller por signal")
	var status := _text_of(_evolution_hud, "StatusLabel")
	var ready := _core_state.essence >= COST and _crystal.amount >= CRYSTAL_LV2_COST
	_check(status == (READY_STATUS if ready else INSUFFICIENT_STATUS),
			"§45 o status acompanha a conta real (%f Essência → %s, obtido %s)"
					% [_core_state.essence,
							READY_STATUS if ready else INSUFFICIENT_STATUS, status])
	_measurements["essence_at_victory"] = _core_state.essence
	print("[INFO] §82 Essência medida no instante da vitória: %f (custo %f)."
			% [_core_state.essence, COST])


## §23/§52/§72/§73: a vitória não toca na economia operacional.
func _test_no_crystal_touches_the_operating_economy() -> void:
	_check(_stockpile.get_amount(CRYSTAL_ID) == 0,
			"§73/§52 o estoque não conhece o id abyssal_crystal, %d"
					% _stockpile.get_amount(CRYSTAL_ID))
	_check(_stockpile.get_amount(ORE) == _iron_before,
			"§73 o Iron Ore do depósito não mudou com a vitória (%d → %d)"
					% [_iron_before, _stockpile.get_amount(ORE)])
	_check(_piles_in_scene().size() == _piles_before,
			"§23/§72 nenhuma pilha nova apareceu pela vitória (%d → %d)"
					% [_piles_before, _piles_in_scene().size()])
	var cargo := 0
	for worker in _workers_in_scene():
		cargo += worker.state.carried_amount
	_check(cargo == 0, "§23 nenhum Worker está carregando coisa nenhuma, %d" % cargo)
	# §52: o painel de recursos continua falando só de minério.
	_check(_text_of(_scene.get_node("UI/ResourceDebugPanel"), "OreLabel")
			.contains("Minério de Ferro"),
			"§52 ResourceDebugHud continua sendo o painel do minério, obtido %s"
					% _text_of(_scene.get_node("UI/ResourceDebugPanel"), "OreLabel"))


## §81/§82/§86: o fechamento canônico do MVP, com Essência esperada e tecla real.
func _test_canonical_mvp_closes_with_real_input() -> void:
	var waited := true
	if _core_state.essence < COST:
		waited = await _wait_until_real(
				func() -> bool: return _core_state.essence >= COST, 90.0)
	_check(waited, "§82 a Essência chegou a 25 por geração natural, %f" % _core_state.essence)
	var essence_before := _core_state.essence
	var crystal_before := _crystal.amount
	var integrity_before := _core_state.integrity
	var core_id := _core.get_instance_id()
	var state_id := _core_state.get_instance_id()
	_measurements["essence_before_evolution"] = essence_before
	_measurements["crystal_before_evolution"] = crystal_before

	# §86: com as três condições postas, o painel já anuncia o passo.
	_check(_text_of(_evolution_hud, "StatusLabel") == READY_STATUS,
			"§47/§86 pronto para evoluir, obtido %s"
					% _text_of(_evolution_hud, "StatusLabel"))
	_check(_text_of(_evolution_hud, "OfferLabel")
			== "[V] Evoluir para Nv.2 — 25 Essência",
			"§47 a oferta mantém o preço da Definition, obtido %s"
					% _text_of(_evolution_hud, "OfferLabel"))

	_press_key(KEY_V)
	_check(await _wait_until(func() -> bool: return _core_state.level == 2, 5.0),
			"§81 V atravessou o input real e evoluiu o Núcleo")
	_check(_core.get_instance_id() == core_id, "§80 o CoreRuntime é a mesma instância")
	_check(_core_state.get_instance_id() == state_id, "§80 o CoreState é o mesmo objeto")
	_check(_close(_core_state.essence, essence_before - COST, 0.5),
			"§81 a Essência caiu exatamente 25 (%f → %f)"
					% [essence_before, _core_state.essence])
	_check(crystal_before - _crystal.amount == CRYSTAL_LV2_COST,
			"§81/§37 o Cristal caiu exatamente 1 (%d → %d)"
					% [crystal_before, _crystal.amount])
	_check(_core_state.level == 2, "§81 Núcleo Nv.2")
	_check(_close(_core_state.integrity, 150.0),
			"§80 a Integrity do Nv.2 abriu no teto, %f" % _core_state.integrity)
	_check(integrity_before < _core_state.integrity,
			"§80 a evolução recompensou a sobrevivência (%f → %f)"
					% [integrity_before, _core_state.integrity])

	# §80: tudo que a Tarefa 14 jurou preservar continua no lugar.
	_check(_core_state.core_id == "main_core", "§80 core_id continua main_core")
	_check(_core_state.population == 3,
			"§80 população preservada em 3, obtido %d" % _core_state.population)
	_check(_core_state.population_capacity_bonus == 4,
			"§80 bônus do Ninho preservado, %d" % _core_state.population_capacity_bonus)
	_check(_core_state.get_population_capacity() == 16,
			"§80 capacidade efetiva 12 + 4, %d" % _core_state.get_population_capacity())
	_check(_construction.nest() != null and _construction.nest().is_inside_tree(),
			"§80 o Ninho continua na cena")
	_check(_construction.barracks() != null and _construction.barracks().is_inside_tree(),
			"§80 o Quartel continua na cena")
	_check(_soldier != null and _soldier.is_inside_tree(), "§80 o Soldado continua no mapa")
	_check(_workers_in_scene().size() == 2,
			"§80 os dois Workers continuam vivos, %d" % _workers_in_scene().size())
	_check(_stockpile.get_amount(ORE) >= _iron_before,
			"§80/§73 o estoque de Iron não encolheu, %d" % _stockpile.get_amount(ORE))

	# §41/§79 na campanha: o segundo V não cobra de novo.
	var essence_after_first := _core_state.essence
	var crystal_after_first := _crystal.amount
	# §41/§79 na campanha: o segundo V não cobra de novo. A Essência do Nv.2 continua
	# sendo gerada (1.5/s), então a régua correta é "nenhuma cobrança", não "número
	# congelado" — o mesmo contrato que test_core_evolution §106 mede na campanha.
	_press_key(KEY_V)
	await _advance(0.3)
	_check(_core_state.essence >= essence_after_first - 0.001,
			"§79 na campanha o segundo V não cobriu Essência (%f → %f)"
					% [essence_after_first, _core_state.essence])
	_check(_crystal.amount == crystal_after_first,
			"§41/§79 na campanha o segundo V não cobriu Cristal (%d → %d)"
					% [crystal_after_first, _crystal.amount])
	_check(_core_state.level == 2, "§96 não existe Nv.3, %d" % _core_state.level)
	_measurements["crystal_after_evolution"] = _crystal.amount


## §48/§87: a celebração continua no mesmo painel, agora com a sobra da chave.
func _test_hud_after_evolution() -> void:
	_check(_text_of(_evolution_hud, "LevelLabel") == NV2_LINE,
			"§87 a primeira linha virou \"%s\", obtido %s"
					% [NV2_LINE, _text_of(_evolution_hud, "LevelLabel")])
	_check(_text_of(_evolution_hud, "OfferLabel") == MVP_LINE,
			"§87/§48 o painel anuncia \"%s\", obtido %s"
					% [MVP_LINE, _text_of(_evolution_hud, "OfferLabel")])
	_check(_text_of(_evolution_hud, "CrystalLabel").begins_with(CRYSTAL_NAME),
			"§48 a linha do Cristal continuou no painel, obtido %s"
					% _text_of(_evolution_hud, "CrystalLabel"))
	var stats_label := _evolution_hud.find_child("StatsLabel", true, false) as Label
	_check(stats_label != null and stats_label.visible,
			"§87 as estatísticas do Nv.2 entraram na tela")
	# §49: o painel anda por signal. Uma tecla sem condição não redesenha nada de novo.
	_check(_text_of(_evolution_hud, "StatusLabel") == "",
			"§48 depois da evolução a linha de status esvazia, obtido %s"
					% _text_of(_evolution_hud, "StatusLabel"))


# ============================================================ Harness de rig isolado


## Rig de invasão com o Cristal vinculado, exatamente como GameMain liga (§15/§17): o
## mesmo State nas mãos de quem concede e de quem cobra.
func _make_invasion_rig() -> Dictionary:
	_rig = Node3D.new()
	_rig.name = "CrystalInvasionRig"
	root.add_child(_rig)
	var dungeon := Node3D.new()
	dungeon.name = "DungeonRoot"
	_rig.add_child(dungeon)
	_rig_core = CORE_SCENE.instantiate() as CoreRuntime
	dungeon.add_child(_rig_core)
	_rig_core.global_position = CORE_HOME
	_rig_state = CoreState.new(load(CORE_1_PATH) as CoreDefinition)
	_rig_core.setup(load(CORE_1_PATH) as CoreDefinition, _rig_state)
	var point_a := Marker3D.new()
	point_a.name = "InvasionSpawnPointA"
	dungeon.add_child(point_a)
	var point_b := Marker3D.new()
	point_b.name = "InvasionSpawnPointB"
	dungeon.add_child(point_b)
	await process_frame
	point_a.global_position = SPAWN_A
	point_b.global_position = SPAWN_B
	var crystal := _new_crystal()
	_rig_evolution = CoreEvolutionController.new()
	_rig_evolution.name = "CoreEvolutionController"
	_rig.add_child(_rig_evolution)
	_rig_invasion = InvasionController.new()
	_rig_invasion.name = "InvasionController"
	_rig.add_child(_rig_invasion)
	await process_frame
	_rig_evolution.setup(_rig_core, _rig_state, load(CORE_2_PATH) as CoreDefinition)
	_rig_evolution.bind_abyssal_crystal_state(crystal)
	_rig_invasion.setup(
			load(ENEMY_DEFINITION_PATH) as EnemyDefinition,
			ENEMY_SCENE,
			dungeon,
			_rig_core,
			[point_a, point_b])
	_rig_invasion.preparation_duration = SHORT_PREP
	_rig_invasion.bind_abyssal_crystal_state(crystal)
	_rig_invasion.invasion_victory.connect(_rig_evolution.unlock_after_victory)
	await process_frame
	return {
		"rig": _rig,
		"dungeon": dungeon,
		"core": _rig_core,
		"state": _rig_state,
		"evolution": _rig_evolution,
		"invasion": _rig_invasion,
		"crystal": crystal,
	}


## Rig de evolução sem invasão nenhuma: a conta é testada ao centésimo, então o rig fica
## fora da árvore e a Essência não anda entre o ajuste do harness e a tecla.
func _make_detached_rig() -> Dictionary:
	_rig = Node3D.new()
	_rig.name = "CrystalDetachedRig"
	_rig_core = CORE_SCENE.instantiate() as CoreRuntime
	_rig.add_child(_rig_core)
	_rig_state = CoreState.new(load(CORE_1_PATH) as CoreDefinition)
	_rig_core.setup(load(CORE_1_PATH) as CoreDefinition, _rig_state)
	_rig_evolution = CoreEvolutionController.new()
	_rig_evolution.name = "CrystalDetachedEvolution"
	root.add_child(_rig_evolution)
	await process_frame
	_rig_evolution.setup(_rig_core, _rig_state, load(CORE_2_PATH) as CoreDefinition)
	var crystal := _new_crystal()
	_rig_evolution.bind_abyssal_crystal_state(crystal)
	return {
		"core": _rig_core,
		"state": _rig_state,
		"evolution": _rig_evolution,
		"crystal": crystal,
	}


## §33/§46/§85: o painel isolado, ligado a um controller desatado. É o único jeito de
## mostrar "falta o Cristal" com Essência sobrando, sem depender de uma derrota alheia.
## A cena anda só por signal: entre as duas leituras abaixo ninguém tecla, ninguém espera
## frame nenhum, só o `amount_changed` do Cristal.
func _test_hud_missing_crystal_harness() -> void:
	var rig := await _make_detached_rig()
	var evolution := rig["evolution"] as CoreEvolutionController
	var state := rig["state"] as CoreState
	var crystal := rig["crystal"] as AbyssalCrystalState
	var panel := EVOLUTION_HUD_SCENE.instantiate()
	root.add_child(panel)
	await process_frame
	panel.bind(evolution, state, crystal)

	evolution.unlock_after_victory()
	_set_essence_to(state, MAX_ESSENCE_LV1)
	_check(_close(state.essence, MAX_ESSENCE_LV1),
			"§85 o harness tem Essência de sobra, %f" % state.essence)
	_check(not evolution.can_evolve(), "§33/§85 com tanque cheio e chave zero não evolui")
	_check(_text_of(panel, "StatusLabel") == CRYSTAL_STATUS,
			"§46/§85 o painel aponta a falta da chave, obtido %s"
					% _text_of(panel, "StatusLabel"))
	_check(_text_of(panel, "CrystalLabel") == CRYSTAL_BEFORE_LINE,
			"§44/§85 a linha lê o saldo real, obtido %s" % _text_of(panel, "CrystalLabel"))

	crystal.add(REWARD)
	# §49: nenhuma chamada de redrawing aqui. Se o painel dependesse de polling, a linha
	# ainda diria "0 / 1" e o status continuaria apontando uma falta que já não existe.
	_check(_text_of(panel, "CrystalLabel") == CRYSTAL_AFTER_VICTORY_LINE,
			"§45/§49/§85 o signal do Cristal redraw o painel na hora, obtido %s"
					% _text_of(panel, "CrystalLabel"))
	_check(_text_of(panel, "StatusLabel") == READY_STATUS,
			"§47/§85 com as três condições o painel anuncia a evolução, obtido %s"
					% _text_of(panel, "StatusLabel"))
	root.remove_child(panel)
	panel.free()
	_free_rig()


func _new_crystal() -> AbyssalCrystalState:
	return AbyssalCrystalState.new(load(CRYSTAL_PATH) as AbyssalCrystalDefinition)


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


# ==================================================================== Infraestrutura


func _reset_capture() -> void:
	_crystal_events.clear()


func _on_crystal_changed(current: int) -> void:
	_crystal_events.append(current)


func _on_campaign_crystal_changed(current: int) -> void:
	_crystal_events_before_victory.append(current)


func _boot_scene() -> void:
	_scene = MAIN_SCENE.instantiate()
	root.add_child(_scene)
	await _advance(0.2)
	_dungeon = _scene.get_node("World/DungeonRoot") as Node3D
	_camera = _scene.get_node("World/CameraRig/Camera3D") as Camera3D
	_selection = _scene.get_node("Systems/SelectionController") as SelectionController
	_construction = _scene.get_node("Systems/ConstructionController") as ConstructionController
	_recruitment = _scene.get_node(
			"Systems/SoldierRecruitmentController") as SoldierRecruitmentController
	_invasion = _scene.get_node("Systems/InvasionController") as InvasionController
	_evolution = _scene.get_node("Systems/CoreEvolutionController") as CoreEvolutionController
	_evolution_hud = _scene.get_node("UI/CoreEvolutionDebugPanel")
	_deposit = _scene.get_node("World/DungeonRoot/Deposit001") as ResourceDepositRuntime
	_core = _scene.get_node("World/DungeonRoot/MainCore") as CoreRuntime
	_worker = _scene.get_node("World/DungeonRoot/Worker001") as WorkerRuntime
	_stockpile = _deposit.stockpile
	_core_state = _core.core_state()
	_crystal = _evolution.abyssal_crystal_state()
	# §81/T14: a campanha inteira corre com o cronômetro de produção, sem encurtamento.
	# Depois do Ninho ainda há mineração, Quartel e Soldado a serem pagos pela geração
	# natural, e são os 60 s de aviso que dão esse tempo à partida. Encurtar aqui mataria
	# o Núcleo antes da defesa existir. O valor em si é provado em test_invasion_preparation.
	Engine.set_physics_ticks_per_second(TICKS)


func _free_scene() -> void:
	_soldier = null
	_worker2 = null
	_crystal = null
	if _scene != null and is_instance_valid(_scene):
		_scene.free()
	_scene = null
	_dungeon = null
	_camera = null
	_selection = null
	_construction = null
	_recruitment = null
	_invasion = null
	_evolution = null
	_evolution_hud = null
	_deposit = null
	_stockpile = null
	_core = null
	_core_state = null
	_worker = null


func _set_essence_to(state: CoreState, value: float) -> void:
	var difference := value - state.essence
	if difference > 0.0:
		state.add_essence(difference)
	elif difference < 0.0:
		state.consume_essence(-difference)


func _workers_in_scene() -> Array[WorkerRuntime]:
	var found: Array[WorkerRuntime] = []
	for child in _dungeon.get_children():
		if child is WorkerRuntime and not child.is_queued_for_deletion():
			found.append(child as WorkerRuntime)
	return found


func _piles_in_scene() -> Array[ResourcePileRuntime]:
	var found: Array[ResourcePileRuntime] = []
	for child in _dungeon.get_children():
		if child is ResourcePileRuntime and not child.is_queued_for_deletion():
			found.append(child as ResourcePileRuntime)
	return found


func _find_pile() -> ResourcePileRuntime:
	var piles := _piles_in_scene()
	return piles[0] if piles.size() == 1 else null


func _rock_with_id(id: String) -> RockRuntime:
	for child in _dungeon.get_children():
		if child is RockRuntime and (child as RockRuntime).rock_id == id \
				and not child.is_queued_for_deletion():
			return child as RockRuntime
	return null


func _rock_present(id: String) -> bool:
	return _rock_with_id(id) != null


func _total_cargo() -> int:
	var total := 0
	for worker in _workers_in_scene():
		total += worker.state.carried_amount
	return total


## Um turno completo de mineração, igual ao das suítes anteriores.
func _mine_with_two_workers(rock: RockRuntime) -> void:
	if rock == null:
		_check(false, "§81 a rocha de minério da campanha não foi encontrada")
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
			"§81 a rocha %s foi esgotada pelos dois Workers" % rock_id)
	_check(await _wait_until(func() -> bool: return _find_pile() != null, 10.0),
			"§81 a rocha %s virou uma pilha" % rock_id)
	if _find_pile() == null:
		return
	await _right_click(_find_pile().global_position)
	_check(await _wait_until(func() -> bool: return _total_cargo() == 3, 40.0),
			"§81 os Workers encheram a carga de 3, obtido %d" % _total_cargo())
	_check(await _wait_until(func() -> bool: return _total_cargo() == 0, 60.0),
			"§81 a carga chegou ao depósito")


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
		if _code_of(path).contains(needle):
			offenders.append(path)
	return offenders


func _files_named(sources: Array[String], needle: String) -> Array[String]:
	var offenders: Array[String] = []
	var lowered := needle.to_lower()
	for path in sources:
		if path.get_file().to_lower().contains(lowered):
			offenders.append(path)
	return offenders


func _close(a: float, b: float, tolerance := 0.001) -> bool:
	return absf(a - b) <= tolerance


func _print_measurements() -> void:
	print("[INFO] medições do Cristal Abissal: %s" % [_measurements])


func _check(condition: bool, label: String) -> void:
	_asserts += 1
	if condition:
		print("[PASS] %s" % label)
	else:
		_failures += 1
		print("[FAIL] %s" % label)


func _finish() -> void:
	print("---- abyssal crystal progression tests finished: %d asserts, %d failure(s) ----"
			% [_asserts, _failures])
	quit(1 if _failures > 0 else 0)
