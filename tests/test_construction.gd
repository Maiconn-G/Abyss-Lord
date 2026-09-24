extends SceneTree

const MAIN_SCENE := preload("res://game/GameMain.tscn")
const NEST_SCENE := preload("res://world/dungeon/rooms/nest/NestRuntime.tscn")
const PILE_SCENE := preload("res://world/resources/ResourcePileRuntime.tscn")
const NEST_DEFINITION_PATH := "res://data/rooms/abyss_nest.tres"
const IRON_ORE_PATH := "res://data/resources/iron_ore.tres"
const CORE_DEFINITION_PATH := "res://data/core/core_level_1.tres"
const NEST_RUNTIME_PATH := "res://world/dungeon/rooms/nest/nest_runtime.gd"
const CONSTRUCTION_CONTROLLER_PATH := "res://systems/construction/construction_controller.gd"
const WORKER_RUNTIME_PATH := "res://units/workers/worker_runtime.gd"

const GROUND_LAYER := 1
const UNIT_LAYER := 2
const DIGGABLE_LAYER := 4
const RESOURCE_LAYER := 8
const CONSTRUCTION_LAYER := 16
const CLICKABLE := GROUND_LAYER | UNIT_LAYER | DIGGABLE_LAYER | RESOURCE_LAYER | CONSTRUCTION_LAYER

const BUILD_POINT := Vector3(-5, 0, -5)
const CLEAR_GROUND := Vector3(-2, 0, 0)
const FAR_GROUND := Vector3(-9, 0, -2)
const ORE_PILE_DROP := Vector3(-11, 0, -1)
const NEST_RADIUS := 1.1
const WORKER_RADIUS := 0.35
const MIN_CLEARANCE := NEST_RADIUS + WORKER_RADIUS
const ORE_ROCK_ID := "iron_ore_001"
const COMMON_ROCK_ID := "rock_001"
const NEST_NAME := "Ninho Abissal"

var _failures := 0
var _asserts := 0
var _frames := 0
var _scene: Node
var _dungeon: Node3D
var _worker: WorkerRuntime
var _camera: Camera3D
var _selection: SelectionController
var _construction: ConstructionController
var _deposit: ResourceDepositRuntime
var _floor: StaticBody3D
var _build_point: Marker3D
var _core: CoreRuntime
var _core_hud: Node
var _ore_hud: Node
var _nest_hud: Node
var _stockpile: ResourceStockpileState
var _clock: WorkClock
var _ore_rock: RockRuntime
var _nest: NestRuntime
var _completions: Array[int] = []
var _capacity_events: Array[String] = []


func _initialize() -> void:
	_run_all()


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > 60000:
		_check(false, "timeout: a suíte de construção não terminou")
		_finish()
	return false


class WorkClock extends Node:
	var ticks := 0
	var elapsed := 0.0
	var running := false

	func _physics_process(delta: float) -> void:
		if running:
			ticks += 1
			elapsed += delta

	func reset() -> void:
		ticks = 0
		elapsed = 0.0
		running = true

	func stop() -> float:
		running = false
		return elapsed


func _run_all() -> void:
	await process_frame
	_test_stockpile_consume()
	_test_stockpile_consume_insufficient()
	_test_stockpile_consume_invalid()
	_test_nest_definition()
	_test_nest_state_initial()
	_test_nest_apply_work()
	_test_nest_invalid_and_clamp()
	_test_nest_completion_signal_once()
	_test_core_state_capacity_bonus()
	await _test_nest_runtime_structure()
	await _test_construction_scenarios()
	_boot_scene()
	await _advance(0.15)
	_test_scene_layout()
	await _test_full_integration_cycle()
	await _test_common_systems_survive()
	_test_scope_guards()
	_finish()


func _iron_ore() -> ResourceDefinition:
	return load(IRON_ORE_PATH) as ResourceDefinition


func _nest_definition() -> NestDefinition:
	return load(NEST_DEFINITION_PATH) as NestDefinition


func _core_definition() -> CoreDefinition:
	return load(CORE_DEFINITION_PATH) as CoreDefinition


func _check(condition: bool, label: String) -> void:
	_asserts += 1
	if condition:
		print("[PASS] %s" % label)
	else:
		_failures += 1
		print("[FAIL] %s" % label)


func _close(a: float, b: float, tolerance: float = 0.001) -> bool:
	return absf(a - b) <= tolerance


func _advance(seconds: float) -> void:
	var ticks := int(ceil(seconds * Engine.get_physics_ticks_per_second()))
	for i in ticks:
		await physics_frame


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


func _text_of(root: Node, label_name: String) -> String:
	var label := root.find_child(label_name, true, false) as Label
	if label == null:
		return "<ausente>"
	return label.text


func _has_signal(emitter: Object, signal_name: String) -> bool:
	for signal_info in emitter.get_signal_list():
		if String(signal_info.name) == signal_name:
			return true
	return false


# ------------------------------------------------------------- Stockpile: consumo


func _test_stockpile_consume() -> void:
	var ore := _iron_ore()
	var stockpile := ResourceStockpileState.new()
	var events: Array[String] = []
	stockpile.resource_changed.connect(
			func(definition: ResourceDefinition, new_amount: int) -> void:
				events.append("%s=%d" % [definition.resource_id, new_amount]))
	stockpile.add_resource(ore, 3)
	_check(stockpile.consume_resource(ore, 3), "consume_resource(iron_ore, 3) com 3 devolve true")
	_check(stockpile.get_amount(ore.resource_id) == 0, "consumir 3 de 3 deixa o estoque em 0")
	_check(events == ["iron_ore=3", "iron_ore=0"], "consume emite resource_changed com o total novo")
	_check(not stockpile.consume_resource(ore, 1), "consumir de estoque vazio devolve false")
	_check(stockpile.get_amount(ore.resource_id) == 0, "estoque vazio permanece 0")


func _test_stockpile_consume_insufficient() -> void:
	var ore := _iron_ore()
	var stockpile := ResourceStockpileState.new()
	var events: Array[int] = []
	stockpile.resource_changed.connect(
			func(_definition: ResourceDefinition, _amount: int) -> void: events.append(1))
	stockpile.add_resource(ore, 2)
	events.clear()
	_check(not stockpile.consume_resource(ore, 3), "§44 consumo atômico: 2 não paga custo 3")
	_check(stockpile.get_amount(ore.resource_id) == 2, "§44 estoque continua 2 após a recusa")
	_check(events.is_empty(), "nenhum sinal é emitido quando o consumo é recusado")


