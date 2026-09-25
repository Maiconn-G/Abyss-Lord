extends SceneTree

# Tarefa 13 — Timer de Invasão, Aviso Prévio e Preparação Defensiva.
#
# A suíte prova o anúncio: o Ninho concluído abre PREPARATION com 60 s de crédito
# (§6/§32), o countdown anda por delta em tempo real (§4/§5), nenhum invasor nasce
# antes do zero (§27), a largada em zero é exatamente a largada da Tarefa 12 (§12),
# e durante todo o aviso a partida continua sendo um RTS (§22–§26, §54–§61). O aviso
# em si é UI: aparece na preparação, some na largada e não segura clique (§17–§21).
#
# Três blocos, nesta ordem:
#   1) ciclo de vida isolado do InvasionController, sem HUD nenhum (§74) e sem cena;
#   2) Cena A — a campanha de produção inteira sob os 60 s verdadeiros (§23/§62/§63);
#   3) Cena B/C — a tecla F em cada estado (§46–§50) e o jogador que não se prepara
#      (§65/§67), com duração encurtada só pelo @export, como §16 autoriza.
#
# Convenção desta suíte e das anteriores: o input do jogador é sempre sintético, mas
# entra pelo InputMap e pelos raycasts de tela reais, e nada na produção joga sozinho
# (§64). A Essência é reposta pelo harness porque a geração de 1/s do Núcleo não paga
# a conta dentro da janela de medição — isso é funding de teste, não ação automática.

const MAIN_SCENE := preload("res://game/GameMain.tscn")
const CORE_SCENE := preload("res://world/dungeon/core/CoreRuntime.tscn")
const ENEMY_SCENE := preload("res://units/enemies/EnemyRuntime.tscn")
const WARNING_SCENE := preload("res://ui/hud/InvasionWarningHud.tscn")
const INVASION_HUD_SCENE := preload("res://ui/hud/InvasionDebugHud.tscn")

const CORE_DEFINITION_PATH := "res://data/core/core_level_1.tres"
const IRON_ORE_PATH := "res://data/resources/iron_ore.tres"
const ENEMY_DEFINITION_PATH := "res://data/units/enemies/cave_beast.tres"

const INVASION_CONTROLLER_SOURCE_PATH := "res://systems/combat/invasion_controller.gd"
const INVASION_HUD_SOURCE_PATH := "res://ui/hud/invasion_debug_hud.gd"
const INVASION_WARNING_HUD_SOURCE_PATH := "res://ui/hud/invasion_warning_hud.gd"
const INVASION_WARNING_SCENE_PATH := "res://ui/hud/InvasionWarningHud.tscn"
const GAME_MAIN_SOURCE_PATH := "res://game/game_main.gd"
const NEST_STATE_SOURCE_PATH := "res://core/state/nest_state.gd"
const CORE_STATE_SOURCE_PATH := "res://core/state/core_state.gd"
const PROJECT_SETTINGS_PATH := "res://project.godot"

const GROUND_LAYER := 1
const UNIT_LAYER := 2
const DIGGABLE_LAYER := 4
const RESOURCE_LAYER := 8
const CONSTRUCTION_LAYER := 16
const ENEMY_LAYER := 32

const SPAWN_A := Vector3(-4, 0, 10)
const SPAWN_B := Vector3(11, 0, 0)
const CORE_PLANAR := Vector3.ZERO
## Os dois invasores nascem a mais de 10 m do Núcleo e a 15.7 m um do outro: qualquer
## corpo a menos de 1 m do seu ponto de largada só pode ter nascido ali.
const BIRTH_TOLERANCE := 1.0
## Postura defensiva do Soldado: na rota do Invader001, a tempo de interceptar antes
## de o Núcleo apanhar, e fora da linha de visão da câmera para o clique entrar.
const SOLDIER_DEFENSE := Vector3(-2.2, 0, 6.2)
const NEST_POINT := Vector3(-5, 0, -5)
const BARRACKS_POINT := Vector3(-10, 0, -5)
const WORKER_WALK_TARGET := Vector3(6.0, 0.0, 9.0)

const FIRST_ORE_ROCK_ID := "iron_ore_001"
const SECOND_ORE_ROCK_ID := "iron_ore_002"

const BEAST_HP := 48.0
const BEAST_SPEED := 2.5
const BEAST_RADIUS := 0.6
const SOLDIER_HP := 80.0
const ORE := &"iron_ore"
const INTEGRITY := 100.0
const CAPACITY_BASE := 8
const CAPACITY_WITH_NEST := 12
const TICKS := 60

## Durações de teste. 60.0 é o valor de produção e Cena A o usa sem encostar nele;
## os outros só existem porque §16 manda encurtar pelo @export, nunca por tecla.
const PRODUCTION_DURATION := 60.0
const ROUND_DURATION := 5.0
const NO_PREP_DURATION := 2.0
## §52: 42.2 s restantes têm de virar 43 no ceil — o exemplo literal da especificação.
const CEIL_PROBE_DURATION := 42.2

const HINT_LINE := "[F] Iniciar primeira invasão"
const WAITING_STATUS := "Status: aguardando ameaça"
const PREPARATION_ALERT := "AMEAÇA DETECTADA"
const PREPARATION_ADVICE := "Prepare suas defesas."
const ACTIVE_STATUS := "Status: INVASÃO"
const VICTORY_STATUS := "Status: VITÓRIA"
const DEFEAT_STATUS := "Status: DERROTA"
const WARNING_TITLE := "AMEAÇA DETECTADA"
## §52: 42.2 s restantes têm de aparecer como 43 nos dois painéis.
const CEIL_WARNING_LINE := "INVASÃO EM 43 s"
const CEIL_STATUS_LINE := "Invasão em: 43 s"

var _failures := 0
var _asserts := 0
var _frames := 0
var _scene: Node
var _dungeon: Node3D
var _camera: Camera3D
var _selection: SelectionController
var _construction: ConstructionController
var _recruitment: SoldierRecruitmentController
var _invasion: InvasionController
var _deposit: ResourceDepositRuntime
var _core: CoreRuntime
var _core_state: CoreState
var _stockpile: ResourceStockpileState
var _invasion_hud: Node
var _warning_hud: Node
var _worker: WorkerRuntime
var _worker2: WorkerRuntime
var _soldier: SoldierRuntime

## Contadores de sinal. §43/§44/§45 e §72 exigem "exatamente uma vez", e uma vez só se
## prova com um contador que a cena alimenta, nunca com uma inferência.
var _started_events := 0
var _victory_events := 0
var _defeat_events := 0
var _preparation_events := 0
var _time_changed_events := 0
var _capacity_events := 0
var _remaining_trace: Array[int] = []
var _countdown_trace: Array[float] = []
var _status_trace: Array[String] = []
var _measurements := {}
## Contadores da varredura frame a frame de §41. São variáveis do harness porque um
## lambda do GDScript captura locais por valor: incrementando um `var` da função, a
## varredura contaria para sempre zero.
var _probe_frames := 0
var _probe_clean_frames := 0

## Sonda isolada do controller: cena mínima, sem UI nenhuma, para §74.
var _rig: Node3D
var _rig_controller: InvasionController
var _rig_core: CoreRuntime
var _rig_state: CoreState


func _initialize() -> void:
	_run_all()


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > 1200000:
		_check(false, "timeout: a suíte de preparação não terminou")
		_finish()
	return false


func _run_all() -> void:
	# Bloco 1 — o ciclo de vida do cronômetro sem jogo em volta.
	_test_controller_source()
	_test_hud_sources()
	_test_scope_guards()
	await _test_isolated_lifecycle()
	await _test_isolated_no_early_spawn()
	await _test_isolated_second_preparation()
	await _test_countdown_is_real_time()
	await _test_countdown_at_30_and_120_hz()
	await _test_isolated_f_key()
	await _test_isolated_no_key_skip()
	await _test_isolated_huds_read_ceil()
	_test_warning_scene_surface()

	# Bloco 2 — Cena A: a campanha inteira sob os 60 segundos de produção.
	await _boot_scene()
	await _test_boot_state()
	await _test_nest_opens_preparation()
	await _test_gameplay_during_countdown()
	await _test_full_preparation_campaign()
	await _test_launch_at_zero()
	await _test_defense_and_victory()
	await _test_nothing_after_victory()
	_free_scene()

	# Bloco 3 — Cena B: a tecla F em cada estado do ciclo.
	await _boot_scene()
	await _test_f_opens_preparation()
	await _test_f_does_not_skip_or_reset()
	await _test_f_after_launch_and_end()
	_free_scene()

	# Cena C — o jogador que não prepara nada.
	await _boot_scene()
	await _test_unprepared_defeat()
	_free_scene()

	_print_measurements()
	_finish()


# ============================================================ Bloco 1 — ciclo isolado


