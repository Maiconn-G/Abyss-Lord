extends SceneTree

# Tarefa 23 — a primeira Incursão da Superfície.
#
# A pergunta desta suíte é a do princípio da tarefa (GDD §58.1): o Núcleo que volta a
# pulsar é notado pela superfície, e a superfície manda uma guilda para SAQUEAR — não para
# destruir. Por isso cada cenário mede Notoriedade, estoque e o destino do saque, e prova
# que o Núcleo não é alvo.
#
# Quatro blocos:
#   1) contrato e guarda de fonte — Definition, NotorietyState e RaiderState sozinhos, sem
#      cena; o saqueador é um EnemyRuntime; a primeira invasão não foi tocada; o Save V5;
#   2) gatilho — a evolução real para o Nv.2 soma 20 de Notoriedade e abre a preparação de
#      120 s; a carga não soma de novo; a contagem leva à largada de dois saqueadores;
#   3) o saque — Biomassa antes do Minério, três por saqueador, fuga com perda e Notoriedade,
#      morte com devolução, recuo por vida baixa, Depósito vazio, duelo com o Soldado real;
#   4) persistência V5 — PREPARATION, ACTIVE no meio do saque e ENDED voltam exatos; loads
#      repetidos não duplicam; V4 migra (Nv.1 com zero, Nv.2 com 20 e a guilda a caminho); a
#      corrente V1→V5 inteira; arquivos contraditórios recusados com o mundo intacto.

const MAIN_SCENE := preload("res://game/GameMain.tscn")

const RAIDER_DEFINITION_PATH := "res://data/units/enemies/guild_raider.tres"
const RAIDER_RUNTIME_SOURCE := "res://units/enemies/raider_runtime.gd"
const INCURSION_SOURCE := "res://systems/combat/surface_incursion_controller.gd"
const INVASION_SOURCE := "res://systems/combat/invasion_controller.gd"
const SNAPSHOT_SOURCE := "res://systems/persistence/campaign_snapshot.gd"
const GAME_MAIN_SOURCE := "res://game/game_main.gd"
const CI_SOURCE := "res://.github/workflows/ci.yml"
const V5_DOC := "res://docs/SAVE_SCHEMA_V5.md"
const IRON_ORE_PATH := "res://data/resources/iron_ore.tres"
const BIOMASS_PATH := "res://data/resources/biomass.tres"
const CORE_LV2_PATH := "res://data/core/core_level_2.tres"

const TEST_DIR := "user://tests/surface_incursion"
const FRESH_PATH := "user://tests/surface_incursion/pristine.json"
const PREP_PATH := "user://tests/surface_incursion/preparacao.json"
const ACTIVE_PATH := "user://tests/surface_incursion/ativa.json"
const ENDED_PATH := "user://tests/surface_incursion/encerrada.json"
const V4_LV1_PATH := "user://tests/surface_incursion/v4_nv1.json"
const V4_LV2_PATH := "user://tests/surface_incursion/v4_nv2.json"
const V1_PATH := "user://tests/surface_incursion/v1.json"
const BAD_PATH := "user://tests/surface_incursion/contraditoria.json"
const TEST_PATHS: Array[String] = [FRESH_PATH, PREP_PATH, ACTIVE_PATH, ENDED_PATH,
		V4_LV1_PATH, V4_LV2_PATH, V1_PATH, BAD_PATH]

const PLAYER_PRIMARY := "user://campaign_save.json"
const PLAYER_BACKUP := "user://campaign_save.bak"

const ORE := &"iron_ore"
const BIOMASS := &"biomass"

## Os números que a tarefa fixou, conferidos contra os arquivos.
const RAIDER_HEALTH := 40.0
const LOOT_CAPACITY := 3
const RETREAT_RATIO := 0.35
const PREPARATION := 120.0
const THRESHOLD := 20
const LEVEL_TWO_NOTORIETY := 20
const SLAIN_NOTORIETY := 5
const ESCAPED_NOTORIETY := 10
const GUILD := 2
const ENTRANCE_A := Vector3(3, 0, 13)
const ENTRANCE_B := Vector3(-7, 0, 13)

const HUD_QUIET := "Superfície: o Núcleo ainda não foi notado"

const TICKS := 60
const SPEED := 4.0
const SHORT_PREPARATION := 1.0
const ESSENCE_GRANT := 20.0

var _failures := 0
var _asserts := 0
var _frames := 0
var _measurements := {}

var _scene: Node
var _dungeon: Node3D
var _construction: ConstructionController
var _recruitment: SoldierRecruitmentController
var _invasion: InvasionController
var _incursion: SurfaceIncursionController
var _evolution: CoreEvolutionController
var _save: SaveGameController
var _core: CoreRuntime
var _core_state: CoreState
var _crystal: AbyssalCrystalState
var _stockpile: ResourceStockpileState
var _deposit: Node3D
var _iron: ResourceDefinition
var _biomass: ResourceDefinition
var _core_lv2: CoreDefinition
var _invasion_hud: Node

var _started_events := 0
var _ended_events := 0
var _failed_events: Array[String] = []
var _player_before := ""
var _player_backup_before := ""


func _initialize() -> void:
	_run_all()


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > 1500000:
		_check(false, "timeout: a suíte da incursão não terminou")
		_finish()
	return false


