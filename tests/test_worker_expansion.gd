extends SceneTree

# Tarefa 22 — Worker003 e a primeira expansão populacional por Biomassa.
#
# A pergunta desta suíte é a do princípio da tarefa: depois de aprender a converter Essência
# em matéria viva (Tarefa 21), o Núcleo aprende a dar CORPO a um servo com essa matéria. O
# terceiro Trabalhador custa Biomassa (corpo) e Essência (alma), só existe a partir do Nv.2
# e só existe uma vez. Cada cenário mede estoque, Essência, população e mundo.
#
# Quatro blocos, nesta ordem:
#   1) contrato e guarda de fonte — a Definition existe sozinha, sem cena, com os números da
#      tarefa; o worker_003 tem exatamente dois donos (controller e contrato do Save); o
#      controller do segundo Worker não foi tocado; a tecla U existe no InputMap;
#   2) as portas — Nv.1, Biomassa, Essência e capacidade fecham a invocação sem cobrar nada,
#      e o painel diz qual porta está fechada;
#   3) a invocação real — a tecla U invoca uma única vez, cobra Biomassa e Essência exatas,
#      soma uma população e o novo servo trabalha; o segundo Worker continua independente;
#   4) persistência V4 — o terceiro Worker salva e volta, load repetido não duplica, e as
#      correntes V3→V4 e V1→V2→V3→V4 abrem justamente a rota dele; arquivos contraditórios
#      são recusados com o mundo intacto.
#
# Todo arquivo mora em `user://tests/worker_expansion/` e desaparece no fim (§121/T18).

const MAIN_SCENE := preload("res://game/GameMain.tscn")

const EXPANSION_DEFINITION_PATH := "res://data/units/workers/abyss_worker_expansion.tres"
const EXPANSION_DEFINITION_SOURCE := "res://core/definitions/worker_expansion_definition.gd"
const EXPANSION_CONTROLLER_SOURCE := "res://systems/population/worker_expansion_controller.gd"
const INVOCATION_CONTROLLER_SOURCE := "res://systems/population/worker_invocation_controller.gd"
const SNAPSHOT_SOURCE := "res://systems/persistence/campaign_snapshot.gd"
const SAVE_CONTROLLER_SOURCE := "res://systems/persistence/save_game_controller.gd"
const GAME_MAIN_SOURCE := "res://game/game_main.gd"
const PROJECT_SOURCE := "res://project.godot"
const CI_SOURCE := "res://.github/workflows/ci.yml"
const V3_DOC := "res://docs/SAVE_SCHEMA_V3.md"
const V4_DOC := "res://docs/SAVE_SCHEMA_V4.md"
const IRON_ORE_PATH := "res://data/resources/iron_ore.tres"
const BIOMASS_PATH := "res://data/resources/biomass.tres"
const CORE_LV2_PATH := "res://data/core/core_level_2.tres"

const TEST_DIR := "user://tests/worker_expansion"
const FRESH_PATH := "user://tests/worker_expansion/pristine.json"
const PRIMARY_PATH := "user://tests/worker_expansion/campaign.json"
const WITH_THIRD_PATH := "user://tests/worker_expansion/com_terceiro.json"
const WITHOUT_THIRD_PATH := "user://tests/worker_expansion/sem_terceiro.json"
const V3_PATH := "user://tests/worker_expansion/v3.json"
const V1_PATH := "user://tests/worker_expansion/v1.json"
const BAD_PATH := "user://tests/worker_expansion/contraditoria.json"
const E2E_PATH := "user://tests/worker_expansion/e2e.json"
const TEST_PATHS: Array[String] = [FRESH_PATH, PRIMARY_PATH, WITH_THIRD_PATH,
		WITHOUT_THIRD_PATH, V3_PATH, V1_PATH, BAD_PATH, E2E_PATH]

const PLAYER_PRIMARY := "user://campaign_save.json"
const PLAYER_BACKUP := "user://campaign_save.bak"

const ORE := &"iron_ore"
const BIOMASS := &"biomass"
const THIRD_ID := "worker_003"
const SECOND_ID := "worker_002"

## Os números que a tarefa fixou. Vêm da Definition, e esta suíte confere o arquivo — um
## valor alterado sem teste precisa falhar.
const BIOMASS_COST := 3
const ESSENCE_COST := 10.0
const REQUIRED_LEVEL := 2

## Textos do painel, copiados da produção de propósito: se a linha sair do lugar, a suíte
## denuncia em vez de acompanhar.
const HUD_HINT := "[U] Invocar Trabalhador Abissal — 3 Biomassa + 10 Essência"
const HUD_LEVEL := "Terceiro trabalhador: requer Núcleo Nv.2"
const HUD_CAPACITY := "Terceiro trabalhador: capacidade cheia"
const HUD_BIOMASS := "Terceiro trabalhador: Biomassa insuficiente"
const HUD_ESSENCE := "Terceiro trabalhador: Essência insuficiente"
const HUD_READY := "Terceiro trabalhador: pronto"
const HUD_DONE := "Terceiro trabalhador invocado"

const TICKS := 60
const SPEED := 4.0
const ESSENCE_GRANT := 20.0
const FARM_INTERVAL := 8.0
const FARM_COST := 4
const FARM_WORK := 6.0

var _failures := 0
var _asserts := 0
var _frames := 0
var _measurements := {}
var _speed := 1.0

var _scene: Node
var _dungeon: Node3D
var _construction: ConstructionController
var _invocation: WorkerInvocationController
var _expansion: WorkerExpansionController
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
var _spawn_point: Marker3D
var _population_hud: Node

var _expanded_events := 0
var _failed_events: Array[String] = []
var _player_before := ""
var _player_backup_before := ""


func _initialize() -> void:
	_run_all()


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > 1500000:
		_check(false, "timeout: a suíte da expansão populacional não terminou")
		_finish()
	return false


