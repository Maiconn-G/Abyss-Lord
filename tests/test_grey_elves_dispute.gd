extends SceneTree

# Tarefa 27 — o segundo Povo Nativo (Elfos Cinzentos) e a primeira disputa entre povos.
#
# A pergunta desta suíte (GDD §51.1 e §70): o domínio tem mais de um povo, e eles querem coisas
# que se chocam. Atender um custa Legitimidade com o outro, e não há resposta certa.
#
# Quatro blocos:
#   1) contrato — Definition dos Elfos, Definition da disputa, o mesmo controller de povo servindo
#      aos dois por dado, as teclas H/O/P, o Save V9;
#   2) os Elfos — o selo das Raízes dorme no Nv.2, desperta no Nv.3, é rompido como obra, e os
#      pedidos pela tecla H levam os Elfos a 60 — um a menos que o juramento;
#   3) a disputa — só abre com os dois povos encontrados; [P] protege as Raízes (Elfos +15 → 75,
#      juramento, +4 de capacidade; Guarda −15); [O] fortifica o Salão (o inverso, sem juramento
#      élfico); uma decisão só; fuga de saqueador custa 5 aos Elfos;
#   4) persistência V9 — decisão e juramento voltam sem somar a capacidade de novo; loads
#      repetidos; migração V8 no Nv.3 (selo intacto, disputa sem decisão); recusas.

const MAIN_SCENE := preload("res://game/GameMain.tscn")

const ELVES_PATH := "res://data/natives/grey_elves.tres"
const DISPUTE_PATH := "res://data/natives/hall_against_roots.tres"
const DISPUTE_SOURCE := "res://systems/natives/dispute_controller.gd"
const CONTROLLER_SOURCE := "res://systems/natives/native_people_controller.gd"
const SNAPSHOT_SOURCE := "res://systems/persistence/campaign_snapshot.gd"
const PROJECT_SOURCE := "res://project.godot"
const V9_DOC := "res://docs/SAVE_SCHEMA_V9.md"
const IRON_ORE_PATH := "res://data/resources/iron_ore.tres"
const BIOMASS_PATH := "res://data/resources/biomass.tres"
const CORE_LV2_PATH := "res://data/core/core_level_2.tres"
const CORE_LV3_PATH := "res://data/core/core_level_3.tres"

const TEST_DIR := "user://tests/grey_elves"
const FRESH_PATH := "user://tests/grey_elves/pristine.json"
const RESOLVED_PATH := "user://tests/grey_elves/decidida.json"
const V8_PATH := "user://tests/grey_elves/v8.json"
const BAD_PATH := "user://tests/grey_elves/contraditoria.json"
const TEST_PATHS: Array[String] = [FRESH_PATH, RESOLVED_PATH, V8_PATH, BAD_PATH]

const PLAYER_PRIMARY := "user://campaign_save.json"
const PLAYER_BACKUP := "user://campaign_save.bak"

const ORE := &"iron_ore"
const BIOMASS := &"biomass"
const ELVES_SEAL_WORK := 14.0
const GUARD_SEAL_WORK := 10.0
const ELVES_START := 30
const ELVES_GAIN := 15
const SWING := 15
const POPULATION_BONUS := 4
const ROOT_SEAL_POINT := Vector3(-13, 0, 8)
const TICKS := 60

var _failures := 0
var _asserts := 0
var _frames := 0

var _scene: Node
var _dungeon: Node3D
var _guard: NativePeopleController
var _elves: NativePeopleController
var _dispute: DisputeController
var _incursion: SurfaceIncursionController
var _save: SaveGameController
var _core: CoreRuntime
var _core_state: CoreState
var _stockpile: ResourceStockpileState
var _worker: WorkerRuntime
var _iron: ResourceDefinition
var _biomass: ResourceDefinition
var _core_lv2: CoreDefinition
var _core_lv3: CoreDefinition
var _hud: Node

var _opened_events := 0
var _resolved_events := 0
var _elves_oath_events := 0
var _failed_events: Array[String] = []
var _player_before := ""
var _player_backup_before := ""


