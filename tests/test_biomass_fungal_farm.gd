extends SceneTree

# Tarefa 21 — Biomassa e a primeira cadeia de produção orgânica do Núcleo Nv.2.
#
# A pergunta desta suíte não é "existe um objeto chamado Fazenda Fúngica". É a do PRINCÍPIO
# da tarefa: depois de aprender a extrair matéria mineral do solo (Tarefa 20), o Núcleo
# aprende a CONVERTER a própria energia em matéria viva. Por isso cada cenário aqui mede
# saldo, relógio, Essência e mundo — nunca aparência.
#
# Quatro blocos, nesta ordem:
#   1) contrato e guarda de fonte (§96/§97/§102–§110) — a Definition e o State existem
#      sozinhos, sem cena; a aritmética do relógio é exata em 30 Hz e em 120 Hz; a produção
#      é limitada por ciclos pagáveis; e o que a tarefa deliberadamente NÃO construiu
#      (segundo estoque, monte de Biomassa, Worker003, consumidor, manutenção) fica provado
#      por varredura de arquivos;
#   2) a obra no mundo (§25/§26/§34/§62–§66/§111–§113) — FungalFarmBuildPoint validado no
#      Ground, a camada Construction reconhecida pelo SelectionController sem branch de tipo,
#      a tecla G real, as cinco portas na ordem certa (Fazenda → Núcleo → Mina → Mina pronta
#      → Ferro), o custo atômico e uma única Fazenda;
#   3) produção por energia (§18–§24/§44–§49/§68–§71/§114–§118) — o relógio só liga depois da
#      obra, o ciclo só fecha com Essência, a Essência é consumida, a Biomassa cai no
#      ResourceStockpileState genérico, dois ciclos pagam dois custos, e sem Essência o
#      relógio satura em um ciclo (sem backlog);
#   4) persistência V3 (§50–§61/§119/§120) — a Fazenda salva e volta incompleta ou com o
#      relógio no meio do ciclo, load repetido não duplica nem multiplica, e a corrente
#      V1→V2→V3 abre justamente a rota da Fazenda.
#
# §78: as medições isoladas usam harness controlado (Nv.2 aplicado direto no Runtime), e a
# integração real existe — ela é `_test_level_two_real_input_and_cost` e o E2E, que chegam
# ao Nv.2 pelo caminho canônico: invasão, vitória, Cristal, evolução.
#
# Todo arquivo mora em `user://tests/fungal_farm/` e desaparece no fim (§121/T18). A cena
# volta ao pristine gravado no boot por `load_campaign()`, que é também a primeira prova de
# que a carga restaura.

const MAIN_SCENE := preload("res://game/GameMain.tscn")

const FARM_DEFINITION_PATH := "res://data/rooms/abyss_fungal_farm.tres"
const FARM_SCENE_PATH := "res://world/dungeon/rooms/fungal_farm/FungalFarmRuntime.tscn"
const FARM_DEFINITION_SOURCE := "res://core/definitions/fungal_farm_definition.gd"
const FARM_STATE_SOURCE := "res://core/state/fungal_farm_state.gd"
const FARM_RUNTIME_SOURCE := "res://world/dungeon/rooms/fungal_farm/fungal_farm_runtime.gd"
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
const BIOMASS_PATH := "res://data/resources/biomass.tres"
const CORE_LV2_PATH := "res://data/core/core_level_2.tres"
const MINE_DEFINITION_PATH := "res://data/rooms/abyss_mine.tres"
const NEST_SCENE_PATH := "res://world/dungeon/rooms/nest/NestRuntime.tscn"
const BARRACKS_SCENE_PATH := "res://world/dungeon/rooms/barracks/BarracksRuntime.tscn"
const MINE_SCENE_PATH := "res://world/dungeon/rooms/mine/MineRuntime.tscn"

const FARM_DIR := "res://world/dungeon/rooms/fungal_farm"
const MINE_DIR := "res://world/dungeon/rooms/mine"
const ROOMS_DIR := "res://data/rooms"
const RESOURCES_DIR := "res://data/resources"
const PERSISTENCE_DIR := "res://systems/persistence"
const CONSTRUCTION_SYSTEM_DIR := "res://systems/construction"
const CORE_STATE_DIR := "res://core/state"
const UI_HUD_DIR := "res://ui/hud"
const V1_DOC := "res://docs/SAVE_SCHEMA_V1.md"
const V2_DOC := "res://docs/SAVE_SCHEMA_V2.md"
const V3_DOC := "res://docs/SAVE_SCHEMA_V3.md"

## §121/T18: caminho de teste, nunca o save do jogador.
const TEST_DIR := "user://tests/fungal_farm"
const FRESH_PATH := "user://tests/fungal_farm/pristine.json"
const PRIMARY_PATH := "user://tests/fungal_farm/campaign.json"
const INCOMPLETE_PATH := "user://tests/fungal_farm/incompleta.json"
const COMPLETE_PATH := "user://tests/fungal_farm/concluida.json"
const STARVED_PATH := "user://tests/fungal_farm/faminta.json"
const ROUNDTRIP_PATH := "user://tests/fungal_farm/roundtrip.json"
const REPEAT_PATH := "user://tests/fungal_farm/repetida.json"
const V1_PATH := "user://tests/fungal_farm/v1.json"
const V2_PATH := "user://tests/fungal_farm/v2.json"
const FUTURE_PATH := "user://tests/fungal_farm/futura.json"
const E2E_PATH := "user://tests/fungal_farm/e2e.json"
const TEST_PATHS: Array[String] = [FRESH_PATH, PRIMARY_PATH, INCOMPLETE_PATH, COMPLETE_PATH,
		STARVED_PATH, ROUNDTRIP_PATH, REPEAT_PATH, V1_PATH, V2_PATH, FUTURE_PATH, E2E_PATH]

const PLAYER_PRIMARY := "user://campaign_save.json"
const PLAYER_BACKUP := "user://campaign_save.bak"

const ORE := &"iron_ore"
const BIOMASS := &"biomass"
const ORE_DISPLAY := "Minério de Ferro"
const BIOMASS_DISPLAY := "Biomassa"
const FARM_DISPLAY := "Fazenda Fúngica"

## §5: os números que a tarefa fixou. Vêm da Definition, e esta suíte confere o arquivo —
## por isso as constantes existem aqui também: um valor alterado sem teste precisa falhar.
const FARM_COST := 4
## T20/T21: o custo da Mina em Minério de Ferro é a primeira porta da progressão e não muda
## nesta tarefa; a suíte o repete aqui para compor setup (Mina + Fazenda) sem depender do
## literal espalhado pelo arquivo.
const MINE_COST := 6
const FARM_WORK := 6.0
const FARM_INTERVAL := 8.0
const FARM_AMOUNT := 1
const FARM_LEVEL := 2
const FARM_ID := "fungal_farm_001"
const FARM_TYPE_ID := &"fungal_farm"
const ESSENCE_PER_CYCLE := 4.0

## Os textos do painel (§36/§107), copiados da produção de propósito: se a linha sair do
## lugar, a suíte denuncia em vez de acompanhar. São literais porque `%` não é expressão
## constante em GDScript — e porque remontar o texto aqui seguiria o erro em vez de expô-lo.
const HUD_BLOCKED := "Fazenda Fúngica: bloqueada — requer Núcleo Nv.2"
const HUD_NO_MINE := "Fazenda Fúngica: bloqueada — requer Mina concluída"
const HUD_READY := "[G] Fazenda Fúngica — 4 Minério de Ferro: pronto para construir"
const HUD_BUILDING := "Fazenda Fúngica: em construção"
const HUD_OPERATIONAL := "Fazenda Fúngica: operacional — +1 Biomassa / 8 s por 4 Essência"
const HUD_INSUFFICIENT := "Fazenda Fúngica: recursos insuficientes"
## §96: a linha operacional muda de texto quando a Essência não cobre o ciclo. Sem essa
## segunda string o estado que a Tarefa 21 introduziu não teria evidência nenhuma.
const HUD_STARVING := "Fazenda Fúngica: operacional — +1 Biomassa / 8 s por 4 Essência (aguardando Essência)"

const GROUND_LAYER := 1
const UNIT_LAYER := 2
const DIGGABLE_LAYER := 4
const RESOURCE_LAYER := 8
const CONSTRUCTION_LAYER := 16
const CLICKABLE := GROUND_LAYER | UNIT_LAYER | DIGGABLE_LAYER | RESOURCE_LAYER | CONSTRUCTION_LAYER

## §25: o ponto da Fazenda é geometria de cena, conferido aqui e não no editor.
const FARM_BUILD_POINT := Vector3(10, 0, -9)
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
## interno de teste): a Fazenda é um ciclo de 8 s, e esperar 30 s reais por linha seria
## mentir para o CI. `_world(segundos)` entrega segundos de tempo de jogo.
const SPEED := 4.0
const ESSENCE_GRANT := 20.0
const SUMMON_COST := 10.0
const INVADER_COUNT := 2

## Os painéis que já existiam (§117/T20/T21: a Fazenda não ganhou HUD próprio).
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
var _biomass: ResourceDefinition
var _core_lv2: CoreDefinition
var _worker: WorkerRuntime
var _farm_build_point: Marker3D
var _farm: FungalFarmRuntime
var _farm_hud: Node
var _resource_hud: Node
var _mine_hud: Node

## Contadores de sinal: a única prova de "uma emissão" é o número de emissões.
var _farm_built_events := 0
var _farm_completed_events := 0
var _load_events: Array[String] = []
var _failed_events: Array[String] = []
var _player_before := ""
var _player_backup_before := ""


func _initialize() -> void:
	_run_all()


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > 1500000:
		_check(false, "timeout: a suíte da Fazenda Fúngica não terminou")
		_finish()
	return false


func _run_all() -> void:
	# Bloco 1 — contrato da Fazenda e o que a tarefa não construiu. Sem cena.
	_test_definition_contract()
	_test_state_clock()
	_test_state_clock_at_both_rates()
	_test_energy_gated_arithmetic()
	_test_scope_guards()

	# O resto precisa da árvore: InputMap, física, raycast, saldo e Essência de verdade.
	await _boot_scene()
	await _test_farm_build_point_and_scene()
	await _test_level_one_gate_with_real_key()
	await _test_farm_requires_completed_mine()
	await _test_level_two_real_input_and_cost()
	await _test_insufficient_iron()
	await _test_process_gating_and_completion()
	await _test_essence_powered_production()
	await _test_two_cycles_two_costs()
	await _test_starvation_saturates()
	await _test_production_is_delta_driven()
	await _test_parallel_economy_mine_and_farm()
	await _test_cooperative_construction()
	await _test_end_to_end_organic_economy()
	await _test_farm_save_incomplete_and_complete()
	await _test_farm_save_starved()
	await _test_roundtrip_and_repeated_loads()
	await _test_v2_migration_opens_the_farm()
	await _test_v1_migration_reaches_v3()
	await _test_future_version_touches_nothing()

	await _free_scene()
	_cleanup_test_files()
	_test_player_save_untouched()
	_print_measurements()
	_finish()


# ========================================= Bloco 1 — Definition, State e guardas de fonte