func _test_stockpile_consume_invalid() -> void:
	var ore := _iron_ore()
	var stockpile := ResourceStockpileState.new()
	var events: Array[int] = []
	stockpile.resource_changed.connect(
			func(_definition: ResourceDefinition, _amount: int) -> void: events.append(1))
	stockpile.add_resource(ore, 3)
	events.clear()
	_check(not stockpile.consume_resource(ore, 0), "§45 consume_resource(0) devolve false")
	_check(not stockpile.consume_resource(ore, -3), "§45 consume_resource(-3) devolve false")
	_check(not stockpile.consume_resource(null, 1), "consume_resource(null, 1) devolve false")
	_check(stockpile.get_amount(ore.resource_id) == 3, "§45 consumos inválidos não alteram o estoque")
	_check(events.is_empty(), "consumos inválidos não emitem sinal")
	_check(stockpile.consume_resource(ore, 1), "consumo parcial válido funciona")
	_check(stockpile.get_amount(ore.resource_id) == 2, "1 consumido de 3 deixa 2")
	_check(not stockpile.has_method("refund"), "§36 não existe refund nesta tarefa")


# ---------------------------------------------------------------- Nest Definition


func _test_nest_definition() -> void:
	var definition := _nest_definition()
	_check(definition != null, "abyss_nest.tres carrega")
	_check(definition is Resource, "NestDefinition é um Resource")
	_check(definition.nest_type_id == &"abyss_nest", "§46 nest_type_id = abyss_nest")
	_check(definition.display_name == NEST_NAME, "§46 display_name = Ninho Abissal")
	_check(definition.build_resource == _iron_ore(), "§46 build_resource aponta para iron_ore.tres")
	_check(definition.build_cost == 3, "§46 build_cost = 3")
	_check(typeof(definition.build_cost) == TYPE_INT, "build_cost é int")
	_check(_close(definition.work_required, 4.0), "§46 work_required = 4.0")
	_check(typeof(definition.work_required) == TYPE_FLOAT, "work_required é float")
	_check(definition.population_capacity_bonus == 4, "§46 population_capacity_bonus = 4")
	_check(typeof(definition.population_capacity_bonus) == TYPE_INT, "bônus populacional é int")
	_check(_script_fields("res://core/definitions/nest_definition.gd")
			== ["nest_type_id", "display_name", "build_resource", "build_cost",
					"work_required", "population_capacity_bonus"],
			"§5 NestDefinition só expõe os 6 campos previstos")
	_check(_core_definition().population_capacity == 8,
			"§27 core_level_1.tres continua com capacidade base 8")


# ------------------------------------------------------------------- Nest State


func _test_nest_state_initial() -> void:
	var definition := _nest_definition()
	var state := NestState.new(definition, "nest_001")
	_check(state is RefCounted, "NestState estende RefCounted")
	_check(state.nest_id == "nest_001", "§47 nest_id = nest_001")
	_check(state.definition == definition, "NestState referencia a Definition")
	_check(_close(state.remaining_work, 4.0), "§47 remaining_work inicia em 4.0")
	_check(not state.is_completed(), "§47 Ninho novo não nasce concluído")
	_check(_instance_fields(state)
			== ["definition", "nest_id", "remaining_work"],
			"§7 completed é derivado, não duplicado como campo")
	_check(_has_signal(state, "work_changed"), "§9 NestState tem signal work_changed")
	_check(_has_signal(state, "construction_completed"),
			"§9 NestState tem signal construction_completed")


func _test_nest_apply_work() -> void:
	var state := NestState.new(_nest_definition(), "nest_001")
	var changes: Array[String] = []
	state.work_changed.connect(
			func(remaining: float, total: float) -> void:
				changes.append("%f/%f" % [remaining, total]))
	state.apply_work(1.0)
	_check(_close(state.remaining_work, 3.0), "§48 apply_work(1) leva 4.0 -> 3.0")
	_check(changes == ["3.000000/4.000000"], "§9 work_changed emite (remaining, total)")
	state.apply_work(0.5)
	_check(_close(state.remaining_work, 2.5), "trabalho fracionário acumula")
	_check(changes.size() == 2, "cada trabalho emite um work_changed")


func _test_nest_invalid_and_clamp() -> void:
	var state := NestState.new(_nest_definition(), "nest_001")
	var changes: Array[int] = []
	state.work_changed.connect(
			func(_remaining: float, _total: float) -> void: changes.append(1))
	state.apply_work(0.0)
	state.apply_work(-1.0)
	_check(_close(state.remaining_work, 4.0), "§50 apply_work(0) e (-1) não alteram estado")
	_check(changes.is_empty(), "trabalho inválido não emite work_changed")
	state.apply_work(100.0)
	_check(_close(state.remaining_work, 0.0), "§49 apply_work(100) trava em 0")
	_check(not (state.remaining_work < 0.0), "remaining_work nunca fica negativo")
	_check(state.is_completed(), "is_completed() verdadeiro ao zerar")
	_check(changes.size() == 1, "apenas um work_changed no clamp")


func _test_nest_completion_signal_once() -> void:
	var state := NestState.new(_nest_definition(), "nest_001")
	var completions: Array[int] = []
	state.construction_completed.connect(func() -> void: completions.append(1))
	state.apply_work(4.0)
	_check(completions == [1], "§51 construction_completed emite exatamente uma vez")
	state.apply_work(1.0)
	state.apply_work(100.0)
	_check(completions.size() == 1, "§51 apply_work depois de concluir não reemite")
	_check(_close(state.remaining_work, 0.0), "progresso concluído não regride")


# ------------------------------------------------- Capacidade do núcleo (State puro)


