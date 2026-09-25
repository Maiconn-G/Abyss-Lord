extends SceneTree

# Tarefa 12 — Primeira Invasão Inimiga e Defesa do Núcleo.
#
# A suíte dirige o GameMain real: a partida abre sem nenhum inimigo (§32), F entra
# pelo InputMap (§26/§65), o InvasionController cria exatamente duas Feras Cavernosas
# (§30), cada uma marcha sozinha até o Núcleo (§11/§12) e só para quando o Soldado a
# intercepta (§17) ou quando o Core cai a zero (§22). Nenhuma busca global, nenhum
# manager genérico: as ordens continuam entrando pelo ray de seleção da Tarefa 11.
#
# §14/§16 da Tarefa 13 mudaram a porta de entrada: o F agora abre a PREPARATION e a
# largada acontece quando o cronômetro zera. Esta suíte mede a invasão em si, então o
# harness encurta preparation_duration (exatamente o que §16 permite) e espera o estado
# ACTIVE. Nenhum assert foi removido: o que mudou foi só o instante da largada.

const MAIN_SCENE := preload("res://game/GameMain.tscn")
const ENEMY_SCENE := preload("res://units/enemies/EnemyRuntime.tscn")
const CORE_SCENE := preload("res://world/dungeon/core/CoreRuntime.tscn")

const ENEMY_DEFINITION_PATH := "res://data/units/enemies/cave_beast.tres"
const CORE_DEFINITION_PATH := "res://data/core/core_level_1.tres"
const IRON_ORE_PATH := "res://data/resources/iron_ore.tres"

const ENEMY_RUNTIME_SOURCE_PATH := "res://units/enemies/enemy_runtime.gd"
const ENEMY_DEFINITION_SOURCE_PATH := "res://core/definitions/enemy_definition.gd"
const CORE_STATE_SOURCE_PATH := "res://core/state/core_state.gd"
const CORE_RUNTIME_SOURCE_PATH := "res://world/dungeon/core/core_runtime.gd"
const CORE_HUD_SOURCE_PATH := "res://ui/hud/core_debug_hud.gd"
const INVASION_CONTROLLER_SOURCE_PATH := "res://systems/combat/invasion_controller.gd"
const INVASION_HUD_SOURCE_PATH := "res://ui/hud/invasion_debug_hud.gd"
const INVASION_WARNING_HUD_SOURCE_PATH := "res://ui/hud/invasion_warning_hud.gd"
const INVASION_WARNING_SCENE_PATH := "res://ui/hud/InvasionWarningHud.tscn"
const GAME_MAIN_SOURCE_PATH := "res://game/game_main.gd"
const SELECTION_SOURCE_PATH := "res://systems/selection/selection_controller.gd"
const SOLDIER_RUNTIME_SOURCE_PATH := "res://units/soldiers/soldier_runtime.gd"
const PROJECT_SETTINGS_PATH := "res://project.godot"

const GROUND_LAYER := 1
const UNIT_LAYER := 2
const DIGGABLE_LAYER := 4
const RESOURCE_LAYER := 8
const CONSTRUCTION_LAYER := 16
const ENEMY_LAYER := 32
const OBSTACLES := DIGGABLE_LAYER | RESOURCE_LAYER | CONSTRUCTION_LAYER

const SPAWN_A := Vector3(-4, 0, 10)
const SPAWN_B := Vector3(11, 0, 0)
const CORE_PLANAR := Vector3.ZERO
## Postura de teste: um pouco dentro dos 1.5 de postura, para medir o golpe sem que o
## invasor precise gastar um frame corrigindo o último centímetro.
const PROBE_STANCE := Vector3(0, 0, 1.45)
const PROBE_TWIN_LEFT := Vector3(-0.6, 0, 1.3)
const PROBE_TWIN_RIGHT := Vector3(0.6, 0, 1.3)
## A câmera olha de (0, 14.1, 14.1) na diagonal descendente, então um Soldado parado
## entre a câmera e a Fera engoliria o raio do clique. O posto de ataque fica a 2.6 de
## lado para que a ordem entre pela mira real, não por sorte de geometria.
const SOLDIER_STANCE := Vector3(2.6, 0, 2.6)
const SOLDIER_INTERCEPT := Vector3(-2, 0, 6.5)
const NEST_POINT := Vector3(-5, 0, -5)
const BARRACKS_POINT := Vector3(-10, 0, -5)
const DEPOSIT_POINT := Vector3(-2, 0, 0)
const CANCEL_WALK := Vector3(-12, 0, 8)
const MID_ROUTE_A := Vector3(-2, 0, 5)
const BUILDING_PROBE := Vector3(-5, 0, -2.2)
const PASSIVE_PROBE_SPOT := Vector3(-3, 0, -12)

const FIRST_ORE_ROCK_ID := "iron_ore_001"
const SECOND_ORE_ROCK_ID := "iron_ore_002"

const BEAST_HP := 48.0
const BEAST_DAMAGE := 6.0
const BEAST_RANGE := 1.2
const BEAST_INTERVAL := 1.0
const BEAST_SPEED := 2.5
const BEAST_RADIUS := 0.6
const CORE_COMBAT_RADIUS := 0.8
const BODY_CLEARANCE := 0.1
const SOLDIER_HP := 80.0
const SOLDIER_RADIUS := 0.42
const ROCK_HALF := 1.0
const BUILD_HALF := 1.1
const DEPOSIT_HALF := 0.6
const BARRACKS_WORK := 6.0
const NEST_WORK := 4.0
const ORE := &"iron_ore"

## Geometria da aproximação: distância de cada ponto de largada até o Núcleo.
const SPAWN_A_DISTANCE := 10.7703
const SPAWN_B_DISTANCE := 11.0
## 0.8 do Núcleo + 0.6 do corpo da Fera + 0.1 de folga (§14).
const STANCE := 1.5
const INTEGRITY := 100.0
const TICKS := 60

const HINT_LINE := "[F] Iniciar primeira invasão"
## §17/T13: a linha de espera passou a nomear o que se espera.
const WAITING_STATUS := "Status: aguardando ameaça"
const ACTIVE_STATUS := "Status: INVASÃO"
## §17/T13: as três linhas que o painel de status vira durante a preparação.
const PREPARATION_ALERT := "AMEAÇA DETECTADA"
const PREPARATION_COUNTDOWN_PREFIX := "Invasão em: "
const PREPARATION_ADVICE := "Prepare suas defesas."
const VICTORY_STATUS := "Status: VITÓRIA"
const DEFEAT_STATUS := "Status: DERROTA"
const NO_ENEMY_LINE := "Sem inimigo em campo"
const BEAST_LINE_FULL := "Fera Cavernosa: 48 / 48 HP"
const REMAINING_TWO := "Inimigos restantes: 2"
const REMAINING_ONE := "Inimigos restantes: 1"
const REMAINING_ZERO := "Inimigos restantes: 0"
## §16/T13: é o harness que encurta o aviso de 60 s — nunca uma tecla de produção.
const HARNESS_PREPARATION := 0.02
## §32/T13: o Ninho agora abre a preparação sozinho. Nas cenas que constroem o Ninho
## antes de exercitar a largada, o harness apenas segura o cronômetro; a largada em si
## continua saindo do mesmo start_invasion() que o zero dispara.
const HELD_PREPARATION := 3600.0
## §14/T13: o F abriu a preparação, então o nascimento das Feras não cai mais no mesmo
## frame da tecla. 0.5 m são 0.2 s de marcha — e os dois pontos de largada ficam a
## 15.7 m um do outro e a mais de 10 m do Núcleo, o que continua provando o marco.
const LAUNCH_BIRTH_TOLERANCE := 0.5

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
var _core_hud: Node
var _combat_hud: Node
var _invasion_hud: Node
var _warning_hud: Node
var _worker: WorkerRuntime
var _worker2: WorkerRuntime
var _soldier: SoldierRuntime
var _probes: Array[EnemyRuntime] = []

var _integrity_events := 0
var _destroyed_events := 0
var _started_events := 0
var _victory_events := 0
var _defeat_events := 0
var _remaining_trace: Array[int] = []
var _population_trace: Array[int] = []
var _defense_report := {}


func _initialize() -> void:
	_run_all()


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > 900000:
		_check(false, "timeout: a suíte de invasão não terminou")
		_finish()
	return false


func _run_all() -> void:
	_test_core_damage()
	_test_core_clamp()
	_test_core_destroyed_once()
	_test_core_invalid_damage()
	_test_core_no_regen_no_repair()
	_test_core_runtime_surface()
	_test_enemy_move_speed()
	await _test_enemy_invasion_api()
	_test_invasion_controller_surface()
	_test_hud_surface()
	_test_scope_guards()

	# Cena 1 — ciclo de vida completo dirigido por input, até a vitória.
	await _boot_scene()
	await _test_boot_without_enemies()
	await _test_invasion_hud_initial()
	await _test_spawn_points()
	await _test_input_action()
	await _test_core_hud_by_signal()
	await _test_no_regen_in_scene()
	await _test_start_invasion_by_input()
	await _test_second_f_does_not_duplicate()
	await _test_advance_simultaneous()
	await _test_workers_ignored()
	await _test_victory_flow()
	_free_scene()

	# Cena 2 — marcha, postura, cadência de dano ao Núcleo e prioridade de combate.
	await _boot_scene()
	await _test_enemy_advance_movement()
	await _test_fps_independence()
	await _test_core_stance_geometry()
	await _test_first_core_hit()
	await _test_continuous_core_attack()
	await _test_two_invaders_damage_rate()
	await _test_combat_priority_over_core()
	await _test_constructions_ignored()
	_free_scene()

	# Cena 3 — interceptação, cancelamento e morte do Soldado com os invasores reais.
	await _boot_scene()
	await _test_intercept_holds_one_invader()
	await _test_move_cancel_returns_to_advance()
	await _test_soldier_death_resumes_advance()
	_free_scene()

	# Cena 4 — o comportamento passivo da Tarefa 11 continua valendo fora da invasão.
	await _boot_scene()
	await _test_passive_enemy_still_idle()
	_free_scene()

	# Cena 5 — derrota por omissão de defesa.
	await _boot_scene()
	await _test_defeat_flow()
	_free_scene()

	# Cena 6 — campanha defensiva end-to-end.
	await _boot_scene()
	await _test_end_to_end_defense()
	_free_scene()
	_finish()


# --------------------------------------------------------------- CoreState (§4–§8)


func _test_core_damage() -> void:
	var state := _new_core_state()
	_check(_close(state.integrity, INTEGRITY), "§1 o Núcleo abre com 100 de Integrity")
	state.damage(BEAST_DAMAGE)
	_check(_close(state.integrity, 94.0), "§53 100 - 6 = 94, obtido %f" % state.integrity)


func _test_core_clamp() -> void:
	var state := _new_core_state()
	var events := [0]
	state.integrity_changed.connect(func(_current: float, _maximum: float) -> void:
		events[0] += 1)
	state.damage(999.0)
	_check(_close(state.integrity, 0.0), "§54 dano 999 clampa em 0, obtido %f" % state.integrity)
	state.damage(50.0)
	_check(_close(state.integrity, 0.0), "§54 depois de zero o clamp continua em 0")
	var above := _new_core_state()
	above.damage(-9_999.0)
	above.damage(0.0)
	_check(_close(above.integrity, INTEGRITY), "§54 o clamp não deixa dano inválido subir")
	_check(events[0] == 1, "§5/§54 Integrity só emite quando muda, eventos %d" % events[0])


func _test_core_destroyed_once() -> void:
	var state := _new_core_state()
	var destroyed := [0]
	state.destroyed.connect(func() -> void: destroyed[0] += 1)
	_check(not state.is_destroyed(), "§55 o Núcleo não nasce destruído")
	state.damage(60.0)
	_check(destroyed[0] == 0 and not state.is_destroyed(),
			"§55 com 40 ainda não há destroyed")
	state.damage(40.0)
	_check(state.is_destroyed() and destroyed[0] == 1,
			"§55 chegar a zero emite destroyed uma vez, obtido %d" % destroyed[0])
	state.damage(40.0)
	state.damage(999.0)
	_check(destroyed[0] == 1,
			"§55/§22 dano depois da destruição não reemite destroyed, obtido %d" % destroyed[0])


func _test_core_invalid_damage() -> void:
	var state := _new_core_state()
	var events := [0]
	state.integrity_changed.connect(func(_current: float, _maximum: float) -> void:
		events[0] += 1)
	state.damage(0.0)
	_check(_close(state.integrity, INTEGRITY), "§56 damage(0) não altera Integrity")
	state.damage(-10.0)
	_check(_close(state.integrity, INTEGRITY), "§56 damage(-10) não altera Integrity")
	_check(events[0] == 0, "§5/§56 dano inválido não emite integrity_changed, eventos %d"
			% events[0])
	_check(not state.is_destroyed(), "§56 o Núcleo continua de pé")