## §96/§5/§8: a Fazenda é uma ConstructionDefinition com relógio de energia, e os números do
## arquivo são os números da tarefa. O custo é ferro e o produto é a Biomassa nova — a
## Resource genérica, não um segundo estoque.
func _test_definition_contract() -> void:
	var farm := load(FARM_DEFINITION_PATH) as FungalFarmDefinition
	_check(farm != null, "§96 abyss_fungal_farm.tres é uma FungalFarmDefinition")
	if farm == null:
		return
	_check(farm is ConstructionDefinition, "§96 FungalFarmDefinition herda ConstructionDefinition")
	_check(farm.farm_type_id == FARM_TYPE_ID, "§96 farm_type_id == fungal_farm, obtido %s"
			% farm.farm_type_id)
	_check(farm.display_name == FARM_DISPLAY, "§96 display_name, obtido %s" % farm.display_name)
	_check(farm.required_core_level == FARM_LEVEL, "§96 required_core_level == 2, obtido %d"
			% farm.required_core_level)
	_check(farm.build_cost == FARM_COST, "§96 build_cost == 4, obtido %d" % farm.build_cost)
	_check(_close(farm.work_required, FARM_WORK), "§96 work_required == 6.0, obtido %f"
			% farm.work_required)
	_check(farm.production_amount == FARM_AMOUNT, "§96 production_amount == 1, obtido %d"
			% farm.production_amount)
	_check(_close(farm.production_interval, FARM_INTERVAL),
			"§96 production_interval == 8.0, obtido %f" % farm.production_interval)
	_check(_close(farm.essence_cost_per_cycle, ESSENCE_PER_CYCLE),
			"§96 essence_cost_per_cycle == 4.0, obtido %f" % farm.essence_cost_per_cycle)
	_check(farm.output_resource != null and farm.output_resource.resource_id == BIOMASS,
			"§96 output_resource == biomass")
	_check(farm.build_resource != null and farm.build_resource.resource_id == ORE,
			"§96 build_resource == iron_ore")
	_check(farm.build_resource == (load(IRON_ORE_PATH) as ResourceDefinition),
			"§96 o .tres referencia o minério canônico em vez de duplicá-lo")
	_check(farm.output_resource == (load(BIOMASS_PATH) as ResourceDefinition),
			"§96 a Biomassa é o biomass.tres canônico")
	_check(_files_in(RESOURCES_DIR, ".tres") == ["biomass.tres", "iron_ore.tres"],
			"§97/§102 exatamente duas Resources: minério e Biomassa, obtido %s"
					% [_files_in(RESOURCES_DIR, ".tres")])
	_check(_files_in(ROOMS_DIR, ".tres")
			== ["abyss_barracks.tres", "abyss_fungal_farm.tres", "abyss_mine.tres",
					"abyss_nest.tres"],
			"§97/§102 as quatro obras da campanha, nenhuma sala genérica, obtido %s"
					% [_files_in(ROOMS_DIR, ".tres")])
	# §8: a Definition própria da Fazenda declara o relógio, a porta de nível e a energia.
	var definition_code := _code_of(FARM_DEFINITION_SOURCE)
	for own_field in ["required_core_level", "output_resource", "production_amount",
			"production_interval", "essence_cost_per_cycle"]:
		_check(definition_code.contains(own_field),
				"§8 fungal_farm_definition.gd declara %s" % own_field)
	for inherited in ["build_cost", "work_required", "build_resource"]:
		_check(not definition_code.contains("var %s" % inherited),
				"§8/§115 %s continua herdado de ConstructionDefinition" % inherited)


## §98–§101/§11/§14–§17: o State é obra (regra da base) e relógio (regra própria). A
## aritmética é testada aqui, em segundos exatos, porque é ela que §24 jura ser independente
## de frame — e agora também de Essência.
func _test_state_clock() -> void:
	var farm := load(FARM_DEFINITION_PATH) as FungalFarmDefinition
	var state := FungalFarmState.new(farm, FARM_ID)
	_check(state is ConstructionState, "§98 FungalFarmState herda ConstructionState")
	_check(_close(state.remaining_work, FARM_WORK), "§98 nasce devendo o trabalho da Definition")
	_check(_close(state.production_elapsed, 0.0), "§98/§11 o relógio começa em zero")
	_check(state.farm_id == FARM_ID, "§100 farm_id é o instance_id da base, obtido %s"
			% state.farm_id)

	# §99/§15: canteiro não produz, e nem acumula tempo — mesmo com Essência de sobra.
	_check(state.advance_production(100.0, 99) == 0,
			"§99 inacabada entrega 0 mesmo com 100 s e Essência")
	_check(_close(state.production_elapsed, 0.0), "§99/§11 elapsed segue 0 enquanto é obra")
	# §14: delta inválido não move nada.
	state.apply_work(FARM_WORK)
	_check(state.is_completed(), "§98 a obra conclui pela regra da base")
	_check(state.advance_production(0.0, 5) == 0, "§14 delta zero não produz")
	_check(state.advance_production(-5.0, 5) == 0, "§14 delta negativo não produz")
	_check(_close(state.production_elapsed, 0.0), "§14 delta inválido não move o relógio")
	# §100/§12: o ciclo é exato — 7 s não pagam nada, o oitavo segundo paga um.
	_check(state.advance_production(7.0, 1) == 0, "§100 sete segundos não fecham ciclo, %f s"
			% state.production_elapsed)
	_check(_close(state.production_elapsed, 7.0), "§100/§12 os 7 s ficaram no relógio, %f"
			% state.production_elapsed)
	_check(state.advance_production(1.0, 1) == FARM_AMOUNT, "§100 o oitavo segundo produz 1")
	_check(_close(state.production_elapsed, 0.0),
			"§12/§100 o bloco inteiro é consumido, sobrou %f" % state.production_elapsed)
	# §17: o relógio satura em UM intervalo por avanço — um delta gigante não fecha 3 ciclos
	# de uma vez, porque acumular além de um intervalo prometeria produção que a energia não
	# pagou. Um único avanço fecha no máximo um ciclo.
	var saturated := state.advance_production(27.0, 9)
	_check(saturated == FARM_AMOUNT, "§17 27 s num único avanço saturam em um ciclo, obtido %d"
			% saturated)
	_check(_close(state.production_elapsed, 0.0),
			"§17/§12 o ciclo saturado é consumido, sobrou %f" % state.production_elapsed)
	# §13/§17: a soma de avanços pequenos (o caso real do `_process`) acumula ciclos.
	var accumulated := 0
	for _step in 27:
		accumulated += state.advance_production(1.0, 9)
	_check(accumulated == 3, "§13/§17 27 avanços de 1 s somam 3 ciclos, obtido %d" % accumulated)
	_check(_close(state.production_elapsed, 3.0), "§13 sobram 3 s no relógio, obtido %f"
			% state.production_elapsed)
	# §16/§23: restaurar é escrever o relógio, com a faixa conferida contra a Definition.
	_check(not state.restore_production_elapsed(-0.1), "§16 elapsed negativo é recusado")
	_check(state.restore_production_elapsed(FARM_INTERVAL),
			"§23/§43 o intervalo é inclusive — um ciclo pronto se restaura esperando Essência")
	_check(not state.restore_production_elapsed(8.1), "§16 acima do intervalo é recusado")
	_check(state.restore_production_elapsed(5.25), "§16 5.25 s é um relógio válido")
	_check(_close(state.production_elapsed, 5.25), "§16 o número salvo chegou, obtido %f"
			% state.production_elapsed)
	# §67 pela aritmética: o que falta para a próxima Biomassa é o resto do ciclo.
	_check(state.advance_production(2.7, 9) == 0, "§67 com 5.25 s salvos, 2.7 s ainda não chegam")
	_check(state.advance_production(0.1, 9) == FARM_AMOUNT, "§67/§12 o ciclo fecha no resto salvo")

	# §17/§114: a Fazenda mora na fundação da Tarefa 15, com dois arquivos próprios.
	_check(_files_in(FARM_DIR, ".gd") == ["fungal_farm_runtime.gd"],
			"§17 rooms/fungal_farm tem um Runtime, obtido %s" % [_files_in(FARM_DIR, ".gd")])
	_check(_files_in(FARM_DIR, ".tscn") == ["FungalFarmRuntime.tscn"],
			"§17 rooms/fungal_farm tem uma cena, obtido %s" % [_files_in(FARM_DIR, ".tscn")])
	# §108: o State não conhece o Núcleo — a Essência chega por parâmetro, nunca por lookup.
	var state_code := _code_of(FARM_STATE_SOURCE)
	for not_here in ["ResourcePile", "Worker", "Stockpile", "add_resource", "Node", "CoreState",
			"consume_essence", "essence"]:
		_check(not state_code.contains(not_here),
				"§108/§111 FungalFarmState não contém %s — State não decide destino nem energia"
						% not_here)


## §24: a mesma aritmética entregue em passos de 30 Hz e de 120 Hz fecha a mesma contagem de
## ciclos na mesma janela de mundo. É esta a prova de §40: ninguém conta frame.
##
## A tolerância do *resto* não é a de T20 (0.001), e a diferença é a regra de §17, não folga:
## o relógio desta Fazenda satura em `production_interval` a cada avanço — o teto vem ANTES da
## contagem de ciclos —, e é isso que garante "100 s num avanço fecham UM ciclo, não doze". Cada
## cruzamento de borda descarta a fração que passou do teto, de forma dependente do tamanho do
## passo; entre 30 Hz e 120 Hz isso vale, no pior caso, um passo do relógio mais lento
## (1/30 s). A igualdade exata só valeria se o tempo fosse acumulado sem teto, o que a Mina de
## T20 faz (§12/§13 dela) e §17 proíbe aqui de propósito.
func _test_state_clock_at_both_rates() -> void:
	var farm := load(FARM_DEFINITION_PATH) as FungalFarmDefinition
	var results := {}
	# 31.5 s de mundo, e não 32: somar 1/30 causais vezes chega a 31.499999999999993, e o
	# teste passaria a medir o ponto de corte do float em vez de medir a independência de FPS.
	for rate in [30, 120]:
		var state := FungalFarmState.new(farm, FARM_ID)
		state.apply_work(FARM_WORK)
		var produced := 0
		for _step in int(rate * CLOCK_WINDOW):
			produced += state.advance_production(1.0 / float(rate), 99)
		results[rate] = {"produced": produced, "elapsed": state.production_elapsed}
	_check(int(results[30]["produced"]) == 3, "§24/§40 30 Hz em %s s produz 3, obtido %s"
			% [CLOCK_WINDOW, results[30]])
	_check(int(results[120]["produced"]) == 3, "§24/§40 120 Hz em %s s produz 3, obtido %s"
			% [CLOCK_WINDOW, results[120]])
	_check(int(results[30]["produced"]) == int(results[120]["produced"]),
			"§24 as duas taxas fecham a mesma contagem de ciclos, obtido %s vs %s"
					% [results[30]["produced"], results[120]["produced"]])
	# A diferença é limitada por um passo do relógio lento por ciclo fechado: cada
	# cruzamento de borda descarta, no máximo, o passo que passou do teto de §17.
	var cycles := int(results[30]["produced"])
	var ideal := float(CLOCK_WINDOW) - float(cycles) * FARM_INTERVAL
	var slack := float(cycles + 1) / 30.0 + 0.001
	for rate in [30, 120]:
		_check(absf(float(results[rate]["elapsed"]) - ideal) <= slack,
				"§24 o relógio de %d Hz fica a menos de %f do resto ideal %f, obtido %f"
						% [rate, slack, ideal, float(results[rate]["elapsed"])])


## §18–§23/§44–§49/§68–§71: a produção é limitada pelos ciclos PAGÁVEIS. A aritmética pura
## disso — quantos ciclos o relógio fechou, quantos a Essência paga, e onde o relógio para em
## cada caso — mora aqui, sem cena.
func _test_energy_gated_arithmetic() -> void:
	var farm := load(FARM_DEFINITION_PATH) as FungalFarmDefinition

	# §19/§44: sem Essência nenhuma, o relógio não acumula produção alguma — nem no passo.
	var no_essence := FungalFarmState.new(farm, FARM_ID)
	no_essence.apply_work(FARM_WORK)
	_check(no_essence.advance_production(100.0, 0) == 0,
			"§19/§44 sem Essência, 100 s não produzem nada")
	# §43: o relógio satura em UM ciclo pronto, não em 12 — não há backlog.
	_check(_close(no_essence.production_elapsed, FARM_INTERVAL),
			"§43/§23 sem Essência o relógio satura em um ciclo (8.0), obtido %f"
					% no_essence.production_elapsed)

	# §20: energia parcial paga só os ciclos que cobrir. Um avanço de 9 s satura em 1 ciclo
	# (8 s), e a energia o paga; o excedente de tempo não vira dívida.
	var partial := FungalFarmState.new(farm, FARM_ID)
	partial.apply_work(FARM_WORK)
	_check(partial.advance_production(9.0, 1) == FARM_AMOUNT,
			"§20/§21 nove segundos fecham 1 ciclo e a Essência o paga")
	_check(_close(partial.production_elapsed, 0.0),
			"§17/§21 o tempo além do intervalo é descartado, obtido %f"
					% partial.production_elapsed)
	# §44/§45: um delta grande é limitado pela saturação E pela energia — nunca fecha dois
	# ciclos de energia que a Essência não cobre.
	var limited := FungalFarmState.new(farm, FARM_ID)
	limited.apply_work(FARM_WORK)
	_check(limited.advance_production(100.0, 2) == FARM_AMOUNT,
			"§17 100 s num avanço saturam em um ciclo, mesmo com energia para dois")
	_check(_close(limited.production_elapsed, 0.0),
			"§17/§45 o relógio zerou depois do ciclo pago, obtido %f"
					% limited.production_elapsed)
	# §13/§17: ciclos consecutivos pagos por avanços pequenos consomem energia um a um.
	var two := FungalFarmState.new(farm, FARM_ID)
	two.apply_work(FARM_WORK)
	var produced_two := two.advance_production(8.0, 2) + two.advance_production(8.0, 2)
	_check(produced_two == 2 * FARM_AMOUNT,
			"§13/§17 dois avanços de um ciclo produzem 2 quando a energia cobre, obtido %d"
					% produced_two)

	# §22: um ciclo já pronto (elapsed == interval) mais Essência fecha no mesmo frame.
	var ready := FungalFarmState.new(farm, FARM_ID)
	ready.apply_work(FARM_WORK)
	_check(ready.advance_production(20.0, 0) == 0, "§22 sem Essência o ciclo fica pronto, sem pagar")
	_check(_close(ready.production_elapsed, FARM_INTERVAL), "§22 o ciclo pronto espera, obtido %f"
			% ready.production_elapsed)
	_check(ready.advance_production(0.1, 1) == FARM_AMOUNT,
			"§22 chegando Essência, o ciclo pronto fecha imediatamente")
	_check(ready.production_elapsed < 0.2, "§22 e o relógio recomeça, obtido %f"
			% ready.production_elapsed)


