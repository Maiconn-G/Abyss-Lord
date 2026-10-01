extends SceneTree

# Tarefa 15 — Consolidação pós-MVP e fundação profissional de construções.
#
# Esta suíte não pede conteúdo novo: ela prova que a base compartilhada de obra
# (ConstructionDefinition / ConstructionState / ConstructionRuntime) carrega os MESMOS
# números e o MESMO loop que as classes separadas carregavam. Ninho continua 3 minério e
# 4.0 de trabalho, Quartel continua 3 minério e 6.0, o bônus continua 4, e o fluxo
# completo Core Lv.1 → Ninho → PREPARATION → Quartel → Soldado → Invasão → Nv.2 fecha
# na cena real.
#
# §61: nada aqui obriga o código a seguir o GDD. As divergências de design estão
# documentadas em docs/POST_MVP_AUDIT.md; os asserts abaixo protegem o comportamento
# atual da partida, que é o que está funcionando.
#
# Três blocos, nesta ordem:
#   1) a base isolada — Definition, State e Runtime testados sem cena nenhuma;
#   2) o GameMain real — as duas obras, os dois Workers, a invasão e a evolução;
#   3) guardas de escopo — nenhuma Factory, nenhum Manager, nenhum Autoload.
#
# Convenção das suítes anteriores, mantida aqui: o input entra pelo InputMap e pelos
# raycasts reais, e nada da produção joga sozinho. O que o harness faz é funding
# (estoque e Essência doados para a medição caber na janela) e, no fim, o dano que
# derruba as Feras — caminho já estabelecido por test_invasion.gd, porque o duelo em si
# pertence a test_combat.gd e a Tarefa 15 não muda regra de combate.

const MAIN_SCENE := preload("res://game/GameMain.tscn")
const NEST_SCENE := preload("res://world/dungeon/rooms/nest/NestRuntime.tscn")
const BARRACKS_SCENE := preload("res://world/dungeon/rooms/barracks/BarracksRuntime.tscn")

const NEST_DEFINITION_PATH := "res://data/rooms/abyss_nest.tres"
const BARRACKS_DEFINITION_PATH := "res://data/rooms/abyss_barracks.tres"
const IRON_ORE_PATH := "res://data/resources/iron_ore.tres"
const SOLDIER_DEFINITION_PATH := "res://data/units/soldiers/abyss_soldier.tres"
const CORE_1_PATH := "res://data/core/core_level_1.tres"
const CORE_2_PATH := "res://data/core/core_level_2.tres"

const CONSTRUCTION_DEFINITION_SOURCE := "res://core/definitions/construction_definition.gd"
const NEST_DEFINITION_SOURCE := "res://core/definitions/nest_definition.gd"
const BARRACKS_DEFINITION_SOURCE := "res://core/definitions/barracks_definition.gd"
const CONSTRUCTION_STATE_SOURCE := "res://core/state/construction_state.gd"
const NEST_STATE_SOURCE := "res://core/state/nest_state.gd"
const BARRACKS_STATE_SOURCE := "res://core/state/barracks_state.gd"
const CONSTRUCTION_RUNTIME_SOURCE := "res://world/dungeon/construction/construction_runtime.gd"
const NEST_RUNTIME_SOURCE := "res://world/dungeon/rooms/nest/nest_runtime.gd"
const BARRACKS_RUNTIME_SOURCE := "res://world/dungeon/rooms/barracks/barracks_runtime.gd"
const CONSTRUCTION_CONTROLLER_SOURCE := "res://systems/construction/construction_controller.gd"
const GAME_MAIN_SOURCE := "res://game/game_main.gd"
const PRODUCTION_DIRS := ["res://camera", "res://core", "res://game", "res://systems",
		"res://ui", "res://units", "res://world"]

const NEST_POINT := Vector3(-5, 0, -5)
const BARRACKS_POINT := Vector3(-10, 0, -5)
const NEST_WORK := 4.0
const BARRACKS_WORK := 6.0
const BUILD_COST := 3
const NEST_BONUS := 4
const BASE_CAPACITY := 8
const WORKER_SPEED := 1.0
const RECRUIT_COST := 15.0
const WORKER_COST := 20.0
const EVOLUTION_COST := 25.0
const BEAST_HP := 48.0
const CAPACITY_LV2 := 12
const RATE_TOLERANCE := 0.12
const WORK_TOLERANCE := 0.35
const ORE := &"iron_ore"
const NEST_NAME := "Ninho Abissal"
const BARRACKS_NAME := "Quartel Abissal"
const WARNING_TITLE := "AMEAÇA DETECTADA"
const NV2_LINE := "NÚCLEO NV.2"
const MVP_LINE := "MVP CONCLUÍDO"

var _failures := 0
var _asserts := 0
var _frames := 0
var _scene: Node
var _dungeon: Node3D
var _camera: Camera3D
var _selection: SelectionController
var _construction: ConstructionController
var _invocation: WorkerInvocationController
var _recruitment: SoldierRecruitmentController
var _invasion: InvasionController
var _evolution: CoreEvolutionController
var _deposit: ResourceDepositRuntime
var _core: CoreRuntime
var _core_state: CoreState
var _stockpile: ResourceStockpileState
var _worker: WorkerRuntime
var _worker2: WorkerRuntime
var _nest: NestRuntime
var _barracks: BarracksRuntime
var _nest_hud: Node
var _military_hud: Node
var _core_hud: Node
var _invasion_hud: Node
var _warning_hud: Node
var _evolution_hud: Node
var _nest_built := 0
var _nest_completed := 0
var _barracks_built := 0
var _barracks_completed := 0
var _state_completions := 0
var _preparation_events := 0
var _started_events := 0
var _victory_events := 0
var _recruited_events := 0
var _mvp_events := 0
var _capacity_trace: Array[String] = []


func _initialize() -> void:
	_run_all()


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > 120000:
		_check(false, "timeout: a suíte de consolidação não terminou")
		_finish()
	return false


func _run_all() -> void:
	await process_frame
	_test_construction_definition_base()
	_test_nest_definition_inheritance()
	_test_barracks_definition_inheritance()
	_test_no_tres_migration()
	_test_construction_state_work()
	_test_construction_state_invalid_work()
	_test_construction_state_completion_once()
	_test_construction_state_shape()
	_test_nest_state_layer()
	_test_barracks_state_layer()
	await _test_construction_runtime_base()
	await _test_runtime_layers_keep_their_scenes()

	_boot_scene()
	await _advance(0.2)
	_test_scene_before_anything()
	await _test_nest_site_end_to_end()
	await _test_one_worker_builds_nest()
	await _test_nest_completed_and_preparation()
	await _test_bonus_does_not_duplicate()
	await _test_barracks_site_end_to_end()
	await _test_two_workers_build_barracks()
	await _test_soldier_recruitment_unlocked()
	await _test_invasion_and_evolution_in_the_same_world()
	await _test_world_numbers_after_mvp()
	_free_scene()
	_test_no_scene_left_behind()
	_test_scope_guards()
	_finish()


# ============================================================= Bloco 1 — a base isolada