func _run_all() -> void:
	_test_definition_contract()
	_test_notoriety_state()
	_test_raider_state()
	_test_scope_guards()

	await _boot_scene()
	await _test_quiet_surface_at_level_one()
	await _test_real_evolution_opens_preparation()
	await _test_load_does_not_add_notoriety_twice()
	await _test_countdown_launches_the_guild()
	await _test_raid_prefers_biomass_and_escapes()
	await _test_slain_raider_returns_loot()
	await _test_low_health_retreat()
	await _test_empty_depot()
	await _test_soldier_duel()
	await _test_save_preparation()
	await _test_save_active_mid_raid()
	await _test_save_ended_and_repeated_loads()
	await _test_v4_migration_level_one()
	await _test_v4_migration_level_two_brings_the_guild()
	await _test_v1_chain_reaches_v5()
	await _test_contradictory_files_are_refused()

	await _free_scene()
	_cleanup_test_files()
	_test_player_save_untouched()
	print("[INFO] medições da incursão: %s" % [_measurements])
	_finish()


# ================================================== Bloco 1 — contrato sem cena


func _test_definition_contract() -> void:
	var definition := load(RAIDER_DEFINITION_PATH) as RaiderDefinition
	_check(definition != null, "o Saqueador de Guilda é uma RaiderDefinition")
	if definition == null:
		return
	_check(definition is EnemyDefinition, "RaiderDefinition herda o corpo de EnemyDefinition")
	_check(definition.enemy_type_id == &"guild_raider", "enemy_type_id guild_raider")
	_check(_close(definition.max_health, RAIDER_HEALTH), "vida %.0f" % RAIDER_HEALTH)
	_check(definition.loot_capacity == LOOT_CAPACITY, "carrega %d" % LOOT_CAPACITY)
	_check(_close(definition.retreat_health_ratio, RETREAT_RATIO), "recua a 35% da vida")
	_check(definition.loot_priority.size() == 2
			and definition.loot_priority[0].resource_id == BIOMASS
			and definition.loot_priority[1].resource_id == ORE,
			"a preferência do saque é Biomassa e depois Minério")
	_check(definition.loot_priority[0] == load(BIOMASS_PATH),
			"o saque usa as Resources genéricas do estoque, não cópias")


func _test_notoriety_state() -> void:
	var notoriety := NotorietyState.new()
	_check(notoriety.value == 0 and notoriety.band() == NotorietyState.Band.UNKNOWN,
			"a Notoriedade começa em 0, desconhecida")
	var emitted := [0]
	notoriety.notoriety_changed.connect(func(_c: int, _m: int) -> void: emitted[0] += 1)
	notoriety.add(0)
	notoriety.add(-5)
	_check(notoriety.value == 0 and emitted[0] == 0, "somar zero ou negativo não faz nada")
	notoriety.add(25)
	_check(notoriety.value == 25 and notoriety.band() == NotorietyState.Band.OBSERVED,
			"25 é observada")
	notoriety.add(500)
	_check(notoriety.value == NotorietyState.MAXIMUM, "o teto é 100")
	_check(notoriety.band() == NotorietyState.Band.SURFACE_TARGET, "100 é alvo da superfície")
	var before: int = emitted[0]
	notoriety.add(1)
	_check(emitted[0] == before, "no teto nenhum sinal novo")
	_check(not notoriety.restore(101) and not notoriety.restore(-1) and notoriety.value == 100,
			"restaurar fora da faixa não toca em nada")
	_check(notoriety.restore(40) and notoriety.value == 40, "restaurar devolve o valor")


func _test_raider_state() -> void:
	var definition := load(RAIDER_DEFINITION_PATH) as RaiderDefinition
	var raid := RaiderState.new(definition, "raider_001")
	_check(raid.phase == RaiderState.Phase.APPROACH and raid.carried_total() == 0,
			"o saqueador nasce se aproximando e de bolso vazio")
	_check(raid.carry(BIOMASS, 2) and raid.carry(ORE, 1), "carrega até a capacidade")
	_check(not raid.carry(ORE, 1) and not raid.has_room(), "não passa da capacidade")
	var dropped := raid.drop_loot()
	_check(int(dropped[BIOMASS]) == 2 and int(dropped[ORE]) == 1 and raid.carried_total() == 0,
			"largar o saque devolve tudo e esvazia a carga")
	_check(not raid.should_retreat(), "com vida cheia não recua")
	raid.damage(RAIDER_HEALTH * (1.0 - RETREAT_RATIO) + 0.1)
	_check(raid.should_retreat(), "abaixo de 35%% da vida recua (vida %f)" % raid.health)
	_check(not raid.restore_raid(RaiderState.Phase.LOOT, {"biomass": 4}),
			"restaurar saque acima da capacidade é recusado")
	_check(raid.restore_raid(RaiderState.Phase.RETREAT, {"biomass": 1, "iron_ore": 2})
			and raid.phase == RaiderState.Phase.RETREAT and raid.carried_total() == 3,
			"restaurar fase e saque dentro da faixa")