## §102–§110/§111–§118/§34/§94: o que a tarefa NÃO é, e onde cada regra vive.
func _test_scope_guards() -> void:
	var sources := _collect_gd_files("res://")
	_check(not sources.is_empty(), "§118 a varredura achou os fontes de produção")

	# §112/§113: nenhuma gerência nova, nenhum segundo estoque, nenhum monte de Biomassa.
	for forbidden in ["FungalFarmManager", "BiomassManager", "OrganicManager",
			"ProductionManager", "EconomyManager", "RoomManager", "RoomDefinition", "RoomState",
			"RoomRuntime", "FarmUpgrade", "FarmModule", "FarmStaffing", "FarmProductivity",
			"MaintenanceSystem", "UpkeepManager", "PowerSystem", "Worker003",
			"BiomassPile", "ResourcePileDelta", "ProductionInputDefinition", "RecipeSystem",
			"ProducerDefinition", "ProductionRuntime", "ProductionState", "FeedingSystem"]:
		_check(_files_named(sources, forbidden).is_empty(),
				"§112/§113 nenhum fonte se chama %s" % forbidden)
		_check(_files_containing(sources, "class_name %s" % forbidden).is_empty(),
				"§112/§113 nenhuma classe %s foi declarada" % forbidden)
	# §112: nada de terceiro Worker, terceiro nível ou segunda invasão.
	_check(_files_containing(sources, "worker_003").is_empty(),
			"§112 não existe Worker003 no projeto, achado em %s"
					% [_files_containing(sources, "worker_003")])
	_check(_files_containing(sources, "level = 3").is_empty(),
			"§112 nenhuma Definition de Núcleo Nv.3")

	# §34/§94: a prova do valor da refatoração da Tarefa 15 — o controller de seleção não
	# sabe que a Fazenda existe. Obra é camada, nunca tipo.
	var selection_code := _code_of(SELECTION_SOURCE)
	for type_name in ["FungalFarmRuntime", "MineRuntime", "NestRuntime", "BarracksRuntime"]:
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
			"§117 nenhum HUD novo, obtido %s" % [_files_in(UI_HUD_DIR, ".tscn")])

	# §25/§26/§62: a Fazenda entra por rota própria e o setup antigo continua de oito argumentos.
	var construction_code := _code_of(CONSTRUCTION_SOURCE)
	for required in ["signal fungal_farm_built", "signal fungal_farm_completed",
			"FUNGAL_FARM_INSTANCE_ID := \"fungal_farm_001\"", "func fungal_farm()",
			"func bind_fungal_farm(", "func build_fungal_farm(", "func restore_fungal_farm("]:
		_check(construction_code.contains(required),
				"§25/§26/§62 construction_controller.gd contém %s" % required)
	_check(construction_code.contains("barracks_build_point: Node3D = null) -> void:"),
			"§26 setup() não virou uma assinatura de onze parâmetros")
	_check(not construction_code.contains("if fungal_farm is ")
			and not construction_code.contains("match "),
			"§25 o controller conhece cada obra por nome, sem type switch")

	# §27: a tecla G entra pelo InputMap e é a única dona do physical_keycode 71.
	var project := _source(PROJECT_SOURCE)
	_check(project.contains("build_fungal_farm="), "§27 o InputMap declara build_fungal_farm")
	_check(_count_occurrences(project, "\"physical_keycode\": 71") == 1,
			"§27 G não disputa nenhuma outra ação, obtido %d ocorrências"
					% _count_occurrences(project, "\"physical_keycode\": 71"))
	_check(_source(CONSTRUCTION_SOURCE).contains("is_action_pressed(\"build_fungal_farm\")"),
			"§27 a obra é pedida pela ação, nunca pela letra solta")

	# §20/§22/§24: o Runtime é delta, estoque, Essência e nada de monte.
	var runtime_code := _code_of(FARM_RUNTIME_SOURCE)
	_check(runtime_code.contains("func _process(delta: float) -> void:"), "§20 um único _process")
	_check(runtime_code.contains("set_process(is_completed())"),
			"§20/§86 o processo é ligado pela conclusão")
	_check(runtime_code.count("func _process(") == 1 and not runtime_code.contains(
			"func _physics_process("), "§117 a Fazenda tem exatamente um processo")
	for not_here in ["ResourcePile", "spawn_resource_pile", "load(", "FileAccess"]:
		_check(not runtime_code.contains(not_here),
				"§24/§22 FungalFarmRuntime não contém %s" % not_here)
	_check(runtime_code.contains("bind_stockpile") and runtime_code.contains("bind_core_state"),
			"§108/§111 o Runtime recebe estoque e Núcleo por binding explícito")
	_check(runtime_code.contains("_stockpile.add_resource"),
			"§22 a produção vai direto para o ResourceStockpileState")
	_check(runtime_code.contains("consume_essence"),
			"§19/§20 a energia sai do CoreState pelo método do Núcleo")

	# §37/§106: o HUD de recurso acompanha as duas linhas — minério e Biomassa.
	var resource_hud := _code_of(RESOURCE_HUD_SOURCE)
	_check(resource_hud.contains("Biomass") or resource_hud.contains("biomass"),
			"§37/§106 o painel de recurso mostra a Biomassa")
	var hud_code := _code_of(CONSTRUCTION_HUD_SOURCE)
	for required in ["FungalFarmStatusLabel", "fungal_farm_built.connect",
			"fungal_farm_completed.connect", "_refresh_fungal_farm(",
			# §96: a linha que avisa da falta de Essência só existe se o painel escutar o
			# signal do saldo — sem essa conexão o texto nunca muda no jogo real.
			"essence_changed.connect("]:
		_check(hud_code.contains(required), "§36/§107 o painel de construção trata da Fazenda em %s"
				% required)

	# §50/§51/§60: versão por versão, uma rota nomeada, sem framework.
	var snapshot_code := _code_of(SNAPSHOT_SOURCE)
	for required in ["const SAVE_VERSION := 3", "const SAVE_VERSION_V1 := 1",
			"const SAVE_VERSION_V2 := 2", "static func validate_v1(",
			"static func validate_v2(", "static func validate_v3(",
			"static func migrate_v1_to_v2(", "static func migrate_v2_to_v3(",
			"static func migrate_to_current("]:
		_check(snapshot_code.contains(required), "§50/§51/§60 campaign_snapshot.gd contém %s"
				% required)
	for forbidden in ["MigrationRegistry", "MigrationManager", "SchemaGraph",
			"MigrationDefinition", "MigrationV2", "MigrationV3"]:
		_check(_files_containing(sources, forbidden).is_empty(),
				"§116 nenhum fonte contém %s, achado em %s"
						% [forbidden, _files_containing(sources, forbidden)])

	# §109/§110/§59: os três documentos de schema existem e documentam a diferença real.
	_check(FileAccess.file_exists(V1_DOC), "§109 docs/SAVE_SCHEMA_V1.md continua no projeto")
	_check(FileAccess.file_exists(V2_DOC), "§110 docs/SAVE_SCHEMA_V2.md continua no projeto")
	_check(FileAccess.file_exists(V3_DOC), "§52 docs/SAVE_SCHEMA_V3.md existe")
	var v3_text := _source(V3_DOC).to_lower()
	for documented in ["save_version", "fungal_farm", "production_elapsed", "essence", "v2",
			"v3", "migration", "offline"]:
		_check(v3_text.contains(documented), "§52 o documento V3 documenta %s" % documented)

	# §120: a suíte entra no CI por descoberta, não por lista.
	var ci_text := _source(CI_SOURCE)
	_check(not ci_text.contains("fungal_farm") and not ci_text.contains("biomass"),
			"§120 o workflow não lista suíte nenhuma — a descoberta é automática")
	_check(not _source(GAME_MAIN_SOURCE).contains("fungal_farm_001"),
			"§25 a raiz de composição não conhece instância nenhuma")


# ============================================================ Bloco 2 — a obra no mundo


## §25/§26/§18/§19/§113: o canteiro tem lugar físico validado no Ground, usa a camada de obra
## já existente e tem cena própria — visualmente distinta da Mina, sem asset e sem material
## que a GeForce 9800 GT não saiba desenhar.
func _test_farm_build_point_and_scene() -> void:
	_check(_farm_build_point.get_class() == "Marker3D", "§25 FungalFarmBuildPoint é um Marker3D")
	_check(_farm_build_point.global_position.is_equal_approx(FARM_BUILD_POINT),
			"§25 FungalFarmBuildPoint em (10, 0, -9), obtido %s"
					% [_farm_build_point.global_position])
	_check(_physics_nodes_under(_farm_build_point).is_empty(),
			"§25 o build point não tem collider nem intercepta raycast")
	var screen := _camera.unproject_position(FARM_BUILD_POINT)
	_check(Rect2(Vector2.ZERO, Vector2(root.size)).has_point(screen),
			"§25 o ponto da Fazenda está dentro do campo da câmera, obtido %s" % [screen])
	var hit := _ray_hit(screen, CLICKABLE)
	_check(not hit.is_empty() and hit.collider == _floor,
			"§25 antes da obra o clique no ponto da Fazenda cai no Ground, obtido %s"
					% [hit.get("collider")])
	_check(_planar_gap(FARM_BUILD_POINT, NEST_BUILD_POINT) >= 6.0,
			"§25 a Fazenda não se sobrepõe ao Ninho, obtido %f"
					% _planar_gap(FARM_BUILD_POINT, NEST_BUILD_POINT))
	_check(_planar_gap(FARM_BUILD_POINT, BARRACKS_BUILD_POINT) >= 6.0,
			"§25 a Fazenda não se sobrepõe ao Quartel, obtido %f"
					% _planar_gap(FARM_BUILD_POINT, BARRACKS_BUILD_POINT))
	_check(_planar_gap(FARM_BUILD_POINT, MINE_BUILD_POINT) >= 6.0,
			"§25 a Fazenda não se sobrepõe à Mina, obtido %f"
					% _planar_gap(FARM_BUILD_POINT, MINE_BUILD_POINT))
	_check(_planar_gap(FARM_BUILD_POINT, CORE_POSITION) >= 7.0,
			"§25 a Fazenda fica fora do corpo do Núcleo, obtido %f"
					% _planar_gap(FARM_BUILD_POINT, CORE_POSITION))
	for rock in _rocks():
		_check(_planar_gap(FARM_BUILD_POINT, rock.global_position) >= 2.6,
				"§25 o canteiro não nasce sobre a Rocha %s, obtido %f"
						% [rock.rock_id, _planar_gap(FARM_BUILD_POINT, rock.global_position)])
	for path_name in ["A", "B"]:
		var origin := INVASION_PATH_A if path_name == "A" else INVASION_PATH_B
		_check(_segment_gap(origin, CORE_POSITION) >= 2.2,
				"§25 a Fazenda não fecha o corredor de invasão %s, folga %f"
						% [path_name, _segment_gap(origin, CORE_POSITION)])

	# §18/§19: a cena é low-poly própria, sem externo e sem metallic cheio.
	var scene_text := _source(FARM_SCENE_PATH)
	_check(_count_occurrences(scene_text, "[ext_resource") == 1,
			"§18/§23 a cena só referencia o próprio script, obtido %d"
					% _count_occurrences(scene_text, "[ext_resource"))
	_check(not scene_text.contains("metallic = 1\n")
			and not scene_text.contains("metallic = 1.0"),
			"§19 nenhum material metálico cheio — OpenGL 3.3 deixaria a Fazenda preta")
	_check(not scene_text.contains("Animation") and not scene_text.contains("Particles"),
			"§18 sem animação nem partícula")
	_check(scene_text.contains("collision_layer = 16"),
			"§33 a Fazenda usa a camada Construction que já existia")
	_check(scene_text != _source(MINE_SCENE_PATH) and scene_text != _source(NEST_SCENE_PATH)
			and scene_text != _source(BARRACKS_SCENE_PATH),
			"§18/§113 a Fazenda tem cena própria, não é a Mina com outro nome")
	for mesh in ["SoilBed", "Cap1", "Spore1", "CultureVat1"]:
		_check(scene_text.contains(String(mesh)),
				"§18 CompletedVisual tem %s — leito, cogumelo, esporo e cuba" % mesh)