func _test_core_no_regen_no_repair() -> void:
	var state := _new_core_state()
	state.damage(30.0)
	_check(not state.has_method("heal"), "§51 CoreState não tem heal")
	_check(not state.has_method("repair"), "§52 CoreState não tem repair")
	_check(not state.has_method("regenerate"), "§51 CoreState não tem regenerate")
	var source := _source(CORE_STATE_SOURCE_PATH).to_lower()
	for forbidden in ["heal", "repair", "regen", "integrity +"]:
		_check(not source.contains(forbidden),
				"§51/§52 core_state.gd não menciona %s" % forbidden)
	_check(_close(state.integrity, 70.0), "§51 o dano recebido permanece, obtido %f"
			% state.integrity)


func _test_core_runtime_surface() -> void:
	var core := CORE_SCENE.instantiate() as CoreRuntime
	_check(core.combat_radius == CORE_COMBAT_RADIUS,
			"§7 combat_radius 0.8 vem do Runtime, obtido %f" % core.combat_radius)
	_check(core.has_method("receive_damage"), "§6 CoreRuntime tem receive_damage")
	var fields := _instance_fields(core)
	for forbidden in ["integrity", "_integrity", "health", "max_integrity"]:
		_check(not fields.has(forbidden) and not fields.has("_" + forbidden),
				"§6 o Runtime não duplica Integrity em campo próprio (%s)" % forbidden)
	_check(fields == ["combat_radius", "_definition", "_state"],
			"§6/§7 os únicos campos do CoreRuntime são combat_radius e as referências, são %s"
					% [fields])
	var state := _new_core_state()
	core.setup(load(CORE_DEFINITION_PATH) as CoreDefinition, state)
	core.receive_damage(BEAST_DAMAGE)
	_check(_close(state.integrity, 94.0),
			"§6 receive_damage só atravessa para o CoreState, obtido %f" % state.integrity)
	core.receive_damage(0.0)
	_check(_close(state.integrity, 94.0), "§6/§56 receive_damage(0) é ignorado")
	_check(_source(CORE_RUNTIME_SOURCE_PATH).contains("_state.damage"),
			"§6 o Runtime delega o número ao State")
	core.free()


# ------------------------------------------------------------ Enemy (§3, §9–§23)


func _test_enemy_move_speed() -> void:
	var definition := _enemy_definition()
	_check(_close(definition.move_speed, BEAST_SPEED),
			"§3/§58 cave_beast.move_speed == 2.5, obtido %f" % definition.move_speed)
	_check(_source(ENEMY_DEFINITION_PATH).contains("move_speed = 2.5"),
			"§3 o número mora no .tres")
	_check(_source(ENEMY_DEFINITION_SOURCE_PATH).contains("@export var move_speed: float"),
			"§3 move_speed é @export float na Definition")
	# §3: nenhum número hardcoded no Runtime.
	var runtime_source := _source(ENEMY_RUNTIME_SOURCE_PATH)
	_check(not runtime_source.contains("2.5"),
			"§3 enemy_runtime.gd não hardcodeia 2.5")
	for value in ["48.0", "6.0", "1.2", "1.0", "2.5"]:
		_check(not runtime_source.contains("= " + value)
				and not runtime_source.contains("(" + value),
				"§3 nenhum número de stat escrito no Runtime (%s)" % value)
	_check(runtime_source.contains("definition.move_speed"),
			"§3 a velocidade vem lida da Definition")


func _test_enemy_invasion_api() -> void:
	var enemy := ENEMY_SCENE.instantiate() as EnemyRuntime
	enemy.setup(_enemy_definition(), EnemyState.new(_enemy_definition(), "probe_api"))
	_check(enemy.has_method("start_invasion"), "§11 EnemyRuntime tem start_invasion")
	_check(enemy.has_method("invasion_target"), "§10 EnemyRuntime expõe invasion_target")
	_check(enemy.has_method("combat_target"), "§10 EnemyRuntime expõe combat_target")
	_check(enemy.has_method("stand_down"), "§22 EnemyRuntime tem stand_down")
	_check(enemy.has_method("action_mode"), "§9 EnemyRuntime expõe o modo atual")
	_check(enemy.action_mode() == EnemyRuntime.ActionMode.IDLE,
			"§9 o modo inicial é IDLE, obtido %s" % [str(enemy.action_mode())])
	_check(enemy.invasion_target() == null and enemy.combat_target() == null,
			"§10 sem ordem os dois alvos estão vazios")
	# O corpo físico só existe depois de entrar na árvore, e é dele que body_radius lê.
	# Um frame de espera porque é a entrada na árvore que resolve os @onready da cena.
	root.add_child(enemy)
	await process_frame
	_check(not enemy.is_physics_processing(),
			"§84 a Fera recém-criada não executa física nenhuma")
	_check(_close(enemy.body_radius(), BEAST_RADIUS),
			"§14 o corpo da Fera mede 0.6 do próprio collider, obtido %f" % enemy.body_radius())
	var source := _source(ENEMY_RUNTIME_SOURCE_PATH)
	_check(source.contains("enum ActionMode"), "§9 o ActionMode é local ao Runtime")
	_check(source.contains("IDLE, ADVANCE, COMBAT"), "§9 os três modos são IDLE/ADVANCE/COMBAT")
	for forbidden in ["StateMachine", "FSM", "BehaviorTree", "State class"]:
		_check(not source.contains(forbidden), "§9 nenhum %s externo no inimigo" % forbidden)
	for forbidden in ["NavigationAgent3D", "NavigationRegion3D", "NavigationMesh",
			"avoidance_enabled", "AStar"]:
		_check(not source.contains(forbidden), "§13/§90 enemy_runtime.gd não usa %s" % forbidden)
	_check(source.contains("move_and_slide()"), "§12 o deslocamento usa move_and_slide")
	_check(not source.contains("move_and_collide"), "§12 nada de move_and_collide")
	_check(not source.contains("global_position +="), "§12 ninguém escreve posição direto")
	_check(not source.contains("velocity * delta") and not source.contains("delta *"),
			"§12 velocity não é multiplicada por delta")
	_check(source.contains("velocity.y = 0.0"), "§12 o movimento é só em X/Z")
	_check(source.contains("velocity = Vector3.ZERO"), "§15 a Fera bate parada")
	root.remove_child(enemy)
	enemy.free()


func _test_invasion_controller_surface() -> void:
	var source := _source(INVASION_CONTROLLER_SOURCE_PATH)
	_check(source.contains("class_name InvasionController"), "§24 InvasionController existe")
	_check(source.contains("extends Node"), "§24 o controller é um Node simples")
	_check(source.contains("enum InvasionState"), "§25 InvasionState é local")
	_check(source.contains("NOT_STARTED, PREPARATION, ACTIVE, VICTORY, DEFEAT"),
			"§2/T13 os cinco estados aparecem exatamente na ordem pedida")
	for state_name in ["NOT_STARTED", "PREPARATION", "ACTIVE", "VICTORY", "DEFEAT"]:
		_check(source.contains(state_name), "§2/T13 o estado %s existe" % state_name)
	_check(source.contains("INVADER_COUNT := 2"), "§30 a quantidade 2 mora num const")
	# §3/T13: os 60 segundos de produção moram num @export, não espalhados em literals.
	_check(source.contains("@export var preparation_duration: float = 60.0"),
			"§3/T13 a duração de produção é @export 60.0")
	# §4/T13 e §5/T13: o resto do tempo é contagem por delta com clamp em zero.
	_check(source.contains("_preparation_time_remaining"), "§4/T13 o restante mora no controller")
	_check(source.contains("func _process(delta: float)"), "§5/T13 a contagem anda por delta")
	_check(source.contains("maxf(_preparation_time_remaining - delta, 0.0)"),
			"§4/T13 o countdown clampa no zero")
	_check(source.contains("set_process(true)"), "§5/T13 o countdown só acorda na preparação")
	_check(source.contains("set_process(false)"), "§5/§79/T13 fora da preparação ele dorme")
	_check(source.contains("if _state != InvasionState.PREPARATION"),
			"§79/T13 o processamento se desliga em qualquer outro estado")
	_check(source.contains("func begin_preparation()"), "§6/T13 existe begin_preparation()")
	_check(source.contains("if _state != InvasionState.NOT_STARTED"),
			"§8/T13 só NOT_STARTED abre preparação")
	_check(source.contains("func preparation_time_remaining()"),
			"§4/T13 o restante é lido de fora sem varrer nada")
	_check(source.contains("NOT_STARTED and _state != InvasionState.PREPARATION"),
			"§13/T13 start_invasion() aceita a preparação e nada além disso")
	_check(source.contains("_displayed_second"), "§10/T13 o emit de HUD é por segundo virado")
	for forbidden in ["create_timer", "Timer.new", "func _physics_process(", "Wave", "Threat",
			"CombatManager", "EnemySpawner", "EnemyFactory", "queue_free", "EventBus",
			"get_tree().get_nodes_in_group", "add_to_group"]:
		_check(not source.contains(forbidden),
				"§24/§38/§91/§92 invasion_controller.gd não contém %s" % forbidden)
	# §38/§91/T13: a varredura do countdown lê código, não a prosa que descreve o que
	# não existe. await e Timer node são justamente as duas cadeias que §5 proíbe.
	var countdown_code := _code_of(INVASION_CONTROLLER_SOURCE_PATH)
	for forbidden in ["await", "Timer", "SceneTreeTimer", "get_tree().paused", "time_scale"]:
		_check(not countdown_code.contains(forbidden),
				"§5/§80/T13 o countdown não contém %s" % forbidden)
	# §5/T13: a contagem é delta puro — nem Timer node, nem cadeia de awaits.
	for signal_name in ["invasion_started", "invasion_victory", "invasion_defeat",
			"active_invaders_changed", "preparation_started", "preparation_time_changed"]:
		_check(source.contains("signal " + signal_name), "§38/§9/T13 o signal %s existe"
				% signal_name)
	_check(source.contains("is_action_pressed(\"start_invasion\")"),
			"§26 a largada sai de uma ação do InputMap, não de keycode solto")
	_check(not source.contains("KEY_F"), "§26 nenhum keycode hardcoded")
	_check(source.contains("setup("), "§28 as dependências entram por setup()")
	# A varredura de lookup global lê o código sem comentários: o próprio arquivo
	# documenta que não usa autoload, e prose não pode ser acusada como uso.
	var code := _code_of(INVASION_CONTROLLER_SOURCE_PATH)
	for lookup in ["get_node(\"/root", "Engine.get_main_loop", "autoload"]:
		_check(not code.to_lower().contains(lookup.to_lower()),
				"§28 nada de lookup global (%s)" % lookup)
	# §33/T13: quem conhece o Ninho é a composition root. O controller nunca sai
	# procurando a construção na árvore.
	for nest in ["Nest", "Construction", "construction_completed"]:
		_check(not code.contains(nest), "§33/T13 o controller não caça %s na árvore" % nest)
	_check(_count_files("res://systems/combat", "*.gd") == 1,
			"§24/§91 exatamente um script em systems/combat")
	_check(_count_files("res://systems/combat", "invasion_controller.gd") == 1,
			"§24 o único script de systems/combat é invasion_controller.gd")


func _test_hud_surface() -> void:
	var source := _source(INVASION_HUD_SOURCE_PATH)
	for line in [HINT_LINE, WAITING_STATUS, ACTIVE_STATUS, VICTORY_STATUS, DEFEAT_STATUS]:
		_check(source.contains(line), "§39 a linha exata \"%s\" está no HUD" % line)
	# §17/T13: as três linhas da preparação são texto de produção, não de teste.
	for line in [PREPARATION_ALERT, PREPARATION_COUNTDOWN_PREFIX, PREPARATION_ADVICE]:
		_check(source.contains(line), "§17/T13 a linha da preparação \"%s\" está no HUD" % line)
	_check(not source.contains("func _process("), "§40 o HUD de invasão não tem _process")
	_check(not source.contains("_physics_process"), "§40 o HUD de invasão não roda por frame")
	for signal_name in ["invasion_started", "invasion_victory", "invasion_defeat",
			"active_invaders_changed", "preparation_started", "preparation_time_changed"]:
		_check(source.contains(signal_name + ".connect"),
				"§38/§40/§9/T13 o HUD consome %s por signal" % signal_name)
	var core_hud := _source(CORE_HUD_SOURCE_PATH)
	_check(core_hud.contains("integrity_changed.connect"),
			"§8/§57 a Integrity do Core HUD chega por signal")
	_check(not core_hud.contains("func _process("), "§8 o Core HUD não consulta por frame")
	var main := _source(GAME_MAIN_SOURCE_PATH)
	_check(main.contains("_invasion_hud.bind"),
			"§40 a composition root liga o HUD ao controller")
	# §18/§19/§20/T13: o aviso é PanelContainer + Label, sem animação, som ou VFX, e só
	# aparece em PREPARATION.
	var warning := _source(INVASION_WARNING_HUD_SOURCE_PATH)
	_check(warning.contains("extends PanelContainer"), "§18/T13 o aviso é um PanelContainer")
	_check(warning.contains("AMEAÇA DETECTADA"), "§19/T13 o aviso nomeia a ameaça")
	_check(warning.contains("preparation_started.connect"),
			"§20/T13 o aviso acorda pelo preparation_started")
	_check(warning.contains("invasion_started.connect"),
			"§20/T13 o aviso se apaga no invasion_started")
	_check(warning.contains("preparation_time_changed.connect"),
			"§51/T13 os segundos do aviso vêm do signal de tempo")
	var warning_code := _code_of(INVASION_WARNING_HUD_SOURCE_PATH)
	for forbidden in ["func _process(", "_physics_process", "create_timer", "Tween",
			"AnimationPlayer", "AudioStream", "CameraShake", "VFX", "Particles"]:
		_check(not warning_code.contains(forbidden), "§18/§75/T13 o aviso não faz %s" % forbidden)
	# §21/T13: a regra de mouse_filter mora no .tscn, que é o que vai para a tela.
	var warning_scene_text := _source(INVASION_WARNING_SCENE_PATH)
	var warning_nodes := warning_scene_text.count("[node name=")
	_check(warning_nodes == 4
			and warning_scene_text.count("mouse_filter = 2") == warning_nodes,
			"§21/T13 os %d nós de Control do aviso são todos IGNORE no .tscn" % warning_nodes)
	_check(warning_scene_text.contains("visible = false"),
			"§31/T13 o aviso nasce escondido no próprio .tscn")
	_check(main.contains("_invasion_warning_hud.bind"),
			"§40/T13 a composition root liga o aviso ao controller")


