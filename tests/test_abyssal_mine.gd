extends SceneTree

# Tarefa 20 — Mina Abissal, a primeira economia renovável do Núcleo Nv.2.
#
# A pergunta desta suíte não é "existe um objeto chamado Mina". É a do PRINCÍPIO da tarefa:
# depois de evoluir o Núcleo, o domínio deixa de depender só de depósitos finitos. Por isso
# cada cenário aqui mede saldo, relógio e mundo — nunca aparência.
#
# Quatro blocos, nesta ordem:
#   1) contrato e guarda de fonte (§80/§81–§85/§112–§116) — a Definition e o State existem
#      sozinhos, sem cena; a aritmética do relógio é exata em 30 Hz e em 120 Hz; e o que a
#      tarefa deliberadamente NÃO construiu (manager, Room*, output pile, segundo Worker)
#      fica provado por varredura de arquivos;
#   2) a obra no mundo (§32/§33/§75–§77/§86/§93/§94) — MineBuildPoint validado no Ground,
#   a   camada Construction reconhecida pelo SelectionController sem nenhum branch de tipo,
#      a tecla M real, a porta de Nível 1 antes do custo, o custo atômico e uma única Mina;
#   3) produção (§20/§21/§38–§42/§85/§87/§88/§95/§96/§79) — relógio desligado enquanto é
#      canteiro, primeiro minério só depois de um intervalo inteiro, saldo no Stockpile,
#      nenhuma Rocha tocada, nenhum monte criado, trabalho cooperativo de um e dois Workers;
#   4) persistência V2 (§74/§97–§105/§66/§67) — a Mina salva e volta incompleta ou com o
#      relógio no meio do ciclo, load repetido não duplica nem multiplica, e o arquivo V1
#      migra abrindo justamente a rota da Mina.
#
# §78: as medições isoladas usam harness controlado (Nv.2 aplicado direto no Runtime), e a
# integração real existe — ela é `_test_level_two_real_input_and_cost` e o E2E, que chegam
# ao Nv.2 pelo caminho canônico: invasão, vitória, Cristal, evolução.
#
# Todo arquivo mora em `user://tests/abyssal_mine/` e desaparece no fim (§107/T18). A cena
# volta ao pristine gravado no boot por `load_campaign()`, que é também a primeira prova de
# que a carga restaura.

const MAIN_SCENE := preload("res://game/GameMain.tscn")

const MINE_DEFINITION_PATH := "res://data/rooms/abyss_mine.tres"
const MINE_SCENE_PATH := "res://world/dungeon/rooms/mine/MineRuntime.tscn"
const MINE_DEFINITION_SOURCE := "res://core/definitions/mine_definition.gd"
const MINE_STATE_SOURCE := "res://core/state/mine_state.gd"
const MINE_RUNTIME_SOURCE := "res://world/dungeon/rooms/mine/mine_runtime.gd"
const SELECTION_SOURCE := "res://systems/selection/selection_controller.gd"
const CONSTRUCTION_SOURCE := "res://systems/construction/construction_controller.gd"
const SNAPSHOT_SOURCE := "res://systems/persistence/campaign_snapshot.gd"
const SAVE_CONTROLLER_SOURCE := "res://systems/persistence/save_game_controller.gd"
const GAME_MAIN_SOURCE := "res://game/game_main.gd"
const CONSTRUCTION_HUD_SOURCE := "res://ui/hud/construction_debug_hud.gd"
const RESOURCE_HUD_SOURCE := "res://ui/hud/resource_debug_hud.gd"
const PROJECT_SOURCE := "res://project.godot"
const CI_SOURCE := "res://.github/workflows/ci.yml"
const IRON_ORE_PATH := "res://data/resources/iron_ore.tres"
const CORE_LV2_PATH := "res://data/core/core_level_2.tres"
const NEST_SCENE_PATH := "res://world/dungeon/rooms/nest/NestRuntime.tscn"
const BARRACKS_SCENE_PATH := "res://world/dungeon/rooms/barracks/BarracksRuntime.tscn"

const MINE_DIR := "res://world/dungeon/rooms/mine"
const ROOMS_DIR := "res://data/rooms"
const RESOURCES_DIR := "res://data/resources"
const PERSISTENCE_DIR := "res://systems/persistence"
const CONSTRUCTION_SYSTEM_DIR := "res://systems/construction"
const UI_HUD_DIR := "res://ui/hud"
const V1_DOC := "res://docs/SAVE_SCHEMA_V1.md"
const V2_DOC := "res://docs/SAVE_SCHEMA_V2.md"

## §107/T18: caminho de teste, nunca o save do jogador.
const TEST_DIR := "user://tests/abyssal_mine"
const FRESH_PATH := "user://tests/abyssal_mine/pristine.json"
const PRIMARY_PATH := "user://tests/abyssal_mine/campaign.json"
const INCOMPLETE_PATH := "user://tests/abyssal_mine/incompleta.json"
const COMPLETE_PATH := "user://tests/abyssal_mine/concluida.json"
const ROUNDTRIP_PATH := "user://tests/abyssal_mine/roundtrip.json"
const REPEAT_PATH := "user://tests/abyssal_mine/repetida.json"
const V1_PATH := "user://tests/abyssal_mine/v1.json"
const V1_BACKUP_PATH := "user://tests/abyssal_mine/v1_backup.json"
const FUTURE_PATH := "user://tests/abyssal_mine/futura.json"
const E2E_PATH := "user://tests/abyssal_mine/e2e.json"
const TEST_PATHS: Array[String] = [FRESH_PATH, PRIMARY_PATH, INCOMPLETE_PATH, COMPLETE_PATH,
		ROUNDTRIP_PATH, REPEAT_PATH, V1_PATH, V1_BACKUP_PATH, FUTURE_PATH, E2E_PATH]

const PLAYER_PRIMARY := "user://campaign_save.json"
const PLAYER_BACKUP := "user://campaign_save.bak"

const ORE := &"iron_ore"
const ORE_DISPLAY := "Minério de Ferro"
const MINE_DISPLAY := "Mina Abissal"

## §5: os números que a tarefa fixou. Vêm da Definition, e esta suíte confere o arquivo —
## por isso as constantes existem aqui também: um valor alterado sem teste precisa falhar.
const MINE_COST := 6
const MINE_WORK := 8.0
const MINE_INTERVAL := 10.0
const MINE_AMOUNT := 1
const MINE_LEVEL := 2
const MINE_ID := "mine_001"
const MINE_TYPE_ID := &"abyss_mine"

## Os textos do painel (§36/§107), copiados da produção de propósito: se a linha sair do
## lugar, a suíte denuncia em vez de acompanhar. São literais porque `%` não é expressão
## constante em GDScript — e porque remontar o texto aqui seguiria o erro em vez de expô-lo.
const HUD_BLOCKED := "Mina Abissal: bloqueada — requer Núcleo Nv.2"
const HUD_READY := "[M] Mina Abissal — 6 Minério de Ferro: pronto para construir"
const HUD_BUILDING := "Mina Abissal: em construção"
const HUD_OPERATIONAL := "Mina Abissal: operacional — +1 Minério de Ferro / 10 s"
const HUD_INSUFFICIENT := "Mina Abissal: recursos insuficientes"

const GROUND_LAYER := 1
const UNIT_LAYER := 2
const DIGGABLE_LAYER := 4
const RESOURCE_LAYER := 8
const CONSTRUCTION_LAYER := 16
const CLICKABLE := GROUND_LAYER | UNIT_LAYER | DIGGABLE_LAYER | RESOURCE_LAYER | CONSTRUCTION_LAYER

## §32: o ponto da Mina é geometria de cena, conferido aqui e não no editor.
const MINE_BUILD_POINT := Vector3(0, 0, -9)
const NEST_BUILD_POINT := Vector3(-5, 0, -5)
const BARRACKS_BUILD_POINT := Vector3(-10, 0, -5)
const INVASION_PATH_A := Vector3(-4, 0, 10)
const INVASION_PATH_B := Vector3(11, 0, 0)
const CORE_POSITION := Vector3(0, 1, 0)

const WORKER_BUILD_GAP := 1.5
## A janela das medições de taxa: três ciclos inteiros com um resto folgado, para que a
## comparação entre 30 Hz e 120 Hz não caia em cima do ponto de corte do float.
const CLOCK_WINDOW := 31.5
const TICKS := 60
## O mundo pode andar mais rápido que o relógio da máquina (§40 não diz respeito a FPS
## interno de teste): a Mina é um ciclo de 10 s, e esperar 30 s reais por linha seria
## mentir para o CI. `_world(segundos)` entrega segundos de tempo de jogo.
const SPEED := 4.0
const ESSENCE_GRANT := 20.0
const SUMMON_COST := 10.0
const INVADER_COUNT := 2

## Os painéis que já existiam (§36/T20: a Mina não ganhou HUD próprio).
const HUD_SCENES: Array[String] = ["CombatDebugHud.tscn", "ConstructionDebugHud.tscn",
		"CoreDebugHud.tscn", "CoreEvolutionDebugHud.tscn", "InvasionDebugHud.tscn",
		"InvasionWarningHud.tscn", "MilitaryDebugHud.tscn", "ResourceDebugHud.tscn",
		"WorkerInvocationDebugHud.tscn"]

var _failures := 0
var _asserts := 0
var _frames := 0
var _measurements := {}
var _speed := 1.0

var _scene: Node
var _camera: Camera3D
var _dungeon: Node3D
var _floor: StaticBody3D
var _selection: SelectionController
var _construction: ConstructionController
var _invocation: WorkerInvocationController
var _invasion: InvasionController
var _evolution: CoreEvolutionController
var _save: SaveGameController
var _core: CoreRuntime
var _core_state: CoreState
var _crystal: AbyssalCrystalState
var _stockpile: ResourceStockpileState
var _iron: ResourceDefinition
var _core_lv2: CoreDefinition
var _worker: WorkerRuntime
var _mine_build_point: Marker3D
var _mine: MineRuntime
var _mine_hud: Node
var _ore_hud: Node

## Contadores de sinal: a única prova de "uma emissão" é o número de emissões.
var _mine_built_events := 0
var _mine_completed_events := 0
var _load_events: Array[String] = []
var _failed_events: Array[String] = []
var _player_before := ""
var _player_backup_before := ""


