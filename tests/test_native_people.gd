extends SceneTree

# Tarefa 24 — o primeiro Povo Nativo: a Guarda Decapitada.
#
# A pergunta desta suíte é a do GDD §51.1: o domínio herdado já tinha gente, e ela não
# aceita automaticamente um humano no trono. Por isso cada cenário mede Legitimidade, o que
# a move (pedidos, mérito, perda) e o que ela entrega (o juramento e o Guardião).
#
# Quatro blocos:
#   1) contrato e guarda de fonte — Definition, LegitimacyState, o selo é obra, o Guardião é
#      Soldado, nenhum sistema genérico de facções, tecla J, Save V6;
#   2) o selo — dorme no Nv.1, desperta com a evolução real, é rompido por Trabalhadores pela
#      ordem genérica de obra, e romper encontra a Guarda com Legitimidade 25;
#   3) a Legitimidade — pedidos em ordem e atômicos, juramento aos 61 com o Guardião, mérito e
#      perda pela Incursão da Superfície, o Guardião que cai, o juramento que é histórico;
#   4) persistência V6 — selo pela metade, Guarda encontrada, Guardião ferido, loads repetidos,
#      Nv.1 sem selo, migração V5 (Nv.1 e Nv.2), corrente V1→V6 e recusas com mundo intacto.

const MAIN_SCENE := preload("res://game/GameMain.tscn")

const PEOPLE_DEFINITION_PATH := "res://data/natives/decapitated_guard.tres"
const CONTROLLER_SOURCE := "res://systems/natives/native_people_controller.gd"
const SEAL_SOURCE := "res://world/dungeon/natives/ancient_seal_runtime.gd"
const GUARDIAN_SCENE_PATH := "res://units/natives/DecapitatedGuardianRuntime.tscn"
const SNAPSHOT_SOURCE := "res://systems/persistence/campaign_snapshot.gd"
const SELECTION_SOURCE := "res://systems/selection/selection_controller.gd"
const WORKER_SOURCE := "res://units/workers/worker_runtime.gd"
const GAME_MAIN_SOURCE := "res://game/game_main.gd"
const PROJECT_SOURCE := "res://project.godot"
const CI_SOURCE := "res://.github/workflows/ci.yml"
const V6_DOC := "res://docs/SAVE_SCHEMA_V6.md"
const IRON_ORE_PATH := "res://data/resources/iron_ore.tres"
const BIOMASS_PATH := "res://data/resources/biomass.tres"
const CORE_LV2_PATH := "res://data/core/core_level_2.tres"

const TEST_DIR := "user://tests/native_people"
const FRESH_PATH := "user://tests/native_people/pristine.json"
const HALF_SEAL_PATH := "user://tests/native_people/selo_pela_metade.json"
const DISCOVERED_PATH := "user://tests/native_people/encontrada.json"
const GUARDIAN_PATH := "user://tests/native_people/guardiao.json"
const LEVEL_ONE_PATH := "user://tests/native_people/nv1.json"
const V5_LV1_PATH := "user://tests/native_people/v5_nv1.json"
const V5_LV2_PATH := "user://tests/native_people/v5_nv2.json"
const V1_PATH := "user://tests/native_people/v1.json"
const BAD_PATH := "user://tests/native_people/contraditoria.json"
const TEST_PATHS: Array[String] = [FRESH_PATH, HALF_SEAL_PATH, DISCOVERED_PATH, GUARDIAN_PATH,
		LEVEL_ONE_PATH, V5_LV1_PATH, V5_LV2_PATH, V1_PATH, BAD_PATH]

const PLAYER_PRIMARY := "user://campaign_save.json"
const PLAYER_BACKUP := "user://campaign_save.bak"

const ORE := &"iron_ore"
const BIOMASS := &"biomass"

## Os números da tarefa, conferidos contra o arquivo.
const SEAL_WORK := 10.0
const STARTING_LEGITIMACY := 25
const ARMOR_COST := 8
const VIGIL_COST := 5
const REQUEST_GAIN := 20
const SLAIN_GAIN := 5
const FLED_LOSS := 10
const FALLEN_LOSS := 10
const OATH := 61
const GUARDIAN_HEALTH := 140.0
const GUARDIAN_DAMAGE := 16.0
const SEAL_POINT := Vector3(12, 0, 7)
const GUARDIAN_POINT := Vector3(10.5, 0, 5)
const CONSTRUCTION_LAYER := 16

const HUD_ASLEEP := "Selo Antigo: adormecido — requer Núcleo Nv.2"
const HUD_AWAKE := "Selo Antigo: desperto — rompa-o com Trabalhadores (0%)"
const HUD_FOUND := "Guarda Decapitada encontrada"
const HUD_ARMOR_READY := "[J] Pedido: Aço para as armaduras — 8 Minério de Ferro (+20)"
const HUD_ARMOR_SHORT := "Pedido: Aço para as armaduras — 8 Minério de Ferro (recursos insuficientes)"
const HUD_ALL_DONE := "Todos os pedidos da Guarda foram cumpridos"
const HUD_OATH_PENDING := "Juramento: aos 61 de Legitimidade"
const HUD_VIGIL := "Juramento prestado — o Guardião Decapitado está em vigília"
const HUD_FALLEN := "Juramento prestado — o Guardião caiu em combate"

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
var _natives: NativePeopleController
var _incursion: SurfaceIncursionController
var _invasion: InvasionController
var _evolution: CoreEvolutionController
var _save: SaveGameController
var _core: CoreRuntime
var _core_state: CoreState
var _crystal: AbyssalCrystalState
var _stockpile: ResourceStockpileState
var _worker: WorkerRuntime
var _iron: ResourceDefinition
var _biomass: ResourceDefinition
var _core_lv2: CoreDefinition
var _hud: Node