# --------------------------------------------------------------- Escopos (§90–§94)


func _test_scope_guards() -> void:
	var sources := _collect_gd_files("res://")
	_check(not sources.is_empty(), "§98 a varredura de fontes encontrou arquivos .gd")
	for forbidden in ["WaveManager", "WaveDefinition", "WaveQueue", "ThreatManager",
			"CombatManager", "EnemySpawner", "EnemyFactory", "GameOverScreen",
			"NavigationAgent3D", "NavigationRegion3D", "NavigationMesh", "avoidance_enabled",
			"AStar3D", "FlowField", "auto_aggro", "nearest_enemy", "regenerate_integrity",
			"repair_core", "experience_reward", "loot_table", "EventBus", "threat_level",
			"GameClock", "TimeManager", "DayNightManager", "EventManager", "StoryManager",
			"MilestoneManager", "WarningManager", "ThreatSystem", "wave_index"]:
		var offenders := _files_containing(sources, forbidden)
		_check(offenders.is_empty(),
				"§90–§94/§75–§78 nenhum código de produção contém %s, achado em %s"
						% [forbidden, offenders])
	# §98/T14: a contagem cresceu porque existe um sexto controller real — o de evolução
	# do Núcleo, que é o único degrau de progressão do MVP. A exigência continua exata:
	# um controller novo exige uma tarefa nova, nunca um Manager genérico (árvore de
	# upgrades, ProgressionManager, MilestoneManager). Antes 5, agora 6.
	_check(_collect_gd_files("res://systems").size() == 6,
			"§98 systems/ continua com exatamente seis scripts de controle, obtido %d"
					% _collect_gd_files("res://systems").size())
	var main := _source(GAME_MAIN_SOURCE_PATH)
	for forbidden in ["Enemy001", "_spawn_initial_enemy", "EnemySpawnPoint", "queue_free(_core",
			"remove_child(_core"]:
		_check(not main.contains(forbidden),
				"§23/§32 game_main.gd não contém %s" % forbidden)
	_check(main.contains("ENEMY_SCENE"), "§28 GameMain conhece a cena da Fera para injetá-la")
	_check(main.contains("_invasion.setup("), "§28 GameMain injeta as dependências da invasão")
	# §33/§77/T13: o gatilho do Ninho é uma conexão explícita da composition root, e a
	# partida nunca joga sozinha (§64/T13).
	_check(main.contains("_construction.nest_completed.connect"),
			"§33/T13 GameMain conecta o Ninho concluído")
	_check(main.contains("_invasion.begin_preparation()"),
			"§6/T13 o único efeito do Ninho sobre a invasão é abrir a preparação")
	_check(not main.contains("start_invasion()"),
			"§32/T13 GameMain não larga a invasão direto, muito menos no Ninho")
	for auto in ["_worker.build(", "auto_build", "auto_mine", "auto_recruit"]:
		_check(not main.contains(auto), "§64/T13 nada na produção se constrói sozinho (%s)" % auto)
	var settings := _source(PROJECT_SETTINGS_PATH)
	_check(not settings.contains("[autoload]"), "§24/§38 nada de autoload no projeto")
	var selection := _source(SELECTION_SOURCE_PATH)
	_check(selection.contains("ENEMY_LAYER"), "§45 a seleção continua enxergando a camada Enemy")
	_check(selection.contains("\"attack_target\""),
			"§45 o dispatch de ATTACK por camada continua intacto")
	var enemy_source := _source(ENEMY_RUNTIME_SOURCE_PATH).to_lower()
	for forbidden in ["nest", "barracks", "construction", "worker", "deposit", "nearest",
			"get_tree(", "physics ray", "intersect_ray"]:
		_check(not enemy_source.contains(forbidden),
				"§43/§44/§45/§42 a Fera não procura nada por conta própria (%s)" % forbidden)
	var soldier_source := _source(SOLDIER_RUNTIME_SOURCE_PATH)
	for forbidden in ["CoreRuntime", "CoreState", "receive_damage(_core", "integrity"]:
		_check(not soldier_source.contains(forbidden),
				"§46 o Soldado não conhece o Núcleo nem decide atacar sozinho (%s)" % forbidden)


# ----------------------------------------------------------------- Cena real (§98)


func _test_boot_without_enemies() -> void:
	var enemies := _enemies_in_scene()
	_check(enemies.is_empty(), "§32 a partida abre com 0 inimigos, obtido %d" % enemies.size())
	_check(_scene.get_node_or_null("World/DungeonRoot/Enemy001") == null,
			"§32 não existe mais o Enemy001 automático")
	_check(_invasion.invasion_state() == InvasionController.InvasionState.NOT_STARTED,
			"§25 o controller abre em NOT_STARTED")
	_check(_invasion.active_invaders() == 0, "§36 active_invaders começa em 0")
	_check(_invasion.invaders().is_empty(), "§34 nenhuma criatura registrada antes do F")
	# §31/§36/T13: a partida abre sem ameaça anunciada — countdown parado e aviso occulto.
	_check(_close(_invasion.preparation_time_remaining(), 0.0),
			"§36/T13 o tempo restante abre em 0, obtido %f"
					% _invasion.preparation_time_remaining())
	_check(not _warning_hud.visible, "§31/T13 o aviso de ameaça começa escondido")
	_check(_close(_core_state.integrity, INTEGRITY), "§1 Integrity 100 no início")
	_check(_core.is_inside_tree() and is_instance_valid(_core_state),
			"§23 o Núcleo está na árvore e vivo")
	_check(_text_of(_combat_hud, "EnemyLabel") == NO_ENEMY_LINE,
			"§32/§39 o painel de combate abre sem inimigo, obtido %s"
					% _text_of(_combat_hud, "EnemyLabel"))


func _test_invasion_hud_initial() -> void:
	var panel := _scene.get_node("UI/InvasionDebugPanel")
	_check(panel is InvasionDebugHud, "§39 o painel de invasão está composto no GameMain")
	_check(_text_of(_invasion_hud, "HintLabel") == HINT_LINE,
			"§39 a dica é \"%s\", obtido %s" % [HINT_LINE, _text_of(_invasion_hud, "HintLabel")])
	_check(_text_of(_invasion_hud, "StatusLabel") == WAITING_STATUS,
			"§39 o status inicial é \"%s\", obtido %s"
					% [WAITING_STATUS, _text_of(_invasion_hud, "StatusLabel")])
	_check(_text_of(_invasion_hud, "RemainingLabel") == "",
			"§39 não há contagem antes da invasão, obtido %s"
					% _text_of(_invasion_hud, "RemainingLabel"))
	var offenders := _controls_not_ignoring(panel)
	_check(offenders.is_empty(), "§40 todo Control do painel de invasão é IGNORE, %s"
			% [offenders])
	# §21/§31/T13: o aviso também é composto, começa escondido e não segura clique nenhum.
	var warning := _scene.get_node("UI/InvasionWarningPanel")
	_check(warning is InvasionWarningHud, "§19/T13 o painel de aviso está composto no GameMain")
	_check(not warning.visible, "§31/T13 o aviso nasce escondido")
	var warning_offenders := _controls_not_ignoring(warning)
	_check(warning_offenders.is_empty(), "§21/T13 todo Control do aviso é IGNORE, %s"
			% [warning_offenders])


func _test_spawn_points() -> void:
	var markers: Array[Node3D] = []
	for child in _dungeon.get_children():
		if child is Marker3D and String(child.name).begins_with("InvasionSpawnPoint"):
			markers.append(child as Marker3D)
	_check(markers.size() == 2,
			"§29 exatamente dois pontos de invasão, obtido %d" % markers.size())
	var point_a := _dungeon.get_node_or_null("InvasionSpawnPointA") as Node3D
	var point_b := _dungeon.get_node_or_null("InvasionSpawnPointB") as Node3D
	_check(point_a != null and point_b != null, "§29 os dois pontos têm o nome pedido")
	if point_a == null or point_b == null:
		return
	_check(point_a.global_position.is_equal_approx(SPAWN_A),
			"§29 A está em (-4, 0, 10), obtido %s" % [point_a.global_position])
	_check(point_b.global_position.is_equal_approx(SPAWN_B),
			"§29 B está em (11, 0, 0), obtido %s" % [point_b.global_position])
	_check_spawn_point(point_a, "A", SPAWN_A_DISTANCE)
	_check_spawn_point(point_b, "B", SPAWN_B_DISTANCE)
	_check(_planar_gap(point_a.global_position, point_b.global_position)
			> 2.0 * BEAST_RADIUS + 1.0,
			"§29 os dois pontos não se sobrepõem (%f)"
					% _planar_gap(point_a.global_position, point_b.global_position))
	# Os corpos das duas posturas finais param do lado oposto do Núcleo e continuam separados.
	_check(_stance_separation() > 2.0 * BEAST_RADIUS,
			"§29/§64 as duas posturas finais não se sobrepõem (%f)" % _stance_separation())


func _check_spawn_point(point: Node3D, label: String, expected_distance: float) -> void:
	var spot := point.global_position
	_check(_ground_body_at(spot) == "TestFloorBody",
			"§29 %s está sobre o Ground, obtido %s" % [label, _ground_body_at(spot)])
	_check(_shape_clear_at(spot, BEAST_RADIUS + 0.4, OBSTACLES | UNIT_LAYER),
			"§29 %s não tem nenhuma forma sólida em cima" % label)
	_check(_close(_planar_gap(spot, CORE_PLANAR), expected_distance, 0.01),
			"§29 %s fica a %f do Núcleo (esperado %f)"
					% [label, _planar_gap(spot, CORE_PLANAR), expected_distance])
	_check(_planar_gap(spot, CORE_PLANAR) > STANCE + 6.0,
			"§29 %s está longe o bastante para a marcha ser visível" % label)
	_check(_route_ray_clear(spot), "§29 a rota reta de %s até o Núcleo não cruza obstáculo" % label)
	_check(_route_body_clear(spot),
			"§29 o corpo de 0.6 de %s atravessa a rota inteira sem sobreposição" % label)
	for rock in _rocks_in_scene():
		var margin := _planar_gap(spot, rock.global_position) - ROCK_HALF - BEAST_RADIUS
		_check(margin > 0.4,
				"§29 %s não bloqueia a rocha %s (folga %f)" % [label, rock.rock_id, margin])
	_check(_site_margin(spot, NEST_POINT, BUILD_HALF) > 0.4,
			"§29 %s não bloqueia o Ninho (%f)" % [label, _site_margin(spot, NEST_POINT, BUILD_HALF)])
	_check(_site_margin(spot, BARRACKS_POINT, BUILD_HALF) > 0.4,
			"§29 %s não bloqueia o Quartel (%f)"
					% [label, _site_margin(spot, BARRACKS_POINT, BUILD_HALF)])
	_check(_site_margin(spot, DEPOSIT_POINT, DEPOSIT_HALF) > 0.4,
			"§29 %s não bloqueia o depósito (%f)"
					% [label, _site_margin(spot, DEPOSIT_POINT, DEPOSIT_HALF)])


func _test_input_action() -> void:
	_check(InputMap.has_action("start_invasion"), "§26 a ação start_invasion existe")
	var events := InputMap.action_get_events("start_invasion")
	_check(events.size() == 1, "§26/§65 a ação tem exatamente um evento, obtido %d"
			% events.size())
	if events.is_empty():
		return
	var key := events[0] as InputEventKey
	_check(key != null, "§26 o evento registrado é uma tecla, obtido %s"
			% [str(events[0].get_class())])
	if key == null:
		return
	_check(key.physical_keycode == KEY_F,
			"§26 a tecla física registrada é F (70), obtido %d" % key.physical_keycode)
	_check(not key.alt_pressed and not key.shift_pressed and not key.ctrl_pressed
			and not key.meta_pressed, "§26 nenhuma modificadora acompanha o F")