func _initialize() -> void:
	_run_all()


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > 1500000:
		_check(false, "timeout: a suíte da Mina Abissal não terminou")
		_finish()
	return false


func _run_all() -> void:
	# Bloco 1 — contrato da Mina e o que a tarefa não construiu. Sem cena.
	_test_definition_contract()
	_test_state_clock()
	_test_state_clock_at_both_rates()
	_test_scope_guards()

	# O resto precisa da árvore: InputMap, física, raycast e saldo de verdade.
	await _boot_scene()
	await _test_mine_build_point_and_scene()
	await _test_level_one_gate_with_real_key()
	await _test_level_two_real_input_and_cost()
	await _test_insufficient_iron()
	await _test_process_gating_and_completion()
	await _test_production_in_the_world()
	await _test_production_is_delta_driven()
	await _test_cooperative_construction()
	await _test_end_to_end_renewable_economy()
	await _test_mine_save_incomplete_and_complete()
	await _test_roundtrip_and_repeated_loads()
	await _test_v1_migration_opens_the_mine()
	await _test_future_version_touches_nothing()

	await _free_scene()
	_cleanup_test_files()
	_test_player_save_untouched()
	_print_measurements()
	_finish()


# ========================================= Bloco 1 — Definition, State e guardas de fonte


## §80/§5/§9: a Mina é uma ConstructionDefinition com relógio, e os números do arquivo são
## os números da tarefa. O custo e o produto são o MESMO iron_ore.tres — nenhuma Resource
## nova foi inventada para acomodar a economia.
func _test_definition_contract() -> void:
	var mine := load(MINE_DEFINITION_PATH) as MineDefinition
	_check(mine != null, "§80 abyss_mine.tres é uma MineDefinition")
	if mine == null:
		return
	_check(mine is ConstructionDefinition, "§80 MineDefinition herda ConstructionDefinition")
	_check(mine.mine_type_id == MINE_TYPE_ID, "§80 mine_type_id == abyss_mine, obtido %s"
			% mine.mine_type_id)
	_check(mine.display_name == MINE_DISPLAY, "§80 display_name, obtido %s" % mine.display_name)
	_check(mine.required_core_level == MINE_LEVEL, "§80 required_core_level == 2, obtido %d"
			% mine.required_core_level)
	_check(mine.build_cost == MINE_COST, "§80 build_cost == 6, obtido %d" % mine.build_cost)
	_check(_close(mine.work_required, MINE_WORK), "§80 work_required == 8.0, obtido %f"
			% mine.work_required)
	_check(mine.production_amount == MINE_AMOUNT, "§80 production_amount == 1, obtido %d"
			% mine.production_amount)
	_check(_close(mine.production_interval, MINE_INTERVAL),
			"§80 production_interval == 10.0, obtido %f" % mine.production_interval)
	_check(mine.output_resource != null and mine.output_resource.resource_id == ORE,
			"§80 output_resource == iron_ore")
	_check(mine.build_resource == mine.output_resource,
			"§9 custo e produto são o mesmo iron_ore.tres, sem Resource nova")
	_check(mine.build_resource == (load(IRON_ORE_PATH) as ResourceDefinition),
			"§9 o .tres referencia o recurso canônico em vez de duplicá-lo")
	_check(_files_in(RESOURCES_DIR, ".tres") == ["iron_ore.tres"],
			"§9/§112 nenhuma Resource de Biomassa foi inventada, obtido %s"
					% [_files_in(RESOURCES_DIR, ".tres")])
	_check(_files_in(ROOMS_DIR, ".tres")
			== ["abyss_barracks.tres", "abyss_mine.tres", "abyss_nest.tres"],
			"§9/§114 as três obras da campanha, nenhuma sala genérica, obtido %s"
					% [_files_in(ROOMS_DIR, ".tres")])
	# §8: a Definition própria da Mina declara só o relógio e a porta de nível.
	var definition_code := _code_of(MINE_DEFINITION_SOURCE)
	for own_field in ["required_core_level", "output_resource", "production_amount",
			"production_interval"]:
		_check(definition_code.contains(own_field),
				"§8 mine_definition.gd declara %s" % own_field)
	for inherited in ["build_cost", "work_required", "build_resource"]:
		_check(not definition_code.contains("var %s" % inherited),
				"§8/§115 %s continua herdado de ConstructionDefinition" % inherited)


## §81–§84/§11–§16: o State é obra (regra da base) e relógio (regra própria). A aritmética é
## testada aqui, em segundos exatos, porque é ela que §40 jura ser independente de frame.
func _test_state_clock() -> void:
	var mine := load(MINE_DEFINITION_PATH) as MineDefinition
	var state := MineState.new(mine, MINE_ID)
	_check(state is ConstructionState, "§81 MineState herda ConstructionState")
	_check(_close(state.remaining_work, MINE_WORK), "§81 nasce devendo o trabalho da Definition")
	_check(_close(state.production_elapsed, 0.0), "§81/§11 o relógio começa em zero")
	_check(state.mine_id == MINE_ID, "§10 mine_id é o instance_id da base, obtido %s"
			% state.mine_id)

	# §82/§15: canteiro não produz, e nem acumula tempo.
	_check(state.advance_production(100.0) == 0, "§82 inacabada entrega 0 mesmo com 100 s")
	_check(_close(state.production_elapsed, 0.0), "§82/§11 elapsed segue 0 enquanto é obra")
	# §14: delta inválido não move nada.
	state.apply_work(MINE_WORK)
	_check(state.is_completed(), "§83 a obra conclui pela regra da base")
	_check(state.advance_production(0.0) == 0, "§14 delta zero não produz")
	_check(state.advance_production(-5.0) == 0, "§14 delta negativo não produz")
	_check(_close(state.production_elapsed, 0.0), "§14 delta inválido não move o relógio")
	# §83/§12: o ciclo é exato — 9 s não pagam nada, o décimo segundo paga um.
	_check(state.advance_production(9.0) == 0, "§83 nove segundos não fecham ciclo, obtido %f s"
			% state.production_elapsed)
	_check(_close(state.production_elapsed, 9.0), "§83/§12 os 9 s ficaram no relógio, %f"
			% state.production_elapsed)
	_check(state.advance_production(1.0) == MINE_AMOUNT, "§83 o décimo segundo produz 1")
	_check(_close(state.production_elapsed, 0.0),
			"§12/§83 o bloco inteiro é consumido, sobrou %f" % state.production_elapsed)
	# §84/§13: um delta grande fecha todos os ciclos que cobre.
	var burst := state.advance_production(35.0)
	_check(burst == 3, "§84 35 s produzem 3 minérios, obtido %d" % burst)
	_check(_close(state.production_elapsed, 5.0), "§84 sobram 5 s no relógio, obtido %f"
			% state.production_elapsed)
	# §16: restaurar é escrever o relógio, com a faixa conferida contra a Definition.
	_check(not state.restore_production_elapsed(-0.1), "§16 elapsed negativo é recusado")
	_check(not state.restore_production_elapsed(MINE_INTERVAL),
			"§16 o intervalo é exclusive — um ciclo inteiro se restaura produzindo")
	_check(not state.restore_production_elapsed(11.0), "§16 acima do intervalo é recusado")
	_check(state.restore_production_elapsed(6.25), "§16 6.25 s é um relógio válido")
	_check(_close(state.production_elapsed, 6.25), "§16 o número salvo chegou, obtido %f"
			% state.production_elapsed)
	# §99 pela aritmética: o que falta para o próximo minério é o resto do ciclo.
	_check(state.advance_production(3.7) == 0, "§99 com 6.25 s salvos, 3.7 s ainda não chegam")
	_check(state.advance_production(0.1) == MINE_AMOUNT, "§99/§12 o ciclo fecha no resto salvo")

	# §17/§114: a Mina mora na fundação da Tarefa 15, com dois arquivos próprios.
	_check(_files_in(MINE_DIR, ".gd") == ["mine_runtime.gd"],
			"§17 rooms/mine tem um Runtime, obtido %s" % [_files_in(MINE_DIR, ".gd")])
	_check(_files_in(MINE_DIR, ".tscn") == ["MineRuntime.tscn"],
			"§17 rooms/mine tem uma cena, obtido %s" % [_files_in(MINE_DIR, ".tscn")])
	var state_code := _code_of(MINE_STATE_SOURCE)
	for not_here in ["ResourcePile", "Worker", "Stockpile", "add_resource", "Node"]:
		_check(not state_code.contains(not_here),
				"§23/§112 MineState não contém %s — State não decide destino de produto"
						% not_here)


## §85: a mesma aritmética entregue em passos de 30 Hz e de 120 Hz produz o mesmo número na
## mesma janela de mundo. É esta a prova de §40: ninguém conta frame.
func _test_state_clock_at_both_rates() -> void:
	var mine := load(MINE_DEFINITION_PATH) as MineDefinition
	var results := {}
	# 31.5 s de mundo, e não 30: somar 1/30 noventena vezes chega a 29.99999999999993, e o
	# teste passaria a medir o ponto de corte do float em vez de medir a independência de FPS.
	for rate in [30, 120]:
		var state := MineState.new(mine, MINE_ID)
		state.apply_work(MINE_WORK)
		var produced := 0
		for _step in int(rate * CLOCK_WINDOW):
			produced += state.advance_production(1.0 / float(rate))
		results[rate] = {"produced": produced, "elapsed": state.production_elapsed}
	_check(int(results[30]["produced"]) == 3, "§85 30 Hz em %s s produz 3, obtido %s"
			% [CLOCK_WINDOW, results[30]])
	_check(int(results[120]["produced"]) == 3, "§85 120 Hz em %s s produz 3, obtido %s"
			% [CLOCK_WINDOW, results[120]])
	_check(absf(float(results[30]["elapsed"]) - float(results[120]["elapsed"])) < 0.001,
			"§85 o resto do relógio é equivalente: %f vs %f"
					% [float(results[30]["elapsed"]), float(results[120]["elapsed"])])