## Os textos, o enum e as proibições de arquivo. É aqui que §75/§76/§77/§78 são presos
## antes de qualquer comportamento: se o sistema novo existir, a suíte já acusa.
func _test_controller_source() -> void:
	var source := _source(INVASION_CONTROLLER_SOURCE_PATH)
	_check(source.contains("enum InvasionState { NOT_STARTED, PREPARATION, ACTIVE, "
			+ "VICTORY, DEFEAT }"), "§2 os cinco estados, na ordem pedida, num enum local")
	_check(source.contains("@export var preparation_duration: float = 60.0"),
			"§3 a duração de produção é um @export 60.0")
	_check(source.contains("signal preparation_started(duration: float)"),
			"§9 preparation_started(duration) existe")
	_check(source.contains("signal preparation_time_changed(remaining: float, "
			+ "duration: float)"), "§9 preparation_time_changed(remaining, duration) existe")
	_check(source.contains("func begin_preparation() -> bool"), "§13 begin_preparation existe")
	_check(source.contains("func _process(delta: float) -> void"),
			"§5/§79 o countdown anda por delta em _process")
	_check(source.contains("set_process(false)") and source.contains("set_process(true)"),
			"§5/§79 o processamento só liga na preparação")
	_check(source.contains("maxf(_preparation_time_remaining - delta, 0.0)"),
			"§4 o restante é decrementado por delta e clampado em 0")
	_check(source.contains("if _state != InvasionState.PREPARATION:"),
			"§79 fora de PREPARATION o _process se desliga sozinho")
	# §12/§13: a transição para ACTIVE reusa a largada da Tarefa 12. Uma função nova de
	# spawn seria duplicação, e é exatamente o que a especificação veda.
	_check(source.count("func start_invasion(") == 1, "§12 existe uma única largada")
	_check(source.contains("_displayed_second"),
			"§10 o emissão de tempo só acontece quando o segundo exibido vira")
	_check(source.contains("int(ceilf(remaining))") or source.contains("ceilf(_preparation"),
			"§11 a política de arredondamento é ceil")
	var code := _code_of(INVASION_CONTROLLER_SOURCE_PATH)
	for forbidden in ["Timer", "create_timer", "await", "GameClock", "TimeManager",
			"EventManager", "StoryManager", "EventBus", "Milestone", "Wave", "Threat",
			"get_tree().paused", "Engine.time_scale", "randf", "RandomNumberGenerator"]:
		_check(not code.contains(forbidden),
				"§5/§34/§75/§76/§77/§80 o controller não contém %s" % forbidden)
	for forbidden in ["Nest", "Construction", "construction_completed"]:
		_check(not code.contains(forbidden),
				"§33 o controller não sai procurando %s na árvore" % forbidden)


func _test_hud_sources() -> void:
	var status := _source(INVASION_HUD_SOURCE_PATH)
	for line in [WAITING_STATUS, PREPARATION_ALERT, PREPARATION_ADVICE, ACTIVE_STATUS,
			VICTORY_STATUS, DEFEAT_STATUS, HINT_LINE]:
		_check(status.contains(line), "§17 o painel de status conhece a linha \"%s\"" % line)
	_check(status.contains("\"Invasão em: %d s\""), "§17 o painel de status mostra a contagem")
	for signal_name in ["preparation_started", "preparation_time_changed"]:
		_check(status.contains(signal_name + ".connect"),
				"§9/§40 o painel consome %s por sinal" % signal_name)
	_check(not _code_of(INVASION_HUD_SOURCE_PATH).contains("func _process("),
			"§40 o painel de status não varre o jogo por frame")
	var warning := _source(INVASION_WARNING_HUD_SOURCE_PATH)
	_check(warning.contains("extends PanelContainer"), "§18 o aviso é PanelContainer + Label")
	_check(warning.contains("\"AMEAÇA DETECTADA\""), "§19 o aviso tem o título pedido")
	_check(warning.contains("INVASÃO EM"), "§19 o aviso mostra os segundos restantes")
	_check(warning.contains("visible = false") or warning.contains("_hide()"),
			"§20 o aviso sabe se esconder")
	for signal_name in ["preparation_started", "preparation_time_changed", "invasion_started"]:
		_check(warning.contains(signal_name + ".connect"),
				"§20/§70 o aviso obedece a %s" % signal_name)
	var warning_code := _code_of(INVASION_WARNING_HUD_SOURCE_PATH)
	for forbidden in ["Timer", "create_timer", "Tween", "AnimationPlayer", "AudioStream",
			"Camera", "shake", "Sound", "func _process("]:
		_check(not warning_code.contains(forbidden),
				"§18/§75 o aviso não faz %s — é só Label por sinal" % forbidden)
	_check(not _source(GAME_MAIN_SOURCE_PATH).contains("Engine.time_scale")
			and not _source(GAME_MAIN_SOURCE_PATH).contains("get_tree().paused"),
			"§80 a composition root não pausa nada")


func _test_scope_guards() -> void:
	var sources := _collect_gd_files("res://")
	_check(not sources.is_empty(), "§82 a varredura encontrou os fontes de produção")
	for forbidden in ["GameClock", "TimeManager", "DayNight", "CalendarSystem",
			"EventManager", "StoryEventManager", "GameEventManager", "MilestoneManager",
			"EventBus", "WaveManager", "WaveDefinition", "ThreatManager", "EnemySpawner",
			"SpeedToggle", "GameSpeed", "AutoBuild", "AutoRecruit", "AutoMine"]:
		var offenders := _files_containing(sources, forbidden)
		_check(offenders.is_empty(),
				"§75/§76/§77/§78/§64 nenhum fonte contém %s, achado em %s"
						% [forbidden, offenders])
	_check(_collect_gd_files("res://systems/events").is_empty(),
			"§34 systems/events continua sem script nenhum")
	_check(_collect_gd_files("res://systems/combat").size() == 1,
			"§34 systems/combat continua com exatamente um script")
	# §35: o countdown é transitório e não migrou para dentro de nenhum State persistido.
	for path in [NEST_STATE_SOURCE_PATH, CORE_STATE_SOURCE_PATH]:
		var code := _code_of(path)
		for forbidden in ["preparation", "Invasion", "countdown", "warning"]:
			_check(not code.to_lower().contains(forbidden.to_lower()),
					"§35 %s não guarda nada da preparação (%s)" % [path, forbidden])
	# §72/§33: o bônus de população do Ninho não passou a depender da invasão existir.
	_check(_code_of("res://systems/construction/construction_controller.gd")
			.find("Invasion") < 0,
			"§33/§73 o ConstructionController não conhece a invasão")


## A cena isolada: um dungeon vazio, dois Marker3D, um CoreRuntime de verdade e o
## controller. Nem HUD, nem GameMain — é assim que §74 prova que o cronômetro é dono
## do ciclo e a interface é apenas consumidora.
func _make_isolated_rig(duration: float) -> InvasionController:
	# Cada rig isolado é um ciclo limpo: os contadores de sinal pertencem à cena que está
	# sendo montada agora, não à soma de todos os rigs da suíte.
	_preparation_events = 0
	_time_changed_events = 0
	_started_events = 0
	_victory_events = 0
	_defeat_events = 0
	_countdown_trace.clear()
	_probe_frames = 0
	_probe_clean_frames = 0
	_rig = Node3D.new()
	_rig.name = "IsolatedRig"
	root.add_child(_rig)
	var dungeon := Node3D.new()
	dungeon.name = "DungeonRoot"
	_rig.add_child(dungeon)
	_rig_core = CORE_SCENE.instantiate() as CoreRuntime
	dungeon.add_child(_rig_core)
	_rig_state = CoreState.new(load(CORE_DEFINITION_PATH) as CoreDefinition)
	_rig_core.setup(load(CORE_DEFINITION_PATH) as CoreDefinition, _rig_state)
	for point_name in ["InvasionSpawnPointA", "InvasionSpawnPointB"]:
		var marker := Marker3D.new()
		marker.name = point_name
		dungeon.add_child(marker)
	# Os @onready dos nós só resolvem depois de um frame na árvore.
	await process_frame
	# Os dois pontos da produção, exatamente onde o GameMain os coloca.
	dungeon.get_node("InvasionSpawnPointA").global_position = SPAWN_A
	dungeon.get_node("InvasionSpawnPointB").global_position = SPAWN_B
	_rig_controller = InvasionController.new()
	_rig_controller.name = "InvasionController"
	_rig.add_child(_rig_controller)
	await process_frame
	_rig_controller.setup(
			load(ENEMY_DEFINITION_PATH) as EnemyDefinition,
			ENEMY_SCENE,
			dungeon,
			_rig_core,
			[dungeon.get_node("InvasionSpawnPointA"), dungeon.get_node("InvasionSpawnPointB")])
	_rig_controller.preparation_duration = duration
	_rig_controller.preparation_started.connect(_on_preparation_started)
	_rig_controller.preparation_time_changed.connect(_on_preparation_time_changed)
	_rig_controller.invasion_started.connect(_on_invasion_started)
	return _rig_controller


func _free_isolated_rig() -> void:
	_rig_controller = null
	_rig_core = null
	_rig_state = null
	if _rig != null and is_instance_valid(_rig):
		_rig.free()
	_rig = null


func _on_preparation_started(_duration: float) -> void:
	_preparation_events += 1


func _on_preparation_time_changed(remaining: float, _duration: float) -> void:
	_time_changed_events += 1
	_countdown_trace.append(remaining)


func _on_invasion_started(_invaders: Array) -> void:
	_started_events += 1