func _test_core_hud_by_signal() -> void:
	_check(_text_of(_core_hud, "IntegrityLabel") == "Integrity: 100 / 100",
			"§57 o painel abre mostrando 100 / 100, obtido %s"
					% _text_of(_core_hud, "IntegrityLabel"))
	_core.receive_damage(BEAST_DAMAGE)
	_check(_text_of(_core_hud, "IntegrityLabel") == "Integrity: 94 / 100",
			"§8/§57 receive_damage atualiza o HUD sem polling, obtido %s"
					% _text_of(_core_hud, "IntegrityLabel"))
	_core.receive_damage(4.0)
	_check(_text_of(_core_hud, "IntegrityLabel") == "Integrity: 90 / 100",
			"§8 o HUD acompanha cada dano, obtido %s" % _text_of(_core_hud, "IntegrityLabel"))
	_check(_integrity_events == 2,
			"§5 dois danos, dois integrity_changed, obtido %d" % _integrity_events)
	_core.receive_damage(0.0)
	_core.receive_damage(-6.0)
	_check(_integrity_events == 2 and _close(_core_state.integrity, 90.0),
			"§56 dano inválido não mexe no HUD nem no State")
	_check(_close(_core_state.integrity, 90.0),
			"§53 a Integrity de referência das próximas medições é 90, obtido %f"
					% _core_state.integrity)


func _test_no_regen_in_scene() -> void:
	var before := _core_state.integrity
	await _advance(2.0)
	_check(_close(_core_state.integrity, before),
			"§51 em 2 s de jogo a Integrity não subiu sozinha (%f → %f)"
					% [before, _core_state.integrity])
	_check(_close(before, 90.0), "§51/§52 nada devolve Integrity ao Núcleo")


func _test_start_invasion_by_input() -> void:
	var before_invaders := _enemies_in_scene()
	_check(before_invaders.is_empty(), "§65 antes do F a cena tem 0 inimigos")
	await _press_f_and_launch()
	await _advance(0.05)
	var invaders := _enemies_in_scene()
	_check(invaders.size() == 2,
			"§65 um F real cria exatamente 2 Feras, obtido %d" % invaders.size())
	_check(_invasion.invasion_state() == InvasionController.InvasionState.ACTIVE,
			"§25/§65 o estado virou ACTIVE por input, não só por chamada direta")
	_check(_started_events == 1, "§38 invasion_started emitiu uma vez, obtido %d"
			% _started_events)
	_check(_remaining_trace.size() == 1 and _remaining_trace[0] == 2,
			"§38/§39 contagem registrada %s" % [_remaining_trace])
	# Os invasores já marcham quando a medição acontece: desde a Tarefa 13 o F abre a
	# preparação e é o cronômetro que planta as Feras, então a prova é "nasceu naquele
	# marco", com a folga de LAUNCH_BIRTH_TOLERANCE medidos depois da largada.
	var drift_a := invaders[0].global_position.distance_to(SPAWN_A)
	var drift_b := invaders[1].global_position.distance_to(SPAWN_B)
	var distinct_points := SPAWN_A.distance_to(SPAWN_B) > 2.0 * BEAST_RADIUS
	_check(distinct_points and drift_a < LAUNCH_BIRTH_TOLERANCE
			and drift_b < LAUNCH_BIRTH_TOLERANCE,
			"§29/§34 os dois invasores nasceram cada um no seu SpawnPoint, afastados "
					+ "(%f, %f)" % [drift_a, drift_b])
	_check(invaders[0].state != invaders[1].state,
			"§35 cada invasor tem o próprio EnemyState")
	_check(invaders[0].definition == invaders[1].definition,
			"§35 a Definition é a mesma instância compartilhada")
	_check(invaders[0].definition == _enemy_definition()
			and invaders[0].definition.resource_path == ENEMY_DEFINITION_PATH,
			"§31 as duas usam cave_beast.tres, sem nova Definition")
	_check(invaders[0].get_enemy_id() == "invader_001"
			and invaders[1].get_enemy_id() == "invader_002",
			"§30/§67 os ids são invader_001 e invader_002, obtidos %s e %s"
					% [invaders[0].get_enemy_id(), invaders[1].get_enemy_id()])
	_check(invaders[0].state.enemy_id != invaders[1].state.enemy_id,
			"§67 os ids dos States são diferentes")
	_check(invaders[0].invasion_target() == _core and invaders[1].invasion_target() == _core,
			"§42 o alvo é o CoreRuntime injetado, não um raycast nem um scan")
	_check(invaders[0].action_mode() == EnemyRuntime.ActionMode.ADVANCE
			and invaders[1].action_mode() == EnemyRuntime.ActionMode.ADVANCE,
			"§11 os dois entram em ADVANCE imediatamente")
	_check(invaders[0].state.health == BEAST_HP and invaders[1].state.health == BEAST_HP,
			"§30 cada invasor chega com os 48 de vida da espécie")
	_check(_text_of(_invasion_hud, "StatusLabel") == ACTIVE_STATUS,
			"§39 o painel mostra \"%s\", obtido %s"
					% [ACTIVE_STATUS, _text_of(_invasion_hud, "StatusLabel")])
	_check(_text_of(_invasion_hud, "RemainingLabel") == REMAINING_TWO,
			"§39 o painel abre com 2 restantes, obtido %s"
					% _text_of(_invasion_hud, "RemainingLabel"))
	_check(_text_of(_combat_hud, "EnemyLabel") == BEAST_LINE_FULL,
			"§33/T11 o painel de combate passou a mostrar a Fera invasora, obtido %s"
					% _text_of(_combat_hud, "EnemyLabel"))
	# §70/T13: o aviso não fica por cima do combate — apagou no mesmo instante da largada.
	_check(not _warning_hud.visible, "§70/T13 o aviso sumiu quando a invasão virou ACTIVE")
	_check(_text_of(_invasion_hud, "HintLabel") == HINT_LINE,
			"§17/T13 o painel de status voltou a dica normal no ACTIVE, obtido %s"
					% _text_of(_invasion_hud, "HintLabel"))


func _test_second_f_does_not_duplicate() -> void:
	_press_key(KEY_F)
	await _advance(0.05)
	var enemies := _enemies_in_scene()
	_check(enemies.size() == 2,
			"§66/§67 o segundo F não cria terceiro nem quarto, obtido %d" % enemies.size())
	_check(_started_events == 1, "§66 invasion_started continua em 1, obtido %d" % _started_events)
	_check(_invasion.invasion_state() == InvasionController.InvasionState.ACTIVE,
			"§66 o estado continua ACTIVE")
	_check(not _invasion.start_invasion(),
			"§66 start_invasion() recusa uma segunda largada")
	_check(not _invasion.begin_preparation(),
			"§15/T13 com a invasão ACTIVE o F não reabre preparação nenhuma")


func _test_advance_simultaneous() -> void:
	var invaders := _invasion.invaders()
	var before_a := _planar_gap(invaders[0].global_position, CORE_PLANAR)
	var before_b := _planar_gap(invaders[1].global_position, CORE_PLANAR)
	await _advance(1.0)
	var after_a := _planar_gap(invaders[0].global_position, CORE_PLANAR)
	var after_b := _planar_gap(invaders[1].global_position, CORE_PLANAR)
	_check(after_a < before_a - 2.0 and after_b < before_b - 2.0,
			"§59/§68 os dois fecharam distância ao mesmo tempo (%f→%f, %f→%f)"
					% [before_a, after_a, before_b, after_b])
	_check(_close(before_a - after_a, BEAST_SPEED, 0.05)
			and _close(before_b - after_b, BEAST_SPEED, 0.05),
			"§58/§68 cada um anda 2.5 por segundo (%f e %f)"
					% [before_a - after_a, before_b - after_b])
	_check(invaders[0].velocity.y == 0.0 and invaders[1].velocity.y == 0.0,
			"§12 nenhum dos dois sai do plano do chão")


func _test_workers_ignored() -> void:
	var invaders := _invasion.invaders()
	var worker := _workers_in_scene()[0]
	var worker_state := worker.state
	_check(worker_state != null, "§69 o Worker da partida está vivo")
	_place(worker, MID_ROUTE_A)
	await _advance(0.1)
	var gap_before := _planar_gap(invaders[0].global_position, CORE_PLANAR)
	var health_before := worker_state.health
	# A rota do ponto A passa exatamente por (-2, 0, 5): o invasor atravessa o Worker.
	await _advance(1.2)
	var gap_after := _planar_gap(invaders[0].global_position, CORE_PLANAR)
	_check(_close(worker_state.health, health_before),
			"§43/§69 o Worker não recebeu nenhum dano da Fera (%f → %f)"
					% [health_before, worker_state.health])
	_check(invaders[0].combat_target() == null and not invaders[0].is_engaged(),
			"§43/§45 a Fera não trocou de alvo para o Worker")
	_check(invaders[0].action_mode() == EnemyRuntime.ActionMode.ADVANCE,
			"§69 a Fera continuou ADVANCE ao passar pelo Worker, modo %s"
					% [str(invaders[0].action_mode())])
	_check(invaders[0].invasion_target() == _core,
			"§42/§69 o alvo estratégico continua sendo o Núcleo")
	_check(gap_after < gap_before - 2.0,
			"§69 o Worker não bloqueou a marcha (%f → %f)" % [gap_before, gap_after])
	_check(not worker.has_method("attack_target"),
			"§90 o Worker continua sem nenhuma capacidade de combate")


func _test_victory_flow() -> void:
	var invaders := _invasion.invaders()
	var first := invaders[0]
	var second := invaders[1]
	var essence_before := _core_state.essence
	var ore_before := _stockpile.get_amount(ORE)
	var piles_before := _piles_in_scene().size()
	var death_spot := first.global_position
	first.receive_damage(BEAST_HP)
	await _advance(0.1)
	_check(_invasion.active_invaders() == 1,
			"§75 a morte do primeiro invasor deixa 1 ativo, obtido %d"
					% _invasion.active_invaders())
	_check(_invasion.invasion_state() == InvasionController.InvasionState.ACTIVE,
			"§75 a invasão continua ACTIVE com um invasor em campo")
	_check(_text_of(_invasion_hud, "RemainingLabel") == REMAINING_ONE,
			"§39/§75 o painel acompanhou a morte, obtido %s"
					% _text_of(_invasion_hud, "RemainingLabel"))
	_check(_text_of(_combat_hud, "EnemyLabel") == BEAST_LINE_FULL,
			"§33/T11 o painel de combate passou a mostrar o segundo invasor, obtido %s"
					% _text_of(_combat_hud, "EnemyLabel"))
	var enemies := _enemies_in_scene()
	_check(enemies.size() == 1 and not is_instance_valid(first),
			"§47 a Fera derrotada saiu da cena")
	await _advance(0.1)
	var screen := _screen(death_spot + Vector3(0.0, 0.4, 0.0))
	var ray_enemy := _screen_hit(screen, ENEMY_LAYER)
	_check(ray_enemy.is_empty(),
			"§83 a camada Enemy não responde mais no lugar da Fera morta, obtido %s"
					% [ray_enemy.get("collider", null)])
	var ray_ground := _screen_hit(screen, GROUND_LAYER)
	_check(ray_ground.get("collider", null) != null,
			"§83 o Ground continua respondendo no mesmo lugar, obtido %s"
					% [ray_ground.get("collider", null)])
	second.receive_damage(BEAST_HP)
	await _advance(0.1)
	_check(_invasion.active_invaders() == 0,
			"§76 o segundo invasor derruba a contagem para 0, obtido %d"
					% _invasion.active_invaders())
	_check(_invasion.invasion_state() == InvasionController.InvasionState.VICTORY,
			"§36/§76 ACTIVE virou VICTORY")
	_check(_victory_events == 1, "§77 invasion_victory emitiu exatamente uma vez, obtido %d"
			% _victory_events)
	_check(_remaining_trace.size() == 3 and _remaining_trace[0] == 2
			and _remaining_trace[1] == 1 and _remaining_trace[2] == 0,
			"§39 a sequência de restantes foi %s" % [_remaining_trace])
	_check(_text_of(_invasion_hud, "StatusLabel") == VICTORY_STATUS,
			"§39 o painel fecha com \"%s\", obtido %s"
					% [VICTORY_STATUS, _text_of(_invasion_hud, "StatusLabel")])
	_check(_text_of(_invasion_hud, "RemainingLabel") == REMAINING_ZERO,
			"§39 contagem final 0, obtido %s" % _text_of(_invasion_hud, "RemainingLabel"))
	_check(_destroyed_events == 0 and _core_state.integrity > 0.0,
			"§36 a vitória exige o Núcleo de pé (%f)" % _core_state.integrity)
	_check(_close(_core_state.essence, essence_before),
			"§41/§78 vencer não deu Essência (%f → %f)"
					% [essence_before, _core_state.essence])
	_check(_stockpile.get_amount(ORE) == ore_before
			and _piles_in_scene().size() == piles_before,
			"§41 vencer não deu minério nem pilha (%d → %d)"
					% [ore_before, _stockpile.get_amount(ORE)])
	_check(_population_trace.is_empty(),
			"§41/§75 a morte dos invasores não mexeu em população %s" % [_population_trace])
	_press_key(KEY_F)
	await _advance(0.1)
	var after_victory := _enemies_in_scene()
	_check(_invasion.invasion_state() == InvasionController.InvasionState.VICTORY
			and after_victory.is_empty(),
			"§66/§90 depois da vitória não existe segunda invasão")
	_check(_started_events == 1, "§66 um único invasion_started para sempre, obtido %d"
			% _started_events)