func _test_scope_guards() -> void:
	var raider_code := _code_of(RAIDER_RUNTIME_SOURCE)
	_check(raider_code.contains("extends EnemyRuntime"),
			"o saqueador é um EnemyRuntime — o Soldado o enfrenta sem branch de tipo")
	var invasion_code := _code_of(INVASION_SOURCE)
	for needle in ["Raider", "raider", "Notoriety", "surface", "Surface"]:
		_check(not invasion_code.contains(needle),
				"o InvasionController da primeira invasão não conhece %s" % needle)
	var incursion_code := _code_of(INCURSION_SOURCE)
	_check(not incursion_code.contains("get_node(") and not incursion_code.contains("get_tree()"),
			"o controller da incursão recebe tudo por injeção")
	_check(not incursion_code.contains("receive_damage") and not incursion_code.contains("CoreRuntime"),
			"a incursão não mira o Núcleo")
	var sources := _collect_gd_files("res://")
	for forbidden in ["WaveManager", "EnemySpawner", "SpawnManager", "ThreatManager",
			"ThreatSystem", "IncursionManager", "RaidManager", "LootTable", "SecondInvasion"]:
		_check(_files_named(sources, forbidden).is_empty()
				and _files_containing(sources, "class_name %s" % forbidden).is_empty(),
				"nenhum %s foi criado" % forbidden)
	var snapshot_code := _code_of(SNAPSHOT_SOURCE)
	# T24: a versão corrente subiu para 6; o V5 desta tarefa continua nomeado.
	for required in ["const SAVE_VERSION_V5 := 5", "const SAVE_VERSION_V4 := 4",
			"static func validate_v5(", "static func migrate_v4_to_v5(",
			"static func migrate_v3_to_v4("]:
		_check(snapshot_code.contains(required), "campaign_snapshot.gd contém %s" % required)
	_check(FileAccess.file_exists(V5_DOC), "docs/SAVE_SCHEMA_V5.md existe")
	var doc := _source(V5_DOC).to_lower()
	for documented in ["surface", "notoriety", "raiders", "loot", "v4", "v5", "migra",
			"preparation_time_remaining"]:
		_check(doc.contains(documented), "o documento V5 documenta %s" % documented)
	_check(not _source(CI_SOURCE).contains("surface_incursion"),
			"o workflow não lista suíte nenhuma — a descoberta é automática")
	_check(not _code_of(GAME_MAIN_SOURCE).contains("raider_001"),
			"a raiz de composição não conhece instância nenhuma")


# ================================================== Bloco 2 — o gatilho


func _test_quiet_surface_at_level_one() -> void:
	await _reset_campaign()
	_check(_incursion.notoriety().value == 0, "no boot a Notoriedade é 0")
	_check(_incursion.incursion_state() == SurfaceIncursionController.IncursionState.NOT_STARTED,
			"no boot a incursão não começou")
	_check(_text_of(_invasion_hud, "IncursionLabel") == HUD_QUIET,
			"o painel diz que a superfície não notou, obtido %s"
					% _text_of(_invasion_hud, "IncursionLabel"))
	_check(_text_of(_invasion_hud, "NotorietyLabel") == "Notoriedade: 0/100",
			"o painel mostra a Notoriedade")
	_check(_incursion.preparation_duration == PREPARATION,
			"a preparação de produção é de %.0f s" % PREPARATION)


func _test_real_evolution_opens_preparation() -> void:
	await _reset_campaign()
	await _reach_level_two_for_real()
	_check(_incursion.notoriety().value == LEVEL_TWO_NOTORIETY,
			"a evolução real para o Nv.2 soma %d, obtido %d"
					% [LEVEL_TWO_NOTORIETY, _incursion.notoriety().value])
	_check(_incursion.incursion_state() == SurfaceIncursionController.IncursionState.PREPARATION,
			"no limiar de %d a guilda começa a vir" % THRESHOLD)
	_check(_incursion.preparation_time_remaining() > PREPARATION - 1.0,
			"a contagem começa cheia, obtido %f" % _incursion.preparation_time_remaining())
	_check(_text_of(_invasion_hud, "IncursionLabel").begins_with("Guilda da superfície a caminho"),
			"o painel anuncia a guilda, obtido %s" % _text_of(_invasion_hud, "IncursionLabel"))
	_check(_text_of(_invasion_hud, "NotorietyLabel") == "Notoriedade: 20/100",
			"o painel mostra 20")
	_check(_alive_raiders().is_empty(), "durante a preparação ninguém entrou ainda")


func _test_load_does_not_add_notoriety_twice() -> void:
	_use_path(PREP_PATH)
	_check(_save.save_campaign(), "save no meio da preparação")
	_check(_save.load_campaign(), "load no meio da preparação")
	_check(_incursion.notoriety().value == LEVEL_TWO_NOTORIETY,
			"a carga não soma a evolução de novo, obtido %d" % _incursion.notoriety().value)
	# A evolução de harness também é evolução: soma uma vez só.
	await _reset_campaign()
	_core.evolve_to(_core_lv2)
	_check(_incursion.notoriety().value == LEVEL_TWO_NOTORIETY, "evolve_to soma uma vez")
	_check(not _core.evolve_to(_core_lv2), "não existe segunda evolução para o Nv.2")
	_check(_incursion.notoriety().value == LEVEL_TWO_NOTORIETY, "e não soma de novo")