## §36/§38/§42/§43/§44/§45/§74/§79: o ciclo inteiro, sem cena e sem HUD.
func _test_isolated_lifecycle() -> void:
	var controller := await _make_isolated_rig(PRODUCTION_DURATION)
	_check(controller.preparation_duration == PRODUCTION_DURATION,
			"§38 a produção usa 60.0, obtido %f" % controller.preparation_duration)
	_check(controller.invasion_state() == InvasionController.InvasionState.NOT_STARTED,
			"§36 o controller abre em NOT_STARTED")
	_check(controller.preparation_time_remaining() == 0.0,
			"§36/§4 fora de preparação não há contagem parada, obtido %f"
					% controller.preparation_time_remaining())
	_check(controller.invaders().is_empty(), "§36 nenhum inimigo registrado")
	_check(not controller.is_processing(), "§79 NOT_STARTED não processa timer")
	_check(_preparation_events == 0 and _time_changed_events == 0,
			"§44 nada foi emitido antes de começar (%d/%d)"
					% [_preparation_events, _time_changed_events])

	_check(controller.begin_preparation(), "§6/§8 a primeira preparação abre")
	_check(controller.invasion_state() == InvasionController.InvasionState.PREPARATION,
			"§2/§37 o Ninho/atalho abre PREPARATION, nunca ACTIVE")
	_check(controller.preparation_time_remaining() == PRODUCTION_DURATION,
			"§4 ao iniciar, o restante é a duração cheia, obtido %f"
					% controller.preparation_time_remaining())
	_check(_preparation_events == 1,
			"§9/§44 preparation_started emitiu exatamente uma vez, obtido %d"
					% _preparation_events)
	_check(controller.is_processing(), "§79 PREPARATION liga o processamento")
	_check(_enemies_in(_rig).is_empty(),
			"§27/§41 durante a preparação não existe nenhum invasor na cena")
	_check(_close(_rig_state.integrity, INTEGRITY),
			"§28 sem inimigo em campo a Integrity continua 100, obtido %f"
					% _rig_state.integrity)

	# §45: um segundo de tela, um emit. Não duzentos por frame.
	await _advance_real(2.2)
	_check(_time_changed_events >= 1 and _time_changed_events <= 4,
			"§10/§45 em 2.2 s o sinal virou no máximo 3 vezes, obtido %d"
					% _time_changed_events)
	var decreasing := true
	for index in range(1, _countdown_trace.size()):
		if _countdown_trace[index] >= _countdown_trace[index - 1]:
			decreasing = false
	_check(decreasing, "§45 os valores emitidos decrescem sempre, %s" % [_countdown_trace])
	var elapsed := controller.preparation_duration - controller.preparation_time_remaining()
	_check(1.6 < elapsed and elapsed < 2.8,
			"§4/§39 em ~2.2 s reais o countdown andou o mesmo tanto, obtido %f" % elapsed)

	# §43: uma única emissão de largada, e §12 o clamp em zero.
	_check(controller.start_invasion(), "§12 a largada reusa o start_invasion da Tarefa 12")
	_check(_started_events == 1, "§43 invasion_started saiu uma vez, obtido %d"
			% _started_events)
	_check(controller.invasion_state() == InvasionController.InvasionState.ACTIVE,
			"§12 o zero leva a ACTIVE")
	_check(controller.preparation_time_remaining() == 0.0,
			"§4/§12 o restante fecha em 0 exato, obtido %f"
					% controller.preparation_time_remaining())
	_check(not controller.is_processing(), "§79 em ACTIVE o timer está desligado")
	var before := _time_changed_events
	await _advance_real(1.0)
	_check(_time_changed_events == before,
			"§45 depois de ACTIVE nenhum preparation_time_changed continua, %d → %d"
					% [before, _time_changed_events])
	_check(not controller.begin_preparation(),
			"§48/§49 em ACTIVE a preparação não reabre")
	_check(controller.active_invaders() == 2, "§30/T13 as duas Feras estão em campo")
	_free_isolated_rig()


func _count_clean_frames() -> bool:
	# §41 fala dos frames de preparação. O frame em que a largada já aconteceu tem as duas
	# Feras por definição — ele encerra a varredura e não entra na contagem.
	if _rig_controller == null or not is_instance_valid(_rig_controller) \
			or _rig_controller.invasion_state() \
			!= InvasionController.InvasionState.PREPARATION:
		return false
	_probe_frames += 1
	var empty := _enemies_in(_rig).is_empty()
	if empty:
		_probe_clean_frames += 1
	return empty


## §39/§41/§42/§27: a contagem inteira de uma rodada de 5 s, frame a frame, até o zero.
## Duas metades: primeiro a amostra de §39 (2 s passados, ~3 s restantes), depois o resto
## da contagem inspecionado corpo a corpo para provar que nenhum invasor existe antes do
## zero — e que exatamente dois existem no frame seguinte.
func _test_isolated_no_early_spawn() -> void:
	var controller := await _make_isolated_rig(ROUND_DURATION)
	_check(controller.begin_preparation(), "§39 a rodada de 5 s abriu")

	await _advance_real(2.0)
	var middle := controller.preparation_time_remaining()
	_check(_close(middle, 3.0, 0.4),
			"§39 em harness de 5 s, após ~2 s o restante é ~3, obtido %f" % middle)
	_check(controller.invasion_state() == InvasionController.InvasionState.PREPARATION,
			"§39/§41 a metade da rodada ainda é PREPARATION")
	_check(_enemies_in(_rig).is_empty(), "§41/§27 com 3 s restantes não há nenhuma Fera")

	# §41: o caso literal da especificação — 0.1 s restante e o mundo ainda limpo. A
	# varredura frame a frame acumula as duas janelas: do meio da rodada até o zero.
	var almost_zero := await _wait_until_real(
			func() -> bool:
				return controller.preparation_time_remaining() <= 0.15,
			20.0, _count_clean_frames)
	_check(almost_zero, "§41 a contagem chegou à faixa de 0.1 s")
	_check(controller.preparation_time_remaining() <= 0.15,
			"§41 o restante medido é <= 0.15, obtido %f"
					% controller.preparation_time_remaining())
	_check(controller.invasion_state() == InvasionController.InvasionState.PREPARATION
			and _enemies_in(_rig).is_empty(),
			"§41/§27 a um piscar do zero: PREPARATION e zero Enemy")

	var waited := await _wait_until_real(
			func() -> bool:
				return controller.invasion_state() == InvasionController.InvasionState.ACTIVE,
			20.0, _count_clean_frames)
	_check(waited, "§42/§62 o cronômetro largou a invasão sozinho")
	_check(_probe_clean_frames == _probe_frames and _probe_frames > 20,
			"§41 nenhum frame de preparação tinha inimigo (%d de %d inspecionados)"
					% [_probe_clean_frames, _probe_frames])
	_check(_started_events == 1,
			"§43 uma largada em toda a rodada, obtido %d" % _started_events)
	var invaders := _enemies_in(_rig)
	_check(invaders.size() == 2, "§42/§30 exatamente duas Feras, obtido %d" % invaders.size())
	var drift_a := invaders[0].global_position.distance_to(SPAWN_A)
	var drift_b := invaders[1].global_position.distance_to(SPAWN_B)
	_check(drift_a < BIRTH_TOLERANCE and drift_b < BIRTH_TOLERANCE,
			"§34/T13 cada Fera nasceu no seu ponto (%f, %f)" % [drift_a, drift_b])
	_check(_close(controller.preparation_time_remaining(), 0.0),
			"§4 o zero é exato no fim, obtido %f" % controller.preparation_time_remaining())
	# §45: a duração de 5 s produz ~5 segundos de tela virados, não 300 emissões.
	_check(_time_changed_events >= 5 and _time_changed_events <= 8,
			"§10/§45 cerca de um emit por segundo exibido, obtido %d" % _time_changed_events)
	_check(_preparation_events == 1, "§44 preparation_started uma única vez, %d"
			% _preparation_events)
	_free_isolated_rig()


## §8/§29/§30: uma preparação por partida. Nadinha de timer reiniciado por um sinal
## repetido, nem depois da vitória, nem depois da derrota.
func _test_isolated_second_preparation() -> void:
	var controller := await _make_isolated_rig(3.0)
	_preparation_events = 0
	_check(controller.begin_preparation(), "§8 a primeira abertura passou")
	var first := controller.preparation_time_remaining()
	await _advance_real(0.6)
	_check(not controller.begin_preparation(),
			"§8 em PREPARATION uma segunda chamada não abre nada")
	var after := controller.preparation_time_remaining()
	_check(after < first and after > 0.0,
			"§8/§15 o timer não reiniciou: %f → %f" % [first, after])
	_check(_preparation_events == 1,
			"§8/§44 preparation_started não reemitiu, obtido %d" % _preparation_events)
	var waited := await _wait_until_real(
			func() -> bool:
				return controller.invasion_state() == InvasionController.InvasionState.ACTIVE,
			20.0)
	_check(waited, "§8/§42 a rodada terminou em ACTIVE")
	_check(not controller.begin_preparation(), "§29 depois da largada não há preparação")
	# §29/§30: o desfecho também não reabre nada — aqui a derrota, matando o Núcleo.
	_rig_state.damage(999.0)
	await _advance_real(0.2)
	_check(controller.invasion_state() == InvasionController.InvasionState.DEFEAT,
			"§30/T13 a derrota da Tarefa 12 continua valendo")
	_check(not controller.begin_preparation(), "§30 depois de DEFEAT nada reinicia")
	_check(controller.preparation_time_remaining() == 0.0,
			"§30 o restante continua 0, obtido %f" % controller.preparation_time_remaining())
	_check(_preparation_events == 1,
			"§29/§30 um único preparation_started para sempre, %d" % _preparation_events)
	_free_isolated_rig()