## §112–§116/§34/§94/§109–§110/§120: o que a tarefa NÃO é, e onde cada regra vive.
func _test_scope_guards() -> void:
	var sources := _collect_gd_files("res://")
	_check(not sources.is_empty(), "§118 a varredura achou os fontes de produção")

	# §113/§112: nenhuma gerência nova. A Mina é uma obra, não um sistema.
	for forbidden in ["MineManager", "ProductionManager", "EconomyManager", "RoomManager",
			"RoomDefinition", "RoomState", "RoomRuntime", "MineUpgrade", "MineModule",
			"MineStaffing", "MineProductivity", "MaintenanceSystem", "PowerSystem",
			"Biomass", "FungalFarm", "HaulingJob", "OutputPile"]:
		_check(_files_named(sources, forbidden).is_empty(),
				"§112/§113/§114 nenhum fonte se chama %s" % forbidden)
		_check(_files_containing(sources, "class_name %s" % forbidden).is_empty(),
				"§112/§114 nenhuma classe %s foi declarada" % forbidden)
	# §112: nada de terceiro Worker, terceiro nível ou segunda invasão.
	_check(_files_containing(sources, "worker_003").is_empty(),
			"§112 não existe Worker003 no projeto, achado em %s"
					% [_files_containing(sources, "worker_003")])
	_check(_files_containing(sources, "level = 3").is_empty(),
			"§112 nenhuma Definition de Núcleo Nv.3")

	# §34/§94: a prova do valor da refatoração da Tarefa 15 — o controller de seleção não
	# sabe que a Mina existe. Obra é camada, nunca tipo.
	var selection_code := _code_of(SELECTION_SOURCE)
	for type_name in ["MineRuntime", "NestRuntime", "BarracksRuntime"]:
		_check(not selection_code.contains(type_name),
				"§34/§94 SelectionController não tem branch de %s" % type_name)
	_check(selection_code.contains("CONSTRUCTION_LAYER"),
			"§34 a obra é reconhecida pela camada física")

	# §115/§113: a fundação não foi refeita nem ganhou arquivos.
	_check(_files_in(CONSTRUCTION_SYSTEM_DIR, ".gd") == ["construction_controller.gd"],
			"§115 systems/construction continua com um controller, obtido %s"
					% [_files_in(CONSTRUCTION_SYSTEM_DIR, ".gd")])
	_check(_collect_gd_files(PERSISTENCE_DIR).size() == 2,
			"§116 a persistência são dois arquivos, sem framework de migração")
	_check(_files_in(UI_HUD_DIR, ".tscn") == HUD_SCENES,
			"§36 nenhum HUD novo, obtido %s" % [_files_in(UI_HUD_DIR, ".tscn")])

	# §25/§26: a Mina entra por rota própria e o setup antigo continua de oito argumentos.
	var construction_code := _code_of(CONSTRUCTION_SOURCE)
	for required in ["signal mine_built", "signal mine_completed",
			"MINE_INSTANCE_ID := \"mine_001\"", "func mine()", "func bind_mine(",
			"func build_mine()", "func restore_mine("]:
		_check(construction_code.contains(required),
				"§25/§26/§63 construction_controller.gd contém %s" % required)
	_check(construction_code.contains("barracks_build_point: Node3D = null) -> void:"),
			"§26 setup() não virou uma assinatura de onze parâmetros")
	_check(not construction_code.contains("if mine is ")
			and not construction_code.contains("match "),
			"§25 o controller conhece cada obra por nome, sem type switch")

	# §27: a tecla M entra pelo InputMap e é a única dona do physical_keycode 77.
	var project := _source(PROJECT_SOURCE)
	_check(project.contains("build_mine="), "§27 o InputMap declara build_mine")
	_check(_count_occurrences(project, "\"physical_keycode\": 77") == 1,
			"§27 M não disputa nenhuma outra ação, obtido %d ocorrências"
					% _count_occurrences(project, "\"physical_keycode\": 77"))
	_check(_source(CONSTRUCTION_SOURCE).contains("is_action_pressed(\"build_mine\")"),
			"§27 a obra é pedida pela ação, nunca pela letra solta")

	# §20/§22/§24: o Runtime é delta, estoque e nada de monte.
	var runtime_code := _code_of(MINE_RUNTIME_SOURCE)
	_check(runtime_code.contains("func _process(delta: float) -> void:"), "§20 um único _process")
	_check(runtime_code.contains("set_process(is_completed())"),
			"§20/§86 o processo é ligado pela conclusão")
	_check(runtime_code.count("func _process(") == 1 and not runtime_code.contains(
			"func _physics_process("), "§117 a Mina tem exatamente um processo")
	for not_here in ["ResourcePile", "spawn_resource_pile", "Worker", "load(", "FileAccess"]:
		_check(not runtime_code.contains(not_here),
				"§24/§22 MineRuntime não contém %s" % not_here)
	_check(runtime_code.contains("_stockpile.add_resource(mine_definition.output_resource"),
			"§22 a produção vai direto para o ResourceStockpileState")

	# §37/§106: o HUD de recurso não soube da Mina — por isso continua funcionando.
	_check(not _code_of(RESOURCE_HUD_SOURCE).to_lower().contains("mine"),
			"§37 resource_debug_hud.gd não ganhou código da Mina")
	var hud_code := _code_of(CONSTRUCTION_HUD_SOURCE)
	for required in ["MineStatusLabel", "mine_built.connect", "mine_completed.connect",
			"_refresh_mine()"]:
		_check(hud_code.contains(required), "§36/§107 o painel de construção trata da Mina em %s"
				% required)

	# §45/§53/§116: versão por versão, uma rota nomeada, sem framework.
	var snapshot_code := _code_of(SNAPSHOT_SOURCE)
	for required in ["const SAVE_VERSION := 2", "const SAVE_VERSION_V1 := 1",
			"static func validate_v1(", "static func validate_v2(",
			"static func migrate_v1_to_v2(", "static func migrate_to_current("]:
		_check(snapshot_code.contains(required), "§47/§53/§60 campaign_snapshot.gd contém %s"
				% required)
	for forbidden in ["MigrationRegistry", "MigrationManager", "SchemaGraph",
			"MigrationDefinition", "MigrationV2"]:
		_check(_files_containing(sources, forbidden).is_empty(),
				"§116 nenhum fonte contém %s, achado em %s"
						% [forbidden, _files_containing(sources, forbidden)])

	# §109/§110: o V1 é histórico preservado e o V2 documenta a diferença real.
	_check(FileAccess.file_exists(V1_DOC), "§109 docs/SAVE_SCHEMA_V1.md continua no projeto")
	_check(FileAccess.file_exists(V2_DOC), "§110 docs/SAVE_SCHEMA_V2.md existe")
	var v2_text := _source(V2_DOC).to_lower()
	for documented in ["save_version", "mine", "production_elapsed", "migration",
			"v1", "offline"]:
		_check(v2_text.contains(documented),
				"§110 o documento V2 documenta %s" % documented)
	var v1_text := _source(V1_DOC)
	_check(v1_text.contains("\"save_version\": 1"),
			"§109 o documento V1 preserva o exemplo que existia")

	# §120: a suíte entra no CI por descoberta, não por lista.
	var ci_text := _source(CI_SOURCE)
	_check(not ci_text.contains("abyssal_mine"),
			"§120 o workflow não lista suíte nenhuma — a descoberta é automática")
	_check(not _source(GAME_MAIN_SOURCE).contains("mine_001"),
			"§25 a raiz de composição não conhece instância nenhuma")


# ============================================================ Bloco 2 — a obra no mundo


## §32/§33/§18/§19/§93: o canteiro tem lugar físico validado no Ground, usa a camada de obra
## já existente e tem cena própria — visualmente distinta, sem asset e sem material que a
## GeForce 9800 GT não saiba desenhar.
func _test_mine_build_point_and_scene() -> void:
	_check(_mine_build_point.get_class() == "Marker3D", "§32 MineBuildPoint é um Marker3D")
	_check(_mine_build_point.global_position.is_equal_approx(MINE_BUILD_POINT),
			"§32 MineBuildPoint em (0, 0, -9), obtido %s" % [_mine_build_point.global_position])
	_check(_physics_nodes_under(_mine_build_point).is_empty(),
			"§32 o build point não tem collider nem intercepta raycast")
	var screen := _camera.unproject_position(MINE_BUILD_POINT)
	_check(Rect2(Vector2.ZERO, Vector2(root.size)).has_point(screen),
			"§32 o ponto da Mina está dentro do campo da câmera, obtido %s" % [screen])
	var hit := _ray_hit(screen, CLICKABLE)
	_check(not hit.is_empty() and hit.collider == _floor,
			"§32 antes da obra o clique no ponto da Mina cai no Ground, obtido %s"
					% [hit.get("collider")])
	_check(_planar_gap(MINE_BUILD_POINT, NEST_BUILD_POINT) >= 6.0,
			"§32 a Mina não se sobrepõe ao Ninho, obtido %f"
					% _planar_gap(MINE_BUILD_POINT, NEST_BUILD_POINT))
	_check(_planar_gap(MINE_BUILD_POINT, BARRACKS_BUILD_POINT) >= 6.0,
			"§32 a Mina não se sobrepõe ao Quartel, obtido %f"
					% _planar_gap(MINE_BUILD_POINT, BARRACKS_BUILD_POINT))
	_check(_planar_gap(MINE_BUILD_POINT, CORE_POSITION) >= 7.0,
			"§32 a Mina fica fora do corpo do Núcleo, obtido %f"
					% _planar_gap(MINE_BUILD_POINT, CORE_POSITION))
	for rock in _rocks():
		_check(_planar_gap(MINE_BUILD_POINT, rock.global_position) >= 2.6,
				"§32 o canteiro não nasce sobre a Rocha %s, obtido %f"
						% [rock.rock_id, _planar_gap(MINE_BUILD_POINT, rock.global_position)])
	for path_name in ["A", "B"]:
		var origin := INVASION_PATH_A if path_name == "A" else INVASION_PATH_B
		_check(_segment_gap(origin, CORE_POSITION) >= 2.2,
				"§32 a Mina não fecha o corredor de invasão %s, folga %f"
						% [path_name, _segment_gap(origin, CORE_POSITION)])

	# §18/§19: a cena é low-poly própria, sem extermal e sem metallic cheio.
	var scene_text := _source(MINE_SCENE_PATH)
	_check(_count_occurrences(scene_text, "[ext_resource") == 1,
			"§18/§23 a cena só referencia o próprio script, obtido %d"
					% _count_occurrences(scene_text, "[ext_resource"))
	_check(not scene_text.contains("metallic = 1\n")
			and not scene_text.contains("metallic = 1.0"),
			"§19 nenhum material metálico cheio — OpenGL 3.3 deixaria a Mina preta")
	_check(not scene_text.contains("Animation") and not scene_text.contains("Particles"),
			"§18 sem animação nem partícula")
	_check(scene_text.contains("collision_layer = 16"),
			"§33 a Mina usa a camada Construction que já existia")
	_check(scene_text != _source(NEST_SCENE_PATH) and scene_text != _source(BARRACKS_SCENE_PATH),
			"§18/§108 a Mina tem cena própria, não é o Ninho com outro nome")
	for mesh in ["Entrance", "Ore1", "Post1", "Lintel"]:
		_check(scene_text.contains(String(mesh)),
				"§18 CompletedVisual tem %s — entrada escura, minério e estrutura" % mesh)


