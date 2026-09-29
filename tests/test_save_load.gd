extends SceneTree

# Tarefa 18 — Save/Load profissional da campanha.
#
# O contrato desta suíte é um só (§PRINCÍPIO): o arquivo não fotografa a SceneTree, fotografa
# a campanha. Por isso cada cenário aqui mede o domínio antes do save, mexe no mundo de
# verdade depois, e exige que o load devolva exatamente os números gravados — não Nodes
# recriados, não sinais de conquista repetidos, não bônus readicionados.
#
# Quatro blocos, nesta ordem:
#   1) contrato do arquivo e guardas de fonte — CampaignSnapshot sozinho, sem cena, com o
#      documento mínimo do §68/§69 e as recusas estruturais (§104/§105), mais o que a tarefa
#      deliberadamente NÃO construiu (§117/§120/§127/§129/§108);
#   2) I/O real em user://tests/ — escrita atômica, backup, fallback e as recusas que não
#      podem tocar em nada, agora contra arquivos de verdade e com contagem de sinais
#      (§107/§111/§112/§102/§113/§103/§114);
#   3) a matriz de cenários da campanha (§82–§101) — Núcleo, Cristal, estoque, Workers,
#      carga, Rochas, montes, obras, Soldado, contagem de preparação, invasão ativa, vitória,
#      Nv.2, derrota, carga repetida e roundtrip;
#   4) entrada, HUD e limpeza — Ctrl+S/Ctrl+L pelo InputMap na GameMain real (§115), a prova
#      de que as duas combinações não sequestram nenhum comando de gameplay (§116), o painel
#      alinhado depois da carga (§77/§80) e o save do jogador intocado (§107/§108).
#
# Todo arquivo escrito aqui mora em `user://tests/save_load/` e é apagado no fim (§107). A
# partida isolada de cada cenário volta ao mesmo pristine por `load_campaign()` do arquivo
# gravado no boot — que é, ela própria, a primeira prova de que a carga restaura.

const MAIN_SCENE := preload("res://game/GameMain.tscn")

const SNAPSHOT_SOURCE := "res://systems/persistence/campaign_snapshot.gd"
const CONTROLLER_SOURCE := "res://systems/persistence/save_game_controller.gd"
const GAME_MAIN_SOURCE := "res://game/game_main.gd"
const PROJECT_SOURCE := "res://project.godot"

const PERSISTENCE_DIR := "res://systems/persistence"
const UI_HUD_DIR := "res://ui/hud"

## §107: caminho de teste, sempre sob user://tests/. Nenhum deles é o save do jogador.
const TEST_DIR := "user://tests/save_load"
const FRESH_PATH := "user://tests/save_load/pristine.json"
const PRIMARY_PATH := "user://tests/save_load/campaign.json"
const BACKUP_PATH := "user://tests/save_load/campaign.bak"
const ABSENT_PATH := "user://tests/save_load/nao_existe.json"
const INPUT_PATH := "user://tests/save_load/teclas.json"
const WORKER_PATH := "user://tests/save_load/trabalhadores.json"
const ROCK_PATH := "user://tests/save_load/rochas.json"
const PILE_PATH := "user://tests/save_load/montes.json"
const NEST_PATH := "user://tests/save_load/ninho.json"
const BARRACKS_PATH := "user://tests/save_load/quartel.json"
const SOLDIER_PATH := "user://tests/save_load/soldado.json"
const PREP_PATH := "user://tests/save_load/preparacao.json"
const ACTIVE_PATH := "user://tests/save_load/invasao.json"
const VICTORY_PATH := "user://tests/save_load/vitoria.json"
const LEVEL2_PATH := "user://tests/save_load/nivel2.json"
const DEFEAT_PATH := "user://tests/save_load/derrota.json"
const RICH_PATH := "user://tests/save_load/rica.json"
const ROUNDTRIP_PATH := "user://tests/save_load/roundtrip.json"
const TEST_PATHS: Array[String] = [FRESH_PATH, PRIMARY_PATH, BACKUP_PATH, ABSENT_PATH,
		INPUT_PATH, WORKER_PATH, ROCK_PATH, PILE_PATH, NEST_PATH, BARRACKS_PATH,
		SOLDIER_PATH, PREP_PATH, ACTIVE_PATH, VICTORY_PATH, LEVEL2_PATH, DEFEAT_PATH,
		RICH_PATH, ROUNDTRIP_PATH]

## §6/§108: o caminho de produção. A suíte nunca escreve aqui — só registra como estava.
const PLAYER_PRIMARY := "user://campaign_save.json"
const PLAYER_BACKUP := "user://campaign_save.bak"

const ORE := &"iron_ore"
const ORE_PATH := "res://data/resources/iron_ore.tres"
const FIRST_ORE_ROCK_ID := "iron_ore_001"
const SECOND_ORE_ROCK_ID := "iron_ore_002"
const COMMON_ROCK_ID := "rock_001"

## Valores das Definitions que os cenários usam para alterar o mundo de forma mensurável.
const WORKER_HP := 50.0
const SOLDIER_HP := 80.0
const BEAST_HP := 48.0
const NEST_WORK := 4.0
const NEST_BONUS := 4
const BARRACKS_WORK := 6.0
const ORE_ROCK_WORK := 5.0
const COMMON_ROCK_WORK := 4.0
const ROCK_YIELD := 3
const CARRY_CAPACITY := 3
const INVADER_COUNT := 2
const FIRST_INVADER := "invader_001"
const SECOND_INVADER := "invader_002"
const INTEGRITY_LV1 := 100.0
const INTEGRITY_LV2 := 150.0
const GENERATION_LV2 := 1.5
const ESSENCE_GRANT := 20.0
const SUMMON_COST := 10.0
const RECRUIT_COST := 15.0
const BUILD_COST := 3
const SHORT_PREP := 0.9
const PRODUCTION_PREP := 60.0
const TICKS := 60

## §116: os comandos que moram em `_unhandled_input`. Nenhum deles pode casar com Ctrl+S ou
## Ctrl+L no nível do evento — é exatamente assim que o controller decide a jogada.
const COMMAND_ACTIONS: Array[String] = ["build_nest", "build_barracks", "summon_worker",
		"recruit_soldier", "start_invasion", "evolve_core"]

## §116/§55: a câmera é a única consumidora que pergunta o estado por frame, e o S dela é a
## mesma letra do atalho de save. O matching do InputMap é de subconjunto, então a prova de
## §116 aqui é a consequência no mundo: com o chord de persistência no ar, a view não anda.
const CAMERA_ACTIONS: Array[String] = ["camera_forward", "camera_backward", "camera_left",
		"camera_right"]

## Textos do painel (§77/§80/T18), copiados da produção de propósito: se a carga alinhar o
## número e o rótulo continuar preso à cena, esta linha denuncia.
const TITLE_LV1 := "Abyssal Core Lv. 1"
const TITLE_LV2 := "Abyssal Core Lv. 2"
const CRYSTAL_ONE_LINE := "Cristal Abissal: 1 / 1"

## Os painéis que existem desde antes desta tarefa (§117): nenhum outro arquivo entra aqui.
const HUD_SCENES: Array[String] = ["CombatDebugHud.tscn", "ConstructionDebugHud.tscn",
		"CoreDebugHud.tscn", "CoreEvolutionDebugHud.tscn", "InvasionDebugHud.tscn",
		"InvasionWarningHud.tscn", "MilitaryDebugHud.tscn", "ResourceDebugHud.tscn",
		"WorkerInvocationDebugHud.tscn"]

var _failures := 0
var _asserts := 0
var _frames := 0
var _measurements := {}

var _scene: Node
var _camera_rig: Node3D
var _camera: Camera3D
var _dungeon: Node3D
var _save: SaveGameController
var _selection: SelectionController
var _construction: ConstructionController
var _invocation: WorkerInvocationController
var _recruitment: SoldierRecruitmentController
var _invasion: InvasionController
var _evolution: CoreEvolutionController
var _core: CoreRuntime
var _core_state: CoreState
var _crystal: AbyssalCrystalState
var _stockpile: ResourceStockpileState
var _iron: ResourceDefinition
var _worker: WorkerRuntime

## Contadores de sinal (§114): a única prova de "uma emissão" é o número de emissões.
var _save_events: Array[String] = []
var _load_events: Array[String] = []
var _failed_events: Array[String] = []
var _victory_events := 0
var _defeat_events := 0
var _barracks_completed_events := 0
var _crystal_events := 0

## §107: o estado do save real do jogador, medido antes de qualquer escrita desta suíte.
var _player_before := ""
var _player_backup_before := ""


func _initialize() -> void:
	_run_all()


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > 1200000:
		_check(false, "timeout: a suíte de save/load não terminou")
		_finish()
	return false


func _run_all() -> void:
	# Bloco 1 — contrato do arquivo e guardas de fonte.
	_test_schema_contract()
	_test_structural_refusals()
	_test_position_contract()
	_test_source_guards()

	# O resto precisa da árvore: posição global, física e InputMap de verdade.
	await _boot_scene()
	await _test_isolated_file_io()
	await _test_atomic_write_and_backup()
	await _test_refusals_touch_nothing()
	await _test_fresh_campaign_roundtrip()
	await _test_second_worker_and_cargo()
	await _test_rocks_and_piles()
	await _test_nest_progress_and_bonus()
	await _test_barracks_and_soldier()
	await _test_preparation_countdown()
	await _test_active_invasion()
	await _test_victory_and_evolution()
	await _test_defeat_stays_defeat()
	await _test_repeated_load_is_idempotent()
	await _test_roundtrip_is_stable()
	await _test_snapshot_holds_only_domain()
	await _test_manual_input_actions()
	await _test_inputs_do_not_conflict()
	await _test_hud_realigns_after_load()

	await _free_scene()
	_cleanup_test_files()
	_test_player_save_untouched()

	_print_measurements()
	_finish()


# ================================================ Bloco 1 — contrato do schema e de fonte


## §110/§6/§7: o envelope é format + save_version + metadata + campaign, é JSON puro e é
## legível por humano. Nada aqui depende da cena — o contrato existe antes do jogo.
func _test_schema_contract() -> void:
	var document := CampaignSnapshot.build_document(_minimal_campaign(), {"probe": "suíte"})
	_check(document[CampaignSnapshot.ROOT_FORMAT] == CampaignSnapshot.SAVE_FORMAT,
			"§6 format == abyss_lord_campaign, obtido %s" % document[CampaignSnapshot.ROOT_FORMAT])
	_check(int(document[CampaignSnapshot.ROOT_VERSION]) == 1,
			"§7 save_version == 1, obtido %s" % document[CampaignSnapshot.ROOT_VERSION])
	_check(document.has(CampaignSnapshot.ROOT_METADATA)
			and document.has(CampaignSnapshot.ROOT_CAMPAIGN),
			"§6 envelope tem metadata e campaign")
	_check(document.keys().size() == 4,
			"§6 a raiz tem exatamente quatro chaves, obtido %d" % document.keys().size())
	_check(CampaignSnapshot.validate_document(document).is_empty(),
			"§68/§69 o documento mínimo das sete seções é aceito: %s"
					% CampaignSnapshot.validate_document(document))
	for section in [CampaignSnapshot.SECTION_CORE, CampaignSnapshot.SECTION_PROGRESSION,
			CampaignSnapshot.SECTION_ECONOMY, CampaignSnapshot.SECTION_UNITS,
			CampaignSnapshot.SECTION_CONSTRUCTIONS, CampaignSnapshot.SECTION_WORLD,
			CampaignSnapshot.SECTION_INVASION]:
		_check((document[CampaignSnapshot.ROOT_CAMPAIGN] as Dictionary).has(section),
				"§69 a seção obrigatória %s existe no documento" % section)
	# §110: serializável como JSON e relido como o mesmo documento válido.
	var text := CampaignSnapshot.to_text(document)
	_check(not text.is_empty() and text.contains("\n  \""),
			"§110 o arquivo é indentado e legível por humano")
	var reread: Variant = CampaignSnapshot.parse_document(text)
	_check(reread is Dictionary, "§110 o texto volta como Dictionary")
	_check(CampaignSnapshot.validate_document(reread).is_empty(),
			"§110 o roundtrip JSON continua válido: %s" % CampaignSnapshot.validate_document(reread))
	_check(CampaignSnapshot.parse_document("{not valid json") == null,
			"§102 JSON ilegível devolve null em vez de estourar")
	# §13: nada de objeto, script ou caminho de cena no texto.
	for forbidden in ["Object", "res://", "PackedScene", "instance_id"]:
		_check(not text.contains(forbidden),
				"§13/§122 o texto do arquivo não menciona %s" % forbidden)