# ------------------------------------------------- Movimento e ataque ao Núcleo (§12–§16)


func _test_enemy_advance_movement() -> void:
	var probe := _spawn_probe("probe_advance", SPAWN_A)
	_check(probe.action_mode() == EnemyRuntime.ActionMode.ADVANCE,
			"§11 start_invasion colocou a Fera em ADVANCE")
	_check(probe.is_physics_processing(), "§12 ADVANCE liga a física do corpo")
	var gaps: Array[float] = []
	for _sample in 4:
		gaps.append(_planar_gap(probe.global_position, CORE_PLANAR))
		await _advance(0.5)
	gaps.append(_planar_gap(probe.global_position, CORE_PLANAR))
	var decreasing := true
	for index in gaps.size() - 1:
		if gaps[index + 1] >= gaps[index]:
			decreasing = false
	_check(decreasing, "§59/§12 a distância ao Núcleo cai frame a frame, %s" % [gaps])
	_check(_close(gaps[0] - gaps[1], BEAST_SPEED * 0.5, 0.02),
			"§58 um passo de 0.5 s anda 1.25, obtido %f" % (gaps[0] - gaps[1]))
	_check(absf(probe.velocity.length() - BEAST_SPEED) < 0.01,
			"§12/§58 a velocidade é exatamente definition.move_speed, obtida %f"
					% probe.velocity.length())
	_check(probe.velocity.y == 0.0, "§12 velocity.y é zerado sempre, obtido %f" % probe.velocity.y)
	_check(_planar_offset_of(probe, CORE_PLANAR).normalized().dot(
			probe.velocity.normalized()) > 0.999,
			"§12 a marcha aponta exatamente para o Núcleo")
	_retire_probe(probe)


func _test_fps_independence() -> void:
	var closed_30 := await _advance_sample_at(30)
	var closed_120 := await _advance_sample_at(120)
	Engine.set_physics_ticks_per_second(TICKS)
	await _advance(0.1)
	_check(_close(closed_30, BEAST_SPEED, 0.05) and _close(closed_120, BEAST_SPEED, 0.05),
			"§60 os dois rates andam 2.5 em 1 s real (%f vs %f)" % [closed_30, closed_120])
	_check(_close(closed_30, closed_120, 0.02),
			"§60/§12 a posição fechada é equivalente a 30 Hz e 120 Hz (%f vs %f)"
					% [closed_30, closed_120])


func _advance_sample_at(ticks_per_second: int) -> float:
	Engine.set_physics_ticks_per_second(ticks_per_second)
	await _advance(0.15)
	var probe := _spawn_probe("probe_fps_%d" % ticks_per_second, SPAWN_A)
	var before := _planar_gap(probe.global_position, CORE_PLANAR)
	await _advance(1.0)
	var closed := before - _planar_gap(probe.global_position, CORE_PLANAR)
	_retire_probe(probe)
	await _advance(0.1)
	return closed


func _test_core_stance_geometry() -> void:
	_reset_core_integrity()
	var probe := _spawn_probe("probe_stance", SPAWN_A)
	var closest := INF
	var guard := 0
	# Para no primeiro golpe: a partir daí a Fera está definitivamente em postura, e o
	# loop não fica gastando segundos demais de suíte por causa do intervalo de 1 s.
	while _integrity_events == 0 and guard < 12 * TICKS:
		closest = minf(closest, _planar_gap(probe.global_position, CORE_PLANAR))
		await physics_frame
		guard += 1
	var stance := _planar_gap(probe.global_position, CORE_PLANAR)
	_check(_integrity_events == 1, "§61 a marcha terminou em exatamente um golpe, %d"
			% _integrity_events)
	_check(stance <= STANCE + 0.06,
			"§14 a Fera para na postura de 1.5 do Núcleo, obtido %f" % stance)
	_check(stance >= STANCE - 0.06,
			"§14/§61 ela não invade o corpo do Núcleo, obtido %f" % stance)
	_check(closest > CORE_COMBAT_RADIUS,
			"§61 a centroide nunca entrou na esfera de combate do Núcleo (mínimo %f)" % closest)
	_check(stance - CORE_COMBAT_RADIUS <= BEAST_RANGE,
			"§14 da postura a Fera ainda alcança o Núcleo (%f <= %f)"
					% [stance - CORE_COMBAT_RADIUS, BEAST_RANGE])
	_check(stance >= CORE_COMBAT_RADIUS + BEAST_RADIUS - BODY_CLEARANCE,
			"§61 as duas primitivas param separadas uma da outra (%f >= %f)"
					% [stance, CORE_COMBAT_RADIUS + BEAST_RADIUS - BODY_CLEARANCE])
	_check(_close(stance, probe.invasion_target().combat_radius
			+ probe.body_radius() + BODY_CLEARANCE, 0.06),
			"§14 postura = combat_radius + corpo + folga, obtido %f" % stance)
	_check(probe.velocity == Vector3.ZERO, "§15 quem está de postura bate parado")
	_retire_probe(probe)
	_reset_core_integrity()


func _test_first_core_hit() -> void:
	_reset_core_integrity()
	var started_at := Engine.get_physics_frames()
	var probe := _spawn_probe("probe_first_hit", PROBE_STANCE)
	var integrity_before := _core_state.integrity
	var events_before := _integrity_events
	_check(probe.action_mode() == EnemyRuntime.ActionMode.ADVANCE,
			"§16 a Fera dentro da postura continua no modo de marcha")
	await _advance(0.5)
	_check(_close(_core_state.integrity, integrity_before)
			and _integrity_events == events_before,
			"§62 antes de meio attack_interval o Núcleo não perde nada (%f)"
					% _core_state.integrity)
	var elapsed := await _seconds_until_integrity_change(integrity_before, started_at, 3.0)
	_check(elapsed > 0.9 and elapsed < 1.1,
			"§16/§62 o primeiro golpe cai um attack_interval depois da postura, obtido %f s"
					% elapsed)
	_check(_close(_core_state.integrity, integrity_before - BEAST_DAMAGE),
			"§62 o primeiro hit tira exatamente 6, obtido %f" % _core_state.integrity)
	_check(_integrity_events == events_before + 1,
			"§62/§5 um golpe, um integrity_changed, obtido %d" % _integrity_events)
	_check(probe.velocity == Vector3.ZERO, "§15 a Fera não anda enquanto golpeia o Núcleo")
	_retire_probe(probe)
	_reset_core_integrity()


func _test_continuous_core_attack() -> void:
	_reset_core_integrity()
	var probe := _spawn_probe("probe_continuous", PROBE_STANCE)
	var previous := _core_state.integrity
	var hits := 0
	while hits < 3:
		var started_at := Engine.get_physics_frames()
		var elapsed := await _seconds_until_integrity_change(previous, started_at, 1.6)
		var next := previous - BEAST_DAMAGE
		var cadence_ok := elapsed > BEAST_INTERVAL - 0.05 and elapsed < BEAST_INTERVAL + 0.15
		var value_ok := _close(_core_state.integrity, next)
		_check(cadence_ok and value_ok,
				"§63 o %dº golpe cai %f s depois do anterior e deixa %f, obtido %f"
						% [hits + 1, elapsed, next, _core_state.integrity])
		previous = next
		hits += 1
	_check(_close(_core_state.integrity, 82.0),
			"§63 a escada temporal é 94, 88 e 82, obtido %f" % _core_state.integrity)
	_check(_integrity_events == 3,
			"§63/§5 três golpes, três integrity_changed, obtido %d" % _integrity_events)
	_check(_close(probe.state.health, BEAST_HP),
			"§63 atacar o Núcleo não custa vida à Fera (%f)" % probe.state.health)
	_check(probe.action_mode() == EnemyRuntime.ActionMode.ADVANCE,
			"§63 golpear o Núcleo não troca o modo de marcha")
	_retire_probe(probe)
	_reset_core_integrity()


func _test_two_invaders_damage_rate() -> void:
	_reset_core_integrity()
	var left := _spawn_probe("probe_twin_left", PROBE_TWIN_LEFT)
	var right := _spawn_probe("probe_twin_right", PROBE_TWIN_RIGHT)
	# A janela de medição é um pouco maior que um intervalo para que o alinhamento
	# de frames de um único golpe não embaralhe a contagem: 1.5 s cobra exatamente
	# um golpe de cada, 5.0 s depois cobram exatamente dez.
	var before := _core_state.integrity
	var elapsed := await _advance_timed(1.5)
	var opening := before - _core_state.integrity
	_check(_close(opening, BEAST_DAMAGE * 2.0, 0.001),
			"§64 nos primeiros 1.5 s cada Fera cobrou 6 (%f em %f s)" % [opening, elapsed])
	_check(_integrity_events == 2,
			"§64/§5 dois golpes, dois integrity_changed, obtido %d" % _integrity_events)
	before = _core_state.integrity
	var events_before := _integrity_events
	elapsed = await _advance_timed(5.0)
	var drop := before - _core_state.integrity
	var rate := drop / elapsed
	_check(_close(drop, BEAST_DAMAGE * 10.0, 0.001),
			"§64 a janela de 5.0 s tem exatamente dez golpes de 6 (%f em %f s)"
					% [drop, elapsed])
	_check(_close(rate, 12.0, 0.01),
			"§64 os dois juntos dão 12 Integrity por segundo, obtido %f" % rate)
	_check(_integrity_events - events_before == 10,
			"§64/§5 nenhum hit duplicado nem perdido, signals %d em vez de 10"
					% (_integrity_events - events_before))
	_check(_close(_core_state.integrity, INTEGRITY - 72.0, 0.001),
			"§64 as duas Feras somadas deixam o Núcleo em 28, obtido %f"
					% _core_state.integrity)
	_check(_planar_gap(left.global_position, right.global_position)
			> 2.0 * BEAST_RADIUS - 0.05,
			"§64 os dois corpos convivem sem sobreposição (%f)"
					% _planar_gap(left.global_position, right.global_position))
	_retire_probe(left)
	_retire_probe(right)
	_reset_core_integrity()


## §18/§72: uma Fera colada no Núcleo que recebe ordem de combate deixa de cobrar
## Integrity. A prioridade é do alvo que a enfrentou, não de uma escolha do Runtime.
func _test_combat_priority_over_core() -> void:
	await _prepare_army()
	_reset_core_integrity()
	_place(_soldier, SOLDIER_STANCE)
	var arrived := await _wait_until(
			func() -> bool: return not _soldier.has_move_target(), 8.0)
	_check(arrived, "a suíte posicionou o Soldado ao lado do Núcleo")
	_selection.clear_selection()
	await _click_select(_soldier)
	var blocked := _spawn_probe("probe_priority", PROBE_STANCE)
	# O engage vem antes de qualquer await: sem ordem a Fera começaria a cobrar o
	# Núcleo no instante em que o intervalo de 1 s vence.
	blocked.engage(_soldier)
	_check(blocked.action_mode() == EnemyRuntime.ActionMode.COMBAT,
			"§18 a Fera colada no Núcleo foi puxada para COMBAT")
	# O corpo novo só existe no espaço físico depois de o servidor de física sincronizar
	# a Shape, e é dele que o raio do clique precisa achar a Fera.
	await _advance(0.05)
	# A mira é conferida antes do clique: se algo estiver na frente da Fera, a ordem
	# vira MOVE e a falsificação passaria como comportamento do produto.
	var aim := _screen(_body_screen_position(blocked.global_position))
	var aimed: Object = _screen_hit(aim, UNIT_LAYER | ENEMY_LAYER).get("collider", null)
	_check(aimed == blocked, "§72 a mira do clique caiu na Fera, obtido %s" % [aimed])
	await _right_click(_body_screen_position(blocked.global_position))
	await _advance(0.05)
	_check(_soldier.action_mode() == SoldierRuntime.ActionMode.ATTACK,
			"§72 o Soldado atacou a Fera que estava em postura do Núcleo")
	_check(blocked.combat_target() == _soldier,
			"§72/§17 o alvo de combate passou a ser o Soldado")
	var stance_gap := _planar_gap(blocked.global_position, CORE_PLANAR)
	_check(stance_gap - CORE_COMBAT_RADIUS <= BEAST_RANGE,
			"§72 ela está de fato ao alcance do Núcleo (%f)" % stance_gap)
	# §72 só vale se o duelo estiver acontecendo de verdade: o Soldado para exatamente
	# do lado de fora dos dois corpos, a 1.12 do centro da Fera, dentro do alcance dela.
	var settled := await _wait_until(
			func() -> bool: return not _soldier.has_move_target(), 4.0)
	_check(settled, "§72 o Soldado terminou de andar até a Fera")
	var ideal_strike_gap := BEAST_RADIUS + SOLDIER_RADIUS + BODY_CLEARANCE
	var actual_strike_gap := _planar_gap(_soldier.global_position, blocked.global_position)
	_check(_close(actual_strike_gap, ideal_strike_gap, 0.03),
			"§72 ele parou na postura exata de corpo contra corpo (%f vs %f)"
					% [actual_strike_gap, ideal_strike_gap])
	var integrity_before := _core_state.integrity
	await _advance(2.0)
	_check(_close(_core_state.integrity, integrity_before),
			"§18/§72 enquanto luta, a Fera não dá nenhum golpe no Núcleo (%f → %f)"
					% [integrity_before, _core_state.integrity])
	_check(_integrity_events == 0,
			"§72 zero integrity_changed durante o combate, obtido %d" % _integrity_events)
	_check(blocked.velocity == Vector3.ZERO
			and blocked.action_mode() == EnemyRuntime.ActionMode.COMBAT,
			"§72 ela fica parada no mesmo ponto de postura")
	_check(_soldier.state.health < SOLDIER_HP,
			"§72/§17 o combate aconteceu de verdade (Soldado %f)" % _soldier.state.health)
	_check(is_instance_valid(blocked), "§72 nenhuma das duas partes morreu nesse intervalo")
	blocked.disengage()
	var resumed := blocked.action_mode() == EnemyRuntime.ActionMode.ADVANCE
	_check(resumed, "§72 solta do combate, a Fera volta a ADVANCE contra o Núcleo")
	_retire_probe(blocked)