func _test_core_state_capacity_bonus() -> void:
	var definition := _core_definition()
	var state := CoreState.new(definition)
	_check(_has_signal(state, "population_capacity_changed"), "§30 sinal específico de capacidade")
	_check(state.population_capacity_bonus == 0, "§28 capacidade começa sem bônus")
	_check(state.get_population_capacity() == 8, "§28 8 + 0 = 8")
	state.set_population(999)
	_check(state.population == 8, "§67 set_population(999) sem Ninho trava em 8")
	var events: Array[String] = []
	state.population_capacity_changed.connect(
			func(current: int, capacity: int) -> void:
				events.append("%d/%d" % [current, capacity]))
	state.add_population_capacity_bonus(0)
	state.add_population_capacity_bonus(-3)
	_check(state.population_capacity_bonus == 0, "§33 bônus inválido não altera estado")
	_check(events.is_empty(), "§33 bônus inválido não emite sinal")
	state.add_population_capacity_bonus(4)
	_check(state.population_capacity_bonus == 4, "§33 add_population_capacity_bonus(4) aplica 4")
	_check(state.get_population_capacity() == 12, "§28 8 + 4 = 12")
	_check(events == ["8/12"], "§30 population_capacity_changed emite (população, capacidade)")
	state.set_population(999)
	_check(state.population == 12, "§67 set_population(999) com Ninho trava em 12")
	state.set_population(12)
	_check(state.population == 12, "§67 set_population(12) atinge a capacidade efetiva")
	state.set_population(-5)
	_check(state.population == 0, "população nunca fica negativa")
	_check(definition.population_capacity == 8, "§27 a Definition continua a fonte da base")


# ------------------------------------------------------------------ Nest Runtime


func _test_nest_runtime_structure() -> void:
	var nest := NEST_SCENE.instantiate() as NestRuntime
	_check(nest != null, "§52 NestRuntime.tscn instancia")
	_check(nest.get_class() == "StaticBody3D", "§10 raiz do Ninho é StaticBody3D")
	_check(nest.collision_layer == CONSTRUCTION_LAYER,
			"§13 canteiro nasce na camada Construction")
	var construction := nest.find_child("ConstructionVisual", true, false) as Node3D
	var completed := nest.find_child("CompletedVisual", true, false) as Node3D
	var collision := nest.find_child("CollisionShape3D", true, false) as CollisionShape3D
	_check(construction != null, "§52 tem ConstructionVisual")
	_check(completed != null, "§52 tem CompletedVisual")
	_check(collision != null and collision.shape != null, "§52 tem CollisionShape3D com shape")
	_check(construction.visible and not completed.visible,
			"§52 inicialmente só o canteiro está visível")
	root.add_child(nest)
	await process_frame
	nest.setup(_nest_definition(), NestState.new(_nest_definition(), "nest_001"))
	_check(construction.visible and not completed.visible, "setup mantém o canteiro visível")
	nest.state.apply_work(4.0)
	_check(not construction.visible and completed.visible,
			"§52 ao concluir o visual troca de canteiro para prédio")
	_check(not collision.disabled, "§26 collider permanece válido")
	_check(is_instance_valid(nest) and nest.get_parent() != null,
			"§11 o Runtime não é removido ao concluir")
	_check(nest.is_completed(), "Runtime reporta a conclusão")
	nest.queue_free()
	await process_frame


# ----------------------------------- Controller real: estoque 0 / 2 / 3 e duplicidade


func _test_construction_scenarios() -> void:
	var harness := Node3D.new()
	harness.name = "ConstructionHarness"
	var nests_root := Node3D.new()
	nests_root.name = "NestParent"
	harness.add_child(nests_root)
	var build_point := Marker3D.new()
	build_point.name = "HarnessBuildPoint"
	build_point.position = Vector3(500, 0, 500)
	harness.add_child(build_point)
	var controller := ConstructionController.new()
	controller.name = "HarnessController"
	harness.add_child(controller)
	root.add_child(harness)

	var ore := _iron_ore()
	var definition := _nest_definition()
	var stockpile := ResourceStockpileState.new()
	var core_state := CoreState.new(_core_definition())
	controller.setup(stockpile, definition, NEST_SCENE, build_point, nests_root)
	controller.bind_core_state(core_state)

	_check(not controller.build_nest(), "§53 com estoque 0 o controller recusa a obra")
	_check(nests_root.get_child_count() == 0, "§53 nenhum Ninho criado sem recurso")
	_check(stockpile.get_amount(ore.resource_id) == 0, "§53 estoque 0 permanece 0")

	stockpile.add_resource(ore, 2)
	_check(not controller.build_nest(), "§54 com estoque 2 a obra é recusada")
	_check(nests_root.get_child_count() == 0, "§54 nenhum Ninho com estoque insuficiente")
	_check(stockpile.get_amount(ore.resource_id) == 2, "§54 estoque continua 2")

	stockpile.add_resource(ore, 1)
	_check(controller.build_nest(), "§55 com estoque 3 a obra é criada")
	_check(nests_root.get_child_count() == 1, "§55 exatamente 1 NestRuntime criado")
	_check(stockpile.get_amount(ore.resource_id) == 0, "§35 custo pago no início: estoque vai a 0")
	_check(controller.nest() != null, "o controller expõe o Ninho construído")
	_check(controller.nest().global_position.is_equal_approx(build_point.global_position),
			"§15 Ninho instanciado na posição do build point")
	_check(core_state.get_population_capacity() == 8,
			"§34 criar o canteiro NÃO muda a capacidade")
	_check(core_state.population_capacity_bonus == 0, "§32 bônus ainda não aplicado no canteiro")

	_check(not controller.build_nest(), "§56 B novamente não cria um segundo Ninho")
	_check(nests_root.get_child_count() == 1, "§56 continua exatamente 1 Ninho")
	stockpile.add_resource(ore, 3)
	_check(not controller.build_nest(), "§56 obra existente bloqueia nova cobrança")
	_check(stockpile.get_amount(ore.resource_id) == 3, "§56 nenhum recurso é cobrado novamente")

	var nest := controller.nest()
	var completions: Array[int] = []
	nest.state.construction_completed.connect(func() -> void: completions.append(1))
	_check(not nest.is_completed(), "antes do trabalho o Ninho está em construção")
	nest.state.apply_work(4.0)
	_check(completions == [1], "§26 construction_completed dispara uma vez no controller real")
	_check(core_state.population_capacity_bonus == 4, "§32 bônus aplicado na conclusão")
	_check(core_state.get_population_capacity() == 12, "§28 capacidade efetiva vira 12")
	nest.state.apply_work(2.0)
	for i in 5:
		controller.build_nest()
	_check(core_state.population_capacity_bonus == 4, "§66 bônus não duplica")
	_check(completions.size() == 1, "nenhuma conclusão extra")
	_check(nests_root.get_child_count() == 1, "ainda 1 Ninho")
	_check(nest.is_completed(), "Ninho concluído permanece concluído")

	harness.queue_free()
	await process_frame


# ------------------------------------------------------------------------ Cena real