## §67/§69/§104/§105: toda recusa estrutural devolve motivo, nunca meia aplicação.
## O §104 é uma recusa do contrato (versão), o §105 é uma seção que sumiu.
func _test_structural_refusals() -> void:
	var campaign := _minimal_campaign()
	_accept(CampaignSnapshot.build_document(campaign, {}),
			"§68 o documento mínimo é a linha de partida das recusas")

	# §104: estrutura boa, versão que não existe.
	var version_two := CampaignSnapshot.build_document(campaign, {}) as Dictionary
	version_two[CampaignSnapshot.ROOT_VERSION] = 2
	_refuse(version_two, "save_version", "§104 save_version = 2 é recusado sem adivinhação")
	var version_string := CampaignSnapshot.build_document(campaign, {}) as Dictionary
	version_string[CampaignSnapshot.ROOT_VERSION] = "1"
	_refuse(version_string, "save_version", "§8 save_version em texto é recusado")
	var version_float := CampaignSnapshot.build_document(campaign, {}) as Dictionary
	version_float[CampaignSnapshot.ROOT_VERSION] = 1.0
	_accept(version_float, "§13/T18 1.0 lido do JSON é a versão 1")

	# §105: uma seção obrigatória ausente.
	for section in [CampaignSnapshot.SECTION_CORE, CampaignSnapshot.SECTION_PROGRESSION,
			CampaignSnapshot.SECTION_ECONOMY, CampaignSnapshot.SECTION_UNITS,
			CampaignSnapshot.SECTION_CONSTRUCTIONS, CampaignSnapshot.SECTION_WORLD,
			CampaignSnapshot.SECTION_INVASION]:
		var missing := campaign.duplicate(true) as Dictionary
		missing.erase(section)
		_refuse(CampaignSnapshot.build_document(missing, {}), section,
				"§69/§105 a seção %s ausente é recusada" % section)

	var wrong_format := CampaignSnapshot.build_document(campaign, {}) as Dictionary
	wrong_format[CampaignSnapshot.ROOT_FORMAT] = "other_game"
	_refuse(wrong_format, "format", "§6 format desconhecido é recusado")

	# Núcleo.
	var negative_integrity := _campaign_copy()
	(negative_integrity[CampaignSnapshot.SECTION_CORE] as Dictionary)[
			CampaignSnapshot.KEY_INTEGRITY] = -1.0
	_refuse_document(negative_integrity, "negativo", "§69 Integrity negativa é recusada")
	var fractional_level := _campaign_copy()
	(fractional_level[CampaignSnapshot.SECTION_CORE] as Dictionary)[
			CampaignSnapshot.KEY_LEVEL] = 1.5
	_refuse_document(fractional_level, "core tem campo", "§13/T18 nível fracionário é recusado")
	var foreign_core := _campaign_copy()
	(foreign_core[CampaignSnapshot.SECTION_CORE] as Dictionary)["core_id"] = "other_core"
	_refuse_document(foreign_core, "core_id", "§14 core_id que não é o da campanha é recusado")

	# Progressão e economia.
	var negative_crystal := _campaign_copy()
	((negative_crystal[CampaignSnapshot.SECTION_PROGRESSION] as Dictionary)[
			CampaignSnapshot.KEY_CRYSTAL] as Dictionary)[CampaignSnapshot.KEY_AMOUNT] = -1
	_refuse_document(negative_crystal, "abyssal_crystal", "§69 Cristal negativo é recusado")
	var missing_crystal := _campaign_copy()
	(missing_crystal[CampaignSnapshot.SECTION_PROGRESSION] as Dictionary).erase(
			CampaignSnapshot.KEY_CRYSTAL)
	_refuse_document(missing_crystal, "abyssal_crystal",
			"§69 progression sem abyssal_crystal é recusada")
	var fractional_stock := _campaign_copy()
	(fractional_stock[CampaignSnapshot.SECTION_ECONOMY] as Dictionary)[
			CampaignSnapshot.KEY_STOCKPILE]["iron_ore"] = 0.5
	_refuse_document(fractional_stock, "stockpile",
			"§13/T18 saldo fracionário é recusado")
	var missing_stockpile := _campaign_copy()
	(missing_stockpile[CampaignSnapshot.SECTION_ECONOMY] as Dictionary).erase(
			CampaignSnapshot.KEY_STOCKPILE)
	_refuse_document(missing_stockpile, "stockpile",
			"§69 economy sem stockpile é recusada")
	var negative_population := _campaign_copy()
	(negative_population[CampaignSnapshot.SECTION_CORE] as Dictionary)[
			CampaignSnapshot.KEY_POPULATION] = -1
	_refuse_document(negative_population, "core", "§69 Population negativa é recusada")
	var no_scene_worker := _campaign_copy()
	(no_scene_worker[CampaignSnapshot.SECTION_UNITS] as Dictionary)[
			CampaignSnapshot.KEY_WORKERS] = []
	_refuse_document(no_scene_worker, CampaignSnapshot.FIRST_WORKER_ID,
			"§23/T18 arquivo sem worker_001 é corrompido, não partida nova")


func _test_position_contract() -> void:
	var encoded := CampaignSnapshot.encode_position(Vector3(-4.5, 1.25, 12.0))
	_check(encoded.size() == 3, "§13 posição é três números, obtido %d" % encoded.size())
	var decoded := CampaignSnapshot.decode_position(encoded)
	_check(decoded == Vector3(-4.5, 1.25, 12.0),
			"§24 a posição volta exatamente como foi medida, obtido %s" % decoded)
	var campaign := _minimal_campaign()
	(campaign[CampaignSnapshot.SECTION_UNITS] as Dictionary)[
			CampaignSnapshot.KEY_WORKERS][0][CampaignSnapshot.KEY_POSITION] = [1.0, 2.0]
	_refuse(CampaignSnapshot.build_document(campaign, {}), CampaignSnapshot.FIRST_WORKER_ID,
			"§13 posição que não é tripla é recusada")


## §117/§120/§127/§129/§108/§122: o que a tarefa deliberadamente não construiu, e onde a
## lógica de serialização mora.
func _test_source_guards() -> void:
	var sources := _collect_gd_files("res://")
	_check(not sources.is_empty(), "§120 a varredura achou os fontes de produção")
	for forbidden in ["SaveManager", "AutoSave", "Autosave", "QuickSave", "SaveSlot",
			"MultiSlot", "CloudSave", "SteamCloud", "Encryption", "Checksum", "Thumbnail",
			"OfflineProgress", "NewGamePlus", "RollbackHistory", "LoadScreen", "SaveMenu",
			"SaveDebugHud", "SaveLoadHud", "DependencyContainer", "MigrationV2",
			"EventBus", "SaveSystem", "LoadSystem"]:
		_check(_files_containing(sources, forbidden).is_empty(),
				"§120/§59/§128 nenhum fonte contém %s, achado em %s"
						% [forbidden, _files_containing(sources, forbidden)])
		_check(_files_named(sources, forbidden).is_empty(),
				"§120 nenhum fonte de produção tem %s no nome" % forbidden)

	# §117: nenhum painel novo. A lista é a da tarefa anterior, inteira.
	_check(_files_in(UI_HUD_DIR, ".tscn") == HUD_SCENES,
			"§117 ui/hud continua com os nove painéis de sempre, obtido %s"
					% [_files_in(UI_HUD_DIR, ".tscn")])
	_check(not ResourceLoader.exists("res://ui/hud/SaveDebugHud.tscn"),
			"§59 não existe painel de save")

	# §98/T18: systems/ tem sete controllers e o contrato do arquivo.
	_check(_collect_gd_files(PERSISTENCE_DIR).size() == 2,
			"§11 a persistência são dois arquivos: controller e contrato, obtido %d"
					% _collect_gd_files(PERSISTENCE_DIR).size())
	_check(_collect_gd_files("res://systems").size() == 8,
			"§13/T18 systems/ tem sete controllers e o contrato de schema, obtido %d"
					% _collect_gd_files("res://systems").size())

	# §129: persistência é instantânea no frame do input, nunca por frame.
	var controller_code := _code_of(CONTROLLER_SOURCE)
	for forbidden in ["func _process(", "func _physics_process(", "await "]:
		_check(not controller_code.contains(forbidden),
				"§129/§130 o SaveGameController não contém %s" % forbidden)
	var snapshot_code := _code_of(SNAPSHOT_SOURCE)
	for forbidden in ["func _process(", "extends Node", "load(", "FileAccess"]:
		_check(not snapshot_code.contains(forbidden),
				"§110/§16 o contrato não contém %s" % forbidden)
	_check(snapshot_code.contains("extends RefCounted"),
			"§110 CampaignSnapshot é RefCounted")

	# §127: a raiz de composição injeta e registra; a serialização não migrou para ela.
	var main_code := _code_of(GAME_MAIN_SOURCE)
	for forbidden in ["JSON", "FileAccess", "DirAccess", "user://", "snapshot_campaign",
			"validate_campaign", "CampaignSnapshot", "save_campaign(", "load_campaign("]:
		_check(not main_code.contains(forbidden),
				"§127 game_main.gd não contém %s" % forbidden)
	for required in ["SAVE_SCRIPT.new()", "_save.setup(", "bind_restore_materials(",
			"register_rock(", "load_succeeded.connect(_on_load_succeeded)"]:
		_check(main_code.contains(required),
				"§127/§10 a GameMain ainda faz %s" % required)
	_check(main_code.count("SAVE_SCRIPT.new()") == 1,
			"§10 existe um único SaveGameController, criado na raiz de composição")

	# §108/§6: o caminho de produção é user://, e res:// nunca recebe save.
	_check(controller_code.contains("user://campaign_save.json"),
			"§6/§108 o caminho padrão é user://campaign_save.json")
	_check(not controller_code.contains("\"res://"),
			"§108 a persistência não conhece nenhum caminho res://")

	# §55/§56: as duas ações vivem no InputMap; nenhuma outra porta de input existe.
	var project := _source(PROJECT_SOURCE)
	_check(project.contains("save_game=") and project.contains("load_game="),
			"§55 o InputMap declara save_game e load_game")
	_check(not project.contains("[autoload]"),
			"§120/§10 o projeto continua sem Autoload nenhum")
	_check(not controller_code.contains("match event"),
			"§56 o controller não compara keycode à mão")


# ================================================== Bloco 2 — I/O real em user://tests/