## §42: a base existe, é Resource e tem exatamente os três campos de obra. Nada de
## efeito, nada de tipo de sala, nada de identificador — isso é o que a torna compartilhável.
func _test_construction_definition_base() -> void:
	var base := load(CONSTRUCTION_DEFINITION_SOURCE) as GDScript
	_check(base != null and base.can_instantiate(), "§42 ConstructionDefinition é um script carregável")
	var probe := base.new() as ConstructionDefinition
	_check(probe is Resource, "§42 ConstructionDefinition extends Resource")
	_check(_script_fields(CONSTRUCTION_DEFINITION_SOURCE)
			== ["build_resource", "build_cost", "work_required"],
			"§42 a base expõe exatamente os 3 campos de obra")
	_check(probe.build_cost == BUILD_COST, "§42 build_cost padrão 3, obtido %d" % probe.build_cost)
	_check(_close(probe.work_required, NEST_WORK),
			"§42 work_required padrão 4.0, obtido %f" % probe.work_required)
	_check(probe.build_resource == null, "§42 nenhum recurso padrão inventado na base")
	_check(not probe.has_signal("construction_completed"),
			"§42 a Definition é dado, não emite signal")
	_check(base.get_base_script() == null, "§42 ConstructionDefinition tem Resource como base direta")


## §43: o Ninho passa a herdar, sem perder nada do que já era seu.
func _test_nest_definition_inheritance() -> void:
	var definition := load(NEST_DEFINITION_PATH) as NestDefinition
	_check(definition != null, "§43 abyss_nest.tres continua carregando")
	if definition == null:
		return
	_check(definition is ConstructionDefinition, "§43 NestDefinition é uma ConstructionDefinition")
	_check((load(NEST_DEFINITION_SOURCE) as GDScript).get_base_script()
			== load(CONSTRUCTION_DEFINITION_SOURCE),
			"§43 a base declarada de NestDefinition é ConstructionDefinition")
	_check(_script_fields(NEST_DEFINITION_SOURCE)
			== ["nest_type_id", "display_name", "population_capacity_bonus",
					"build_resource", "build_cost", "work_required"],
			"§43 o Ninho declara 3 campos próprios e herda os 3 de obra, obtido %s"
					% [_script_fields(NEST_DEFINITION_SOURCE)])
	_check(definition.nest_type_id == &"abyss_nest", "§43 nest_type_id abyss_nest preservado")
	_check(definition.display_name == NEST_NAME, "§43 display_name preservado")
	_check(definition.population_capacity_bonus == NEST_BONUS,
			"§43/§68 population_capacity_bonus continua 4, obtido %d"
					% definition.population_capacity_bonus)
	_check(definition.build_cost == BUILD_COST,
			"§43/§68 build_cost continua 3, obtido %d" % definition.build_cost)
	_check(_close(definition.work_required, NEST_WORK),
			"§43/§68 work_required continua 4.0, obtido %f" % definition.work_required)
	_check(definition.build_resource == _iron_ore(),
			"§43 build_resource herdado aponta para o mesmo iron_ore")


## §44: o Quartel herda a mesma base e mantém o trabalho maior, que sempre foi dele.
func _test_barracks_definition_inheritance() -> void:
	var definition := load(BARRACKS_DEFINITION_PATH) as BarracksDefinition
	_check(definition != null, "§44 abyss_barracks.tres continua carregando")
	if definition == null:
		return
	_check(definition is ConstructionDefinition, "§44 BarracksDefinition é uma ConstructionDefinition")
	_check(_script_fields(BARRACKS_DEFINITION_SOURCE)
			== ["barracks_type_id", "display_name", "soldier_definition",
					"build_resource", "build_cost", "work_required"],
			"§44 o Quartel declara 3 campos próprios e herda os 3 de obra, obtido %s"
					% [_script_fields(BARRACKS_DEFINITION_SOURCE)])
	_check(definition.barracks_type_id == &"abyss_barracks", "§44 barracks_type_id preservado")
	_check(definition.soldier_definition == _soldier_definition(),
			"§44 a Definition do Soldado continuou sendo própria do Quartel")
	_check(definition.build_cost == BUILD_COST,
			"§44/§68 build_cost continua 3, obtido %d" % definition.build_cost)
	_check(_close(definition.work_required, BARRACKS_WORK),
			"§44/§68 work_required continua 6.0, obtido %f" % definition.work_required)
	# §68: o valor de 6.0 é do Quartel, não um efeito colateral da base. Uma Definition
	# criada em código, sem .tres, tem de nascer com o padrão histórico da classe.
	var bare := BarracksDefinition.new()
	_check(_close(bare.work_required, BARRACKS_WORK),
			"§68/§12 BarracksDefinition.new() sem .tres nasce com 6.0, obtido %f"
					% bare.work_required)
	_check(_close((ConstructionDefinition.new() as ConstructionDefinition).work_required, NEST_WORK),
			"§68 a base continua com o padrão 4.0, sem contaminação")


## §12: a refatoração foi de código, não de dados. Os .tres não foram reescritos nem
## migrados à mão, e ainda assim produzem os mesmos números de sempre.
func _test_no_tres_migration() -> void:
	var nest_text := _source(NEST_DEFINITION_PATH)
	var barracks_text := _source(BARRACKS_DEFINITION_PATH)
	_check(nest_text.contains("build_cost = 3") and nest_text.contains("work_required = 4.0"),
			"§12 abyss_nest.tres conserva 3 / 4.0 escritos, sem migração")
	_check(barracks_text.contains("build_cost = 3")
			and barracks_text.contains("work_required = 6.0"),
			"§12 abyss_barracks.tres conserva 3 / 6.0 escritos, sem migração")
	_check(not nest_text.contains("barracks") and not barracks_text.contains("nest_type_id"),
			"§12 nenhum dado de uma sala vazou para a outra")
	# §9/T20 nomeia o caminho exato da terceira Definition (`res://data/rooms/abyss_mine.tres`).
	# T21 acrescenta a quarta (`abyss_fungal_farm.tres`), citada no mesmo contrato. O que a
	# guarda proíbe continua sendo sala inventada, não a contagem: uma sala com nome e valores
	# escritos no contrato deixa de ser inventada quando o contrato passa a citá-la.
	_check(_files_with_extension("res://data/rooms", ".tres")
			== ["abyss_barracks.tres", "abyss_fungal_farm.tres", "abyss_mine.tres",
					"abyss_nest.tres"],
			"§12/§2 T15, §9 T20 e §9 T21: as Definitions da campanha, nenhuma sala inventada")


## §45: a regra de obra vive uma vez. Com uma Definition sintética, o State base anda
## exatamente como andava nos dois States separados.
func _test_construction_state_work() -> void:
	var definition := ConstructionDefinition.new() as ConstructionDefinition
	definition.build_resource = _iron_ore()
	definition.build_cost = BUILD_COST
	definition.work_required = NEST_WORK
	var state := ConstructionState.new(definition, "probe_001")
	_check(_close(state.remaining_work, NEST_WORK),
			"§45 remaining_work nasce do work_required (%f)" % state.remaining_work)
	_check(state.instance_id == "probe_001", "§45 instance_id guardado uma única vez")
	_check(state.definition == definition, "§45 o State referencia a Definition")
	_check(not state.is_completed(), "§45 canteiro nasce incompleto")
	var progress: Array[String] = []
	state.work_changed.connect(
			func(remaining: float, total: float) -> void:
				progress.append("%f/%f" % [remaining, total]))
	state.apply_work(1.0)
	_check(_close(state.remaining_work, 3.0), "§45 apply_work(1) leva 4.0 a 3.0")
	_check(progress == ["3.000000/4.000000"], "§45 work_changed emite (remaining, total)")
	state.apply_work(0.5)
	_check(_close(state.remaining_work, 2.5), "§45 trabalho fracionário acumula")
	_check(progress.size() == 2, "§45 um work_changed por trabalho aplicado")