var _awakened_events := 0
var _discovered_events := 0
var _oath_events := 0
var _failed_events: Array[String] = []
var _player_before := ""
var _player_backup_before := ""


func _initialize() -> void:
	_run_all()


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > 1500000:
		_check(false, "timeout: a suíte do povo nativo não terminou")
		_finish()
	return false


func _run_all() -> void:
	_test_definition_contract()
	_test_legitimacy_state()
	_test_scope_guards()

	await _boot_scene()
	await _test_seal_sleeps_at_level_one()
	await _test_real_evolution_awakens_the_seal()
	await _test_workers_break_the_seal()
	await _test_requests_in_order_and_atomic()
	await _test_oath_brings_the_guardian()
	await _test_merit_from_the_incursion()
	await _test_guardian_fights_and_falls()
	await _test_oath_is_historical()
	await _test_save_half_broken_seal()
	await _test_save_discovered_people()
	await _test_save_guardian_and_repeated_loads()
	await _test_level_one_file_removes_the_seal()
	await _test_v5_migration()
	await _test_v1_chain_reaches_v6()
	await _test_contradictory_files_are_refused()

	await _free_scene()
	_cleanup_test_files()
	_test_player_save_untouched()
	print("[INFO] medições do povo nativo: %s" % [_measurements])
	_finish()


# ================================================== Bloco 1 — contrato sem cena


func _test_definition_contract() -> void:
	var people := load(PEOPLE_DEFINITION_PATH) as NativePeopleDefinition
	_check(people != null, "a Guarda Decapitada é uma NativePeopleDefinition")
	if people == null:
		return
	_check(people.people_id == &"decapitated_guard", "people_id decapitated_guard")
	_check(people.display_name == "Guarda Decapitada", "nome Guarda Decapitada")
	_check(people.required_core_level == 2, "o selo desperta no Nv.2")
	_check(people.seal_definition != null and _close(people.seal_definition.work_required, SEAL_WORK),
			"o selo exige %.0f de trabalho" % SEAL_WORK)
	_check(people.seal_definition.build_cost == 0, "romper o selo não custa recurso")
	_check(people.starting_legitimacy == STARTING_LEGITIMACY, "a Guarda recebe o Regente com 25")
	_check(people.requests.size() == 2, "dois pedidos")
	if people.requests.size() == 2:
		var armor := people.requests[0]
		var vigil := people.requests[1]
		_check(armor.resource.resource_id == ORE and armor.amount == ARMOR_COST
				and armor.legitimacy_gain == REQUEST_GAIN,
				"o primeiro pedido é 8 Minério por +20")
		_check(vigil.resource.resource_id == BIOMASS and vigil.amount == VIGIL_COST
				and vigil.legitimacy_gain == REQUEST_GAIN,
				"o segundo pedido é 5 Biomassa por +20")
		_check(armor.resource == load(IRON_ORE_PATH) and vigil.resource == load(BIOMASS_PATH),
				"os pedidos usam as Resources genéricas do estoque")
	_check(people.legitimacy_per_raider_slain == SLAIN_GAIN
			and people.legitimacy_per_raider_fled == FLED_LOSS
			and people.legitimacy_per_guardian_fallen == FALLEN_LOSS,
			"mérito +5, fuga −10, Guardião caído −10")
	_check(people.oath_threshold == OATH, "o juramento vem aos 61")
	var guardian := people.guardian_definition
	_check(guardian != null and guardian.unit_type_id == &"decapitated_guardian"
			and _close(guardian.max_health, GUARDIAN_HEALTH)
			and _close(guardian.attack_damage, GUARDIAN_DAMAGE),
			"o Guardião tem 140 de vida e 16 de dano")
	_check(STARTING_LEGITIMACY + 2 * REQUEST_GAIN >= OATH,
			"os dois pedidos sozinhos levam a Guarda ao juramento (25 + 40 ≥ 61)")


func _test_legitimacy_state() -> void:
	var legitimacy := LegitimacyState.new()
	_check(legitimacy.value == 0 and legitimacy.band() == LegitimacyState.Band.HOSTILE,
			"começa em 0, hostil")
	legitimacy.add(25)
	_check(legitimacy.band_name() == "desconfiado", "25 é desconfiado")
	legitimacy.add(20)
	_check(legitimacy.band_name() == "tolerante", "45 é tolerante")
	legitimacy.add(20)
	_check(legitimacy.band_name() == "leal", "65 é leal")
	legitimacy.add(500)
	_check(legitimacy.value == 100 and legitimacy.band_name() == "devoto", "teto 100, devoto")
	legitimacy.remove(500)
	_check(legitimacy.value == 0, "o chão é 0")
	var emitted := [0]
	legitimacy.legitimacy_changed.connect(func(_c: int, _m: int) -> void: emitted[0] += 1)
	legitimacy.remove(5)
	legitimacy.add(0)
	legitimacy.add(-3)
	_check(emitted[0] == 0, "nada muda → nenhum sinal")
	_check(not legitimacy.restore(101) and not legitimacy.restore(-1) and legitimacy.value == 0,
			"restaurar fora da faixa não toca em nada")
	_check(legitimacy.restore(61) and legitimacy.value == 61, "restaurar devolve o valor")