func _run_all() -> void:
	# Bloco 1 — contrato e guardas de fonte. Sem cena.
	_test_definition_contract()
	_test_scope_guards()

	await _boot_scene()
	# Bloco 2 — as portas.
	await _test_level_one_gate_with_real_key()
	await _test_biomass_gate()
	await _test_essence_gate()
	await _test_capacity_gate()
	# Bloco 3 — a invocação real.
	await _test_real_key_summons_once_and_pays()
	await _test_third_worker_is_a_real_worker()
	await _test_second_worker_stays_independent()
	await _test_end_to_end_biomass_to_worker()
	# Bloco 4 — persistência V4.
	await _test_save_roundtrip_with_third_worker()
	await _test_load_without_third_removes_it()
	await _test_repeated_loads_never_duplicate()
	await _test_v3_migration_opens_the_expansion()
	await _test_v1_chain_reaches_v4()
	await _test_contradictory_files_are_refused()

	await _free_scene()
	_cleanup_test_files()
	_test_player_save_untouched()
	_print_measurements()
	_finish()


# ========================================= Bloco 1 — Definition e guardas de fonte


func _test_definition_contract() -> void:
	var definition := load(EXPANSION_DEFINITION_PATH) as WorkerExpansionDefinition
	_check(definition != null, "a receita da expansão é uma WorkerExpansionDefinition")
	if definition == null:
		return
	_check(definition.required_core_level == REQUIRED_LEVEL,
			"a expansão abre no Nv.%d, obtido %d" % [REQUIRED_LEVEL, definition.required_core_level])
	_check(definition.biomass_cost == BIOMASS_COST,
			"o corpo custa %d de Biomassa, obtido %d" % [BIOMASS_COST, definition.biomass_cost])
	_check(_close(definition.essence_cost, ESSENCE_COST),
			"a alma custa %.0f de Essência, obtido %f" % [ESSENCE_COST, definition.essence_cost])
	_check(definition.biomass_resource != null
			and definition.biomass_resource.resource_id == BIOMASS,
			"o recurso do corpo é a Biomassa genérica da Tarefa 21")
	_check(definition.biomass_resource == load(BIOMASS_PATH),
			"é a mesma Resource de biomass.tres, não uma cópia")
	_check(definition.display_name == "Trabalhador Abissal",
			"o servo invocado é um Trabalhador Abissal, obtido %s" % definition.display_name)
	# A unidade não tem corpo próprio: vida, velocidade e carga são da WorkerDefinition.
	var fields := _script_fields(definition)
	for forbidden in ["max_health", "move_speed", "work_speed", "carry_capacity", "unit_id"]:
		_check(not fields.has(forbidden),
				"a receita não duplica %s da WorkerDefinition nem a identidade do Save" % forbidden)


func _test_scope_guards() -> void:
	var sources := _collect_gd_files("res://")
	_check(not sources.is_empty(), "a varredura achou os fontes de produção")
	# O terceiro Worker tem exatamente dois donos: quem invoca e o contrato do arquivo.
	var owners := _files_containing(sources, "\"worker_003\"")
	owners.sort()
	_check(owners == [SNAPSHOT_SOURCE, EXPANSION_CONTROLLER_SOURCE],
			"worker_003 mora só no controller e no contrato do Save, obtido %s" % [owners])
	# O controller do segundo Worker não ganhou caminho novo.
	var invocation_code := _code_of(INVOCATION_CONTROLLER_SOURCE)
	_check(not invocation_code.contains("worker_003") and not invocation_code.contains("biomass"),
			"o WorkerInvocationController continua sendo só o do segundo Worker")
	_check(invocation_code.contains("const SUMMONED_UNIT_ID := \"worker_002\""),
			"o id do segundo Worker continua sendo worker_002")
	# Nenhuma gerência genérica de população.
	for forbidden in ["PopulationManager", "PopulationRegistry", "WorkerRoster", "UnitRegistry",
			"SpawnManager", "WorkerFactory", "SummonQueue", "RecipeSystem", "CostDefinition"]:
		_check(_files_named(sources, forbidden).is_empty(),
				"nenhum fonte se chama %s" % forbidden)
		_check(_files_containing(sources, "class_name %s" % forbidden).is_empty(),
				"nenhuma classe %s foi declarada" % forbidden)
	var controller_code := _code_of(EXPANSION_CONTROLLER_SOURCE)
	_check(not controller_code.contains("get_node(") and not controller_code.contains("find_child(")
			and not controller_code.contains("get_tree()"),
			"o controller recebe tudo por injeção, sem procurar na árvore")
	_check(not controller_code.contains("\"U\"") and not controller_code.contains("KEY_U"),
			"nenhuma tecla física hardcoded no controller")
	# InputMap: a ação existe e a letra U a dispara.
	_check(_source(PROJECT_SOURCE).contains("summon_expansion_worker="),
			"a ação summon_expansion_worker existe no project.godot")
	_check(InputMap.has_action(&"summon_expansion_worker"),
			"summon_expansion_worker está registrada no runtime")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_U
	_check(InputMap.event_is_action(key, &"summon_expansion_worker", false),
			"a tecla U dispara a ação summon_expansion_worker")
	for other in [&"summon_worker", &"build_nest", &"build_barracks"]:
		if InputMap.has_action(other):
			_check(not InputMap.event_is_action(key, other, false),
					"a tecla U não colide com %s" % other)
	# O contrato do arquivo subiu para V4, versão por versão, sem framework.
	var snapshot_code := _code_of(SNAPSHOT_SOURCE)
	for required in ["const SAVE_VERSION := 4", "const SAVE_VERSION_V3 := 3",
			"static func validate_v4(", "static func migrate_v3_to_v4(",
			"static func migrate_v2_to_v3(", "static func migrate_v1_to_v2("]:
		_check(snapshot_code.contains(required), "campaign_snapshot.gd contém %s" % required)
	_check(FileAccess.file_exists(V3_DOC), "docs/SAVE_SCHEMA_V3.md continua no projeto")
	_check(FileAccess.file_exists(V4_DOC), "docs/SAVE_SCHEMA_V4.md existe")
	var v4_text := _source(V4_DOC).to_lower()
	for documented in ["save_version", "worker_003", "worker_003_summoned", "v3", "v4",
			"migra", "biomassa", "essência"]:
		_check(v4_text.contains(documented), "o documento V4 documenta %s" % documented)
	# A suíte entra no CI por descoberta, não por lista.
	_check(not _source(CI_SOURCE).contains("worker_expansion"),
			"o workflow não lista suíte nenhuma — a descoberta é automática")
	_check(not _code_of(GAME_MAIN_SOURCE).contains("worker_003"),
			"a raiz de composição não conhece a identidade do terceiro Worker")