## §75/§76/§89/§107: a GameMain fresca é Nv.1, o jogador tem ferro sobrando e a tecla G real
## não faz nada — a porta do nível vem antes do custo, então o saldo nem é tocado.
func _test_level_one_gate_with_real_key() -> void:
	await _reset_campaign()
	_give_iron(20)
	await _advance(0.05)
	_check(_core_state.level == 1, "§76 a campanha fresca é Nv.1, obtido %d" % _core_state.level)
	_check(_stockpile.get_amount(ORE) == 20, "§76 há 20 de minério para gastar")
	_check(_text_of(_farm_hud, "FungalFarmStatusLabel") == HUD_BLOCKED,
			"§107 Lv.1: o painel diz %s, obtido %s" % [HUD_BLOCKED,
					_text_of(_farm_hud, "FungalFarmStatusLabel")])
	await _press_farm_key()
	_check(_construction.fungal_farm() == null, "§75/§76 G no Nv.1 não cria Fazenda")
	_check(_stockpile.get_amount(ORE) == 20, "§76/§89 o bloqueio não consome nada, obtido %d"
			% _stockpile.get_amount(ORE))
	_check(_farm_built_events == 0, "§76 nenhum signal de obra, obtido %d" % _farm_built_events)
	_check(not _construction.build_fungal_farm(),
			"§89 build_fungal_farm() direto também recusa no Nv.1")
	_check(_farm_count() == 0, "§76 zero obras, obtido %d" % _farm_count())


## §66/§77/§89: no Nv.2 sem Mina concluída a ordem das portas para na Mina — e a recusa
## também é atômica, sem tocar no ferro.
func _test_farm_requires_completed_mine() -> void:
	# Nv.2, ferro de sobra, mas sem Mina nenhuma.
	await _reset_campaign()
	await _unlock_level_two(FARM_COST + 4)
	_check(_construction.mine() == null, "§66 setup: sem Mina")
	_check(_text_of(_farm_hud, "FungalFarmStatusLabel") == HUD_NO_MINE,
			"§107 Nv.2 sem Mina: o painel diz %s, obtido %s" % [HUD_NO_MINE,
					_text_of(_farm_hud, "FungalFarmStatusLabel")])
	_check(not _construction.build_fungal_farm(), "§66 Nv.2 sem Mina recusa a Fazenda")
	_check(_construction.fungal_farm() == null, "§66 nenhum canteiro foi criado")
	_check(_stockpile.get_amount(ORE) == FARM_COST + 4,
			"§66/§89 a recusa não descontou nada, obtido %d" % _stockpile.get_amount(ORE))

	# Nv.2, Mina lançada mas ainda canteiro: continua recusando.
	await _reset_campaign()
	await _open_mine_site(FARM_COST + 4)
	_check(_construction.mine() != null and not _construction.mine().is_completed(),
			"§66 setup: Mina é canteiro")
	_check(not _construction.build_fungal_farm(), "§66 Mina em obra ainda não abre a Fazenda")
	_check(_construction.fungal_farm() == null, "§66 nenhum canteiro foi criado com Mina em obra")

	# Nv.2, Mina concluída: a Fazenda abre. São precisos os 6 da Mina E os 4 da Fazenda —
	# `_open_mine_site` entrega o total, então o saldo tem de cobrir as duas obras.
	await _reset_campaign()
	await _open_mine_site(MINE_COST + FARM_COST)
	_construction.mine().state.apply_work(8.0)
	await _advance(0.05)
	_check(_construction.mine().is_completed(), "§66 setup: Mina concluída")
	_check(_stockpile.get_amount(ORE) == FARM_COST,
			"§107 setup: sobraram exatamente os %d da Fazenda, obtido %d"
					% [FARM_COST, _stockpile.get_amount(ORE)])
	_check(_text_of(_farm_hud, "FungalFarmStatusLabel") == HUD_READY,
			"§107 Nv.2 com Mina pronta: %s, obtido %s" % [HUD_READY,
					_text_of(_farm_hud, "FungalFarmStatusLabel")])


## §77/§78/§90/§31/§92/§107: a integração real. A campanha joga o MVP até o Nv.2, constrói a
## Mina e a conclui, e aí a mesma tecla G abre a Fazenda — o custo sai uma única vez, e a
## Fazenda é uma só.
func _test_level_two_real_input_and_cost() -> void:
	await _reset_campaign()
	_give_iron(20)
	await _reach_level_two_for_real()
	_check(_core_state.level == FARM_LEVEL, "§78 Nv.2 alcançado pelo caminho canônico")
	# Constrói e conclui a Mina — a segunda porta da progressão. O painel da Fazenda só
	# troca de "recursos insuficientes" para "pronto" depois que a conclusão da Mina
	# propaga no frame seguinte, então a leitura do HUD espera o quadro.
	await _open_mine_site_completing_it()
	await _advance(0.05)
	_check(_stockpile.get_amount(ORE) == 20 - 6, "§77 o minério gasto na Mina veio do saldo, %d"
			% _stockpile.get_amount(ORE))
	var farm_hud_text := _text_of(_farm_hud, "FungalFarmStatusLabel")
	_check(farm_hud_text == HUD_READY,
			"§107 Nv.2 com Mina pronta: %s, obtido %s" % [HUD_READY, farm_hud_text])
	await _press_farm_key()
	_farm = _construction.fungal_farm()
	_check(_farm != null, "§77/§90 G na porta aberta lança o canteiro da Fazenda")
	if _farm == null:
		return
	_check(_stockpile.get_amount(ORE) == 20 - 6 - FARM_COST,
			"§77/§90 quatro minérios cobrados de uma vez, obtido %d"
					% _stockpile.get_amount(ORE))
	_check(_farm.global_position.is_equal_approx(FARM_BUILD_POINT),
			"§25 a Fazenda nasceu no FungalFarmBuildPoint, obtido %s" % [_farm.global_position])
	_check(_farm is ConstructionRuntime, "§93/§17 FungalFarmRuntime é ConstructionRuntime")
	_check(_farm.state is ConstructionState, "§98 o State da Fazenda é um ConstructionState")
	_check(_farm.collision_layer == CONSTRUCTION_LAYER,
			"§33/§93 a Fazenda está na camada Construction, obtida %d" % _farm.collision_layer)
	_check(_farm.state.farm_id == FARM_ID, "§25 a instância é fungal_farm_001, obtida %s"
			% _farm.state.farm_id)
	_check(_farm_built_events == 1, "§25 fungal_farm_built emitido exatamente uma vez, %d"
			% _farm_built_events)
	_check(_text_of(_farm_hud, "FungalFarmStatusLabel") == HUD_BUILDING,
			"§107 em construção: %s, obtido %s" % [HUD_BUILDING,
					_text_of(_farm_hud, "FungalFarmStatusLabel")])
	# §34/§94 de verdade: o ray do SelectionController reconhece a obra pela camada.
	var hit := _ray_hit(_camera.unproject_position(_farm.global_position), CLICKABLE)
	_check(not hit.is_empty() and hit.collider == _farm,
			"§34/§94 a Fazenda é alcançada pelo mesmo raycast que enxerga Mina, Ninho e Quartel")
	# §31/§92: G de novo não cobra nem duplica.
	await _press_farm_key()
	_check(_farm_count() == 1, "§31 uma única Fazenda, obtido %d" % _farm_count())
	_check(_stockpile.get_amount(ORE) == 20 - 6 - FARM_COST,
			"§92 nenhuma segunda cobrança, obtido %d" % _stockpile.get_amount(ORE))
	_check(_farm_built_events == 1, "§92 fungal_farm_built continua 1, obtido %d"
			% _farm_built_events)


## §30/§91: aberta a porta do nível e a da Mina, a outra recusa é a do saldo — e ela também é
## atômica.
func _test_insufficient_iron() -> void:
	await _reset_campaign()
	await _open_mine_site_completing_it()
	_give_iron(FARM_COST - 1)
	_check(_stockpile.get_amount(ORE) == FARM_COST - 1, "§91 há 3 de 4 necessários")
	_check(not _construction.build_fungal_farm(), "§91 com 3 minérios a Fazenda é recusada")
	_check(_construction.fungal_farm() == null, "§91 nenhum canteiro foi criado")
	_check(_stockpile.get_amount(ORE) == FARM_COST - 1,
			"§30/§91 a recusa não descontou nada, obtido %d" % _stockpile.get_amount(ORE))
	_check(_text_of(_farm_hud, "FungalFarmStatusLabel") == HUD_INSUFFICIENT,
			"§107 porteira aberta sem saldo: %s, obtido %s" % [HUD_INSUFFICIENT,
					_text_of(_farm_hud, "FungalFarmStatusLabel")])


## §20/§21/§86/§18: enquanto é obra não há processo nem produção; a conclusão liga o relógio
## zerado e troca o visual pela regra da base.
func _test_process_gating_and_completion() -> void:
	await _reset_campaign()
	await _open_farm_site(FARM_COST + 4, 0.0)
	_check(_farm != null and not _farm.is_completed(), "setup: canteiro aberto")
	_check(not _farm.is_processing(), "§20/§86 canteiro não roda _process")
	_check(_close(_farm_clock(), 0.0), "§11 enquanto é obra o relógio é zero")
	var site_visual := _farm.find_child("ConstructionVisual", true, false) as Node3D
	var built_visual := _farm.find_child("CompletedVisual", true, false) as Node3D
	_check(site_visual != null and built_visual != null, "§18 a cena tem os dois visuais")
	_check(site_visual.visible and not built_visual.visible, "§18 canteiro visível, prédio oculto")
	await _world(4.0)
	_check(_stockpile.get_amount(BIOMASS) == 0, "§99/§15 obra inacabada não produz")
	_check(_farm_built_events == 1 and _farm_completed_events == 0,
			"§21 nenhuma conclusão antes da hora (%d/%d)"
					% [_farm_built_events, _farm_completed_events])

	# A conclusão é síncrona no `apply_work`, e é por isso que o zero do relógio é conferido
	# antes de qualquer frame: um frame depois, o processo já terá andado.
	_give_essence(ESSENCE_PER_CYCLE * 3.0)
	_farm.state.apply_work(FARM_WORK)
	_check(_farm.is_completed(), "§21 a obra conclui")
	_check(_farm.is_processing(), "§86/§20 concluída, o processo liga")
	_check(_close(_farm_clock(), 0.0), "§21/§11 o relógio recomeça do zero")
	_check(built_visual.visible and not site_visual.visible, "§18/§108 o visual trocou")
	_check(_farm_completed_events == 1, "§21 fungal_farm_completed uma vez, obtido %d"
			% _farm_completed_events)
	_check(_text_of(_farm_hud, "FungalFarmStatusLabel") == HUD_OPERATIONAL,
			"§107 operacional: %s, obtido %s" % [HUD_OPERATIONAL,
					_text_of(_farm_hud, "FungalFarmStatusLabel")])
	await _advance(0.05)
	_check(_farm_clock() > 0.0 and _farm_clock() < 0.5,
			"§20/§11 ligado o processo, o relógio anda com o mundo, obtido %f" % _farm_clock())
	await _world(0.3)
	_check(_stockpile.get_amount(BIOMASS) == 0, "§21/§38 nenhuma moeda instantânea na conclusão")