func _test_scope_guards() -> void:
	_check(_code_of(SEAL_SOURCE).contains("extends ConstructionRuntime"),
			"o selo é uma obra — Trabalhadores o rompem pela ordem genérica")
	var guardian_scene := _source(GUARDIAN_SCENE_PATH)
	_check(guardian_scene.contains("res://units/soldiers/soldier_runtime.gd"),
			"o Guardião usa o Runtime do Soldado — combate e seleção sem branch")
	_check(guardian_scene.contains("rts_selectable"), "o Guardião é selecionável")
	for source in [SELECTION_SOURCE, WORKER_SOURCE]:
		var code := _code_of(source)
		_check(not code.contains("Seal") and not code.contains("Native")
				and not code.contains("Guardian"),
				"%s não conhece selo, povo nem Guardião" % source.get_file())
	var controller := _code_of(CONTROLLER_SOURCE)
	_check(not controller.contains("get_node(") and not controller.contains("get_tree()"),
			"o controller do povo recebe tudo por injeção")
	_check(not controller.contains("try_add_population"),
			"o Guardião não ocupa população do Núcleo")
	var sources := _collect_gd_files("res://")
	for forbidden in ["FactionManager", "FactionSystem", "ReputationSystem", "ReputationManager",
			"DiplomacyManager", "RelationshipManager", "NativeManager", "QuestManager",
			"QuestSystem", "PeopleRegistry"]:
		_check(_files_named(sources, forbidden).is_empty()
				and _files_containing(sources, "class_name %s" % forbidden).is_empty(),
				"nenhum %s foi criado" % forbidden)
	_check(_source(PROJECT_SOURCE).contains("fulfill_native_request="),
			"a ação fulfill_native_request existe")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_J
	_check(InputMap.event_is_action(key, &"fulfill_native_request", false), "a tecla J a dispara")
	for other in InputMap.get_actions():
		if other == &"fulfill_native_request" or String(other).begins_with("ui_"):
			continue
		_check(not InputMap.event_is_action(key, other, false), "a tecla J não colide com %s" % other)
	var snapshot := _code_of(SNAPSHOT_SOURCE)
	for required in ["const SAVE_VERSION_V6 := 6", "const SAVE_VERSION_V5 := 5",
			"static func validate_v6(", "static func migrate_v5_to_v6(",
			"static func migrate_v4_to_v5("]:
		_check(snapshot.contains(required), "campaign_snapshot.gd contém %s" % required)
	_check(FileAccess.file_exists(V6_DOC), "docs/SAVE_SCHEMA_V6.md existe")
	var doc := _source(V6_DOC).to_lower()
	for documented in ["natives", "decapitated_guard", "seal_work_done", "legitimacy",
			"requests_fulfilled", "oath_sworn", "guardian", "v5", "v6", "migra"]:
		_check(doc.contains(documented), "o documento V6 documenta %s" % documented)
	_check(not _source(CI_SOURCE).contains("native_people"),
			"o workflow não lista suíte nenhuma — a descoberta é automática")
	_check(not _code_of(GAME_MAIN_SOURCE).contains("guardian_001")
			and not _code_of(GAME_MAIN_SOURCE).contains("ancient_seal_001"),
			"a raiz de composição não conhece instância nenhuma")


# ================================================== Bloco 2 — o selo


func _test_seal_sleeps_at_level_one() -> void:
	await _reset_campaign()
	_check(_natives.seal() == null, "no Nv.1 não existe selo")
	_check(_seal_count() == 0, "nenhum selo no mundo")
	_check(_text_of(_hud, "PeopleLabel") == HUD_ASLEEP,
			"o painel diz que o selo dorme, obtido %s" % _text_of(_hud, "PeopleLabel"))
	_give(_iron, ARMOR_COST)
	await _press(KEY_J)
	_check(_stockpile.get_amount(ORE) == ARMOR_COST, "a tecla J não faz nada antes da Guarda")


func _test_real_evolution_awakens_the_seal() -> void:
	await _reset_campaign()
	_awakened_events = 0
	await _reach_level_two_for_real()
	var seal := _natives.seal()
	_check(seal != null and _awakened_events == 1, "a evolução real desperta o selo, uma vez")
	if seal == null:
		return
	_check(_planar_gap(seal.global_position, SEAL_POINT) < 0.01, "o selo está no canto leste")
	_check(seal.collision_layer & CONSTRUCTION_LAYER != 0, "o selo está na camada Construction")
	_check(not seal.is_completed(), "o selo nasce intacto")
	_check(_text_of(_hud, "PeopleLabel") == HUD_AWAKE,
			"o painel anuncia o selo desperto, obtido %s" % _text_of(_hud, "PeopleLabel"))
	_check(not _natives.is_discovered(), "a Guarda ainda não foi encontrada")
	_check(_natives.legitimacy().value == 0, "sem Guarda, sem Legitimidade")