# ======================================================= Bloco 2 — as portas


func _test_level_one_gate_with_real_key() -> void:
	await _reset_campaign()
	_check(_core_state.level == 1, "setup: campanha do boot no Nv.1")
	_give_biomass(BIOMASS_COST * 2)
	_give_essence(ESSENCE_GRANT)
	var before := _snapshot_text()
	_check(_expansion.gate() == WorkerExpansionController.Gate.CORE_LEVEL,
			"no Nv.1 a primeira porta fechada é o nível do Núcleo")
	_check(_text_of(_population_hud, "ExpansionHintLabel") == HUD_HINT,
			"o painel anuncia a receita, obtido %s" % _text_of(_population_hud, "ExpansionHintLabel"))
	_check(_text_of(_population_hud, "ExpansionStatusLabel") == HUD_LEVEL,
			"o painel diz que falta o Nv.2, obtido %s"
					% _text_of(_population_hud, "ExpansionStatusLabel"))
	await _press_expansion_key()
	_check(_third_worker() == null, "a tecla U no Nv.1 não invoca nada")
	_check(not _expansion.worker_ever_expanded(), "a flag histórica continua false")
	_check(_expanded_events == 0, "nenhuma conquista anunciada")
	_check(_stockpile.get_amount(BIOMASS) == BIOMASS_COST * 2,
			"a Biomassa não foi cobrada, obtido %d" % _stockpile.get_amount(BIOMASS))
	_check(_snapshot_without_essence(_snapshot_text()) == _snapshot_without_essence(before),
			"o mundo não mudou além da regeneração da Essência")


func _test_biomass_gate() -> void:
	await _reset_campaign()
	_core.evolve_to(_core_lv2)
	await _advance(0.05)
	_give_biomass(BIOMASS_COST - 1)
	_give_essence(ESSENCE_GRANT)
	_check(_expansion.gate() == WorkerExpansionController.Gate.BIOMASS,
			"no Nv.2 com %d de Biomassa a porta fechada é a Biomassa" % (BIOMASS_COST - 1))
	await _advance(0.05)
	_check(_text_of(_population_hud, "ExpansionStatusLabel") == HUD_BIOMASS,
			"o painel diz que falta Biomassa, obtido %s"
					% _text_of(_population_hud, "ExpansionStatusLabel"))
	var population := _core_state.population
	_freeze_essence()
	var essence := _core_state.essence
	_check(not _expansion.summon_expansion_worker(), "sem Biomassa a invocação é recusada")
	_check(_stockpile.get_amount(BIOMASS) == BIOMASS_COST - 1,
			"recusar não cobra a Biomassa que existe, obtido %d" % _stockpile.get_amount(BIOMASS))
	_check(_close(_core_state.essence, essence), "recusar não cobra Essência")
	_check(_core_state.population == population, "recusar não soma população")
	_resume_essence()
	# A última unidade de Biomassa abre a porta seguinte.
	_give_biomass(1)
	await _advance(0.05)
	_check(_expansion.gate() == WorkerExpansionController.Gate.READY,
			"com %d de Biomassa e Essência a invocação fica pronta" % BIOMASS_COST)
	_check(_text_of(_population_hud, "ExpansionStatusLabel") == HUD_READY,
			"o painel acompanha o estoque, obtido %s"
					% _text_of(_population_hud, "ExpansionStatusLabel"))


func _test_essence_gate() -> void:
	await _reset_campaign()
	_core.evolve_to(_core_lv2)
	_give_biomass(BIOMASS_COST)
	_freeze_essence()
	_drain_essence()
	_give_essence(ESSENCE_COST - 1.0)
	await _advance(0.05)
	_check(_expansion.gate() == WorkerExpansionController.Gate.ESSENCE,
			"com Biomassa e sem Essência a porta fechada é a Essência")
	_check(_text_of(_population_hud, "ExpansionStatusLabel") == HUD_ESSENCE,
			"o painel diz que falta Essência, obtido %s"
					% _text_of(_population_hud, "ExpansionStatusLabel"))
	_check(not _expansion.summon_expansion_worker(), "sem Essência a invocação é recusada")
	_check(_stockpile.get_amount(BIOMASS) == BIOMASS_COST,
			"a transação é atômica: a Biomassa não sai sem a Essência, obtido %d"
					% _stockpile.get_amount(BIOMASS))
	_check(_close(_core_state.essence, ESSENCE_COST - 1.0),
			"a Essência parcial continua intacta, obtido %f" % _core_state.essence)
	_resume_essence()