func _initialize() -> void:
	_run_all()


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > 1500000:
		_check(false, "timeout: a suíte dos Elfos não terminou")
		_finish()
	return false


func _run_all() -> void:
	_test_contract()

	await _boot_scene()
	await _test_root_seal_sleeps_until_level_three()
	await _test_workers_break_the_root_seal()
	await _test_elves_requests_with_real_key()
	await _test_dispute_opens_only_with_both()
	await _test_protect_the_roots()
	await _test_fortify_the_hall()
	await _test_raider_flight_costs_the_elves()
	await _test_save_resolved_dispute()
	await _test_v8_migration_at_level_three()
	await _test_contradictory_files_are_refused()

	await _free_scene()
	_cleanup_test_files()
	_test_player_save_untouched()
	_finish()


# ================================================================ Bloco 1 — contrato


func _test_contract() -> void:
	var elves := load(ELVES_PATH) as NativePeopleDefinition
	_check(elves != null and elves.people_id == &"grey_elves", "os Elfos Cinzentos são um povo")
	if elves == null:
		return
	_check(elves.required_core_level == 3, "o selo das Raízes desperta no Nv.3")
	_check(_close(elves.seal_definition.work_required, ELVES_SEAL_WORK), "o selo exige 14 de trabalho")
	_check(elves.starting_legitimacy == ELVES_START, "os Elfos recebem o Regente com 30")
	_check(elves.requests.size() == 2 and elves.requests[0].resource.resource_id == BIOMASS
			and elves.requests[0].amount == 6 and elves.requests[1].resource.resource_id == ORE
			and elves.requests[1].amount == 6,
			"pedidos: 6 Biomassa e depois 6 Minério")
	_check(elves.requests[0].legitimacy_gain == ELVES_GAIN and elves.requests[1].legitimacy_gain
			== ELVES_GAIN, "cada pedido vale +15")
	_check(ELVES_START + 2 * ELVES_GAIN == elves.oath_threshold - 1,
			"os pedidos sozinhos param a um ponto do juramento (60 de 61)")
	_check(elves.guardian_definition == null and elves.oath_population_bonus == POPULATION_BONUS,
			"o juramento élfico abre +4 de capacidade, sem Guardião")
	_check(elves.request_action == &"fulfill_elves_request" and elves.request_key_label == "H",
			"os pedidos élficos usam a tecla H")
	var dispute := load(DISPUTE_PATH) as DisputeDefinition
	_check(dispute != null and dispute.first_people_id == &"decapitated_guard"
			and dispute.second_people_id == &"grey_elves" and dispute.legitimacy_swing == SWING,
			"a disputa opõe Guarda e Elfos, ±15")
	var controller := _code_of(CONTROLLER_SOURCE)
	_check(not controller.contains("grey_elves") and not controller.contains("decapitated_guard"),
			"o controller de povo não conhece povo nenhum pelo nome: tudo é dado")
	var dispute_code := _code_of(DISPUTE_SOURCE)
	_check(not dispute_code.contains("get_node(") and not dispute_code.contains("get_tree()"),
			"a disputa recebe os povos por injeção")
	for pair in [[&"fulfill_elves_request", KEY_H], [&"dispute_favor_first", KEY_O],
			[&"dispute_favor_second", KEY_P]]:
		var key := InputEventKey.new()
		key.physical_keycode = pair[1]
		_check(InputMap.event_is_action(key, pair[0], false), "%s está na tecla certa" % pair[0])
		for other in InputMap.get_actions():
			if other == pair[0] or String(other).begins_with("ui_"):
				continue
			_check(not InputMap.event_is_action(key, other, false),
					"a tecla de %s não colide com %s" % [pair[0], other])
	var snapshot := _code_of(SNAPSHOT_SOURCE)
	for required in ["const SAVE_VERSION := 9", "const SAVE_VERSION_V8 := 8",
			"static func validate_v9(", "static func migrate_v8_to_v9("]:
		_check(snapshot.contains(required), "campaign_snapshot.gd contém %s" % required)
	_check(FileAccess.file_exists(V9_DOC), "docs/SAVE_SCHEMA_V9.md existe")
	var doc := _read_text(V9_DOC).to_lower()
	for documented in ["grey_elves", "dispute", "resolution", "v8", "v9", "migra"]:
		_check(doc.contains(documented), "o documento V9 documenta %s" % documented)