## §46: trabalho inválido continua sendo ignorado, sem emitir nada.
func _test_construction_state_invalid_work() -> void:
	var state := ConstructionState.new(ConstructionDefinition.new(), "probe_002")
	var emitted: Array[int] = []
	state.work_changed.connect(func(_r: float, _t: float) -> void: emitted.append(1))
	state.apply_work(0.0)
	state.apply_work(-1.0)
	_check(_close(state.remaining_work, NEST_WORK),
			"§46 apply_work(0) e (-1) não alteram o progresso (%f)" % state.remaining_work)
	_check(emitted.is_empty(), "§46 trabalho inválido não emite work_changed")


## §47: a conclusão é um evento único, e trabalho depois dela não reabre a obra.
## As contagens são Arrays porque lambda de GDScript captura local por valor — um `+=`
## dentro do callback não alcançaria a variável de fora.
func _test_construction_state_completion_once() -> void:
	var state := ConstructionState.new(ConstructionDefinition.new(), "probe_003")
	var completions: Array[int] = []
	var changes: Array[int] = []
	state.construction_completed.connect(func() -> void: completions.append(1))
	state.work_changed.connect(func(_r: float, _t: float) -> void: changes.append(1))
	state.apply_work(10.0)
	_check(_close(state.remaining_work, 0.0), "§47 o trabalho extra é truncado em zero, nunca negativo")
	_check(state.is_completed(), "§47 is_completed() verdadeiro ao zerar")
	_check(completions.size() == 1,
			"§47 construction_completed disparou uma vez (%d)" % completions.size())
	state.apply_work(2.0)
	state.apply_work(-2.0)
	_check(completions.size() == 1,
			"§47 nenhum segundo disparo depois de concluir (%d)" % completions.size())
	_check(changes.size() == 1, "§47 obra concluída não emite work_changed (%d)" % changes.size())
	_check(_close(state.remaining_work, 0.0), "§47 o progresso não recomeça")
	# Uma Definition sem trabalho já nasce concluída, e não emite conclusão fantasma.
	var zero_definition := ConstructionDefinition.new() as ConstructionDefinition
	zero_definition.work_required = 0.0
	var zero_state := ConstructionState.new(zero_definition, "probe_004")
	var zero_events: Array[int] = []
	zero_state.construction_completed.connect(func() -> void: zero_events.append(1))
	_check(zero_state.is_completed(), "§45 work_required 0.0 nasce concluído")
	_check(zero_events.is_empty(), "§45 nenhum signal de conclusão no construtor")


## A base só guarda o que a obra é: identidade, Definition e trabalho restante.
func _test_construction_state_shape() -> void:
	var state := ConstructionState.new(ConstructionDefinition.new(), "probe_005")
	_check(state is RefCounted, "§13 ConstructionState é RefCounted, não Node")
	_check(_instance_fields(state) == ["definition", "instance_id", "remaining_work"],
			"§13/§14 exatamente 3 campos na base, sem completed duplicado")
	_check(_has_signal(state, "work_changed") and _has_signal(state, "construction_completed"),
			"§45 os dois signals continuam na base")
	for forbidden in ["health", "population", "essence", "cargo", "completed",
			"nest_id", "barracks_id", "room_type", "effect"]:
		_check(not _instance_fields(state).has(forbidden),
				"§13/§25 a base de obra não guarda %s" % forbidden)


## §48: NestState continua existindo, continua sendo a classe do Ninho e herda a regra.
func _test_nest_state_layer() -> void:
	var definition := _nest_definition()
	var state := NestState.new(definition, "nest_001")
	_check(state is ConstructionState, "§48 NestState é uma ConstructionState")
	_check(state.definition == definition, "§48/§17 a base aceita a Definition do Ninho")
	_check(_close(state.remaining_work, NEST_WORK),
			"§48/§68 Ninho continua exigindo 4.0, obtido %f" % state.remaining_work)
	_check(state.nest_id == "nest_001", "§48 nest_id continua respondendo")
	_check(state.nest_id == state.instance_id,
			"§15 nest_id lê o instance_id único, não um segundo valor")
	var events: Array[int] = []
	state.construction_completed.connect(func() -> void: events.append(1))
	state.apply_work(4.0)
	_check(events.size() == 1,
			"§48 o comportamento herdado chegou igual, %d conclusão(ões)" % events.size())
	_check(state.is_completed(), "§48 is_completed() continua derivado do trabalho")
	_check(_instance_fields(state)
			== ["nest_id", "definition", "instance_id", "remaining_work"],
			"§13/§15 a camada do Ninho só acrescenta o alias, obtido %s"
					% [_instance_fields(state)])


## §49: idem para o Quartel, com o trabalho de 6.0.
func _test_barracks_state_layer() -> void:
	var definition := _barracks_definition()
	var state := BarracksState.new(definition, "barracks_001")
	_check(state is ConstructionState, "§49 BarracksState é uma ConstructionState")
	_check(_close(state.remaining_work, BARRACKS_WORK),
			"§49/§68 Quartel continua exigindo 6.0, obtido %f" % state.remaining_work)
	_check(state.barracks_id == "barracks_001", "§49 barracks_id continua respondendo")
	_check(state.barracks_id == state.instance_id, "§16 barracks_id lê o instance_id da base")
	var signals: Array[int] = []
	state.work_changed.connect(func(_r: float, _t: float) -> void: signals.append(1))
	for _step in 6:
		state.apply_work(1.0)
	_check(state.is_completed() and signals.size() == 6,
			"§49 seis aplicações inteiras, seis sinais, obtido %d" % signals.size())
	_check(_instance_fields(state)
			== ["barracks_id", "definition", "instance_id", "remaining_work"],
			"§13/§16 a camada do Quartel só acrescenta o alias, obtido %s"
					% [_instance_fields(state)])
	_check(NestState.new(_nest_definition(), "nest_002") is ConstructionState,
			"§15/§16 construtores públicos preservados: NestState.new(definition, id)")
	_check(BarracksState.new(definition, "barracks_002") is ConstructionState,
			"§16 BarracksState.new(definition, id) continua sendo a porta de entrada")


## §50: a base de Runtime é StaticBody3D com dois visuais e troca um pelo outro a partir
## do State — sem frame, sem polling, sem saber que é Ninho ou Quartel.
func _test_construction_runtime_base() -> void:
	var site := NEST_SCENE.instantiate() as ConstructionRuntime
	root.add_child(site)
	await _advance(0.05)
	_check(site is ConstructionRuntime, "§50 a cena do Ninho instancia uma ConstructionRuntime")
	_check(site.get_class() == "StaticBody3D", "§50 a base continua StaticBody3D")
	_check(site.find_child("ConstructionVisual", true, false) is Node3D,
			"§50 ConstructionVisual existe na estrutura")
	_check(site.find_child("CompletedVisual", true, false) is Node3D,
			"§50 CompletedVisual existe na estrutura")
	var construction := site.find_child("ConstructionVisual", true, false) as Node3D
	var completed := site.find_child("CompletedVisual", true, false) as Node3D
	site.setup(_nest_definition(), NestState.new(_nest_definition(), "nest_probe"))
	_check(not site.is_completed(), "§50 canteiro recém-criado não está concluído")
	_check(construction.visible and not completed.visible,
			"§50 setup() mostra o canteiro e esconde o prédio")
	site.state.apply_work(NEST_WORK)
	_check(site.is_completed(), "§50 is_completed() é derivado do State, sem flag própria")
	await _advance(0.05)
	_check(not construction.visible and completed.visible,
			"§50 a conclusão do State trocou o visual sozinha, sem chamada externa")
	_check(site.state.construction_completed.is_connected(site.refresh_visual),
			"§50 é a base que liga construction_completed a refresh_visual, uma vez")
	_check(not _instance_fields(site).has("remaining_work")
			and not _instance_fields(site).has("work_required"),
			"§50 o Runtime não duplica o trabalho — quem manda é o State, obtido %s"
					% [_instance_fields(site)])
	site.free()


