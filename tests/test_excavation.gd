extends SceneTree

const MAIN_SCENE := preload("res://game/GameMain.tscn")
const ROCK_DEFINITION_PATH := "res://data/environment/common_rock.tres"

const WORKER_START := Vector3(2, 0, 2)
const ROCK_1 := Vector3(6, 1, 2)
const GROUND_POINT := Vector3(-6, 0, -4)
const HUD_POINT := Vector2(60, 60)
const WORKER_CAPSULE_RADIUS := 0.35
const ROCK_HALF := 1.0

var _failures := 0
var _asserts := 0
var _frames := 0
var _scene: Node
var _worker: WorkerRuntime
var _camera: Camera3D
var _controller: SelectionController
var _hud: Control
var _rocks: Array[RockRuntime] = []
var _clock: FrameClock


class FrameClock extends Node:
	var ticks := 0
	var elapsed := 0.0

	func _physics_process(delta: float) -> void:
		ticks += 1
		elapsed += delta

	func reset() -> void:
		ticks = 0
		elapsed = 0.0


func _initialize() -> void:
	_run_all()


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > 12000:
		_check(false, "timeout: a suíte de escavação não terminou")
		_finish()
	return false


func _run_all() -> void:
	await process_frame
	_test_rock_definition_resource()
	_test_rock_state()
	_test_apply_work()
	_test_clamp()
	_test_invalid_amounts()
	_test_work_changed()
	_test_excavated_once()
	_boot_scene()
	await _advance(0.1)
	_test_rock_runtime_scene()
	_test_hud_mouse_filter()
	await _test_hud_does_not_swallow_click()
	await _test_left_click_on_rock_deselects()
	await _test_right_click_on_rock_orders_excavation()
	await _test_approach_stops_in_work_range()
	await _test_work_over_time()
	await _test_conclusion()
	await _test_cancel_keeps_progress()
	await _test_resume_continues_progress()
	await _test_switch_target()
	await _test_work_fps_independence()
	await _test_no_resources_no_managers()
	_finish()


func _rock_definition() -> RockDefinition:
	return load(ROCK_DEFINITION_PATH) as RockDefinition


func _test_rock_definition_resource() -> void:
	var definition := _rock_definition()
	_check(definition != null, "common_rock.tres carrega")
	_check(definition is RockDefinition, "Resource usa RockDefinition")
	_check(definition.rock_type_id == &"common_rock", "rock_type_id = common_rock")
	_check(definition.display_name == "Rocha Comum", "display_name = Rocha Comum")
	_check(_close(definition.work_required, 4.0), "work_required = 4.0")


func _test_rock_state() -> void:
	var definition := _rock_definition()
	var state := RockState.new(definition, "rock_001")
	_check(state.rock_id == "rock_001", "rock_id = rock_001")
	_check(state.definition == definition, "RockState referencia a Definition")
	_check(_close(state.remaining_work, 4.0), "remaining_work inicia em 4.0")
	_check(state.get("max_work") == null, "RockState não duplica o limite de trabalho")
	_check(not state.is_excavated(), "rocha nova não nasce escavada")


func _test_apply_work() -> void:
	var state := RockState.new(_rock_definition(), "rock_001")
	state.apply_work(1.0)
	_check(_close(state.remaining_work, 3.0), "4.0 - apply_work(1.0) = 3.0, obtido %f" % state.remaining_work)


func _test_clamp() -> void:
	var state := RockState.new(_rock_definition(), "rock_001")
	state.apply_work(100.0)
	_check(_close(state.remaining_work, 0.0), "apply_work(100) satura em 0")
	_check(state.remaining_work >= 0.0, "remaining_work nunca fica negativo")
	_check(state.is_excavated(), "is_excavated() verdadeiro ao chegar a zero")


func _test_invalid_amounts() -> void:
	var state := RockState.new(_rock_definition(), "rock_001")
	state.apply_work(0.0)
	_check(_close(state.remaining_work, 4.0), "apply_work(0) não altera estado")
	state.apply_work(-10.0)
	_check(_close(state.remaining_work, 4.0), "apply_work(-10) não altera estado")