## §19/§20/§21/§22/§44/§45/§46/§114: o ciclo orgânico no mundo real — 8 s e 4 de Essência
## pagam 1 de Biomassa, a Essência cai, e o ciclo continua sozinho.
func _test_essence_powered_production() -> void:
	await _reset_campaign()
	await _open_farm_site(FARM_COST + 4, FARM_WORK, 0.0)
	_give_essence(ESSENCE_PER_CYCLE * 4.0)
	_freeze_essence()
	await _advance(0.05)
	_check(_farm.is_completed() and _farm.is_processing(), "setup: Fazenda operacional")
	var biomass_before := _stockpile.get_amount(BIOMASS)
	var essence_before := _core_state.essence
	_set_speed(SPEED)
	# §38: abaixo do intervalo, nada. Oito segundos menos um, nenhuma Biomassa.
	await _world(FARM_INTERVAL - 1.0)
	_check(_stockpile.get_amount(BIOMASS) == biomass_before,
			"§38 antes do intervalo nada foi produzido, obtido %d"
					% _stockpile.get_amount(BIOMASS))
	var next := await _wait_for_biomass(biomass_before + FARM_AMOUNT, 4.0)
	_check(next and _stockpile.get_amount(BIOMASS) == biomass_before + FARM_AMOUNT,
			"§39/§46 8 s depois o saldo é X+1, obtido %d"
					% _stockpile.get_amount(BIOMASS))
	# §19: com a regeneração congelada, o gasto é exatamente o preço do ciclo.
	var spent := essence_before - _core_state.essence
	_check(_close(spent, ESSENCE_PER_CYCLE, 0.6),
			"§19 um ciclo custa 4.0 de Essência, obtido %f" % spent)
	_check(_farm_clock() < FARM_INTERVAL, "§12 o resto do ciclo continua menor que o intervalo")
	# §39/§40: o ciclo seguinte fecha sozinho e cobra o mesmo preço.
	var second := await _wait_for_biomass(biomass_before + 2 * FARM_AMOUNT, 4.0)
	_check(second, "§39 a produção é contínua — dois ciclos seguidos")
	_check(_close(essence_before - _core_state.essence, 2 * ESSENCE_PER_CYCLE, 0.7),
			"§40 dois ciclos custaram ~8.0, obtido %f" % (essence_before - _core_state.essence))
	_measurements["essencia_gasta_1_ciclo"] = spent
	_resume_essence()
	_check(_pile_count() == 0, "§24/§42/§88 nenhum monte nasceu da Fazenda, obtido %d"
			% _pile_count())
	# §37/§106: o painel de recurso mostra minério e Biomassa.
	_check(_text_of(_resource_hud, "BiomassLabel") == "%s: %d" % [BIOMASS_DISPLAY,
					_stockpile.get_amount(BIOMASS)],
			"§37/§106 o HUD de recurso acompanha a Biomassa por signal, obtido %s"
					% _text_of(_resource_hud, "BiomassLabel"))
	_set_speed(1.0)


## §45/§47/§48: dois ciclos fechados num delta grande consomem dois custos. A Essência é
## finita, e o saldo de Biomassa nunca cresce mais rápido do que a energia paga.
func _test_two_cycles_two_costs() -> void:
	await _reset_campaign()
	await _open_farm_site(FARM_COST + 4, FARM_WORK, 0.0)
	_give_essence(ESSENCE_PER_CYCLE * 4.0)
	_freeze_essence()
	await _advance(0.05)
	var essence_before := _core_state.essence
	var biomass_before := _stockpile.get_amount(BIOMASS)
	# §47: 8 s — um ciclo, um custo.
	_set_speed(SPEED)
	var one := await _wait_for_biomass(biomass_before + FARM_AMOUNT, 4.0)
	_check(one, "§47 o primeiro ciclo fechou")
	var spent_one := essence_before - _core_state.essence
	_check(_close(spent_one, ESSENCE_PER_CYCLE, 0.6),
			"§47 um ciclo custou 4.0 de Essência, obtido %f" % spent_one)
	# §48: 16 s — dois ciclos, dois custos.
	var two := await _wait_for_biomass(biomass_before + 2 * FARM_AMOUNT, 4.0)
	_check(two and _stockpile.get_amount(BIOMASS) == biomass_before + 2 * FARM_AMOUNT,
			"§48 o segundo ciclo fechou sozinho, obtido %d" % _stockpile.get_amount(BIOMASS))
	var spent_two := essence_before - _core_state.essence
	_check(_close(spent_two, 2 * ESSENCE_PER_CYCLE, 0.8),
			"§48 dois ciclos consumiram 8.0 de Essência, obtido %f" % spent_two)
	_measurements["biomassa_2_ciclos"] = _stockpile.get_amount(BIOMASS)
	_measurements["essencia_2_ciclos"] = spent_two
	_resume_essence()
	_set_speed(1.0)


## §43/§44/§45: sem Essência, o relógio satura em UM ciclo e não acumula produção — não há
## backlog. Com a regeneração congelada, a fome é um estado real e permanente.
func _test_starvation_saturates() -> void:
	await _reset_campaign()
	await _open_farm_site(FARM_COST + 4, FARM_WORK, 0.0)
	_freeze_essence()
	_drain_essence()
	_check(_core_state.essence < 0.1, "§43 setup: Essência esgotada, obtida %f"
			% _core_state.essence)
	_set_speed(SPEED)
	# §43: muito tempo sem Essência — o relógio para em 8.0, não em 80.
	await _world(FARM_INTERVAL * 5.0)
	_check(_close(_farm_clock(), FARM_INTERVAL),
			"§43 cinco ciclos de espera saturam em um ciclo pronto, obtido %f" % _farm_clock())
	_check(_stockpile.get_amount(BIOMASS) == 0, "§43 nenhuma Biomassa foi acumulada, obtido %d"
			% _stockpile.get_amount(BIOMASS))
	_check(_text_of(_farm_hud, "FungalFarmStatusLabel") == HUD_STARVING,
			"§96/§107 sem Essência o painel avisa, obtido %s"
					% _text_of(_farm_hud, "FungalFarmStatusLabel"))
	# §45: chega Essência para exatamente um ciclo. Só ele se paga, apesar das dezenas de
	# segundos de espera — a produção não explode com o tempo parado.
	_give_essence(ESSENCE_PER_CYCLE)
	await _advance(0.05)
	_check(_stockpile.get_amount(BIOMASS) == FARM_AMOUNT,
			"§45/§44 a Essência de um ciclo produziu exatamente um, obtido %d"
					% _stockpile.get_amount(BIOMASS))
	_check(_close(_core_state.essence, 0.0, 0.01),
			"§45 o ciclo consumiu a Essência inteira, sobrou %f" % _core_state.essence)
	_check(_text_of(_farm_hud, "FungalFarmStatusLabel") == HUD_STARVING,
			"§96/§107 pago um ciclo, a linha volta a avisar da falta, obtido %s"
					% _text_of(_farm_hud, "FungalFarmStatusLabel"))
	# §44: de novo sem Essência, o relógio volta a saturar em outro ciclo — e nada acumula.
	await _world(FARM_INTERVAL * 3.0)
	_check(_stockpile.get_amount(BIOMASS) == FARM_AMOUNT,
			"§44 sem nova Essência nada foi produzido, obtido %d"
					% _stockpile.get_amount(BIOMASS))
	_check(_close(_farm_clock(), FARM_INTERVAL),
			"§44/§43 o relógio saturou no ciclo pronto de novo, obtido %f" % _farm_clock())
	# §46: chega energia para dois ciclos, mas só um está pronto — fecha um, não dois de uma vez.
	_give_essence(ESSENCE_PER_CYCLE * 2.0)
	await _advance(0.05)
	_check(_stockpile.get_amount(BIOMASS) == FARM_AMOUNT + 1,
			"§46 o ciclo pronto fechou com a energia, obtido %d" % _stockpile.get_amount(BIOMASS))
	_check(_text_of(_farm_hud, "FungalFarmStatusLabel") == HUD_OPERATIONAL,
			"§96/§107 com Essência de sobra o aviso desaparece, obtido %s"
					% _text_of(_farm_hud, "FungalFarmStatusLabel"))
	_resume_essence()
	_set_speed(1.0)


## §40/§24 no Runtime: o mesmo relógio semeado fecha o ciclo em 30 Hz e em 120 Hz. Ninguém
## conta frames — a produção é função do delta que o motor entrega.
func _test_production_is_delta_driven() -> void:
	var results := {}
	for rate in [30, 120]:
		await _reset_campaign()
		await _open_farm_site(FARM_COST, FARM_WORK, 0.0)
		_give_essence(ESSENCE_PER_CYCLE * 3.0)
		await _advance(0.05)
		# §16: a mesma porta que o load usa serve aqui para semear o relógio perto da borda.
		_check(_farm.restore_production(FARM_INTERVAL - 0.6), "§16 setup: relógio semeado em 7.4 s")
		Engine.set_physics_ticks_per_second(rate)
		_set_speed(SPEED)
		var biomass := _stockpile.get_amount(BIOMASS)
		await _world(0.4)
		var before := _stockpile.get_amount(BIOMASS)
		await _world(0.5)
		results[rate] = {"produced": _stockpile.get_amount(BIOMASS) - biomass,
				"elapsed": _farm_clock(),
				"stopped_at": before - biomass}
		_set_speed(1.0)
		Engine.set_physics_ticks_per_second(TICKS)
	_check(int(results[30]["produced"]) == int(results[120]["produced"]),
			"§40/§24 30 Hz e 120 Hz produziram o mesmo: %s" % [results])
	_check(int(results[30]["produced"]) + int(results[30]["stopped_at"]) == FARM_AMOUNT,
			"§40 o ciclo fechou uma única vez em cada taxa: %s" % [results])
	_check(absf(float(results[30]["elapsed"]) - float(results[120]["elapsed"])) < 0.25,
			"§24 o resto do relógio é equivalente entre taxas: %s" % [results])
	_measurements["fps_30hz"] = results[30]
	_measurements["fps_120hz"] = results[120]


## §49/§69/§70/§71: as duas economias convivem. A Mina produz minério sem gastar Essência a
## cada ciclo; a Fazenda gasta Essência a cada ciclo. As duas rodam ao mesmo tempo, na mesma
## cena, sem interferência.
func _test_parallel_economy_mine_and_farm() -> void:
	await _reset_campaign()
	await _open_mine_site_completing_it()
	_give_iron(FARM_COST + 4)
	await _advance(0.05)
	_check(_construction.build_fungal_farm(), "§70 setup: Fazenda lançada ao lado da Mina")
	_farm = _construction.fungal_farm()
	_farm.state.apply_work(FARM_WORK)
	_give_essence(ESSENCE_PER_CYCLE * 4.0)
	_freeze_essence()
	await _advance(0.05)
	_check(_construction.mine() != null and _construction.mine().is_completed(),
			"§69 a Mina está operacional")
	_check(_farm.is_completed(), "§70 a Fazenda está operacional")
	var ore_before := _stockpile.get_amount(ORE)
	var biomass_before := _stockpile.get_amount(BIOMASS)
	var essence_before := _core_state.essence
	_set_speed(SPEED)
	# §69: dez segundos — a Mina fecha um ciclo de minério, a Fazenda fecha um de Biomassa
	# (8 s) e começa outro. As duas correm em paralelo.
	var ore_grew := await _wait_for_iron(ore_before + 1, 4.0)
	var biomass_grew := await _wait_for_biomass(biomass_before + 1, 4.0)
	_set_speed(1.0)
	_check(ore_grew, "§69 a Mina produziu minério em paralelo, obtido %d"
			% _stockpile.get_amount(ORE))
	_check(biomass_grew, "§70 a Fazenda produziu Biomassa em paralelo, obtido %d"
			% _stockpile.get_amount(BIOMASS))
	_check(_core_state.essence < essence_before,
			"§71 só a Fazenda gastou Essência, de %f para %f"
					% [essence_before, _core_state.essence])
	_check(_pile_count() == 0, "§24 nenhum monte nasceu das duas economias")
	_resume_essence()
	_measurements["paralelo_ore"] = _stockpile.get_amount(ORE) - ore_before
	_measurements["paralelo_biomass"] = _stockpile.get_amount(BIOMASS) - biomass_before