## §111/§107/§6: salvar escreve arquivo de verdade, no caminho injetado, com temporário,
## backup e as três chaves de caminho dentro de user://tests/.
func _test_isolated_file_io() -> void:
	_use_path(FRESH_PATH)
	_reset_counters()
	var before := _snapshot_text()
	_check(_save.save_campaign(), "§111 o primeiro save grava a campanha pristine")
	_check(FileAccess.file_exists(FRESH_PATH), "§111 o arquivo existe em user://tests/")
	_check(_save_events == [FRESH_PATH],
			"§114 save_succeeded emitido uma vez, com o caminho, obtido %s" % [_save_events])
	_check(_load_events.is_empty() and _failed_events.is_empty(),
			"§114 um save bom não emite load nem falha, obtido %s/%s" % [_load_events, _failed_events])
	_check(_read_text(FRESH_PATH).length() > 200, "§110 o arquivo tem conteúdo legível")
	# §62: o temporário não fica para trás.
	_check(not FileAccess.file_exists(FRESH_PATH.get_basename() + ".tmp"),
			"§62 nenhum arquivo temporário sobrevive ao save")
	_check(_snapshot_text() == before,
			"§130 salvar não alterou a campanha em curso")


## §112/§102/§113: escrita atômica com primário novo e backup velho, e o fallback que salva
## a campanha quando o primário apodrece.
func _test_atomic_write_and_backup() -> void:
	await _reset_campaign()
	_use_path(PRIMARY_PATH)
	_check(_save.save_campaign(), "§112 save A publicado")
	# B é a mesma campanha com Ninho — uma diferença discreta, não um timestamp.
	_give_iron(BUILD_COST + 1)
	_check(_construction.build_nest(), "§112 o Ninho que diferencia A de B foi lançado")
	_reset_counters()
	_check(_save.save_campaign(), "§112 save B publicado")
	_check(FileAccess.file_exists(PRIMARY_PATH) and FileAccess.file_exists(BACKUP_PATH),
			"§112 primário e backup existem depois do segundo save")
	_check(_has_nest_in_file(PRIMARY_PATH), "§112 primário == B (tem Ninho)")
	_check(not _has_nest_in_file(BACKUP_PATH), "§112 backup == A (sem Ninho)")

	# §102/§113: JSON podre no primário, backup bom.
	_write_text(PRIMARY_PATH, "{not valid json")
	_reset_counters()
	_check(_save.load_campaign(), "§113/§102 o load cai no backup e devolve true")
	_check(_load_events == [BACKUP_PATH],
			"§113/§114 load_succeeded anunciou o backup, uma vez, obtido %s" % [_load_events])
	_check(_failed_events.is_empty(),
			"§114 o fallback bem-sucedido não emite operation_failed, obtido %s" % [_failed_events])
	await _advance(0.05)
	_check(_construction.nest() == null or _construction.nest().is_queued_for_deletion(),
			"§113 os dados de A voltaram: o Ninho de B não existe na campanha carregada")
	_check(_save.save_path() == PRIMARY_PATH,
			"§64 o fallback não troca o caminho configurado do primário")

	# §103: os dois podres — recusa, mundo intacto.
	_use_path(PRIMARY_PATH)
	_write_text(BACKUP_PATH, "{tambem nao json")
	await _reset_campaign()
	_use_path(PRIMARY_PATH)
	_give_iron(1)
	var guard := _snapshot_text()
	_reset_counters()
	_check(not _save.load_campaign(), "§103 primário e backup ilegíveis devolvem false")
	_check(_load_events.is_empty(), "§103/§114 sem carga não há load_succeeded")
	_check(_failed_events.size() == 1,
			"§114 a recusa emite exatamente um operation_failed, obtido %d" % _failed_events.size())
	_check(_snapshot_text() == guard, "§103 o mundo em curso permaneceu idêntico")


## §58/§104/§105/§106: recusa é não tocar em nada — no arquivo ausente, na versão do futuro,
## na seção que sumiu e no id que a campanha não conhece.
func _test_refusals_touch_nothing() -> void:
	await _reset_campaign()
	_use_path(PRIMARY_PATH)
	_give_iron(BUILD_COST + 1)
	_check(_construction.build_nest(), "§105/§106 a guarda do mundo é um Ninho em curso")
	await _advance(0.05)
	var guard := _snapshot_text()
	var campaign := _save.snapshot_campaign()

	# §58: arquivo que não existe não é corrupção.
	_use_path(ABSENT_PATH)
	_remove_file(ABSENT_PATH)
	_reset_counters()
	_check(not _save.load_campaign(), "§58 nenhum arquivo devolve false")
	_check(_failed_events.size() == 1 and _failed_events[0].contains("load"),
			"§58/§114 a ausência é anunciada como falha de load, obtido %s" % [_failed_events])
	_check(_snapshot_text() == guard, "§58 o mundo intacto diante de arquivo ausente")

	# §104: versão que ainda não existe.
	var future := CampaignSnapshot.build_document(campaign, {}) as Dictionary
	future[CampaignSnapshot.ROOT_VERSION] = 2
	_use_path(PRIMARY_PATH)
	_write_text(PRIMARY_PATH, CampaignSnapshot.to_text(future))
	_reset_counters()
	_check(not _save.load_campaign(), "§104 save_version = 2 é recusado no arquivo real")
	_check(_failed_events[0].contains("save_version"),
			"§104 o motivo diz a versão, obtido %s" % [_failed_events])
	_check(_snapshot_text() == guard, "§104 a recusa de versão não tocou em nada")

	# §105: falta campaign.core.
	var headless := campaign.duplicate(true) as Dictionary
	headless.erase(CampaignSnapshot.SECTION_CORE)
	_write_text(PRIMARY_PATH,
			CampaignSnapshot.to_text(CampaignSnapshot.build_document(headless, {})))
	_reset_counters()
	_check(not _save.load_campaign(), "§105 core ausente é recusado")
	_check(_failed_events[0].contains(CampaignSnapshot.SECTION_CORE),
			"§105 o motivo nomeia a seção, obtido %s" % [_failed_events])
	_check(_snapshot_text() == guard, "§105 nenhuma metade do JSON foi aplicada")

	# §106: resource_id que a whitelist não conhece.
	var alien := campaign.duplicate(true) as Dictionary
	(alien[CampaignSnapshot.SECTION_ECONOMY] as Dictionary)[
			CampaignSnapshot.KEY_STOCKPILE]["unknown_resource"] = 5
	_write_text(PRIMARY_PATH,
			CampaignSnapshot.to_text(CampaignSnapshot.build_document(alien, {})))
	_reset_counters()
	_check(not _save.load_campaign(), "§106 resource_id desconhecido é recusado")
	_check(_failed_events[0].contains("unknown_resource"),
			"§106 o motivo cita o id rejeitado, obtido %s" % [_failed_events])
	_check(_snapshot_text() == guard, "§106 o estoque do jogador permanece o mesmo")

	# §106/§38: rock_id que não é uma Rocha canônica da campanha.
	var alien_rock := campaign.duplicate(true) as Dictionary
	var rocks: Array = (alien_rock[CampaignSnapshot.SECTION_WORLD] as Dictionary)[
			CampaignSnapshot.KEY_ROCKS]
	(rocks[0] as Dictionary)[CampaignSnapshot.KEY_ROCK_ID] = "rock_999"
	_write_text(PRIMARY_PATH,
			CampaignSnapshot.to_text(CampaignSnapshot.build_document(alien_rock, {})))
	_reset_counters()
	_check(not _save.load_campaign(), "§38/§106 rock_id desconhecido é recusado")
	_check(_failed_events[0].contains("rock_999"),
			"§106 o motivo cita a Rocha estranha, obtido %s" % [_failed_events])

	# §71: unit_type_id que não é o Worker da campanha.
	var alien_unit := campaign.duplicate(true) as Dictionary
	var workers: Array = (alien_unit[CampaignSnapshot.SECTION_UNITS] as Dictionary)[
			CampaignSnapshot.KEY_WORKERS]
	(workers[0] as Dictionary)[CampaignSnapshot.KEY_UNIT_TYPE_ID] = "dragon_admin"
	_write_text(PRIMARY_PATH,
			CampaignSnapshot.to_text(CampaignSnapshot.build_document(alien_unit, {})))
	_reset_counters()
	_check(not _save.load_campaign(), "§71 unit_type_id desconhecido é recusado")
	_check(_failed_events[0].contains("dragon_admin"),
			"§71 o motivo cita o tipo estranho, obtido %s" % [_failed_events])
	_check(_snapshot_text() == guard, "§67 nenhuma recusa acima mutou a campanha")
	await _return_to_fresh()


# ==================================================== Bloco 3 — a matriz de cenários §82–§101


## §82: a partida que ainda não começou volta inteira, e nada do que a partida fez depois
## do save sobrevive a ela.
func _test_fresh_campaign_roundtrip() -> void:
	await _reset_campaign()
	var before := _snapshot_text()
	_check(int(_core_state.level) == 1, "§82 Nv.1")
	_check(_worker_count() == 1, "§82 exatamente um Worker, obtido %d" % _worker_count())
	_check(_crystal.amount == 0, "§82 Cristal 0, obtido %d" % _crystal.amount)
	_check(_stockpile.get_amount(ORE) == 0, "§82 estoque vazio")
	_check(_construction.nest() == null and _construction.barracks() == null,
			"§82 sem Ninho e sem Quartel")
	_check(_recruitment.soldier() == null, "§82 sem Soldado")
	_check(_invasion.invasion_state() == InvasionController.InvasionState.NOT_STARTED,
			"§82 invasão NOT_STARTED")

	_use_path(WORKER_PATH)
	_check(_save.save_campaign(), "§82 a campanha inicial foi salva")
	# Altera o mundo de verdade.
	_give_iron(9)
	_check(_invocation.summon_worker(), "§82 alteração: convocou Worker002")
	_check(_construction.build_nest(), "§82 alteração: lançou o Ninho")
	_core_state.damage(25.0)
	_worker.move_to(Vector3(-7.0, 0.0, 7.0))
	_check(_worker.action_mode() == WorkerRuntime.ActionMode.MOVE,
			"§82 a alteração é real: o Worker está andando")
	_reset_counters()
	_check(_save.load_campaign(), "§82 load")
	_check(_snapshot_text() == before, "§82 tudo volta exatamente como o arquivo")
	_check(_worker_count() == 1, "§82 o Worker002 pós-save desapareceu, obtido %d"
			% _worker_count())
	_check(_construction.nest() == null or _construction.nest().is_queued_for_deletion(),
			"§82 o Ninho pós-save desapareceu")
	_check(_close(_core_state.integrity, INTEGRITY_LV1),
			"§82 Integrity de volta a 100, obtida %f" % _core_state.integrity)
	_check(_stockpile.get_amount(ORE) == 0, "§82 o ferro pós-save sumiu do estoque")
	_check(_core_state.population_capacity_bonus == 0, "§82 bônus populacional 0")
	await _return_to_fresh()