## §51/§52: as duas classes concretas continuam existindo e continuam distintas. A
## herança tirou regra duplicada, não identidade nem visual.
func _test_runtime_layers_keep_their_scenes() -> void:
	var nest := NEST_SCENE.instantiate() as NestRuntime
	var barracks := BARRACKS_SCENE.instantiate() as BarracksRuntime
	_check(nest is ConstructionRuntime, "§51 NestRuntime é uma ConstructionRuntime")
	_check(barracks is ConstructionRuntime, "§52 BarracksRuntime é uma ConstructionRuntime")
	_check(nest.get_class() == "StaticBody3D" and barracks.get_class() == "StaticBody3D",
			"§51/§52 nenhuma classe de Node nova foi inventada no meio do caminho")
	_check(not ResourceLoader.exists("res://world/dungeon/construction/ConstructionRuntime.tscn"),
			"§21 não existe cena genérica compartilhada — cada sala mantém a sua")
	_check(_instance_fields(nest) == ["definition", "state",
			"_construction_visual", "_completed_visual"],
			"§51/§52 os Runtimes concretos não declaram campo algum, obtido %s"
					% [_instance_fields(nest)])
	_check(_instance_fields(nest) == _instance_fields(barracks),
			"§51/§52 Ninho e Quartel têm a mesma lista de campos — herança, não cópia")
	_check(not _source(NEST_RUNTIME_SOURCE).contains("remaining_work")
			and not _source(BARRACKS_RUNTIME_SOURCE).contains("apply_work"),
			"§8 nenhuma regra de obra sobreviveu nas camadas finas")
	_check(_mesh_names(nest).has("NestDome") and _mesh_names(barracks).has("Banner"),
			"§21/§76 os visuais continuam sendo ovo abissal e quartel com estandarte")
	_check(_mesh_count(nest) != _mesh_count(barracks),
			"§21 as duas cenas têm contagens de mesh próprias (%d vs %d)"
					% [_mesh_count(nest), _mesh_count(barracks)])
	nest.free()
	barracks.free()


## O bloco 1 instancia Resources e Scenes fora da árvore e o bloco 2 monta o GameMain
## inteiro. Nada pode sobrar: teste que deixa órfão na árvore contamina a próxima suíte.
func _test_no_scene_left_behind() -> void:
	var survivors := 0
	for child in root.get_children():
		if String(child.name) == "GameMain":
			survivors += 1
	_check(not is_instance_valid(_scene), "§60 a cena do bloco 2 foi liberada")
	_check(survivors == 0, "§60 não ficou nenhum GameMain órfão na árvore, %d" % survivors)


# ============================================================ Bloco 2 — o GameMain real


func _boot_scene() -> void:
	_scene = MAIN_SCENE.instantiate()
	root.add_child(_scene)
	await _advance(0.2)
	_dungeon = _scene.get_node("World/DungeonRoot") as Node3D
	_camera = _scene.get_node("World/CameraRig/Camera3D") as Camera3D
	_selection = _scene.get_node("Systems/SelectionController") as SelectionController
	_construction = _scene.get_node("Systems/ConstructionController") as ConstructionController
	_invocation = _scene.get_node("Systems/WorkerInvocationController") as WorkerInvocationController
	_recruitment = _scene.get_node("Systems/SoldierRecruitmentController") as SoldierRecruitmentController
	_invasion = _scene.get_node("Systems/InvasionController") as InvasionController
	_evolution = _scene.get_node("Systems/CoreEvolutionController") as CoreEvolutionController
	_deposit = _scene.get_node("World/DungeonRoot/Deposit001") as ResourceDepositRuntime
	_core = _scene.get_node("World/DungeonRoot/MainCore") as CoreRuntime
	_worker = _scene.get_node("World/DungeonRoot/Worker001") as WorkerRuntime
	_nest_hud = _scene.get_node("UI/ConstructionDebugPanel")
	_military_hud = _scene.get_node("UI/MilitaryDebugPanel")
	_core_hud = _scene.get_node("UI/CoreDebugPanel")
	_invasion_hud = _scene.get_node("UI/InvasionDebugPanel")
	_warning_hud = _scene.get_node("UI/InvasionWarningPanel")
	_evolution_hud = _scene.get_node("UI/CoreEvolutionDebugPanel")
	_stockpile = _deposit.stockpile
	_core_state = _core.core_state()
	# Funding de teste: a geração de 1/s do Núcleo não paga o loop inteiro dentro da
	# janela de medição. Desligar a geração não muda regra nenhuma — §68 proíbe mexer nos
	# números, e aqui eles só são adiantados pelo harness.
	_core.set_process(false)
	_construction.nest_built.connect(func(_n: NestRuntime) -> void: _nest_built += 1)
	_construction.nest_completed.connect(func(_n: NestRuntime) -> void: _nest_completed += 1)
	_construction.barracks_built.connect(func(_b: BarracksRuntime) -> void: _barracks_built += 1)
	_construction.barracks_completed.connect(
			func(_b: BarracksRuntime) -> void: _barracks_completed += 1)
	_invasion.preparation_started.connect(func(_d: float) -> void: _preparation_events += 1)
	_invasion.invasion_started.connect(func(_i: Array) -> void: _started_events += 1)
	_invasion.invasion_victory.connect(func() -> void: _victory_events += 1)
	_recruitment.soldier_recruited.connect(func(_s: SoldierRuntime) -> void: _recruited_events += 1)
	_evolution.mvp_completed.connect(func() -> void: _mvp_events += 1)
	_core_state.population_capacity_changed.connect(
			func(current: int, capacity: int) -> void:
				_capacity_trace.append("%d/%d" % [current, capacity]))


func _test_scene_before_anything() -> void:
	_check(_nests_in_scene().is_empty() and _barracks_in_scene().is_empty(),
			"§53/§54 a partida abre sem nenhuma obra")
	_check(_stockpile.get_amount(ORE) == 0, "§53 estoque começa em 0")
	_check(_core_state.population_capacity_bonus == 0, "§58 bônus começa em 0")
	_check(_core_state.get_population_capacity() == BASE_CAPACITY,
			"§68 capacidade base continua 8, obtido %d" % _core_state.get_population_capacity())
	_check(_close(_core_state.definition.population_capacity, BASE_CAPACITY),
			"§68 core_level_1.tres intacto (%f)" % _core_state.definition.population_capacity)
	_check(_invasion.invasion_state() == InvasionController.InvasionState.NOT_STARTED,
			"§57 a ameaça ainda não foi anunciada")
	_check(not _evolution.is_unlocked(), "§57 sem vitória não existe evolução")
	_check(_workers_in_scene().size() == 1, "§70 exatamente 1 Worker no início")