func _test_constructions_ignored() -> void:
	# §32/T13: esta cena conclui o Ninho, e o Ninho concluído é o gatilho da preparação.
	# O cronômetro fica mantido para que as Feras só apareçam pela via que a cena testa.
	_invasion.preparation_duration = HELD_PREPARATION
	await _build_nest()
	await _build_barracks()
	var nest := _construction.nest()
	var barracks := _construction.barracks()
	_check(nest != null and barracks != null, "§70 o Ninho e o Quartel de teste existem")
	if nest == null or barracks == null:
		return
	var built := nest.is_completed() and barracks.is_completed()
	_check(built, "§70 as duas obras estão prontas")
	var probe := _spawn_probe("probe_buildings", BUILDING_PROBE)
	var nest_gap_before := _planar_gap(probe.global_position, nest.global_position)
	await _advance(1.2)
	var nests := _nests_in_scene()
	var barracks_list := _barracks_in_scene()
	_check(nests.size() == 1 and barracks_list.size() == 1,
			"§44/§94 nenhuma construção saiu da cena (%d ninhos, %d quartéis)"
					% [nests.size(), barracks_list.size()])
	var intact := nest.is_completed() and barracks.is_completed()
	_check(intact, "§44 as construções não sofreram nenhum dano")
	_check(not nest.is_queued_for_deletion() and not barracks.is_queued_for_deletion(),
			"§44/§94 Ninho e Quartel não são destruíveis nesta tarefa")
	_check(probe.combat_target() == null and probe.invasion_target() == _core,
			"§44/§45 a Fera passou ao lado sem trocar de alvo")
	var mode_ok := probe.action_mode() == EnemyRuntime.ActionMode.ADVANCE \
			or probe.action_mode() == EnemyRuntime.ActionMode.COMBAT
	_check(mode_ok, "§44 o modo continua sendo o da marcha, obtido %s"
			% [str(probe.action_mode())])
	var moved_away := _planar_gap(probe.global_position, nest.global_position) > nest_gap_before
	_check(moved_away, "§44 a Fera se afastou do Ninho em direção ao Núcleo (%f → %f)"
			% [nest_gap_before, _planar_gap(probe.global_position, nest.global_position)])
	_check(not probe.has_method("assign_construction_target")
			and not probe.has_method("attack_building"),
			"§44/§94 a Fera nem sequer tem ordem contra construções")
	_retire_probe(probe)


# ------------------------------------------------------ Interceptação (§17–§21, §71–§74)


func _test_intercept_holds_one_invader() -> void:
	await _prepare_army()
	_place(_soldier, SOLDIER_INTERCEPT)
	var arrived := await _wait_until(
			func() -> bool: return not _soldier.has_move_target(), 8.0)
	_check(arrived, "§71 o Soldado foi postado na rota do Invader001")
	await _press_f_and_launch()
	await _advance(0.6)
	var invaders := _invasion.invaders()
	_check(invaders.size() == 2, "§71 a invasão de teste tem duas Feras")
	var first := invaders[0]
	var second := invaders[1]
	_selection.clear_selection()
	await _click_select(_soldier)
	_check(_soldier.action_mode() == SoldierRuntime.ActionMode.IDLE,
			"§46 antes da ordem o Soldado está IDLE, sem auto-interceptar")
	_check(not _soldier.has_move_target(), "§46/§71 nada move o Soldado por conta própria")
	await _right_click(_body_screen_position(first.global_position))
	await _advance(0.05)
	_check(_soldier.action_mode() == SoldierRuntime.ActionMode.ATTACK,
			"§71 RMB no invasor abriu ATTACK no Soldado")
	_check(first.action_mode() == EnemyRuntime.ActionMode.COMBAT,
			"§71/§17 o Invader001 virou COMBAT, obtido %s" % [str(first.action_mode())])
	_check(first.combat_target() == _soldier, "§10 o alvo de combate é o Soldado")
	var second_gap_before := _planar_gap(second.global_position, CORE_PLANAR)
	await _advance(1.5)
	var second_moved := _planar_gap(second.global_position, CORE_PLANAR)
	_check(second.action_mode() == EnemyRuntime.ActionMode.ADVANCE
			and second.combat_target() == null,
			"§47/§71 o Invader002 continua ADVANCE rumo ao Núcleo")
	_check(second_moved < second_gap_before - 2.0,
			"§47 interceptar um não congela o outro (%f → %f)"
					% [second_gap_before, second_moved])
	_check(first.invasion_target() == _core,
			"§10/§47 o alvo estratégico do interceptado continua guardado")
	var ids := _unit_ids()
	_check(ids == ["soldier_001"], "§71 apenas o Soldado está selecionado, obtido %s" % [ids])
	# O duelo real aconteceria aqui; a vida da Fera é reposta para que os próximos
	# passos medham COMBAT/ADVANCE sem que o invasor morra no meio do caminho.
	first.state.heal(BEAST_HP)
	_check(_close(first.state.health, BEAST_HP), "a suíte manteve o duelo vivo para §73/§74")


func _test_move_cancel_returns_to_advance() -> void:
	var invaders := _invasion.invaders()
	var first := invaders[0]
	_check(first.action_mode() == EnemyRuntime.ActionMode.COMBAT,
			"§19 a Fera estava em COMBAT antes do cancelamento")
	var gap_at_cancel := _planar_gap(first.global_position, CORE_PLANAR)
	_check(gap_at_cancel > STANCE + 3.0,
			"§19 a interceptação aconteceu longe do Núcleo, então a volta a marchar é visível (%f)"
					% gap_at_cancel)
	var integrity_before := _core_state.integrity
	# A ordem de MOVE vai ao Soldado selecionado; é ela que devolve a Fera à marcha.
	await _right_click(CANCEL_WALK)
	await _advance(0.05)
	_check(first.combat_target() == null, "§19 a ordem de MOVE limpou o alvo de combate")
	_check(first.action_mode() == EnemyRuntime.ActionMode.ADVANCE,
			"§19/§73 COMBAT voltou direto para ADVANCE, obtido %s"
					% [str(first.action_mode())])
	_check(first.invasion_target() == _core, "§19/§20 o alvo do Núcleo nunca foi perdido")
	var gap_before := _planar_gap(first.global_position, CORE_PLANAR)
	await _advance(0.6)
	var gap_after := _planar_gap(first.global_position, CORE_PLANAR)
	_check(gap_after < gap_before - 1.0,
			"§19 a Fera voltou a marchar de fato (%f → %f)" % [gap_before, gap_after])
	_check(_close(_core_state.integrity, integrity_before),
			"§19/§72 nenhuma chicotada de dano no cancelamento")


func _test_soldier_death_resumes_advance() -> void:
	var invaders := _invasion.invaders()
	var first := invaders[0]
	_check(_soldier != null and is_instance_valid(_soldier),
			"§74 o Soldado ainda está em campo para ser derrotado aqui")
	await _right_click(_body_screen_position(first.global_position))
	await _advance(0.1)
	_check(first.action_mode() == EnemyRuntime.ActionMode.COMBAT
			and first.combat_target() == _soldier,
			"§74 o combate estava acontecendo antes da morte do Soldado")
	var soldier_state := _soldier.state
	var population_before := _core_state.population
	_population_trace.clear()
	_soldier.receive_damage(SOLDIER_HP * 10.0)
	await _advance(0.2)
	_check(first.combat_target() == null, "§20 o alvo morto saiu do combate")
	_check(first.action_mode() == EnemyRuntime.ActionMode.ADVANCE,
			"§20/§74 a Fera retomou ADVANCE contra o Núcleo, obtido %s"
					% [str(first.action_mode())])
	var gap_before := _planar_gap(first.global_position, CORE_PLANAR)
	await _advance(0.6)
	var gap_after := _planar_gap(first.global_position, CORE_PLANAR)
	_check(gap_after < gap_before - 1.0,
			"§20 ela voltou a fechar distância (%f → %f)" % [gap_before, gap_after])
	_check(_core_state.population == population_before - 1,
			"§21 a população caiu exatamente uma casa (%d → %d)"
					% [population_before, _core_state.population])
	_check(_population_trace.size() == 1 and _population_trace[0] == population_before - 1,
			"§21/§74 um único evento de população na morte do Soldado, obtido %s"
					% [_population_trace])
	var gone := not is_instance_valid(_soldier) and soldier_state.is_dead()
	_check(gone, "§74 o Soldado derrotado saiu da cena com o State zerado")
	_check(_invasion.invasion_state() == InvasionController.InvasionState.ACTIVE,
			"§74 a morte do Soldado não encerra a invasão")


# ------------------------------------------------------- Tarefa 11 preservada (§84/§85)


func _test_passive_enemy_still_idle() -> void:
	var passive := _spawn_probe("probe_passive", PASSIVE_PROBE_SPOT, false)
	_check(passive.action_mode() == EnemyRuntime.ActionMode.IDLE,
			"§84 fora de invasão a Fera continua IDLE")
	_check(not passive.is_physics_processing(),
			"§84 sem start_invasion ela nem roda física")
	_check(passive.invasion_target() == null and passive.combat_target() == null,
			"§84 nenhum alvo é descoberto sozinho")
	await _prepare_army()
	var integrity_before := _core_state.integrity
	# 1.4 de lado: o raio do clique passa pela Fera sem o corpo do Soldado no meio.
	_place(_soldier, Vector3(-1.6, 0.0, -10.9))
	var arrived := await _wait_until(
			func() -> bool: return not _soldier.has_move_target(), 8.0)
	_check(arrived, "§84 o Soldado chegou ao lado da Fera passiva")
	var health_before := passive.state.health
	await _advance(2.0)
	_check(passive.action_mode() == EnemyRuntime.ActionMode.IDLE
			and passive.velocity == Vector3.ZERO,
			"§84 a Fera passiva não andou nem acordou")
	_check(_close(passive.state.health, health_before)
			and _close(_soldier.state.health, SOLDIER_HP),
			"§84 ninguém se auto-atacou sem ordem")
	_check(_close(_core_state.integrity, integrity_before),
			"§84 a Fera passiva não encosta no Núcleo")
	_selection.clear_selection()
	await _click_select(_soldier)
	var passive_aim := _screen(_body_screen_position(passive.global_position))
	var aimed: Object = _screen_hit(passive_aim, UNIT_LAYER | ENEMY_LAYER).get("collider", null)
	_check(aimed == passive,
			"§85 a mira do clique caiu na Fera passiva, obtido %s" % [aimed])
	await _right_click(_body_screen_position(passive.global_position))
	await _advance(0.1)
	_check(passive.action_mode() == EnemyRuntime.ActionMode.COMBAT,
			"§85 o Soldado ainda consegue engajar uma Fera fora da invasão")
	passive.disengage()
	await _advance(0.1)
	_check(passive.action_mode() == EnemyRuntime.ActionMode.IDLE,
			"§85 sem alvo de invasão o cancelamento devolve IDLE, obtido %s"
					% [str(passive.action_mode())])
	_check(not passive.is_physics_processing(),
			"§85/§12 IDLE desliga a física da Fera")
	_retire_probe(passive)


# ----------------------------------------------------------------------- Derrota (§22/§79)


