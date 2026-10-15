extends SceneTree

# Tarefa 26 — a Ascensão: Núcleo Nv.2 → Nv.3 ("Masmorra", GDD §8).
#
# A pergunta desta suíte: o domínio cresce de novo, e cresce por uma conquista. A chave é o
# Cristal da primeira guilda da superfície repelida sem nenhuma fuga; o preço é Cristal,
# Essência e Biomassa; e a tecla V nunca sobe dois níveis de uma vez.
#
# Quatro blocos:
#   1) contrato — a Definition do Nv.3, o controller separado do MVP, o Save V8;
#   2) o Cristal — guilda inteira repelida entrega 1 Cristal, uma vez; guilda com fuga não;
#   3) a Ascensão — portas na ordem, transação atômica, a tecla V real, Nv.3 com população
#      30, escala e Notoriedade +20, e a mesma tecla que não pula dois níveis;
#   4) persistência V8 — Nv.3 e a flag voltam, migração V7 não inventa Cristal, recusas.

const MAIN_SCENE := preload("res://game/GameMain.tscn")

const CORE_LV2_PATH := "res://data/core/core_level_2.tres"
const CORE_LV3_PATH := "res://data/core/core_level_3.tres"
const BIOMASS_PATH := "res://data/resources/biomass.tres"
const ASCENSION_SOURCE := "res://systems/progression/core_ascension_controller.gd"
const EVOLUTION_SOURCE := "res://systems/progression/core_evolution_controller.gd"
const SNAPSHOT_SOURCE := "res://systems/persistence/campaign_snapshot.gd"
const V8_DOC := "res://docs/SAVE_SCHEMA_V8.md"

const TEST_DIR := "user://tests/core_ascension"
const FRESH_PATH := "user://tests/core_ascension/pristine.json"
const LV3_PATH := "user://tests/core_ascension/nv3.json"
const V7_PATH := "user://tests/core_ascension/v7.json"
const BAD_PATH := "user://tests/core_ascension/contraditoria.json"
const TEST_PATHS: Array[String] = [FRESH_PATH, LV3_PATH, V7_PATH, BAD_PATH]

const PLAYER_PRIMARY := "user://campaign_save.json"
const PLAYER_BACKUP := "user://campaign_save.bak"

const BIOMASS := &"biomass"
const ESSENCE_COST := 40.0
const BIOMASS_COST := 10
const POPULATION_LV3 := 30
const SCALE_LV3 := 1.5
const TICKS := 60

var _failures := 0
var _asserts := 0
var _frames := 0

var _scene: Node
var _dungeon: Node3D
var _incursion: SurfaceIncursionController
var _evolution: CoreEvolutionController
var _ascension: CoreAscensionController
var _invasion: InvasionController
var _save: SaveGameController
var _core: CoreRuntime
var _core_state: CoreState
var _crystal: AbyssalCrystalState
var _stockpile: ResourceStockpileState
var _biomass: ResourceDefinition
var _core_lv2: CoreDefinition
var _evolution_hud: Node
var _ascended_events := 0
var _crystal_events := 0
var _failed_events: Array[String] = []
var _player_before := ""
var _player_backup_before := ""


func _initialize() -> void:
	_run_all()


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > 1500000:
		_check(false, "timeout: a suíte da Ascensão não terminou")
		_finish()
	return false


func _run_all() -> void:
	_test_contract()

	await _boot_scene()
	await _test_clean_repel_grants_one_crystal()
	await _test_escape_grants_nothing()
	await _test_gates_in_order_and_atomic()
	await _test_real_key_ascends_once()
	await _test_one_key_never_climbs_two_levels()
	await _test_save_level_three()
	await _test_v7_migration_invents_no_crystal()
	await _test_contradictory_files_are_refused()

	await _free_scene()
	_cleanup_test_files()
	_test_player_save_untouched()
	_finish()


# ================================================================ Bloco 1 — contrato