## §75/§76/§89/§107: a GameMain fresca é Nv.1, o jogador tem minério sobrando e a tecla M
## real não faz nada — o bloqueio vem antes do custo, então o saldo nem é tocado.
func _test_level_one_gate_with_real_key() -> void:
	await _reset_campaign()
	_give_iron(20)
	await _advance(0.05)
	_check(_core_state.level == 1, "§76 a campanha fresca é Nv.1, obtido %d" % _core_state.level)
	_check(_stockpile.get_amount(ORE) == 20, "§76 há 20 de minério para gastar")
	_check(_text_of(_mine_hud, "MineStatusLabel") == HUD_BLOCKED,
			"§107 Lv.1: o painel diz %s, obtido %s" % [HUD_BLOCKED,
					_text_of(_mine_hud, "MineStatusLabel")])
	await _press_mine_key()
	_check(_construction.mine() == null, "§75/§76 M no Nv.1 não cria Mina")
	_check(_stockpile.get_amount(ORE) == 20, "§76/§89 o bloqueio não consome nada, obtido %d"
			% _stockpile.get_amount(ORE))
	_check(_mine_built_events == 0, "§76 nenhum signal de obra, obtido %d" % _mine_built_events)
	_check(not _construction.build_mine(), "§89 build_mine() direto também recusa no Nv.1")
	_check(_mine_count() == 0, "§76 zero obras, obtido %d" % _mine_count())


## §77/§78/§90/§31/§92/§107: a integração real. A campanha joga o MVP até o Nv.2, e aí a
## mesma tecla M abre a obra — o custo sai uma única vez, e a Mina é uma só.
func _test_level_two_real_input_and_cost() -> void:
	await _reset_campaign()
	_give_iron(20)
	await _reach_level_two_for_real()
	_check(_core_state.level == MINE_LEVEL, "§78 Nv.2 alcançado pelo caminho canônico")
	_check(_stockpile.get_amount(ORE) == 20, "§77 o minério da porta está na mão, obtido %d"
			% _stockpile.get_amount(ORE))
	_check(_text_of(_mine_hud, "MineStatusLabel") == HUD_READY,
			"§107 Lv.2 disponível: %s, obtido %s" % [HUD_READY,
					_text_of(_mine_hud, "MineStatusLabel")])
	await _press_mine_key()
	_mine = _construction.mine()
	_check(_mine != null, "§77/§90 M no Nv.2 lança o canteiro da Mina")
	if _mine == null:
		return
	_check(_stockpile.get_amount(ORE) == 20 - MINE_COST,
			"§77/§90 seis minérios cobrados de uma vez, obtido %d"
					% _stockpile.get_amount(ORE))
	_check(_mine.global_position.is_equal_approx(MINE_BUILD_POINT),
			"§32 a Mina nasceu no MineBuildPoint, obtido %s" % [_mine.global_position])
	_check(_mine is ConstructionRuntime, "§93/§17 MineRuntime é ConstructionRuntime")
	_check(_mine.state is ConstructionState, "§81 o State da Mina é um ConstructionState")
	_check(_mine.collision_layer == CONSTRUCTION_LAYER,
			"§33/§93 a Mina está na camada Construction, obtida %d" % _mine.collision_layer)
	_check(_mine.state.mine_id == MINE_ID, "§25 a instância é mine_001, obtida %s"
			% _mine.state.mine_id)
	_check(_mine_built_events == 1, "§25 mine_built emitido exatamente uma vez, %d"
			% _mine_built_events)
	_check(_text_of(_mine_hud, "MineStatusLabel") == HUD_BUILDING,
			"§107 em construção: %s, obtido %s" % [HUD_BUILDING,
					_text_of(_mine_hud, "MineStatusLabel")])
	# §34/§94 de verdade: o ray do SelectionController reconhece a obra pela camada.
	var hit := _ray_hit(_camera.unproject_position(_mine.global_position), CLICKABLE)
	_check(not hit.is_empty() and hit.collider == _mine,
			"§34/§94 a Mina é alcançada pelo mesmo raycast que enxerga Ninho e Quartel")
	# §31/§92: M de novo não cobra nem duplica.
	await _press_mine_key()
	_check(_mine_count() == 1, "§31 uma única Mina, obtido %d" % _mine_count())
	_check(_stockpile.get_amount(ORE) == 20 - MINE_COST,
			"§92 nenhuma segunda cobrança, obtido %d" % _stockpile.get_amount(ORE))
	_check(_mine_built_events == 1, "§92 mine_built continua 1, obtido %d" % _mine_built_events)


## §30/§91: aberta a porta do nível, a outra recusa é a do saldo — e ela também é atômica.
func _test_insufficient_iron() -> void:
	await _reset_campaign()
	await _unlock_level_two(MINE_COST - 1)
	_check(_stockpile.get_amount(ORE) == MINE_COST - 1, "§91 há 5 de 6 necessários")
	_check(not _construction.build_mine(), "§91 com 5 minérios a Mina é recusada")
	_check(_construction.mine() == null, "§91 nenhum canteiro foi criado")
	_check(_stockpile.get_amount(ORE) == MINE_COST - 1,
			"§30/§91 a recusa não descontou nada, obtido %d" % _stockpile.get_amount(ORE))
	_check(_text_of(_mine_hud, "MineStatusLabel") == HUD_INSUFFICIENT,
			"§107 Nv.2 sem saldo: %s, obtido %s" % [HUD_INSUFFICIENT,
					_text_of(_mine_hud, "MineStatusLabel")])


## §20/§21/§86/§18: enquanto é obra não há processo nem produção; a conclusão liga o relógio
## zerado e troca o visual pela regra da base.
func _test_process_gating_and_completion() -> void:
	await _reset_campaign()
	await _open_mine_site(MINE_COST + 4)
	_check(_mine != null and not _mine.is_completed(), "setup: canteiro aberto")
	_check(not _mine.is_processing(), "§20/§86 canteiro não roda _process")
	_check(_close(_mine_clock(), 0.0), "§11 enquanto é obra o relógio é zero")
	var site_visual := _mine.find_child("ConstructionVisual", true, false) as Node3D
	var built_visual := _mine.find_child("CompletedVisual", true, false) as Node3D
	_check(site_visual != null and built_visual != null, "§18 a cena tem os dois visuais")
	_check(site_visual.visible and not built_visual.visible, "§18 canteiro visível, prédio oculto")
	await _world(4.0)
	_check(_stockpile.get_amount(ORE) == 4, "§82/§15 obra inacabada não produz, obtido %d"
			% _stockpile.get_amount(ORE))
	_check(_mine_built_events == 1 and _mine_completed_events == 0,
			"§21 nenhuma conclusão antes da hora (%d/%d)"
					% [_mine_built_events, _mine_completed_events])

	# A conclusão é síncrona no `apply_work`, e é por isso que o zero do relógio é conferido
	# antes de qualquer frame: um frame depois, o processo já terá andado.
	_mine.state.apply_work(MINE_WORK)
	_check(_mine.is_completed(), "§21 a obra conclui")
	_check(_mine.is_processing(), "§86/§20 concluída, o processo liga")
	_check(_close(_mine_clock(), 0.0), "§21/§11 o relógio recomeça do zero")
	_check(built_visual.visible and not site_visual.visible, "§18/§108 o visual trocou")
	_check(_mine_completed_events == 1, "§21 mine_completed uma vez, obtido %d"
			% _mine_completed_events)
	_check(_text_of(_mine_hud, "MineStatusLabel") == HUD_OPERATIONAL,
			"§107 operacional: %s, obtido %s" % [HUD_OPERATIONAL,
					_text_of(_mine_hud, "MineStatusLabel")])
	await _advance(0.05)
	_check(_mine_clock() > 0.0 and _mine_clock() < 0.5,
			"§20/§11 ligado o processo, o relógio anda com o mundo, obtido %f" % _mine_clock())
	await _world(0.3)
	_check(_stockpile.get_amount(ORE) == 4, "§21/§38 nenhuma moeda instantânea na conclusão")


