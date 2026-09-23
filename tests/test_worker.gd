extends SceneTree

const WORKER_DEFINITION_PATH := "res://data/units/workers/abyss_worker.tres"
const CORE_DEFINITION_PATH := "res://data/core/core_level_1.tres"
const WORKER_RUNTIME_SCENE := preload("res://units/workers/WorkerRuntime.tscn")
const CORE_HUD_SCENE := preload("res://ui/hud/CoreDebugHud.tscn")
const MAIN_SCENE := preload("res://game/GameMain.tscn")

const PROBE_FRAMES := 60

var _failures := 0
var _asserts := 0
var _started := false
var _frames := 0
var _probe_scene: Node
var _probe_worker: WorkerRuntime
var _probe_start := Vector3.ZERO


func _process(_delta: float) -> bool:
	_frames += 1
	if not _started:
		_started = true
		_run_all()
		_start_probe()
		return false
	if _frames < PROBE_FRAMES:
		return false
	_finish_probe()
	print("---- worker tests finished: %d asserts, %d failure(s) ----" % [_asserts, _failures])
	quit(1 if _failures > 0 else 0)
	return true


func _run_all() -> void:
	_test_definition_resource()
	_test_initial_state()
	_test_shared_definition()
	_test_damage()
	_test_health_floor()
	_test_heal()
	_test_health_ceiling()
	_test_invalid_amounts()
	_test_health_signal()
	_test_runtime_structure()
	_test_setup_references()
	_test_population()
	_test_population_clamp()
	_test_population_signal()
	_test_hud_reacts_to_population()


func _test_definition_resource() -> void:
	var definition := _worker_definition()
	_check(definition != null, "abyss_worker.tres carrega")
	_check(definition.unit_type_id == &"abyss_worker", "unit_type_id = abyss_worker")
	_check(definition.display_name == "Trabalhador Abissal", "display_name = Trabalhador Abissal")
	_check(_close(definition.max_health, 50.0, 0.001), "max_health = 50")
	_check(_close(definition.move_speed, 3.5, 0.001), "move_speed = 3.5")
	_check(_close(definition.work_speed, 1.0, 0.001), "work_speed = 1")


func _test_initial_state() -> void:
	var state := WorkerState.new(_worker_definition(), "worker_001")
	_check(state.unit_id == "worker_001", "unit_id = worker_001")
	_check(_close(state.health, 50.0, 0.001), "health inicia em 50")
	_check(state.level == 1, "level inicia em 1")
	_check(_close(state.experience, 0.0, 0.001), "experience inicia em 0")


func _test_shared_definition() -> void:
	var definition := _worker_definition()
	var state := WorkerState.new(definition, "worker_001")
	_check(state.definition == definition, "WorkerState referencia a Definition")
	_check(_close(state.definition.max_health, 50.0, 0.001), "state.definition.max_health = 50")
	_check(state.get("max_health") == null, "WorkerState nao duplica max_health")
	_check(state.unit_id != definition.display_name, "unit_id e separado de display_name")


func _test_damage() -> void:
	var state := WorkerState.new(_worker_definition(), "worker_001")
	state.damage(10.0)
	_check(_close(state.health, 40.0, 0.001), "50 - damage(10) = 40, obtido %f" % state.health)


func _test_health_floor() -> void:
	var state := WorkerState.new(_worker_definition(), "worker_001")
	state.damage(1000.0)
	_check(_close(state.health, 0.0, 0.001), "damage(1000) satura em 0, obtido %f" % state.health)
	_check(state.health >= 0.0, "health nunca fica negativo")


func _test_heal() -> void:
	var state := WorkerState.new(_worker_definition(), "worker_001")
	state.damage(30.0)
	state.heal(10.0)
	_check(_close(state.health, 30.0, 0.001), "20 + heal(10) = 30, obtido %f" % state.health)


func _test_health_ceiling() -> void:
	var state := WorkerState.new(_worker_definition(), "worker_001")
	state.damage(30.0)
	state.heal(1000.0)
	_check(_close(state.health, 50.0, 0.001), "heal(1000) satura em 50, obtido %f" % state.health)


func _test_invalid_amounts() -> void:
	var state := WorkerState.new(_worker_definition(), "worker_001")
	state.damage(-10.0)
	_check(_close(state.health, 50.0, 0.001), "damage(-10) e ignorado")
	state.heal(-10.0)
	_check(_close(state.health, 50.0, 0.001), "heal(-10) e ignorado")
	state.damage(10.0)
	state.damage(0.0)
	state.heal(0.0)
	_check(_close(state.health, 40.0, 0.001), "damage(0) e heal(0) nao alteram health")


func _test_health_signal() -> void:
	var state := WorkerState.new(_worker_definition(), "worker_001")
	var received: Array[Vector2] = []
	state.health_changed.connect(
		func(current: float, maximum: float) -> void:
			received.append(Vector2(current, maximum))
	)
	state.damage(10.0)
	_check(received.size() == 1, "damage real emite health_changed")
	_check(received.size() > 0 and _close(received[0].x, 40.0, 0.001) and _close(received[0].y, 50.0, 0.001),
			"payload = (40, 50), obtido %s" % [received])
	state.damage(0.0)
	state.heal(0.0)
	state.damage(-5.0)
	state.heal(-5.0)
	_check(received.size() == 1, "alteracoes nulas ou negativas nao emitem sinal")
	state.heal(1000.0)
	_check(received.size() == 2, "heal valido emite")
	state.heal(1000.0)
	_check(received.size() == 2, "heal sem mudanca nao emite")