func _test_contract() -> void:
	var lv3 := load(CORE_LV3_PATH) as CoreDefinition
	_check(lv3 != null and lv3.level == 3, "existe a Definition do Nv.3")
	if lv3 == null:
		return
	_check(lv3.population_capacity == POPULATION_LV3, "Nv.3 tem população base 30 (GDD §8)")
	_check(lv3.evolution_crystal_cost == 1 and _close(lv3.evolution_essence_cost, ESSENCE_COST)
			and lv3.evolution_biomass_cost == BIOMASS_COST,
			"a Ascensão custa 1 Cristal + 40 Essência + 10 Biomassa")
	var lv2 := load(CORE_LV2_PATH) as CoreDefinition
	_check(lv3.evolution_essence_cost <= lv2.max_essence,
			"o custo de Essência cabe no tanque do Nv.2")
	_check(lv2.evolution_biomass_cost == 0, "o Nv.2 continua sem custo de Biomassa")
	_check(lv3.max_integrity > lv2.max_integrity and lv3.max_essence > lv2.max_essence
			and lv3.essence_generation_rate > lv2.essence_generation_rate,
			"o Nv.3 é maior em tudo")
	var evolution_code := _code_of(EVOLUTION_SOURCE)
	_check(not evolution_code.contains("Ascension") and not evolution_code.contains("biomass"),
			"o CoreEvolutionController do MVP não foi tocado pela Ascensão")
	var ascension_code := _code_of(ASCENSION_SOURCE)
	_check(not ascension_code.contains("get_node(") and not ascension_code.contains("get_tree()"),
			"a Ascensão recebe tudo por injeção")
	var snapshot := _code_of(SNAPSHOT_SOURCE)
	for required in ["const SAVE_VERSION_V8 := 8", "const SAVE_VERSION_V7 := 7",
			"static func validate_v8(", "static func migrate_v7_to_v8("]:
		_check(snapshot.contains(required), "campaign_snapshot.gd contém %s" % required)
	_check(FileAccess.file_exists(V8_DOC), "docs/SAVE_SCHEMA_V8.md existe")
	var doc := _read_text(V8_DOC).to_lower()
	for documented in ["clean_repel_milestone", "nv.3", "v7", "v8", "migra", "cristal"]:
		_check(doc.contains(documented), "o documento V8 documenta %s" % documented)


# ================================================================ Bloco 2 — o Cristal


func _test_clean_repel_grants_one_crystal() -> void:
	await _reset_campaign()
	_core.evolve_to(_core_lv2)
	var before := _crystal.amount
	_crystal_events = 0
	await _launch_and_slay_guild()
	_check(_crystal.amount == before + 1, "a guilda inteira repelida entrega 1 Cristal: %d → %d"
			% [before, _crystal.amount])
	_check(_incursion.clean_repel_rewarded() and _crystal_events == 1, "o marco foi registrado")
	_restart_incursion_now()
	await _launch_and_slay_guild()
	_check(_crystal.amount == before + 1, "a segunda guilda inteira repelida não entrega outro")


func _test_escape_grants_nothing() -> void:
	await _reset_campaign()
	_core.evolve_to(_core_lv2)
	_check(_incursion.start_incursion(), "setup: guilda largada")
	await _advance(0.05)
	var raiders := _alive_raiders()
	raiders[0].receive_damage(9999.0)
	await _advance(0.05)
	var before := _crystal.amount
	Engine.time_scale = 4.0
	await _wait_until(func() -> bool: return _alive_raiders().is_empty(), 40.0)
	Engine.time_scale = 1.0
	_check(_incursion.escaped_count() == 1, "um saqueador fugiu")
	_check(_crystal.amount == before and not _incursion.clean_repel_rewarded(),
			"guilda com fuga não entrega Cristal")


# =============================================================== Bloco 3 — a Ascensão