## §83/§84: o segundo Worker é histórico, e a carga de um Worker é dado de campanha.
func _test_second_worker_and_cargo() -> void:
	await _reset_campaign()
	_give_iron(BUILD_COST + CARRY_CAPACITY)
	_check(_invocation.summon_worker(), "§83 Worker002 convocado na campanha do save")
	await _advance(0.05)
	var second: WorkerRuntime = _invocation.summoned_worker()
	second.state.set_cargo(_iron, CARRY_CAPACITY)
	second.global_position = Vector3(4.0, 0.0, 4.0)
	_check(_worker_count() == 2, "§83 dois Workers, obtido %d" % _worker_count())
	_check(_core_state.population == 2, "§83 Population 2, obtido %d" % _core_state.population)
	_check(_invocation.worker_ever_summoned(), "§83 worker_002_summoned true")

	_use_path(WORKER_PATH)
	var before := _snapshot_text()
	_check(_save.save_campaign(), "§83/§84 save com segundo Worker e carga")
	# Altera: entrega a carga, enche o estoque, move a unidade.
	second.state.clear_cargo()
	_give_iron(CARRY_CAPACITY)
	second.move_to(Vector3(-6.0, 0.0, -6.0))
	_check(_save.load_campaign(), "§83/§84 load")
	_check(_snapshot_text() == before, "§84 snapshot exato depois da carga")
	_check(_worker_count() == 2, "§83 continuam dois Workers, obtido %d" % _worker_count())
	_check(not _invocation.summon_worker(),
			"§83 worker_002_summoned=true trava um terceiro [I]")
	_check(_close(second.global_position.x, 4.0) and _close(second.global_position.z, 4.0),
			"§83 posição do Worker002 voltou, obtida %s" % second.global_position)
	_check(second.state.carried_amount == CARRY_CAPACITY,
			"§84 carga voltou a 3, obtido %d" % second.state.carried_amount)
	_check(second.state.carried_resource == _iron, "§84 o recurso carregado voltou")
	_check(_stockpile.get_amount(ORE) == BUILD_COST + CARRY_CAPACITY,
			"§84 o estoque voltou ao valor salvo, obtido %d" % _stockpile.get_amount(ORE))
	_check(_core_state.population == 2, "§29/§83 Population 2, obtido %d"
			% _core_state.population)
	await _return_to_fresh()


## §85/§86/§87: Rocha intacta, Rocha parcial, Rocha escavada e o monte no chão.
func _test_rocks_and_piles() -> void:
	await _reset_campaign()
	var ore := _rock(FIRST_ORE_ROCK_ID)
	_check(ore != null, "§37 a Rocha de minério da cena é registrada no ledger")
	if ore == null:
		return
	ore.state.apply_work(2.0)
	_check(_close(ore.state.remaining_work, ORE_ROCK_WORK - 2.0),
			"§85 trabalho restante parcial, obtido %f" % ore.state.remaining_work)
	_use_path(ROCK_PATH)
	var before := _snapshot_text()
	_check(_save.save_campaign(), "§85 save com Rocha parcial")
	# Conclusão da Rocha depois do save: ela sai da cena e larga um monte.
	ore.state.apply_work(ORE_ROCK_WORK)
	await _advance(0.1)
	_check(_rock(FIRST_ORE_ROCK_ID) == null, "§85 a Rocha escavada sumiu da cena")
	_check(_pile_count() == 1, "§85 a escavação largou um monte, obtido %d" % _pile_count())
	_check(_save.load_campaign(), "§85 load")
	_check(_snapshot_text() == before, "§85 snapshot exato com Rocha parcial")
	var restored := _rock(FIRST_ORE_ROCK_ID)
	_check(restored != null, "§85 a Rocha parcial reapareceu")
	if restored != null:
		_check(_close(restored.state.remaining_work, ORE_ROCK_WORK - 2.0),
				"§85 remaining_work voltou ao salvo, obtido %f" % restored.state.remaining_work)
	_check(_pile_count() == 0,
			"§85/§44 o monte criado depois do save não estava no arquivo, obtido %d"
					% _pile_count())

	# §86: Rocha escavada no momento do save não reaparece nunca.
	await _reset_campaign()
	var common := _rock(COMMON_ROCK_ID)
	_check(common != null, "§37 a Rocha comum está na cena")
	if common != null:
		common.state.apply_work(COMMON_ROCK_WORK)
		await _advance(0.1)
		_check(_rock(COMMON_ROCK_ID) == null, "§86 a Rocha foi escavada antes do save")
		_use_path(ROCK_PATH)
		var excavated := _snapshot_text()
		_check(_save.save_campaign(), "§86 save com Rocha escavada")
		_check(_save.load_campaign(), "§86 load")
		_check(_snapshot_text() == excavated, "§86 snapshot exato com Rocha escavada")
		_check(_rock(COMMON_ROCK_ID) == null, "§40/§86 a Rocha paga continua ausente")

	# §87: o monte do chão é campanha.
	await _reset_campaign()
	var ore_002 := _rock(SECOND_ORE_ROCK_ID)
	_check(ore_002 != null, "§37 a segunda Rocha de minério existe")
	if ore_002 == null:
		return
	ore_002.state.apply_work(ORE_ROCK_WORK)
	await _advance(0.1)
	_check(_pile_count() == 1, "§87 o monte existe no chão, obtido %d" % _pile_count())
	_use_path(PILE_PATH)
	var pile_before := _snapshot_text()
	_check(_save.save_campaign(), "§87 save com monte de minério")
	var pile := _first_pile()
	_check(pile != null and pile.state.amount == ROCK_YIELD,
			"§87 o monte salvo tem 3 de ferro, obtido %s"
					% ["ausente" if pile == null else str(pile.state.amount)])
	if pile != null:
		_check(pile.state.take(ROCK_YIELD) == ROCK_YIELD, "§87 a coleta esvaziou o monte")
	_check(_stockpile.get_amount(ORE) == 0, "§87 o estoque salvo estava zerado")
	_give_iron(5)
	_check(_save.load_campaign(), "§87 load")
	_check(_snapshot_text() == pile_before, "§87 snapshot exato com monte")
	var back := _first_pile()
	_check(back != null and back.state.amount == ROCK_YIELD,
			"§87/§43 o monte voltou com 3, obtido %s"
					% ["ausente" if back == null else str(back.state.amount)])
	_check(_stockpile.get_amount(ORE) == 0,
			"§87/§84 carga e estoque seguem o snapshot, obtido %d" % _stockpile.get_amount(ORE))
	await _return_to_fresh()


## §88/§89: a obra incompleta volta incompleta, e o bônus do Ninho pronto é o número salvo.
func _test_nest_progress_and_bonus() -> void:
	await _reset_campaign()
	_give_iron(BUILD_COST + 1)
	_check(_construction.build_nest(), "§88 o canteiro do Ninho foi aberto")
	var nest := _construction.nest()
	_check(nest != null, "§88 o Ninho existe na cena")
	if nest == null:
		return
	nest.state.apply_work(2.0)
	_check(_close(nest.state.remaining_work, 2.0),
			"§88 trabalho restante ~2, obtido %f" % nest.state.remaining_work)
	_check(_core_state.population_capacity_bonus == 0, "§88 ainda sem bônus")
	_use_path(NEST_PATH)
	var before := _snapshot_text()
	_check(_save.save_campaign(), "§88 save do Ninho incompleto")
	nest.state.apply_work(2.0)
	_check(nest.is_completed(), "§88 a obra foi concluída depois do save")
	_check(_core_state.population_capacity_bonus == NEST_BONUS,
			"§88 o bônus da partida em curso é 4, obtido %d"
					% _core_state.population_capacity_bonus)
	_check(_save.load_campaign(), "§88 load")
	_check(_snapshot_text() == before, "§88 snapshot exato do Ninho incompleto")
	_check(_core_state.population_capacity_bonus == 0,
			"§88/§31 o bônus voltou ao salvo (0), obtido %d"
					% _core_state.population_capacity_bonus)
	var restored := _construction.nest()
	_check(restored != null and _close(restored.state.remaining_work, 2.0),
			"§88 o canteiro voltou com ~2 de trabalho")

	# §89: Ninho completo, bônus 4, cargas repetidas nunca 8 nem 12.
	await _reset_campaign()
	_give_iron(BUILD_COST)
	_check(_construction.build_nest(), "§89 Ninho relançado")
	_construction.nest().state.apply_work(NEST_WORK)
	_check(_core_state.population_capacity_bonus == NEST_BONUS,
			"§89 bônus 4 aplicado pela conclusão real, obtido %d"
					% _core_state.population_capacity_bonus)
	_check(_invasion.invasion_state() == InvasionController.InvasionState.PREPARATION,
			"§89 a conclusão anunciou a ameaça")
	_use_path(NEST_PATH)
	var complete := _snapshot_text()
	_check(_save.save_campaign(), "§89 save com Ninho completo")
	_core_state.add_population_capacity_bonus(4)
	_check(_core_state.population_capacity_bonus == 8, "§89 a partida inflou o bônus para 8")
	_check(_save.load_campaign(), "§89 load")
	_check(_core_state.population_capacity_bonus == NEST_BONUS,
			"§89/§76 o bônus voltou a 4, nunca 8, obtido %d"
					% _core_state.population_capacity_bonus)
	_check(_snapshot_text() == complete, "§89 snapshot exato com Ninho completo")
	await _return_to_fresh()


## §90/§91/§97/§98: Quartel incompleto, Quartel pronto reconhecido, Soldado vivo e morto.
func _test_barracks_and_soldier() -> void:
	await _reset_campaign()
	_give_iron(BUILD_COST + 1)
	_check(_construction.build_barracks(), "§90 o Quartel foi lançado")
	var barracks := _construction.barracks()
	_check(barracks != null, "§90 o canteiro do Quartel existe")
	if barracks == null:
		return
	barracks.state.apply_work(2.0)
	_use_path(BARRACKS_PATH)
	var before := _snapshot_text()
	_check(_save.save_campaign(), "§90 save do Quartel incompleto")
	barracks.state.apply_work(BARRACKS_WORK)
	_check(barracks.is_completed(), "§90 a obra foi terminada depois do save")
	_check(_save.load_campaign(), "§90 load")
	_check(_snapshot_text() == before, "§90 progresso do Quartel voltou exato")
	var restored := _construction.barracks()
	_check(restored != null and _close(restored.state.remaining_work, BARRACKS_WORK - 2.0),
			"§90 o Quartel voltou com 4 de trabalho restante")

	# §91: um Quartel carregado completo é reconhecido como pronto, sem reemissão.
	await _reset_campaign()
	_give_iron(BUILD_COST)
	_check(_construction.build_barracks(), "§91 Quartel relançado")
	_construction.barracks().state.apply_work(BARRACKS_WORK)
	_use_path(BARRACKS_PATH)
	_check(_save.save_campaign(), "§91 save com Quartel completo")
	await _return_to_fresh()
	_use_path(BARRACKS_PATH)
	_check(_core_state.essence >= RECRUIT_COST, "§91 a campanha tem Essência para recrutar")
	_check(not _recruitment.barracks_completed(),
			"§91/§90 a partida limpa não tem Quartel nenhum")
	_reset_barracks_counter()
	_check(_save.load_campaign(), "§91 load do Quartel completo")
	_check(_recruitment.barracks_completed(), "§91 o recrutamento reconhece a obra carregada")
	_check(_recruitment.can_recruit(),
			"§91/§35 recrutar não exige reconstruir o Quartel")
	_check(_barracks_completed_events == 0,
			"§35/§75 a carga não reemite barracks_completed, obtido %d" % _barracks_completed_events)

	# §97: Soldado vivo com HP e posição próprios.
	var recruited := _recruitment.recruit_soldier()
	_check(recruited, "§97 o Soldado foi recrutado na campanha do save")
	var soldier := _recruitment.soldier()
	_check(soldier != null, "§97 o Soldado existe em cena")
	if soldier == null:
		return
	soldier.receive_damage(20.0)
	soldier.global_position = Vector3(3.0, 0.0, 3.0)
	_check(_close(soldier.state.health, SOLDIER_HP - 20.0),
			"§97 vida ferida, obtida %f" % soldier.state.health)
	_use_path(SOLDIER_PATH)
	var soldier_before := _snapshot_text()
	_check(_save.save_campaign(), "§97 save com Soldado ferido")
	soldier.state.heal(20.0)
	soldier.move_to(Vector3(-8.0, 0.0, 8.0))
	_check(soldier.action_mode() == SoldierRuntime.ActionMode.MOVE,
			"§97 a ordem de movimento é transitória")
	_check(_save.load_campaign(), "§97 load")
	_check(_snapshot_text() == soldier_before, "§97 snapshot exato do Soldado vivo")
	_check(_close(_recruitment.soldier().state.health, SOLDIER_HP - 20.0),
			"§97 a mesma vida voltou, obtida %f" % _recruitment.soldier().state.health)
	_check(_recruitment.soldier().global_position == Vector3(3.0, 0.0, 3.0),
			"§97 a mesma posição voltou, obtida %s" % _recruitment.soldier().global_position)
	_check(_recruitment.soldier().action_mode() == SoldierRuntime.ActionMode.IDLE,
			"§97/§139 a unidade própria volta IDLE")

	# §98: morto continua recrutado e não volta.
	await _reset_campaign()
	await _load_barracks_campaign_with_soldier()
	var alive := _recruitment.soldier()
	if alive == null:
		_check(false, "§98 o Soldado da campanha carregada não existe")
		return
	alive.receive_damage(9999.0)
	await _advance(0.1)
	_check(_recruitment.soldier() == null, "§98 o Soldado morto saiu da cena")
	_check(_recruitment.ever_recruited(), "§98 recruited continua true")
	_check(_core_state.population == 1,
			"§98 Population descontada, obtido %d" % _core_state.population)
	_use_path(SOLDIER_PATH)
	var dead_before := _snapshot_text()
	_check(_save.save_campaign(), "§98 save com Soldado morto")
	_check(not _recruitment.can_recruit(), "§98 morto não libera segundo recrutamento")
	_check(_save.load_campaign(), "§98 load")
	_check(_snapshot_text() == dead_before, "§98 snapshot exato da morte")
	_check(_recruitment.soldier() == null, "§98/§28 nada ressuscitou")
	_check(_recruitment.ever_recruited(), "§28 a flag histórica voltou do arquivo")
	_check(not _recruitment.can_recruit(), "§98/§47 R continua bloqueado depois do load")
	_check(_core_state.population == 1, "§98 Population seguiu o arquivo, %d"
			% _core_state.population)
	await _return_to_fresh()