## §53: 3 Minério → B → canteiro. O consumo e a criação vêm do controller real, pela
## tecla real, e o canteiro já é montado pela base compartilhada.
func _test_nest_site_end_to_end() -> void:
	_press_key(KEY_B)
	await _advance(0.1)
	_check(_nests_in_scene().is_empty(), "§53 B sem Minério não abre canteiro")
	_check(_nest_built == 0, "§56 nenhum nest_built na recusa")
	_stockpile.add_resource(_iron_ore(), BUILD_COST)
	await _advance(0.1)
	_press_key(KEY_B)
	await _advance(0.2)
	var nests := _nests_in_scene()
	_check(nests.size() == 1, "§53 B com 3 Minério abre exatamente 1 canteiro")
	if nests.is_empty():
		_finish()
		return
	_nest = nests[0]
	_state_completions = 0
	_nest.state.construction_completed.connect(func() -> void: _state_completions += 1)
	_check(_nest_built == 1 and _nest_completed == 0,
			"§56 nest_built=1 e nest_completed=0 no canteiro (%d/%d)"
					% [_nest_built, _nest_completed])
	_check(_construction.nest() == _nest, "§56 o accessor nest() aponta para a obra real")
	_check(_stockpile.get_amount(ORE) == 0, "§53 os 3 Minério foram consumidos")
	_check(_nest.global_position.is_equal_approx(NEST_POINT),
			"§53 o canteiro nasceu no NestBuildPoint")
	_check(_close(_nest.state.remaining_work, NEST_WORK),
			"§68 o canteiro exige 4.0 herdado da base, obtido %f" % _nest.state.remaining_work)
	_check(_nest.state is NestState and _nest.state is ConstructionState,
			"§48 o State da cena é NestState e, por herança, ConstructionState")
	_check(_nest.definition is ConstructionDefinition,
			"§43 o Runtime expõe a Definition pela base, sem casting no meio do caminho")
	_check(_visual_pair(_nest, true), "§51 canteiro visível, prédio escondido")
	_check(_text_of(_nest_hud, "StatusLabel") == "%s: em construção" % NEST_NAME,
			"§53 o HUD de obra lê o canteiro como \"%s: em construção\"" % NEST_NAME)
	_check(_core_state.population_capacity_bonus == 0, "§58 canteiro não dá bônus")
	_check(_core_state.get_population_capacity() == BASE_CAPACITY,
			"§58 capacidade continua 8 no canteiro, obtido %d"
					% _core_state.get_population_capacity())
	_check(_text_of(_core_hud, "PopulationLabel") == "Population: 1 / 8",
			"§53 HUD do núcleo segue 1 / 8, obtido %s"
					% _text_of(_core_hud, "PopulationLabel"))
	_check(_invasion.invasion_state() == InvasionController.InvasionState.NOT_STARTED,
			"§57 canteiro não anuncia invasão, só a conclusão")


## §53 + §55 (parte 1): um Worker a pé, pela ordem RMB real, aplicando 1.0 trabalho/s.
func _test_one_worker_builds_nest() -> void:
	_selection.clear_selection()
	await _click_select(_worker)
	_check(_selection.selected_unit == _worker, "§55 o Worker foi selecionado pelo clique real")
	_right_click(_nest.global_position)
	await _advance(0.1)
	_check(_worker.action_mode() == WorkerRuntime.ActionMode.BUILD,
			"§53 RMB no canteiro colocou o Worker em BUILD")
	_check(_worker.current_construction_target() == _nest,
			"§53 o alvo é o Ninho criado pela base compartilhada")
	_check(await _wait_until(func() -> bool: return _in_range(_worker, _nest), 12.0),
			"§53 o Worker entrou em build_range")
	await _wait_until(func() -> bool: return _worker.velocity == Vector3.ZERO, 5.0)
	_check(_close(_worker.definition.work_speed, WORKER_SPEED),
			"§68 work_speed do Worker continua 1.0, obtido %f" % _worker.definition.work_speed)
	var before := _nest.state.remaining_work
	await _advance(1.0)
	var applied := before - _nest.state.remaining_work
	_check(_close(applied, WORKER_SPEED, RATE_TOLERANCE),
			"§55 um Worker aplica 1.0 trabalho por segundo, obtido %f" % applied)
	_check(await _wait_until(func() -> bool: return _nest.is_completed(), 12.0),
			"§53 o Worker sozinho terminou a obra")
	_check(_close(_nest.state.remaining_work, 0.0), "§53 remaining_work zerou")


## §53 fim + §56 + §57 + §58: conclusão, bônus e o disparo da preparação.
func _test_nest_completed_and_preparation() -> void:
	await _advance(0.2)
	_check(_nest_completed == 1, "§56 nest_completed emitido uma vez pelo controller (%d)"
			% _nest_completed)
	_check(_state_completions == 1, "§47 a State da cena concluiu uma vez (%d)" % _state_completions)
	_check(_visual_pair(_nest, false), "§51 o Ninho concluído trocou para o prédio")
	_check(_nest.collision_layer == 16, "§51 o Ninho continua na camada Construction")
	_check(_core_state.population_capacity_bonus == NEST_BONUS,
			"§58 o bônus aplicado pelo controller é 4, obtido %d"
					% _core_state.population_capacity_bonus)
	_check(_core_state.get_population_capacity() == BASE_CAPACITY + NEST_BONUS,
			"§53 8 + 4 = 12, obtido %d" % _core_state.get_population_capacity())
	_check(_capacity_trace == ["1/12"], "§56 population_capacity_changed levou 1/12, obtido %s"
			% [_capacity_trace])
	_check(_text_of(_core_hud, "PopulationLabel") == "Population: 1 / 12",
			"§53 HUD passou a 1 / 12 por signal, obtido %s"
					% _text_of(_core_hud, "PopulationLabel"))
	_check(_text_of(_nest_hud, "StatusLabel") == "%s: concluído" % NEST_NAME,
			"§53 HUD de obra anuncia \"%s: concluído\"" % NEST_NAME)
	_check(_invasion.invasion_state() == InvasionController.InvasionState.PREPARATION,
			"§57 Ninho concluído abriu PREPARATION na cena real")
	_check(_preparation_events == 1, "§57 preparation_started chegou uma vez (%d)"
			% _preparation_events)
	_check(_invasion.preparation_time_remaining() > 55.0
			and _invasion.preparation_time_remaining() <= 60.0,
			"§57/§68 o crédito de preparação continua os 60 s de produção (%f)"
					% _invasion.preparation_time_remaining())
	_check(_text_of(_warning_hud, "TitleLabel") == WARNING_TITLE,
			"§57 o aviso prévio apareceu, obtido %s" % _text_of(_warning_hud, "TitleLabel"))
	_check(_text_of(_invasion_hud, "StatusLabel").begins_with("Invasão em: "),
			"§57 o painel de invasão conta o tempo, obtido %s"
					% _text_of(_invasion_hud, "StatusLabel"))


## §58: o bônus é aplicado uma única vez pelo controller. Insistir em B, ou trabalhar
## de novo num prédio pronto, não soma nada.
func _test_bonus_does_not_duplicate() -> void:
	_press_key(KEY_B)
	_press_key(KEY_B)
	await _advance(0.2)
	_nest.state.apply_work(2.0)
	await _advance(0.4)
	_check(_nests_in_scene().size() == 1, "§58 B repetido não cria um segundo Ninho")
	_check(_stockpile.get_amount(ORE) == 0, "§58 nenhuma cobrança extra de recurso")
	_check(_core_state.population_capacity_bonus == NEST_BONUS,
			"§58 bônus continua 4, não 8/12/16, obtido %d" % _core_state.population_capacity_bonus)
	_check(_core_state.get_population_capacity() == BASE_CAPACITY + NEST_BONUS,
			"§58 capacidade continua 12, obtido %d" % _core_state.get_population_capacity())
	_check(_state_completions == 1, "§58 nenhuma conclusão extra no Ninho pronto (%d)"
			% _state_completions)
	_check(_capacity_trace == ["1/12"], "§58 nenhum sinal de capacidade repetido, obtido %s"
			% [_capacity_trace])
	_selection.clear_selection()
	await _click_select(_worker)
	_right_click(_nest.global_position)
	await _advance(0.15)
	_check(not _worker.is_building(), "§58 prédio concluído recusa ordem de construção")