# ================================================================ Bloco 2 — os Elfos


func _test_root_seal_sleeps_until_level_three() -> void:
	await _reset_campaign()
	_core.evolve_to(_core_lv2)
	await _advance(0.05)
	_check(_elves.seal() == null, "no Nv.2 o selo das Raízes dorme")
	_check(_text_of(_hud, "SecondPeopleLabel") == "Raízes Seladas: adormecido — requer Núcleo Nv.3",
			"o painel diz que o selo dorme: %s" % _text_of(_hud, "SecondPeopleLabel"))
	_core.evolve_to(_core_lv3)
	await _advance(0.05)
	var seal := _elves.seal()
	_check(seal != null and _planar_gap(seal.global_position, ROOT_SEAL_POINT) < 0.01,
			"no Nv.3 o selo das Raízes desperta no canto oeste")
	_check(seal != null and seal != _guard.seal(), "cada povo tem o seu selo")
	_check(_text_of(_hud, "SecondPeopleLabel").begins_with("Raízes Seladas: desperto"),
			"o painel anuncia: %s" % _text_of(_hud, "SecondPeopleLabel"))


func _test_workers_break_the_root_seal() -> void:
	var seal := _elves.seal()
	_worker.global_position = seal.global_position + Vector3(1.6, 0.0, 0.0)
	_worker.reset_transient_order()
	_worker.assign_construction_target(seal)
	_check(_worker.is_building(), "o Trabalhador aceita o selo das Raízes como obra")
	Engine.time_scale = 4.0
	var broken := await _wait_until(func() -> bool: return _elves.is_discovered(), 15.0)
	Engine.time_scale = 1.0
	_check(broken, "o selo das Raízes foi rompido")
	_check(_elves.legitimacy().value == ELVES_START and _elves.legitimacy().band_name() == "desconfiado",
			"os Elfos recebem o Regente com 30")
	_check(_text_of(_hud, "SecondPeopleLabel") == "Elfos Cinzentos encontrados",
			"o painel encontra os Elfos")
	_check(not _guard.is_discovered(), "a Guarda continua sem ser encontrada")


func _test_elves_requests_with_real_key() -> void:
	_drain()
	_stockpile.add_resource(_biomass, 6)
	_stockpile.add_resource(_iron, 6)
	await _advance(0.05)
	_check(_text_of(_hud, "SecondRequestLabel") == "[H] Pedido: Raízes famintas — 6 Biomassa (+15)",
			"o painel mostra o pedido e a tecla: %s" % _text_of(_hud, "SecondRequestLabel"))
	await _press(KEY_J)
	_check(_elves.requests_fulfilled() == 0 and _stockpile.get_amount(BIOMASS) == 6,
			"a tecla J é da Guarda: não cumpre pedido élfico")
	await _press(KEY_H)
	_check(_elves.requests_fulfilled() == 1 and _stockpile.get_amount(BIOMASS) == 0,
			"a tecla H cumpre o primeiro pedido élfico")
	await _press(KEY_H)
	_check(_elves.requests_fulfilled() == 2 and _stockpile.get_amount(ORE) == 0,
			"a tecla H cumpre o segundo")
	_check(_elves.legitimacy().value == 60, "os Elfos chegam a 60")
	_check(not _elves.has_sworn_oath(), "60 ainda não é juramento")
	_check(_text_of(_hud, "SecondRequestLabel") == "Todos os pedidos dos Elfos foram cumpridos",
			"o painel encerra os pedidos élficos")


# ================================================================ Bloco 3 — a disputa