func _test_runtime_structure() -> void:
	var runtime := _spawn_runtime()
	_check(runtime is CharacterBody3D, "WorkerRuntime e CharacterBody3D")
	var visual := runtime.get_node_or_null("Visual")
	_check(visual is MeshInstance3D, "Visual e MeshInstance3D")
	_check(visual != null and (visual as MeshInstance3D).mesh != null, "Visual possui mesh")
	var collider := runtime.get_node_or_null("CollisionShape3D")
	_check(collider is CollisionShape3D, "CollisionShape3D existe")
	_check(collider != null and (collider as CollisionShape3D).shape != null, "collider possui shape")


func _test_setup_references() -> void:
	var definition := _worker_definition()
	var state := WorkerState.new(definition, "worker_001")
	var runtime := _spawn_runtime()
	_check(runtime.state == null, "Runtime nao cria State escondido antes do setup")
	runtime.setup(definition, state)
	_check(runtime.definition == definition, "runtime.definition e a instancia enviada")
	_check(runtime.state == state, "runtime.state e a instancia enviada")
	_check(runtime.state.unit_id == "worker_001", "identidade preservada apos setup")


func _test_population() -> void:
	var state := CoreState.new(_core_definition())
	state.set_population(1)
	_check(state.population == 1, "set_population(1) -> 1")


func _test_population_clamp() -> void:
	var state := CoreState.new(_core_definition())
	state.set_population(-100)
	_check(state.population == 0, "set_population(-100) -> 0")
	state.set_population(999)
	_check(state.population == 8, "set_population(999) -> capacity 8")


func _test_population_signal() -> void:
	var state := CoreState.new(_core_definition())
	var received: Array[Vector2] = []
	state.population_changed.connect(
		func(current: int, capacity: int) -> void:
			received.append(Vector2(current, capacity))
	)
	state.set_population(1)
	_check(received.size() == 1 and received[0] == Vector2(1, 8),
			"population_changed emite (1, 8), obtido %s" % [received])
	state.set_population(1)
	_check(received.size() == 1, "mesmo valor nao reemite")
	state.set_population(999)
	_check(received.size() == 2 and received[1] == Vector2(8, 8), "clamp emite valor efetivo")


func _test_hud_reacts_to_population() -> void:
	var state := CoreState.new(_core_definition())
	var panel := _spawn_hud()
	panel.bind_core(state)
	var labels := panel.get_node("VBox")
	_check(_text_of(labels, "PopulationLabel") == "Population: 0 / 8",
			"HUD comeca em 0/8: %s" % _text_of(labels, "PopulationLabel"))
	state.set_population(1)
	_check(_text_of(labels, "PopulationLabel") == "Population: 1 / 8",
			"HUD reage ao population_changed: %s" % _text_of(labels, "PopulationLabel"))


func _start_probe() -> void:
	_probe_scene = MAIN_SCENE.instantiate()
	root.add_child(_probe_scene)
	_probe_worker = _probe_scene.get_node("World/DungeonRoot/Worker001") as WorkerRuntime
	_probe_start = _probe_worker.global_position


func _finish_probe() -> void:
	_check(_probe_worker != null, "GameMain contem Worker001")
	if _probe_worker == null:
		return
	var moved := _probe_worker.global_position.distance_to(_probe_start)
	_check(moved < 0.0001,
			"Worker permanece parado por %d frames (deslocamento %f)" % [PROBE_FRAMES, moved])
	_check(_probe_worker.velocity == Vector3.ZERO, "velocity continua Vector3.ZERO")
	_check(_probe_worker.state != null and _probe_worker.state.health == 50.0,
			"Worker do cena esta inicializado com health 50")
	var labels := (_probe_scene.get_node("UI/CoreDebugPanel") as Node).get_node("VBox")
	_check(_text_of(labels, "PopulationLabel") == "Population: 1 / 8",
			"cena mostra Population 1/8: %s" % _text_of(labels, "PopulationLabel"))
	_check(_probe_worker.global_position.y > -0.001 and _probe_worker.global_position.y < 0.001,
			"Worker fica apoiado no plano do piso (y=%f)" % _probe_worker.global_position.y)


func _spawn_runtime() -> WorkerRuntime:
	var runtime := WORKER_RUNTIME_SCENE.instantiate() as WorkerRuntime
	root.add_child(runtime)
	return runtime


func _spawn_hud() -> CoreDebugHud:
	var panel := CORE_HUD_SCENE.instantiate() as CoreDebugHud
	root.add_child(panel)
	return panel


func _worker_definition() -> WorkerDefinition:
	return load(WORKER_DEFINITION_PATH) as WorkerDefinition


func _core_definition() -> CoreDefinition:
	return load(CORE_DEFINITION_PATH) as CoreDefinition


func _text_of(labels: Node, label_name: String) -> String:
	return (labels.get_node(label_name) as Label).text


func _close(a: float, b: float, tolerance: float = 0.001) -> bool:
	return absf(a - b) <= tolerance


func _check(condition: bool, label: String) -> void:
	_asserts += 1
	if condition:
		print("[PASS] %s" % label)
	else:
		_failures += 1
		print("[FAIL] %s" % label)