func _test_workers_break_the_seal() -> void:
	await _reset_campaign()
	_core.evolve_to(_core_lv2)
	await _advance(0.05)
	var seal := _natives.seal()
	_discovered_events = 0
	_worker.global_position = seal.global_position + Vector3(-1.6, 0.0, 0.0)
	_worker.reset_transient_order()
	_worker.assign_construction_target(seal)
	_check(_worker.is_building(), "o Trabalhador aceita o selo como obra")
	await _advance(1.0)
	var done := _natives.seal_work_done()
	_check(done > 0.5 and done < SEAL_WORK, "o trabalho rompe o selo aos poucos, %f" % done)
	_check(_text_of(_hud, "PeopleLabel").begins_with("Selo Antigo: desperto"),
			"o painel acompanha o progresso: %s" % _text_of(_hud, "PeopleLabel"))
	_set_speed(SPEED)
	var broken := await _wait_until(func() -> bool: return _natives.is_discovered(), 10.0)
	_set_speed(1.0)
	_check(broken, "o selo foi rompido")
	_check(seal.is_completed(), "a obra do selo está concluída — o salão está aberto")
	_check(_discovered_events == 1, "people_discovered emitido uma vez")
	_check(_natives.legitimacy().value == STARTING_LEGITIMACY,
			"a Guarda recebe o Regente com %d" % STARTING_LEGITIMACY)
	_check(_natives.legitimacy().band_name() == "desconfiado", "desconfiada")
	await _advance(0.1)
	_check(not _worker.is_building(), "com o selo aberto o Trabalhador para")
	_check(_text_of(_hud, "PeopleLabel") == HUD_FOUND, "o painel diz que a Guarda foi encontrada")
	_check(_text_of(_hud, "LegitimacyLabel") == "Legitimidade: 25/100 (desconfiado)",
			"o painel mostra a Legitimidade, obtido %s" % _text_of(_hud, "LegitimacyLabel"))
	_check(_text_of(_hud, "OathLabel") == HUD_OATH_PENDING, "o painel mostra o limiar do juramento")
	seal.state.apply_work(5.0)
	_check(_discovered_events == 1, "trabalhar no selo aberto não encontra a Guarda de novo")


# ================================================ Bloco 3 — a Legitimidade


func _test_requests_in_order_and_atomic() -> void:
	await _discover_people()
	_drain_stockpile()
	_give(_biomass, VIGIL_COST)
	await _advance(0.05)
	_check(_natives.request_gate() == NativePeopleController.RequestGate.INSUFFICIENT,
			"sem Minério o primeiro pedido não pode ser cumprido")
	_check(_text_of(_hud, "RequestLabel") == HUD_ARMOR_SHORT,
			"o painel mostra o pedido e a falta: %s" % _text_of(_hud, "RequestLabel"))
	await _press(KEY_J)
	_check(_natives.requests_fulfilled() == 0 and _stockpile.get_amount(BIOMASS) == VIGIL_COST,
			"a Biomassa não pula a fila: os pedidos vêm em ordem")
	_check(_natives.legitimacy().value == STARTING_LEGITIMACY, "nada muda")
	_give(_iron, ARMOR_COST + 2)
	await _advance(0.05)
	_check(_text_of(_hud, "RequestLabel") == HUD_ARMOR_READY,
			"o painel acompanha o estoque: %s" % _text_of(_hud, "RequestLabel"))
	await _press(KEY_J)
	_check(_stockpile.get_amount(ORE) == 2, "o pedido levou exatamente 8 de Minério")
	_check(_natives.requests_fulfilled() == 1, "um pedido cumprido")
	_check(_natives.legitimacy().value == STARTING_LEGITIMACY + REQUEST_GAIN,
			"a Legitimidade subiu 20: %d" % _natives.legitimacy().value)
	_check(_natives.legitimacy().band_name() == "tolerante", "a Guarda passa a tolerante")
	_check(not _natives.has_sworn_oath(), "45 ainda não é juramento")
	_check(_natives.current_request().request_id == &"vigil_sustenance",
			"o segundo pedido se abre")
	_measurements["legitimacy_after_first_request"] = _natives.legitimacy().value


func _test_oath_brings_the_guardian() -> void:
	var population := _core_state.population
	_oath_events = 0
	_check(_natives.request_gate() == NativePeopleController.RequestGate.READY,
			"com 5 de Biomassa o segundo pedido está pronto")
	await _press(KEY_J)
	_check(_stockpile.get_amount(BIOMASS) == 0, "o pedido levou exatamente 5 de Biomassa")
	_check(_natives.legitimacy().value == STARTING_LEGITIMACY + 2 * REQUEST_GAIN,
			"a Legitimidade chegou a 65")
	_check(_natives.has_sworn_oath() and _oath_events == 1, "aos 61 a Guarda prestou juramento")
	var guardian := _natives.guardian()
	_check(guardian != null, "o Guardião Decapitado entrou em vigília")
	if guardian == null:
		return
	_check(guardian.get_unit_id() == "guardian_001", "identidade guardian_001")
	_check(guardian.definition.unit_type_id == &"decapitated_guardian", "o corpo é o do Guardião")
	_check(_planar_gap(guardian.global_position, GUARDIAN_POINT) < 0.5,
			"ele aparece diante do salão")
	_check(guardian.is_in_group(&"rts_selectable"), "o jogador pode selecioná-lo")
	_check(_core_state.population == population,
			"o Guardião é súdito da Guarda e não ocupa população: %d" % _core_state.population)
	_check(_natives.request_gate() == NativePeopleController.RequestGate.ALL_FULFILLED,
			"não há terceiro pedido")
	_check(_text_of(_hud, "RequestLabel") == HUD_ALL_DONE, "o painel encerra os pedidos")
	_check(_text_of(_hud, "OathLabel") == HUD_VIGIL, "o painel mostra o Guardião em vigília")
	_give(_biomass, VIGIL_COST)
	await _press(KEY_J)
	_check(_stockpile.get_amount(BIOMASS) == VIGIL_COST, "J depois do fim não cobra nada")
	var start := guardian.global_position
	guardian.move_to(start + Vector3(-2.0, 0.0, 0.0))
	await _advance(1.0)
	_check(_planar_gap(guardian.global_position, start) > 1.0, "o Guardião anda por ordem")