## §38/§39/§87/§40/§41/§42/§24/§37: o ciclo de produção no mundo real — 4 minérios em saldo,
## dez segundos para o quinto, e ele continua sozinho. Rocha e monte não mudam.
func _test_production_in_the_world() -> void:
	await _reset_campaign()
	await _open_mine_site(MINE_COST + 4)
	_mine.state.apply_work(MINE_WORK)
	await _advance(0.05)
	var iron := _stockpile.get_amount(ORE)
	var rocks_before := _rock_progress()
	_check(iron == 4, "§87 antes: 4 minérios no saldo, obtido %d" % iron)
	_set_speed(SPEED)
	# §38: abaixo do intervalo, nada. A janela é 9 s de mundo — nunca um frame.
	await _world(MINE_INTERVAL - 1.0)
	_check(_stockpile.get_amount(ORE) == iron, "§38 antes do intervalo nada foi produzido")
	_check(_mine_clock() > 8.0 and _mine_clock() < MINE_INTERVAL,
			"§38 o relógio andou com o mundo, obtido %f" % _mine_clock())
	var first := await _wait_for_iron(iron + MINE_AMOUNT, 4.0)
	_check(first and _stockpile.get_amount(ORE) == iron + MINE_AMOUNT,
			"§38/§87 o primeiro minério chegou em %d s, obtido %d"
					% [int(MINE_INTERVAL), _stockpile.get_amount(ORE)])
	await _world(MINE_INTERVAL)
	_check(_stockpile.get_amount(ORE) == iron + 2 * MINE_AMOUNT,
			"§39 o segundo ciclo fechou sozinho, obtido %d" % _stockpile.get_amount(ORE))
	await _world(MINE_INTERVAL)
	_check(_stockpile.get_amount(ORE) == iron + 3 * MINE_AMOUNT,
			"§39/§84 a produção é contínua — 30 s, 3 minérios, obtido %d"
					% _stockpile.get_amount(ORE))
	_measurements["saldo_antes"] = iron
	_measurements["saldo_depois_30s"] = _stockpile.get_amount(ORE)
	_measurements["religio_apos_30s"] = _mine_clock()
	_check(_mine_clock() < MINE_INTERVAL, "§12 o resto do ciclo continua menor que o intervalo")
	_check(_pile_count() == 0, "§24/§42/§88 nenhum monte nasceu da Mina, obtido %d"
			% _pile_count())
	_check(_rock_progress() == rocks_before, "§41/§88 a produção não encosta em nenhuma Rocha")
	_check(_text_of(_ore_hud, "OreLabel") == "%s: %d" % [ORE_DISPLAY, iron + 3 * MINE_AMOUNT],
			"§37/§106 o HUD de recurso acompanha por signal, obtido %s"
					% _text_of(_ore_hud, "OreLabel"))
	_set_speed(1.0)


## §40/§85 no Runtime: o mesmo relógio semeados fecha o ciclo em 30 Hz e em 120 Hz. Ninguém
## conta frames — a produção é função do delta que o motor entrega.
func _test_production_is_delta_driven() -> void:
	var results := {}
	for rate in [30, 120]:
		await _reset_campaign()
		await _open_mine_site(MINE_COST)
		_mine.state.apply_work(MINE_WORK)
		await _advance(0.05)
		# §16: a mesma porta que o load usa serve aqui para semear o relógio perto da borda.
		_check(_mine.restore_production(9.4), "§16 setup: relógio semeados em 9.4 s")
		Engine.set_physics_ticks_per_second(rate)
		_set_speed(SPEED)
		var iron := _stockpile.get_amount(ORE)
		await _world(0.4)
		var before := _stockpile.get_amount(ORE)
		await _world(0.5)
		results[rate] = {"produced": _stockpile.get_amount(ORE) - iron,
				"elapsed": _mine_clock(),
				"stopped_at": before - iron}
		_set_speed(1.0)
		Engine.set_physics_ticks_per_second(TICKS)
	_check(int(results[30]["produced"]) == int(results[120]["produced"]),
			"§40/§85 30 Hz e 120 Hz produziram o mesmo: %s" % [results])
	_check(int(results[30]["produced"]) + int(results[30]["stopped_at"]) == MINE_AMOUNT,
			"§40 o ciclo fechou uma única vez em cada taxa: %s" % [results])
	_check(absf(float(results[30]["elapsed"]) - float(results[120]["elapsed"])) < 0.25,
			"§85 o resto do relógio é equivalente entre taxas: %s" % [results])
	_measurements["fps_30hz"] = results[30]
	_measurements["fps_120hz"] = results[120]


## §34/§35/§95/§96: a obra cooperativa da Tarefa 15 atende a Mina sem código novo — RMB
## real, ordem BUILD, e o trabalho de um Worker rende 1.0/s, de dois rende 2.0/s.
func _test_cooperative_construction() -> void:
	await _reset_campaign()
	await _open_mine_site(MINE_COST)
	_check(_mine != null, "setup: canteiro da Mina lançado")
	await _park_near_mine(_worker, -1.0)
	await _advance(0.05)
	_selection.clear_selection()
	await _click_select(_worker)
	_check(_selection.selected_unit == _worker, "§34 o Worker foi selecionado por clique real")
	await _right_click(_mine.global_position)
	_check(_worker.action_mode() == WorkerRuntime.ActionMode.BUILD,
			"§34/§94 RMB na Mina coloca o Worker em BUILD pela camada")
	_check(_worker.current_construction_target() == _mine,
			"§34 o alvo de construção é a Mina, obtido %s" % [_worker.current_construction_target()])
	await _advance(0.1)
	var rate_one := await _measure_work_rate()
	var predicted_one := MINE_WORK / rate_one
	_check(_close(rate_one, 1.0, 0.2),
			"§95 um Worker rende work_speed por segundo, obtido %f" % rate_one)
	_check(_close(predicted_one, 8.0, 1.5),
			"§95/§35 trabalho puro de um Worker ≈ 8 s, obtido %f" % predicted_one)

	_give_essence(SUMMON_COST + 2.0)
	_check(_invocation.summon_worker(), "§96 Worker002 convocado para a obra")
	await _advance(0.1)
	var second := _second_worker()
	_check(second != null, "§96 o segundo Worker está em campo")
	if second == null:
		return
	await _park_near_mine(second, 1.0)
	# §34/§96: o Worker001 continua selecionado desde o clique real lá em cima — a ordem de
	# construção não desfaz a seleção. O shift-clique é no recém-chegado, que ainda está no
	# ponto de estacionamento; o que já trabalha encostou no canteiro e é o corpo da Mina que
	# o ray encontra primeiro. Clicar nele seria testar a geometria da câmera, não a obra.
	await _shift_click_select(second)
	_check(_selection.selected_units.has(_worker) and _selection.selected_units.has(second),
			"§96 o grupo é os dois Workers, obtido %s" % [_selection.selected_units])
	_check(_selection.selected_units.size() == 2, "§96 dois Workers selecionados, obtido %d"
			% _selection.selected_units.size())
	await _right_click(_mine.global_position)
	_check(_worker.is_building() and second.is_building(),
			"§35/§96 os dois atenderam a mesma obra")
	_check(_worker.current_construction_target() == _mine
			and second.current_construction_target() == _mine,
			"§35 os dois têm a Mina como alvo — a obra é compartilhada, não duplicada")
	await _advance(0.1)
	var rate_two := await _measure_work_rate()
	var predicted_two := MINE_WORK / rate_two
	_check(_close(rate_two, 2.0, 0.3),
			"§96 dois Workers rendem 2.0 de trabalho por segundo, obtido %f" % rate_two)
	_check(_close(predicted_two, 4.0, 1.0),
			"§96/§35 trabalho puro de dois Workers ≈ 4 s, obtido %f" % predicted_two)
	_check(predicted_two < predicted_one, "§35 a cooperação acelera a obra, %f contra %f"
			% [predicted_two, predicted_one])
	_measurements["trabalho_1_worker"] = predicted_one
	_measurements["trabalho_2_workers"] = predicted_two
	# A obra continua de verdade até fechar, e o relógio liga sozinho na conclusão.
	var done := await _wait_until(func() -> bool: return _mine.is_completed(), 30.0)
	_check(done, "§95/§21 os Workers terminaram a Mina")
	_check(_mine_completed_events == 1, "§21 uma conclusão por obra, obtido %d"
			% _mine_completed_events)
	_check(_mine.is_processing(), "§20/§86 a Mina terminada produz")


## §79: o cenário principal inteiro, por InputMap, SelectionController, BUILD, MineRuntime e
## Stockpile — uma campanha Nv.2 carregada, M, dois Workers, obra, e saldo +1 a cada 10 s.
func _test_end_to_end_renewable_economy() -> void:
	await _reset_campaign()
	# §107: o arquivo desta cena é o E2E_PATH — salvar no FRESH_PATH destruíria o ponto de
	# isolamento de todas as suítes seguintes.
	_use_path(E2E_PATH)
	_give_iron(MINE_COST)
	await _reach_level_two_for_real()
	_check(_invocation.summon_worker(), "§79 setup: Worker002 convocado")
	await _advance(0.1)
	_check(_save.save_campaign(), "§79 a campanha Nv.2 com dois Workers é salva")
	await _reset_campaign()
	_use_path(E2E_PATH)
	_check(_save.load_campaign(), "§79 load da campanha Nv.2")
	var loaded := _workers()
	_check(loaded.size() == 2, "§79 dois Workers voltaram do arquivo, obtido %d"
			% loaded.size())
	_check(_core_state.level == MINE_LEVEL, "§79 o Nv.2 veio do arquivo")
	_check(_stockpile.get_amount(ORE) >= MINE_COST, "§79 o minério veio do arquivo, %d"
			% _stockpile.get_amount(ORE))
	# §78: nenhum método de obra é chamado — a letra M decide.
	await _press_mine_key()
	_mine = _construction.mine()
	_check(_mine != null, "§79 M lançou o canteiro da Mina")
	if _mine == null:
		return
	_selection.clear_selection()
	await _click_select(loaded[0])
	await _shift_click_select(loaded[1])
	await _right_click(_mine.global_position)
	_check(loaded[0].is_building() and loaded[1].is_building(),
			"§79 os dois Workers caminharam para a obra por ordem real")
	_set_speed(2.0)
	var built := await _wait_until(func() -> bool: return _mine.is_completed(), 40.0)
	_set_speed(1.0)
	_check(built, "§79 a obra cooperativa concluiu a Mina")
	var produced := _stockpile.get_amount(ORE)
	_check(_mine_clock() < MINE_INTERVAL, "§79/§21 nada foi produzido de graça")
	_set_speed(SPEED)
	# §79 mede o ciclo, não a espera: nove segundos de mundo e nada, o décimo segundo e X+1.
	await _world(MINE_INTERVAL - 1.0)
	_check(_stockpile.get_amount(ORE) == produced,
			"§79/§38 antes do intervalo o saldo ainda é X=%d, obtido %d"
					% [produced, _stockpile.get_amount(ORE)])
	var plus_one := await _wait_for_iron(produced + MINE_AMOUNT, 3.0)
	_check(plus_one and _stockpile.get_amount(ORE) == produced + MINE_AMOUNT,
			"§79 10 s depois o saldo é X+1, obtido %d contra X=%d"
					% [_stockpile.get_amount(ORE), produced])
	await _world(MINE_INTERVAL)
	_check(_stockpile.get_amount(ORE) == produced + 2 * MINE_AMOUNT,
			"§79 aos 20 s o saldo é X+2, obtido %d" % _stockpile.get_amount(ORE))
	_check(_pile_count() == 0, "§79/§24 o caminho todo sem nenhum monte")
	_set_speed(1.0)
	_measurements["e2e_x"] = produced
	_measurements["e2e_x_plus_2"] = _stockpile.get_amount(ORE)