## §54: 3 Minério → K → canteiro do Quartel, com o trabalho maior vindo da base.
func _test_barracks_site_end_to_end() -> void:
	_stockpile.add_resource(_iron_ore(), BUILD_COST)
	await _advance(0.1)
	_press_key(KEY_K)
	await _advance(0.2)
	var sites := _barracks_in_scene()
	_check(sites.size() == 1, "§54 K com 3 Minério abre exatamente 1 canteiro de Quartel")
	if sites.is_empty():
		_finish()
		return
	_barracks = sites[0]
	_state_completions = 0
	_barracks.state.construction_completed.connect(func() -> void: _state_completions += 1)
	_check(_barracks_built == 1 and _barracks_completed == 0,
			"§56 barracks_built=1 e barracks_completed=0 no canteiro (%d/%d)"
					% [_barracks_built, _barracks_completed])
	_check(_construction.barracks() == _barracks, "§56 o accessor barracks() aponta para a obra")
	_check(_construction.nest() == _nest, "§54 o Ninho não foi substituído no controller")
	_check(_stockpile.get_amount(ORE) == 0, "§54 os 3 Minério do Quartel foram consumidos")
	_check(_barracks.global_position.is_equal_approx(BARRACKS_POINT),
			"§54 o canteiro nasceu no BarracksBuildPoint")
	_check(_close(_barracks.state.remaining_work, BARRACKS_WORK),
			"§68 o Quartel continua exigindo 6.0, obtido %f" % _barracks.state.remaining_work)
	_check(_barracks.state is BarracksState and _barracks.state is ConstructionState,
			"§49 o State da cena é BarracksState e, por herança, ConstructionState")
	_check(_visual_pair(_barracks, true), "§52 canteiro do Quartel visível, prédio escondido")
	_check(_text_of(_military_hud, "BarracksStatusLabel")
			== "%s: em construção" % BARRACKS_NAME,
			"§54 HUD militar mostra a obra em andamento")
	_check(_core_state.population_capacity_bonus == NEST_BONUS,
			"§54 o Quartel não mexeu no bônus do Ninho (%d)" % _core_state.population_capacity_bonus)
	_check(not _recruitment.barracks_completed(),
			"§59 canteiro não destrava recrutamento — is_completed() responde pela base")


## §55: os dois Workers somam trabalho no mesmo alvo. A herança não serializou a obra.
func _test_two_workers_build_barracks() -> void:
	_set_essence(WORKER_COST)
	_press_key(KEY_I)
	await _advance(0.4)
	_worker2 = _invocation.summoned_worker()
	_check(_worker2 != null and _workers_in_scene().size() == 2,
			"§55 a tecla I invocou o segundo Worker (%d na cena)" % _workers_in_scene().size())
	_check(_core_state.population == 2, "§55 Population 2, obtido %d" % _core_state.population)
	_place(_worker, Vector3(BARRACKS_POINT.x + 1.5, 0.0, BARRACKS_POINT.z + 0.9))
	_place(_worker2, Vector3(BARRACKS_POINT.x + 1.5, 0.0, BARRACKS_POINT.z - 0.9))
	await _advance(0.1)
	_selection.clear_selection()
	await _click_select(_worker)
	await _shift_click_select(_worker2)
	_check(_selection.selected_units.size() == 2, "§55 os dois Workers estão selecionados")
	_right_click(_barracks.global_position)
	await _advance(0.1)
	_check(_worker.is_building() and _worker2.is_building(),
			"§55 os dois Workers constrõem o mesmo Quartel")
	_check(_worker.current_construction_target() == _barracks
			and _worker2.current_construction_target() == _barracks,
			"§55 mesmo alvo para os dois, sem branch por tipo de sala")
	_check(await _wait_until(
			func() -> bool:
				return _in_range(_worker, _barracks) and _in_range(_worker2, _barracks), 12.0),
			"§55 os dois entraram em build_range")
	await _wait_until(func() -> bool:
		return _worker.velocity == Vector3.ZERO and _worker2.velocity == Vector3.ZERO, 5.0)
	var before := _barracks.state.remaining_work
	await _advance(1.0)
	var applied := before - _barracks.state.remaining_work
	_check(_close(applied, WORKER_SPEED * 2.0, RATE_TOLERANCE),
			"§55 dois Workers aplicam ~2.0 trabalho por segundo, obtido %f" % applied)
	_check(not _barracks.is_completed(),
			"§55 a obra não fechou num instante — restante %f" % _barracks.state.remaining_work)
	var elapsed := await _time_until(func() -> bool: return _barracks.is_completed(), 12.0)
	_check(_barracks.is_completed(), "§55 a obra conjunta chegou ao fim")
	_check(_close(_barracks.state.remaining_work, 0.0), "§55 remaining_work zerou")
	_check(_close(before - applied, elapsed * WORKER_SPEED * 2.0, WORK_TOLERANCE),
			"§55 o restante (%f) foi pago a 2.0/s em %f s, cooperação sem serialização"
					% [before - applied, elapsed])
	_check(1.0 + elapsed < before,
			"§55/§68 a obra saiu antes dos %f s que um Worker sozinho levaria (%f s no total)"
					% [before, 1.0 + elapsed])


## §54 fim + §59 + §56: conclusão, barracks_completed() e o recrutamento real.
func _test_soldier_recruitment_unlocked() -> void:
	await _advance(0.2)
	_check(_visual_pair(_barracks, false), "§52 o Quartel concluído trocou para o prédio")
	_check(_state_completions == 1, "§47/§52 o Quartel concluiu uma vez (%d)" % _state_completions)
	_check(_barracks_completed == 1, "§56 barracks_completed emitido uma vez (%d)"
			% _barracks_completed)
	_check(_text_of(_military_hud, "BarracksStatusLabel")
			== "%s: concluído" % BARRACKS_NAME, "§54 HUD militar anuncia o Quartel pronto")
	_check(_core_state.population_capacity_bonus == NEST_BONUS,
			"§54 o Quartel não deu bônus populacional (%d)" % _core_state.population_capacity_bonus)
	_check(_core_state.get_population_capacity() == BASE_CAPACITY + NEST_BONUS,
			"§54 capacidade segue 12, obtido %d" % _core_state.get_population_capacity())
	_check(_recruitment.barracks_completed(),
			"§59 o recrutamento detecta a conclusão pelo método herdado")
	_check(_barracks.definition.soldier_definition == _soldier_definition(),
			"§44 a Definition do Soldado continuou própria do Quartel")
	_set_essence(RECRUIT_COST)
	await _advance(0.1)
	_check(_recruitment.can_recruit(), "§59 com Quartel pronto, Essência e vaga, pode recrutar")
	_press_key(KEY_R)
	await _advance(0.4)
	var soldiers := _soldiers_in_scene()
	_check(soldiers.size() == 1, "§59 R recrutou exatamente 1 Soldado (%d)" % soldiers.size())
	if soldiers.is_empty():
		return
	_check(_recruited_events == 1, "§56 soldier_recruited chegou uma vez (%d)" % _recruited_events)
	_check(_core_state.population == 3,
			"§68/§70 população 3 no fim do loop, obtido %d" % _core_state.population)
	_check(_text_of(_core_hud, "PopulationLabel") == "Population: 3 / 12",
			"§59 HUD do núcleo mostra 3 / 12, obtido %s"
					% _text_of(_core_hud, "PopulationLabel"))