func _test_capacity_gate() -> void:
	await _reset_campaign()
	_core.evolve_to(_core_lv2)
	_give_biomass(BIOMASS_COST)
	_give_essence(ESSENCE_GRANT)
	var original := _core_state.population
	var capacity := _core_state.get_population_capacity()
	_core_state.set_population(capacity)
	await _advance(0.05)
	_check(_expansion.gate() == WorkerExpansionController.Gate.CAPACITY,
			"com a população em %d/%d a porta fechada é a capacidade" % [capacity, capacity])
	_check(_text_of(_population_hud, "ExpansionStatusLabel") == HUD_CAPACITY,
			"o painel diz que a capacidade está cheia, obtido %s"
					% _text_of(_population_hud, "ExpansionStatusLabel"))
	_check(not _expansion.summon_expansion_worker(), "capacidade cheia recusa a invocação")
	_check(_stockpile.get_amount(BIOMASS) == BIOMASS_COST, "nada foi cobrado")
	_core_state.set_population(original)


# ================================================== Bloco 3 — a invocação real


func _test_real_key_summons_once_and_pays() -> void:
	await _reset_campaign()
	_core.evolve_to(_core_lv2)
	_give_biomass(BIOMASS_COST + 2)
	_give_essence(ESSENCE_GRANT)
	await _advance(0.05)
	_freeze_essence()
	var essence := _core_state.essence
	var population := _core_state.population
	_expanded_events = 0
	await _press_expansion_key()
	var third := _third_worker()
	_check(third != null, "a tecla U no Nv.2 invoca o terceiro Trabalhador")
	if third == null:
		_resume_essence()
		return
	_check(third == _expansion.expanded_worker(), "o controller guarda o Runtime invocado")
	_check(third.state.unit_id == THIRD_ID, "a identidade é worker_003, obtido %s"
			% third.state.unit_id)
	_check(_stockpile.get_amount(BIOMASS) == 2,
			"o corpo custou exatamente %d de Biomassa: %d → 2, obtido %d"
					% [BIOMASS_COST, BIOMASS_COST + 2, _stockpile.get_amount(BIOMASS)])
	_check(_close(essence - _core_state.essence, ESSENCE_COST),
			"a alma custou exatamente %.0f de Essência, de %f para %f"
					% [ESSENCE_COST, essence, _core_state.essence])
	_check(_core_state.population == population + 1,
			"a população subiu uma unidade: %d → %d" % [population, _core_state.population])
	_check(_expanded_events == 1, "worker_expanded foi emitido uma vez, obtido %d"
			% _expanded_events)
	_check(_expansion.worker_ever_expanded(), "a flag histórica virou true")
	_check(_planar_gap(third.global_position, _spawn_point.global_position) < 0.5,
			"o servo nasce no ponto de invocação, obtido %s" % third.global_position)
	_check(third.definition.unit_type_id == &"abyss_worker",
			"o corpo é o mesmo Trabalhador Abissal dos outros dois")
	_check(_text_of(_population_hud, "ExpansionStatusLabel") == HUD_DONE,
			"o painel registra a conquista, obtido %s"
					% _text_of(_population_hud, "ExpansionStatusLabel"))
	# Uma vez só, mesmo com recursos sobrando.
	_give_biomass(BIOMASS_COST)
	_give_essence(ESSENCE_GRANT)
	var biomass_before := _stockpile.get_amount(BIOMASS)
	var essence_before := _core_state.essence
	await _press_expansion_key()
	_check(_workers().size() == 2, "o segundo U não cria um quarto Worker, obtido %d"
			% _workers().size())
	_check(_stockpile.get_amount(BIOMASS) == biomass_before and
			_close(_core_state.essence, essence_before),
			"o segundo U não cobra nada")
	_check(_expanded_events == 1, "nenhuma segunda conquista anunciada")
	_check(_expansion.gate() == WorkerExpansionController.Gate.ALREADY_SUMMONED,
			"a porta fica fechada para sempre depois da invocação")
	_resume_essence()
	_measurements["population_after_third"] = _core_state.population


func _test_third_worker_is_a_real_worker() -> void:
	var third := _third_worker()
	_check(third != null, "setup: o terceiro Worker existe")
	if third == null:
		return
	var start := third.global_position
	third.move_to(start + Vector3(2.0, 0.0, 0.0))
	await _advance(1.5)
	_check(_planar_gap(third.global_position, start) > 1.0,
			"o terceiro Worker anda por ordem, como os outros, de %s para %s"
					% [start, third.global_position])
	_check(_close(third.definition.work_speed, _worker.definition.work_speed),
			"ele trabalha na mesma taxa do Worker001")
	# Ele soma na obra cooperativa: duas mãos rendem o dobro de uma.
	_core.evolve_to(_core_lv2)
	_give_iron(6)
	_check(_construction.build_mine(), "setup: Mina lançada para medir a obra")
	var mine := _construction.mine()
	var remaining := mine.state.remaining_work
	_park_near(third, mine.global_position)
	third.assign_construction_target(mine)
	await _advance(1.0)
	var done := remaining - mine.state.remaining_work
	_check(done > 0.5, "o terceiro Worker aplica trabalho na obra, obtido %f" % done)
	_measurements["third_worker_work_1s"] = done


func _test_second_worker_stays_independent() -> void:
	await _reset_campaign()
	_core.evolve_to(_core_lv2)
	_give_essence(ESSENCE_GRANT * 2.0)
	_give_biomass(BIOMASS_COST)
	_check(_expansion.summon_expansion_worker(), "o terceiro Worker vem antes do segundo")
	_check(not _invocation.worker_ever_summoned(),
			"invocar o terceiro não marca o segundo como invocado")
	_check(_invocation.summon_worker(), "o segundo Worker continua invocável pela tecla I")
	var ids: Array[String] = []
	for worker in _workers():
		ids.append(worker.state.unit_id)
	ids.sort()
	_check(ids == ["worker_001", SECOND_ID, THIRD_ID], "três Workers distintos, obtido %s" % [ids])
	_check(_core_state.population == 3, "População 3, obtido %d" % _core_state.population)
	_check(not _invocation.summon_worker() and not _expansion.summon_expansion_worker(),
			"cada regra continua valendo uma vez só")