func _test_defeat_flow() -> void:
	await _press_f_and_launch()
	await _advance(0.1)
	var enemies := _enemies_in_scene()
	_check(enemies.size() == 2, "§79 a invasão sem defesa começou com duas Feras")
	_check(_invasion.invasion_state() == InvasionController.InvasionState.ACTIVE,
			"§79 o estado é ACTIVE")
	var first_drop := await _seconds_until_integrity_change(INTEGRITY,
			Engine.get_physics_frames(), 12.0)
	_check(first_drop > 0.0,
			"§79 o Núcleo começou a perder Integrity em %f s" % first_drop)
	var destroyed_at := await _wait_until(
			func() -> bool: return _core_state.is_destroyed(), 40.0)
	_check(destroyed_at, "§79 sem defesa a Integrity chegou a 0")
	_check(_core_state.integrity == 0.0, "§54/§79 o clamp deixou o zero exato")
	_check(_destroyed_events == 1, "§55 destroyed uma única vez, obtido %d" % _destroyed_events)
	_check(_defeat_events == 1,
			"§80 invasion_defeat emitiu exatamente uma vez, obtido %d" % _defeat_events)
	_check(_invasion.invasion_state() == InvasionController.InvasionState.DEFEAT,
			"§25/§37 o estado fechou em DEFEAT")
	_check(_text_of(_invasion_hud, "StatusLabel") == DEFEAT_STATUS,
			"§39 o painel mostra \"%s\", obtido %s"
					% [DEFEAT_STATUS, _text_of(_invasion_hud, "StatusLabel")])
	var survivors := _enemies_in_scene()
	_check(not survivors.is_empty(), "§22/§37 a derrota não apaga os invasores vivos")
	await _advance(5.0)
	_check(_close(_core_state.integrity, 0.0),
			"§81 cinco segundos depois a Integrity continua 0, obtido %f"
					% _core_state.integrity)
	_check(_destroyed_events == 1 and _defeat_events == 1,
			"§80 nada reemitiu destruição nem derrota (%d/%d)"
					% [_destroyed_events, _defeat_events])
	var stopped := true
	for enemy in survivors:
		if not is_instance_valid(enemy):
			continue
		if enemy.velocity != Vector3.ZERO \
				or enemy.action_mode() != EnemyRuntime.ActionMode.IDLE:
			stopped = false
	_check(stopped, "§22/§81 todos os invasores pararam com velocity ZERO")
	_check(_core.is_inside_tree() and is_instance_valid(_core)
			and not _core.is_queued_for_deletion(),
			"§23/§82 o CoreRuntime continua na árvore depois da derrota")
	_check(_core.core_state() == _core_state, "§23 o State do Núcleo é o mesmo de sempre")
	var children_before := _scene.get_child_count()
	await _advance(1.0)
	var still_alive := _scene.get_child_count() == children_before \
			and _scene.is_inside_tree() and not _scene.is_queued_for_deletion()
	_check(still_alive,
			"§94 a cena seguiu viva um segundo depois: nada de congelar, menu ou reinício")
	var ui_children := _scene.get_node("UI").get_child_count()
	# §83/T13: a contagem de painéis é literal e mudou porque o aviso de ameaça é um
	# painel novo. Nada de Game Over: antes eram 8, agora 8 debug + 1 aviso.
	# §94/T14: cresceu de novo por um motivo do mesmo tipo — o painel de evolução é a
	# legenda do Nv.2, não uma tela de vitória. A guarda continua exata (nada de ">="):
	# 8 debug + 1 aviso + 1 evolução. Game Over, Victory screen e credits continuariam
	# aparecendo aqui como um filho extra e o teste falharia do mesmo jeito.
	_check(ui_children == 10,
			"§94 nenhum painel de Game Over apareceu, filhos de UI = %d" % ui_children)
	var second := _invasion.invaders()[1]
	second.receive_damage(BEAST_HP)
	await _advance(0.1)
	_check(_invasion.invasion_state() == InvasionController.InvasionState.DEFEAT
			and _victory_events == 0,
			"§36 matar invasor depois da derrota não converte em vitória")


# --------------------------------------------------------------- End-to-end (§86/§87)


func _test_end_to_end_defense() -> void:
	var enemies := _enemies_in_scene()
	_check(enemies.is_empty() and _core_state.population == 1,
			"§86 a campanha defensiva abre sem inimigo e com 1 Worker")
	# §32/T13: o Ninho desta cena é construído no meio do caminho e, desde a Tarefa 13,
	# concluí-lo abre a preparação. A contagem fica mantida para que a largada aconteça
	# no fim da campanha, exatamente como nas versões anteriores da suíte.
	_invasion.preparation_duration = HELD_PREPARATION
	_set_essence(20.0)
	_press_key(KEY_I)
	await _advance(0.4)
	_worker2 = _workers_in_scene()[1] if _workers_in_scene().size() == 2 else null
	_check(_worker2 != null and _core_state.population == 2, "§86-1 o segundo Worker chegou")

	await _mine_with_two_workers(_rock_with_id(FIRST_ORE_ROCK_ID))
	_check(_stockpile.get_amount(ORE) == 3,
			"§86-2 a primeira rocha rendeu 3 minério, obtido %d" % _stockpile.get_amount(ORE))

	_press_key(KEY_B)
	await _advance(0.2)
	var nest := _construction.nest()
	_check(nest != null, "§86-3 B abriu o Ninho com a invasão ainda por vir")
	if nest == null:
		return
	_place(_worker, Vector3(NEST_POINT.x + 1.5, 0.0, NEST_POINT.z + 0.9))
	_place(_worker2, Vector3(NEST_POINT.x + 1.5, 0.0, NEST_POINT.z - 0.9))
	await _advance(0.1)
	_selection.clear_selection()
	await _click_select(_worker)
	await _shift_click_select(_worker2)
	await _right_click(nest.global_position)
	var nest_done := await _wait_until(func() -> bool: return nest.is_completed(), 30.0)
	_check(nest_done, "§86-3 os Workers construíram o Ninho")
	# §32/T13: o Ninho caiu pronto e a partida inteira entrou em preparação — sem F,
	# sem chamada direta, sem nenhum botão novo.
	_check(_invasion.invasion_state() == InvasionController.InvasionState.PREPARATION,
			"§32/T13 a campanha real entrou em PREPARATION sozinha")
	_check(_enemies_in_scene().is_empty(),
			"§27/T13 a preparação da campanha real ainda não tem Fera nenhuma")

	await _mine_with_two_workers(_rock_with_id(SECOND_ORE_ROCK_ID))
	_check(_stockpile.get_amount(ORE) == 3, "§86-4 a segunda rocha rendeu mais 3 minério")

	_set_essence(20.0)
	_press_key(KEY_K)
	await _advance(0.2)
	var barracks := _construction.barracks()
	_check(barracks != null, "§86-5 K abriu o Quartel")
	if barracks == null:
		return
	_place(_worker, Vector3(BARRACKS_POINT.x + 1.5, 0.0, BARRACKS_POINT.z + 0.9))
	_place(_worker2, Vector3(BARRACKS_POINT.x + 1.5, 0.0, BARRACKS_POINT.z - 0.9))
	await _advance(0.1)
	_selection.clear_selection()
	await _click_select(_worker)
	await _shift_click_select(_worker2)
	await _right_click(barracks.global_position)
	var barracks_done := await _wait_until(func() -> bool: return barracks.is_completed(), 30.0)
	_check(barracks_done, "§86-5 a obra do Quartel terminou")

	_set_essence(20.0)
	_press_key(KEY_R)
	await _advance(0.4)
	_soldier = _recruitment.soldier()
	_check(_soldier != null and _core_state.population == 3, "§86-6 R recrutou o Soldado")
	if _soldier == null:
		return
	var integrity_ok := _close(_core_state.integrity, INTEGRITY)
	_check(integrity_ok, "§86 o Núcleo chega à invasão inteiro, obtido %f"
			% _core_state.integrity)

	var started_at := Engine.get_physics_frames()
	# §15/T13: no meio da preparação já aberta, o F da campanha não pula nada. A largada
	# vem em seguida pelo mesmo portão do zero.
	_press_key(KEY_F)
	await _advance(0.1)
	_check(_invasion.invasion_state() == InvasionController.InvasionState.PREPARATION,
			"§15/T13 o F dentro da preparação não adiantou a invasão")
	await _launch_invasion_now()
	var invaders := _enemies_in_scene()
	_check(invaders.size() == 2, "§86-7 F lançou as duas Feras na campanha real")
	var first := invaders[0]
	var second := invaders[1]
	var contact := await _wait_until(
			func() -> bool: return _core_state.integrity < INTEGRITY, 20.0)
	_check(contact, "§86/§79 o Núcleo sofreu dano sem ninguém mandar")
	_selection.clear_selection()
	await _click_select(_soldier)
	var selected := _unit_ids() == ["soldier_001"]
	_check(selected, "§86-8 o Soldado foi selecionado para a defesa")
	await _right_click(_body_screen_position(first.global_position))
	await _advance(0.05)
	_check(first.action_mode() == EnemyRuntime.ActionMode.COMBAT,
			"§86-8 o Soldado interceptou o Invader001")
	_check(second.action_mode() == EnemyRuntime.ActionMode.ADVANCE,
			"§47/§86-8 o Invader002 seguiu avançando sozinho")
	var first_id := first.get_instance_id()
	var first_died := await _wait_until(
			func() -> bool: return not is_instance_id_valid(first_id), 30.0)
	_check(first_died and _invasion.active_invaders() == 1,
			"§86-9 o Invader001 caiu e restou 1 invasor")
	var integrity_mid := _core_state.integrity
	_check(integrity_mid < INTEGRITY and integrity_mid > 0.0,
			"§78/§86 a campanha real pode apanhar e ainda ter Núcleo de pé (%f)" % integrity_mid)
	var second_state := second.state
	# Sem clique no invasor: ele não é selecionável e o clique limparia a ordem. O
	# próprio RMB no corpo dele troca o alvo do Soldado que já estava comandado.
	await _right_click(_body_screen_position(second.global_position))
	await _advance(0.05)
	var retargeted := _soldier.current_attack_target() == second \
			and second.action_mode() == EnemyRuntime.ActionMode.COMBAT
	_check(retargeted,
			"§49/§86-10 o novo RMB trocou o alvo manualmente, sem auto-retarget")
	var second_id := second.get_instance_id()
	var second_died := await _wait_until(
			func() -> bool: return not is_instance_id_valid(second_id), 40.0)
	_check(second_died, "§86-11 o Invader002 também caiu")
	_check(second_state.is_dead(), "§86-11 o State da segunda Fera ficou em zero")
	var won := _invasion.active_invaders() == 0 \
			and _invasion.invasion_state() == InvasionController.InvasionState.VICTORY
	_check(won, "§36/§86-12 a campanha terminou em VICTORY")
	_check(_victory_events == 1, "§77/§86 vitória emitida uma vez, obtido %d" % _victory_events)
	# A Fera chamava queue_free() no próprio frame de física: o Soldado só percebe a
	# perda do alvo no processo seguinte.
	await _advance(0.4)
	_check(_soldier.action_mode() == SoldierRuntime.ActionMode.IDLE
			and _soldier.current_attack_target() == null,
			"§86-12 o Soldado voltou a IDLE sem alvo")
	var defense := {}
	defense["invasion_seconds"] = _physics_seconds_since(started_at)
	defense["soldier_health"] = _soldier.state.health
	defense["core_integrity"] = _core_state.integrity
	defense["population"] = _core_state.population
	_defense_report = defense
	print("[INFO] §86 defesa real: Integrity final %f, HP do Soldado %f, invasão em %f s, "
			% [defense["core_integrity"], defense["soldier_health"],
			defense["invasion_seconds"]]
			+ "população %d" % defense["population"])
	_check(_core_state.population == 3, "§86/§21 população final 3 (2 Workers + Soldado)")
	_check(_core_state.integrity > 0.0, "§86/§78 o Núcleo sobreviveu à defesa")


# ------------------------------------------------------------------------ Infraestrutura


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
	# §14/§16/T13: o F passou a abrir a PREPARATION de 60 s. Esta suíte exercita a
	# invasão em si, então o harness encurta o mesmo @export que a produção usa.
	_invasion.preparation_duration = HARNESS_PREPARATION
	_deposit = _scene.get_node("World/DungeonRoot/Deposit001") as ResourceDepositRuntime
	_core = _scene.get_node("World/DungeonRoot/MainCore") as CoreRuntime
	_worker = _scene.get_node("World/DungeonRoot/Worker001") as WorkerRuntime
	_core_hud = _scene.get_node("UI/CoreDebugPanel")
	_combat_hud = _scene.get_node("UI/CombatDebugPanel")
	_invasion_hud = _scene.get_node("UI/InvasionDebugPanel")
	_warning_hud = _scene.get_node("UI/InvasionWarningPanel")
	_stockpile = _deposit.stockpile
	_core_state = _core.core_state()
	# A geração passiva de Essência é congelada: recompensa falsa não pode passar por ela.
	_core.set_process(false)
	_integrity_events = 0
	_destroyed_events = 0
	_started_events = 0
	_victory_events = 0
	_defeat_events = 0
	_remaining_trace.clear()
	_population_trace.clear()
	_probes.clear()
	_soldier = null
	_worker2 = null
	Engine.set_physics_ticks_per_second(TICKS)
	_core_state.integrity_changed.connect(_on_integrity_changed)
	_core_state.destroyed.connect(_on_core_destroyed)
	_core_state.population_changed.connect(_on_population_changed)
	_invasion.invasion_started.connect(_on_invasion_started)
	_invasion.invasion_victory.connect(_on_invasion_victory)
	_invasion.invasion_defeat.connect(_on_invasion_defeat)
	_invasion.active_invaders_changed.connect(_on_active_invaders_changed)