func _test_countdown_launches_the_guild() -> void:
	await _reset_campaign()
	_incursion.preparation_duration = SHORT_PREPARATION
	_core.evolve_to(_core_lv2)
	_started_events = 0
	var integrity := _core_state.integrity
	await _advance(SHORT_PREPARATION + 0.3)
	_check(_incursion.incursion_state() == SurfaceIncursionController.IncursionState.ACTIVE,
			"a contagem acabou e a incursão começou")
	_check(_started_events == 1, "incursion_started foi emitido uma vez")
	var raiders := _alive_raiders()
	_check(raiders.size() == GUILD, "a guilda tem %d saqueadores, obtido %d"
			% [GUILD, raiders.size()])
	if raiders.size() == GUILD:
		var ids: Array[String] = [raiders[0].get_enemy_id(), raiders[1].get_enemy_id()]
		ids.sort()
		_check(ids == ["raider_001", "raider_002"], "identidades raider_001/002, obtido %s" % [ids])
		_check(_planar_gap(raiders[0].global_position, ENTRANCE_A) < 1.5
				or _planar_gap(raiders[0].global_position, ENTRANCE_B) < 1.5,
				"eles entram pela borda da superfície")
		_check(raiders[0].is_in_group(&"combat_target"), "o Soldado pode mirá-los")
	_check(_text_of(_invasion_hud, "IncursionLabel") == "INCURSÃO — saqueadores: 2",
			"o painel acompanha a largada, obtido %s" % _text_of(_invasion_hud, "IncursionLabel"))
	_check(_invasion.invasion_state() == InvasionController.InvasionState.NOT_STARTED,
			"a primeira invasão não foi tocada")
	await _advance(0.5)
	_check(_close(_core_state.integrity, integrity), "o Núcleo não é alvo da guilda")
	_incursion.preparation_duration = PREPARATION


func _test_raid_prefers_biomass_and_escapes() -> void:
	await _launch_guild()
	_give(_biomass, 2)
	_give(_iron, 10)
	var notoriety := _incursion.notoriety().value
	_set_speed(SPEED)
	var looted := await _wait_until(
			func() -> bool: return _total_carried() == GUILD * LOOT_CAPACITY, 30.0)
	_check(looted, "os dois encheram os bolsos, obtido %d" % _total_carried())
	_check(_stockpile.get_amount(BIOMASS) == 0, "a Biomassa foi levada primeiro")
	_check(_stockpile.get_amount(ORE) == 10 - (GUILD * LOOT_CAPACITY - 2),
			"o Minério completou o saque: 10 → %d" % _stockpile.get_amount(ORE))
	var core_integrity := _core_state.integrity
	var gone := await _wait_until(func() -> bool: return _alive_raiders().is_empty(), 40.0)
	_set_speed(1.0)
	_check(gone, "os dois saqueadores fugiram para a superfície")
	_check(_incursion.incursion_state() == SurfaceIncursionController.IncursionState.ENDED,
			"a incursão terminou")
	_check(_incursion.escaped_count() == GUILD and _incursion.repelled_count() == 0,
			"dois fugiram, nenhum foi repelido")
	_check(_ended_events == 1, "incursion_ended emitido uma vez")
	_check(_stockpile.get_amount(BIOMASS) == 0 and _stockpile.get_amount(ORE) == 6,
			"o saque fugiu com eles: estoque não recuperou nada")
	_check(_incursion.notoriety().value == notoriety + GUILD * ESCAPED_NOTORIETY,
			"cada fuga soma %d de Notoriedade: %d → %d"
					% [ESCAPED_NOTORIETY, notoriety, _incursion.notoriety().value])
	_check(_close(_core_state.integrity, core_integrity), "o Núcleo saiu intacto")
	_check(_text_of(_invasion_hud, "IncursionLabel")
			== "Incursão encerrada — repelidos: 0, fugiram: 2",
			"o painel registra o desfecho, obtido %s" % _text_of(_invasion_hud, "IncursionLabel"))


func _test_slain_raider_returns_loot() -> void:
	await _launch_guild()
	_give(_biomass, 6)
	var notoriety := _incursion.notoriety().value
	_set_speed(SPEED)
	var looting := await _wait_until(
			func() -> bool: return _raider_carrying(2) != null, 30.0)
	_set_speed(1.0)
	var victim := _raider_carrying(2)
	_check(looting and victim != null, "um saqueador já carrega 2")
	if victim == null:
		return
	var carried := victim.raider_state().carried_total()
	var before := _stockpile.get_amount(BIOMASS)
	victim.receive_damage(9999.0)
	await _advance(0.05)
	_check(_stockpile.get_amount(BIOMASS) == before + carried,
			"o saque do morto volta ao estoque: %d → %d" % [before, _stockpile.get_amount(BIOMASS)])
	_check(_incursion.repelled_count() == 1, "um repelido")
	_check(_incursion.notoriety().value == notoriety + SLAIN_NOTORIETY,
			"a morte soma %d de Notoriedade" % SLAIN_NOTORIETY)
	_check(_alive_raiders().size() == 1, "um saqueador continua em campo")
	_check(_incursion.incursion_state() == SurfaceIncursionController.IncursionState.ACTIVE,
			"com um em campo a incursão continua")
	_measurements["loot_returned"] = carried


func _test_low_health_retreat() -> void:
	await _launch_guild()
	_give(_biomass, 6)
	var raider := _alive_raiders()[0]
	raider.receive_damage(RAIDER_HEALTH * (1.0 - RETREAT_RATIO) + 1.0)
	await _advance(0.1)
	_check(raider.raider_state().phase == RaiderState.Phase.RETREAT,
			"ferido abaixo de 35%% ele desiste e recua")
	_check(raider.raider_state().carried_total() == 0, "recua sem ter roubado nada")
	_set_speed(SPEED)
	var raider_instance := raider.get_instance_id()
	var escaped := await _wait_until(
			func() -> bool: return _escaped_or_gone(raider_instance), 20.0)
	_set_speed(1.0)
	_check(escaped, "e foge para a superfície")