## A rota real: invasão vencida, Cristal, evolução, Mina, Fazenda, Biomassa produzida pela
## Fazenda — e só então o terceiro servo, pela tecla.
func _test_end_to_end_biomass_to_worker() -> void:
	await _reset_campaign()
	_use_path(E2E_PATH)
	_give_iron(20)
	await _reach_level_two_for_real()
	if _construction.mine() == null:
		_check(_construction.build_mine(), "e2e: Mina lançada")
	_construction.mine().state.apply_work(8.0)
	await _advance(0.05)
	_check(_construction.build_fungal_farm(), "e2e: Fazenda lançada")
	var farm := _construction.fungal_farm()
	farm.state.apply_work(FARM_WORK)
	await _advance(0.05)
	_check(_stockpile.get_amount(BIOMASS) == 0, "e2e: a campanha começa sem Biomassa")
	_check(_expansion.gate() == WorkerExpansionController.Gate.BIOMASS,
			"e2e: no Nv.2 sem Biomassa a porta fechada é a Biomassa")
	_set_speed(SPEED)
	var grown := await _wait_for_biomass(BIOMASS_COST, FARM_INTERVAL * BIOMASS_COST / SPEED + 6.0)
	_set_speed(1.0)
	_check(grown, "e2e: a Fazenda produziu %d de Biomassa, obtido %d"
			% [BIOMASS_COST, _stockpile.get_amount(BIOMASS)])
	_give_essence(ESSENCE_GRANT)
	var biomass := _stockpile.get_amount(BIOMASS)
	await _press_expansion_key()
	_check(_third_worker() != null, "e2e: a Biomassa da Fazenda virou o terceiro Trabalhador")
	_check(_stockpile.get_amount(BIOMASS) == biomass - BIOMASS_COST,
			"e2e: a Biomassa produzida foi o corpo, %d → %d"
					% [biomass, _stockpile.get_amount(BIOMASS)])
	_check(_save.save_campaign(), "e2e: a campanha com três servos é salva")
	_measurements["e2e_biomass_when_summoned"] = biomass


# ============================================== Bloco 4 — persistência (schema V4)


func _test_save_roundtrip_with_third_worker() -> void:
	await _reset_campaign()
	_core.evolve_to(_core_lv2)
	_give_biomass(BIOMASS_COST)
	_give_essence(ESSENCE_GRANT)
	_check(_expansion.summon_expansion_worker(), "setup: terceiro Worker invocado")
	await _advance(0.05)
	var third := _third_worker()
	third.state.set_cargo(_iron, 2)
	third.global_position = Vector3(3.0, 0.0, 3.0)
	_use_path(WITH_THIRD_PATH)
	var before := _snapshot_text()
	_check(_save.save_campaign(), "save com o terceiro Worker carregando minério")
	var document := _document_from_file(WITH_THIRD_PATH)
	_check(int(document[CampaignSnapshot.ROOT_VERSION]) == 4,
			"o arquivo publicado é V4, obtido %s" % [document[CampaignSnapshot.ROOT_VERSION]])
	var units: Dictionary = document[CampaignSnapshot.ROOT_CAMPAIGN][CampaignSnapshot.SECTION_UNITS]
	_check(units.get(CampaignSnapshot.KEY_THIRD_SUMMONED) == true,
			"worker_003_summoned = true no arquivo")
	_check(_unit_ids(units).has(THIRD_ID), "o registro worker_003 está no arquivo")
	var text := _read_text(WITH_THIRD_PATH)
	for forbidden in ["biomass_cost", "essence_cost", "required_core_level"]:
		_check(not text.contains(forbidden), "a receita (%s) é configuração e não vai ao arquivo"
				% forbidden)
	# Altera tudo que o arquivo descreve.
	third.state.clear_cargo()
	third.move_to(Vector3(-6.0, 0.0, -6.0))
	_give_biomass(5)
	_expanded_events = 0
	_check(_save.load_campaign(), "load da campanha com o terceiro Worker")
	_check(_snapshot_text() == before, "snapshot exato depois da carga")
	_check(_workers().size() == 2, "dois Workers (001 e 003), obtido %d" % _workers().size())
	var loaded := _third_worker()
	_check(loaded != null and loaded.state.carried_amount == 2,
			"a carga do terceiro Worker voltou")
	_check(loaded != null and _close(loaded.global_position.x, 3.0)
			and _close(loaded.global_position.z, 3.0), "a posição voltou")
	_check(_expansion.worker_ever_expanded(), "a flag histórica voltou true")
	_check(_expanded_events == 0, "a carga não reanuncia a conquista")
	_check(not _expansion.summon_expansion_worker(), "a flag carregada trava um novo U")


func _test_load_without_third_removes_it() -> void:
	await _reset_campaign()
	_core.evolve_to(_core_lv2)
	_use_path(WITHOUT_THIRD_PATH)
	_check(_save.save_campaign(), "setup: campanha Nv.2 sem terceiro Worker salva")
	var population := _core_state.population
	_give_biomass(BIOMASS_COST)
	_give_essence(ESSENCE_GRANT)
	_check(_expansion.summon_expansion_worker(), "setup: terceiro Worker invocado depois do save")
	_check(_save.load_campaign(), "load do arquivo anterior à invocação")
	await _advance(0.05)
	_check(_third_worker() == null, "o terceiro Worker que o arquivo não tem foi desmontado")
	_check(not _expansion.worker_ever_expanded(), "a flag voltou false")
	_check(_core_state.population == population, "a população voltou a %d, obtido %d"
			% [population, _core_state.population])
	_check(_expansion.gate() == WorkerExpansionController.Gate.BIOMASS,
			"a campanha carregada volta a esperar Biomassa")