func _test_dispute_opens_only_with_both() -> void:
	_check(not _dispute.is_open(), "com só os Elfos encontrados não há disputa")
	_check(_text_of(_hud, "DisputeLabel") == "", "o painel não mostra disputa")
	await _press(KEY_P)
	_check(_dispute.resolution() == DisputeController.Resolution.UNRESOLVED,
			"não se decide uma disputa que não existe")
	_opened_events = 0
	_guard.seal().state.apply_work(GUARD_SEAL_WORK)
	await _advance(0.05)
	_check(_guard.is_discovered(), "a Guarda foi encontrada")
	_check(_dispute.is_open() and _opened_events == 1, "com os dois encontrados a disputa se abre, uma vez")
	_check(_text_of(_hud, "DisputeLabel").begins_with("DISPUTA: O Salão contra as Raízes"),
			"o painel anuncia a disputa: %s" % _text_of(_hud, "DisputeLabel"))
	_check(_text_of(_hud, "DisputeChoiceLabel").contains("[O] Fortificar o Salão")
			and _text_of(_hud, "DisputeChoiceLabel").contains("[P] Proteger as Raízes"),
			"o painel mostra os dois lados: %s" % _text_of(_hud, "DisputeChoiceLabel"))


func _test_protect_the_roots() -> void:
	var guard_before := _guard.legitimacy().value
	var capacity := _core_state.get_population_capacity()
	_elves_oath_events = 0
	_resolved_events = 0
	await _press(KEY_P)
	_check(_dispute.resolution() == DisputeController.Resolution.SECOND and _resolved_events == 1,
			"[P] protege as Raízes")
	_check(_elves.legitimacy().value == 75, "os Elfos sobem para 75")
	_check(_guard.legitimacy().value == guard_before - SWING,
			"a Guarda perde 15: %d → %d" % [guard_before, _guard.legitimacy().value])
	_check(_elves.has_sworn_oath() and _elves_oath_events == 1, "os Elfos prestam juramento")
	_check(_core_state.get_population_capacity() == capacity + POPULATION_BONUS,
			"as galerias das Raízes abrigam +4: capacidade %d → %d"
					% [capacity, _core_state.get_population_capacity()])
	_check(_elves.guardian() == null, "o juramento élfico não traz Guardião")
	_check(_text_of(_hud, "SecondOathLabel")
			== "Juramento prestado — as galerias das Raízes abrigam +4 de população",
			"o painel mostra o que o juramento deu: %s" % _text_of(_hud, "SecondOathLabel"))
	_check(_text_of(_hud, "DisputeLabel") == "O Salão contra as Raízes — decidida: Proteger as Raízes",
			"o painel registra a decisão: %s" % _text_of(_hud, "DisputeLabel"))
	await _press(KEY_O)
	_check(_dispute.resolution() == DisputeController.Resolution.SECOND and _resolved_events == 1,
			"a disputa se decide uma vez só")
	_check(_core_state.get_population_capacity() == capacity + POPULATION_BONUS,
			"nem o bônus nem a Legitimidade se movem de novo")


func _test_fortify_the_hall() -> void:
	await _discover_both()
	var guard_before := _guard.legitimacy().value
	var elves_before := _elves.legitimacy().value
	var capacity := _core_state.get_population_capacity()
	await _press(KEY_O)
	_check(_dispute.resolution() == DisputeController.Resolution.FIRST, "[O] fortifica o Salão")
	_check(_guard.legitimacy().value == guard_before + SWING, "a Guarda sobe 15")
	_check(_elves.legitimacy().value == elves_before - SWING, "os Elfos perdem 15")
	_check(not _elves.has_sworn_oath(), "sem as Raízes protegidas, os Elfos não juram")
	_check(_core_state.get_population_capacity() == capacity, "nenhuma capacidade nova")