## §81: o countdown anda em tempo real e o combate continua em física. As duas coisas
## têm de conviver: enquanto o cronômetro cai 2 s, uma Fera da Tarefa 12 anda os seus
## 2.5 m/s de sempre, sem ter migrado para _process.
func _test_countdown_is_real_time() -> void:
	var controller := await _make_isolated_rig(PRODUCTION_DURATION)
	_check(controller.begin_preparation(), "§81 a preparação abriu")
	var started := Engine.get_physics_frames()
	await _advance_real(2.0)
	var seconds := controller.preparation_duration - controller.preparation_time_remaining()
	var measured := _physics_seconds_since(started)
	_check(_close(seconds, measured, 0.15),
			"§81 o countdown e a física andam no mesmo relógio (%f vs %f)"
					% [seconds, measured])
	var code := _code_of(INVASION_CONTROLLER_SOURCE_PATH)
	_check(not code.contains("func _physics_process("),
			"§81 o timer não migrou para a física")
	_free_isolated_rig()


## §40/§5/§81: mesma duração real em 30 Hz e 120 Hz. Um Timer de um segundo ou uma
## cadeia de awaits daria números diferentes; delta dá o mesmo.
func _test_countdown_at_30_and_120_hz() -> void:
	var at_30 := await _countdown_sample_isolated(30, 2.0)
	var at_120 := await _countdown_sample_isolated(120, 2.0)
	Engine.set_physics_ticks_per_second(TICKS)
	await _advance_real(0.2)
	_check(at_30["elapsed"] > 1.7 and at_120["elapsed"] > 1.7,
			"§40 as duas amostras cobriram ~2 s reais (%f / %f)"
					% [at_30["elapsed"], at_120["elapsed"]])
	_check(at_30["frames"] < at_120["frames"] / 2,
			"§40 as duas taxas não andaram o mesmo número de frames (%d vs %d)"
					% [at_30["frames"], at_120["frames"]])
	_check(_close(at_30["drain"], at_120["drain"], 0.2),
			"§40 a contagem por delta é igual a 30 Hz e 120 Hz (%f vs %f)"
					% [at_30["drain"], at_120["drain"]])
	_check(absf(at_30["drain"] - at_30["elapsed"]) < 0.15
			and absf(at_120["drain"] - at_120["elapsed"]) < 0.15,
			"§5/§40 o que o countdown perdeu é o tempo real que passou "
					+ "(%f/%f e %f/%f)"
					% [at_30["drain"], at_30["elapsed"], at_120["drain"], at_120["elapsed"]])
	_measurements["drain_30"] = at_30["drain"]
	_measurements["drain_120"] = at_120["drain"]
	_measurements["frames_30"] = at_30["frames"]
	_measurements["frames_120"] = at_120["frames"]


## Uma amostra isolada: monta o rig, abre a preparação com taxa de física `ticks`, e
## mede quanto o countdown perdeu em ~`seconds` de tempo real.
func _countdown_sample_isolated(ticks: int, seconds: float) -> Dictionary:
	var controller := await _make_isolated_rig(PRODUCTION_DURATION)
	Engine.set_physics_ticks_per_second(ticks)
	_check(controller.begin_preparation(), "§40 a preparação da amostra abriu")
	var started_ticks := Engine.get_physics_frames()
	var started_ms := Time.get_ticks_msec()
	await _advance_real(seconds)
	var elapsed := float(Time.get_ticks_msec() - started_ms) / 1000.0
	var result := {
		"drain": PRODUCTION_DURATION - controller.preparation_time_remaining(),
		"elapsed": elapsed,
		"frames": Engine.get_physics_frames() - started_ticks,
	}
	_free_isolated_rig()
	return result


## §14/§46: a tecla F é atalho de preparação — ela abre o aviso, não a invasão.
func _test_isolated_f_key() -> void:
	var controller := await _make_isolated_rig(ROUND_DURATION)
	_press_key(KEY_F)
	await _advance_real(0.1)
	_check(controller.invasion_state() == InvasionController.InvasionState.PREPARATION,
			"§14/§46 F em NOT_STARTED abre PREPARATION")
	_check(_enemies_in(_rig).is_empty(), "§46 F nenhum ainda cria Fera alguma")
	_check(_started_events == 0, "§14 F sozinho não emite invasion_started, %d"
			% _started_events)
	_check(controller.preparation_time_remaining() > ROUND_DURATION - 0.5,
			"§46 o F abriu com a duração cheia, obtido %f"
					% controller.preparation_time_remaining())
	_free_isolated_rig()


## §15/§16: não existe tecla de pulo. Nem em PREPARATION, nem em lugar nenhum.
func _test_isolated_no_key_skip() -> void:
	var controller := await _make_isolated_rig(ROUND_DURATION)
	controller.begin_preparation()
	await _advance_real(0.4)
	var before := controller.preparation_time_remaining()
	for _tap in 5:
		_press_key(KEY_F)
		await _advance_real(0.05)
	var after := controller.preparation_time_remaining()
	_check(after < before,
			"§15 cinco F seguidos não resetaram o timer (%f → %f)" % [before, after])
	_check(_enemies_in(_rig).is_empty(), "§15/§27 nenhum F adiantou a invasão")
	_check(_started_events == 0, "§15 nenhum F emitiu a largada")
	_check(controller.invasion_state() == InvasionController.InvasionState.PREPARATION,
			"§15 o estado continua PREPARATION")
	# §16: a única alavanca é o @export, e ela é do harness — não de um atalho.
	_check(controller.preparation_duration == ROUND_DURATION,
			"§16 a duração encurtada é o @export, obtido %f" % controller.preparation_duration)
	_free_isolated_rig()


## O painel de aviso, aberto sem GameMain: é Control puro, invisível por padrão, e não
## intercepta um clique sequer (§21/§31).
func _test_warning_scene_surface() -> void:
	var panel := WARNING_SCENE.instantiate() as Control
	_check(panel != null, "§19 a cena de aviso existe")
	_check(not panel.visible, "§31/§20 o aviso nasce escondido")
	var offenders := _controls_not_ignoring(panel)
	_check(offenders.is_empty(),
			"§21 todo Control do aviso é IGNORE na cena, %s" % [offenders])
	panel.free()


## §52/§11/§40/§74: os dois painéis ligados direto a um controller órfão, sem GameMain.
## É assim que se prova a direção da dependência — o HUD lê sinal e formata ceil(42.2)=43;
## ele não manda nada no cronômetro, e o cronômetro vive sem ele.
func _test_isolated_huds_read_ceil() -> void:
	var controller := await _make_isolated_rig(CEIL_PROBE_DURATION)
	var warning := WARNING_SCENE.instantiate() as InvasionWarningHud
	var status := INVASION_HUD_SCENE.instantiate() as InvasionDebugHud
	root.add_child(warning)
	root.add_child(status)
	await process_frame
	warning.bind(controller)
	status.bind(controller)
	await process_frame
	_check(not warning.visible, "§31/§51 antes da preparação o aviso está hidden")
	_check(not controller.is_processing(), "§79 o rig parado não processa timer")
	controller.begin_preparation()
	await process_frame
	_check(warning.visible, "§51/§37 com a preparação o aviso ficou visível")
	_check(_text_of(warning, "CountdownLabel") == CEIL_WARNING_LINE,
			"§52 o aviso mostra 43 para 42.2 s, obtido %s"
					% _text_of(warning, "CountdownLabel"))
	_check(_text_of(status, "StatusLabel") == CEIL_STATUS_LINE,
			"§52 o painel de status mostra 43 para 42.2 s, obtido %s"
					% _text_of(status, "StatusLabel"))
	_check(_text_of(warning, "TitleLabel") == WARNING_TITLE,
			"§19 o título do aviso é \"%s\", obtido %s"
					% [WARNING_TITLE, _text_of(warning, "TitleLabel")])
	# §74: nenhum dos dois painéis tem poder sobre o ciclo. A largada é do controller.
	_check(controller.start_invasion(), "§74 a largada aconteceu com os HUDs pendurados")
	await process_frame
	_check(not warning.visible, "§70/§51 no instante da largada o aviso saiu da tela")
	_check(_text_of(status, "StatusLabel") == ACTIVE_STATUS,
			"§71/§40 o painel reagiu ao signal, obtido %s"
					% _text_of(status, "StatusLabel"))
	_check(_text_of(status, "HintLabel") == HINT_LINE,
			"§17 a dica voltou depois do aviso, obtido %s"
					% _text_of(status, "HintLabel"))
	root.remove_child(warning)
	warning.free()
	root.remove_child(status)
	status.free()
	_free_isolated_rig()


# ============================================================== Bloco 2 — Cena A


