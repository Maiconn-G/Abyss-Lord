extends SceneTree

# Tarefa 25 — incursões recorrentes que escalam com a Notoriedade.
#
# A pergunta desta suíte (GDD §13 e §58.1): a superfície não esquece. Depois de cada
# incursão vem uma calmaria, depois outra guilda, e quanto mais Notoriedade, maior o grupo.
#
# Três blocos:
#   1) contrato — a tabela de tamanho por faixa, a calmaria de produção, o Save V7;
#   2) a recorrência no mundo — calmaria, nova preparação, incursão 2, guildas de 3 e 5, as
#      entradas alternadas, o painel;
#   3) persistência V7 — calmaria no meio, guilda de 4 em campo, loads repetidos, migração V6
#      (ENDED volta a chamar a guilda; NOT_STARTED continua zerado) e recusas.

const MAIN_SCENE := preload("res://game/GameMain.tscn")

const SNAPSHOT_SOURCE := "res://systems/persistence/campaign_snapshot.gd"
const V7_DOC := "res://docs/SAVE_SCHEMA_V7.md"
const CORE_LV2_PATH := "res://data/core/core_level_2.tres"

const TEST_DIR := "user://tests/recurring_incursions"
const FRESH_PATH := "user://tests/recurring_incursions/pristine.json"
const COOLDOWN_PATH := "user://tests/recurring_incursions/calmaria.json"
const BIG_GUILD_PATH := "user://tests/recurring_incursions/guilda_grande.json"
const V6_ENDED_PATH := "user://tests/recurring_incursions/v6_encerrada.json"
const V6_FRESH_PATH := "user://tests/recurring_incursions/v6_nova.json"
const BAD_PATH := "user://tests/recurring_incursions/contraditoria.json"
const TEST_PATHS: Array[String] = [FRESH_PATH, COOLDOWN_PATH, BIG_GUILD_PATH, V6_ENDED_PATH,
		V6_FRESH_PATH, BAD_PATH]

const PLAYER_PRIMARY := "user://campaign_save.json"
const PLAYER_BACKUP := "user://campaign_save.bak"

const COOLDOWN := 90.0
const PREPARATION := 120.0
const SHORT := 0.5
const ENTRANCE_A := Vector3(3, 0, 13)
const ENTRANCE_B := Vector3(-7, 0, 13)
const TICKS := 60
const SPEED := 4.0

var _failures := 0
var _asserts := 0
var _frames := 0

var _scene: Node
var _dungeon: Node3D
var _incursion: SurfaceIncursionController
var _save: SaveGameController
var _core: CoreRuntime
var _stockpile: ResourceStockpileState
var _core_lv2: CoreDefinition
var _invasion_hud: Node
var _started_events := 0
var _failed_events: Array[String] = []
var _player_before := ""
var _player_backup_before := ""


func _initialize() -> void:
	_run_all()


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > 1500000:
		_check(false, "timeout: a suíte das incursões recorrentes não terminou")
		_finish()
	return false


func _run_all() -> void:
	_test_guild_size_table()
	_test_contract()

	await _boot_scene()
	await _test_cooldown_then_next_guild()
	await _test_guild_grows_with_notoriety()
	await _test_largest_guild_uses_both_entrances()
	await _test_save_mid_cooldown()
	await _test_save_big_guild_and_repeated_loads()
	await _test_v6_migration()
	await _test_contradictory_files_are_refused()

	await _free_scene()
	_cleanup_test_files()
	_test_player_save_untouched()
	_finish()


# ================================================================ Bloco 1 — contrato


func _test_guild_size_table() -> void:
	var table := [[0, 2], [20, 2], [40, 2], [41, 3], [60, 3], [61, 4], [80, 4], [81, 5], [100, 5]]
	for row in table:
		_check(SurfaceIncursionController.guild_size_for(row[0]) == row[1],
				"Notoriedade %d → guilda de %d" % [row[0], row[1]])
	_check(SurfaceIncursionController.FIRST_GUILD_SIZE == 2
			and SurfaceIncursionController.MAX_GUILD_SIZE == 5, "a guilda vai de 2 a 5")