func _test_raider_flight_costs_the_elves() -> void:
	await _discover_both()
	var before := _elves.legitimacy().value
	_check(_incursion.start_incursion(), "setup: guilda largada")
	await _advance(0.05)
	Engine.time_scale = 4.0
	await _wait_until(func() -> bool: return _incursion_ended(), 40.0)
	Engine.time_scale = 1.0
	var fled := _incursion.escaped_count()
	_check(fled > 0, "saqueadores fugiram: %d" % fled)
	_check(_elves.legitimacy().value == before - 5 * fled,
			"cada fuga custa 5 aos Elfos: %d → %d" % [before, _elves.legitimacy().value])


# ======================================================== Bloco 4 — persistência V9


func _test_save_resolved_dispute() -> void:
	await _discover_both()
	_elves.legitimacy().add(2 * ELVES_GAIN)
	var capacity_before_oath := _core_state.get_population_capacity()
	_check(_dispute.resolve(DisputeController.Resolution.SECOND), "setup: Raízes protegidas")
	_check(_elves.has_sworn_oath(), "setup: os Elfos juraram")
	var capacity := _core_state.get_population_capacity()
	_check(capacity == capacity_before_oath + POPULATION_BONUS, "setup: +4 de capacidade")
	_use_path(RESOLVED_PATH)
	_check(_save.save_campaign(), "save com a disputa decidida")
	var natives: Dictionary = _document_from_file(RESOLVED_PATH)[CampaignSnapshot.ROOT_CAMPAIGN][
			CampaignSnapshot.SECTION_NATIVES]
	_check(natives[CampaignSnapshot.KEY_DISPUTE][CampaignSnapshot.KEY_RESOLUTION] == "SECOND",
			"a decisão está no arquivo")
	_check(bool(natives[CampaignSnapshot.ELVES_PEOPLE_ID][CampaignSnapshot.KEY_OATH_SWORN]),
			"o juramento élfico está no arquivo")
	_resolved_events = 0
	_elves_oath_events = 0
	for attempt in 3:
		_check(_save.load_campaign(), "load repetido %d" % (attempt + 1))
		await _advance(0.05)
	_check(_dispute.resolution() == DisputeController.Resolution.SECOND, "a decisão voltou")
	_check(_core_state.get_population_capacity() == capacity,
			"a capacidade volta igual — o bônus não é somado de novo: %d"
					% _core_state.get_population_capacity())
	_check(_resolved_events == 0 and _elves_oath_events == 0,
			"a carga não reanuncia decisão nem juramento")
	_check(_seal_count() == 2, "dois selos, um de cada povo, obtido %d" % _seal_count())


func _test_v8_migration_at_level_three() -> void:
	await _reset_campaign()
	_core.evolve_to(_core_lv2)
	_core.evolve_to(_core_lv3)
	await _advance(0.05)
	var campaign := _save.snapshot_campaign()
	var natives: Dictionary = campaign[CampaignSnapshot.SECTION_NATIVES]
	natives.erase(CampaignSnapshot.ELVES_PEOPLE_ID)
	natives.erase(CampaignSnapshot.KEY_DISPUTE)
	_check(CampaignSnapshot.validate_v8(campaign).is_empty(),
			"sem Elfos nem disputa é um V8 válido: %s" % CampaignSnapshot.validate_v8(campaign))
	_check(not CampaignSnapshot.validate_v9(campaign).is_empty(), "como V9 é recusada")
	_check(_write_text(V8_PATH, CampaignSnapshot.to_text(_document(8, campaign))), "V8 escrito")
	await _reset_campaign()
	_use_path(V8_PATH)
	_check(_save.load_campaign(), "o V8 carrega pela migração")
	_check(_elves.seal() != null and not _elves.seal().is_completed(),
			"uma campanha Nv.3 antiga ganha o selo das Raízes, intacto")
	_check(not _elves.is_discovered() and _dispute.resolution()
			== DisputeController.Resolution.UNRESOLVED, "e nada foi decidido")