func _test_empty_depot() -> void:
	await _launch_guild()
	_drain_stockpile()
	_set_speed(SPEED)
	var gone := await _wait_until(func() -> bool: return _alive_raiders().is_empty(), 40.0)
	_set_speed(1.0)
	_check(gone, "com o Depósito vazio eles chegam, não levam nada e vão embora")
	_check(_incursion.escaped_count() == GUILD, "dois fugiram de mãos vazias")


func _test_soldier_duel() -> void:
	await _reset_campaign()
	_incursion.preparation_duration = SHORT_PREPARATION
	_give(_iron, 30)
	_give_essence(ESSENCE_GRANT * 2.0)
	_check(_construction.build_barracks(), "setup: Quartel lançado")
	_construction.barracks().state.apply_work(100.0)
	await _advance(0.05)
	_check(_recruitment.recruit_soldier(), "setup: Soldado recrutado")
	var soldier := _recruitment.soldier()
	_core.evolve_to(_core_lv2)
	await _advance(SHORT_PREPARATION + 0.3)
	_incursion.preparation_duration = PREPARATION
	_give(_biomass, 6)
	var target := _alive_raiders()[0]
	soldier.global_position = target.global_position + Vector3(1.0, 0.0, 0.0)
	_check(soldier.attack_target(target), "o Soldado aceita o saqueador como alvo")
	_check(target.action_mode() == EnemyRuntime.ActionMode.COMBAT, "o saqueador revida")
	var target_instance := target.get_instance_id()
	_set_speed(SPEED)
	var resolved := await _wait_until(
			func() -> bool: return _duel_resolved(target_instance), 20.0)
	_check(resolved, "o duelo se resolve: o saqueador morre ou foge ferido")
	var fought := not is_instance_valid(target) or target.state.health < RAIDER_HEALTH
	_check(fought, "o saqueador levou golpes do Soldado")
	_check(soldier.state.health < soldier.definition.max_health or not is_instance_valid(target),
			"o saqueador também bateu (ou caiu antes)")
	await _wait_until(func() -> bool: return _alive_raiders().is_empty(), 40.0)
	_set_speed(1.0)
	_check(_incursion.incursion_state() == SurfaceIncursionController.IncursionState.ENDED,
			"a incursão termina depois do duelo")
	_measurements["duel_repelled"] = _incursion.repelled_count()


# ================================================== Bloco 4 — persistência V5


func _test_save_preparation() -> void:
	await _reset_campaign()
	_core.evolve_to(_core_lv2)
	await _advance(1.0)
	_use_path(PREP_PATH)
	var remaining := _incursion.preparation_time_remaining()
	_check(_save.save_campaign(), "save na preparação")
	var document := _document_from_file(PREP_PATH)
	_check(int(document[CampaignSnapshot.ROOT_VERSION]) == CampaignSnapshot.SAVE_VERSION,
			"o arquivo é a versão corrente")
	var surface: Dictionary = document[CampaignSnapshot.ROOT_CAMPAIGN][
			CampaignSnapshot.SECTION_SURFACE]
	_check(int(surface[CampaignSnapshot.KEY_NOTORIETY]) == LEVEL_TWO_NOTORIETY,
			"a Notoriedade foi gravada")
	_check(surface[CampaignSnapshot.KEY_INCURSION][CampaignSnapshot.KEY_STATE] == "PREPARATION",
			"o estado PREPARATION foi gravado")
	await _advance(1.0)
	_check(_save.load_campaign(), "load da preparação")
	_check(_close(_incursion.preparation_time_remaining(), remaining, 0.05),
			"o segundo exato voltou: %f contra %f"
					% [_incursion.preparation_time_remaining(), remaining])
	_check(_incursion.incursion_state() == SurfaceIncursionController.IncursionState.PREPARATION,
			"a contagem continua depois da carga")


func _test_save_active_mid_raid() -> void:
	await _launch_guild()
	_give(_biomass, 6)
	_set_speed(SPEED)
	await _wait_until(func() -> bool: return _raider_carrying(1) != null, 30.0)
	_set_speed(1.0)
	_use_path(ACTIVE_PATH)
	var before := _snapshot_text()
	_check(_save.save_campaign(), "save no meio do saque")
	var record := _first_raider_record(ACTIVE_PATH)
	_check(not record.is_empty() and (record[CampaignSnapshot.KEY_LOOT] as Dictionary).size() > 0,
			"o saque em curso está no arquivo: %s" % [record])
	_check(not _read_text(ACTIVE_PATH).contains("loot_capacity")
			and not _read_text(ACTIVE_PATH).contains("steal_interval"),
			"capacidade e ritmo do saque são configuração, não vão ao arquivo")
	# Muda o mundo: mata um, esvazia o estoque.
	_alive_raiders()[0].receive_damage(9999.0)
	_drain_stockpile()
	await _advance(0.1)
	_started_events = 0
	_check(_save.load_campaign(), "load do saque em curso")
	await _advance(0.02)
	_check(_snapshot_text_without_motion() == _without_motion(before),
			"a campanha voltou exata (posições conferidas à parte)")
	_check(_alive_raiders().size() == 2, "os dois saqueadores voltaram, obtido %d"
			% _alive_raiders().size())
	_check(_started_events == 0, "a carga não reanuncia a largada")
	_set_speed(SPEED)
	var gone := await _wait_until(func() -> bool: return _alive_raiders().is_empty(), 40.0)
	_set_speed(1.0)
	_check(gone and _incursion.incursion_state()
			== SurfaceIncursionController.IncursionState.ENDED,
			"a incursão restaurada segue até o fim")