func _test_gates_in_order_and_atomic() -> void:
	await _reset_campaign()
	_check(_ascension.gate() == CoreAscensionController.Gate.NOT_AT_SOURCE,
			"no Nv.1 a Ascensão nem existe ainda")
	_check(_text_of(_evolution_hud, "AscensionStatusLabel") == "Ascensão: requer Núcleo Nv.2",
			"o painel diz o que falta: %s" % _text_of(_evolution_hud, "AscensionStatusLabel"))
	_core.evolve_to(_core_lv2)
	_drain()
	await _advance(0.05)
	_check(_ascension.gate() == CoreAscensionController.Gate.CRYSTAL, "no Nv.2 falta o Cristal")
	_check(_text_of(_evolution_hud, "AscensionStatusLabel").ends_with("repila uma guilda inteira"),
			"o painel aponta a guilda: %s" % _text_of(_evolution_hud, "AscensionStatusLabel"))
	_crystal.add(1)
	_core.set_process(false)
	_core_state.consume_essence(_core_state.essence)
	_core_state.add_essence(ESSENCE_COST - 1.0)
	_check(_ascension.gate() == CoreAscensionController.Gate.ESSENCE, "depois falta a Essência")
	_core_state.add_essence(1.0)
	_stockpile.add_resource(_biomass, BIOMASS_COST - 1)
	_check(_ascension.gate() == CoreAscensionController.Gate.BIOMASS, "depois falta a Biomassa")
	_check(not _ascension.try_ascend(), "sem Biomassa a Ascensão é recusada")
	_check(_crystal.amount == 1 and _close(_core_state.essence, ESSENCE_COST)
			and _stockpile.get_amount(BIOMASS) == BIOMASS_COST - 1,
			"recusar não cobra nenhuma das três metades")
	_stockpile.add_resource(_biomass, 1)
	await _advance(0.02)
	_check(_ascension.gate() == CoreAscensionController.Gate.READY, "com tudo, pronta")
	_check(_text_of(_evolution_hud, "AscensionStatusLabel") == "Pronto para ascender",
			"o painel diz que está pronta")
	_check(_text_of(_evolution_hud, "AscensionLabel")
			== "[V] Ascender a Nv.3 — 1 Cristal Abissal + 40 Essência + 10 Biomassa",
			"o painel mostra a receita: %s" % _text_of(_evolution_hud, "AscensionLabel"))
	_core.set_process(true)


func _test_real_key_ascends_once() -> void:
	_core.set_process(false)
	var notoriety := _incursion.notoriety().value
	_ascended_events = 0
	await _press_v()
	_check(_core_state.level == 3, "a tecla V real ascende o Núcleo ao Nv.3")
	_check(_ascended_events == 1, "ascension_completed emitido uma vez")
	_check(_crystal.amount == 0 and _close(_core_state.essence, 0.0, 0.01)
			and _stockpile.get_amount(BIOMASS) == 0,
			"a Ascensão cobrou Cristal, Essência e Biomassa")
	_check(_core_state.get_population_capacity() >= POPULATION_LV3,
			"a população base passa a 30: capacidade %d" % _core_state.get_population_capacity())
	_check(_close(_core.scale.x, SCALE_LV3), "o Núcleo cresce para 1.5")
	_check(_incursion.notoriety().value == notoriety + 20,
			"a superfície nota o Nv.3: +20 de Notoriedade")
	_check(_text_of(_evolution_hud, "AscensionLabel") == "Ascensão concluída",
			"o painel registra a Ascensão")
	_crystal.add(5)
	_core_state.add_essence(100.0)
	_stockpile.add_resource(_biomass, 50)
	await _press_v()
	_check(_core_state.level == 3 and _ascended_events == 1, "não existe Nv.4: a tecla não faz nada")
	_core.set_process(true)


func _test_one_key_never_climbs_two_levels() -> void:
	await _reset_campaign()
	_check(_core_state.level == 1, "setup: Nv.1")
	await _win_first_invasion()
	_crystal.add(1)
	_core_state.add_essence(200.0)
	_stockpile.add_resource(_biomass, BIOMASS_COST)
	_core.set_process(false)
	await _press_v()
	_check(_core_state.level == 2,
			"com duas chaves e recursos de sobra, uma tecla V sobe só um nível: Nv.%d"
					% _core_state.level)
	# O tanque do Nv.1 limita a Essência a 50; o Nv.2 recebe o que sobrou. Recarrega para a
	# segunda metade da prova.
	_core_state.add_essence(100.0)
	await _press_v()
	_check(_core_state.level == 3, "a segunda tecla V ascende ao Nv.3")
	_core.set_process(true)


# ======================================================== Bloco 4 — persistência V8