func _test_boot_state() -> void:
	_check(_invasion.preparation_duration == PRODUCTION_DURATION,
			"§38 a cena de produção abre com 60.0, obtido %f"
					% _invasion.preparation_duration)
	_check(_invasion.invasion_state() == InvasionController.InvasionState.NOT_STARTED,
			"§36/§31 a partida abre em NOT_STARTED")
	_check(_invasion.preparation_time_remaining() == 0.0, "§36 o restante abre em 0")
	_check(_enemies_in_scene().is_empty(), "§31 nenhum Enemy no início")
	_check(not _warning_hud.visible, "§31/§36 o warning começa hidden")
	_check(_close(_core_state.integrity, INTEGRITY), "§68 a Integrity abre em 100")
	_check(_core_state.get_population_capacity() == CAPACITY_BASE,
			"§72 a capacidade abre em 8, obtido %d" % _core_state.get_population_capacity())
	_check(_text_of(_invasion_hud, "HintLabel") == HINT_LINE,
			"§17 a dica continua \"%s\", obtido %s"
					% [HINT_LINE, _text_of(_invasion_hud, "HintLabel")])
	_check(_text_of(_invasion_hud, "StatusLabel") == WAITING_STATUS,
			"§17 o status inicial é \"%s\", obtido %s"
					% [WAITING_STATUS, _text_of(_invasion_hud, "StatusLabel")])
	_check(_text_of(_invasion_hud, "RemainingLabel") == "", "§69 sem inimigos, sem contagem")
	_status_trace.append(_text_of(_invasion_hud, "StatusLabel"))
	var offenders := _controls_not_ignoring(_scene.get_node("UI"))
	_check(offenders.is_empty(),
			"§21/§53 nenhum Control da UI inteira intercepta mouse, %s" % [offenders])


## O prólogo de campanha usado pela Cena A e pela Cena C: chama o segundo Worker, esgota
## a primeira rocha, paga e constrói o Ninho com os dois Workers cooperando. Termina no
## instante em que o Ninho conclui — que é exatamente o gatilho da preparação (§32).
func _build_nest_cooperatively() -> bool:
	_set_essence(20.0)
	_press_key(KEY_I)
	await _advance(0.4)
	_worker2 = _workers_in_scene()[1] if _workers_in_scene().size() == 2 else null
	_check(_worker2 != null, "§62 o segundo Worker chegou para a campanha")
	await _mine_with_two_workers(_rock_with_id(FIRST_ORE_ROCK_ID))
	_check(_stockpile.get_amount(ORE) == 3,
			"§62 a primeira rocha pagou o Ninho, obtido %d" % _stockpile.get_amount(ORE))
	_measurements["essence_before_nest"] = _core_state.essence
	_press_key(KEY_B)
	await _advance(0.2)
	var nest := _construction.nest()
	_check(nest != null, "§62 B abriu o canteiro do Ninho")
	if nest == null:
		return false
	_place(_worker, Vector3(NEST_POINT.x + 1.5, 0.0, NEST_POINT.z + 0.9))
	_place(_worker2, Vector3(NEST_POINT.x + 1.5, 0.0, NEST_POINT.z - 0.9))
	await _advance(0.1)
	_selection.clear_selection()
	await _click_select(_worker)
	await _shift_click_select(_worker2)
	await _right_click(nest.global_position)
	var built := await _wait_until(func() -> bool: return nest.is_completed(), 30.0)
	_check(built, "§37 os Workers construíram o Ninho de verdade")
	await _advance(0.1)
	return built


## §32/§37/§72/§73: o Ninho concluído é o gatilho. A mesma conclusão dá o bônus de
## capacidade e abre a preparação — cada uma exatamente uma vez, sem nenhum F no meio.
func _test_nest_opens_preparation() -> void:
	await _build_nest_cooperatively()

	_check(_invasion.invasion_state() == InvasionController.InvasionState.PREPARATION,
			"§6/§32/§37 o Ninho concluído abriu PREPARATION sem nenhuma tecla")
	_check(_close(_invasion.preparation_time_remaining(), PRODUCTION_DURATION, 1.0),
			"§32/§4 o timer abre com ~60 s, obtido %f"
					% _invasion.preparation_time_remaining())
	_check(_enemies_in_scene().is_empty(), "§37/§27 no instante do gatilho há 0 inimigos")
	_check(_warning_hud.visible, "§37/§51 o aviso apareceu com a preparação")
	_check(_text_of(_warning_hud, "TitleLabel") == WARNING_TITLE,
			"§19 o aviso diz \"%s\", obtido %s"
					% [WARNING_TITLE, _text_of(_warning_hud, "TitleLabel")])
	_check(_text_of(_warning_hud, "CountdownLabel").ends_with(" s"),
			"§51 o aviso mostra os segundos, obtido %s"
					% _text_of(_warning_hud, "CountdownLabel"))
	_check(_text_of(_invasion_hud, "HintLabel") == PREPARATION_ALERT,
			"§17 o painel de status virou \"%s\", obtido %s"
					% [PREPARATION_ALERT, _text_of(_invasion_hud, "HintLabel")])
	_check(_text_of(_invasion_hud, "StatusLabel").begins_with("Invasão em: "),
			"§17 a contagem está no status, obtido %s"
					% _text_of(_invasion_hud, "StatusLabel"))
	_check(_text_of(_invasion_hud, "RemainingLabel") == PREPARATION_ADVICE,
			"§17 o conselho é \"%s\", obtido %s"
					% [PREPARATION_ADVICE, _text_of(_invasion_hud, "RemainingLabel")])
	_status_trace.append(_text_of(_invasion_hud, "StatusLabel"))
	_measurements["remaining_at_nest"] = _invasion.preparation_time_remaining()

	# §72: duas consequências, cada uma uma vez só.
	_check(_core_state.get_population_capacity() == CAPACITY_WITH_NEST,
			"§72 a capacidade foi de 8 para 12, obtido %d"
					% _core_state.get_population_capacity())
	_check(_capacity_events == 1,
			"§72/§8 o bônus de capacidade aconteceu uma vez, obtido %d" % _capacity_events)
	_check(_preparation_events == 1,
			"§44 preparation_started uma emissão no gatilho, %d" % _preparation_events)
	_check(_close(_core_state.integrity, INTEGRITY),
			"§68/§28 durante a preparação a Integrity continua 100, %f"
					% _core_state.integrity)


## §22–§26, §54–§61: o countdown não é uma pausa. Tudo o que o RTS fazia antes continua
## fazendo durante, e nada do que acontece altera o timer.
func _test_gameplay_during_countdown() -> void:
	var essence_before := _core_state.essence
	await _advance(3.0)
	_check(_core_state.essence > essence_before,
			"§54 a Essência continuou gerando na preparação (%f → %f)"
					% [essence_before, _core_state.essence])
	var remaining_before := _invasion.preparation_time_remaining()
	_check(remaining_before < PRODUCTION_DURATION,
			"§39 o countdown já andou, obtido %f" % remaining_before)

	# §55: mover um Worker por clique real, com o aviso na tela.
	_selection.clear_selection()
	await _click_select(_worker)
	_check(_unit_ids() == ["worker_001"], "§55/§53 o clique pela warning selecionou o Worker")
	_place(_worker, WORKER_WALK_TARGET)
	await _advance(0.1)
	_selection.clear_selection()
	await _click_select(_worker)
	await _right_click(Vector3(WORKER_WALK_TARGET.x + 2.5, 0.0, WORKER_WALK_TARGET.z - 2.0))
	var arrived := await _wait_until(func() -> bool: return not _worker.has_move_target(), 12.0)
	_check(arrived, "§55 o Worker andou durante a preparação")
	var moved := _invasion.preparation_time_remaining()
	_check(moved < remaining_before - 1.0,
			"§55 e o timer continuou caindo enquanto ele andava (%f → %f)"
					% [remaining_before, moved])

	# §56/§57: escavar e transportar sob o aviso.
	var ore_before := _stockpile.get_amount(ORE)
	_measurements["remaining_before_ore2"] = _invasion.preparation_time_remaining()
	await _mine_with_two_workers(_rock_with_id(SECOND_ORE_ROCK_ID))
	_check(_stockpile.get_amount(ORE) == ore_before + 3,
			"§56/§57 a segunda rocha foi minerada, levada e depositada (%d → %d)"
					% [ore_before, _stockpile.get_amount(ORE)])
	_measurements["remaining_after_ore2"] = _invasion.preparation_time_remaining()
	_check(_invasion.invasion_state() == InvasionController.InvasionState.PREPARATION,
			"§56/§57 minerar não adiantou nem atrasou a invasão")
	_check(_enemies_in_scene().is_empty(), "§27/§56 ainda nenhum Enemy em campo")

	# §53: um clique atravessando o retângulo do aviso é um clique no mundo.
	_selection.clear_selection()
	await _click_select(_worker)
	var selected_before := _unit_ids().size()
	var center := _warning_screen_center()
	_press(MOUSE_BUTTON_LEFT, center)
	_release(MOUSE_BUTTON_LEFT, center)
	await _advance(0.1)
	_check(_unit_ids().is_empty(),
			"§53 o clique dentro da warning chegou ao jogo e limpo a seleção (%d → 0)"
					% selected_before)
	_check(_warning_hud.visible, "§53 a warning continua visível, sem engolir input")

	# §58/§59: o Quartel nasce, e dois Workers o constroem com o cronômetro correndo.
	var timer_before := _invasion.preparation_time_remaining()
	_set_essence(20.0)
	_press_key(KEY_K)
	await _advance(0.2)
	var barracks := _construction.barracks()
	_check(barracks != null, "§58 K criou o Quartel durante a preparação")
	if barracks == null:
		return
	_place(_worker, Vector3(BARRACKS_POINT.x + 1.5, 0.0, BARRACKS_POINT.z + 0.9))
	_place(_worker2, Vector3(BARRACKS_POINT.x + 1.5, 0.0, BARRACKS_POINT.z - 0.9))
	await _advance(0.1)
	_selection.clear_selection()
	await _click_select(_worker)
	await _shift_click_select(_worker2)
	await _right_click(barracks.global_position)
	var done := await _wait_until(func() -> bool: return barracks.is_completed(), 30.0)
	_check(done, "§59 a construção cooperativa do Quartel terminou no prazo")
	_check(_invasion.invasion_state() == InvasionController.InvasionState.PREPARATION,
			"§58/§59 construir não tocou no ciclo")
	_check(_invasion.preparation_time_remaining() < timer_before,
			"§58 o countdown não pausou nem resetou na obra (%f → %f)"
					% [timer_before, _invasion.preparation_time_remaining()])
	_measurements["remaining_after_barracks"] = _invasion.preparation_time_remaining()

	# §60/§26: recrutar é decisão do jogador e não acelera nada.
	var before_recruit := _invasion.preparation_time_remaining()
	_set_essence(20.0)
	_press_key(KEY_R)
	await _advance(0.4)
	_soldier = _recruitment.soldier()
	_check(_soldier != null, "§60 R recrutou o Soldado com o timer correndo")
	if _soldier == null:
		return
	_check(_close(_soldier.state.health, SOLDIER_HP),
			"§60 o Soldado chegou inteiro, %f" % _soldier.state.health)
	_check(_invasion.invasion_state() == InvasionController.InvasionState.PREPARATION,
			"§26 recrutar não iniciou a invasão mais cedo")
	_check(_invasion.preparation_time_remaining() < before_recruit,
			"§26 o timer seguiu o mesmo ciclo depois do recrutamento (%f → %f)"
					% [before_recruit, _invasion.preparation_time_remaining()])
	_measurements["remaining_after_soldier"] = _invasion.preparation_time_remaining()

	# §61: posicionar a defesa antes do zero.
	_selection.clear_selection()
	await _click_select(_soldier)
	await _right_click(SOLDIER_DEFENSE)
	var in_position := await _wait_until(func() -> bool: return not _soldier.has_move_target(),
			20.0)
	_check(in_position, "§61 o Soldado obedeceu à ordem defensiva durante o aviso")
	_measurements["remaining_after_position"] = _invasion.preparation_time_remaining()
	_measurements["defense_spot"] = _soldier.global_position