# ============================================== Bloco 3 — a Mina no arquivo (schema V2)


## §97/§98/§99/§50/§51/§63/§65: a obra incompleta volta incompleta com o relógio em zero, e
## a obra pronta volta com o ciclo no meio — sem produzir durante a carga.
func _test_mine_save_incomplete_and_complete() -> void:
	# ---- §97: incompleta
	await _reset_campaign()
	await _open_mine_site(MINE_COST)
	_mine.state.apply_work(MINE_WORK - 3.0)
	await _advance(0.05)
	_use_path(INCOMPLETE_PATH)
	_check(_save.save_campaign(), "§97 save da Mina incompleta")
	var record := _mine_record_from_file(INCOMPLETE_PATH)
	_check(bool(record[CampaignSnapshot.KEY_EXISTS]), "§48 constructions.mine existe=true")
	_check(String(record["mine_id"]) == MINE_ID, "§48 o id gravado é mine_001, obtido %s"
			% [record["mine_id"]])
	_check(_close(float(record[CampaignSnapshot.KEY_REMAINING_WORK]), 3.0),
			"§97 remaining_work salvo 3.0, obtido %s" % [record[CampaignSnapshot.KEY_REMAINING_WORK]])
	_check(_close(float(record[CampaignSnapshot.KEY_PRODUCTION_ELAPSED]), 0.0),
			"§50/§11 obra incompleta grava relógio zero, obtido %s"
					% [record[CampaignSnapshot.KEY_PRODUCTION_ELAPSED]])
	_check(CampaignSnapshot.decode_position(record[CampaignSnapshot.KEY_POSITION])
			.is_equal_approx(MINE_BUILD_POINT), "§48 a posição salva é a do canteiro")

	await _reset_campaign()
	_check(_construction.mine() == null, "§65 a campanha de origem não tem Mina depois do reset")
	_use_path(INCOMPLETE_PATH)
	_mine_built_events = 0
	_mine_completed_events = 0
	_check(_save.load_campaign(), "§97 load da Mina incompleta")
	_mine = _construction.mine()
	_check(_mine != null, "§65/§63 o canteiro voltou montado")
	if _mine != null:
		_check(_close(_mine.state.remaining_work, 3.0),
				"§97 o mesmo trabalho restante, obtido %f" % _mine.state.remaining_work)
		_check(_close(_mine_clock(), 0.0), "§97/§50 o relógio continua zero")
		_check(not _mine.is_processing(), "§65/§20 incompleta não roda processo depois do load")
	_check(_mine_built_events == 1, "§63 mine_built uma vez pela rota de carga, %d"
			% _mine_built_events)
	_check(_mine_completed_events == 0, "§63 nenhuma conclusão falsa no load, %d"
			% _mine_completed_events)
	_check(_stockpile.get_amount(ORE) == 0,
			"§63/§48 a carga não cobra o custo nem produz, obtido %d"
					% _stockpile.get_amount(ORE))

	# ---- §98/§99: completa, com o ciclo no meio
	_mine.state.apply_work(3.0)
	await _advance(0.05)
	_set_speed(SPEED)
	await _world(6.2)
	_set_speed(1.0)
	var elapsed := _mine_clock()
	_check(elapsed > 5.5 and elapsed < MINE_INTERVAL,
			"§98 o relógio pegou %f s de ciclo" % elapsed)
	_use_path(COMPLETE_PATH)
	var iron_before := _stockpile.get_amount(ORE)
	_check(_save.save_campaign(), "§98 save da Mina operacional")
	var complete := _mine_record_from_file(COMPLETE_PATH)
	_check(_close(float(complete[CampaignSnapshot.KEY_REMAINING_WORK]), 0.0),
			"§51 obra concluída grava remaining_work 0")
	_check(_close(float(complete[CampaignSnapshot.KEY_PRODUCTION_ELAPSED]), elapsed, 0.1),
			"§49/§51 production_elapsed salvo %s contra %f"
					% [complete[CampaignSnapshot.KEY_PRODUCTION_ELAPSED], elapsed])
	await _reset_campaign()
	_use_path(COMPLETE_PATH)
	_mine_built_events = 0
	_mine_completed_events = 0
	_check(_save.load_campaign(), "§98 load da Mina operacional")
	_mine = _construction.mine()
	_check(_mine != null and _mine.is_completed(), "§98 a Mina voltou concluída")
	_check(_mine.is_processing(), "§64/§20 a Mina restaurada volta produzindo")
	var restored := _mine_clock()
	_check(_close(restored, elapsed, 0.15),
			"§98/§49 o ciclo voltou no número salvo, %f contra %f" % [restored, elapsed])
	_check(_stockpile.get_amount(ORE) == iron_before,
			"§63/§52 nenhum minério do passado — sem offline progress, obtido %d"
					% _stockpile.get_amount(ORE))
	_check(_mine_completed_events == 0, "§64 mine_completed não é reemitido pela carga")
	# §99: falta só o resto do ciclo para o próximo minério.
	_set_speed(SPEED)
	var remaining := MINE_INTERVAL - restored
	await _world(maxf(remaining - 0.3, 0.0))
	_check(_stockpile.get_amount(ORE) == iron_before,
			"§99 antes do resto do ciclo nada chegou, faltavam %f s" % remaining)
	var next := await _wait_for_iron(iron_before + MINE_AMOUNT, 4.0)
	_check(next and _stockpile.get_amount(ORE) == iron_before + MINE_AMOUNT,
			"§99/§67 o ciclo retoma do número salvo")
	_set_speed(1.0)
	_measurements["elapsed_antes_do_load"] = elapsed
	_measurements["elapsed_depois_do_load"] = restored


## §74/§105/§66/§67/§104: o roundtrip não move nada, e cinco cargas do mesmo arquivo não
## criam segunda Mina nem multiplicam produção.
func _test_roundtrip_and_repeated_loads() -> void:
	await _reset_campaign()
	await _open_mine_site(MINE_COST + 4)
	_mine.state.apply_work(MINE_WORK)
	await _advance(0.05)
	_set_speed(SPEED)
	await _world(4.0)
	_set_speed(1.0)
	_use_path(ROUNDTRIP_PATH)
	# Sem frame entre as três operações: o que se compara é o arquivo, não o mundo.
	var snapshot_a := _normalize(_save.snapshot_campaign())
	_check(_save.save_campaign(), "§74 save A da Mina em ciclo")
	_check(_save.load_campaign(), "§74 load")
	_check(_save.save_campaign(), "§74 save B")
	var snapshot_b := _normalize(_save.snapshot_campaign())
	_check(snapshot_a == snapshot_b, "§74/§105 campaign A == campaign B")
	var written := _document_from_file(ROUNDTRIP_PATH)
	_check(int(written[CampaignSnapshot.ROOT_VERSION]) == CampaignSnapshot.SAVE_VERSION,
			"§74/§45 o roundtrip continua V2, obtido %s"
					% [written[CampaignSnapshot.ROOT_VERSION]])

	_use_path(REPEAT_PATH)
	_check(_save.save_campaign(), "§104 save da carga repetida")
	var before := _normalize(_save.snapshot_campaign())
	# A obra montada tem três ouvintes do `construction_completed`: a troca de visual da base,
	# o `_sync_production` do MineRuntime e o `_on_mine_completed` do controller. O que §66 proíbe
	# é o quarto — o acumulador que uma recarga com `connect()` a mais produziria.
	var listeners := _connections_of(_mine.state.construction_completed)
	_check(listeners == 3, "§66 a Mina montada tem três ouvintes, obtido %d" % listeners)
	for attempt in range(1, 6):
		_check(_save.load_campaign(), "§104 carga %d devolve true" % attempt)
	_check(_mine_count() == 1, "§66/§104 cinco cargas, uma Mina, obtido %d" % _mine_count())
	_check(_normalize(_save.snapshot_campaign()) == before,
			"§66 o snapshot não deriva com as cargas")
	_check(_connections_of(_mine.state.construction_completed) == listeners,
			"§66 carga repetida não acumulou ouvintes, obtido %d"
					% _connections_of(_mine.state.construction_completed))
	var iron := _stockpile.get_amount(ORE)
	_set_speed(SPEED)
	await _world(MINE_INTERVAL + 0.5)
	_set_speed(1.0)
	_check(_stockpile.get_amount(ORE) == iron + MINE_AMOUNT,
			"§67/§104 dez segundos depois de cinco cargas = um minério, obtido +%d"
					% (_stockpile.get_amount(ORE) - iron))