func _boot_scene() -> void:
	_scene = MAIN_SCENE.instantiate()
	root.add_child(_scene)
	_dungeon = _scene.get_node("World/DungeonRoot") as Node3D
	_worker = _scene.get_node("World/DungeonRoot/Worker001") as WorkerRuntime
	_camera = _scene.get_node("World/CameraRig/Camera3D") as Camera3D
	_selection = _scene.get_node("Systems/SelectionController") as SelectionController
	_construction = _scene.get_node("Systems/ConstructionController") as ConstructionController
	_deposit = _scene.get_node("World/DungeonRoot/Deposit001") as ResourceDepositRuntime
	_build_point = _scene.get_node("World/DungeonRoot/NestBuildPoint") as Marker3D
	_core = _scene.get_node("World/DungeonRoot/MainCore") as CoreRuntime
	_floor = _scene.get_node("World/Environment/TestFloorBody") as StaticBody3D
	_core_hud = _scene.get_node("UI/CoreDebugPanel")
	_ore_hud = _scene.get_node("UI/ResourceDebugPanel")
	_nest_hud = _scene.get_node("UI/ConstructionDebugPanel")
	_clock = WorkClock.new()
	_clock.name = "WorkClock"
	root.add_child(_clock)
	_stockpile = _deposit.stockpile
	for child in _dungeon.get_children():
		if child is RockRuntime and (child as RockRuntime).rock_id == ORE_ROCK_ID:
			_ore_rock = child as RockRuntime


func _test_scene_layout() -> void:
	_check(_build_point.get_class() == "Marker3D", "§14 NestBuildPoint é um Marker3D")
	_check(_build_point.global_position.is_equal_approx(BUILD_POINT),
			"§14 NestBuildPoint em (-5, 0, -5)")
	_check(_physics_nodes_under(_build_point).is_empty(),
			"§72 o build point não tem collider nem intercepta raycast")
	_check(String(ProjectSettings.get_setting("layer_names/3d_physics/layer_5"))
			== "Construction", "§13 camada 5 chama-se Construction")
	# A Tarefa 11 transformou a camada 6 de antecipação proibida em realidade: ela é a
	# camada dos inimigos. Continua sendo a última camada nomeada do projeto.
	_check(String(ProjectSettings.get_setting("layer_names/3d_physics/layer_6"))
			== "Enemies", "§13/§15 T11 a camada 6 passou a ser Enemies")
	_check(String(ProjectSettings.get_setting("layer_names/3d_physics/layer_7")).is_empty(),
			"§13 nenhuma sétima camada criada")
	_check(_count_occurrences(_source_text("res://project.godot"),
			"3d_physics/layer_") == 6, "§13 exatamente 6 camadas nomeadas")
	_check(_nests_in_scene().is_empty(), "a cena começa sem nenhum Ninho")
	_check(_stockpile.get_amount(&"iron_ore") == 0, "§70 Stockpile começa em 0")
	var screen := _camera.unproject_position(BUILD_POINT)
	_check(Rect2(Vector2.ZERO, Vector2(root.size)).has_point(screen),
			"§14 NestBuildPoint está dentro do campo da câmera")
	var hit := _screen_hit(screen, CLICKABLE)
	_check(not hit.is_empty() and hit.collider == _floor,
			"§72 antes do Ninho o clique no build point cai no chão")
	_check(_planar_gap(_build_point.global_position, _deposit.global_position) > 4.0,
			"§14 canteiro não se sobrepõe ao depósito")
	_check(_planar_gap(_build_point.global_position, _worker.global_position) > 4.0,
			"§14 canteiro longe do ponto inicial do Worker")
	_check(_planar_gap(_build_point.global_position, _ore_rock.global_position) > 6.0,
			"§14 canteiro longe da rocha de minério")
	for rock in _rocks_alive():
		_check(_segment_clear_of(rock.global_position, 1.0 + MIN_CLEARANCE,
				_deposit.global_position, _build_point.global_position),
				"§14 rota reta livre do depósito ao canteiro (rocha %s)" % rock.rock_id)
	_check(_controls_not_ignoring(_scene.get_node("UI")).is_empty(),
			"§73 todos os controles do HUD usam mouse_filter IGNORE")
	_check(_buttons_under(_scene.get_node("UI")) == 0,
			"§19 nenhum botão interativo foi criado")
	_check(_text_of(_nest_hud, "HintLabel") == "[B] Construir Ninho Abissal — 3 Minério de Ferro",
			"§18 HUD mostra o atalho B com o custo vindo da Definition")
	_check(_text_of(_nest_hud, "StatusLabel") == "%s: recursos insuficientes" % NEST_NAME,
			"§18 HUD mostra recursos insuficientes com estoque 0")
	_check(_text_of(_core_hud, "PopulationLabel") == "Population: 1 / 8",
			"§31 HUD do núcleo começa em 1 / 8")
	_check(_worker.collision_mask & CONSTRUCTION_LAYER != 0,
			"§23 o Worker colide com a camada Construction")


func _physics_nodes_under(node: Node) -> Array[String]:
	var found: Array[String] = []
	for child in node.get_children():
		if child.get_class().contains("Collision") or child is PhysicsBody3D:
			found.append(String(child.name))
		found.append_array(_physics_nodes_under(child))
	return found


