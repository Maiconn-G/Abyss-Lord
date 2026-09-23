extends SceneTree

const CORE_DEFINITION_PATH := "res://data/core/core_level_1.tres"
const CORE_RUNTIME_SCENE := preload("res://world/dungeon/core/CoreRuntime.tscn")
const MAIN_SCENE := preload("res://game/GameMain.tscn")

var _failures := 0
var _asserts := 0
var _ran := false
var _state: CoreState


func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	_run_all()
	print("---- core tests finished: %d asserts, %d failure(s) ----" % [_asserts, _failures])
	quit(1 if _failures > 0 else 0)
	return true


func _run_all() -> void:
	_test_definition_resource()
	_test_initial_state()
	_test_generation()
	_test_fps_independence()
	_test_max_clamp()
	_test_consume_valid()
	_test_consume_insufficient()
	_test_negative_amounts()
	_test_runtime_setup()
	_test_signal()
	_test_scene_integration()


func _test_definition_resource() -> void:
	var definition := _definition()
	_check(definition != null, "core_level_1.tres carrega")
	_check(definition.level == 1, "level = 1")
	_check(_close(definition.max_integrity, 100.0, 0.001), "max_integrity = 100")
	_check(_close(definition.max_essence, 50.0, 0.001), "max_essence = 50")
	_check(_close(definition.starting_essence, 20.0, 0.001), "starting_essence = 20")
	_check(definition.population_capacity == 8, "population_capacity = 8")
	_check(_close(definition.essence_generation_rate, 1.0, 0.001), "essence_generation_rate = 1")


func _test_initial_state() -> void:
	var state := CoreState.new(_definition())
	_check(state.core_id == "main_core", "core_id = main_core")
	_check(state.level == 1, "estado inicial: Level = 1")
	_check(_close(state.integrity, 100.0, 0.001), "estado inicial: Integrity = 100")
	_check(_close(state.essence, 20.0, 0.001), "estado inicial: Essence = 20")
	_check(state.population == 0, "estado inicial: Population = 0")


func _test_generation() -> void:
	var runtime := _spawn_runtime()
	for i in 300:
		runtime._process(1.0 / 60.0)
	_check(_close(_state.essence, 25.0, 0.01), "5s de geracao -> 25, obtido %f" % _state.essence)


func _test_fps_independence() -> void:
	var slow := _spawn_runtime()
	for i in 150:
		slow._process(1.0 / 30.0)
	var at_30 := _state.essence

	var fast := _spawn_runtime()
	for i in 600:
		fast._process(1.0 / 120.0)
	var at_120 := _state.essence

	_check(_close(at_30, 25.0, 0.01), "30 fps por 5s -> 25, obtido %f" % at_30)
	_check(_close(at_120, 25.0, 0.01), "120 fps por 5s -> 25, obtido %f" % at_120)
	_check(_close(at_30, at_120, 0.001), "geracao independe de FPS")


func _test_max_clamp() -> void:
	var definition := _definition()
	var runtime := _spawn_runtime()
	var exceeded := false
	for i in 6000:
		runtime._process(0.1)
		if _state.essence > definition.max_essence:
			exceeded = true
	_check(not exceeded, "Essence nunca ultrapassa o maximo durante a simulacao")
	_check(_close(_state.essence, 50.0, 0.001), "Essence satura em 50, obtido %f" % _state.essence)


func _test_consume_valid() -> void:
	var state := CoreState.new(_definition())
	_check(state.consume_essence(5.0), "consume_essence(5) retorna true")
	_check(_close(state.essence, 15.0, 0.001), "20 - 5 = 15, obtido %f" % state.essence)


func _test_consume_insufficient() -> void:
	var state := CoreState.new(_definition())
	state.consume_essence(5.0)
	_check(not state.consume_essence(30.0), "consume_essence(30) com 15 disponiveis retorna false")
	_check(_close(state.essence, 15.0, 0.001), "consumo invalido nao altera Essence, obtido %f" % state.essence)