func _test_repeated_loads_never_duplicate() -> void:
	_use_path(WITH_THIRD_PATH)
	for attempt in 3:
		_check(_save.load_campaign(), "load repetido %d" % (attempt + 1))
		await _advance(0.05)
	var thirds := 0
	for worker in _workers():
		if worker.state.unit_id == THIRD_ID:
			thirds += 1
	_check(thirds == 1, "três loads, um único worker_003, obtido %d" % thirds)
	_check(_core_state.population == _workers().size(),
			"população fecha com os Workers vivos: %d" % _core_state.population)


func _test_v3_migration_opens_the_expansion() -> void:
	await _reset_campaign()
	_core.evolve_to(_core_lv2)
	await _advance(0.05)
	# Uma campanha V3 real é a V4 de agora, sem a chave do terceiro Worker.
	var campaign := _save.snapshot_campaign()
	var units: Dictionary = campaign[CampaignSnapshot.SECTION_UNITS]
	_check(units.has(CampaignSnapshot.KEY_THIRD_SUMMONED), "o snapshot V4 traz a flag nova")
	units.erase(CampaignSnapshot.KEY_THIRD_SUMMONED)
	_check(CampaignSnapshot.validate_v3(campaign).is_empty(),
			"a mesma campanha sem a flag é um V3 válido, motivo %s"
					% [CampaignSnapshot.validate_v3(campaign)])
	_check(not CampaignSnapshot.validate_v4(campaign).is_empty(),
			"como V4 a mesma campanha é recusada")
	var document := _document(CampaignSnapshot.SAVE_VERSION_V3, campaign)
	_check(_write_text(V3_PATH, CampaignSnapshot.to_text(document)), "o V3 foi escrito")
	_use_path(V3_PATH)
	_check(_save.load_campaign(), "o V3 carrega pela migração")
	_check(not _expansion.worker_ever_expanded(), "a migração não inventou terceiro Worker")
	_check(_core_state.level == REQUIRED_LEVEL, "o Nv.2 do arquivo chegou")
	_give_biomass(BIOMASS_COST)
	_give_essence(ESSENCE_GRANT)
	_check(_expansion.summon_expansion_worker(), "a campanha migrada pode expandir")
	_use_path(PRIMARY_PATH)
	_check(_save.save_campaign(), "re-save da campanha migrada")
	var resaved := _document_from_file(PRIMARY_PATH)
	_check(int(resaved[CampaignSnapshot.ROOT_VERSION]) == CampaignSnapshot.SAVE_VERSION,
			"o re-save publica V4")
	# O V3 no disco não foi reescrito "para atualizar".
	_check(int(_document_from_file(V3_PATH)[CampaignSnapshot.ROOT_VERSION]) == 3,
			"o arquivo V3 continua V3 no disco")


func _test_v1_chain_reaches_v4() -> void:
	await _reset_campaign()
	var campaign := _save.snapshot_campaign()
	var constructions: Dictionary = campaign[CampaignSnapshot.SECTION_CONSTRUCTIONS]
	constructions.erase(CampaignSnapshot.SECTION_MINE)
	constructions.erase(CampaignSnapshot.SECTION_FUNGAL_FARM)
	(campaign[CampaignSnapshot.SECTION_UNITS] as Dictionary).erase(
			CampaignSnapshot.KEY_THIRD_SUMMONED)
	_check(CampaignSnapshot.validate_v1(campaign).is_empty(),
			"sem Mina, Fazenda e flag nova a campanha é um V1 válido, motivo %s"
					% [CampaignSnapshot.validate_v1(campaign)])
	var migrated := CampaignSnapshot.migrate_to_current(_document(1, campaign))
	_check(int(migrated[CampaignSnapshot.ROOT_VERSION]) == 4, "a corrente V1→V4 chega ao V4")
	var units: Dictionary = migrated[CampaignSnapshot.ROOT_CAMPAIGN][CampaignSnapshot.SECTION_UNITS]
	_check(units.get(CampaignSnapshot.KEY_THIRD_SUMMONED) == false,
			"o degrau V3→V4 acrescenta worker_003_summoned = false")
	var migrated_constructions: Dictionary = migrated[CampaignSnapshot.ROOT_CAMPAIGN][
			CampaignSnapshot.SECTION_CONSTRUCTIONS]
	_check(migrated_constructions.has(CampaignSnapshot.SECTION_MINE)
			and migrated_constructions.has(CampaignSnapshot.SECTION_FUNGAL_FARM),
			"os degraus anteriores continuam acrescentando Mina e Fazenda")
	_check(_write_text(V1_PATH, CampaignSnapshot.to_text(_document(1, campaign))), "o V1 foi escrito")
	_use_path(V1_PATH)
	_check(_save.load_campaign(), "o V1 carrega pela corrente inteira")
	_check(not _expansion.worker_ever_expanded() and _third_worker() == null,
			"a corrente não inventou terceiro Worker")