## §23/§62/§63: a campanha inteira cabe nos 60 s? É a medição, não a opinião.
func _test_full_preparation_campaign() -> void:
	var remaining := _invasion.preparation_time_remaining()
	_check(_invasion.invasion_state() == InvasionController.InvasionState.PREPARATION,
			"§62 a campanha inteira aconteceu dentro de PREPARATION")
	_check(remaining > 0.0,
			"§63 a preparação completa coube no prazo, sobraram %f s" % remaining)
	_check(remaining >= 10.0,
			"§63 com margem razoável (>= 10 s), obtido %f" % remaining)
	_measurements["margin"] = remaining
	print("[INFO] §63 folga medida: Ninho→Soldado posicionado deixou %f s dos 60." % remaining)
	_check(_close(_core_state.integrity, INTEGRITY),
			"§68 a campanha chegou ao zero com a Integrity intacta, %f"
					% _core_state.integrity)


## §42/§43/§68/§69/§70/§71: o momento em que o aviso vira invasão.
func _test_launch_at_zero() -> void:
	var trace_before := _countdown_trace.size()
	var last_labels: Array[String] = []
	var launched := await _wait_until_real(
			func() -> bool:
				return _invasion.invasion_state() == InvasionController.InvasionState.ACTIVE,
			120.0,
			func() -> bool:
				var label := _text_of(_invasion_hud, "StatusLabel")
				if not last_labels.has(label):
					last_labels.append(label)
					_status_trace.append(label)
				# §11: o que vale é o que esteve na tela. O texto do painel escondido não
				# é leitura de HUD — por isso a amostra só acontece com o aviso visível.
				if _warning_hud.visible:
					var countdown := _text_of(_warning_hud, "CountdownLabel")
					if not last_labels.has(countdown):
						last_labels.append(countdown)
				return false)
	_check(launched, "§42/§62 o zero chegou sozinho e a invasão começou")
	_measurements["launch_labels"] = last_labels
	_check(_countdown_trace.size() > trace_before,
			"§45 a contagem inteira foi emitida até o zero (%d → %d)"
					% [trace_before, _countdown_trace.size()])
	var seen_three := false
	var seen_two := false
	var seen_one := false
	for label in last_labels:
		if label.contains(" 3 s") or label.contains(": 3 s"):
			seen_three = true
		if label.contains(" 2 s") or label.contains(": 2 s"):
			seen_two = true
		if label.contains(" 1 s") or label.contains(": 1 s"):
			seen_one = true
	_check(seen_three and seen_two and seen_one,
			"§11/§52 o HUD passou por 3, 2 e 1 antes da largada: %s" % [last_labels])
	_check(not last_labels.has("Invasão em: 0 s") and not last_labels.has("INVASÃO EM 0 s"),
			"§11/§52 nenhum dos dois painéis mostrou um 0 enquanto esteve na tela")

	_check(_enemies_in_scene().size() == 2, "§42 exatamente 2 Enemies no zero")
	_check(_started_events == 1, "§43 invasion_started uma única vez, %d" % _started_events)
	_check(not _warning_hud.visible, "§70/§20 no mesmo instante o aviso sumiu")
	_check(_invasion.preparation_time_remaining() == 0.0, "§4 o restante fechou em 0")
	_check(not _invasion.is_processing(), "§79 ACTIVE não processa timer")
	_check(_close(_core_state.integrity, INTEGRITY, 9.99),
			"§68 a transição não resetou nem zerou a Integrity, %f" % _core_state.integrity)
	_check(_text_of(_invasion_hud, "StatusLabel") == ACTIVE_STATUS,
			"§17/§71 o status passou a \"%s\", obtido %s"
					% [ACTIVE_STATUS, _text_of(_invasion_hud, "StatusLabel")])
	_check(_text_of(_invasion_hud, "HintLabel") == HINT_LINE,
			"§17 a dica voltou ao normal depois do aviso, %s"
					% _text_of(_invasion_hud, "HintLabel"))
	_check(_remaining_trace == [2], "§69 a contagem abriu em 2, %s" % [_remaining_trace])

	# §61: o spawn não teleporta nem reseta a defesa que o jogador posicionou.
	var spot: Vector3 = _measurements["defense_spot"]
	_check(_soldier != null and _soldier.global_position.distance_to(spot) < 0.6,
			"§61 o Soldado continua no posto defensivo depois da largada (%s → %s)"
					% [str(spot), str(_soldier.global_position)])
	_check(_soldier.action_mode() == SoldierRuntime.ActionMode.IDLE,
			"§61/T12 nenhuma unidade saiu do lugar por conta própria")


## §66/§22: a defesa da Tarefa 12 continua funcionando exatamente igual.
func _test_defense_and_victory() -> void:
	var invaders := _invasion.invaders()
	_check(invaders.size() == 2, "§66 a defesa encara as duas Feras")
	_selection.clear_selection()
	await _click_select(_soldier)
	await _right_click(_body_screen_position(invaders[0].global_position))
	await _advance(0.05)
	_check(invaders[0].action_mode() == EnemyRuntime.ActionMode.COMBAT,
			"§66/T12 o Invader001 parou no duelo")
	var first_id := invaders[0].get_instance_id()
	var first_died := await _wait_until(
			func() -> bool: return not is_instance_id_valid(first_id), 40.0)
	_check(first_died and _remaining_trace.back() == 1,
			"§66/§69 o primeiro caiu e a contagem foi para 1, %s" % [_remaining_trace])
	await _right_click(_body_screen_position(invaders[1].global_position))
	await _advance(0.05)
	var second_id := invaders[1].get_instance_id()
	var second_died := await _wait_until(
			func() -> bool: return not is_instance_id_valid(second_id), 40.0)
	_check(second_died, "§66 o Invader002 também caiu")
	_check(_invasion.invasion_state() == InvasionController.InvasionState.VICTORY,
			"§66 a vitória continua sendo a da Tarefa 12")
	_check(_victory_events == 1, "§66/§43 victory uma vez, %d" % _victory_events)
	_check(_text_of(_invasion_hud, "StatusLabel") == VICTORY_STATUS,
			"§71/§17 o status fechou em \"%s\", obtido %s"
					% [VICTORY_STATUS, _text_of(_invasion_hud, "StatusLabel")])
	_status_trace.append(_text_of(_invasion_hud, "StatusLabel"))
	_check(not _warning_hud.visible, "§70 o aviso não voltou para a vitória")
	_check(_core_state.integrity > 0.0,
			"§66/§68 o Núcleo sobreviveu à defesa preparada, %f" % _core_state.integrity)
	_measurements["victory_integrity"] = _core_state.integrity
	_measurements["victory_soldier_hp"] = _soldier.state.health
	print("[INFO] §66 defesa com preparação: Integrity %f, Soldado %f HP."
			% [_core_state.integrity, _soldier.state.health])