func _test_merit_from_the_incursion() -> void:
	await _discover_people()
	await _launch_guild()
	var raiders := _alive_raiders()
	_check(raiders.size() == 2, "setup: a guilda entrou")
	var before := _natives.legitimacy().value
	raiders[0].receive_damage(9999.0)
	await _advance(0.05)
	_check(_natives.legitimacy().value == before + SLAIN_GAIN,
			"um saqueador morto no domínio vale +5: %d → %d"
					% [before, _natives.legitimacy().value])
	before = _natives.legitimacy().value
	_set_speed(SPEED)
	var fled := await _wait_until(func() -> bool: return _alive_raiders().is_empty(), 40.0)
	_set_speed(1.0)
	_check(fled, "o outro saqueador fugiu")
	_check(_natives.legitimacy().value == before - FLED_LOSS,
			"um saqueador que foge custa 10: %d → %d" % [before, _natives.legitimacy().value])
	# A Guarda só mede o que acontece depois de encontrada.
	await _reset_campaign()
	await _launch_guild()
	_alive_raiders()[0].receive_damage(9999.0)
	await _advance(0.05)
	_check(_natives.legitimacy().value == 0, "antes de rompido o selo, a Guarda não observa nada")


func _test_guardian_fights_and_falls() -> void:
	await _discover_people()
	_natives.legitimacy().add(OATH)
	await _advance(0.05)
	var guardian := _natives.guardian()
	_check(guardian != null, "setup: Guardião em vigília")
	await _launch_guild()
	var target := _alive_raiders()[0]
	guardian.global_position = target.global_position + Vector3(1.0, 0.0, 0.0)
	_check(guardian.attack_target(target), "o Guardião aceita o saqueador como alvo")
	_check(target.action_mode() == EnemyRuntime.ActionMode.COMBAT, "o saqueador revida")
	var before := _natives.legitimacy().value
	var target_instance := target.get_instance_id()
	_set_speed(SPEED)
	var resolved := await _wait_until(
			func() -> bool: return _raider_gone_or_fleeing(target_instance), 20.0)
	_set_speed(1.0)
	_check(resolved, "o duelo do Guardião se resolve")
	var slain := instance_from_id(target_instance) == null
	if slain:
		_check(_natives.legitimacy().value >= before + SLAIN_GAIN,
				"o saqueador que o Guardião abate também vale mérito")
	_measurements["guardian_slew_raider"] = slain
	_check(_natives.guardian() != null, "o Guardião sobreviveu ao duelo")
	# A queda é medida sem a guilda em campo: um saqueador ferido foge pela entrada ao lado e
	# somaria o próprio −10 na mesma janela.
	await _discover_people()
	_natives.legitimacy().add(OATH)
	await _advance(0.05)
	var fallen_before := _natives.legitimacy().value
	var guardian_alive := _natives.guardian()
	_check(guardian_alive != null, "setup: Guardião em vigília, sem guilda")
	if guardian_alive == null:
		return
	guardian_alive.receive_damage(9999.0)
	await _advance(0.05)
	_check(_natives.guardian() == null, "o Guardião caiu")
	_check(_natives.legitimacy().value == fallen_before - FALLEN_LOSS,
			"perder o Guardião custa 10 de Legitimidade: %d → %d"
					% [fallen_before, _natives.legitimacy().value])
	_check(_natives.has_sworn_oath(), "o juramento continua prestado")
	_check(_text_of(_hud, "OathLabel") == HUD_FALLEN, "o painel registra a queda")


func _test_oath_is_historical() -> void:
	_oath_events = 0
	_natives.legitimacy().remove(100)
	_natives.legitimacy().add(OATH + 10)
	await _advance(0.05)
	_check(_oath_events == 0 and _natives.guardian() == null,
			"cruzar o limiar de novo não presta outro juramento nem traz outro Guardião")
	_check(_guardian_count() == 0, "nenhum Guardião no mundo")


# ================================================== Bloco 4 — persistência V6


func _test_save_half_broken_seal() -> void:
	await _reset_campaign()
	_core.evolve_to(_core_lv2)
	await _advance(0.05)
	_natives.seal().state.apply_work(4.0)
	_use_path(HALF_SEAL_PATH)
	_check(_save.save_campaign(), "save com o selo pela metade")
	var entry := _natives_entry(_document_from_file(HALF_SEAL_PATH))
	_check(int(_document_from_file(HALF_SEAL_PATH)[CampaignSnapshot.ROOT_VERSION])
			== CampaignSnapshot.SAVE_VERSION,
			"o arquivo é V6")
	_check(_close(float(entry[CampaignSnapshot.KEY_SEAL_WORK_DONE]), 4.0),
			"o trabalho feito no selo foi gravado: %s" % [entry])
	_natives.seal().state.apply_work(3.0)
	_check(_save.load_campaign(), "load do selo pela metade")
	_check(_close(_natives.seal_work_done(), 4.0), "o selo voltou com 4 de trabalho feito")
	_check(not _natives.is_discovered(), "e a Guarda ainda não foi encontrada")
	_check(_seal_count() == 1, "um único selo no mundo")