func _test_contradictory_files_are_refused() -> void:
	await _reset_campaign()
	_core.evolve_to(_core_lv2)
	_give_biomass(BIOMASS_COST)
	_give_essence(ESSENCE_GRANT)
	_check(_expansion.summon_expansion_worker(), "setup: terceiro Worker invocado")
	await _advance(0.05)
	var good := _save.snapshot_campaign()

	# V3 não conhece worker_003: o formato congelado não ganha unidade nova.
	var as_v3 := good.duplicate(true)
	(as_v3[CampaignSnapshot.SECTION_UNITS] as Dictionary).erase(CampaignSnapshot.KEY_THIRD_SUMMONED)
	_check(not CampaignSnapshot.validate_v3(as_v3).is_empty(),
			"um V3 com registro worker_003 é recusado: %s" % CampaignSnapshot.validate_v3(as_v3))

	# Registro sem história: a unidade existe mas a flag diz que nunca foi invocada.
	var no_history := good.duplicate(true)
	(no_history[CampaignSnapshot.SECTION_UNITS] as Dictionary)[
			CampaignSnapshot.KEY_THIRD_SUMMONED] = false
	_check(not CampaignSnapshot.validate_v4(no_history).is_empty(),
			"worker_003 com worker_003_summoned = false é recusado")

	# Flag no Nv.1: a expansão só existe a partir do Nv.2, e o Núcleo não regride.
	var too_early := good.duplicate(true)
	_drop_third_record(too_early)
	var core: Dictionary = too_early[CampaignSnapshot.SECTION_CORE]
	core[CampaignSnapshot.KEY_LEVEL] = 1
	core[CampaignSnapshot.KEY_POPULATION] = int(core[CampaignSnapshot.KEY_POPULATION]) - 1
	core[CampaignSnapshot.KEY_ESSENCE] = 0.0
	core[CampaignSnapshot.KEY_INTEGRITY] = 1.0
	_check(CampaignSnapshot.validate_v4(too_early).is_empty(),
			"setup: estruturalmente a campanha é V4 válida, motivo %s"
					% CampaignSnapshot.validate_v4(too_early))
	var reason := _save.validate_campaign(too_early)
	_check(reason.contains("worker_003"),
			"o controller recusa terceiro Worker invocado no Nv.1, motivo %s" % reason)

	# Versão do futuro.
	var future := _document(5, good)
	_check(CampaignSnapshot.validate_document(future).contains("save_version não suportado"),
			"save_version = 5 é recusado sem adivinhação")

	# Nenhuma recusa toca no mundo.
	var world_before := _snapshot_text()
	for bad in [_document(3, as_v3), _document(4, no_history), _document(4, too_early), future]:
		_check(_write_text(BAD_PATH, CampaignSnapshot.to_text(bad)), "o arquivo ruim foi escrito")
		_use_path(BAD_PATH)
		_failed_events.clear()
		_check(not _save.load_campaign(), "o arquivo contraditório não carrega")
		_check(not _failed_events.is_empty(), "a recusa anuncia o motivo: %s" % [_failed_events])
		_check(_snapshot_text() == world_before, "o mundo continua intacto")
	await _reset_campaign()


# ==================================================================== helpers de cenário


func _reach_level_two_for_real() -> void:
	_give_essence(ESSENCE_GRANT)
	_check(_invasion.start_invasion(), "setup: a invasão foi largada")
	await _advance(0.05)
	for enemy in _alive_enemies():
		enemy.receive_damage(9999.0)
	await _advance(0.05)
	_check(_invasion.invasion_state() == InvasionController.InvasionState.VICTORY,
			"setup: VICTORY")
	_check(_crystal.amount == 1, "setup: a chave chegou, obtido %d" % _crystal.amount)
	_check(_evolution.try_evolve(), "setup: o Núcleo evoluiu para o Nv.2")
	await _advance(0.05)


func _reset_campaign() -> void:
	_resume_essence()
	_set_speed(1.0)
	_use_path(FRESH_PATH)
	_check(_save.load_campaign(), "setup: a carga de isolamento devolve a campanha do boot")
	_expanded_events = 0
	await _advance(0.1)


func _drop_third_record(campaign: Dictionary) -> void:
	var units: Dictionary = campaign[CampaignSnapshot.SECTION_UNITS]
	var kept: Array = []
	for record in units[CampaignSnapshot.KEY_WORKERS] as Array:
		if String((record as Dictionary)[CampaignSnapshot.KEY_UNIT_ID]) != THIRD_ID:
			kept.append(record)
	units[CampaignSnapshot.KEY_WORKERS] = kept


func _document(version: int, campaign: Dictionary) -> Dictionary:
	return {
		CampaignSnapshot.ROOT_FORMAT: CampaignSnapshot.SAVE_FORMAT,
		CampaignSnapshot.ROOT_VERSION: version,
		CampaignSnapshot.ROOT_METADATA: {"saved_at_unix": 1760450000, "probe": "expansão"},
		CampaignSnapshot.ROOT_CAMPAIGN: campaign,
	}