func _test_contract() -> void:
	var code := _code_of(SNAPSHOT_SOURCE)
	for required in ["const SAVE_VERSION_V7 := 7", "const SAVE_VERSION_V6 := 6",
			"static func validate_v7(", "static func migrate_v6_to_v7(",
			"static func migrate_v5_to_v6("]:
		_check(code.contains(required), "campaign_snapshot.gd contém %s" % required)
	_check(FileAccess.file_exists(V7_DOC), "docs/SAVE_SCHEMA_V7.md existe")
	var doc := _source(V7_DOC).to_lower()
	for documented in ["incursion_number", "guild_size", "cooldown_remaining", "v6", "v7",
			"migra", "calmaria"]:
		_check(doc.contains(documented), "o documento V7 documenta %s" % documented)


# =================================================== Bloco 2 — a recorrência no mundo


func _test_cooldown_then_next_guild() -> void:
	await _reset_campaign()
	_check(_incursion.cooldown_duration == COOLDOWN, "a calmaria de produção é de 90 s")
	await _launch_and_finish_guild()
	_check(_incursion.incursion_state() == SurfaceIncursionController.IncursionState.ENDED,
			"a primeira incursão terminou")
	_check(_incursion.incursion_number() == 1, "foi a incursão 1")
	_check(_close(_incursion.cooldown_remaining(), COOLDOWN, 0.5),
			"a calmaria começou cheia: %f" % _incursion.cooldown_remaining())
	_check(_text_of(_invasion_hud, "IncursionLabel").begins_with("Incursão 1 encerrada")
			and _text_of(_invasion_hud, "IncursionLabel").contains("próxima em"),
			"o painel mostra a calmaria: %s" % _text_of(_invasion_hud, "IncursionLabel"))
	_incursion.cooldown_duration = SHORT
	_incursion.restore_surface(_incursion.notoriety().value,
			SurfaceIncursionController.IncursionState.ENDED, 0.0, [],
			_incursion.repelled_count(), _incursion.escaped_count(),
			_incursion.incursion_number(), _incursion.guild_size(), SHORT)
	await _advance(SHORT + 0.2)
	_check(_incursion.incursion_state() == SurfaceIncursionController.IncursionState.PREPARATION,
			"ao fim da calmaria a próxima guilda começa a preparação")
	_check(_close(_incursion.preparation_time_remaining(), PREPARATION, 0.5),
			"a preparação da próxima é a de produção")
	_started_events = 0
	_check(_incursion.start_incursion(), "a próxima guilda é largada")
	_check(_incursion.incursion_number() == 2 and _started_events == 1, "é a incursão 2")
	_check(_incursion.repelled_count() == 0 and _incursion.escaped_count() == 0,
			"o desfecho da anterior foi zerado")
	_check(_text_of(_invasion_hud, "IncursionLabel").begins_with("INCURSÃO 2"),
			"o painel numera a incursão: %s" % _text_of(_invasion_hud, "IncursionLabel"))
	_incursion.cooldown_duration = COOLDOWN


func _test_guild_grows_with_notoriety() -> void:
	await _reset_campaign()
	_core.evolve_to(_core_lv2)
	_incursion.notoriety().restore(45)
	_check(_incursion.start_incursion(), "largada com Notoriedade 45")
	await _advance(0.05)
	_check(_alive_raiders().size() == 3 and _incursion.guild_size() == 3,
			"Notoriedade 45 traz 3 saqueadores, obtido %d" % _alive_raiders().size())
	var ids: Array[String] = []
	for raider in _alive_raiders():
		ids.append(raider.get_enemy_id())
	ids.sort()
	_check(ids == ["raider_001", "raider_002", "raider_003"], "identidades em sequência: %s" % [ids])