## §100/§101/§102/§72/§73/§60: o arquivo V1 migra e, na campanha migrada, a Mina é
## simplesmente a obra que ainda não foi feita. A prova byte a byte do fixture congelado
## está em test_save_load.gd (§72/§73); aqui importa a consequência econômica da migração.
func _test_v1_migration_opens_the_mine() -> void:
	await _reset_campaign()
	_give_iron(MINE_COST)
	await _reach_level_two_for_real()
	_check(_core_state.level == MINE_LEVEL, "§100 setup: campanha Nv.2 com 6 minérios")
	var campaign := _save.snapshot_campaign()
	var constructions: Dictionary = campaign[CampaignSnapshot.SECTION_CONSTRUCTIONS]
	_check(constructions.has(CampaignSnapshot.SECTION_MINE), "§48 o snapshot V2 traz a Mina")
	constructions.erase(CampaignSnapshot.SECTION_MINE)
	_check(CampaignSnapshot.validate_v1(campaign).is_empty(),
			"§60 a mesma campanha sem a Mina é um V1 válido, motivo %s"
					% [CampaignSnapshot.validate_v1(campaign)])
	_check(not CampaignSnapshot.validate_v2(campaign).is_empty(),
			"§60/§48 como V2 a mesma campanha é recusada: %s"
					% [CampaignSnapshot.validate_v2(campaign)])
	var document := {
		CampaignSnapshot.ROOT_FORMAT: CampaignSnapshot.SAVE_FORMAT,
		CampaignSnapshot.ROOT_VERSION: CampaignSnapshot.SAVE_VERSION_V1,
		CampaignSnapshot.ROOT_METADATA: {"saved_at_unix": 1759172340, "probe": "suíte"},
		CampaignSnapshot.ROOT_CAMPAIGN: campaign,
	}
	_check(_write_text(V1_PATH, CampaignSnapshot.to_text(document)), "§72 o V1 foi escrito")
	_use_path(V1_PATH)
	_check(_save.load_campaign(), "§100/§53 o V1 carrega pela migração")
	_check(_construction.mine() == null, "§100/§48 a migração não inventou Mina")
	_check(_core_state.level == MINE_LEVEL, "§100/§54 o Nv.2 do arquivo chegou")
	_check(_stockpile.get_amount(ORE) == MINE_COST,
			"§100/§54 o saldo antigo está intacto, obtido %d" % _stockpile.get_amount(ORE))
	await _press_mine_key()
	_mine = _construction.mine()
	_check(_mine != null, "§100 a campanha migrada pode construir a Mina")
	# §101: o save que vem depois já é V2, e diz a verdade sobre a Mina que existe agora.
	_use_path(PRIMARY_PATH)
	_check(_save.save_campaign(), "§101 re-save da campanha migrada")
	var resaved := _document_from_file(PRIMARY_PATH)
	_check(int(resaved[CampaignSnapshot.ROOT_VERSION]) == CampaignSnapshot.SAVE_VERSION,
			"§101/§56 o re-save publica V2, obtido %s" % [resaved[CampaignSnapshot.ROOT_VERSION]])
	var saved_mine: Dictionary = (resaved[CampaignSnapshot.ROOT_CAMPAIGN] as Dictionary)[
			CampaignSnapshot.SECTION_CONSTRUCTIONS][CampaignSnapshot.SECTION_MINE]
	_check(bool(saved_mine[CampaignSnapshot.KEY_EXISTS]),
			"§101 a Mina real aparece no V2, obtido %s" % [saved_mine])
	_check(_close(float(saved_mine[CampaignSnapshot.KEY_PRODUCTION_ELAPSED]), 0.0),
			"§50/§101 canteiro grava relógio zero, obtido %s"
					% [saved_mine[CampaignSnapshot.KEY_PRODUCTION_ELAPSED]])

	# §102/§69: o primário está podre e o backup é V1 — a rota de fallback migra também.
	await _reset_campaign()
	_give_iron(MINE_COST)
	await _reach_level_two_for_real()
	var v1_campaign := _save.snapshot_campaign()
	(v1_campaign[CampaignSnapshot.SECTION_CONSTRUCTIONS] as Dictionary) \
			.erase(CampaignSnapshot.SECTION_MINE)
	var v1_text := CampaignSnapshot.to_text({
		CampaignSnapshot.ROOT_FORMAT: CampaignSnapshot.SAVE_FORMAT,
		CampaignSnapshot.ROOT_VERSION: CampaignSnapshot.SAVE_VERSION_V1,
		CampaignSnapshot.ROOT_METADATA: {"saved_at_unix": 1759172340, "probe": "backup"},
		CampaignSnapshot.ROOT_CAMPAIGN: v1_campaign,
	})
	_use_path(V1_BACKUP_PATH)
	# §102/T18: o backup é derivado do primário por `get_basename() + ".bak"` — o arquivo irmão
	# de `v1_backup.json` é `v1_backup.bak`, não `v1_backup.json.bak`.
	var backup_path := V1_BACKUP_PATH.get_basename() + ".bak"
	_check(_write_text(backup_path, v1_text), "§102 o backup V1 foi escrito")
	_check(_write_text(V1_BACKUP_PATH, "{\"format\": \"abyss_lord_cam"),
			"§102 o primário foi corrompido de propósito")
	_load_events.clear()
	_failed_events.clear()
	_check(_save.load_campaign(), "§102/§69 o load pelo backup V1 migra e carrega")
	_check(_load_events == [backup_path],
			"§102/§114 o fallback anunciou o backup, obtido %s" % [_load_events])
	_check(_construction.mine() == null, "§102 a campanha do backup não tem Mina")
	_check(_core_state.level == MINE_LEVEL, "§102 o Nv.2 do backup chegou, %d"
			% _core_state.level)
	await _reset_campaign()


## §57/§103/§105: versão que o contrato não conhece é recusada antes de tocar em qualquer
## número, inclusive quando é o número do futuro.
func _test_future_version_touches_nothing() -> void:
	await _reset_campaign()
	await _open_mine_site(MINE_COST + 4)
	var world_before := _snapshot_text()
	var document := _document_from_file(REPEAT_PATH)
	document[CampaignSnapshot.ROOT_VERSION] = 999
	_use_path(FUTURE_PATH)
	_check(_write_text(FUTURE_PATH, CampaignSnapshot.to_text(document)),
			"§103 o arquivo do futuro foi escrito")
	_check(CampaignSnapshot.validate_document(document)
			.contains("save_version não suportado"),
			"§57 o contrato recusa 999 com motivo explícito")
	_failed_events.clear()
	_check(not _save.load_campaign(), "§57/§103 load de save_version = 999 é recusado")
	_check(not _failed_events.is_empty(), "§105 a recusa anunciou o motivo, %s"
			% [_failed_events])
	_check(_snapshot_text() == world_before, "§103/§105 o mundo intacto diante do futuro")
	_check(_mine_count() == 1, "§103 a Mina da partida não foi tocada, obtido %d"
			% _mine_count())
	await _reset_campaign()


# ==================================================================== helpers de cenário


## §78: a rota real até o Nv.2 — invasão vencida, Cristal conquistado, evolução paga.
func _reach_level_two_for_real() -> void:
	_give_essence(ESSENCE_GRANT)
	_check(_invasion.start_invasion(), "§78 setup: a invasão foi largada")
	await _advance(0.05)
	for enemy in _alive_enemies():
		enemy.receive_damage(9999.0)
	await _advance(0.05)
	_check(_invasion.invasion_state() == InvasionController.InvasionState.VICTORY,
			"§78 setup: VICTORY")
	_check(_crystal.amount == 1, "§78 setup: a chave chegou, obtido %d" % _crystal.amount)
	_check(_evolution.try_evolve(), "§78 setup: o Núcleo evoluiu para o Nv.2")
	await _advance(0.05)


## §78: nas medições isoladas o Nv.2 é aplicado direto no Runtime. Nada aqui simula a
## progressão — só abre a porta que §28/§29 descrevem, para medir a obra em si.
func _unlock_level_two(iron_amount: int) -> void:
	_core.evolve_to(_core_lv2)
	_give_iron(iron_amount)
	_mine_built_events = 0
	_mine_completed_events = 0
	await _advance(0.05)


func _open_mine_site(iron_amount: int) -> void:
	await _unlock_level_two(iron_amount)
	_check(_construction.build_mine(), "setup: Mina lançada com %d minérios" % iron_amount)
	_mine = _construction.mine()
	await _advance(0.05)


func _mine_clock() -> float:
	return (_mine.state as MineState).production_elapsed


func _set_speed(value: float) -> void:
	_speed = value
	Engine.time_scale = value


func _world(seconds: float) -> void:
	await _advance(seconds / _speed)


func _measure_work_rate() -> float:
	var before := _mine.state.remaining_work
	await _advance(1.0)
	return before - _mine.state.remaining_work


func _reset_campaign() -> void:
	_use_path(FRESH_PATH)
	_check(_save.load_campaign(), "setup: a carga de isolamento devolve a campanha do boot")
	_mine = _construction.mine()
	await _advance(0.1)


func _give_iron(amount: int) -> void:
	_stockpile.add_resource(_iron, amount)


func _give_essence(amount: float) -> void:
	_core_state.add_essence(amount)


func _use_path(path: String) -> void:
	_save.configure_save_path(path)


func _on_mine_built(_mine: MineRuntime) -> void:
	_mine_built_events += 1


func _on_mine_completed(_mine: MineRuntime) -> void:
	_mine_completed_events += 1


func _on_load_succeeded(path: String) -> void:
	_load_events.append(path)


func _on_operation_failed(operation: String, reason: String) -> void:
	_failed_events.append("%s:%s" % [operation, reason])


func _workers() -> Array[WorkerRuntime]:
	var found: Array[WorkerRuntime] = []
	for child in _dungeon.get_children():
		var worker := child as WorkerRuntime
		if worker != null and not worker.is_queued_for_deletion():
			found.append(worker)
	return found


func _second_worker() -> WorkerRuntime:
	for worker in _workers():
		if worker != _worker:
			return worker
	return null


func _mine_count() -> int:
	var total := 0
	for child in _dungeon.get_children():
		if child is MineRuntime:
			total += 1
	return total


func _pile_count() -> int:
	var total := 0
	for child in _dungeon.get_children():
		var pile := child as ResourcePileRuntime
		if pile != null and not pile.is_queued_for_deletion():
			total += 1
	return total


func _rocks() -> Array[RockRuntime]:
	var found: Array[RockRuntime] = []
	for child in _dungeon.get_children():
		var rock := child as RockRuntime
		if rock != null and not rock.is_queued_for_deletion():
			found.append(rock)
	return found


func _rock_progress() -> String:
	var progress := {}
	for rock in _rocks():
		progress[rock.rock_id] = rock.state.remaining_work
	return _normalize(progress)


func _alive_enemies() -> Array[EnemyRuntime]:
	var found: Array[EnemyRuntime] = []
	for child in _dungeon.get_children():
		var enemy := child as EnemyRuntime
		if enemy != null and not enemy.is_queued_for_deletion() and not enemy.state.is_dead():
			found.append(enemy)
	return found


func _snapshot_text() -> String:
	return _normalize(_save.snapshot_campaign())


# ================================================================== input e mundo reais


## §75: a letra M entra pelo caminho do sistema operacional — InputMap casa a ação, o estado
## polled é atualizado e `_unhandled_input` decide a jogada.
func _press_mine_key() -> void:
	var pressed := InputEventKey.new()
	pressed.physical_keycode = KEY_M
	pressed.pressed = true
	Input.parse_input_event(pressed)
	var released := InputEventKey.new()
	released.physical_keycode = KEY_M
	released.pressed = false
	Input.parse_input_event(released)
	await _advance(0.1)


func _click_select(worker: WorkerRuntime) -> void:
	await _press_release(MOUSE_BUTTON_LEFT, _screen(worker.global_position))