func _test_negative_amounts() -> void:
	var state := CoreState.new(_definition())
	state.add_essence(-5.0)
	_check(_close(state.essence, 20.0, 0.001), "add_essence(-5) e ignorado")
	_check(not state.consume_essence(-5.0), "consume_essence(-5) retorna false")
	_check(_close(state.essence, 20.0, 0.001), "consume_essence(-5) nao altera Essence")
	state.add_essence(0.0)
	_check(_close(state.essence, 20.0, 0.001), "add_essence(0) e ignorado")


func _test_runtime_setup() -> void:
	var runtime := _spawn_runtime()
	var visual := runtime.get_node_or_null("Visual")
	_check(visual is MeshInstance3D, "CoreRuntime tem Visual MeshInstance3D")
	_check((visual as MeshInstance3D).mesh != null, "Visual possui mesh")
	_check(runtime.is_class("Node3D"), "CoreRuntime e um Node3D")


func _test_signal() -> void:
	var definition := _definition()
	var state := CoreState.new(definition)
	# GDScript lambdas capture locals by value, so emissions are recorded in an Array.
	var received: Array[Vector2] = []
	state.essence_changed.connect(
		func(current: float, maximum: float) -> void:
			received.append(Vector2(current, maximum))
	)
	state.add_essence(1.0)
	_check(received.size() == 1, "add_essence emite essence_changed")
	if received.size() >= 1:
		_check(_close(received[0].x, 21.0, 0.001) and _close(received[0].y, 50.0, 0.001),
				"payload do sinal = (21, 50), obtido %s" % [received[0]])
	state.add_essence(999.0)
	_check(received.size() == 2 and _close(state.essence, 50.0, 0.001),
			"saturacao emite uma unica vez (%d sinais)" % received.size())
	state.add_essence(1.0)
	_check(received.size() == 2, "geracao para em 50: nenhum sinal extra")


func _test_scene_integration() -> void:
	var scene := MAIN_SCENE.instantiate()
	root.add_child(scene)

	var runtime := scene.get_node_or_null("World/DungeonRoot/MainCore") as CoreRuntime
	var panel := scene.get_node_or_null("UI/CoreDebugPanel") as CoreDebugHud
	_check(runtime != null, "GameMain contem MainCore (CoreRuntime)")
	_check(panel != null, "GameMain contem o painel do HUD")
	if runtime == null or panel == null:
		return

	var labels := panel.get_node("VBox")
	_check(_text_of(labels, "IntegrityLabel") == "Integrity: 100 / 100",
			"HUD inicial: %s" % _text_of(labels, "IntegrityLabel"))
	_check(_text_of(labels, "EssenceLabel") == "Essence: 20 / 50",
			"HUD inicial: %s" % _text_of(labels, "EssenceLabel"))
	_check(_text_of(labels, "PopulationLabel") == "Population: 0 / 8",
			"HUD inicial: %s" % _text_of(labels, "PopulationLabel"))

	runtime.set_process(false)
	runtime._process(1.0)
	_check(_text_of(labels, "EssenceLabel") == "Essence: 21 / 50",
			"HUD acompanha o sinal: %s" % _text_of(labels, "EssenceLabel"))

	for i in 40:
		runtime._process(1.0)
	_check(_text_of(labels, "EssenceLabel") == "Essence: 50 / 50",
			"HUD para em 50: %s" % _text_of(labels, "EssenceLabel"))


func _spawn_runtime() -> CoreRuntime:
	var definition := _definition()
	_state = CoreState.new(definition)
	var runtime := CORE_RUNTIME_SCENE.instantiate() as CoreRuntime
	root.add_child(runtime)
	runtime.setup(definition, _state)
	runtime.set_process(false)
	return runtime


func _definition() -> CoreDefinition:
	return load(CORE_DEFINITION_PATH) as CoreDefinition


func _text_of(labels: Node, label_name: String) -> String:
	return (labels.get_node(label_name) as Label).text


func _close(a: float, b: float, tolerance: float = 0.5) -> bool:
	return absf(a - b) <= tolerance


func _check(condition: bool, label: String) -> void:
	_asserts += 1
	if condition:
		print("[PASS] %s" % label)
	else:
		_failures += 1
		print("[FAIL] %s" % label)