func _test_largest_guild_uses_both_entrances() -> void:
	await _reset_campaign()
	_core.evolve_to(_core_lv2)
	_incursion.notoriety().restore(90)
	_check(_incursion.start_incursion(), "largada com Notoriedade 90")
	await _advance(0.05)
	var raiders := _alive_raiders()
	_check(raiders.size() == 5, "uma potência notada recebe 5 saqueadores, obtido %d" % raiders.size())
	var near_a := 0
	var near_b := 0
	for raider in raiders:
		if _planar_gap(raider.global_position, ENTRANCE_A) < 1.5:
			near_a += 1
		elif _planar_gap(raider.global_position, ENTRANCE_B) < 1.5:
			near_b += 1
	_check(near_a == 3 and near_b == 2, "as entradas se alternam: %d em A, %d em B" % [near_a, near_b])
	_set_speed(SPEED)
	var all_left := await _wait_until(func() -> bool: return _alive_raiders().is_empty(), 60.0)
	_set_speed(1.0)
	_check(all_left and _incursion.escaped_count() == 5, "os cinco foram e voltaram de mãos vazias")
	_check(_incursion.notoriety().value == 100, "cinco fugas levam a Notoriedade ao teto")


# ===================================================== Bloco 3 — persistência V7


func _test_save_mid_cooldown() -> void:
	await _reset_campaign()
	await _launch_and_finish_guild()
	await _advance(1.0)
	var remaining := _incursion.cooldown_remaining()
	_use_path(COOLDOWN_PATH)
	_check(_save.save_campaign(), "save no meio da calmaria")
	var incursion := _incursion_of(_document_from_file(COOLDOWN_PATH)[CampaignSnapshot.ROOT_CAMPAIGN])
	_check(int(incursion[CampaignSnapshot.KEY_INCURSION_NUMBER]) == 1
			and int(incursion[CampaignSnapshot.KEY_GUILD_SIZE]) == 2,
			"número e guilda foram gravados: %s" % [incursion])
	_check(_close(float(incursion[CampaignSnapshot.KEY_COOLDOWN_REMAINING]), remaining, 0.05),
			"a calmaria foi gravada")
	await _advance(1.0)
	_check(_save.load_campaign(), "load no meio da calmaria")
	_check(_close(_incursion.cooldown_remaining(), remaining, 0.05),
			"o segundo exato da calmaria voltou: %f contra %f"
					% [_incursion.cooldown_remaining(), remaining])
	_check(_incursion.incursion_state() == SurfaceIncursionController.IncursionState.ENDED,
			"e a calmaria continua contando")
	await _advance(0.5)
	_check(_incursion.cooldown_remaining() < remaining, "o relógio anda depois da carga")


func _test_save_big_guild_and_repeated_loads() -> void:
	await _reset_campaign()
	_core.evolve_to(_core_lv2)
	_incursion.notoriety().restore(70)
	_check(_incursion.start_incursion(), "largada de uma guilda de 4")
	await _advance(0.05)
	_alive_raiders()[0].receive_damage(9999.0)
	await _advance(0.05)
	_use_path(BIG_GUILD_PATH)
	_check(_save.save_campaign(), "save com 3 de 4 em campo")
	for attempt in 3:
		_check(_save.load_campaign(), "load repetido %d" % (attempt + 1))
		await _advance(0.02)
	_check(_alive_raiders().size() == 3, "três loads, três saqueadores, obtido %d"
			% _alive_raiders().size())
	_check(_incursion.guild_size() == 4 and _incursion.repelled_count() == 1,
			"a guilda de 4 e o repelido voltaram")