func _test_save_ended_and_repeated_loads() -> void:
	_use_path(ENDED_PATH)
	_check(_save.save_campaign(), "save da incursão encerrada")
	var notoriety := _incursion.notoriety().value
	for attempt in 3:
		_check(_save.load_campaign(), "load repetido %d" % (attempt + 1))
		await _advance(0.05)
	_check(_alive_raiders().is_empty(), "encerrada não renasce saqueador")
	_check(_incursion.incursion_state() == SurfaceIncursionController.IncursionState.ENDED,
			"ENDED é terminal")
	_check(_incursion.notoriety().value == notoriety, "a Notoriedade não muda com loads")
	_use_path(ACTIVE_PATH)
	for attempt in 3:
		_check(_save.load_campaign(), "load repetido do saque %d" % (attempt + 1))
		await _advance(0.02)
	_check(_alive_raiders().size() == 2, "três loads, dois saqueadores, obtido %d"
			% _alive_raiders().size())


func _test_v4_migration_level_one() -> void:
	await _reset_campaign()
	var campaign := _save.snapshot_campaign()
	campaign.erase(CampaignSnapshot.SECTION_SURFACE)
	_check(CampaignSnapshot.validate_v4(campaign).is_empty(),
			"sem a superfície a campanha é um V4 válido: %s" % CampaignSnapshot.validate_v4(campaign))
	_check(not CampaignSnapshot.validate_v5(campaign).is_empty(), "como V5 é recusada")
	_check(_write_text(V4_LV1_PATH, CampaignSnapshot.to_text(_document(4, campaign))),
			"o V4 Nv.1 foi escrito")
	_use_path(V4_LV1_PATH)
	_check(_save.load_campaign(), "o V4 Nv.1 carrega pela migração")
	_check(_incursion.notoriety().value == 0, "Nv.1 migra com Notoriedade 0")
	_check(_incursion.incursion_state() == SurfaceIncursionController.IncursionState.NOT_STARTED,
			"e a guilda não vem")


func _test_v4_migration_level_two_brings_the_guild() -> void:
	await _reset_campaign()
	await _reach_level_two_for_real()
	var campaign := _save.snapshot_campaign()
	campaign.erase(CampaignSnapshot.SECTION_SURFACE)
	_check(_write_text(V4_LV2_PATH, CampaignSnapshot.to_text(_document(4, campaign))),
			"o V4 Nv.2 foi escrito")
	await _reset_campaign()
	_use_path(V4_LV2_PATH)
	_check(_save.load_campaign(), "o V4 Nv.2 carrega pela migração")
	_check(_incursion.notoriety().value == LEVEL_TWO_NOTORIETY,
			"um Núcleo Nv.2 migra com a Notoriedade do próprio fato: %d"
					% _incursion.notoriety().value)
	_check(_incursion.incursion_state() == SurfaceIncursionController.IncursionState.PREPARATION,
			"e a guilda passa a vir para a campanha antiga também")
	_check(int(_document_from_file(V4_LV2_PATH)[CampaignSnapshot.ROOT_VERSION]) == 4,
			"o arquivo V4 continua V4 no disco")


func _test_v1_chain_reaches_v5() -> void:
	await _reset_campaign()
	var campaign := _save.snapshot_campaign()
	campaign.erase(CampaignSnapshot.SECTION_SURFACE)
	var constructions: Dictionary = campaign[CampaignSnapshot.SECTION_CONSTRUCTIONS]
	constructions.erase(CampaignSnapshot.SECTION_MINE)
	constructions.erase(CampaignSnapshot.SECTION_FUNGAL_FARM)
	(campaign[CampaignSnapshot.SECTION_UNITS] as Dictionary).erase(
			CampaignSnapshot.KEY_THIRD_SUMMONED)
	_check(CampaignSnapshot.validate_v1(campaign).is_empty(), "é um V1 válido")
	var migrated := CampaignSnapshot.migrate_to_current(_document(1, campaign))
	_check(int(migrated[CampaignSnapshot.ROOT_VERSION]) == CampaignSnapshot.SAVE_VERSION,
			"a corrente chega à versão corrente")
	_check(CampaignSnapshot.validate_document(migrated).is_empty(),
			"o V1 migrado é um V5 válido: %s" % CampaignSnapshot.validate_document(migrated))
	_check(_write_text(V1_PATH, CampaignSnapshot.to_text(_document(1, campaign))), "V1 escrito")
	_use_path(V1_PATH)
	_check(_save.load_campaign(), "o V1 carrega pela corrente inteira")
	_check(_incursion.notoriety().value == 0, "a corrente não inventou Notoriedade")