## §92: a contagem volta no segundo exato e continua rodando dali.
func _test_preparation_countdown() -> void:
	await _reset_campaign()
	_invasion.preparation_duration = SHORT_PREP
	_check(_invasion.begin_preparation(), "§92 a preparação começou")
	await _advance(0.3)
	_check(_invasion.invasion_state() == InvasionController.InvasionState.PREPARATION,
			"§92 ainda em preparação")
	var remaining := _invasion.preparation_time_remaining()
	_check(remaining > 0.0 and remaining < SHORT_PREP,
			"§92 o cronômetro andou, restante %f" % remaining)
	_use_path(PREP_PATH)
	var before := _snapshot_text()
	_check(_save.save_campaign(), "§92 save durante a contagem")
	var became_active: Callable = func() -> bool:
		return _invasion.invasion_state() == InvasionController.InvasionState.ACTIVE
	var left_preparation: bool = await _wait_until(became_active, 4.0)
	_check(left_preparation, "§92 a partida deixou a preparação para trás")
	_check(_save.load_campaign(), "§92 load")
	_check(_invasion.invasion_state() == InvasionController.InvasionState.PREPARATION,
			"§92/§46 PREPARATION voltou, não ACTIVE")
	_check(absf(_invasion.preparation_time_remaining() - remaining) < 0.02,
			"§92/§47 o segundo exato voltou, obtido %f esperado %f"
					% [_invasion.preparation_time_remaining(), remaining])
	_check(_enemy_count() == 0, "§92/§48 nenhum invasor antes da hora, obtido %d"
			% _enemy_count())
	_check(_snapshot_text() == before, "§92 snapshot exato da contagem")
	var resumed_active: bool = await _wait_until(became_active, 4.0)
	_check(resumed_active, "§92/§48 o cronômetro retoma daquele ponto")
	_invasion.preparation_duration = PRODUCTION_PREP
	await _return_to_fresh()


## §93/§94/§130/§131: a campanha no meio do combate.
func _test_active_invasion() -> void:
	await _reset_campaign()
	_check(_invasion.start_invasion(), "§93 a invasão foi largada")
	await _advance(0.05)
	var enemies := _alive_enemies()
	_check(enemies.size() == INVADER_COUNT,
			"§93 dois invasores em campo, obtido %d" % enemies.size())
	if enemies.size() < INVADER_COUNT:
		return
	enemies[0].receive_damage(BEAST_HP - 30.0)
	enemies[1].global_position = Vector3(6.0, 0.0, 9.0)
	_check(_invasion.invasion_state() == InvasionController.InvasionState.ACTIVE,
			"§93 estado ACTIVE")
	_use_path(ACTIVE_PATH)
	var before := _snapshot_text()
	var started := Time.get_ticks_usec()
	_check(_save.save_campaign(), "§130/§93 save durante o combate")
	var elapsed := float(Time.get_ticks_usec() - started) / 1000.0
	_measurements["save_ms_durante_combate"] = elapsed
	_check(elapsed < 250.0,
			"§130 o save é instantâneo no frame do input, medido %f ms" % elapsed)

	# §93: os dois voltam com a vida e a posição salvas, retomando ADVANCE.
	enemies[0].receive_damage(9999.0)
	enemies[1].receive_damage(12.0)
	await _advance(0.1)
	_check(_save.load_campaign(), "§93 load do combate")
	var restored := _alive_enemies()
	_check(_invasion.invasion_state() == InvasionController.InvasionState.ACTIVE,
			"§93 ACTIVE voltou")
	_check(restored.size() == INVADER_COUNT,
			"§93/§94 os dois invasores salvos estão em campo, obtido %d" % restored.size())
	_check(_close(restored[0].state.health, 30.0),
			"§93/§49 o HP salvo voltou, obtido %f" % restored[0].state.health)
	_check(_close(restored[1].global_position.x, 6.0)
			and _close(restored[1].global_position.z, 9.0),
			"§93/§49 a posição salva voltou, obtida %s" % restored[1].global_position)
	for enemy in restored:
		_check(enemy.action_mode() == EnemyRuntime.ActionMode.ADVANCE,
				"§93/§50 cada Fera retomou ADVANCE, obtido %s" % enemy.action_mode())
	_check(_snapshot_text() == before, "§93 snapshot exato do combate")

	# §94: o que morreu no arquivo não ressuscita.
	await _return_to_fresh()
	_check(_invasion.start_invasion(), "§94 segunda largada")
	await _advance(0.05)
	var pair := _alive_enemies()
	_check(pair.size() == INVADER_COUNT,
			"§94 a largada põe duas Feras em campo, obtido %d" % pair.size())
	_check(pair[0].state.enemy_id == FIRST_INVADER \
			and pair[1].state.enemy_id == SECOND_INVADER,
			"§94 os ids semânticos são os do ciclo de vida, obtido %s e %s"
					% [pair[0].state.enemy_id, pair[1].state.enemy_id])
	pair[0].receive_damage(9999.0)
	await _advance(0.1)
	_check(_invasion.invasion_state() == InvasionController.InvasionState.ACTIVE,
			"§94 ainda ACTIVE com um vivo")
	_use_path(ACTIVE_PATH)
	var one_before := _snapshot_text()
	_check(_save.save_campaign(), "§94 save com um invasor vivo")
	_check(_save.load_campaign(), "§94 load")
	var alone := _alive_enemies()
	_check(alone.size() == 1, "§94/§50 exatamente um invasor, obtido %d" % alone.size())
	_check(alone[0].state.enemy_id == SECOND_INVADER,
			"§94 o vivo é o segundo, obtido %s" % alone[0].state.enemy_id)
	_check(_snapshot_text() == one_before, "§94 snapshot exato de um invasor")

	# §131: ordens transitórias e Nodes antigos não sobrevivem à carga.
	_selection.clear_selection()
	await _click_select(_worker)
	_check(_selection.selected_units.size() == 1,
			"§121 a seleção existe antes da carga, obtido %d" % _selection.selected_units.size())
	_worker.move_to(Vector3(-9.0, 0.0, -9.0))
	var old_enemies := _alive_enemies()
	var old_soldier := _recruitment.soldier()
	_check(not _save.snapshot_campaign()[
			CampaignSnapshot.SECTION_UNITS][CampaignSnapshot.KEY_WORKERS].is_empty(),
			"§4 a ordem de movimento não é campo do arquivo")
	_check(_save.load_campaign(), "§131 load no meio do combate")
	_check(_selection.selected_units.is_empty(),
			"§121/§4 seleção vazia depois de qualquer carga, obtido %d"
					% _selection.selected_units.size())
	_check(_worker.action_mode() == WorkerRuntime.ActionMode.IDLE,
			"§131/§4 o Worker voltou sem ordem")
	_check(not _worker.has_move_target(), "§131 nenhum alvo de movimento sobreviveu")
	await _advance(0.1)
	for enemy in old_enemies:
		_check(not is_instance_valid(enemy),
				"§131 nenhum Node invasor antigo continua atacando")
	if old_soldier != null and is_instance_valid(old_soldier):
		_check(old_soldier.action_mode() == SoldierRuntime.ActionMode.IDLE,
				"§131 o Soldado em cena foi posto em espera, não continua atacando")
	await _return_to_fresh()


## §95/§96: a vitória com a chave, e o Nv.2 que já pagou o preço.
func _test_victory_and_evolution() -> void:
	await _reset_campaign()
	_check(_invasion.start_invasion(), "§95 a invasão foi largada")
	await _advance(0.05)
	for enemy in _alive_enemies():
		enemy.receive_damage(9999.0)
	await _advance(0.05)
	_check(_invasion.invasion_state() == InvasionController.InvasionState.VICTORY,
			"§95 VICTORY")
	_check(_crystal.amount == 1, "§95 a partida ganhou a chave, obtido %d" % _crystal.amount)
	_give_essence(ESSENCE_GRANT)
	_use_path(VICTORY_PATH)
	var before := _snapshot_text()
	_check(_save.save_campaign(), "§95 save de VICTORY com Cristal 1")
	_check(_evolution.try_evolve(), "§95 a partida gastou a chave e evoluiu")
	_check(_crystal.amount == 0, "§95 a chave foi consumida, obtido %d" % _crystal.amount)
	_check(int(_core_state.level) == 2, "§95 a partida está em Nv.2")
	_reset_counters()
	_check(_save.load_campaign(), "§95 load")
	_check(_invasion.invasion_state() == InvasionController.InvasionState.VICTORY,
			"§95 VICTORY voltou")
	_check(_crystal.amount == 1, "§95/§51 o Cristal salvo voltou, obtido %d" % _crystal.amount)
	_check(_victory_events == 0,
			"§75/§51 a carga não reemite invasion_victory, obtido %d" % _victory_events)
	_check(_crystal_events == 1,
			"§54/§114 o Crystal voltou por um único amount_changed, obtido %d"
					% _crystal_events)
	_check(int(_core_state.level) == 1, "§95 o Core voltou para o momento salvo")
	_check(_snapshot_text() == before, "§95 snapshot exato da vitória")
	_check(_evolution.is_unlocked(), "§95/§79 a evolução continua destravada pelo arquivo")

	# §96: Nv.2 salvo, danificado na partida, restaurado nos números do arquivo.
	_check(_evolution.try_evolve(), "§96 Nv.2 reatingido na campanha carregada")
	await _advance(0.05)
	_use_path(LEVEL2_PATH)
	var saved_integrity := _core_state.integrity
	var saved_essence := _core_state.essence
	var lv2_before := _snapshot_text()
	_check(_save.save_campaign(), "§96 save do Nv.2")
	_core_state.damage(40.0)
	_core_state.consume_essence(saved_essence - 1.0)
	_worker.move_to(Vector3(7.0, 0.0, -7.0))
	_check(_save.load_campaign(), "§96 load")
	_check(int(_core_state.level) == 2, "§96 Nv.2 restaurado")
	_check(_close(_core_state.integrity, saved_integrity),
			"§96/§19 a mesma Integrity, obtida %f salva %f" % [_core_state.integrity,
					saved_integrity])
	_check(_close(_core_state.essence, saved_essence),
			"§96/§19 a mesma Essence, obtida %f salva %f" % [_core_state.essence, saved_essence])
	_check(_close(_core.definition().essence_generation_rate, GENERATION_LV2),
			"§96/§20 a geração voltou a 1.5/s, obtida %f"
					% _core.definition().essence_generation_rate)
	_check(_close(_core_state.definition.max_integrity, INTEGRITY_LV2),
			"§24/§124 o teto vem da Definition de Nv.2, obtido %f"
					% _core_state.definition.max_integrity)
	_check(_crystal.amount == 0, "§96 o Cristal voltou conforme o save, obtido %d"
			% _crystal.amount)
	_check(not _evolution.try_evolve(),
			"§139/§96 em Nv.2 não existe segunda evolução para cobrar")
	_check(_snapshot_text() == lv2_before, "§96 snapshot exato do Nv.2")
	await _return_to_fresh()