func _test_save_discovered_people() -> void:
	await _discover_people()
	_give(_iron, ARMOR_COST)
	_check(_natives.fulfill_request(), "setup: primeiro pedido cumprido")
	_use_path(DISCOVERED_PATH)
	var before := _snapshot_text()
	_check(_save.save_campaign(), "save da Guarda encontrada")
	_check(not _read_text(DISCOVERED_PATH).contains("legitimacy_gain")
			and not _read_text(DISCOVERED_PATH).contains("oath_threshold"),
			"pedidos e limiar são configuração e não vão ao arquivo")
	_natives.legitimacy().add(30)
	_give(_biomass, VIGIL_COST)
	_discovered_events = 0
	_check(_save.load_campaign(), "load da Guarda encontrada")
	_check(_without_motion(_snapshot_text()) == _without_motion(before), "a campanha voltou exata")
	_check(_natives.is_discovered() and _natives.legitimacy().value == 45
			and _natives.requests_fulfilled() == 1,
			"Guarda encontrada, 45 de Legitimidade, um pedido cumprido")
	_check(_discovered_events == 0, "a carga não reanuncia a descoberta")
	_check(_natives.seal().is_completed(), "o salão volta aberto")


func _test_save_guardian_and_repeated_loads() -> void:
	await _discover_people()
	_natives.legitimacy().add(OATH)
	await _advance(0.05)
	var guardian := _natives.guardian()
	guardian.state.damage(40.0)
	guardian.global_position = Vector3(8.0, 0.0, 3.0)
	_use_path(GUARDIAN_PATH)
	_check(_save.save_campaign(), "save com o Guardião ferido")
	guardian.state.damage(30.0)
	_oath_events = 0
	for attempt in 3:
		_check(_save.load_campaign(), "load repetido %d" % (attempt + 1))
		await _advance(0.05)
	_check(_guardian_count() == 1, "três loads, um único Guardião, obtido %d" % _guardian_count())
	var loaded := _natives.guardian()
	_check(loaded != null and _close(loaded.state.health, GUARDIAN_HEALTH - 40.0),
			"a vida do Guardião voltou: %f" % (loaded.state.health if loaded != null else -1.0))
	_check(loaded != null and _planar_gap(loaded.global_position, Vector3(8, 0, 3)) < 0.01,
			"a posição voltou")
	_check(_oath_events == 0, "a carga não reanuncia o juramento")
	_check(_seal_count() == 1, "um único selo")


func _test_level_one_file_removes_the_seal() -> void:
	await _reset_campaign()
	_use_path(LEVEL_ONE_PATH)
	_check(_save.save_campaign(), "setup: campanha Nv.1 salva")
	_core.evolve_to(_core_lv2)
	await _advance(0.05)
	_check(_natives.seal() != null, "setup: o selo despertou")
	_check(_save.load_campaign(), "load do arquivo Nv.1")
	await _advance(0.05)
	_check(_natives.seal() == null and _seal_count() == 0, "a campanha Nv.1 não tem selo")


func _test_v5_migration() -> void:
	await _reset_campaign()
	var campaign := _save.snapshot_campaign()
	campaign.erase(CampaignSnapshot.SECTION_NATIVES)
	_check(CampaignSnapshot.validate_v5(campaign).is_empty(),
			"sem natives a campanha é um V5 válido: %s" % CampaignSnapshot.validate_v5(campaign))
	_check(not CampaignSnapshot.validate_v6(campaign).is_empty(), "como V6 é recusada")
	_check(_write_text(V5_LV1_PATH, CampaignSnapshot.to_text(_document(5, campaign))),
			"o V5 Nv.1 foi escrito")
	_use_path(V5_LV1_PATH)
	_check(_save.load_campaign(), "o V5 Nv.1 carrega pela migração")
	_check(_natives.seal() == null, "Nv.1 migra sem selo")
	await _reset_campaign()
	await _reach_level_two_for_real()
	var level_two := _save.snapshot_campaign()
	level_two.erase(CampaignSnapshot.SECTION_NATIVES)
	_check(_write_text(V5_LV2_PATH, CampaignSnapshot.to_text(_document(5, level_two))),
			"o V5 Nv.2 foi escrito")
	await _reset_campaign()
	_use_path(V5_LV2_PATH)
	_check(_save.load_campaign(), "o V5 Nv.2 carrega pela migração")
	_check(_natives.seal() != null and not _natives.seal().is_completed(),
			"uma campanha Nv.2 antiga ganha o selo, intacto")
	_check(not _natives.is_discovered() and _natives.legitimacy().value == 0,
			"e a Guarda ainda não foi encontrada")
	_check(int(_document_from_file(V5_LV2_PATH)[CampaignSnapshot.ROOT_VERSION]) == 5,
			"o arquivo V5 continua V5 no disco")


func _test_v1_chain_reaches_v6() -> void:
	await _reset_campaign()
	var campaign := _save.snapshot_campaign()
	campaign.erase(CampaignSnapshot.SECTION_NATIVES)
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
			"o V1 migrado é um V6 válido: %s" % CampaignSnapshot.validate_document(migrated))
	_check(_write_text(V1_PATH, CampaignSnapshot.to_text(_document(1, campaign))), "V1 escrito")
	_use_path(V1_PATH)
	_check(_save.load_campaign(), "o V1 carrega pela corrente inteira")
	_check(_natives.seal() == null and not _natives.is_discovered(),
			"a corrente não inventou selo nem Guarda")