## §60: o resto do loop — a ameaça anunciada chega, as duas Feras caem, a vitória liga a
## evolução e o Núcleo vira Nv.2 no mesmo mundo onde as obras foram construídas.
func _test_invasion_and_evolution_in_the_same_world() -> void:
	_check(_invasion.invasion_state() == InvasionController.InvasionState.PREPARATION,
			"§57/§60 a invasão continua PREPARATION antes da largada")
	var launched := _invasion.invasion_state() == InvasionController.InvasionState.ACTIVE \
			or _invasion.start_invasion()
	await _advance(0.2)
	_check(launched, "§60 a largada aceita o estado PREPARATION")
	_check(_invasion.invasion_state() == InvasionController.InvasionState.ACTIVE,
			"§60 a invasão ficou ACTIVE")
	_check(_started_events == 1, "§56/§60 invasion_started emitido uma vez (%d)" % _started_events)
	var invaders := _enemies_in_scene()
	_check(invaders.size() == 2, "§68/§70 exatamente 2 invasores na única onda (%d)"
			% invaders.size())
	if invaders.size() != 2:
		return
	invaders[0].receive_damage(BEAST_HP)
	await _advance(0.1)
	invaders[1].receive_damage(BEAST_HP)
	await _advance(0.2)
	_check(_invasion.invasion_state() == InvasionController.InvasionState.VICTORY,
			"§60 derrubar as duas Feras fecha a invasão em VICTORY")
	_check(_victory_events == 1, "§56/§60 invasion_victory emitido uma vez (%d)" % _victory_events)
	_check(_core_state.integrity > 0.0, "§60 o Núcleo sobreviveu para evoluir (%f)"
			% _core_state.integrity)
	_check(_evolution.is_unlocked(), "§60 a vitória chegou ao controller por signal")
	_set_essence(EVOLUTION_COST)
	await _advance(0.1)
	_press_key(KEY_V)
	_check(await _wait_until(func() -> bool: return _core_state.level == 2, 5.0),
			"§60 V evoluiu o Núcleo para Nv.2")
	_check(_core_state.definition.population_capacity == CAPACITY_LV2,
			"§69 base do Nv.2 continua 12, obtido %d" % _core_state.definition.population_capacity)
	_check(_core_state.population_capacity_bonus == NEST_BONUS,
			"§58/§98 o bônus do Ninho atravessa a evolução, obtido %d"
					% _core_state.population_capacity_bonus)
	_check(_core_state.get_population_capacity() == CAPACITY_LV2 + NEST_BONUS,
			"§60 capacidade efetiva 16, obtido %d" % _core_state.get_population_capacity())
	_check(_mvp_events == 1, "§56/§60 mvp_completed uma vez na cena real (%d)" % _mvp_events)
	_check(_text_of(_evolution_hud, "LevelLabel") == NV2_LINE
			and _text_of(_evolution_hud, "OfferLabel") == MVP_LINE,
			"§60 painel de evolução fecha com Nv.2 / MVP")


## O mundo depois do loop: as duas obras continuam de pé, concluídas e reconhecíveis.
func _test_world_numbers_after_mvp() -> void:
	_check(_nests_in_scene().size() == 1 and _barracks_in_scene().size() == 1,
			"§68 1 Ninho e 1 Quartel, obtido %d/%d"
					% [_nests_in_scene().size(), _barracks_in_scene().size()])
	_check(_nest.is_completed() and _barracks.is_completed(),
			"§51/§52 as duas obras seguem concluídas pela mesma regra herdada")
	_check(_visual_pair(_nest, false) and _visual_pair(_barracks, false),
			"§76 os dois visuais concluídos permanecem na tela")
	_check(_construction.nest() is NestRuntime and _construction.barracks() is BarracksRuntime,
			"§19/§20 as classes concretas continuam sendo o que o controller devolve")
	_check(_recruitment.barracks_completed(), "§59 o recrutamento continua lendo a obra pronta")
	_check(_workers_in_scene().size() == 2 and _soldiers_in_scene().size() == 1,
			"§70/§68 2 Workers e 1 Soldado, obtido %d/%d"
					% [_workers_in_scene().size(), _soldiers_in_scene().size()])
	_check(_enemies_in_scene().is_empty(), "§68 a evolução não chamou segunda invasão")
	_check(_invasion.active_invaders() == 0, "§60 nenhum invasor ativo no fim")
	_check(_nest.state.remaining_work == 0.0 and _barracks.state.remaining_work == 0.0,
			"§68 nenhum trabalho voltou a existir")
	_check(_close(_core_state.definition.max_integrity, 150.0),
			"§69 core_level_2.tres intacto, max_integrity %f" % _core_state.definition.max_integrity)
	_check(ResourceLoader.exists(CORE_1_PATH) and ResourceLoader.exists(CORE_2_PATH),
			"§68 os dois níveis de Núcleo continuam sendo dados, não subclasses")


# --------------------------------------------------------------- Guardas de escopo §22–§34


func _test_scope_guards() -> void:
	var sources := _production_sources()
	_check(not sources.is_empty(), "§22 a varredura achou os fontes de produção")
	var joined := "\n".join(sources.values())
	for forbidden in ["BuildingFactory", "RoomFactory", "ConstructionFactory",
			"BuildingRegistry", "RoomRegistry", "ConstructionManager", "BuildingManager",
			"RoomManager", "HousingManager", "PopulationManager", "UnitFactory",
			"UnitStateBase", "CharacterState", "HealthComponent", "LivingState",
			"UnitRuntimeBase", "RTSUnitBase", "MovableRuntime", "BuildingEffect",
			"EffectDefinition", "EffectSystem", "ModifierSystem", "ServiceLocator",
			"EventBus"]:
		_check(not joined.contains(forbidden),
				"§22/§25/§27/§33 nenhuma %s foi criada pela refatoração" % forbidden)
	_check(_code_of(CONSTRUCTION_CONTROLLER_SOURCE).contains("func build_nest()")
			and _code_of(CONSTRUCTION_CONTROLLER_SOURCE).contains("func build_barracks()"),
			"§23 as duas entradas continuam explícitas e nomeadas")
	_check(not _code_of(CONSTRUCTION_CONTROLLER_SOURCE).contains("_make_state")
			and not _code_of(CONSTRUCTION_CONTROLLER_SOURCE).contains("is BarracksDefinition"),
			"§23 o switch de tipo dentro do helper comum sumiu do código executável")
	_check(_code_of(CONSTRUCTION_CONTROLLER_SOURCE).contains("ConstructionState"),
			"§24 o helper recebe a base, então os dois caminhos viraram um só")
	_check(not _source(GAME_MAIN_SOURCE).contains("Factory")
			and not _source(GAME_MAIN_SOURCE).contains("Registry"),
			"§32 GameMain continua composition root, sem registrar tipos")
	_check(ProjectSettings.get_setting("autoload", {}) is Dictionary
			and (ProjectSettings.get_setting("autoload", {}) as Dictionary).is_empty(),
			"§34 nenhum autoload no projeto, nem novo nem antigo")
	for preserved in ["res://core/definitions/nest_definition.gd",
			"res://core/definitions/barracks_definition.gd",
			"res://core/state/nest_state.gd",
			"res://core/state/barracks_state.gd",
			"res://world/dungeon/rooms/nest/nest_runtime.gd",
			"res://world/dungeon/rooms/barracks/barracks_runtime.gd"]:
		_check(FileAccess.file_exists(preserved),
				"§15/§16/§19/§20 a classe concreta continua existindo: %s" % preserved)
	for base_file in [CONSTRUCTION_DEFINITION_SOURCE, CONSTRUCTION_STATE_SOURCE,
			CONSTRUCTION_RUNTIME_SOURCE]:
		_check(FileAccess.file_exists(base_file),
				"§8 a base compartilhada existe como arquivo: %s" % base_file)
	_check(FileAccess.file_exists("res://docs/POST_MVP_AUDIT.md"),
			"§62/§63/§65 a auditoria GDD × as-built está versionada")