## §29/§49/§30: depois do desfecho, o ciclo está fechado. Nada reabre, nada reinicia.
func _test_nothing_after_victory() -> void:
	_press_key(KEY_F)
	await _advance(0.2)
	_check(_invasion.invasion_state() == InvasionController.InvasionState.VICTORY,
			"§49/§29 F depois da vitória não tem efeito nenhum")
	_check(_enemies_in_scene().is_empty(), "§29/§66 não nasceu segunda invasão")
	_check(_started_events == 1, "§43/§29 invasion_started continua em 1, %d" % _started_events)
	_check(not _warning_hud.visible, "§20 depois da vitória o aviso continua hidden")
	_check(_invasion.preparation_time_remaining() == 0.0,
			"§29 o timer não reiniciou, %f" % _invasion.preparation_time_remaining())


# ======================================================== Bloco 3 — Cenas B e C


## §46: sem Ninho, sem nada — o F sozinho abre o aviso, e só o aviso.
func _test_f_opens_preparation() -> void:
	_invasion.preparation_duration = ROUND_DURATION
	_check(_invasion.invasion_state() == InvasionController.InvasionState.NOT_STARTED,
			"§46 a cena B abre sem preparação")
	_check(not _warning_hud.visible, "§51 antes do aviso, aviso hidden")
	_press_key(KEY_F)
	await _advance(0.1)
	_check(_invasion.invasion_state() == InvasionController.InvasionState.PREPARATION,
			"§46/§14 NOT_STARTED → PREPARATION pelo F real")
	_check(_enemies_in_scene().is_empty(), "§46 nenhum Enemy ainda")
	_check(_warning_hud.visible, "§51 o aviso ficou visível com o F")
	_check(_preparation_events == 1, "§44 um preparation_started, %d" % _preparation_events)
	_check(_close(_invasion.preparation_time_remaining(), ROUND_DURATION, 0.2),
			"§16 o harness encurtou pelo @export, obtido %f"
					% _invasion.preparation_time_remaining())


## §47: F dentro da preparação não pula, não reseta, não atrasa.
func _test_f_does_not_skip_or_reset() -> void:
	var before := _invasion.preparation_time_remaining()
	_press_key(KEY_F)
	await _advance(0.1)
	var after := _invasion.preparation_time_remaining()
	_check(_invasion.invasion_state() == InvasionController.InvasionState.PREPARATION,
			"§47 o estado continua PREPARATION")
	_check(after < before,
			"§47/§15 o timer não resetou (%f → %f)" % [before, after])
	_check(_enemies_in_scene().is_empty(), "§47/§27 o F não adiantou a largada")
	_check(_preparation_events == 1, "§47 nada reemitiu preparation_started, %d"
			% _preparation_events)
	_check(_started_events == 0, "§47/§43 nenhuma largada ainda")


## §48/§49 em cena: a invasão larga, o F perde o efeito, e o desfecho não reabre nada.
func _test_f_after_launch_and_end() -> void:
	var launched := await _wait_until(
			func() -> bool: return _invasion.invasion_state() == InvasionController.InvasionState.ACTIVE, 20.0)
	_check(launched, "§42 a cena B chegou a ACTIVE pelo cronômetro")
	var remaining := _invasion.preparation_time_remaining()
	_press_key(KEY_F)
	await _advance(0.1)
	_check(_invasion.invasion_state() == InvasionController.InvasionState.ACTIVE and remaining == 0.0,
			"§48 F em ACTIVE não tem efeito nenhum")
	_check(_invasion.invaders().size() == 2, "§48/§30 continuam as duas Feras")
	_check(_started_events == 1, "§43/§48 uma única emissão de largada, %d" % _started_events)
	# Fecha o ciclo: sem defesa nenhuma aqui, o Núcleo cai e a vitória fica impossível.
	for enemy in _invasion.invaders():
		enemy.receive_damage(BEAST_HP * 2.0)
	await _advance(0.2)
	_check(_invasion.invasion_state() == InvasionController.InvasionState.VICTORY,
			"§49 a cena B venceu para poder testar o F depois da vitória")
	_press_key(KEY_F)
	await _advance(0.1)
	_check(_invasion.invasion_state() == InvasionController.InvasionState.VICTORY,
			"§49 F depois da VICTORY continua sem efeito")
	_check(_enemies_in_scene().is_empty() and _started_events == 1,
			"§49/§29 nada de segunda invasão, contagem de largadas %d" % _started_events)


## §65/§67/§50/§64: o jogador que preparou o Ninho e depois não fez mais nada. O gatilho
## é o mesmo Ninho da Cena A, o cronômetro corre do mesmo jeito, e o covil sem Soldado
## cai — a derrota da Tarefa 12 preservada, com o F depois dela sem efeito nenhum.
## A duração aqui é o @export encurtado (§16); nenhuma tecla de pulo existe na produção.
func _test_unprepared_defeat() -> void:
	_invasion.preparation_duration = NO_PREP_DURATION
	_measurements["no_prep_duration"] = NO_PREP_DURATION
	# §71: a régua da experiência começa no "aguardando ameaça" desta cena recém-aberta.
	_status_trace.append(_text_of(_invasion_hud, "StatusLabel"))
	await _build_nest_cooperatively()
	var started := Engine.get_physics_frames()

	_check(_invasion.invasion_state() == InvasionController.InvasionState.PREPARATION,
			"§65/§32 o Ninho abriu a preparação nesta cena")
	_check(_warning_hud.visible, "§51 o aviso está na tela da cena C")
	_status_trace.append(_text_of(_invasion_hud, "StatusLabel"))

	var invaded := await _wait_until(
			func() -> bool:
				return _invasion.invasion_state() == InvasionController.InvasionState.ACTIVE,
			20.0)
	var waited := _physics_seconds_since(started)
	_check(invaded, "§65 sem mais nenhuma ação do jogador a invasão começa")
	_check(NO_PREP_DURATION - 0.8 < waited and waited < NO_PREP_DURATION + 1.2,
			"§65 o prazo foi o configurado, em segundos medidos %f" % waited)
	_check(_invasion.invaders().size() == 2, "§67 duas Feras contra um covil indefeso")
	_check(not _warning_hud.visible, "§70 o aviso saiu da tela na largada")
	_check(_close(_core_state.integrity, INTEGRITY),
			"§68 a Integrity não mudou na transição, %f" % _core_state.integrity)
	# §71: o terceiro quadro da sequência é a invasão em si, lido no instante da largada.
	_status_trace.append(_text_of(_invasion_hud, "StatusLabel"))

	# §64: até aqui o jogador só chamou um Worker e construiu o Ninho. Nada mais a
	# produção fez sozinha enquanto o cronômetro corria e nem depois da largada.
	_check(_construction.barracks() == null and _recruitment.soldier() == null,
			"§64/§65 nenhum Quartel nem Soldado apareceu sem ordem do jogador")
	_check(_stockpile.get_amount(ORE) == 0,
			"§64 os Workers não mineraram a segunda rocha sozinhos, %d no depósito"
					% _stockpile.get_amount(ORE))

	var destroyed := await _wait_until(func() -> bool: return _core_state.is_destroyed(), 60.0)
	_check(destroyed, "§67/§79 sem defesa o Núcleo cai a zero")
	_check(_invasion.invasion_state() == InvasionController.InvasionState.DEFEAT,
			"§67 a derrota da Tarefa 12 continua a mesma")
	_check(_defeat_events == 1, "§67 invasion_defeat uma vez, %d" % _defeat_events)
	_check(_text_of(_invasion_hud, "StatusLabel") == DEFEAT_STATUS,
			"§71 o status fechou em \"%s\", obtido %s"
					% [DEFEAT_STATUS, _text_of(_invasion_hud, "StatusLabel")])
	_status_trace.append(_text_of(_invasion_hud, "StatusLabel"))
	_check(not _warning_hud.visible, "§20 na derrota o aviso está hidden")
	_press_key(KEY_F)
	await _advance(0.2)
	_check(_invasion.invasion_state() == InvasionController.InvasionState.DEFEAT,
			"§50 F depois de DEFEAT não tem efeito nenhum")
	_check(_started_events == 1 and _preparation_events == 1,
			"§50/§30 nada reiniciou o ciclo (%d/%d)" % [_started_events, _preparation_events])
	# §71: a sequência do painel, do começo ao fim, na ordem exata da experiência.
	var sequence := _status_sequence()
	_check(sequence == ["aguardando", "preparação", "invasão", "derrota"],
			"§71 a sequência medida foi %s" % [sequence])