## §99: derrota é terminal, e um load não reinicia nada.
func _test_defeat_stays_defeat() -> void:
	await _reset_campaign()
	_check(_invasion.start_invasion(), "§99 a invasão foi largada")
	await _advance(0.05)
	_core_state.damage(9999.0)
	await _advance(0.05)
	_check(_invasion.invasion_state() == InvasionController.InvasionState.DEFEAT,
			"§99 DEFEAT pela queda do Núcleo")
	_check(_close(_core_state.integrity, 0.0), "§99 Núcleo a zero")
	_use_path(DEFEAT_PATH)
	var before := _snapshot_text()
	_check(_save.save_campaign(), "§99 save da derrota")
	await _return_to_fresh()
	_use_path(DEFEAT_PATH)
	_check(_core_state.integrity > 0.0, "§99 a partida limpa tinha Núcleo de pé")
	_check(_save.load_campaign(), "§99 load")
	_check(_invasion.invasion_state() == InvasionController.InvasionState.DEFEAT,
			"§99/§52 a derrota continua derrota")
	_check(_close(_core_state.integrity, 0.0),
			"§99 Integrity 0 voltou do arquivo, obtida %f" % _core_state.integrity)
	_check(not _invasion.begin_preparation(), "§99/§52 não reinicia PREPARATION")
	_check(not _invasion.start_invasion(), "§99/§52 não reinicia ACTIVE")
	_check(_enemy_count() == 0, "§52/§99 nenhum invasor recriado, obtido %d" % _enemy_count())
	_check(_snapshot_text() == before, "§99 snapshot exato da derrota")
	await _return_to_fresh()


## §100/§132/§133: cinco cargas do mesmo arquivo e nenhum duplicado.
func _test_repeated_load_is_idempotent() -> void:
	await _build_rich_campaign()
	_use_path(RICH_PATH)
	var before := _snapshot_text()
	_check(_save.save_campaign(), "§100 save da campanha rica")
	_check(_save.load_campaign(), "§100 primeira carga")
	_check(_snapshot_text() == before, "§100 carga 1 exata")
	# A obra da vida real tem dois ouvintes de conclusão: o controller, que paga o bônus,
	# e o Runtime, que troca o visual. §132 não é "um só" — é "nem um a mais depois de
	# cinco cargas".
	var nest_callbacks := _connections_of(_construction.nest().state.construction_completed)
	# As cargas são síncronas e costuradas sem frame no meio: §100 mede idempotência da
	# carga, e geração de Essência ou passo de Fera entre duas cargas é o mundo, não o load.
	for attempt in range(2, 6):
		_check(_save.load_campaign(), "§100 carga %d devolve true" % attempt)
		_check(_snapshot_text() == before, "§100 carga %d exata" % attempt)
	await _advance(0.1)
	_check(_worker_count() == 2, "§100 nenhum Worker duplicado, obtido %d" % _worker_count())
	_check(_building_count() == 2,
			"§100 Ninho e Quartel, um de cada, obtido %d" % _building_count())
	_check(_pile_count() == 1, "§100 nenhum monte duplicado, obtido %d" % _pile_count())
	_check(_soldier_count() == 1, "§100 um único Soldado, obtido %d" % _soldier_count())
	_check(_crystal.amount == 1, "§100 o Cristal não duplicou, obtido %d" % _crystal.amount)
	_check(_core_state.population_capacity_bonus == NEST_BONUS,
			"§100 o bônus do Ninho não acumulou, obtido %d"
					% _core_state.population_capacity_bonus)
	_check(_core_state.population == 3,
			"§29 Population bate com as três unidades próprias, obtido %d"
					% _core_state.population)
	# §132/§133: nenhuma conexão e nenhum Node acumulados com as cargas repetidas.
	_check(_connections_of(_core_state.destroyed) == 1,
			"§132 destroyed tem um único ouvinte depois de cinco cargas, obtido %d"
					% _connections_of(_core_state.destroyed))
	_check(_connections_of(_construction.nest().state.construction_completed) == nest_callbacks,
			"§132/§100 cinco cargas não acumularam callbacks da obra, %d contra %d"
					% [_connections_of(_construction.nest().state.construction_completed),
							nest_callbacks])
	_check(_connections_of(_recruitment.soldier().soldier_died) == 1,
			"§132 o Soldado restaurado tem um ouvinte de morte, obtido %d"
					% _connections_of(_recruitment.soldier().soldier_died))
	for enemy in _alive_enemies():
		_check(_connections_of(enemy.enemy_died) == 1,
				"§132 cada Fera restaurada escuta a própria morte uma vez")
	_measurements["objetos_apos_5_cargas"] = Performance.get_monitor(
			Performance.OBJECT_COUNT)
	_measurements["orfaos_apos_5_cargas"] = Performance.get_monitor(
			Performance.OBJECT_ORPHAN_NODE_COUNT)
	_check(_alive_runtime_count() < 40,
			"§133 a cena não acumulou runtimes, obtido %d" % _alive_runtime_count())
	await _return_to_fresh()


## §101: save → load → save produz o mesmo estado persistente. Timestamp fica no metadata
## (§72), fora do campaign, então a comparação é por construção livre de relógio.
func _test_roundtrip_is_stable() -> void:
	await _build_rich_campaign()
	_use_path(ROUNDTRIP_PATH)
	var snapshot_a := _snapshot_text()
	_check(_save.save_campaign(), "§101 save A")
	_check(_save.load_campaign(), "§101 load de A")
	var snapshot_after_load := _snapshot_text()
	_check(_save.save_campaign(), "§101 save B")
	var snapshot_b := _snapshot_text()
	_check(snapshot_a == snapshot_b, "§101 A == B para os dados persistentes")
	_check(snapshot_after_load == snapshot_a, "§101 o load não empurrou o domínio")
	var document_a := CampaignSnapshot.build_document(_save.snapshot_campaign(), {})
	_check(CampaignSnapshot.validate_document(document_a).is_empty(),
			"§101 o roundtrip continua um documento válido: %s"
					% CampaignSnapshot.validate_document(document_a))
	await _return_to_fresh()


## §121–§126/§4: o que o arquivo não guarda.
func _test_snapshot_holds_only_domain() -> void:
	await _build_rich_campaign()
	var campaign := _save.snapshot_campaign()
	var text := CampaignSnapshot.to_text(CampaignSnapshot.build_document(campaign, {}))
	for forbidden in ["max_health", "max_essence", "max_integrity", "work_required",
			"move_speed", "essence_generation_rate", "attack_damage", "display_name",
			"population_capacity\":", "\"completed\"", "\"visible\"", "label",
			"get_instance_id", "instance_id", "res://", "SelectionController",
			"func _process", "has_move_target", "action_mode", "combat_target",
			"attack_target", "reward", "crystal_reward", "first_victory", "\"saved\"",
			"quick_save", "autosave"]:
		_check(not text.contains(forbidden),
				"§122/§123/§124/§125/§126/§4 o arquivo não contém %s" % forbidden)
	# §125: o que existe é o bônus, não a capacidade efetiva.
	_check(text.contains(CampaignSnapshot.KEY_CAPACITY_BONUS),
			"§125 population_capacity_bonus é o campo salvo")
	var core: Dictionary = campaign[CampaignSnapshot.SECTION_CORE]
	_check(not core.has("population_capacity"),
			"§125 a capacidade efetiva não é campo do arquivo")
	# §4: ordens e alvos são derivadas do momento, não do arquivo.
	var units: Dictionary = campaign[CampaignSnapshot.SECTION_UNITS]
	var workers: Array = units[CampaignSnapshot.KEY_WORKERS]
	_check(not (workers[0] as Dictionary).has("order")
			and not (workers[0] as Dictionary).has("target"),
			"§4 nenhum registro de Worker guarda ordem ou alvo")
	_check(not campaign[CampaignSnapshot.SECTION_UNITS].has("selection"),
			"§121 a seleção não é uma seção do arquivo")
	_check(not units.has("population_capacity"), "§125 nada de capacidade derivada")
	# §123: conclusão de obra se deriva do trabalho restante.
	var constructions: Dictionary = campaign[CampaignSnapshot.SECTION_CONSTRUCTIONS]
	var nest: Dictionary = constructions[CampaignSnapshot.SECTION_NEST]
	_check(nest.has(CampaignSnapshot.KEY_REMAINING_WORK)
			and not nest.has("completed") and not nest.has("remaining"),
			"§123 o Ninho guarda trabalho restante, nunca o bool derivado")
	_check(not constructions.has("population_capacity_bonus"),
			"§125/§31 o bônus mora no Núcleo, uma única vez")
	await _return_to_fresh()


# ================================================= Bloco 4 — input, painel e limpeza


## §115: Ctrl+S e Ctrl+L na GameMain real, pelo InputMap, sem chamar método nenhum. A tecla
## entra por `Input.parse_input_event`, que é o caminho do sistema operacional: ela casa as
## ações do InputMap, alimenta o estado polled da câmera e entrega o `_unhandled_input` do
## controller — exatamente o tripé que uma chamada direta ao método nunca provaria.
func _test_manual_input_actions() -> void:
	await _reset_campaign()
	_use_path(INPUT_PATH)
	_remove_file(INPUT_PATH)
	_remove_file(INPUT_PATH.get_basename() + ".bak")
	_reset_counters()
	await _hold_key(KEY_S, true, 0.1)
	_check(FileAccess.file_exists(INPUT_PATH),
			"§115 Ctrl+S gravou o arquivo sem nenhum método ser chamado")
	_check(_save_events == [INPUT_PATH],
			"§115/§114 Ctrl+S emitiu save_succeeded uma vez, obtido %s" % [_save_events])
	_check(not Input.is_action_pressed("save_game"),
			"§115 a tecla de save foi solta, não ficou no ar")

	_give_iron(BUILD_COST + 1)
	_check(_construction.build_nest(), "§115 o mundo foi alterado depois do Ctrl+S")
	await _advance(0.05)
	_reset_counters()
	await _hold_key(KEY_L, true, 0.1)
	_check(_load_events == [INPUT_PATH],
			"§115/§114 Ctrl+L emitiu load_succeeded uma vez, obtido %s" % [_load_events])
	_check(_construction.nest() == null or _construction.nest().is_queued_for_deletion(),
			"§115 Ctrl+L devolveu a campanha: o Ninho pós-save sumiu")
	_check(_stockpile.get_amount(ORE) == 0,
			"§115 o estoque voltou ao momento do Ctrl+S, obtido %d" % _stockpile.get_amount(ORE))
	_check(_failed_events.is_empty(),
			"§114 as duas teclas bem-sucedidas não emitiram falha, obtido %s" % [_failed_events])