func _test_save_level_three() -> void:
	await _reset_campaign()
	_core.evolve_to(_core_lv2)
	await _launch_and_slay_guild()
	_core_state.add_essence(80.0)
	_stockpile.add_resource(_biomass, BIOMASS_COST)
	_check(_ascension.try_ascend(), "setup: ascendeu ao Nv.3")
	_use_path(LV3_PATH)
	_check(_save.save_campaign(), "save no Nv.3")
	var document := _document_from_file(LV3_PATH)
	_check(int(document[CampaignSnapshot.ROOT_VERSION]) == CampaignSnapshot.SAVE_VERSION,
			"o arquivo é a versão corrente")
	_check(int(document[CampaignSnapshot.ROOT_CAMPAIGN][CampaignSnapshot.SECTION_CORE][
			CampaignSnapshot.KEY_LEVEL]) == 3, "o Nv.3 está no arquivo")
	_check(bool(document[CampaignSnapshot.ROOT_CAMPAIGN][CampaignSnapshot.SECTION_SURFACE][
			CampaignSnapshot.KEY_CLEAN_REPEL_MILESTONE]), "o marco está no arquivo")
	await _reset_campaign()
	_ascended_events = 0
	_use_path(LV3_PATH)
	_check(_save.load_campaign(), "load do Nv.3")
	_check(_core_state.level == 3 and _close(_core.scale.x, SCALE_LV3), "o Núcleo volta Nv.3")
	_check(_incursion.clean_repel_rewarded(), "o marco volta")
	_check(_ascended_events == 0, "a carga não reanuncia a Ascensão")
	_check(_text_of(_evolution_hud, "AscensionLabel") == "Ascensão concluída",
			"o painel volta concluído")


func _test_v7_migration_invents_no_crystal() -> void:
	await _reset_campaign()
	_core.evolve_to(_core_lv2)
	await _launch_and_slay_guild()
	var campaign := _save.snapshot_campaign()
	(campaign[CampaignSnapshot.SECTION_SURFACE] as Dictionary).erase(
			CampaignSnapshot.KEY_CLEAN_REPEL_MILESTONE)
	_check(CampaignSnapshot.validate_v7(campaign).is_empty(),
			"sem a flag é um V7 válido: %s" % CampaignSnapshot.validate_v7(campaign))
	_check(_write_text(V7_PATH, CampaignSnapshot.to_text(_document(7, campaign))), "V7 escrito")
	_use_path(V7_PATH)
	_check(_save.load_campaign(), "o V7 carrega pela migração")
	_check(not _incursion.clean_repel_rewarded(),
			"a migração não reconhece marco nenhum: a próxima guilda inteira é que conta")


func _test_contradictory_files_are_refused() -> void:
	await _reset_campaign()
	var good := _save.snapshot_campaign()
	var cases: Array = []
	var premature := good.duplicate(true)
	(premature[CampaignSnapshot.SECTION_SURFACE] as Dictionary)[
			CampaignSnapshot.KEY_CLEAN_REPEL_MILESTONE] = true
	cases.append(["Cristal da guilda sem incursão", premature])
	var missing := good.duplicate(true)
	(missing[CampaignSnapshot.SECTION_SURFACE] as Dictionary).erase(
			CampaignSnapshot.KEY_CLEAN_REPEL_MILESTONE)
	cases.append(["V8 sem a flag", missing])
	var level_four := good.duplicate(true)
	(level_four[CampaignSnapshot.SECTION_CORE] as Dictionary)[CampaignSnapshot.KEY_LEVEL] = 4
	cases.append(["Núcleo Nv.4", level_four])
	for entry in cases:
		_check(not _save.validate_campaign(entry[1]).is_empty(),
				"%s é recusado: %s" % [entry[0], _save.validate_campaign(entry[1])])
	_check(CampaignSnapshot.validate_document(_document(CampaignSnapshot.SAVE_VERSION + 1, good)).contains("save_version não suportado"),
			"save_version = 9 é recusado")
	var before := _snapshot_text()
	for entry in cases:
		_write_text(BAD_PATH, CampaignSnapshot.to_text(_document(8, entry[1])))
		_use_path(BAD_PATH)
		_failed_events.clear()
		_check(not _save.load_campaign() and not _failed_events.is_empty(),
				"%s não carrega e anuncia o motivo" % entry[0])
		_check(_snapshot_text() == before, "o mundo continua intacto")


# ==================================================================== helpers


func _launch_and_slay_guild() -> void:
	_check(_incursion.start_incursion(), "setup: guilda largada")
	await _advance(0.05)
	for raider in _alive_raiders():
		raider.receive_damage(9999.0)
	await _advance(0.05)


func _restart_incursion_now() -> void:
	_incursion.restore_surface(_incursion.notoriety().value,
			SurfaceIncursionController.IncursionState.NOT_STARTED, 0.0, [], 0, 0, 0, 0, 0.0,
			_incursion.clean_repel_rewarded())