## §34/§35/§95/§96: a obra cooperativa da Tarefa 15 atende a Fazenda sem código novo — RMB
## real, ordem BUILD, e o trabalho de um Worker rende 1.0/s, de dois rende 2.0/s.
func _test_cooperative_construction() -> void:
	await _reset_campaign()
	# §21: este teste monta o canteiro à mão (não passa por _open_farm_site), então zera os
	# contadores aqui — sem isso a asserção de "uma conclusão por obra" somaria as obras das
	# suítes anteriores e mediria a suíte inteira em vez desta obra.
	_farm_built_events = 0
	_farm_completed_events = 0
	await _open_mine_site_completing_it()
	_give_iron(FARM_COST)
	_check(_construction.build_fungal_farm(), "setup: canteiro da Fazenda lançado")
	_farm = _construction.fungal_farm()
	await _advance(0.05)
	_check(_farm != null, "setup: canteiro da Fazenda lançado")
	if _farm == null:
		return
	await _park_near_farm(_worker, -1.0)
	await _advance(0.05)
	_selection.clear_selection()
	await _click_select(_worker)
	_check(_selection.selected_unit == _worker, "§34 o Worker foi selecionado por clique real")
	await _right_click(_farm.global_position)
	_check(_worker.action_mode() == WorkerRuntime.ActionMode.BUILD,
			"§34/§94 RMB na Fazenda coloca o Worker em BUILD pela camada")
	_check(_worker.current_construction_target() == _farm,
			"§34 o alvo de construção é a Fazenda, obtido %s"
					% [_worker.current_construction_target()])
	await _advance(0.1)
	var rate_one := await _measure_work_rate()
	var predicted_one := FARM_WORK / rate_one
	_check(_close(rate_one, 1.0, 0.2),
			"§95 um Worker rende work_speed por segundo, obtido %f" % rate_one)
	_check(_close(predicted_one, 6.0, 1.5),
			"§95/§35 trabalho puro de um Worker ≈ 6 s, obtido %f" % predicted_one)

	_give_essence(SUMMON_COST + 2.0)
	_check(_invocation.summon_worker(), "§96 Worker002 convocado para a obra")
	await _advance(0.1)
	var second := _second_worker()
	_check(second != null, "§96 o segundo Worker está em campo")
	if second == null:
		return
	await _park_near_farm(second, 1.0)
	await _shift_click_select(second)
	_check(_selection.selected_units.has(_worker) and _selection.selected_units.has(second),
			"§96 o grupo é os dois Workers, obtido %s" % [_selection.selected_units])
	_check(_selection.selected_units.size() == 2, "§96 dois Workers selecionados, obtido %d"
			% _selection.selected_units.size())
	await _right_click(_farm.global_position)
	_check(_worker.is_building() and second.is_building(),
			"§35/§96 os dois atenderam a mesma obra")
	await _advance(0.1)
	var rate_two := await _measure_work_rate()
	var predicted_two := FARM_WORK / rate_two
	_check(_close(rate_two, 2.0, 0.3),
			"§96 dois Workers rendem 2.0 de trabalho por segundo, obtido %f" % rate_two)
	_check(_close(predicted_two, 3.0, 1.0),
			"§96/§35 trabalho puro de dois Workers ≈ 3 s, obtido %f" % predicted_two)
	_check(predicted_two < predicted_one, "§35 a cooperação acelera a obra, %f contra %f"
			% [predicted_two, predicted_one])
	_measurements["trabalho_1_worker"] = predicted_one
	_measurements["trabalho_2_workers"] = predicted_two
	# A obra continua de verdade até fechar, e o relógio liga sozinho na conclusão.
	_give_essence(ESSENCE_PER_CYCLE * 2.0)
	var done := await _wait_until(func() -> bool: return _farm.is_completed(), 30.0)
	_check(done, "§95/§21 os Workers terminaram a Fazenda")
	_check(_farm_completed_events == 1, "§21 uma conclusão por obra, obtido %d"
			% _farm_completed_events)
	_check(_farm.is_processing(), "§20/§86 a Fazenda terminada produz")


## §79: o cenário principal inteiro, por InputMap, SelectionController, BUILD, FungalFarmRuntime
## e Stockpile — uma campanha Nv.2 com Mina pronta, G, dois Workers, obra, e saldo +1 Biomassa
## a cada 8 s pagando 4 de Essência.
func _test_end_to_end_organic_economy() -> void:
	await _reset_campaign()
	# §121: o arquivo desta cena é o E2E_PATH — salvar no FRESH_PATH destruiria o ponto de
	# isolamento de todas as suítes seguintes.
	_use_path(E2E_PATH)
	_give_iron(20)
	await _reach_level_two_for_real()
	await _open_mine_site_completing_it()
	_check(_invocation.summon_worker(), "§79 setup: Worker002 convocado")
	await _advance(0.1)
	_check(_save.save_campaign(), "§79 a campanha Nv.2 com Mina pronta é salva")
	await _reset_campaign()
	_use_path(E2E_PATH)
	_check(_save.load_campaign(), "§79 load da campanha Nv.2")
	var loaded := _workers()
	_check(loaded.size() == 2, "§79 dois Workers voltaram do arquivo, obtido %d" % loaded.size())
	_check(_core_state.level == FARM_LEVEL, "§79 o Nv.2 veio do arquivo")
	_check(_construction.mine() != null and _construction.mine().is_completed(),
			"§79 a Mina pronta veio do arquivo")
	_check(_stockpile.get_amount(ORE) >= FARM_COST, "§79 o minério veio do arquivo, %d"
			% _stockpile.get_amount(ORE))
	# §78: nenhum método de obra é chamado — a letra G decide.
	await _press_farm_key()
	_farm = _construction.fungal_farm()
	_check(_farm != null, "§79 G lançou o canteiro da Fazenda")
	if _farm == null:
		return
	_give_essence(ESSENCE_PER_CYCLE * 4.0)
	_selection.clear_selection()
	await _click_select(loaded[0])
	await _shift_click_select(loaded[1])
	await _right_click(_farm.global_position)
	_check(loaded[0].is_building() and loaded[1].is_building(),
			"§79 os dois Workers caminharam para a obra por ordem real")
	_set_speed(2.0)
	var built := await _wait_until(func() -> bool: return _farm.is_completed(), 40.0)
	_set_speed(1.0)
	_check(built, "§79 a obra cooperativa concluiu a Fazenda")
	_check(_stockpile.get_amount(BIOMASS) == 0, "§79/§21 nada foi produzido de graça")
	var biomass := _stockpile.get_amount(BIOMASS)
	# §79 mede o ciclo, não a espera: sete segundos de mundo e nada, o oitavo segundo e X+1.
	# A Essência é congelada porque no Nv.2 a regen (1.5/s) já supera o gasto da Fazenda
	# (0.5/s): sem congelar, o saldo subiria e o teste mediria a regen, não o pagamento.
	await _world(FARM_INTERVAL - 1.0)
	_check(_stockpile.get_amount(BIOMASS) == biomass,
			"§79/§38 antes do intervalo o saldo ainda é X=%d, obtido %d"
					% [biomass, _stockpile.get_amount(BIOMASS)])
	_freeze_essence()
	_set_speed(SPEED)
	var essence := _core_state.essence
	var plus_one := await _wait_for_biomass(biomass + FARM_AMOUNT, 3.0)
	_check(plus_one and _stockpile.get_amount(BIOMASS) == biomass + FARM_AMOUNT,
			"§79 8 s depois o saldo é X+1, obtido %d contra X=%d"
					% [_stockpile.get_amount(BIOMASS), biomass])
	_check(_close(essence - _core_state.essence, ESSENCE_PER_CYCLE),
			"§79 e a Essência pagou o ciclo, de %f para %f"
					% [essence, _core_state.essence])
	await _wait_for_biomass(biomass + 2 * FARM_AMOUNT, FARM_INTERVAL + 3.0)
	_resume_essence()
	_check(_stockpile.get_amount(BIOMASS) == biomass + 2 * FARM_AMOUNT,
			"§79 aos 16 s o saldo é X+2, obtido %d" % _stockpile.get_amount(BIOMASS))
	_check(_pile_count() == 0, "§79/§24 o caminho todo sem nenhum monte")
	_set_speed(1.0)
	_measurements["e2e_x"] = biomass
	_measurements["e2e_x_plus_2"] = _stockpile.get_amount(BIOMASS)


# ============================================ Bloco 3 — a Fazenda no arquivo (schema V3)


## §53–§57/§50/§51: a obra incompleta volta incompleta com o relógio em zero, e a obra pronta
## volta com o ciclo no meio — sem produzir durante a carga.
func _test_farm_save_incomplete_and_complete() -> void:
	# ---- §53: incompleta
	await _reset_campaign()
	# Canteiro aberto, sem concluir: a obra fica com 2.5 de trabalho faltando.
	await _open_farm_site(FARM_COST, 0.0, ESSENCE_PER_CYCLE * 2.0)
	_farm.state.apply_work(FARM_WORK - 2.5)
	await _advance(0.05)
	_use_path(INCOMPLETE_PATH)
	_check(_save.save_campaign(), "§53 save da Fazenda incompleta")
	var record := _farm_record_from_file(INCOMPLETE_PATH)
	_check(bool(record[CampaignSnapshot.KEY_EXISTS]), "§53 constructions.fungal_farm existe=true")
	_check(String(record["fungal_farm_id"]) == FARM_ID, "§53 o id gravado é fungal_farm_001, %s"
			% [record["fungal_farm_id"]])
	_check(_close(float(record[CampaignSnapshot.KEY_REMAINING_WORK]), 2.5),
			"§53 remaining_work salvo 2.5, obtido %s"
					% [record[CampaignSnapshot.KEY_REMAINING_WORK]])
	_check(_close(float(record[CampaignSnapshot.KEY_PRODUCTION_ELAPSED]), 0.0),
			"§50/§11 obra incompleta grava relógio zero, obtido %s"
					% [record[CampaignSnapshot.KEY_PRODUCTION_ELAPSED]])
	_check(CampaignSnapshot.decode_position(record[CampaignSnapshot.KEY_POSITION])
			.is_equal_approx(FARM_BUILD_POINT), "§53 a posição salva é a do canteiro")

	await _reset_campaign()
	_check(_construction.fungal_farm() == null, "§65 a campanha de origem não tem Fazenda depois do reset")
	_use_path(INCOMPLETE_PATH)
	_farm_built_events = 0
	_farm_completed_events = 0
	_check(_save.load_campaign(), "§53 load da Fazenda incompleta")
	_farm = _construction.fungal_farm()
	_check(_farm != null, "§65/§63 o canteiro voltou montado")
	if _farm != null:
		_check(_close(_farm.state.remaining_work, 2.5),
				"§53 o mesmo trabalho restante, obtido %f" % _farm.state.remaining_work)
		_check(_close(_farm_clock(), 0.0), "§53/§50 o relógio continua zero")
		_check(not _farm.is_processing(), "§65/§20 incompleta não roda processo depois do load")
	_check(_farm_built_events == 1, "§63 fungal_farm_built uma vez pela rota de carga, %d"
			% _farm_built_events)
	_check(_farm_completed_events == 0, "§63 nenhuma conclusão falsa no load, %d"
			% _farm_completed_events)
	_check(_stockpile.get_amount(BIOMASS) == 0,
			"§63/§53 a carga não cobra o custo nem produz, obtido %d"
					% _stockpile.get_amount(BIOMASS))

	# ---- §54/§55/§67: completa, com o ciclo no meio
	_give_essence(ESSENCE_PER_CYCLE * 3.0)
	_farm.state.apply_work(2.5)
	await _advance(0.05)
	_set_speed(SPEED)
	await _world(5.0)
	_set_speed(1.0)
	var elapsed := _farm_clock()
	_check(elapsed > 4.5 and elapsed < FARM_INTERVAL,
			"§54 o relógio pegou %f s de ciclo" % elapsed)
	_use_path(COMPLETE_PATH)
	var biomass_before := _stockpile.get_amount(BIOMASS)
	var essence_before := _core_state.essence
	_check(_save.save_campaign(), "§54 save da Fazenda operacional")
	var complete := _farm_record_from_file(COMPLETE_PATH)
	_check(_close(float(complete[CampaignSnapshot.KEY_REMAINING_WORK]), 0.0),
			"§51 obra concluída grava remaining_work 0")
	_check(_close(float(complete[CampaignSnapshot.KEY_PRODUCTION_ELAPSED]), elapsed, 0.1),
			"§55/§51 production_elapsed salvo %s contra %f"
					% [complete[CampaignSnapshot.KEY_PRODUCTION_ELAPSED], elapsed])
	_check(not complete.has("essence"),
			"§57 a Essência não é duplicada no registro da Fazenda, obtido %s"
					% [complete.keys()])
	await _reset_campaign()
	_use_path(COMPLETE_PATH)
	_farm_built_events = 0
	_farm_completed_events = 0
	_check(_save.load_campaign(), "§54 load da Fazenda operacional")
	_farm = _construction.fungal_farm()
	_check(_farm != null and _farm.is_completed(), "§54 a Fazenda voltou concluída")
	_check(_farm.is_processing(), "§64/§20 a Fazenda restaurada volta produzindo")
	var restored := _farm_clock()
	_check(_close(restored, elapsed, 0.15),
			"§54/§55 o ciclo voltou no número salvo, %f contra %f" % [restored, elapsed])
	_check(_stockpile.get_amount(BIOMASS) == biomass_before,
			"§63/§52 nenhuma Biomassa do passado — sem offline progress, obtido %d"
					% _stockpile.get_amount(BIOMASS))
	_check(_core_state.essence <= essence_before + 0.5,
			"§57/§52 a carga não gastou Essência retroativa, de %f para %f"
					% [essence_before, _core_state.essence])
	_check(_farm_completed_events == 0, "§64 fungal_farm_completed não é reemitido pela carga")
	# §67: falta só o resto do ciclo para a próxima Biomassa.
	_give_essence(ESSENCE_PER_CYCLE)
	_set_speed(SPEED)
	var remaining := FARM_INTERVAL - restored
	await _world(maxf(remaining - 0.3, 0.0))
	_check(_stockpile.get_amount(BIOMASS) == biomass_before,
			"§67 antes do resto do ciclo nada chegou, faltavam %f s" % remaining)
	var next := await _wait_for_biomass(biomass_before + FARM_AMOUNT, 4.0)
	_check(next and _stockpile.get_amount(BIOMASS) == biomass_before + FARM_AMOUNT,
			"§67/§52 o ciclo retoma do número salvo")
	_set_speed(1.0)
	_measurements["elapsed_antes_do_load"] = elapsed
	_measurements["elapsed_depois_do_load"] = restored