## §116: as duas combinações não sequestram nenhum comando de gameplay — e a letra continua
## sendo da câmera.
func _test_inputs_do_not_conflict() -> void:
	await _reset_campaign()
	_use_path(INPUT_PATH)
	_remove_file(INPUT_PATH)
	_remove_file(INPUT_PATH.get_basename() + ".bak")
	var rig_before := _camera_rig.global_position
	var ctrl_s := _key_event(KEY_S, true, true)
	var ctrl_l := _key_event(KEY_L, true, true)
	var plain_s := _key_event(KEY_S, false, true)
	_check(ctrl_s.is_action_pressed("save_game"),
			"§116 Ctrl+S corresponde à ação save_game")
	_check(ctrl_l.is_action_pressed("load_game"),
			"§116 Ctrl+L corresponde à ação load_game")
	_check(plain_s.is_action_pressed("camera_backward"),
			"§116 S puro continua sendo camera_backward — a letra não foi tomada")
	for action in COMMAND_ACTIONS:
		_check(not ctrl_s.is_action_pressed(action),
				"§116 Ctrl+S não dispara %s" % action)
		_check(not ctrl_l.is_action_pressed(action),
				"§116 Ctrl+L não dispara %s" % action)
	# A câmera é a única consumidora polled de tecla e o S é a letra dela; o matching do
	# InputMap é de subconjunto (Ctrl+S casa a tecla simples), então a prova de §116 é a
	# consequência no mundo com o chord segurado por doze frames.
	_reset_counters()
	Input.parse_input_event(ctrl_s)
	await _advance(0.2)
	_check(_camera_rig.global_position == rig_before,
			"§116 Ctrl+S segurado não arrastou a câmera, obtido %s"
					% _camera_rig.global_position)
	_check(_save_events == [INPUT_PATH],
			"§115/§116 Ctrl+S salvou pelo InputMap uma única vez, obtido %s" % [_save_events])
	await _release_key(KEY_S, true)
	# Controle não-vazio: sem chord, o S é WASD e anda. Se a guarda virar decorativa, esta
	# linha denuncia.
	Input.parse_input_event(plain_s)
	await _advance(0.2)
	_check(_camera_rig.global_position != rig_before,
			"§116/§55 S puro move a câmera, obtido %s" % _camera_rig.global_position)
	await _release_key(KEY_S, false)
	_camera_rig.global_position = rig_before
	_reset_counters()
	Input.parse_input_event(ctrl_l)
	await _advance(0.2)
	_check(_camera_rig.global_position == rig_before,
			"§116 Ctrl+L segurado não arrastou a câmera, obtido %s"
					% _camera_rig.global_position)
	_check(_load_events == [INPUT_PATH],
			"§115/§116 Ctrl+L carregou pelo InputMap uma única vez, obtido %s" % [_load_events])
	await _release_key(KEY_L, true)
	await _advance(0.05)
	_check(_construction.nest() == null, "§116 Ctrl+S/Ctrl+L não constroem Ninho")
	_check(_construction.barracks() == null, "§116 Ctrl+S/Ctrl+L não constroem Quartel")
	_check(not _invocation.worker_ever_summoned(), "§116 nenhuma convocação aconteceu")
	_check(not _recruitment.ever_recruited(), "§116 nenhum recrutamento aconteceu")
	_check(_invasion.invasion_state() == InvasionController.InvasionState.NOT_STARTED,
			"§116 nenhuma invasão foi iniciada")
	_check(int(_core_state.level) == 1 and not _evolution.is_unlocked(),
			"§116 nenhuma evolução foi disparada")
	_check(_enemy_count() == 0, "§116 nenhum invasor nasceu das teclas")
	_check(not Input.is_action_pressed("save_game")
			and not Input.is_action_pressed("load_game")
			and not Input.is_action_pressed("camera_backward"),
			"§116 nenhuma tecla de persistência ficou pressionada para os cenários seguintes")


## §77/§80: a carga não reemite conquista nenhuma — quem alinha a UI é o refresh.
func _test_hud_realigns_after_load() -> void:
	await _reset_campaign()
	_check(_text_of(_scene, "TitleLabel") == TITLE_LV1,
			"§77 o painel abre em Nv.1, obtido %s" % _text_of(_scene, "TitleLabel"))
	# Constrói uma campanha de vitória e a carrega sobre uma partida que já gastou a chave.
	_check(_invasion.start_invasion(), "§80/§77 largada para a vitória")
	await _advance(0.05)
	for enemy in _alive_enemies():
		enemy.receive_damage(9999.0)
	await _advance(0.05)
	_use_path(VICTORY_PATH)
	_check(_save.save_campaign(), "§80 save da vitória")
	_check(_text_of(_scene, "CrystalLabel") == CRYSTAL_ONE_LINE,
			"§80 o painel celebrou a conquista em tempo real, obtido %s"
					% _text_of(_scene, "CrystalLabel"))
	_give_essence(ESSENCE_GRANT)
	_check(_evolution.try_evolve(), "§80 a partida gastou a chave")
	_check(_text_of(_scene, "CrystalLabel") != CRYSTAL_ONE_LINE,
			"§80 sem carga o painel mostra o gasto, obtido %s"
					% _text_of(_scene, "CrystalLabel"))
	_check(_text_of(_scene, "TitleLabel") == TITLE_LV2, "§80 o título acompanhou a evolução")
	_check(_save.load_campaign(), "§80 load da vitória")
	_check(_text_of(_scene, "CrystalLabel") == CRYSTAL_ONE_LINE,
			"§77/§80 a chave voltou ao painel pelo refresh, obtido %s"
					% _text_of(_scene, "CrystalLabel"))
	_check(_text_of(_scene, "TitleLabel") == TITLE_LV1,
			"§77/§75 o título voltou ao Nv.1 sem reemitir evolved, obtido %s"
					% _text_of(_scene, "TitleLabel"))
	_check(_text_of(_scene, "IntegrityLabel") == "Integrity: 100 / 100",
			"§77 Integrity alinhada, obtido %s" % _text_of(_scene, "IntegrityLabel"))
	# Nv.2 carregado: o teto novo aparece no painel sem nenhum sinal de evolução.
	await _reset_campaign()
	_use_path(LEVEL2_PATH)
	_check(_save.load_campaign(), "§77/§80 load do Nv.2 salvo pela suíte")
	_check(_text_of(_scene, "TitleLabel") == TITLE_LV2,
			"§77/§75 o título veio do nível do State, obtido %s"
					% _text_of(_scene, "TitleLabel"))
	_check(_text_of(_scene, "IntegrityLabel").ends_with("/ 150"),
			"§77/§123 o teto do painel veio da Definition de Nv.2, obtido %s"
					% _text_of(_scene, "IntegrityLabel"))
	await _reset_campaign()


# ==================================================================== helpers de cenário


## A campanha que tem tudo: dois Workers, Ninho e Quartel prontos, Soldado, monte, Rocha
## parcial, Crystal e invasão em curso.
func _build_rich_campaign() -> void:
	await _reset_campaign()
	_give_iron(12)
	_check(_invocation.summon_worker(), "setup: Worker002 convocado")
	_check(_construction.build_nest(), "setup: Ninho lançado")
	_construction.nest().state.apply_work(NEST_WORK)
	_check(_construction.build_barracks(), "setup: Quartel lançado")
	_construction.barracks().state.apply_work(BARRACKS_WORK)
	_give_essence(ESSENCE_GRANT)
	_check(_recruitment.recruit_soldier(), "setup: Soldado recrutado")
	var ore := _rock(FIRST_ORE_ROCK_ID)
	ore.state.apply_work(2.0)
	var second_ore := _rock(SECOND_ORE_ROCK_ID)
	# §87: a Rocha totalmente paga no momento do save larga o monte que o arquivo guarda.
	second_ore.state.apply_work(ORE_ROCK_WORK)
	await _advance(0.1)
	_crystal.add(1)
	_invasion.start_invasion()
	await _advance(0.1)


## §97/§98: a campanha de referência — Quartel pronto e Soldado em campo — é montada, salva e
## devolvida pelo arquivo. O Soldado que o cenário manipula veio do load, nunca do estado que
## a cena já tinha.
func _load_barracks_campaign_with_soldier() -> void:
	_use_path(BARRACKS_PATH)
	_give_iron(BUILD_COST)
	_check(_construction.build_barracks(), "§97/§98 setup: Quartel lançado")
	_construction.barracks().state.apply_work(BARRACKS_WORK)
	await _advance(0.05)
	_give_essence(ESSENCE_GRANT)
	_check(_recruitment.recruit_soldier(), "§97/§98 setup: Soldado recrutado")
	_check(_save.save_campaign(), "§97/§98 save com Soldado em campo")
	await _reset_campaign()
	_use_path(BARRACKS_PATH)
	_check(_save.load_campaign(), "§97/§98 load da campanha com Soldado")


func _reset_campaign() -> void:
	_use_path(FRESH_PATH)
	_check(_save.load_campaign(), "§95 a carga de isolamento devolve a campanha do boot")
	await _advance(0.05)


## Volta ao pristine sem invalidar o caminho que o cenário estava usando.
func _return_to_fresh() -> void:
	await _reset_campaign()


func _give_iron(amount: int) -> void:
	_stockpile.add_resource(_iron, amount)


func _give_essence(amount: float) -> void:
	_core_state.add_essence(amount)


func _use_path(path: String) -> void:
	_save.configure_save_path(path)


func _reset_counters() -> void:
	_save_events.clear()
	_load_events.clear()
	_failed_events.clear()
	_victory_events = 0
	_defeat_events = 0
	_crystal_events = 0
	_barracks_completed_events = 0


func _reset_barracks_counter() -> void:
	_barracks_completed_events = 0


func _on_save_succeeded(path: String) -> void:
	_save_events.append(path)


func _on_load_succeeded(path: String) -> void:
	_load_events.append(path)


func _on_operation_failed(operation: String, reason: String) -> void:
	_failed_events.append("%s:%s" % [operation, reason])


func _on_invasion_victory() -> void:
	_victory_events += 1


func _on_invasion_defeat() -> void:
	_defeat_events += 1


func _on_barracks_completed(_barracks: BarracksRuntime) -> void:
	_barracks_completed_events += 1


func _on_crystal_changed(_amount: int) -> void:
	_crystal_events += 1


func _worker_count() -> int:
	return _workers().size()


func _workers() -> Array[WorkerRuntime]:
	var found: Array[WorkerRuntime] = []
	for child in _dungeon.get_children():
		var worker := child as WorkerRuntime
		if worker != null and not worker.is_queued_for_deletion():
			found.append(worker)
	return found


func _soldier_count() -> int:
	var total := 0
	for child in _dungeon.get_children():
		var soldier := child as SoldierRuntime
		if soldier != null and not soldier.is_queued_for_deletion():
			total += 1
	return total


func _pile_count() -> int:
	var total := 0
	for child in _dungeon.get_children():
		var pile := child as ResourcePileRuntime
		if pile != null and not pile.is_queued_for_deletion():
			total += 1
	return total


func _first_pile() -> ResourcePileRuntime:
	for child in _dungeon.get_children():
		var pile := child as ResourcePileRuntime
		if pile != null and not pile.is_queued_for_deletion():
			return pile
	return null


func _building_count() -> int:
	var total := 0
	for child in _dungeon.get_children():
		var site := child as ConstructionRuntime
		if site != null and not site.is_queued_for_deletion():
			total += 1
	return total