func _test_contradictory_files_are_refused() -> void:
	await _launch_guild()
	_give(_biomass, 6)
	_set_speed(SPEED)
	await _wait_until(func() -> bool: return _raider_carrying(1) != null, 30.0)
	_set_speed(1.0)
	var good := _save.snapshot_campaign()
	_check(_save.validate_campaign(good).is_empty(), "setup: a campanha ativa é válida")
	var bad_cases: Array = []

	var no_surface := good.duplicate(true)
	no_surface.erase(CampaignSnapshot.SECTION_SURFACE)
	bad_cases.append(["V5 sem surface", no_surface])

	var active_empty := good.duplicate(true)
	_incursion_of(active_empty)[CampaignSnapshot.KEY_RAIDERS] = []
	bad_cases.append(["ACTIVE sem saqueador", active_empty])

	var greedy := good.duplicate(true)
	(_incursion_of(greedy)[CampaignSnapshot.KEY_RAIDERS][0] as Dictionary)[
			CampaignSnapshot.KEY_LOOT] = {"biomass": LOOT_CAPACITY + 1}
	bad_cases.append(["saque acima da capacidade", greedy])

	var stranger := good.duplicate(true)
	(_incursion_of(stranger)[CampaignSnapshot.KEY_RAIDERS][0] as Dictionary)[
			CampaignSnapshot.KEY_RAIDER_ID] = "raider_009"
	bad_cases.append(["raider_id desconhecido", stranger])

	var ended_wrong := good.duplicate(true)
	_incursion_of(ended_wrong)[CampaignSnapshot.KEY_STATE] = "ENDED"
	_incursion_of(ended_wrong)[CampaignSnapshot.KEY_RAIDERS] = []
	bad_cases.append(["ENDED que não fecha a guilda", ended_wrong])

	var loud := good.duplicate(true)
	(loud[CampaignSnapshot.SECTION_SURFACE] as Dictionary)[CampaignSnapshot.KEY_NOTORIETY] = 101
	bad_cases.append(["Notoriedade acima de 100", loud])

	for entry in bad_cases:
		_check(not _save.validate_campaign(entry[1]).is_empty(),
				"%s é recusado: %s" % [entry[0], _save.validate_campaign(entry[1])])
	var future := _document(CampaignSnapshot.SAVE_VERSION + 1, good)
	_check(CampaignSnapshot.validate_document(future).contains("save_version não suportado"),
			"save_version do futuro é recusado sem adivinhação")
	var world_before := _snapshot_text()
	var raiders_before := _alive_raiders().size()
	for entry in bad_cases:
		_check(_write_text(BAD_PATH, CampaignSnapshot.to_text(_document(5, entry[1]))),
				"arquivo ruim escrito: %s" % entry[0])
		_use_path(BAD_PATH)
		_failed_events.clear()
		_check(not _save.load_campaign(), "%s não carrega" % entry[0])
		_check(not _failed_events.is_empty(), "a recusa anuncia o motivo")
		_check(_snapshot_text() == world_before, "o mundo continua intacto")
	_check(_alive_raiders().size() == raiders_before, "nenhum saqueador foi tocado")
	await _reset_campaign()


# ==================================================================== helpers


func _duel_resolved(instance: int) -> bool:
	var target := instance_from_id(instance) as RaiderRuntime
	if target == null or not target.is_alive():
		return true
	return target.raider_state().phase == RaiderState.Phase.RETREAT


func _escaped_or_gone(instance: int) -> bool:
	var raider := instance_from_id(instance) as RaiderRuntime
	return raider == null or raider.has_escaped()


func _launch_guild() -> void:
	await _reset_campaign()
	_drain_stockpile()
	_incursion.preparation_duration = SHORT_PREPARATION
	_core.evolve_to(_core_lv2)
	_started_events = 0
	_ended_events = 0
	await _advance(SHORT_PREPARATION + 0.3)
	_incursion.preparation_duration = PREPARATION
	_check(_alive_raiders().size() == GUILD, "setup: a guilda entrou")


func _reach_level_two_for_real() -> void:
	_give_essence(ESSENCE_GRANT)
	_check(_invasion.start_invasion(), "setup: a invasão foi largada")
	await _advance(0.05)
	for enemy in _alive_beasts():
		enemy.receive_damage(9999.0)
	await _advance(0.05)
	_check(_crystal.amount == 1, "setup: a chave chegou")
	_check(_evolution.try_evolve(), "setup: o Núcleo evoluiu para o Nv.2")
	await _advance(0.05)


func _reset_campaign() -> void:
	_set_speed(1.0)
	_incursion.preparation_duration = PREPARATION
	_use_path(FRESH_PATH)
	_check(_save.load_campaign(), "setup: a carga de isolamento devolve a campanha do boot")
	await _advance(0.1)


func _alive_raiders() -> Array[RaiderRuntime]:
	var found: Array[RaiderRuntime] = []
	for child in _dungeon.get_children():
		var raider := child as RaiderRuntime
		if raider != null and not raider.is_queued_for_deletion() and raider.is_alive() \
				and not raider.has_escaped():
			found.append(raider)
	return found


func _alive_beasts() -> Array[EnemyRuntime]:
	var found: Array[EnemyRuntime] = []
	for child in _dungeon.get_children():
		var enemy := child as EnemyRuntime
		if enemy != null and not (enemy is RaiderRuntime) and not enemy.is_queued_for_deletion() \
				and not enemy.state.is_dead():
			found.append(enemy)
	return found


func _total_carried() -> int:
	var total := 0
	for raider in _alive_raiders():
		total += raider.raider_state().carried_total()
	return total


func _raider_carrying(amount: int) -> RaiderRuntime:
	for raider in _alive_raiders():
		if raider.raider_state().carried_total() >= amount:
			return raider
	return null


func _incursion_of(campaign: Dictionary) -> Dictionary:
	return (campaign[CampaignSnapshot.SECTION_SURFACE] as Dictionary)[
			CampaignSnapshot.KEY_INCURSION]