func _test_work_changed() -> void:
	var state := RockState.new(_rock_definition(), "rock_001")
	var received: Array[Vector2] = []
	state.work_changed.connect(
		func(remaining: float, total: float) -> void:
			received.append(Vector2(remaining, total))
	)
	state.apply_work(1.0)
	_check(received.size() == 1 and _close(received[0].x, 3.0) and _close(received[0].y, 4.0),
			"work_changed emite (3, 4), obtido %s" % [received])
	state.apply_work(0.0)
	state.apply_work(-5.0)
	_check(received.size() == 1, "trabalho nulo ou negativo não emite sinal")
	state.apply_work(3.0)
	_check(received.size() == 2 and _close(received[1].x, 0.0), "payload final (0, 4)")


func _test_excavated_once() -> void:
	var state := RockState.new(_rock_definition(), "rock_001")
	# Lambdas do GDScript capturam escalares por valor; o contador precisa ser uma referência.
	var emitted: Array[int] = [0]
	state.excavated.connect(func() -> void: emitted[0] += 1)
	state.apply_work(2.0)
	_check(emitted[0] == 0, "excavated não emite antes de zerar")
	state.apply_work(2.0)
	_check(emitted[0] == 1, "excavated emite ao cruzar para zero")
	state.apply_work(2.0)
	_check(emitted[0] == 1, "excavated não reemite em chamadas posteriores")


func _boot_scene() -> void:
	_scene = MAIN_SCENE.instantiate()
	root.add_child(_scene)
	_worker = _scene.get_node("World/DungeonRoot/Worker001") as WorkerRuntime
	_camera = _scene.get_node("World/CameraRig/Camera3D") as Camera3D
	_controller = _scene.get_node("Systems/SelectionController") as SelectionController
	_hud = _scene.get_node("UI/CoreDebugPanel") as Control
	for child in (_scene.get_node("World/DungeonRoot") as Node).get_children():
		if child is RockRuntime:
			_rocks.append(child as RockRuntime)
	_clock = FrameClock.new()
	_clock.name = "FrameClock"
	root.add_child(_clock)


func _test_rock_runtime_scene() -> void:
	_check(_rocks.size() >= 2, "pelo menos duas Rocks aparecem na cena: %d" % _rocks.size())
	var rock := _rocks[0]
	_check(rock is StaticBody3D, "RockRuntime é StaticBody3D")
	_check(rock.get_node("Visual") is MeshInstance3D, "RockRuntime possui Visual")
	_check((rock.get_node("Visual") as MeshInstance3D).mesh is BoxMesh, "Visual usa BoxMesh")
	var collider := rock.get_node("CollisionShape3D") as CollisionShape3D
	_check(collider.shape is BoxShape3D, "colisor usa BoxShape3D")
	var box := collider.shape as BoxShape3D
	_check(_close(box.size.x, 2.0) and _close(box.size.y, 2.0) and _close(box.size.z, 2.0),
			"bloco 2 x 2 x 2, obtido %s" % box.size)
	_check(_close(rock.global_position.y - box.size.y * 0.5, 0.0), "base do bloco toca o piso Y=0")
	_check(rock.collision_layer == 4, "rocha está na layer Diggable (3)")
	_check(rock.collision_layer & rock.collision_mask == 0, "layer e mask da rocha não se sobrepõem")
	_check(_worker.collision_mask & 4 == 4, "Worker colide fisicamente com Diggable")
	var ids: Array[String] = []
	for entry in _rocks:
		ids.append(entry.state.rock_id)
	_check(ids == ["rock_001", "rock_002", "rock_003", "iron_ore_001"],
			"GameMain compôs o estado de cada rocha da cena: %s" % [ids])
	_check(_close(_rocks[0].state.remaining_work, 4.0), "estado inicial da rocha tem 4.0 de trabalho")
	_check(_rocks[0].state.definition == _rock_definition(), "rocha usa a Definition do Resource")