func _enemy_count() -> int:
	return _alive_enemies().size()


func _alive_enemies() -> Array[EnemyRuntime]:
	var found: Array[EnemyRuntime] = []
	for child in _dungeon.get_children():
		var enemy := child as EnemyRuntime
		if enemy != null and not enemy.is_queued_for_deletion() and not enemy.state.is_dead():
			found.append(enemy)
	return found


func _alive_runtime_count() -> int:
	var total := 0
	for child in _dungeon.get_children():
		if child is WorkerRuntime or child is SoldierRuntime or child is EnemyRuntime \
				or child is ConstructionRuntime or child is ResourcePileRuntime \
				or child is RockRuntime:
			total += 1
	return total


func _rock(rock_id: String) -> RockRuntime:
	for child in _dungeon.get_children():
		var rock := child as RockRuntime
		if rock != null and not rock.is_queued_for_deletion() and rock.rock_id == rock_id:
			return rock
	return null


func _connections_of(signal_source: Signal) -> int:
	return signal_source.get_connections().size()


func _snapshot_text() -> String:
	return _normalize(_save.snapshot_campaign())


## §101: comparação estável — Dictionary por chave ordenada, Array na ordem gravada.
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


# ============================================================ contrato e guardas de fonte


func _minimal_worker() -> Dictionary:
	return {
		CampaignSnapshot.KEY_UNIT_ID: CampaignSnapshot.FIRST_WORKER_ID,
		CampaignSnapshot.KEY_UNIT_TYPE_ID: "abyss_worker",
		CampaignSnapshot.KEY_HEALTH: WORKER_HP,
		CampaignSnapshot.KEY_LEVEL: 1,
		CampaignSnapshot.KEY_EXPERIENCE: 0.0,
		CampaignSnapshot.KEY_POSITION: [0.0, 0.0, 0.0],
		CampaignSnapshot.KEY_CARRIED_RESOURCE: null,
		CampaignSnapshot.KEY_CARRIED_AMOUNT: 0,
	}


## §68/§69: o mínimo que o contrato aceita, escrito à mão para as recusas estruturais não
## dependerem de cena nenhuma.
func _minimal_campaign() -> Dictionary:
	return {
		CampaignSnapshot.SECTION_CORE: {
			"core_id": CampaignSnapshot.CORE_ID,
			CampaignSnapshot.KEY_LEVEL: 1,
			CampaignSnapshot.KEY_INTEGRITY: INTEGRITY_LV1,
			CampaignSnapshot.KEY_ESSENCE: 20.0,
			CampaignSnapshot.KEY_POPULATION: 1,
			CampaignSnapshot.KEY_CAPACITY_BONUS: 0,
		},
		CampaignSnapshot.SECTION_PROGRESSION: {
			CampaignSnapshot.KEY_CRYSTAL: {CampaignSnapshot.KEY_AMOUNT: 0},
		},
		CampaignSnapshot.SECTION_ECONOMY: {
			CampaignSnapshot.KEY_STOCKPILE: {"iron_ore": 4},
		},
		CampaignSnapshot.SECTION_UNITS: {
			CampaignSnapshot.KEY_WORKERS: [_minimal_worker()],
			CampaignSnapshot.KEY_SECOND_SUMMONED: false,
			CampaignSnapshot.KEY_SOLDIER: {
				CampaignSnapshot.KEY_RECRUITED: false,
				CampaignSnapshot.KEY_ALIVE: false,
			},
		},
		CampaignSnapshot.SECTION_CONSTRUCTIONS: {
			CampaignSnapshot.SECTION_NEST: {CampaignSnapshot.KEY_EXISTS: false},
			CampaignSnapshot.SECTION_BARRACKS: {CampaignSnapshot.KEY_EXISTS: false},
		},
		CampaignSnapshot.SECTION_WORLD: {
			CampaignSnapshot.KEY_ROCKS: [{
				CampaignSnapshot.KEY_ROCK_ID: FIRST_ORE_ROCK_ID,
				CampaignSnapshot.KEY_REMAINING_WORK: ORE_ROCK_WORK,
				CampaignSnapshot.KEY_EXCAVATED: false,
			}],
			CampaignSnapshot.KEY_PILES: [],
		},
		CampaignSnapshot.SECTION_INVASION: {
			CampaignSnapshot.KEY_STATE: "NOT_STARTED",
			CampaignSnapshot.KEY_PREPARATION_REMAINING: 0.0,
			CampaignSnapshot.KEY_INVADERS: [],
		},
	}


func _campaign_copy() -> Dictionary:
	return _minimal_campaign()


func _accept(document: Variant, label: String) -> void:
	var reason := CampaignSnapshot.validate_document(document)
	_check(reason.is_empty(), "%s — aceito, obtido %s" % [label, reason])


func _refuse(document: Variant, needle: String, label: String) -> void:
	var reason := CampaignSnapshot.validate_document(document)
	_check(not reason.is_empty() and reason.contains(needle),
			"%s — recusado com %s" % [label, reason if not reason.is_empty() else "<aceito>"])


func _refuse_document(campaign: Dictionary, needle: String, label: String) -> void:
	_refuse(CampaignSnapshot.build_document(campaign, {}), needle, label)


## §112: distingue A de B pelo dado, não pelo relógio.
func _has_nest_in_file(path: String) -> bool:
	var parsed: Variant = CampaignSnapshot.parse_document(_read_text(path))
	if not (parsed is Dictionary):
		return false
	var campaign: Variant = (parsed as Dictionary).get(CampaignSnapshot.ROOT_CAMPAIGN)
	if not (campaign is Dictionary):
		return false
	var constructions: Variant = (campaign as Dictionary).get(
			CampaignSnapshot.SECTION_CONSTRUCTIONS)
	if not (constructions is Dictionary):
		return false
	var nest: Variant = (constructions as Dictionary).get(CampaignSnapshot.SECTION_NEST)
	if not (nest is Dictionary):
		return false
	return bool((nest as Dictionary).get(CampaignSnapshot.KEY_EXISTS, false))


# ============================================================================== infraestrutura


func _boot_scene() -> void:
	_scene = MAIN_SCENE.instantiate()
	root.add_child(_scene)
	await _advance(0.2)
	_camera_rig = _scene.get_node("World/CameraRig") as Node3D
	_camera = _scene.get_node("World/CameraRig/Camera3D") as Camera3D
	_dungeon = _scene.get_node("World/DungeonRoot") as Node3D
	_selection = _scene.get_node("Systems/SelectionController") as SelectionController
	_construction = _scene.get_node("Systems/ConstructionController") as ConstructionController
	_invocation = _scene.get_node(
			"Systems/WorkerInvocationController") as WorkerInvocationController
	_recruitment = _scene.get_node(
			"Systems/SoldierRecruitmentController") as SoldierRecruitmentController
	_invasion = _scene.get_node("Systems/InvasionController") as InvasionController
	_evolution = _scene.get_node("Systems/CoreEvolutionController") as CoreEvolutionController
	_save = _scene.get_node("Systems/SaveGameController") as SaveGameController
	_core = _scene.get_node("World/DungeonRoot/MainCore") as CoreRuntime
	_worker = _scene.get_node("World/DungeonRoot/Worker001") as WorkerRuntime
	var deposit := _scene.get_node("World/DungeonRoot/Deposit001") as ResourceDepositRuntime
	_stockpile = deposit.stockpile
	_core_state = _core.core_state()
	_crystal = _evolution.abyssal_crystal_state()
	_iron = load(ORE_PATH) as ResourceDefinition
	_player_before = _presence(PLAYER_PRIMARY)
	_player_backup_before = _presence(PLAYER_BACKUP)
	_save.save_succeeded.connect(_on_save_succeeded)
	_save.load_succeeded.connect(_on_load_succeeded)
	_save.operation_failed.connect(_on_operation_failed)
	_invasion.invasion_victory.connect(_on_invasion_victory)
	_invasion.invasion_defeat.connect(_on_invasion_defeat)
	_construction.barracks_completed.connect(_on_barracks_completed)
	_crystal.amount_changed.connect(_on_crystal_changed)
	Engine.set_physics_ticks_per_second(TICKS)


func _free_scene() -> void:
	_save = null
	_stockpile = null
	_core_state = null
	_crystal = null
	_worker = null
	_core = null
	if _scene != null and is_instance_valid(_scene):
		_scene.queue_free()
	_scene = null
	await _advance(0.2)


## §107: "Limpar ao final." O que a suíte criou em user://tests/ desaparece.
func _cleanup_test_files() -> void:
	for path in TEST_PATHS:
		_remove_file(path)
		_remove_file(path.get_basename() + ".bak")
		_remove_file(path.get_basename() + ".tmp")
	var directory := DirAccess.open("user://tests")
	if directory != null:
		directory.remove("save_load")
	var survivors: Array[String] = []
	for path in TEST_PATHS:
		if FileAccess.file_exists(path):
			survivors.append(path)
	_check(survivors.is_empty(),
			"§107 nenhum arquivo de teste sobreviveu, restaram %s" % [survivors])
	_check(DirAccess.open(TEST_DIR) == null,
			"§107 o diretório de teste não fica para trás")


func _remove_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


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


## §107: o save do jogador é medido por conteúdo, não por presunção.
func _presence(path: String) -> String:
	if not FileAccess.file_exists(path):
		return "ausente"
	var text := _read_text(path)
	return "presente:%d:%d" % [text.length(), text.hash()]


func _test_player_save_untouched() -> void:
	_check(_presence(PLAYER_PRIMARY) == _player_before
			and _presence(PLAYER_BACKUP) == _player_backup_before,
			"§107 o save real do jogador não foi tocado: %s → %s"
					% [_player_before, _presence(PLAYER_PRIMARY)])
	for path in TEST_PATHS:
		_check(path.begins_with("user://tests/"),
				"§107 todo caminho de teste está isolado, obtido %s" % path)
	_check(_save == null, "§108 a suíte não guarda referência a nenhum Node já libertado")


## §115/§116: a tecla entra pelo caminho do sistema operacional, `Input.parse_input_event`,
## que casa a ação do InputMap, atualiza o estado polled e entrega o `_unhandled_input`. Um
## toque completo é press, mundo rodando, release — sem release a ação ficaria no ar e
## travaria a guarda de chord da câmera para todos os cenários seguintes.
func _hold_key(keycode: int, with_ctrl: bool, seconds: float) -> void:
	_press_key(keycode, with_ctrl)
	await _advance(seconds)
	await _release_key(keycode, with_ctrl)


func _press_key(keycode: int, with_ctrl: bool) -> void:
	Input.parse_input_event(_key_event(keycode, with_ctrl, true))


func _release_key(keycode: int, with_ctrl: bool) -> void:
	Input.parse_input_event(_key_event(keycode, with_ctrl, false))
	await _advance(0.05)


func _key_event(keycode: int, with_ctrl: bool, is_pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.ctrl_pressed = with_ctrl
	event.pressed = is_pressed
	return event


func _click_select(worker: WorkerRuntime) -> void:
	var screen := _camera.unproject_position(worker.global_position)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = screen
	press.global_position = screen
	root.push_input(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = screen
	release.global_position = screen
	root.push_input(release)
	await _advance(0.05)


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
	print("[INFO] medições de save/load: %s" % [_measurements])


func _check(condition: bool, label: String) -> void:
	_asserts += 1
	if condition:
		print("[PASS] %s" % label)
	else:
		_failures += 1
		print("[FAIL] %s" % label)


func _finish() -> void:
	print("---- save load tests finished: %d asserts, %d failure(s) ----"
			% [_asserts, _failures])
	quit(1 if _failures > 0 else 0)