func _first_raider_record(path: String) -> Dictionary:
	var document := _document_from_file(path)
	var raiders: Array = _incursion_of(document[CampaignSnapshot.ROOT_CAMPAIGN])[
			CampaignSnapshot.KEY_RAIDERS]
	for record in raiders:
		if not (record[CampaignSnapshot.KEY_LOOT] as Dictionary).is_empty():
			return record
	return {} if raiders.is_empty() else raiders[0]


func _document(version: int, campaign: Dictionary) -> Dictionary:
	return {
		CampaignSnapshot.ROOT_FORMAT: CampaignSnapshot.SAVE_FORMAT,
		CampaignSnapshot.ROOT_VERSION: version,
		CampaignSnapshot.ROOT_METADATA: {"saved_at_unix": 1760460000, "probe": "incursão"},
		CampaignSnapshot.ROOT_CAMPAIGN: campaign,
	}


func _give(resource: ResourceDefinition, amount: int) -> void:
	_stockpile.add_resource(resource, amount)


func _give_essence(amount: float) -> void:
	_core_state.add_essence(amount)


func _drain_stockpile() -> void:
	for resource in [_biomass, _iron]:
		var amount := _stockpile.get_amount(resource.resource_id)
		if amount > 0:
			_stockpile.consume_resource(resource, amount)


func _set_speed(value: float) -> void:
	Engine.time_scale = value


func _use_path(path: String) -> void:
	_save.configure_save_path(path)


func _snapshot_text() -> String:
	return _normalize(_save.snapshot_campaign())


## Depois de uma carga, um frame de física já moveu os saqueadores e a Essência regenera.
## A comparação de "voltou exato" tira só esses números em movimento.
func _snapshot_text_without_motion() -> String:
	return _without_motion(_snapshot_text())


func _without_motion(text: String) -> String:
	var regex := RegEx.new()
	regex.compile("(position|essence|preparation_time_remaining)=(\\[[^\\]]*\\]|[0-9.e+-]+)")
	return regex.sub(text, "$1=*", true)


func _on_incursion_started(_raiders: Array) -> void:
	_started_events += 1


func _on_incursion_ended(_repelled: int, _escaped: int) -> void:
	_ended_events += 1


func _on_operation_failed(operation: String, reason: String) -> void:
	_failed_events.append("%s: %s" % [operation, reason])


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


func _text_of(root_node: Node, label_name: String) -> String:
	var label := root_node.find_child(label_name, true, false) as Label
	if label == null:
		return "<ausente>"
	return label.text


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


func _boot_scene() -> void:
	_scene = MAIN_SCENE.instantiate()
	root.add_child(_scene)
	await _advance(0.2)
	_dungeon = _scene.get_node("World/DungeonRoot") as Node3D
	_construction = _scene.get_node("Systems/ConstructionController") as ConstructionController
	_recruitment = _scene.get_node(
			"Systems/SoldierRecruitmentController") as SoldierRecruitmentController
	_invasion = _scene.get_node("Systems/InvasionController") as InvasionController
	_incursion = _scene.get_node(
			"Systems/SurfaceIncursionController") as SurfaceIncursionController
	_evolution = _scene.get_node("Systems/CoreEvolutionController") as CoreEvolutionController
	_save = _scene.get_node("Systems/SaveGameController") as SaveGameController
	_core = _scene.get_node("World/DungeonRoot/MainCore") as CoreRuntime
	var deposit := _scene.get_node("World/DungeonRoot/Deposit001") as ResourceDepositRuntime
	_deposit = deposit
	_stockpile = deposit.stockpile
	_core_state = _core.core_state()
	_crystal = _evolution.abyssal_crystal_state()
	_invasion_hud = _scene.get_node("UI/InvasionDebugPanel")
	_iron = load(IRON_ORE_PATH) as ResourceDefinition
	_biomass = load(BIOMASS_PATH) as ResourceDefinition
	_core_lv2 = load(CORE_LV2_PATH) as CoreDefinition
	_player_before = _presence(PLAYER_PRIMARY)
	_player_backup_before = _presence(PLAYER_BACKUP)
	_incursion.incursion_started.connect(_on_incursion_started)
	_incursion.incursion_ended.connect(_on_incursion_ended)
	_save.operation_failed.connect(_on_operation_failed)
	Engine.set_physics_ticks_per_second(TICKS)
	_check(_planar_gap(_scene.get_node("World/DungeonRoot/SurfaceEntrancePointA").global_position,
			ENTRANCE_A) < 0.01, "a entrada A da superfície está na borda sul")
	_use_path(FRESH_PATH)
	_check(_save.save_campaign(), "setup: a campanha do boot virou o pristine da suíte")


func _free_scene() -> void:
	_save = null
	_stockpile = null
	_core_state = null
	_crystal = null
	_core = null
	_incursion = null
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
	_check(DirAccess.open(TEST_DIR) == null, "o diretório da suíte não fica para trás")


func _test_player_save_untouched() -> void:
	_check(_presence(PLAYER_PRIMARY) == _player_before
			and _presence(PLAYER_BACKUP) == _player_backup_before,
			"o save real do jogador não foi tocado")
	_check(_save == null, "a suíte não guarda referência a nenhum Node já libertado")


func _check(condition: bool, label: String) -> void:
	_asserts += 1
	if condition:
		print("[PASS] %s" % label)
	else:
		_failures += 1
		print("[FAIL] %s" % label)


func _finish() -> void:
	print("---- surface incursion tests finished: %d asserts, %d failure(s) ----"
			% [_asserts, _failures])
	quit(1 if _failures > 0 else 0)