func _test_contradictory_files_are_refused() -> void:
	await _discover_both()
	var good := _save.snapshot_campaign()
	_check(_save.validate_campaign(good).is_empty(), "setup: a campanha com os dois povos é válida")
	var cases: Array = []
	var elf_guardian := good.duplicate(true)
	_elves_entry(elf_guardian)[CampaignSnapshot.KEY_OATH_SWORN] = true
	_elves_entry(elf_guardian)[CampaignSnapshot.KEY_LEGITIMACY] = 70
	_elves_entry(elf_guardian)[CampaignSnapshot.KEY_GUARDIAN] = {
		CampaignSnapshot.KEY_ALIVE: true, CampaignSnapshot.KEY_HEALTH: 50.0,
		CampaignSnapshot.KEY_LEVEL: 1, CampaignSnapshot.KEY_EXPERIENCE: 0.0,
		CampaignSnapshot.KEY_POSITION: [0.0, 0.0, 0.0]}
	cases.append(["Guardião élfico", elf_guardian])
	var early := good.duplicate(true)
	_elves_entry(early)[CampaignSnapshot.KEY_SEAL_WORK_DONE] = 0.0
	_elves_entry(early)[CampaignSnapshot.KEY_LEGITIMACY] = 0
	_dispute_of(early)[CampaignSnapshot.KEY_RESOLUTION] = "FIRST"
	cases.append(["disputa decidida sem os Elfos encontrados", early])
	var unknown := good.duplicate(true)
	_dispute_of(unknown)[CampaignSnapshot.KEY_RESOLUTION] = "BOTH"
	cases.append(["decisão desconhecida", unknown])
	var missing := good.duplicate(true)
	(missing[CampaignSnapshot.SECTION_NATIVES] as Dictionary).erase(CampaignSnapshot.ELVES_PEOPLE_ID)
	cases.append(["V9 sem os Elfos", missing])
	var low := good.duplicate(true)
	(low[CampaignSnapshot.SECTION_CORE] as Dictionary)[CampaignSnapshot.KEY_LEVEL] = 2
	(low[CampaignSnapshot.SECTION_CORE] as Dictionary)[CampaignSnapshot.KEY_INTEGRITY] = 100.0
	(low[CampaignSnapshot.SECTION_CORE] as Dictionary)[CampaignSnapshot.KEY_ESSENCE] = 10.0
	cases.append(["selo das Raízes trabalhado no Nv.2", low])
	for entry in cases:
		_check(not _save.validate_campaign(entry[1]).is_empty(),
				"%s é recusado: %s" % [entry[0], _save.validate_campaign(entry[1])])
	_check(CampaignSnapshot.validate_document(_document(10, good)).contains("save_version não suportado"),
			"save_version = 10 é recusado")
	var before := _snapshot_text()
	for entry in cases:
		_write_text(BAD_PATH, CampaignSnapshot.to_text(_document(9, entry[1])))
		_use_path(BAD_PATH)
		_failed_events.clear()
		_check(not _save.load_campaign() and not _failed_events.is_empty(),
				"%s não carrega e anuncia o motivo" % entry[0])
		_check(_snapshot_text() == before, "o mundo continua intacto")
	await _reset_campaign()


# ==================================================================== helpers


func _incursion_ended() -> bool:
	return _incursion.incursion_state() == SurfaceIncursionController.IncursionState.ENDED


func _discover_both() -> void:
	await _reset_campaign()
	_core.evolve_to(_core_lv2)
	_core.evolve_to(_core_lv3)
	await _advance(0.05)
	_guard.seal().state.apply_work(GUARD_SEAL_WORK)
	_elves.seal().state.apply_work(ELVES_SEAL_WORK)
	await _advance(0.05)
	_check(_guard.is_discovered() and _elves.is_discovered(), "setup: os dois povos encontrados")


func _reset_campaign() -> void:
	Engine.time_scale = 1.0
	_use_path(FRESH_PATH)
	_check(_save.load_campaign(), "setup: a carga de isolamento devolve a campanha do boot")
	await _advance(0.1)


func _drain() -> void:
	for resource in [_biomass, _iron]:
		var amount := _stockpile.get_amount(resource.resource_id)
		if amount > 0:
			_stockpile.consume_resource(resource, amount)