func _test_contradictory_files_are_refused() -> void:
	await _discover_people()
	_natives.legitimacy().add(OATH)
	await _advance(0.05)
	var good := _save.snapshot_campaign()
	_check(_save.validate_campaign(good).is_empty(), "setup: a campanha com Guardião é válida")
	var cases: Array = []

	var missing := good.duplicate(true)
	missing.erase(CampaignSnapshot.SECTION_NATIVES)
	cases.append(["V6 sem natives", missing])

	var overworked := good.duplicate(true)
	_natives_entry_of(overworked)[CampaignSnapshot.KEY_SEAL_WORK_DONE] = SEAL_WORK + 1.0
	cases.append(["selo com trabalho acima do exigido", overworked])

	var early := good.duplicate(true)
	_make_level_one(early)
	_natives_entry_of(early)[CampaignSnapshot.KEY_SEAL_WORK_DONE] = 3.0
	_natives_entry_of(early)[CampaignSnapshot.KEY_LEGITIMACY] = 0
	_natives_entry_of(early)[CampaignSnapshot.KEY_REQUESTS_FULFILLED] = 0
	_natives_entry_of(early)[CampaignSnapshot.KEY_OATH_SWORN] = false
	_natives_entry_of(early)[CampaignSnapshot.KEY_GUARDIAN] = {CampaignSnapshot.KEY_ALIVE: false}
	cases.append(["selo trabalhado no Nv.1", early])

	var premature := good.duplicate(true)
	_natives_entry_of(premature)[CampaignSnapshot.KEY_SEAL_WORK_DONE] = 2.0
	cases.append(["Legitimidade antes de encontrar a Guarda", premature])

	var greedy := good.duplicate(true)
	_natives_entry_of(greedy)[CampaignSnapshot.KEY_REQUESTS_FULFILLED] = 3
	cases.append(["mais pedidos cumpridos do que existem", greedy])

	var oathless := good.duplicate(true)
	_natives_entry_of(oathless)[CampaignSnapshot.KEY_OATH_SWORN] = false
	_natives_entry_of(oathless)[CampaignSnapshot.KEY_GUARDIAN] = {CampaignSnapshot.KEY_ALIVE: false}
	cases.append(["Legitimidade no limiar sem juramento", oathless])

	var stray := good.duplicate(true)
	_natives_entry_of(stray)[CampaignSnapshot.KEY_LEGITIMACY] = 30
	_natives_entry_of(stray)[CampaignSnapshot.KEY_OATH_SWORN] = false
	cases.append(["Guardião sem juramento", stray])

	var titan := good.duplicate(true)
	(_natives_entry_of(titan)[CampaignSnapshot.KEY_GUARDIAN] as Dictionary)[
			CampaignSnapshot.KEY_HEALTH] = GUARDIAN_HEALTH + 1.0
	cases.append(["Guardião acima da vida máxima", titan])

	var loud := good.duplicate(true)
	_natives_entry_of(loud)[CampaignSnapshot.KEY_LEGITIMACY] = 101
	cases.append(["Legitimidade acima de 100", loud])

	for entry in cases:
		_check(not _save.validate_campaign(entry[1]).is_empty(),
				"%s é recusado: %s" % [entry[0], _save.validate_campaign(entry[1])])
	_check(CampaignSnapshot.validate_document(_document(CampaignSnapshot.SAVE_VERSION + 1, good)).contains("save_version não suportado"),
			"save_version = 7 é recusado sem adivinhação")
	var world_before := _snapshot_text()
	for entry in cases:
		_check(_write_text(BAD_PATH, CampaignSnapshot.to_text(_document(6, entry[1]))),
				"arquivo ruim escrito: %s" % entry[0])
		_use_path(BAD_PATH)
		_failed_events.clear()
		_check(not _save.load_campaign(), "%s não carrega" % entry[0])
		_check(not _failed_events.is_empty(), "a recusa anuncia o motivo")
		_check(_snapshot_text() == world_before, "o mundo continua intacto")
	_check(_guardian_count() == 1 and _seal_count() == 1, "Guardião e selo não foram tocados")
	await _reset_campaign()


# ==================================================================== helpers


func _discover_people() -> void:
	await _reset_campaign()
	_core.evolve_to(_core_lv2)
	await _advance(0.05)
	_natives.seal().state.apply_work(SEAL_WORK)
	await _advance(0.05)
	_check(_natives.is_discovered(), "setup: a Guarda foi encontrada")


## O Nv.2 já abriu a preparação de 120 s; a suíte larga a guilda direto, pela mesma porta
## que o fim da contagem usa.
func _launch_guild() -> void:
	if _core_state.level < 2:
		_core.evolve_to(_core_lv2)
	_check(_incursion.start_incursion(), "setup: a incursão foi largada")
	await _advance(0.1)
	_check(_alive_raiders().size() == 2, "setup: a guilda entrou")


func _reach_level_two_for_real() -> void:
	_give_essence(ESSENCE_GRANT)
	_check(_invasion.start_invasion(), "setup: a invasão foi largada")
	await _advance(0.05)
	for child in _dungeon.get_children():
		var enemy := child as EnemyRuntime
		if enemy != null and not (enemy is RaiderRuntime) and enemy.is_alive():
			enemy.receive_damage(9999.0)
	await _advance(0.05)
	_check(_crystal.amount == 1, "setup: a chave chegou")
	_check(_evolution.try_evolve(), "setup: o Núcleo evoluiu para o Nv.2")
	await _advance(0.05)