func _controls_not_ignoring(node: Node) -> Array[String]:
	var bad: Array[String] = []
	if node is Control and (node as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
		bad.append(String(node.name))
	for child in node.get_children():
		bad.append_array(_controls_not_ignoring(child))
	return bad


func _buttons_under(node: Node) -> int:
	var count := 0
	if node is BaseButton:
		count += 1
	for child in node.get_children():
		count += _buttons_under(child)
	return count


func _rocks_alive() -> Array[RockRuntime]:
	var rocks: Array[RockRuntime] = []
	for child in _dungeon.get_children():
		if child is RockRuntime:
			rocks.append(child as RockRuntime)
	return rocks


func _rock_by_id(id: String) -> RockRuntime:
	for child in _dungeon.get_children():
		if child is RockRuntime and (child as RockRuntime).rock_id == id:
			return child as RockRuntime
	return null


func _nests_in_scene() -> Array[NestRuntime]:
	var nests: Array[NestRuntime] = []
	for child in _dungeon.get_children():
		if child is NestRuntime:
			nests.append(child as NestRuntime)
	return nests


# --------------------------------------------------------------- Ciclo completo §70


func _test_full_integration_cycle() -> void:
	var ore := _iron_ore()
	var core_state := _core.core_state()
	_check(_stockpile.get_amount(ore.resource_id) == 0, "§70-0 Stockpile 0")
	_press_build_key()
	await _advance(0.1)
	_check(_nests_in_scene().is_empty(), "§53 tecla B sem recurso na cena real não cria Ninho")
	_check(_construction.nest() == null, "§53 controller real da cena não criou Ninho")
	_check(_stockpile.get_amount(ore.resource_id) == 0, "§53 estoque segue 0")
	_check(_text_of(_nest_hud, "StatusLabel") == "%s: recursos insuficientes" % NEST_NAME,
			"§18 HUD continua indicando recursos insuficientes")

	# ------------------------------------------------- escavar a rocha de minério
	_click(MOUSE_BUTTON_LEFT, _worker.global_position)
	await _advance(0.05)
	_check(_selection.selected_unit == _worker, "Worker selecionado com clique real")
	_click(MOUSE_BUTTON_RIGHT, _ore_rock.global_position)
	await _advance(0.05)
	_check(_worker.action_mode() == WorkerRuntime.ActionMode.EXCAVATE,
			"RMB real na rocha de minério inicia a escavação")
	var pile := await _wait_for_ore_pile(30.0)
	_check(pile != null, "§70-1 rocha de minério virou ResourcePile")
	if pile == null:
		_finish()
		return
	_check(pile.state.amount == 3, "§70-1 Pile 3 / Stockpile 0")
	_check(_stockpile.get_amount(ore.resource_id) == 0, "§70-1 estoque continua 0 com a pilha no chão")

	# ------------------------------------------------------------------- coletar
	_click(MOUSE_BUTTON_RIGHT, pile.global_position)
	await _advance(0.05)
	_check(_worker.action_mode() == WorkerRuntime.ActionMode.COLLECT,
			"RMB real na pilha inicia a coleta")
	await _wait_until_carrying(14.0)
	_check(_worker.state.carried_amount == 3, "§70-2 Cargo 3 / Stockpile 0")
	_check(_stockpile.get_amount(ore.resource_id) == 0, "§70-2 estoque ainda 0 durante o transporte")

	# ------------------------------------------------------------------ entregar
	await _wait_until_delivered(16.0)
	_check(_worker.state.carried_amount == 0, "§70-3 Cargo volta a 0")
	_check(_stockpile.get_amount(ore.resource_id) == 3, "§70-3 Cargo 0 / Stockpile 3")
	_check(_text_of(_ore_hud, "OreLabel") == "Minério de Ferro: 3", "HUD de recurso mostra 3")
	_check(_text_of(_nest_hud, "StatusLabel") == "%s: pronto para construir" % NEST_NAME,
			"§18 HUD libera a obra ao ter recurso suficiente")

	# --------------------------------------------------- pressionar B (tecla real)
	_press_build_key()
	await _advance(0.1)
	var nests := _nests_in_scene()
	_check(nests.size() == 1, "§55 tecla B cria exatamente 1 Ninho na cena real")
	if nests.is_empty():
		_finish()
		return
	_nest = nests[0]
	_completions.clear()
	_nest.state.construction_completed.connect(func() -> void: _completions.append(1))
	_capacity_events.clear()
	core_state.population_capacity_changed.connect(
			func(current: int, capacity: int) -> void:
				_capacity_events.append("%d/%d" % [current, capacity]))
	_check(_stockpile.get_amount(ore.resource_id) == 0, "§35 estoque cai para 0 ao criar o canteiro")
	_check(_text_of(_ore_hud, "OreLabel") == "Minério de Ferro: 0",
			"§68 HUD de recurso mostra 0 por sinal, sem esperar a obra")
	_check(_nest.global_position.is_equal_approx(_build_point.global_position),
			"§14 Ninho ficou no NestBuildPoint")
	_check(_text_of(_nest_hud, "StatusLabel") == "%s: em construção" % NEST_NAME,
			"§18 HUD mostra Ninho em construção")
	_check(core_state.population_capacity_bonus == 0, "§57 capacidade não mudou no canteiro")
	_check(core_state.get_population_capacity() == 8, "§57 Population Capacity = 8 com canteiro")
	_check(_text_of(_core_hud, "PopulationLabel") == "Population: 1 / 8",
			"§34 HUD continua 1 / 8 na criação do canteiro")
	var construction_visual := _nest.find_child("ConstructionVisual", true, false) as Node3D
	var completed_visual := _nest.find_child("CompletedVisual", true, false) as Node3D
	_check(construction_visual.visible and not completed_visual.visible,
			"§11 canteiro visível e prédio escondido")

	_press_build_key()
	await _advance(0.1)
	_check(_nests_in_scene().size() == 1, "§56 segundo B não cria outro Ninho")
	_check(_stockpile.get_amount(ore.resource_id) == 0, "§56 nenhuma cobrança extra na cena real")

	# ----------------------------- SelectionController reconhece a obra e envia BUILD
	var build_hit := _screen_hit(_camera.unproject_position(_nest.global_position), CLICKABLE)
	_check(not build_hit.is_empty() and build_hit.collider == _nest,
			"§13 o raycast de seleção reconhece a camada Construction")
	_click(MOUSE_BUTTON_RIGHT, _nest.global_position)
	await _advance(0.05)
	_check(_worker.action_mode() == WorkerRuntime.ActionMode.BUILD,
			"§58 RMB real sobre o canteiro coloca o Worker em BUILD")
	_check(_worker.is_building(), "§58 Worker está construindo")
	_check(_worker.current_construction_target() == _nest, "§58 alvo de construção é o Ninho")
	_check(_text_of(_core_hud, "PopulationLabel") == "Population: 1 / 8",
			"§34 HUD segue 1 / 8 com a obra em andamento")

	# ------------------------------------------------------------------ aproximação
	await _wait_until_in_build_range(12.0)
	await _wait_until_stopped(6.0)
	var distance := _worker_distance_to(_nest.global_position)
	_check(distance <= _worker.build_range + 0.05,
			"§59 Worker chegou dentro de build_range (%f <= %f)" % [distance, _worker.build_range])
	_check(distance >= MIN_CLEARANCE - 0.06,
			"§23 Worker parou fora do footprint (%f >= %f)" % [distance, MIN_CLEARANCE])
	_check(_close(distance, _worker.build_range - _worker.arrival_distance, 0.25),
			"§23 ponto de aproximação derivado de range - arrival_distance (%f)" % distance)
	_check(not _construction_touches_worker(),
			"§23 sem interpenetração entre Worker e collider do Ninho")
	_check(_worker.velocity == Vector3.ZERO, "§71 Worker fica parado ao lado do canteiro")
	_check(core_state.get_population_capacity() == 8, "§34 capacidade continua 8 construindo")

	# ------------------------------------------------------------------- work speed
	var before := _nest.state.remaining_work
	_clock.reset()
	await _advance(1.0)
	var applied := before - _nest.state.remaining_work
	var elapsed := _clock.stop()
	_check(_close(applied, elapsed * _worker.definition.work_speed, 0.05),
			"§24 trabalho aplicado = work_speed * delta (%f em %f s)" % [applied, elapsed])
	_check(_close(_nest.state.remaining_work, 3.0, 0.15),
			"§60 após ~1 s de trabalho restante ~3.0 (obtido %f)" % _nest.state.remaining_work)
	_check(core_state.get_population_capacity() == 8, "§34 capacidade ainda 8 com 1 s de obra")

	# ---------------------------------------------------------- FPS 30 Hz e 120 Hz
	var work_30 := await _measure_build_work(0.4, 30)
	var work_120 := await _measure_build_work(0.4, 120)
	_check(_close(work_30.applied, work_30.seconds * 1.0, 0.05),
			"§61 construção a 30 Hz rende %f em %f s" % [work_30.applied, work_30.seconds])
	_check(_close(work_120.applied, work_120.seconds * 1.0, 0.05),
			"§61 construção a 120 Hz rende %f em %f s" % [work_120.applied, work_120.seconds])
	_check(absf(work_30.applied - work_120.applied) < 0.06,
			"§25 resultado equivalente em 30 Hz e 120 Hz (%f vs %f)"
					% [work_30.applied, work_120.applied])
	_check(work_120.ticks > work_30.ticks * 3,
			"§61 taxas realmente distintas: %d vs %d ticks" % [work_30.ticks, work_120.ticks])
	_check(core_state.get_population_capacity() == 8, "§34 capacidade ainda 8 após medições de FPS")

	# ------------------------------------------------------------------ interrupção
	var frozen := _nest.state.remaining_work
	_click(MOUSE_BUTTON_RIGHT, CLEAR_GROUND)
	await _advance(0.05)
	_check(not _worker.is_building(), "§37 ordem de movimento interrompe a construção")
	_check(_worker.action_mode() == WorkerRuntime.ActionMode.MOVE, "§62 Worker passa a se mover")
	await _advance(0.6)
	_check(_close(_nest.state.remaining_work, frozen, 0.0001),
			"§37 progresso do Ninho congelado em %f durante o deslocamento" % frozen)
	await _wait_until_not_moving(12.0)
	_check(_worker_distance_to(_nest.global_position) > _worker.build_range,
			"§62 Worker saiu do raio de construção")
	_check(core_state.get_population_capacity() == 8, "§34 capacidade ainda 8 após a interrupção")

	# --------------------------------------------------------------------- retomada
	_click(MOUSE_BUTTON_RIGHT, _nest.global_position)
	await _advance(0.05)
	_check(_worker.is_building(), "§38 nova ordem de construção retoma a obra")
	await _wait_until_in_build_range(12.0)
	_check(_close(_nest.state.remaining_work, frozen, 0.0001),
			"§63 o progresso não reinicia para 4.0 (continha %f)" % frozen)
	before = _nest.state.remaining_work
	_clock.reset()
	await _advance(1.0)
	applied = before - _nest.state.remaining_work
	elapsed = _clock.stop()
	_check(_close(applied, elapsed * 1.0, 0.05),
			"§63 retomada trabalha de novo a work_speed (%f em %f s)" % [applied, elapsed])
	_check(before < 3.5, "§63 restante retomou de %f, nunca voltou a 4.0" % before)
	_check(_nest.state.remaining_work < before, "§63 progresso avança após retomar")
	_check(core_state.get_population_capacity() == 8, "§34 capacidade ainda 8 na retomada")

	# -------------------------------------------------------------------- conclusão
	await _wait_until_completed(14.0)
	_check(_close(_nest.state.remaining_work, 0.0), "§64 remaining_work chega a 0")
	_check(_completions.size() == 1, "§26 conclusão emitida exatamente uma vez na cena real")
	_check(not construction_visual.visible and completed_visual.visible,
			"§11 visual trocou para o prédio concluído")
	_check(is_instance_valid(_nest) and _nest.get_parent() == _dungeon,
			"§11 o Runtime não foi removido da cena")
	var collision := _nest.find_child("CollisionShape3D", true, false) as CollisionShape3D
	_check(collision != null and not collision.disabled, "§26 collider continua válido")
	await _advance(0.2)
	_check(_worker.current_construction_target() == null, "§64 alvo de construção limpo")
	_check(_worker.action_mode() == WorkerRuntime.ActionMode.IDLE, "§64 Worker voltou a IDLE")
	_check(_worker.velocity == Vector3.ZERO, "§64 velocity zerada após concluir")

	# ------------------------------------------------- Ninho concluído recusa trabalho
	_click(MOUSE_BUTTON_RIGHT, _nest.global_position)
	await _advance(0.1)
	_check(not _worker.is_building(), "§40 Ninho concluído não aceita ordem de construção")
	_check(_worker.action_mode() == WorkerRuntime.ActionMode.IDLE,
			"§40 nenhuma ordem nova é dada no prédio concluído")
	_check(_close(_nest.state.remaining_work, 0.0), "§40 trabalho não recomeça")
	_check(_completions.size() == 1, "§40 nenhuma conclusão extra")

	# -------------------------------------------------------------- capacidade efetiva
	_check(core_state.definition.population_capacity == 8, "§65 capacidade base continua 8")
	_check(core_state.population_capacity_bonus == 4, "§65 bônus registrado = 4")
	_check(core_state.get_population_capacity() == 12, "§65 base 8 + bônus 4 = 12")
	_check(core_state.population == 1, "§65 a população real não foi alterada")
	_check(_capacity_events == ["1/12"],
			"§30 population_capacity_changed emitiu (1, 12) exatamente uma vez")
	_check(_text_of(_core_hud, "PopulationLabel") == "Population: 1 / 12",
			"§31 HUD passou de 1 / 8 para 1 / 12 por sinal")
	_check(_text_of(_nest_hud, "StatusLabel") == "%s: concluído" % NEST_NAME,
			"§18 HUD mostra Ninho concluído")
	_check(_nest.collision_layer == CONSTRUCTION_LAYER,
			"§13 Ninho concluído permanece na camada Construction")

	# --------------------------------------------------------------------- bônus único
	await _advance(1.0)
	_press_build_key()
	_click(MOUSE_BUTTON_LEFT, _worker.global_position)
	_click(MOUSE_BUTTON_RIGHT, _nest.global_position)
	_nest.state.apply_work(2.0)
	await _advance(0.5)
	_check(core_state.population_capacity_bonus == 4, "§66 bônus não duplica com o tempo")
	_check(core_state.get_population_capacity() == 12, "§66 capacidade continua 12, não 16/20/24")
	_check(_text_of(_core_hud, "PopulationLabel") == "Population: 1 / 12",
			"§66 HUD ainda 1 / 12")
	_check(_completions.size() == 1, "§66 nenhuma conclusão extra")
	_check(_nests_in_scene().size() == 1, "§66 ainda exatamente 1 Ninho")


func _measure_build_work(seconds: float, ticks_per_second: int) -> Dictionary:
	Engine.set_physics_ticks_per_second(ticks_per_second)
	await _advance(0.1)
	var before := _nest.state.remaining_work
	_clock.reset()
	await _advance(seconds)
	var result := {
		"applied": before - _nest.state.remaining_work,
		"seconds": _clock.stop(),
		"ticks": _clock.ticks,
	}
	Engine.set_physics_ticks_per_second(60)
	await _advance(0.1)
	return result


# ---------------------------------------------------------------- Sistemas comuns


func _test_common_systems_survive() -> void:
	var core_state := _core.core_state()
	var ore := _iron_ore()
	var essence_before := core_state.essence
	await _advance(2.0)
	_check(core_state.essence > essence_before,
			"§69 Essence continua sendo gerada (%f -> %f)" % [essence_before, core_state.essence])
	_check(core_state.get_population_capacity() == 12, "§69 capacidade permanece 12")

	var rock := _rock_by_id(COMMON_ROCK_ID)
	_check(rock != null, "§69 Rocha Comum ainda existe")
	_click(MOUSE_BUTTON_LEFT, _worker.global_position)
	await _advance(0.05)
	_click(MOUSE_BUTTON_RIGHT, rock.global_position)
	await _advance(0.05)
	_check(_worker.action_mode() == WorkerRuntime.ActionMode.EXCAVATE,
			"§69 escavação continua respondendo ao RMB")
	await _advance(0.5)
	_check(_worker.current_excavation_target() == rock, "§69 alvo de escavação é a rocha")
	var gone := false
	var limit := int(40.0 * Engine.get_physics_ticks_per_second())
	var guard := 0
	while not gone and guard < limit:
		await physics_frame
		guard += 1
		gone = not is_instance_valid(rock)
	_check(gone, "§69 Rocha Comum escavada desaparece mesmo com a camada Construction ativa")

	var pile := PILE_SCENE.instantiate() as ResourcePileRuntime
	pile.position = Vector3(ORE_PILE_DROP.x, 0.0, ORE_PILE_DROP.z)
	_dungeon.add_child(pile)
	pile.setup(ore, ResourcePileState.new(ore, "test_drop", 3))
	await _advance(0.1)
	_check(_segment_clear_of(_nest.global_position, MIN_CLEARANCE,
			_worker.global_position, pile.global_position),
			"§69 rota do Worker até a pilha de teste passa livre do Ninho")
	_click(MOUSE_BUTTON_RIGHT, pile.global_position)
	await _advance(0.05)
	_check(_worker.action_mode() == WorkerRuntime.ActionMode.COLLECT,
			"§69 coleta continua respondendo ao RMB")
	await _wait_until_carrying(20.0)
	_check(_worker.state.carried_amount == 3, "§69 Worker carrega 3 de minério")
	await _wait_until_delivered(20.0)
	_check(_stockpile.get_amount(ore.resource_id) == 3, "§69 hauling volta a entregar no depósito")
	_check(_text_of(_ore_hud, "OreLabel") == "Minério de Ferro: 3", "§69 HUD acompanha a entrega")
	_check(_text_of(_nest_hud, "StatusLabel") == "%s: concluído" % NEST_NAME,
			"§18 HUD de obra não regride quando o estoque enche de novo")
	_check(_construction.nest() == _nest, "§69 nenhum segundo Ninho foi criado")

	_click(MOUSE_BUTTON_RIGHT, FAR_GROUND)
	await _advance(0.05)
	_check(_worker.action_mode() == WorkerRuntime.ActionMode.MOVE,
			"§69 movimento RTS continua aceito")
	await _wait_until_not_moving(20.0)
	_check(_worker_distance_to(FAR_GROUND) < 0.3,
			"§69 Worker chegou ao ponto clicado (%f de erro)" % _worker_distance_to(FAR_GROUND))
	_check(_worker.velocity == Vector3.ZERO, "§69 Worker para no destino")


# ------------------------------------------------------------------- Escopo da tarefa


func _test_scope_guards() -> void:
	_check(_scene.find_child("*Manager*", true, false) == null,
			"§74 nenhum ConstructionManager/BuildingManager/RoomManager/EconomyManager")
	_check(_scene.find_child("*Housing*", true, false) == null, "§74 nenhum HousingManager")
	_check(_scene.find_child("*PopulationManager*", true, false) == null,
			"§74 nenhuma PopulationManager")
	_check(_scene.find_child("*Ghost*", true, false) == null, "§74 nenhum ghost de placement")
	_check(_scene.find_child("*Grid*", true, false) == null, "§74 nenhum grid de construção")
	_check(_scene.find_child("*Placement*", true, false) == null, "§74 nenhum sistema de placement")
	_check(_scene.find_child("*Effect*", true, false) == null, "§32 nenhum EffectManager")
	_check(_scene.find_child("*Modifier*", true, false) == null, "§32 nenhum ModifierSystem")
	_check(_scene.find_child("*Registry*", true, false) == null, "§32 nenhum BuildingEffectRegistry")
	_check(_scene.find_child("*Navigation*", true, false) == null, "§74 nenhum nó de navegação")
	_check(_scene.find_child("*Demolition*", true, false) == null, "§74 nenhuma demolição")
	_check(_scene.find_child("*Queue*", true, false) == null, "§74 nenhuma fila de construção")
	_check(_scene.find_child("*AbstractRoom*", true, false) == null,
			"§76 nenhuma abstração genérica de Room")
	_check(ProjectSettings.get_setting("autoload", {}) is Dictionary
			and (ProjectSettings.get_setting("autoload", {}) as Dictionary).is_empty(),
			"§16 nenhum autoload/singleton")
	_check(not _nest.has_method("cancel") and not _nest.has_method("demolish"),
			"§36 nenhum cancelamento ou demolição no Ninho")
	_check(not _nest.has_method("refund"), "§36 nenhum refund no Ninho")
	_check(_construction.nest() == _nest, "§17 uma única instância de Ninho no controller")
	_check(_nests_in_scene().size() == 1, "§17 a cena contém exatamente 1 Ninho")
	_check(WorkerRuntime.ActionMode.size() == 6, "§21 ActionMode tem os 6 modos locais")
	_check(not _source_contains(WORKER_RUNTIME_PATH, "class_name WorkerFsm"),
			"§21 nenhuma FSM externa")
	_check(not _source_contains(NEST_RUNTIME_PATH, "func _process("),
			"§79 NestRuntime não roda por frame")
	_check(not _source_contains(NEST_RUNTIME_PATH, "func _physics_process("),
			"§79 NestRuntime só reage ao State")
	_check(not _source_contains(CONSTRUCTION_CONTROLLER_PATH, "func _process("),
			"§16 controller de obra não roda por frame")
	_check(_construction.get_parent() == _scene.get_node("Systems"),
			"§16 controller vive na cena composition root, sem Autoload")
	_check(not _stockpile.has_method("set_amount"), "estoque não pode ser forçado do exterior")


# -------------------------------------------------------------------------- Input real


func _worker_distance_to(target: Vector3) -> float:
	return _planar_gap(_worker.global_position, target)


func _planar_gap(from: Vector3, to: Vector3) -> float:
	var offset := to - from
	offset.y = 0.0
	return offset.length()


func _segment_clear_of(obstacle: Vector3, obstacle_radius: float,
		from: Vector3, to: Vector3) -> bool:
	var samples := 24
	for i in samples + 1:
		var point := from.lerp(to, float(i) / float(samples))
		if _planar_gap(obstacle, point) < obstacle_radius:
			return false
	return true


func _click(button: int, world_position: Vector3) -> void:
	_click_at_screen(button, _camera.unproject_position(world_position))


func _click_at_screen(button: int, screen_position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	event.position = screen_position
	event.global_position = screen_position
	root.push_input(event)


func _press_build_key() -> void:
	var pressed := InputEventKey.new()
	pressed.physical_keycode = KEY_B
	pressed.pressed = true
	root.push_input(pressed)
	var released := InputEventKey.new()
	released.physical_keycode = KEY_B
	released.pressed = false
	root.push_input(released)


func _screen_hit(screen_position: Vector2, mask: int) -> Dictionary:
	var origin := _camera.project_ray_origin(screen_position)
	var direction := _camera.project_ray_normal(screen_position)
	var space := _scene.get_viewport().world_3d.direct_space_state
	return space.intersect_ray(
			PhysicsRayQueryParameters3D.create(origin, origin + direction * 1000.0, mask))


func _construction_touches_worker() -> bool:
	var space := _scene.get_viewport().world_3d.direct_space_state
	var sphere := SphereShape3D.new()
	sphere.radius = WORKER_RADIUS
	var parameters := PhysicsShapeQueryParameters3D.new()
	parameters.shape = sphere
	parameters.transform = Transform3D(Basis.IDENTITY,
			Vector3(_worker.global_position.x, 0.8, _worker.global_position.z))
	parameters.collision_mask = CONSTRUCTION_LAYER
	parameters.exclude = [_worker.get_rid()]
	return space.intersect_shape(parameters, 8).size() > 0


func _source_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func _source_contains(path: String, needle: String) -> bool:
	return _source_text(path).contains(needle)


func _count_occurrences(text: String, needle: String) -> int:
	var count := 0
	var index := text.find(needle)
	while index != -1:
		count += 1
		index = text.find(needle, index + needle.length())
	return count


# ---------------------------------------------------------------------------- Esperas


func _wait_for_ore_pile(max_seconds: float) -> ResourcePileRuntime:
	var limit := int(max_seconds * Engine.get_physics_ticks_per_second())
	var guard := 0
	while guard < limit:
		await physics_frame
		guard += 1
		for child in _dungeon.get_children():
			if child is ResourcePileRuntime:
				return child as ResourcePileRuntime
	return null


func _wait_until_carrying(max_seconds: float) -> void:
	var limit := int(max_seconds * Engine.get_physics_ticks_per_second())
	var guard := 0
	while _worker.state.carried_amount == 0 and guard < limit:
		await physics_frame
		guard += 1


func _wait_until_delivered(max_seconds: float) -> void:
	var limit := int(max_seconds * Engine.get_physics_ticks_per_second())
	var guard := 0
	while _worker.state.carried_amount > 0 and guard < limit:
		await physics_frame
		guard += 1


func _wait_until_in_build_range(max_seconds: float) -> void:
	var limit := int(max_seconds * Engine.get_physics_ticks_per_second())
	var guard := 0
	while _worker.is_building() and not _in_build_range() and guard < limit:
		await physics_frame
		guard += 1


func _in_build_range() -> bool:
	return _worker_distance_to(_nest.global_position) <= _worker.build_range


func _wait_until_completed(max_seconds: float) -> void:
	var limit := int(max_seconds * Engine.get_physics_ticks_per_second())
	var guard := 0
	while not _nest.state.is_completed() and guard < limit:
		await physics_frame
		guard += 1


func _wait_until_not_moving(max_seconds: float) -> void:
	var limit := int(max_seconds * Engine.get_physics_ticks_per_second())
	var guard := 0
	while _worker.has_move_target() and guard < limit:
		await physics_frame
		guard += 1


func _wait_until_stopped(max_seconds: float) -> void:
	var limit := int(max_seconds * Engine.get_physics_ticks_per_second())
	var guard := 0
	while _worker.has_move_target() and _worker.velocity != Vector3.ZERO and guard < limit:
		await physics_frame
		guard += 1


func _finish() -> void:
	print("---- construction tests finished: %d asserts, %d failure(s) ----"
			% [_asserts, _failures])
	quit(1 if _failures > 0 else 0)