func _shift_click_select(worker: WorkerRuntime) -> void:
	Input.action_press(&"selection_additive")
	await _press_release(MOUSE_BUTTON_LEFT, _screen(worker.global_position))
	Input.action_release(&"selection_additive")


func _right_click(world_position: Vector3) -> void:
	await _press_release(MOUSE_BUTTON_RIGHT, _screen(world_position))


func _press_release(button: int, screen_position: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = button
	press.pressed = true
	press.position = screen_position
	press.global_position = screen_position
	root.push_input(press)
	var release := InputEventMouseButton.new()
	release.button_index = button
	release.pressed = false
	release.position = screen_position
	release.global_position = screen_position
	root.push_input(release)
	await _advance(0.05)


## §95/§96: o tempo medido é o de trabalho puro — os Workers são estacionados ao lado do
## canteiro, cada um em um ponto próprio, exatamente como test_multi_selection.gd faz com o
## Ninho. A viagem pertence ao E2E. Sobrepostos, os dois bodies ocupariam o mesmo pixel e o
## clique alternaria a seleção em vez de somá-la.
func _park_near_mine(worker: WorkerRuntime, z_offset: float) -> void:
	var parked := _mine.global_position \
			+ Vector3(WORKER_BUILD_GAP, 0.0, z_offset)
	worker.velocity = Vector3.ZERO
	worker.global_position = parked
	worker.move_to(parked)
	await _advance(0.1)


func _screen(world_position: Vector3) -> Vector2:
	return _camera.unproject_position(world_position)


func _ray_hit(screen_position: Vector2, mask: int) -> Dictionary:
	var origin := _camera.project_ray_origin(screen_position)
	var direction := _camera.project_ray_normal(screen_position)
	var space := _scene.get_viewport().world_3d.direct_space_state
	return space.intersect_ray(
			PhysicsRayQueryParameters3D.create(origin, origin + direction * 1000.0, mask))


func _physics_nodes_under(node: Node) -> Array[String]:
	var found: Array[String] = []
	for child in node.get_children():
		if child.get_class().contains("Collision") or child is PhysicsBody3D:
			found.append(String(child.name))
		found.append_array(_physics_nodes_under(child))
	return found


func _planar_gap(from: Vector3, to: Vector3) -> float:
	var offset := to - from
	offset.y = 0.0
	return offset.length()


func _segment_gap(from: Vector3, to: Vector3) -> float:
	var closest := INF
	for sample in 25:
		var point := from.lerp(to, float(sample) / 24.0)
		closest = minf(closest, _planar_gap(point, MINE_BUILD_POINT))
	return closest


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


func _wait_for_iron(target: int, max_seconds: float) -> bool:
	return await _wait_until(
			func() -> bool: return _stockpile.get_amount(ORE) >= target, max_seconds)


func _text_of(root_node: Node, label_name: String) -> String:
	var label := root_node.find_child(label_name, true, false) as Label
	if label == null:
		return "<ausente>"
	return label.text


# ============================================================ arquivo, fonte e medições


func _mine_record_from_file(path: String) -> Dictionary:
	var document := _document_from_file(path)
	var constructions: Dictionary = document[CampaignSnapshot.ROOT_CAMPAIGN][
			CampaignSnapshot.SECTION_CONSTRUCTIONS]
	return constructions[CampaignSnapshot.SECTION_MINE]


func _document_from_file(path: String) -> Dictionary:
	var parsed: Variant = CampaignSnapshot.parse_document(_read_text(path))
	return {} if parsed == null else parsed as Dictionary


func _source(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func _code_of(path: String) -> String:
	var kept: Array[String] = []
	for line in _source(path).split("\n"):
		var comment_at := line.find("#")
		kept.append(line.substr(0, comment_at) if comment_at >= 0 else line)
	return "\n".join(kept)


func _count_occurrences(text: String, needle: String) -> int:
	var count := 0
	var index := text.find(needle)
	while index != -1:
		count += 1
		index = text.find(needle, index + needle.length())
	return count


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


## §74/§105: comparação estável — Dictionary por chave ordenada, Array na ordem gravada.
func _normalize(value: Variant) -> String:
	if value is Dictionary:
		var keys: Array = []
		for key in value:
			keys.append(key)
		keys.sort()
		var encoded: Array[String] = []
		for key in keys:
			encoded.append("%s=%s" % [key, _normalize((value as Dictionary)[key])])
		return "{" + ",".join(encoded) + "}"
	if value is Array:
		var items: Array[String] = []
		for item in value:
			items.append(_normalize(item))
		return "[" + ",".join(items) + "]"
	return str(value)


func _connections_of(signal_source: Signal) -> int:
	return signal_source.get_connections().size()


func _close(a: float, b: float, tolerance := 0.001) -> bool:
	return absf(a - b) <= tolerance


# ============================================================================== estrutura


func _boot_scene() -> void:
	_scene = MAIN_SCENE.instantiate()
	root.add_child(_scene)
	await _advance(0.2)
	_camera = _scene.get_node("World/CameraRig/Camera3D") as Camera3D
	_dungeon = _scene.get_node("World/DungeonRoot") as Node3D
	_floor = _scene.get_node("World/Environment/TestFloorBody") as StaticBody3D
	_selection = _scene.get_node("Systems/SelectionController") as SelectionController
	_construction = _scene.get_node("Systems/ConstructionController") as ConstructionController
	_invocation = _scene.get_node(
			"Systems/WorkerInvocationController") as WorkerInvocationController
	_invasion = _scene.get_node("Systems/InvasionController") as InvasionController
	_evolution = _scene.get_node("Systems/CoreEvolutionController") as CoreEvolutionController
	_save = _scene.get_node("Systems/SaveGameController") as SaveGameController
	_core = _scene.get_node("World/DungeonRoot/MainCore") as CoreRuntime
	_worker = _scene.get_node("World/DungeonRoot/Worker001") as WorkerRuntime
	_mine_build_point = _scene.get_node("World/DungeonRoot/MineBuildPoint") as Marker3D
	var deposit := _scene.get_node("World/DungeonRoot/Deposit001") as ResourceDepositRuntime
	_stockpile = deposit.stockpile
	_core_state = _core.core_state()
	_crystal = _evolution.abyssal_crystal_state()
	_mine_hud = _scene.get_node("UI/ConstructionDebugPanel")
	_ore_hud = _scene.get_node("UI/ResourceDebugPanel")
	_iron = load(IRON_ORE_PATH) as ResourceDefinition
	_core_lv2 = load(CORE_LV2_PATH) as CoreDefinition
	_player_before = _presence(PLAYER_PRIMARY)
	_player_backup_before = _presence(PLAYER_BACKUP)
	_construction.mine_built.connect(_on_mine_built)
	_construction.mine_completed.connect(_on_mine_completed)
	_save.load_succeeded.connect(_on_load_succeeded)
	_save.operation_failed.connect(_on_operation_failed)
	Engine.set_physics_ticks_per_second(TICKS)
	_use_path(FRESH_PATH)
	_check(_save.save_campaign(), "setup: a campanha do boot virou o pristine da suíte")


func _free_scene() -> void:
	_mine = null
	_save = null
	_stockpile = null
	_core_state = null
	_crystal = null
	_worker = null
	_core = null
	_engine_reset()
	if _scene != null and is_instance_valid(_scene):
		_scene.queue_free()
	_scene = null
	await _advance(0.2)


func _engine_reset() -> void:
	Engine.time_scale = 1.0
	Engine.set_physics_ticks_per_second(60)


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func _write_text(path: String, text: String) -> bool:
	var directory := DirAccess.open("user://")
	if directory != null:
		directory.make_dir_recursive(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.flush()
	file.close()
	return true


func _remove_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _presence(path: String) -> String:
	if not FileAccess.file_exists(path):
		return "ausente"
	var text := _read_text(path)
	return "presente:%d:%d" % [text.length(), text.hash()]


## §107/T18: o que a suíte criou em user://tests/ desaparece, e o save do jogador não é
## caminho de teste. A varredura é do diretório inteiro justamente porque backup e
## temporário têm nome derivado, e um resíduo de outra rodada não pode sobreviver aqui.
func _cleanup_test_files() -> void:
	for path in TEST_PATHS:
		_remove_file(path)
		_remove_file(path.get_basename() + ".bak")
		_remove_file(path.get_basename() + ".tmp")
		_remove_file(path + ".bak")
		_remove_file(path + ".tmp")
	var directory := DirAccess.open(TEST_DIR)
	if directory != null:
		directory.list_dir_begin()
		var entry := directory.get_next()
		while not entry.is_empty():
			if not directory.current_is_dir():
				directory.remove(entry)
			entry = directory.get_next()
		directory.list_dir_end()
	var tests_root := DirAccess.open("user://tests")
	if tests_root != null:
		tests_root.remove(TEST_DIR.get_file())
	var survivors: Array[String] = []
	for path in TEST_PATHS:
		if FileAccess.file_exists(path):
			survivors.append(path)
	_check(survivors.is_empty(),
			"§107 nenhum arquivo de teste sobreviveu, restaram %s" % [survivors])
	_check(DirAccess.open(TEST_DIR) == null, "§107 o diretório da suíte não fica para trás")


func _test_player_save_untouched() -> void:
	_check(_presence(PLAYER_PRIMARY) == _player_before
			and _presence(PLAYER_BACKUP) == _player_backup_before,
			"§107 o save real do jogador não foi tocado: %s → %s"
					% [_player_before, _presence(PLAYER_PRIMARY)])
	for path in TEST_PATHS:
		_check(path.begins_with("user://tests/"),
				"§107 todo caminho de teste está isolado, obtido %s" % path)
	_check(_save == null, "§108 a suíte não guarda referência a nenhum Node já libertado")


func _print_measurements() -> void:
	print("[INFO] medições da Mina Abissal: %s" % [_measurements])


func _check(condition: bool, label: String) -> void:
	_asserts += 1
	if condition:
		print("[PASS] %s" % label)
	else:
		_failures += 1
		print("[FAIL] %s" % label)


func _finish() -> void:
	print("---- abyssal mine tests finished: %d asserts, %d failure(s) ----"
			% [_asserts, _failures])
	quit(1 if _failures > 0 else 0)