# ==================================================================== Infraestrutura


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
	_deposit = _scene.get_node("World/DungeonRoot/Deposit001") as ResourceDepositRuntime
	_core = _scene.get_node("World/DungeonRoot/MainCore") as CoreRuntime
	_worker = _scene.get_node("World/DungeonRoot/Worker001") as WorkerRuntime
	_invasion_hud = _scene.get_node("UI/InvasionDebugPanel")
	_warning_hud = _scene.get_node("UI/InvasionWarningPanel")
	_stockpile = _deposit.stockpile
	_core_state = _core.core_state()
	# Diferente da suíte da Tarefa 12: aqui a Essência tem de continuar sendo gerada,
	# porque §54 mede exatamente isso durante o countdown.
	_started_events = 0
	_victory_events = 0
	_defeat_events = 0
	_preparation_events = 0
	_time_changed_events = 0
	_capacity_events = 0
	_remaining_trace.clear()
	_countdown_trace.clear()
	_status_trace.clear()
	_soldier = null
	_worker2 = null
	Engine.set_physics_ticks_per_second(TICKS)
	_invasion.preparation_started.connect(_on_preparation_started)
	_invasion.preparation_time_changed.connect(_on_preparation_time_changed)
	_invasion.invasion_started.connect(_on_invasion_started)
	_invasion.invasion_victory.connect(_on_invasion_victory)
	_invasion.invasion_defeat.connect(_on_invasion_defeat)
	_invasion.active_invaders_changed.connect(_on_active_invaders_changed)
	# §72: o bônus de capacidade do Ninho é uma consequência própria, contada à parte.
	_core_state.population_capacity_changed.connect(_on_population_capacity_changed)


func _on_invasion_victory() -> void:
	_victory_events += 1


func _on_invasion_defeat() -> void:
	_defeat_events += 1


func _on_active_invaders_changed(current: int) -> void:
	_remaining_trace.append(current)


func _on_population_capacity_changed(_current: int, _capacity: int) -> void:
	_capacity_events += 1


func _free_scene() -> void:
	_soldier = null
	_worker2 = null
	if _scene != null and is_instance_valid(_scene):
		_scene.free()
	_scene = null
	_dungeon = null
	_camera = null
	_selection = null
	_construction = null
	_recruitment = null
	_invasion = null
	_deposit = null
	_core = null
	_core_state = null
	_stockpile = null
	_invasion_hud = null
	_warning_hud = null
	_worker = null


func _status_sequence() -> Array[String]:
	## §71 pede a sequência de telas: aguardando → preparação → invasão → desfecho.
	## Os status carregam o prefixo "Status: " e a contagem é "Invasão em: N s".
	var out: Array[String] = []
	for entry in _status_trace:
		if entry == WAITING_STATUS:
			out.append("aguardando")
		elif entry.begins_with("Invasão em: "):
			if out.is_empty() or out.back() != "preparação":
				out.append("preparação")
		elif entry == ACTIVE_STATUS:
			out.append("invasão")
		elif entry == VICTORY_STATUS:
			out.append("vitória")
		elif entry == DEFEAT_STATUS:
			out.append("derrota")
	return out


func _warning_screen_center() -> Vector2:
	var size := _camera.get_viewport().get_visible_rect().size
	# O painel está ancorado no topo/centro: o meio geométrico dele é dentro do painel.
	return Vector2(size.x * 0.5, 58.0)


func _enemies_in(container: Node) -> Array[EnemyRuntime]:
	var found: Array[EnemyRuntime] = []
	if container == null or not is_instance_valid(container):
		return found
	for child in container.find_children("*", "EnemyRuntime", true, false):
		var enemy := child as EnemyRuntime
		if enemy != null and not enemy.is_queued_for_deletion():
			found.append(enemy)
	return found


func _enemies_in_scene() -> Array[EnemyRuntime]:
	return _enemies_in(_dungeon)


func _workers_in_scene() -> Array[WorkerRuntime]:
	var found: Array[WorkerRuntime] = []
	for child in _dungeon.get_children():
		if child is WorkerRuntime and not child.is_queued_for_deletion():
			found.append(child as WorkerRuntime)
	return found


func _rock_with_id(id: String) -> RockRuntime:
	for child in _dungeon.get_children():
		if child is RockRuntime and (child as RockRuntime).rock_id == id:
			return child as RockRuntime
	return null


func _rock_present(id: String) -> bool:
	for child in _dungeon.get_children():
		if child is RockRuntime and (child as RockRuntime).rock_id == id \
				and not child.is_queued_for_deletion():
			return true
	return false


func _piles_in_scene() -> Array[ResourcePileRuntime]:
	var found: Array[ResourcePileRuntime] = []
	for child in _dungeon.get_children():
		if child is ResourcePileRuntime and not child.is_queued_for_deletion():
			found.append(child as ResourcePileRuntime)
	return found


func _wait_for_pile(max_seconds: float) -> ResourcePileRuntime:
	var found := await _wait_until(func() -> bool: return _find_pile() != null, max_seconds)
	return _find_pile() if found else null


func _find_pile() -> ResourcePileRuntime:
	var piles := _piles_in_scene()
	return piles[0] if piles.size() == 1 else null


func _total_cargo() -> int:
	var total := 0
	for worker in _workers_in_scene():
		total += worker.state.carried_amount
	return total


func _unit_ids() -> Array[String]:
	var ids: Array[String] = []
	for unit in _selection.selected_units:
		ids.append(unit.get_unit_id())
	return ids


func _iron_ore() -> ResourceDefinition:
	return load(IRON_ORE_PATH) as ResourceDefinition


func _set_essence(value: float) -> void:
	var difference := value - _core_state.essence
	if difference > 0.0:
		_core_state.add_essence(difference)
	elif difference < 0.0:
		_core_state.consume_essence(-difference)


## Um turno completo de mineração, igual ao da suíte anterior: esgotar a rocha, coletar
## a pilha e entregar no depósito — tudo sob o cronômetro rodando.
func _mine_with_two_workers(rock: RockRuntime) -> void:
	if rock == null:
		_check(false, "§62 a rocha de minério da campanha não foi encontrada")
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
	var depleted := await _wait_until(func() -> bool: return not _rock_present(rock_id), 40.0)
	_check(depleted, "§56 a rocha %s foi esgotada pelos dois Workers" % rock_id)
	var pile := await _wait_for_pile(6.0)
	_check(pile != null, "§57 a rocha %s virou uma pilha" % rock_id)
	if pile == null:
		return
	await _right_click(pile.global_position)
	var loaded := await _wait_until(func() -> bool: return _total_cargo() == 3, 25.0)
	_check(loaded, "§57 os Workers encheram a carga de 3, obtido %d" % _total_cargo())
	var delivered := await _wait_until(func() -> bool: return _total_cargo() == 0, 40.0)
	_check(delivered, "§57 a carga chegou ao depósito")


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


## A Fera tem 0.8 de altura: o meio do corpo fica a 0.4.
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


## Frames de física: a régua do mundo simulado (movimento, combate, cadência de golpe).
func _advance(seconds: float) -> void:
	var ticks := int(ceil(seconds * Engine.get_physics_ticks_per_second()))
	for _tick in maxi(ticks, 1):
		await physics_frame


## Tempo real: a régua do countdown, que anda por _process(delta). Usar a outra régua
## aqui seria justamente o erro que §40/§81 querem pegar. O teto de 90 s só existe para
## uma falha de hardware nunca pendurar a suíte inteira.
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


## Espera em tempo real, com uma sonda opcional executada a cada frame — é assim que
## §41 inspeciona "nenhum inimigo antes do zero" frame a frame.
func _wait_until_real(
		condition: Callable, max_seconds: float, probe: Callable = Callable()) -> bool:
	var limit := int(max_seconds * 1000.0) + 4000
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < limit:
		if probe.is_valid():
			probe.call()
		if condition.call():
			return true
		await process_frame
	return condition.call()


func _physics_seconds_since(started_at: int) -> float:
	return float(Engine.get_physics_frames() - started_at) \
			/ float(Engine.get_physics_ticks_per_second())


func _text_of(root_node: Node, label_name: String) -> String:
	var label := root_node.find_child(label_name, true, false) as Label
	if label == null:
		return "<ausente>"
	return label.text


func _controls_not_ignoring(node: Node) -> Array[String]:
	var offenders: Array[String] = []
	for child in node.find_children("*", "Control", true, false):
		var control := child as Control
		if control.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			offenders.append(String(control.name))
	return offenders


## Fonte sem os comentários: uma varredura de "proibido" deve acusar código, nunca a
## prosa que documenta justamente a ausência daquele código.
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
		if _source(path).contains(needle):
			offenders.append(path)
	return offenders


func _close(a: float, b: float, tolerance := 0.001) -> bool:
	return absf(a - b) <= tolerance


func _planar_gap(from: Vector3, to: Vector3) -> float:
	var offset := to - from
	offset.y = 0.0
	return offset.length()


func _print_measurements() -> void:
	print("[INFO] medições da preparação: %s" % [_measurements])


func _check(condition: bool, label: String) -> void:
	_asserts += 1
	if condition:
		print("[PASS] %s" % label)
	else:
		_failures += 1
		print("[FAIL] %s" % label)


func _finish() -> void:
	print("---- invasion preparation tests finished: %d asserts, %d failure(s) ----"
			% [_asserts, _failures])
	quit(1 if _failures > 0 else 0)