func _win_first_invasion() -> void:
	_core_state.add_essence(20.0)
	_check(_invasion.start_invasion(), "setup: a invasão foi largada")
	await _advance(0.05)
	for child in _dungeon.get_children():
		var enemy := child as EnemyRuntime
		if enemy != null and not (enemy is RaiderRuntime) and enemy.is_alive():
			enemy.receive_damage(9999.0)
	await _advance(0.05)
	_check(_crystal.amount == 1, "setup: a chave do MVP chegou")


func _drain() -> void:
	var amount := _stockpile.get_amount(BIOMASS)
	if amount > 0:
		_stockpile.consume_resource(_biomass, amount)
	if _crystal.amount > 0:
		_crystal.consume(_crystal.amount)


func _press_v() -> void:
	var pressed := InputEventKey.new()
	pressed.physical_keycode = KEY_V
	pressed.pressed = true
	Input.parse_input_event(pressed)
	var released := InputEventKey.new()
	released.physical_keycode = KEY_V
	released.pressed = false
	Input.parse_input_event(released)
	await _advance(0.1)


func _reset_campaign() -> void:
	Engine.time_scale = 1.0
	if _core != null:
		_core.set_process(true)
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


func _document(version: int, campaign: Dictionary) -> Dictionary:
	return {
		CampaignSnapshot.ROOT_FORMAT: CampaignSnapshot.SAVE_FORMAT,
		CampaignSnapshot.ROOT_VERSION: version,
		CampaignSnapshot.ROOT_METADATA: {"saved_at_unix": 1760560000, "probe": "ascensão"},
		CampaignSnapshot.ROOT_CAMPAIGN: campaign,
	}


func _use_path(path: String) -> void:
	_save.configure_save_path(path)


func _snapshot_text() -> String:
	return _normalize(_save.snapshot_campaign())


func _on_ascended(_level: int) -> void:
	_ascended_events += 1


func _on_crystal_granted() -> void:
	_crystal_events += 1


func _on_operation_failed(operation: String, reason: String) -> void:
	_failed_events.append("%s: %s" % [operation, reason])


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
	return "<ausente>" if label == null else label.text


func _document_from_file(path: String) -> Dictionary:
	var parsed: Variant = CampaignSnapshot.parse_document(_read_text(path))
	return {} if parsed == null else parsed as Dictionary


func _code_of(path: String) -> String:
	var kept: Array[String] = []
	for line in _read_text(path).split("\n"):
		var comment_at := line.find("#")
		kept.append(line.substr(0, comment_at) if comment_at >= 0 else line)
	return "\n".join(kept)


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
	_incursion = _scene.get_node(
			"Systems/SurfaceIncursionController") as SurfaceIncursionController
	_evolution = _scene.get_node("Systems/CoreEvolutionController") as CoreEvolutionController
	_ascension = _scene.get_node("Systems/CoreAscensionController") as CoreAscensionController
	_invasion = _scene.get_node("Systems/InvasionController") as InvasionController
	_save = _scene.get_node("Systems/SaveGameController") as SaveGameController
	_core = _scene.get_node("World/DungeonRoot/MainCore") as CoreRuntime
	_stockpile = (_scene.get_node("World/DungeonRoot/Deposit001") as ResourceDepositRuntime).stockpile
	_core_state = _core.core_state()
	_crystal = _evolution.abyssal_crystal_state()
	_evolution_hud = _scene.get_node("UI/CoreEvolutionDebugPanel")
	_biomass = load(BIOMASS_PATH) as ResourceDefinition
	_core_lv2 = load(CORE_LV2_PATH) as CoreDefinition
	_player_before = _presence(PLAYER_PRIMARY)
	_player_backup_before = _presence(PLAYER_BACKUP)
	_ascension.ascension_completed.connect(_on_ascended)
	_incursion.clean_repel_crystal_granted.connect(_on_crystal_granted)
	_save.operation_failed.connect(_on_operation_failed)
	Engine.set_physics_ticks_per_second(TICKS)
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


func _presence(path: String) -> String:
	if not FileAccess.file_exists(path):
		return "ausente"
	var text := _read_text(path)
	return "presente:%d:%d" % [text.length(), text.hash()]


func _cleanup_test_files() -> void:
	for path in TEST_PATHS:
		for candidate in [path, path.get_basename() + ".bak", path.get_basename() + ".tmp"]:
			if FileAccess.file_exists(candidate):
				DirAccess.remove_absolute(candidate)
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
	print("---- core ascension tests finished: %d asserts, %d failure(s) ----"
			% [_asserts, _failures])
	quit(1 if _failures > 0 else 0)