func _on_integrity_changed(_current: float, _maximum: float) -> void:
	_integrity_events += 1


func _on_core_destroyed() -> void:
	_destroyed_events += 1


func _on_population_changed(current: int, _capacity: int) -> void:
	_population_trace.append(current)


func _on_invasion_started(_invaders: Array) -> void:
	_started_events += 1


func _on_invasion_victory() -> void:
	_victory_events += 1


func _on_invasion_defeat() -> void:
	_defeat_events += 1


func _on_active_invaders_changed(current: int) -> void:
	_remaining_trace.append(current)


func _free_scene() -> void:
	_probes.clear()
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
	_core_hud = null
	_combat_hud = null
	_invasion_hud = null
	_warning_hud = null
	_worker = null


## Sonda de teste: usa exatamente a mesma cena, Definition e State da produção, mas é
## criada pela suíte para medir um comportamento isolado.
func _spawn_probe(id: String, spot: Vector3, invade := true) -> EnemyRuntime:
	var definition := _enemy_definition()
	var probe := ENEMY_SCENE.instantiate() as EnemyRuntime
	probe.name = "Probe_%s" % id
	probe.setup(definition, EnemyState.new(definition, id))
	_dungeon.add_child(probe)
	probe.global_position = spot
	if invade:
		probe.start_invasion(_core)
	_probes.append(probe)
	return probe


func _retire_probe(probe: EnemyRuntime) -> void:
	_probes.erase(probe)
	probe.stand_down()
	_dungeon.remove_child(probe)
	probe.free()


## §51 não existe nenhuma API de reparo no produto. A suíte repõe a Integrity escrevendo
## o campo público do State, apenas para medir cada janela de dano a partir de 100.
func _reset_core_integrity(value: float = INTEGRITY) -> void:
	_core_state.integrity = value
	_integrity_events = 0
	_destroyed_events = 0


func _prepare_army() -> void:
	_set_essence(20.0)
	_press_key(KEY_I)
	await _advance(0.4)
	_worker2 = _workers_in_scene()[1] if _workers_in_scene().size() == 2 else null
	_check(_worker2 != null and _core_state.population == 2, "a campanha de teste tem 2 Workers")
	await _build_barracks()
	var barracks := _construction.barracks()
	if barracks == null:
		_check(false, "o Quartel de teste não abriu")
		_finish()
		return
	_check(barracks.is_completed(), "o Quartel de teste foi concluído")
	_set_essence(20.0)
	_press_key(KEY_R)
	await _advance(0.4)
	_soldier = _recruitment.soldier()
	if _soldier == null:
		_check(false, "a suíte não conseguiu recrutar o Soldado")
		_finish()
		return
	_check(_close(_core_state.integrity, INTEGRITY),
			"§41 preparar o exército não mexeu na Integrity (%f)" % _core_state.integrity)


func _build_nest() -> void:
	if _construction.nest() != null:
		return
	_stockpile.add_resource(_iron_ore(), 3)
	_press_key(KEY_B)
	await _advance(0.2)
	var nest := _construction.nest()
	if nest != null:
		nest.state.apply_work(NEST_WORK)
		await _advance(0.1)


func _build_barracks() -> void:
	if _construction.barracks() != null:
		return
	_stockpile.add_resource(_iron_ore(), 3)
	_press_key(KEY_K)
	await _advance(0.2)
	var barracks := _construction.barracks()
	if barracks != null:
		barracks.state.apply_work(BARRACKS_WORK)
		await _advance(0.1)


## Um turno completo: esgotar a rocha, coletar a pilha e entregar no depósito.
func _mine_with_two_workers(rock: RockRuntime) -> void:
	if rock == null:
		_check(false, "§86 a rocha de minério da campanha não foi encontrada")
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
	_check(depleted, "§86 a rocha %s foi esgotada pelos dois Workers" % rock_id)
	var pile := await _wait_for_pile(6.0)
	_check(pile != null, "§86 a rocha %s virou uma pilha" % rock_id)
	if pile == null:
		return
	await _right_click(pile.global_position)
	var loaded := await _wait_until(func() -> bool: return _total_cargo() == 3, 25.0)
	_check(loaded, "§86 os Workers encheram a carga de 3, obtido %d" % _total_cargo())
	var delivered := await _wait_until(func() -> bool: return _total_cargo() == 0, 40.0)
	_check(delivered, "§86 a carga chegou ao depósito")


## Quantos segundos reais se passaram desde `started_at` até a Integrity mudar, ou -1.
func _seconds_until_integrity_change(
		before: float, started_at: int, max_seconds: float) -> float:
	var limit := int(max_seconds * Engine.get_physics_ticks_per_second())
	var ticks := 0
	while _close(_core_state.integrity, before) and ticks < limit:
		await physics_frame
		ticks += 1
	if _close(_core_state.integrity, before):
		return -1.0
	return float(Engine.get_physics_frames() - started_at) \
			/ float(Engine.get_physics_ticks_per_second())


func _advance_timed(seconds: float) -> float:
	var ticks := int(ceil(seconds * Engine.get_physics_ticks_per_second()))
	for _tick in maxi(ticks, 1):
		await physics_frame
	return float(ticks) / float(Engine.get_physics_ticks_per_second())


func _physics_seconds_since(started_at: int) -> float:
	return float(Engine.get_physics_frames() - started_at) \
			/ float(Engine.get_physics_ticks_per_second())


func _new_core_state() -> CoreState:
	return CoreState.new(load(CORE_DEFINITION_PATH) as CoreDefinition)


func _enemy_definition() -> EnemyDefinition:
	return load(ENEMY_DEFINITION_PATH) as EnemyDefinition


func _iron_ore() -> ResourceDefinition:
	return load(IRON_ORE_PATH) as ResourceDefinition


func _set_essence(value: float) -> void:
	var difference := value - _core_state.essence
	if difference > 0.0:
		_core_state.add_essence(difference)
	elif difference < 0.0:
		_core_state.consume_essence(-difference)


func _stance_separation() -> float:
	var a := SPAWN_A - CORE_PLANAR
	var b := SPAWN_B - CORE_PLANAR
	var point_a := CORE_PLANAR + a.normalized() * STANCE
	var point_b := CORE_PLANAR + b.normalized() * STANCE
	return _planar_gap(point_a, point_b)


func _planar_offset_of(unit: Node3D, target: Vector3) -> Vector3:
	var offset := target - unit.global_position
	offset.y = 0.0
	return offset


# ------------------------------------------------------------------- Consultas de mundo


func _enemies_in_scene() -> Array[EnemyRuntime]:
	var found: Array[EnemyRuntime] = []
	for child in _dungeon.get_children():
		if child is EnemyRuntime and not child.is_queued_for_deletion():
			found.append(child as EnemyRuntime)
	return found


func _workers_in_scene() -> Array[WorkerRuntime]:
	var found: Array[WorkerRuntime] = []
	for child in _dungeon.get_children():
		if child is WorkerRuntime and not child.is_queued_for_deletion():
			found.append(child as WorkerRuntime)
	return found


func _nests_in_scene() -> Array[NestRuntime]:
	var found: Array[NestRuntime] = []
	for child in _dungeon.get_children():
		if child is NestRuntime:
			found.append(child as NestRuntime)
	return found


func _barracks_in_scene() -> Array[BarracksRuntime]:
	var found: Array[BarracksRuntime] = []
	for child in _dungeon.get_children():
		if child is BarracksRuntime:
			found.append(child as BarracksRuntime)
	return found


func _rocks_in_scene() -> Array[RockRuntime]:
	var found: Array[RockRuntime] = []
	for child in _dungeon.get_children():
		if child is RockRuntime and not child.is_queued_for_deletion():
			found.append(child as RockRuntime)
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


func _ground_body_at(point: Vector3) -> String:
	var hit := (_scene.get_viewport().world_3d.direct_space_state
			.intersect_ray(PhysicsRayQueryParameters3D.create(
					Vector3(point.x, 6.0, point.z), Vector3(point.x, 0.0, point.z),
					GROUND_LAYER)))
	return String(hit.collider.name) if not hit.is_empty() else "<nada>"


func _shape_clear_at(point: Vector3, radius: float, mask: int) -> bool:
	return not _sphere_hits(Vector3(point.x, 0.8, point.z), radius, mask)


func _sphere_hits(point: Vector3, radius: float, mask: int) -> bool:
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	var parameters := PhysicsShapeQueryParameters3D.new()
	parameters.shape = sphere
	parameters.transform = Transform3D(Basis.IDENTITY, point)
	parameters.collision_mask = mask
	return not (_scene.get_viewport().world_3d.direct_space_state
			.intersect_shape(parameters, 8).is_empty())


## A rota é validada fisicamente: a linha reta até a postura não cruza rocha, pilha,
## construção nem unidade, e um corpo do raio real da Fera cabe em cada amostra dela.
func _route_ray_clear(from: Vector3) -> bool:
	var target := _route_end(from)
	var hit := (_scene.get_viewport().world_3d.direct_space_state
			.intersect_ray(PhysicsRayQueryParameters3D.create(
					Vector3(from.x, 0.6, from.z), Vector3(target.x, 0.6, target.z),
					OBSTACLES | UNIT_LAYER)))
	return hit.is_empty()


func _route_body_clear(from: Vector3) -> bool:
	var target := _route_end(from)
	for sample in 32:
		var point := from.lerp(target, float(sample) / 31.0)
		if not _shape_clear_at(point, BEAST_RADIUS, OBSTACLES | UNIT_LAYER):
			return false
	return true


func _route_end(from: Vector3) -> Vector3:
	return CORE_PLANAR + (from - CORE_PLANAR).normalized() * (STANCE - 0.2)


## Folga entre o ponto de largada e um canteiro/depósito: nem o spawn nem o corpo da
## Fera em postura inicial podem sentar em cima de uma obra do jogador.
func _site_margin(from: Vector3, site: Vector3, half: float) -> float:
	return _planar_gap(from, site) - BEAST_RADIUS - half


# ---------------------------------------------------------------------- Input e tela


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


func _screen_hit(screen_position: Vector2, mask: int) -> Dictionary:
	var origin := _camera.project_ray_origin(screen_position)
	var direction := _camera.project_ray_normal(screen_position)
	return _scene.get_viewport().world_3d.direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(origin, origin + direction * 1000.0, mask))


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


## §14/T13: o F da Tarefa 12 virou atalho da preparação. Para esta suíte, que exercita
## a invasão em si, "apertar F" só termina quando o cronômetro já largou as Feras.
func _press_f_and_launch() -> void:
	_press_key(KEY_F)
	var launched := await _wait_until(
			func() -> bool:
				return _invasion.invasion_state() == InvasionController.InvasionState.ACTIVE,
			3.0)
	_check(launched, "§14/T13 o F abriu a preparação e o cronômetro largou a invasão")


## §32/§12/T13: nas cenas que constroem o Ninho antes da largada, o gatilho automático
## já abriu uma preparação mantida. A suíte então entra pelo mesmo portão por onde o
## cronômetro entra quando o zero chega — nenhum caminho de spawn paralelo.
func _launch_invasion_now() -> void:
	_check(_invasion.invasion_state() == InvasionController.InvasionState.PREPARATION,
			"§32/T13 o Ninho concluído abriu a preparação desta cena")
	_check(_enemies_in_scene().is_empty(), "§27/T13 nenhuma Fera nasce antes do zero")
	_check(_invasion.start_invasion(),
			"§12/T13 a largada reusa start_invasion(), sem duplicar o spawn")
	await _advance(0.05)


# --------------------------------------------------------- Leitura de fontes e HUD


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


func _instance_fields(instance: Object) -> Array[String]:
	var fields: Array[String] = []
	for property in instance.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			fields.append(String(property.name))
	return fields


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


func _count_files(path: String, pattern: String) -> int:
	var directory := DirAccess.open(path)
	if directory == null:
		return -1
	directory.list_dir_begin()
	var count := 0
	var entry := directory.get_next()
	while not entry.is_empty():
		if not directory.current_is_dir() \
				and not entry.ends_with(".uid") \
				and entry.match(pattern):
			count += 1
		entry = directory.get_next()
	directory.list_dir_end()
	return count


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


func _check(condition: bool, label: String) -> void:
	_asserts += 1
	if condition:
		print("[PASS] %s" % label)
	else:
		_failures += 1
		print("[FAIL] %s" % label)


func _finish() -> void:
	print("---- invasion tests finished: %d asserts, %d failure(s) ----"
			% [_asserts, _failures])
	quit(1 if _failures > 0 else 0)