func _test_v6_migration() -> void:
	await _reset_campaign()
	await _launch_and_finish_guild()
	var campaign := _save.snapshot_campaign()
	var incursion := _incursion_of(campaign)
	for key in [CampaignSnapshot.KEY_INCURSION_NUMBER, CampaignSnapshot.KEY_GUILD_SIZE,
			CampaignSnapshot.KEY_COOLDOWN_REMAINING]:
		incursion.erase(key)
	_check(CampaignSnapshot.validate_v6(campaign).is_empty(),
			"sem os campos novos é um V6 válido: %s" % CampaignSnapshot.validate_v6(campaign))
	_check(not CampaignSnapshot.validate_v7(campaign).is_empty(), "como V7 é recusada")
	_check(_write_text(V6_ENDED_PATH, CampaignSnapshot.to_text(_document(6, campaign))),
			"o V6 encerrado foi escrito")
	await _reset_campaign()
	_use_path(V6_ENDED_PATH)
	_check(_save.load_campaign(), "o V6 encerrado carrega pela migração")
	await _advance(0.1)
	_check(_incursion.incursion_number() == 1, "aquela foi a incursão 1")
	_check(_incursion.incursion_state() == SurfaceIncursionController.IncursionState.PREPARATION,
			"a calmaria migrada zerada chama a próxima guilda: a superfície não esquece")
	await _reset_campaign()
	var fresh := _save.snapshot_campaign()
	var fresh_incursion := _incursion_of(fresh)
	for key in [CampaignSnapshot.KEY_INCURSION_NUMBER, CampaignSnapshot.KEY_GUILD_SIZE,
			CampaignSnapshot.KEY_COOLDOWN_REMAINING]:
		fresh_incursion.erase(key)
	_check(_write_text(V6_FRESH_PATH, CampaignSnapshot.to_text(_document(6, fresh))),
			"o V6 sem incursão foi escrito")
	_use_path(V6_FRESH_PATH)
	_check(_save.load_campaign(), "o V6 sem incursão carrega")
	_check(_incursion.incursion_number() == 0 and _incursion.guild_size() == 0
			and _incursion.incursion_state() == SurfaceIncursionController.IncursionState.NOT_STARTED,
			"sem incursão, nada é inventado")


func _test_contradictory_files_are_refused() -> void:
	await _reset_campaign()
	_core.evolve_to(_core_lv2)
	_check(_incursion.start_incursion(), "setup: incursão em campo")
	await _advance(0.05)
	var good := _save.snapshot_campaign()
	_check(_save.validate_campaign(good).is_empty(), "setup: a campanha ativa é válida")
	var cases: Array = []
	var huge := good.duplicate(true)
	_incursion_of(huge)[CampaignSnapshot.KEY_GUILD_SIZE] = 6
	cases.append(["guilda de 6", huge])
	var stray_cooldown := good.duplicate(true)
	_incursion_of(stray_cooldown)[CampaignSnapshot.KEY_COOLDOWN_REMAINING] = 10.0
	cases.append(["calmaria em ACTIVE", stray_cooldown])
	var unnumbered := good.duplicate(true)
	_incursion_of(unnumbered)[CampaignSnapshot.KEY_INCURSION_NUMBER] = 0
	cases.append(["ACTIVE sem número", unnumbered])
	var crowded := good.duplicate(true)
	_incursion_of(crowded)[CampaignSnapshot.KEY_GUILD_SIZE] = 2
	var extra: Dictionary = (_incursion_of(crowded)[CampaignSnapshot.KEY_RAIDERS] as Array)[0].duplicate(true)
	extra[CampaignSnapshot.KEY_RAIDER_ID] = "raider_003"
	(_incursion_of(crowded)[CampaignSnapshot.KEY_RAIDERS] as Array).append(extra)
	cases.append(["mais saqueadores do que a guilda", crowded])
	var outsider := good.duplicate(true)
	((_incursion_of(outsider)[CampaignSnapshot.KEY_RAIDERS] as Array)[0] as Dictionary)[
			CampaignSnapshot.KEY_RAIDER_ID] = "raider_004"
	cases.append(["raider_id além da guilda", outsider])
	for entry in cases:
		_check(not _save.validate_campaign(entry[1]).is_empty(),
				"%s é recusado: %s" % [entry[0], _save.validate_campaign(entry[1])])
	_check(CampaignSnapshot.validate_document(_document(CampaignSnapshot.SAVE_VERSION + 1, good)).contains("save_version não suportado"),
			"save_version = 8 é recusado")
	var before := _snapshot_text()
	for entry in cases:
		_check(_write_text(BAD_PATH, CampaignSnapshot.to_text(_document(7, entry[1]))),
				"arquivo ruim escrito: %s" % entry[0])
		_use_path(BAD_PATH)
		_failed_events.clear()
		_check(not _save.load_campaign() and not _failed_events.is_empty(),
				"%s não carrega e anuncia o motivo" % entry[0])
		_check(_snapshot_text() == before, "o mundo continua intacto")
	await _reset_campaign()