func _elves_entry(campaign: Dictionary) -> Dictionary:
	return (campaign[CampaignSnapshot.SECTION_NATIVES] as Dictionary)[CampaignSnapshot.ELVES_PEOPLE_ID]


func _dispute_of(campaign: Dictionary) -> Dictionary:
	return (campaign[CampaignSnapshot.SECTION_NATIVES] as Dictionary)[CampaignSnapshot.KEY_DISPUTE]


func _seal_count() -> int:
	var total := 0
	for child in _dungeon.get_children():
		if child is AncientSealRuntime and not child.is_queued_for_deletion():
			total += 1
	return total


func _press(keycode: Key) -> void:
	var pressed := InputEventKey.new()
	pressed.physical_keycode = keycode
	pressed.pressed = true
	Input.parse_input_event(pressed)
	var released := InputEventKey.new()
	released.physical_keycode = keycode
	released.pressed = false
	Input.parse_input_event(released)
	await _advance(0.1)


func _document(version: int, campaign: Dictionary) -> Dictionary:
	return {
		CampaignSnapshot.ROOT_FORMAT: CampaignSnapshot.SAVE_FORMAT,
		CampaignSnapshot.ROOT_VERSION: version,
		CampaignSnapshot.ROOT_METADATA: {"saved_at_unix": 1760570000, "probe": "elfos"},
		CampaignSnapshot.ROOT_CAMPAIGN: campaign,
	}


func _use_path(path: String) -> void:
	_save.configure_save_path(path)


func _snapshot_text() -> String:
	return _normalize(_save.snapshot_campaign())


func _on_opened() -> void:
	_opened_events += 1


func _on_resolved(_resolution: int) -> void:
	_resolved_events += 1


func _on_elves_oath(_guardian: SoldierRuntime) -> void:
	_elves_oath_events += 1


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
	_guard = _scene.get_node("Systems/NativePeopleController") as NativePeopleController
	_elves = _scene.get_node("Systems/GreyElvesController") as NativePeopleController
	_dispute = _scene.get_node("Systems/DisputeController") as DisputeController
	_incursion = _scene.get_node(
			"Systems/SurfaceIncursionController") as SurfaceIncursionController
	_save = _scene.get_node("Systems/SaveGameController") as SaveGameController
	_core = _scene.get_node("World/DungeonRoot/MainCore") as CoreRuntime
	_worker = _scene.get_node("World/DungeonRoot/Worker001") as WorkerRuntime
	_stockpile = (_scene.get_node("World/DungeonRoot/Deposit001") as ResourceDepositRuntime).stockpile
	_core_state = _core.core_state()
	_hud = _scene.get_node("UI/NativesDebugPanel")
	_iron = load(IRON_ORE_PATH) as ResourceDefinition
	_biomass = load(BIOMASS_PATH) as ResourceDefinition
	_core_lv2 = load(CORE_LV2_PATH) as CoreDefinition
	_core_lv3 = load(CORE_LV3_PATH) as CoreDefinition
	_player_before = _presence(PLAYER_PRIMARY)
	_player_backup_before = _presence(PLAYER_BACKUP)
	_dispute.dispute_opened.connect(_on_opened)
	_dispute.dispute_resolved.connect(_on_resolved)
	_elves.oath_sworn.connect(_on_elves_oath)
	_save.operation_failed.connect(_on_operation_failed)
	Engine.set_physics_ticks_per_second(TICKS)
	_use_path(FRESH_PATH)
	_check(_save.save_campaign(), "setup: a campanha do boot virou o pristine da suíte")


func _free_scene() -> void:
	_save = null
	_stockpile = null
	_core_state = null
	_core = null
	_worker = null
	_guard = null
	_elves = null
	_dispute = null
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
	print("---- grey elves and dispute tests finished: %d asserts, %d failure(s) ----"
			% [_asserts, _failures])
	quit(1 if _failures > 0 else 0)