func _unit_ids(units: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for record in units[CampaignSnapshot.KEY_WORKERS] as Array:
		ids.append(String((record as Dictionary)[CampaignSnapshot.KEY_UNIT_ID]))
	return ids


func _give_iron(amount: int) -> void:
	_stockpile.add_resource(_iron, amount)


func _give_biomass(amount: int) -> void:
	_stockpile.add_resource(_biomass, amount)


func _give_essence(amount: float) -> void:
	_core_state.add_essence(amount)


func _drain_essence() -> void:
	_core_state.consume_essence(_core_state.essence)


## A regeneração do Núcleo mascararia o pagamento: congelada, `antes - depois` é o custo.
func _freeze_essence() -> void:
	_core.set_process(false)


func _resume_essence() -> void:
	if _core != null:
		_core.set_process(true)


func _set_speed(value: float) -> void:
	_speed = value
	Engine.time_scale = value


func _use_path(path: String) -> void:
	_save.configure_save_path(path)


func _on_worker_expanded(_runtime: WorkerRuntime) -> void:
	_expanded_events += 1


func _on_operation_failed(operation: String, reason: String) -> void:
	_failed_events.append("%s: %s" % [operation, reason])


func _workers() -> Array[WorkerRuntime]:
	var found: Array[WorkerRuntime] = []
	for child in _dungeon.get_children():
		var worker := child as WorkerRuntime
		if worker != null and not worker.is_queued_for_deletion():
			found.append(worker)
	return found


func _third_worker() -> WorkerRuntime:
	for worker in _workers():
		if worker.state.unit_id == THIRD_ID:
			return worker
	return null


func _alive_enemies() -> Array[EnemyRuntime]:
	var found: Array[EnemyRuntime] = []
	for child in _dungeon.get_children():
		var enemy := child as EnemyRuntime
		if enemy != null and not enemy.is_queued_for_deletion() and not enemy.state.is_dead():
			found.append(enemy)
	return found


func _park_near(worker: WorkerRuntime, target: Vector3) -> void:
	worker.global_position = target + Vector3(0.0, 0.0, 1.2)
	worker.reset_transient_order()


func _snapshot_text() -> String:
	return _normalize(_save.snapshot_campaign())


## A Essência regenera por frame; para comparar "o mundo não mudou" ignora-se só ela.
func _snapshot_without_essence(text: String) -> String:
	var regex := RegEx.new()
	regex.compile("essence=[0-9.e+-]+")
	return regex.sub(text, "essence=*", true)


func _press_expansion_key() -> void:
	var pressed := InputEventKey.new()
	pressed.physical_keycode = KEY_U
	pressed.pressed = true
	Input.parse_input_event(pressed)
	var released := InputEventKey.new()
	released.physical_keycode = KEY_U
	released.pressed = false
	Input.parse_input_event(released)
	await _advance(0.1)


func _planar_gap(from: Vector3, to: Vector3) -> float:
	return Vector2(from.x - to.x, from.z - to.z).length()


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


func _wait_for_biomass(target: int, max_seconds: float) -> bool:
	return await _wait_until(
			func() -> bool: return _stockpile.get_amount(BIOMASS) >= target, max_seconds)


func _text_of(root_node: Node, label_name: String) -> String:
	var label := root_node.find_child(label_name, true, false) as Label
	if label == null:
		return "<ausente>"
	return label.text


func _script_fields(instance: Object) -> Array[String]:
	var fields: Array[String] = []
	for property in instance.get_property_list():
		if int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			fields.append(String(property["name"]))
	return fields


# ============================================================ arquivo, fonte e medições


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


func _close(a: float, b: float, tolerance := 0.001) -> bool:
	return absf(a - b) <= tolerance


# ============================================================================== estrutura


func _boot_scene() -> void:
	_scene = MAIN_SCENE.instantiate()
	root.add_child(_scene)
	await _advance(0.2)
	_dungeon = _scene.get_node("World/DungeonRoot") as Node3D
	_construction = _scene.get_node("Systems/ConstructionController") as ConstructionController
	_invocation = _scene.get_node(
			"Systems/WorkerInvocationController") as WorkerInvocationController
	_expansion = _scene.get_node("Systems/WorkerExpansionController") as WorkerExpansionController
	_invasion = _scene.get_node("Systems/InvasionController") as InvasionController
	_evolution = _scene.get_node("Systems/CoreEvolutionController") as CoreEvolutionController
	_save = _scene.get_node("Systems/SaveGameController") as SaveGameController
	_core = _scene.get_node("World/DungeonRoot/MainCore") as CoreRuntime
	_worker = _scene.get_node("World/DungeonRoot/Worker001") as WorkerRuntime
	_spawn_point = _scene.get_node("World/DungeonRoot/WorkerSpawnPoint") as Marker3D
	var deposit := _scene.get_node("World/DungeonRoot/Deposit001") as ResourceDepositRuntime
	_stockpile = deposit.stockpile
	_core_state = _core.core_state()
	_crystal = _evolution.abyssal_crystal_state()
	_population_hud = _scene.get_node("UI/WorkerInvocationDebugPanel")
	_iron = load(IRON_ORE_PATH) as ResourceDefinition
	_biomass = load(BIOMASS_PATH) as ResourceDefinition
	_core_lv2 = load(CORE_LV2_PATH) as CoreDefinition
	_player_before = _presence(PLAYER_PRIMARY)
	_player_backup_before = _presence(PLAYER_BACKUP)
	_expansion.worker_expanded.connect(_on_worker_expanded)
	_save.operation_failed.connect(_on_operation_failed)
	Engine.set_physics_ticks_per_second(TICKS)
	_use_path(FRESH_PATH)
	_check(_save.save_campaign(), "setup: a campanha do boot virou o pristine da suíte")


func _free_scene() -> void:
	_save = null
	_stockpile = null
	_core_state = null
	_crystal = null
	_worker = null
	_core = null
	_expansion = null
	Engine.time_scale = 1.0
	Engine.set_physics_ticks_per_second(60)
	if _scene != null and is_instance_valid(_scene):
		_scene.queue_free()
	_scene = null
	await _advance(0.2)


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


func _cleanup_test_files() -> void:
	for path in TEST_PATHS:
		_remove_file(path)
		_remove_file(path.get_basename() + ".bak")
		_remove_file(path.get_basename() + ".tmp")
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
	_check(survivors.is_empty(), "nenhum arquivo de teste sobreviveu, restaram %s" % [survivors])
	_check(DirAccess.open(TEST_DIR) == null, "o diretório da suíte não fica para trás")


func _test_player_save_untouched() -> void:
	_check(_presence(PLAYER_PRIMARY) == _player_before
			and _presence(PLAYER_BACKUP) == _player_backup_before,
			"o save real do jogador não foi tocado: %s → %s"
					% [_player_before, _presence(PLAYER_PRIMARY)])
	for path in TEST_PATHS:
		_check(path.begins_with("user://tests/"), "todo caminho de teste está isolado: %s" % path)
	_check(_save == null, "a suíte não guarda referência a nenhum Node já libertado")


func _print_measurements() -> void:
	print("[INFO] medições da expansão populacional: %s" % [_measurements])


func _check(condition: bool, label: String) -> void:
	_asserts += 1
	if condition:
		print("[PASS] %s" % label)
	else:
		_failures += 1
		print("[FAIL] %s" % label)


func _finish() -> void:
	print("---- worker expansion tests finished: %d asserts, %d failure(s) ----"
			% [_asserts, _failures])
	quit(1 if _failures > 0 else 0)