# ==================================================================== helpers


func _launch_and_finish_guild() -> void:
	_core.evolve_to(_core_lv2)
	_check(_incursion.start_incursion(), "setup: a guilda foi largada")
	await _advance(0.05)
	for raider in _alive_raiders():
		raider.receive_damage(9999.0)
	await _advance(0.05)


func _reset_campaign() -> void:
	_set_speed(1.0)
	_incursion.cooldown_duration = COOLDOWN
	_use_path(FRESH_PATH)
	_check(_save.load_campaign(), "setup: a carga de isolamento devolve a campanha do boot")
	_drain_stockpile()
	await _advance(0.1)


func _drain_stockpile() -> void:
	var amounts := _stockpile.snapshot_amounts()
	for resource in _incursion.raider_definition().loot_priority:
		var amount := int(amounts.get(resource.resource_id, 0))
		if amount > 0:
			_stockpile.consume_resource(resource, amount)


func _alive_raiders() -> Array[RaiderRuntime]:
	var found: Array[RaiderRuntime] = []
	for child in _dungeon.get_children():
		var raider := child as RaiderRuntime
		if raider != null and not raider.is_queued_for_deletion() and raider.is_alive() \
				and not raider.has_escaped():
			found.append(raider)
	return found


func _incursion_of(campaign: Dictionary) -> Dictionary:
	return (campaign[CampaignSnapshot.SECTION_SURFACE] as Dictionary)[
			CampaignSnapshot.KEY_INCURSION]


func _document(version: int, campaign: Dictionary) -> Dictionary:
	return {
		CampaignSnapshot.ROOT_FORMAT: CampaignSnapshot.SAVE_FORMAT,
		CampaignSnapshot.ROOT_VERSION: version,
		CampaignSnapshot.ROOT_METADATA: {"saved_at_unix": 1760550000, "probe": "recorrência"},
		CampaignSnapshot.ROOT_CAMPAIGN: campaign,
	}


func _set_speed(value: float) -> void:
	Engine.time_scale = value


func _use_path(path: String) -> void:
	_save.configure_save_path(path)


func _snapshot_text() -> String:
	return _normalize(_save.snapshot_campaign())


func _on_incursion_started(_raiders: Array) -> void:
	_started_events += 1


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
	return "<ausente>" if label == null else label.text


func _document_from_file(path: String) -> Dictionary:
	var parsed: Variant = CampaignSnapshot.parse_document(_read_text(path))
	return {} if parsed == null else parsed as Dictionary


func _source(path: String) -> String:
	return _read_text(path)


func _code_of(path: String) -> String:
	var kept: Array[String] = []
	for line in _source(path).split("\n"):
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
	_save = _scene.get_node("Systems/SaveGameController") as SaveGameController
	_core = _scene.get_node("World/DungeonRoot/MainCore") as CoreRuntime
	_stockpile = (_scene.get_node("World/DungeonRoot/Deposit001") as ResourceDepositRuntime).stockpile
	_invasion_hud = _scene.get_node("UI/InvasionDebugPanel")
	_core_lv2 = load(CORE_LV2_PATH) as CoreDefinition
	_player_before = _presence(PLAYER_PRIMARY)
	_player_backup_before = _presence(PLAYER_BACKUP)
	_incursion.incursion_started.connect(_on_incursion_started)
	_save.operation_failed.connect(_on_operation_failed)
	Engine.set_physics_ticks_per_second(TICKS)
	_use_path(FRESH_PATH)
	_check(_save.save_campaign(), "setup: a campanha do boot virou o pristine da suíte")


func _free_scene() -> void:
	_save = null
	_stockpile = null
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
	print("---- recurring incursion tests finished: %d asserts, %d failure(s) ----"
			% [_asserts, _failures])
	quit(1 if _failures > 0 else 0)