func _test_hud_mouse_filter() -> void:
	_check(_hud.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"CoreDebugPanel usa mouse_filter IGNORE")
	_check((_hud.get_node("VBox") as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"VBox do HUD também ignora o mouse")


func _test_hud_does_not_swallow_click() -> void:
	await _reset_worker()
	_click(MOUSE_BUTTON_LEFT, _worker.global_position)
	await process_frame
	_check(_controller.selected_unit == _worker, "clique no Worker seleciona (input real do viewport)")
	_click_at_screen(MOUSE_BUTTON_LEFT, HUD_POINT)
	await process_frame
	_check(_controller.selected_unit == null,
			"clique esquerdo sobre a região do HUD chega ao jogo e limpa a seleção")
	_controller._select(_worker)
	await process_frame
	_click_at_screen(MOUSE_BUTTON_RIGHT, HUD_POINT)
	await process_frame
	_check(not _worker.is_excavating(), "botão direito sobre o HUD não gera escavação")
	_check(_worker.has_move_target(), "botão direito sobre a região do HUD gera ordem de movimento")
	await _advance(0.3)
	_check(_worker.global_position.distance_to(WORKER_START) > 0.3,
			"Worker obedece à ordem dada por cima do HUD: afastou-se %f"
			% _worker.global_position.distance_to(WORKER_START))
	await _reset_worker()


func _test_left_click_on_rock_deselects() -> void:
	_controller._select(_worker)
	await process_frame
	_click(MOUSE_BUTTON_LEFT, _rocks[0].global_position)
	await process_frame
	_check(_controller.selected_unit == null, "clique esquerdo na rocha desseleciona")
	_check(not _worker.get_node("SelectionIndicator").visible, "indicador some ao clicar na rocha")
	_check(not _worker.is_excavating(), "clique esquerdo na rocha não inicia trabalho")


func _test_right_click_on_rock_orders_excavation() -> void:
	await _reset_worker()
	_controller._select(_worker)
	await process_frame
	_click(MOUSE_BUTTON_RIGHT, ROCK_1)
	await process_frame
	_check(_worker.is_excavating(), "botão direito na rocha cria ordem de escavação")
	_check(_worker.current_excavation_target() == _rocks[0], "alvo de escavação é a rocha atingida pelo ray")
	_check(_worker.has_move_target(), "Worker começa a se aproximar da rocha")
	_check(_rocks[0].state.remaining_work > 3.5, "rocha ainda quase intacta no início da aproximação")


func _test_approach_stops_in_work_range() -> void:
	await _wait_until_not_moving(4.0)
	var distance := _planar_distance(_rocks[0].global_position)
	_check(distance <= _worker.work_range + 0.05,
			"Worker para dentro do work_range: %f <= %f" % [distance, _worker.work_range + 0.05])
	_check(distance >= ROCK_HALF + WORKER_CAPSULE_RADIUS,
			"Worker não entra na rocha: %f >= %f" % [distance, ROCK_HALF + WORKER_CAPSULE_RADIUS])
	_check(not _overlaps_diggable(_worker_chest(), WORKER_CAPSULE_RADIUS - 0.01),
			"query física: cápsula do Worker não sobrepõe a rocha")
	_check(_worker.velocity == Vector3.ZERO, "Worker para ao chegar na posição de trabalho")
	_check(_worker.is_excavating(), "ordem de escavação continua ativa parado")
	_check(_close(_worker.global_position.y, 0.0, 0.005), "Worker permanece sobre o piso (y=%f)"
			% _worker.global_position.y)


func _test_work_over_time() -> void:
	var before := _rocks[0].state.remaining_work
	_clock.reset()
	await _advance(1.0)
	var after := _rocks[0].state.remaining_work
	var expected := _worker.definition.work_speed * _clock.elapsed
	_check(before > 3.9, "rocha começa o trabalho com ~4.0, obtido %f" % before)
	_check(absf((before - after) - expected) < 0.05,
			"1 s de trabalho remove ~1.0 (work_speed * delta): removido %f, esperado %f"
			% [before - after, expected])
	_check(_close(after, 3.0, 0.15), "após ~1 s resta ~3.0, obtido %f" % after)
	_check(_worker.is_excavating(), "Worker continua escavando")


func _test_conclusion() -> void:
	var rock := _rocks[0]
	var guard := 0
	while is_instance_valid(rock) and guard < 60 * 12:
		await physics_frame
		guard += 1
	_check(not is_instance_valid(rock), "rocha é removida do mundo ao concluir")
	_check(not _worker.is_excavating(), "Worker limpa o alvo de escavação")
	_check(not _worker.has_move_target(), "Worker fica sem destino")
	_check(_worker.velocity == Vector3.ZERO, "Worker fica parado após concluir")
	_check(_ray(ROCK_1, 4).is_empty(), "ray Diggable não encontra mais a rocha")
	_check(_ray(ROCK_1, 1).get("collider", null) != null, "ray Ground encontra o piso no lugar da rocha")
	_check(not _overlaps_diggable(ROCK_1, 0.5), "collider da rocha desapareceu da space state")
	var resting := _worker.global_position
	await _advance(0.5)
	_check(_worker.global_position.distance_to(resting) < 0.0001,
			"Worker permanece parado onde terminou (%s)" % resting)


func _test_cancel_keeps_progress() -> void:
	var rock := _rocks[2]
	await _reset_worker()
	_controller._select(_worker)
	await process_frame
	_click(MOUSE_BUTTON_RIGHT, rock.global_position)
	await _wait_until_not_moving(6.0)
	_clock.reset()
	await _advance(1.0)
	var progress := rock.state.remaining_work
	_check(_close(progress, 3.0, 0.15), "rocha do cancelamento ficou em ~3.0, obtido %f" % progress)
	_click(MOUSE_BUTTON_RIGHT, GROUND_POINT)
	await process_frame
	_check(not _worker.is_excavating(), "ordem de movimento cancela a escavação")
	_check(_worker.has_move_target(), "Worker passa a se mover")
	await _advance(0.5)
	_check(_close(rock.state.remaining_work, progress, 0.0001),
			"progresso da rocha não regride nem avança após cancelar")
	_check(_worker.global_position.distance_to(WORKER_START) > 0.5, "Worker realmente saiu do local")


func _test_resume_continues_progress() -> void:
	var rock := _rocks[2]
	var before := rock.state.remaining_work
	await _wait_until_not_moving(6.0)
	_controller._select(_worker)
	await process_frame
	_click(MOUSE_BUTTON_RIGHT, rock.global_position)
	await _wait_until_not_moving(6.0)
	_clock.reset()
	await _advance(1.0)
	var after := rock.state.remaining_work
	_check(before < 3.1, "rocha retoma de ~3.0 e não de 4.0, obtido %f" % before)
	_check(_close(before - after, _worker.definition.work_speed * _clock.elapsed, 0.05),
			"retomada aplica work_speed * delta, removido %f" % (before - after))
	_check(_close(after, 2.0, 0.2), "após retomar 1 s resta ~2.0, obtido %f" % after)


func _test_switch_target() -> void:
	var old_rock: RockRuntime = _rocks[2]
	var new_rock: RockRuntime = _rocks[1]
	var old_progress := old_rock.state.remaining_work
	_click(MOUSE_BUTTON_RIGHT, new_rock.global_position)
	await process_frame
	_check(_worker.current_excavation_target() == new_rock, "nova rocha substitui o alvo")
	_check(_worker.has_move_target(), "Worker parte para a nova rocha")
	await _advance(0.5)
	_check(_close(old_rock.state.remaining_work, old_progress, 0.0001),
			"rocha anterior conserva o progresso de %f" % old_progress)
	await _wait_until_not_moving(8.0)
	_check(_planar_distance(new_rock.global_position) <= _worker.work_range + 0.05,
			"Worker alcança a nova rocha a %f" % _planar_distance(new_rock.global_position))
	_clock.reset()
	await _advance(1.0)
	_check(_close(new_rock.state.remaining_work, 3.0, 0.15),
			"nova rocha perde ~1.0 de trabalho, resta %f" % new_rock.state.remaining_work)


func _test_work_fps_independence() -> void:
	var rock := _rocks[1]
	var work_30 := await _measure_work(30)
	var work_120 := await _measure_work(120)
	Engine.set_physics_ticks_per_second(60)
	await process_frame
	_check(_close(work_30.done, work_30.seconds * _worker.definition.work_speed, 0.06),
			"trabalho a 30 Hz = %f em %f s" % [work_30.done, work_30.seconds])
	_check(_close(work_120.done, work_120.seconds * _worker.definition.work_speed, 0.06),
			"trabalho a 120 Hz = %f em %f s" % [work_120.done, work_120.seconds])
	_check(absf(work_30.done - work_120.done) < 0.08,
			"mesmo tempo de trabalho em 30 Hz e 120 Hz (%f vs %f)" % [work_30.done, work_120.done])
	_check(work_120.ticks > work_30.ticks * 3,
			"taxas realmente distintas: %d vs %d ticks" % [work_30.ticks, work_120.ticks])


class WorkRun:
	var done := 0.0
	var seconds := 0.0
	var ticks := 0


func _measure_work(ticks_per_second: int) -> WorkRun:
	Engine.set_physics_ticks_per_second(ticks_per_second)
	await process_frame
	var rock := _rocks[1]
	await _wait_until_not_moving(4.0)
	_clock.reset()
	var before := rock.state.remaining_work
	await _advance(1.0)
	var result := WorkRun.new()
	result.done = before - rock.state.remaining_work
	result.seconds = _clock.elapsed
	result.ticks = _clock.ticks
	return result


func _test_no_resources_no_managers() -> void:
	var fields: Array[String] = []
	for property in RockDefinition.new().get_property_list():
		if not property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			continue
		fields.append(property.name)
	_check(fields == ["rock_type_id", "display_name", "work_required",
			"yield_resource", "yield_amount"],
			"RockDefinition só expõe os 5 campos previstos: %s" % [fields])
	_check(_scene.find_child("Drop*", true, false) == null, "nenhum nó de recurso foi criado ao escavar")
	_check(_scene.find_child("*Manager*", true, false) == null, "nenhum manager de jobs foi criado")
	_check(_scene.find_child("Navigation*", true, false) == null, "nenhum nó de navegação foi criado")
	var autoloads: Dictionary = ProjectSettings.get_setting("autoload", {})
	_check(autoloads.is_empty(), "nenhum autoload/singleton foi adicionado")
	_check(_rocks.size() == 4 and is_instance_valid(_rocks[1]) and is_instance_valid(_rocks[2]),
			"as demais rochas continuam disponíveis após a escavação")


func _reset_worker(position_at: Vector3 = WORKER_START) -> void:
	_worker.velocity = Vector3.ZERO
	_worker.global_position = position_at
	_worker.move_to(position_at)
	await _advance(0.05)


func _wait_until_not_moving(max_seconds: float) -> void:
	var limit := int(max_seconds * Engine.get_physics_ticks_per_second())
	var guard := 0
	while _worker.has_move_target() and guard < limit:
		await physics_frame
		guard += 1
	if _worker.has_move_target():
		_check(false, "Worker não terminou de se mover em %f s" % max_seconds)


func _advance(seconds: float) -> void:
	var ticks := int(ceil(seconds * Engine.get_physics_ticks_per_second()))
	for i in ticks:
		await physics_frame


func _click(button: int, world_position: Vector3) -> void:
	_click_at_screen(button, _camera.unproject_position(world_position))


func _click_at_screen(button: int, screen_position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	event.position = screen_position
	event.global_position = screen_position
	root.push_input(event)


func _planar_distance(target: Vector3) -> float:
	var offset := target - _worker.global_position
	offset.y = 0.0
	return offset.length()


func _worker_chest() -> Vector3:
	return _worker.global_position + Vector3(0, 0.8, 0)


func _space() -> PhysicsDirectSpaceState3D:
	return _scene.get_viewport().world_3d.direct_space_state


func _ray(world_position: Vector3, mask: int) -> Dictionary:
	var origin := _camera.global_position
	var direction := (world_position - origin).normalized()
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 1000.0, mask)
	return _space().intersect_ray(query)


func _ray_at_screen(screen_position: Vector2, mask: int) -> Dictionary:
	var origin := _camera.project_ray_origin(screen_position)
	var direction := _camera.project_ray_normal(screen_position)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 1000.0, mask)
	return _space().intersect_ray(query)


func _overlaps_diggable(point: Vector3, radius: float) -> bool:
	var shape := SphereShape3D.new()
	shape.radius = radius
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = Transform3D(Basis.IDENTITY, point)
	params.collision_mask = 4
	return not _space().intersect_shape(params, 1).is_empty()


func _close(a: float, b: float, tolerance: float = 0.001) -> bool:
	return absf(a - b) <= tolerance


func _finish() -> void:
	print("---- excavation tests finished: %d asserts, %d failure(s) ----" % [_asserts, _failures])
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	_asserts += 1
	if condition:
		print("[PASS] %s" % label)
	else:
		_failures += 1
		print("[FAIL] %s" % label)