## §56/§23: um relógio saturado (elapsed == interval, ciclo pronto esperando Essência) é um
## save válido — a faixa é inclusiva no topo justamente por causa da fome.
func _test_farm_save_starved() -> void:
	await _reset_campaign()
	await _open_farm_site(FARM_COST, FARM_WORK, 0.0)
	_freeze_essence()
	_drain_essence()
	_set_speed(SPEED)
	await _world(FARM_INTERVAL + 2.0)
	_set_speed(1.0)
	_check(_close(_farm_clock(), FARM_INTERVAL), "§23 setup: relógio saturado no ciclo pronto")
	_use_path(STARVED_PATH)
	_check(_save.save_campaign(), "§56 uma Fazenda faminta é salva")
	var record := _farm_record_from_file(STARVED_PATH)
	_check(_close(float(record[CampaignSnapshot.KEY_PRODUCTION_ELAPSED]), FARM_INTERVAL, 0.01),
			"§56/§23 o ciclo pronto é gravado como 8.0, obtido %s"
					% [record[CampaignSnapshot.KEY_PRODUCTION_ELAPSED]])
	# §56: o contrato aceita explicitamente o topo da faixa — e o Controller de save também.
	_check(CampaignSnapshot.validate_document(CampaignSnapshot.parse_document(
			_read_text(STARVED_PATH))).is_empty(),
			"§56/§23 o ciclo pronto (8.0) é um documento V3 válido")
	await _reset_campaign()
	_freeze_essence()
	_drain_essence()
	_use_path(STARVED_PATH)
	_check(_save.load_campaign(), "§56 load da Fazenda faminta")
	_farm = _construction.fungal_farm()
	_check(_farm != null and _farm.is_completed(), "§56 a Fazenda voltou concluída")
	_check(_close(_farm_clock(), FARM_INTERVAL, 0.05),
			"§56/§23 o ciclo pronto voltou pronto, obtido %f" % _farm_clock())
	_check(_stockpile.get_amount(BIOMASS) == 0, "§56 nada foi produzido sem Essência")
	# §46: a energia chegou depois do load — o ciclo pronto fecha.
	_give_essence(ESSENCE_PER_CYCLE)
	await _advance(0.05)
	_check(_stockpile.get_amount(BIOMASS) == FARM_AMOUNT,
			"§46 o ciclo pronto restaurado fechou ao chegar Essência, obtido %d"
					% _stockpile.get_amount(BIOMASS))
	_resume_essence()


## §74/§105/§66/§67/§52: o roundtrip não move nada, e cinco cargas do mesmo arquivo não
## criam segunda Fazenda nem multiplicam produção.
func _test_roundtrip_and_repeated_loads() -> void:
	await _reset_campaign()
	await _open_farm_site(FARM_COST + 4, FARM_WORK, ESSENCE_PER_CYCLE * 4.0)
	_set_speed(SPEED)
	await _world(3.0)
	_set_speed(1.0)
	_use_path(ROUNDTRIP_PATH)
	# Sem frame entre as três operações: o que se compara é o arquivo, não o mundo.
	var snapshot_a := _normalize(_save.snapshot_campaign())
	_check(_save.save_campaign(), "§74 save A da Fazenda em ciclo")
	_check(_save.load_campaign(), "§74 load")
	_check(_save.save_campaign(), "§74 save B")
	var snapshot_b := _normalize(_save.snapshot_campaign())
	_check(snapshot_a == snapshot_b, "§74/§105 campaign A == campaign B")
	var written := _document_from_file(ROUNDTRIP_PATH)
	_check(int(written[CampaignSnapshot.ROOT_VERSION]) == CampaignSnapshot.SAVE_VERSION,
			"§74/§52 o roundtrip continua V3, obtido %s"
					% [written[CampaignSnapshot.ROOT_VERSION]])

	_use_path(REPEAT_PATH)
	_check(_save.save_campaign(), "§104 save da carga repetida")
	var before := _normalize(_save.snapshot_campaign())
	# A obra montada tem três ouvintes do `construction_completed`: a troca de visual da base,
	# o `_sync_production` do FungalFarmRuntime e o `_on_fungal_farm_completed` do controller.
	# O que §66 proíbe é o quarto — o acumulador que uma recarga com `connect()` a mais
	# produziria.
	var listeners := _connections_of(_farm.state.construction_completed)
	_check(listeners == 3, "§66 a Fazenda montada tem três ouvintes, obtido %d" % listeners)
	for attempt in range(1, 6):
		_check(_save.load_campaign(), "§104 carga %d devolve true" % attempt)
	_check(_farm_count() == 1, "§66/§104 cinco cargas, uma Fazenda, obtido %d" % _farm_count())
	_check(_normalize(_save.snapshot_campaign()) == before,
			"§66 o snapshot não deriva com as cargas")
	_check(_connections_of(_farm.state.construction_completed) == listeners,
			"§66 carga repetida não acumulou ouvintes, obtido %d"
					% _connections_of(_farm.state.construction_completed))
	_give_essence(ESSENCE_PER_CYCLE)
	var biomass := _stockpile.get_amount(BIOMASS)
	_set_speed(SPEED)
	await _world(FARM_INTERVAL + 0.5)
	_set_speed(1.0)
	_check(_stockpile.get_amount(BIOMASS) == biomass + FARM_AMOUNT,
			"§67/§104 oito segundos depois de cinco cargas = uma Biomassa, obtido +%d"
					% (_stockpile.get_amount(BIOMASS) - biomass))


## §58/§60/§70: o arquivo V2 migra para V3, e na campanha migrada a Fazenda é simplesmente a
## obra que ainda não foi feita. A prova byte a byte do fixture congelado está em
## test_save_load.gd (§56); aqui importa a consequência econômica da migração.
func _test_v2_migration_opens_the_farm() -> void:
	await _reset_campaign()
	_give_iron(20)
	await _reach_level_two_for_real()
	await _open_mine_site_completing_it()
	_check(_core_state.level == FARM_LEVEL, "§70 setup: campanha Nv.2 com Mina pronta")
	# Uma campanha V2 real é a V3 de agora, com a seção da Fazenda arrancada.
	var campaign := _save.snapshot_campaign()
	var constructions: Dictionary = campaign[CampaignSnapshot.SECTION_CONSTRUCTIONS]
	_check(constructions.has(CampaignSnapshot.SECTION_FUNGAL_FARM),
			"§58 o snapshot V3 traz a Fazenda")
	constructions.erase(CampaignSnapshot.SECTION_FUNGAL_FARM)
	_check(CampaignSnapshot.validate_v2(campaign).is_empty(),
			"§60 a mesma campanha sem a Fazenda é um V2 válido, motivo %s"
					% [CampaignSnapshot.validate_v2(campaign)])
	_check(not CampaignSnapshot.validate_v3(campaign).is_empty(),
			"§60/§58 como V3 a mesma campanha é recusada: %s"
					% [CampaignSnapshot.validate_v3(campaign)])
	var document := {
		CampaignSnapshot.ROOT_FORMAT: CampaignSnapshot.SAVE_FORMAT,
		CampaignSnapshot.ROOT_VERSION: CampaignSnapshot.SAVE_VERSION_V2,
		CampaignSnapshot.ROOT_METADATA: {"saved_at_unix": 1759172340, "probe": "suíte"},
		CampaignSnapshot.ROOT_CAMPAIGN: campaign,
	}
	_check(_write_text(V2_PATH, CampaignSnapshot.to_text(document)), "§60 o V2 foi escrito")
	_use_path(V2_PATH)
	_check(_save.load_campaign(), "§60/§58 o V2 carrega pela migração")
	_check(_construction.fungal_farm() == null, "§60/§58 a migração não inventou Fazenda")
	_check(_construction.mine() != null and _construction.mine().is_completed(),
			"§60 a Mina do V2 voltou concluída")
	_check(_core_state.level == FARM_LEVEL, "§60 o Nv.2 do arquivo chegou")
	_give_iron(FARM_COST)
	await _press_farm_key()
	_farm = _construction.fungal_farm()
	_check(_farm != null, "§70 a campanha migrada pode construir a Fazenda")
	# §59: o save que vem depois já é V3, e diz a verdade sobre a Fazenda que existe agora.
	_use_path(PRIMARY_PATH)
	_check(_save.save_campaign(), "§59 re-save da campanha migrada")
	var resaved := _document_from_file(PRIMARY_PATH)
	_check(int(resaved[CampaignSnapshot.ROOT_VERSION]) == CampaignSnapshot.SAVE_VERSION,
			"§59/§58 o re-save publica V3, obtido %s" % [resaved[CampaignSnapshot.ROOT_VERSION]])
	var saved_farm: Dictionary = (resaved[CampaignSnapshot.ROOT_CAMPAIGN] as Dictionary)[
			CampaignSnapshot.SECTION_CONSTRUCTIONS][CampaignSnapshot.SECTION_FUNGAL_FARM]
	_check(bool(saved_farm[CampaignSnapshot.KEY_EXISTS]),
			"§59 a Fazenda real aparece no V3, obtido %s" % [saved_farm])
	_check(_close(float(saved_farm[CampaignSnapshot.KEY_PRODUCTION_ELAPSED]), 0.0),
			"§50/§59 canteiro grava relógio zero, obtido %s"
					% [saved_farm[CampaignSnapshot.KEY_PRODUCTION_ELAPSED]])