# ---------------------------------------------------------------------- Helpers de teste


func _iron_ore() -> ResourceDefinition:
	return load(IRON_ORE_PATH) as ResourceDefinition


func _soldier_definition() -> SoldierDefinition:
	return load(SOLDIER_DEFINITION_PATH) as SoldierDefinition


func _nest_definition() -> NestDefinition:
	return load(NEST_DEFINITION_PATH) as NestDefinition


func _barracks_definition() -> BarracksDefinition:
	return load(BARRACKS_DEFINITION_PATH) as BarracksDefinition


func _set_essence(value: float) -> void:
	var difference := value - _core_state.essence
	if difference > 0.0:
		_core_state.add_essence(difference)
	elif difference < 0.0:
		_core_state.consume_essence(-difference)


func _free_scene() -> void:
	if _scene != null and is_instance_valid(_scene):
		_scene.free()
	_scene = null
	_dungeon = null
	_camera = null
	_selection = null
	_construction = null
	_invocation = null
	_recruitment = null
	_invasion = null
	_evolution = null
	_deposit = null
	_core = null
	_core_state = null
	_stockpile = null
	_worker = null
	_worker2 = null
	_nest = null
	_barracks = null


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


func _workers_in_scene() -> Array[WorkerRuntime]:
	var found: Array[WorkerRuntime] = []
	for child in _dungeon.get_children():
		if child is WorkerRuntime:
			found.append(child as WorkerRuntime)
	return found


func _soldiers_in_scene() -> Array[SoldierRuntime]:
	var found: Array[SoldierRuntime] = []
	for child in _dungeon.get_children():
		if child is SoldierRuntime:
			found.append(child as SoldierRuntime)
	return found


func _enemies_in_scene() -> Array[EnemyRuntime]:
	var found: Array[EnemyRuntime] = []
	for child in _dungeon.get_children():
		if child is EnemyRuntime and not child.is_queued_for_deletion():
			found.append(child as EnemyRuntime)
	return found


## §50/§51/§52: o par de visuais é a única evidência de obra que a base expõe. `site` é
## ConstructionRuntime, então este helper funciona para as duas salas sem saber qual é.
func _visual_pair(site: ConstructionRuntime, under_construction: bool) -> bool:
	var construction := site.find_child("ConstructionVisual", true, false) as Node3D
	var completed := site.find_child("CompletedVisual", true, false) as Node3D
	if construction == null or completed == null:
		return false
	return construction.visible == under_construction and completed.visible != under_construction


func _in_range(unit: WorkerRuntime, site: ConstructionRuntime) -> bool:
	return _planar_gap(unit.global_position, site.global_position) <= unit.build_range


func _planar_gap(from: Vector3, to: Vector3) -> float:
	var offset := to - from
	offset.y = 0.0
	return offset.length()


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


func _mesh_names(node: Node) -> Array[String]:
	var names: Array[String] = []
	for child in node.get_children():
		if child is MeshInstance3D:
			names.append(String(child.name))
		names.append_array(_mesh_names(child))
	return names


func _mesh_count(node: Node) -> int:
	var count := 0
	for child in node.get_children():
		if child is MeshInstance3D:
			count += 1
		count += _mesh_count(child)
	return count


func _files_with_extension(folder: String, extension: String) -> Array[String]:
	var found: Array[String] = []
	var directory := DirAccess.open(folder)
	if directory == null:
		return found
	directory.list_dir_begin()
	var name := directory.get_next()
	while not name.is_empty():
		if not directory.current_is_dir() and name.ends_with(extension):
			found.append(name)
		name = directory.get_next()
	directory.list_dir_end()
	found.sort()
	return found


## Varredura de fonte só em produção: as suítes citam os nomes proibidos para negá-los,
## e incluir testes no texto varrido acusaria a própria guarda.
func _production_sources() -> Dictionary:
	var collected := {}
	for folder in PRODUCTION_DIRS:
		_collect_gd_files(folder, collected)
	return collected


func _collect_gd_files(folder: String, into: Dictionary) -> void:
	var directory := DirAccess.open(folder)
	if directory == null:
		return
	directory.list_dir_begin()
	var name := directory.get_next()
	while not name.is_empty():
		var full := folder.path_join(name)
		if directory.current_is_dir():
			_collect_gd_files(full, into)
		elif name.ends_with(".gd"):
			into[full] = _source(full)
		name = directory.get_next()
	directory.list_dir_end()


func _source(path: String) -> String:
	return FileAccess.get_file_as_string(path)


## Só o que executa: o comentário do controller nomeia, em prosa, o switch que ele não
## tem mais, e uma varredura de fonte crua acusaria a própria documentação da limpeza.
func _code_of(path: String) -> String:
	var lines: Array[String] = []
	for line in _source(path).split("\n"):
		var stripped := String(line).strip_edges()
		if stripped.begins_with("#"):
			continue
		lines.append(stripped)
	return "\n".join(lines)


func _text_of(root_node: Node, label_name: String) -> String:
	var label := root_node.find_child(label_name, true, false) as Label
	if label == null:
		return "<ausente>"
	return label.text


func _script_fields(script_path: String) -> Array[String]:
	var fields: Array[String] = []
	for property in (load(script_path) as GDScript).new().get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			fields.append(String(property.name))
	return fields


func _instance_fields(instance: Object) -> Array[String]:
	var fields: Array[String] = []
	for property in instance.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			fields.append(String(property.name))
	return fields


func _has_signal(emitter: Object, signal_name: String) -> bool:
	for signal_info in emitter.get_signal_list():
		if String(signal_info.name) == signal_name:
			return true
	return false


func _close(a: float, b: float, tolerance: float = 0.001) -> bool:
	return absf(a - b) <= tolerance


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


func _time_until(condition: Callable, max_seconds: float) -> float:
	var ticks := 0
	var limit := int(max_seconds * Engine.get_physics_ticks_per_second())
	while not condition.call() and ticks < limit:
		await physics_frame
		ticks += 1
	return float(ticks) / float(Engine.get_physics_ticks_per_second())


func _check(condition: bool, label: String) -> void:
	_asserts += 1
	if condition:
		print("[PASS] %s" % label)
	else:
		_failures += 1
		print("[FAIL] %s" % label)


func _finish() -> void:
	print("---- post mvp consolidation tests finished: %d asserts, %d failure(s) ----"
			% [_asserts, _failures])
	quit(1 if _failures > 0 else 0)