func _reset_campaign() -> void:
	_set_speed(1.0)
	_incursion.preparation_duration = 120.0
	_use_path(FRESH_PATH)
	_check(_save.load_campaign(), "setup: a carga de isolamento devolve a campanha do boot")
	await _advance(0.1)


func _make_level_one(campaign: Dictionary) -> void:
	var core: Dictionary = campaign[CampaignSnapshot.SECTION_CORE]
	core[CampaignSnapshot.KEY_LEVEL] = 1
	core[CampaignSnapshot.KEY_ESSENCE] = 0.0
	core[CampaignSnapshot.KEY_INTEGRITY] = 1.0
	var surface: Dictionary = campaign[CampaignSnapshot.SECTION_SURFACE]
	surface[CampaignSnapshot.KEY_NOTORIETY] = 0
	surface[CampaignSnapshot.KEY_INCURSION] = {
		CampaignSnapshot.KEY_STATE: "NOT_STARTED",
		CampaignSnapshot.KEY_PREPARATION_REMAINING: 0.0,
		CampaignSnapshot.KEY_RAIDERS: [],
		CampaignSnapshot.KEY_REPELLED: 0,
		CampaignSnapshot.KEY_ESCAPED: 0,
		CampaignSnapshot.KEY_INCURSION_NUMBER: 0,
		CampaignSnapshot.KEY_GUILD_SIZE: 0,
		CampaignSnapshot.KEY_COOLDOWN_REMAINING: 0.0,
	}


func _natives_entry(document: Dictionary) -> Dictionary:
	return _natives_entry_of(document[CampaignSnapshot.ROOT_CAMPAIGN])


func _natives_entry_of(campaign: Dictionary) -> Dictionary:
	return (campaign[CampaignSnapshot.SECTION_NATIVES] as Dictionary)[
			CampaignSnapshot.NATIVE_PEOPLE_ID]


func _document(version: int, campaign: Dictionary) -> Dictionary:
	return {
		CampaignSnapshot.ROOT_FORMAT: CampaignSnapshot.SAVE_FORMAT,
		CampaignSnapshot.ROOT_VERSION: version,
		CampaignSnapshot.ROOT_METADATA: {"saved_at_unix": 1760540000, "probe": "povo nativo"},
		CampaignSnapshot.ROOT_CAMPAIGN: campaign,
	}


func _alive_raiders() -> Array[RaiderRuntime]:
	var found: Array[RaiderRuntime] = []
	for child in _dungeon.get_children():
		var raider := child as RaiderRuntime
		if raider != null and not raider.is_queued_for_deletion() and raider.is_alive() \
				and not raider.has_escaped():
			found.append(raider)
	return found


func _raider_gone_or_fleeing(instance: int) -> bool:
	var raider := instance_from_id(instance) as RaiderRuntime
	if raider == null or not raider.is_alive() or raider.has_escaped():
		return true
	return raider.raider_state().phase == RaiderState.Phase.RETREAT


func _seal_count() -> int:
	var total := 0
	for child in _dungeon.get_children():
		if child is AncientSealRuntime and not child.is_queued_for_deletion():
			total += 1
	return total


func _guardian_count() -> int:
	var total := 0
	for child in _dungeon.get_children():
		var unit := child as SoldierRuntime
		if unit != null and not unit.is_queued_for_deletion() and unit.state != null \
				and unit.state.unit_id == "guardian_001":
			total += 1
	return total


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


func _without_motion(text: String) -> String:
	var regex := RegEx.new()
	regex.compile("(essence|preparation_time_remaining)=([0-9.e+-]+)")
	return regex.sub(text, "$1=*", true)


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


func _on_seal_awakened(_seal: AncientSealRuntime) -> void:
	_awakened_events += 1


func _on_people_discovered() -> void:
	_discovered_events += 1


func _on_oath_sworn(_guardian: SoldierRuntime) -> void:
	_oath_events += 1


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
	_natives = _scene.get_node("Systems/NativePeopleController") as NativePeopleController
	_incursion = _scene.get_node(
			"Systems/SurfaceIncursionController") as SurfaceIncursionController
	_invasion = _scene.get_node("Systems/InvasionController") as InvasionController
	_evolution = _scene.get_node("Systems/CoreEvolutionController") as CoreEvolutionController
	_save = _scene.get_node("Systems/SaveGameController") as SaveGameController
	_core = _scene.get_node("World/DungeonRoot/MainCore") as CoreRuntime
	_worker = _scene.get_node("World/DungeonRoot/Worker001") as WorkerRuntime
	var deposit := _scene.get_node("World/DungeonRoot/Deposit001") as ResourceDepositRuntime
	_stockpile = deposit.stockpile
	_core_state = _core.core_state()
	_crystal = _evolution.abyssal_crystal_state()
	_hud = _scene.get_node("UI/NativesDebugPanel")
	_iron = load(IRON_ORE_PATH) as ResourceDefinition
	_biomass = load(BIOMASS_PATH) as ResourceDefinition
	_core_lv2 = load(CORE_LV2_PATH) as CoreDefinition
	_player_before = _presence(PLAYER_PRIMARY)
	_player_backup_before = _presence(PLAYER_BACKUP)
	_natives.seal_awakened.connect(_on_seal_awakened)
	_natives.people_discovered.connect(_on_people_discovered)
	_natives.oath_sworn.connect(_on_oath_sworn)
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
	_worker = null
	_natives = null
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
	print("---- native people tests finished: %d asserts, %d failure(s) ----"
			% [_asserts, _failures])
	quit(1 if _failures > 0 else 0)