## §61/§62: um arquivo V1 atravessa a corrente inteira (V1→V2→V3) e chega com Mina e Fazenda
## inexistentes, prontas para serem construídas.
func _test_v1_migration_reaches_v3() -> void:
	await _reset_campaign()
	_give_iron(20)
	await _reach_level_two_for_real()
	# Uma campanha V1 real é a V3 de agora, sem Mina e sem Fazenda.
	var campaign := _save.snapshot_campaign()
	(campaign[CampaignSnapshot.SECTION_CONSTRUCTIONS] as Dictionary) \
			.erase(CampaignSnapshot.SECTION_MINE)
	(campaign[CampaignSnapshot.SECTION_CONSTRUCTIONS] as Dictionary) \
			.erase(CampaignSnapshot.SECTION_FUNGAL_FARM)
	_check(CampaignSnapshot.validate_v1(campaign).is_empty(),
			"§61 a mesma campanha sem Mina nem Fazenda é um V1 válido, motivo %s"
					% [CampaignSnapshot.validate_v1(campaign)])
	var document := {
		CampaignSnapshot.ROOT_FORMAT: CampaignSnapshot.SAVE_FORMAT,
		CampaignSnapshot.ROOT_VERSION: CampaignSnapshot.SAVE_VERSION_V1,
		CampaignSnapshot.ROOT_METADATA: {"saved_at_unix": 1759172340, "probe": "corrente"},
		CampaignSnapshot.ROOT_CAMPAIGN: campaign,
	}
	_check(_write_text(V1_PATH, CampaignSnapshot.to_text(document)), "§61 o V1 foi escrito")
	_use_path(V1_PATH)
	_check(_save.load_campaign(), "§61/§58 o V1 carrega pela corrente inteira")
	_check(_construction.mine() == null, "§61 a corrente não inventou Mina")
	_check(_construction.fungal_farm() == null, "§61/§62 a corrente não inventou Fazenda")
	_check(_core_state.level == FARM_LEVEL, "§61 o Nv.2 do arquivo chegou")
	# §62: a campanha migrada percorre as duas obras até a Biomassa.
	await _open_mine_site_completing_it()
	_give_iron(FARM_COST)
	_check(_construction.build_fungal_farm(), "§62 a campanha migrada pode construir a Fazenda")
	_farm = _construction.fungal_farm()
	_farm.state.apply_work(FARM_WORK)
	_give_essence(ESSENCE_PER_CYCLE * 2.0)
	await _advance(0.05)
	_set_speed(SPEED)
	var grown := await _wait_for_biomass(1, 4.0)
	_set_speed(1.0)
	_check(grown and _stockpile.get_amount(BIOMASS) >= FARM_AMOUNT,
			"§62 a campanha migrada produz Biomassa, obtido %d"
					% _stockpile.get_amount(BIOMASS))
	# §59: o re-save sai V3 com as duas obras reais.
	_use_path(PRIMARY_PATH)
	_check(_save.save_campaign(), "§59 re-save V3 da campanha migrada")
	var resaved := _document_from_file(PRIMARY_PATH)
	_check(int(resaved[CampaignSnapshot.ROOT_VERSION]) == CampaignSnapshot.SAVE_VERSION,
			"§59 o re-save publica V3, obtido %s" % [resaved[CampaignSnapshot.ROOT_VERSION]])
	var saved: Dictionary = (resaved[CampaignSnapshot.ROOT_CAMPAIGN] as Dictionary)[
			CampaignSnapshot.SECTION_CONSTRUCTIONS]
	_check(bool((saved[CampaignSnapshot.SECTION_MINE] as Dictionary)[
			CampaignSnapshot.KEY_EXISTS]), "§59 a Mina real aparece no V3")
	_check(bool((saved[CampaignSnapshot.SECTION_FUNGAL_FARM] as Dictionary)[
			CampaignSnapshot.KEY_EXISTS]), "§59 a Fazenda real aparece no V3")


## §57/§103/§105: versão que o contrato não conhece é recusada antes de tocar em qualquer
## número, inclusive quando é o número do futuro.
func _test_future_version_touches_nothing() -> void:
	await _reset_campaign()
	await _open_mine_site_completing_it()
	_give_iron(FARM_COST + 4)
	_check(_construction.build_fungal_farm(), "setup: Fazenda no mundo")
	_farm = _construction.fungal_farm()
	await _advance(0.05)
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
	_check(not _failed_events.is_empty(), "§105 a recusa anunciou o motivo, %s" % [_failed_events])
	_check(_snapshot_text() == world_before, "§103/§105 o mundo intacto diante do futuro")
	_check(_farm_count() == 1, "§103 a Fazenda da partida não foi tocada, obtido %d"
			% _farm_count())
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
	_farm_built_events = 0
	_farm_completed_events = 0
	await _advance(0.05)


## Lança a Mina como CANTEIRO (não conclui) — o estado intermediário entre "sem Mina" e
## "Mina pronta", que é a segunda porta da Fazenda.
func _open_mine_site(iron_amount: int) -> void:
	if _core_state.level < FARM_LEVEL:
		_core.evolve_to(_core_lv2)
	_give_iron(iron_amount)
	_farm_built_events = 0
	_farm_completed_events = 0
	_check(_construction.build_mine(), "setup: Mina lançada com %d minérios" % iron_amount)
	await _advance(0.05)


## Lança a Mina e a conclui pela regra da base — a primeira obra da economia mineral, que é
## a segunda porta da Fazenda. Idempotente: se a Mina já existe (de um teste anterior na
## mesma campanha), só garante que ela esteja concluída. Se não há ferro para lançá-la, o
## setup entrega os seis — o que este helper testa é a porta da Fazenda, não o custo da Mina.
func _open_mine_site_completing_it() -> void:
	if _core_state.level < FARM_LEVEL:
		_core.evolve_to(_core_lv2)
	if _construction.mine() == null:
		if _stockpile.get_amount(ORE) < 6:
			_give_iron(6)
		_check(_construction.build_mine(), "setup: Mina lançada")
	_construction.mine().state.apply_work(8.0)
	await _advance(0.05)


## Abre um canteiro de Fazenda pronto para medir. `iron_amount` é o ferro entregue DEPOIS
## de a Mina já ter custado os seis dela — a pré-condição é construída aqui, não cobrada do
## chamador. `essence` negativa significa "sem Essência".
func _open_farm_site(iron_amount: int, work: float, essence: float = -1.0) -> void:
	if _core_state.level < FARM_LEVEL:
		_core.evolve_to(_core_lv2)
	if _construction.mine() == null:
		_give_iron(6)
		_check(_construction.build_mine(), "setup: Mina lançada como pré-requisito")
	_construction.mine().state.apply_work(8.0)
	_give_iron(iron_amount)
	if essence >= 0.0:
		_give_essence(essence)
	_farm_built_events = 0
	_farm_completed_events = 0
	_check(_construction.build_fungal_farm(), "setup: Fazenda lançada")
	_farm = _construction.fungal_farm()
	if work > 0.0 and _farm != null:
		_farm.state.apply_work(work)
	await _advance(0.05)


func _farm_clock() -> float:
	return (_farm.state as FungalFarmState).production_elapsed


func _set_speed(value: float) -> void:
	_speed = value
	Engine.time_scale = value


func _world(seconds: float) -> void:
	await _advance(seconds / _speed)


func _measure_work_rate() -> float:
	var before := _farm.state.remaining_work
	await _advance(1.0)
	return before - _farm.state.remaining_work


func _reset_campaign() -> void:
	_use_path(FRESH_PATH)
	_check(_save.load_campaign(), "setup: a carga de isolamento devolve a campanha do boot")
	_farm = _construction.fungal_farm()
	await _advance(0.1)


func _give_iron(amount: int) -> void:
	_stockpile.add_resource(_iron, amount)


func _give_essence(amount: float) -> void:
	_core_state.add_essence(amount)


## §43/§44: esvazia a Essência do Núcleo. O Núcleo regenera 1.0/s, então a janela de
## observação da fome tem de ser curta o bastante para a regeneração não pagar um ciclo
## (4.0 de Essência = 4 s) — é assim que o mundo real se comporta, e a suíte mede o mundo.
func _drain_essence() -> void:
	_core_state.consume_essence(_core_state.essence)


## §19/§47/§48: congela a regeneração do Núcleo para medir o consumo da Fazenda como um
## orçamento fechado. O Runtime do Núcleo regenera 1.5/s no Nv.2, o que mascararia o gasto de
## 4.0 por ciclo; desligado o processo, `essência inicial - final` É o que a Fazenda pagou.
func _freeze_essence() -> void:
	_core.set_process(false)


func _resume_essence() -> void:
	_core.set_process(true)


func _use_path(path: String) -> void:
	_save.configure_save_path(path)


func _on_farm_built(_farm: FungalFarmRuntime) -> void:
	_farm_built_events += 1


func _on_farm_completed(_farm: FungalFarmRuntime) -> void:
	_farm_completed_events += 1


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


func _farm_count() -> int:
	var total := 0
	for child in _dungeon.get_children():
		if child is FungalFarmRuntime:
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


## §75: a letra G entra pelo caminho do sistema operacional — InputMap casa a ação, o estado
## polled é atualizado e `_unhandled_input` decide a jogada.
func _press_farm_key() -> void:
	var pressed := InputEventKey.new()
	pressed.physical_keycode = KEY_G
	pressed.pressed = true
	Input.parse_input_event(pressed)
	var released := InputEventKey.new()
	released.physical_keycode = KEY_G
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
## canteiro, cada um em um ponto próprio. A viagem pertence ao E2E. Sobrepostos, os dois
## bodies ocupariam o mesmo pixel e o clique alternaria a seleção em vez de somá-la.
## §95/§96: o tempo medido é o de trabalho puro — os Workers são estacionados ao lado do
## canteiro, cada um em um ponto próprio, exatamente como test_abyssal_mine.gd faz com a Mina.
## A diferença é de geometria, não de obra: a Mina fica no centro do campo (x=0) e o estaciona-
## mento a +X projeta fora do corpo dela; a Fazenda fica em x=10, perto da borda comprimida pelo
## tilt, e o mesmo +X cairia dentro da pegada na tela. Por isso o estacionamento aqui é do lado
## do Núcleo (−X), onde o Worker projeta longe o bastante para o ray de seleção alcançá-lo.
func _park_near_farm(worker: WorkerRuntime, z_offset: float) -> void:
	var parked := _farm.global_position \
			+ Vector3(-WORKER_BUILD_GAP, 0.0, z_offset)
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
		closest = minf(closest, _planar_gap(point, FARM_BUILD_POINT))
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


func _wait_for_biomass(target: int, max_seconds: float) -> bool:
	return await _wait_until(
			func() -> bool: return _stockpile.get_amount(BIOMASS) >= target, max_seconds)


func _text_of(root_node: Node, label_name: String) -> String:
	var label := root_node.find_child(label_name, true, false) as Label
	if label == null:
		return "<ausente>"
	return label.text


# ============================================================ arquivo, fonte e medições


func _farm_record_from_file(path: String) -> Dictionary:
	var document := _document_from_file(path)
	var constructions: Dictionary = document[CampaignSnapshot.ROOT_CAMPAIGN][
			CampaignSnapshot.SECTION_CONSTRUCTIONS]
	return constructions[CampaignSnapshot.SECTION_FUNGAL_FARM]


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
	_farm_build_point = _scene.get_node("World/DungeonRoot/FungalFarmBuildPoint") as Marker3D
	var deposit := _scene.get_node("World/DungeonRoot/Deposit001") as ResourceDepositRuntime
	_stockpile = deposit.stockpile
	_core_state = _core.core_state()
	_crystal = _evolution.abyssal_crystal_state()
	_farm_hud = _scene.get_node("UI/ConstructionDebugPanel")
	_resource_hud = _scene.get_node("UI/ResourceDebugPanel")
	_mine_hud = _scene.get_node("UI/ResourceDebugPanel")
	_iron = load(IRON_ORE_PATH) as ResourceDefinition
	_biomass = load(BIOMASS_PATH) as ResourceDefinition
	_core_lv2 = load(CORE_LV2_PATH) as CoreDefinition
	_player_before = _presence(PLAYER_PRIMARY)
	_player_backup_before = _presence(PLAYER_BACKUP)
	_construction.fungal_farm_built.connect(_on_farm_built)
	_construction.fungal_farm_completed.connect(_on_farm_completed)
	_save.load_succeeded.connect(_on_load_succeeded)
	_save.operation_failed.connect(_on_operation_failed)
	Engine.set_physics_ticks_per_second(TICKS)
	_use_path(FRESH_PATH)
	_check(_save.save_campaign(), "setup: a campanha do boot virou o pristine da suíte")


func _free_scene() -> void:
	_farm = null
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


## §121/T18: o que a suíte criou em user://tests/ desaparece, e o save do jogador não é
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
			"§121 nenhum arquivo de teste sobreviveu, restaram %s" % [survivors])
	_check(DirAccess.open(TEST_DIR) == null, "§121 o diretório da suíte não fica para trás")


func _test_player_save_untouched() -> void:
	_check(_presence(PLAYER_PRIMARY) == _player_before
			and _presence(PLAYER_BACKUP) == _player_backup_before,
			"§121 o save real do jogador não foi tocado: %s → %s"
					% [_player_before, _presence(PLAYER_PRIMARY)])
	for path in TEST_PATHS:
		_check(path.begins_with("user://tests/"),
				"§121 todo caminho de teste está isolado, obtido %s" % path)
	_check(_save == null, "§122 a suíte não guarda referência a nenhum Node já libertado")


func _print_measurements() -> void:
	print("[INFO] medições da Fazenda Fúngica: %s" % [_measurements])


func _check(condition: bool, label: String) -> void:
	_asserts += 1
	if condition:
		print("[PASS] %s" % label)
	else:
		_failures += 1
		print("[FAIL] %s" % label)


func _finish() -> void:
	print("---- biomass fungal farm tests finished: %d asserts, %d failure(s) ----"
			% [_asserts, _failures])
	quit(1 if _failures > 0 else 0)
