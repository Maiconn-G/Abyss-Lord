extends SceneTree

const MAIN_SCENE := preload("res://game/GameMain.tscn")
const WORKER_START := Vector3(2, 0, 2)
const MOVE_TARGET := Vector3(5, 0, 2)
const GROUND_POINT := Vector3(-6, 0, -4)
const TRAVEL := 3.0


var _failures := 0
var _asserts := 0
var _frames := 0
var _scene: Node
var _worker: WorkerRuntime
var _camera: Camera3D
var _controller: SelectionController
var _ground: StaticBody3D
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
	if _frames > 8000:
		_check(false, "timeout: a suíte RTS não terminou")
		_finish()
	return false


func _run_all() -> void:
	await process_frame
	_test_input_actions()
	_boot_scene()
	await _advance(0.1)
	_test_ground_collision()
	_test_worker_collision()
	_test_controller_wiring()
	_test_state_not_polluted()
	_test_indicator_initially_hidden()
	_test_raycast_identifies_worker()
	_test_raycast_identifies_ground()
	await _test_left_click_selects_worker()
	await _test_left_click_on_ground_clears_selection()
	await _test_reselect_worker()
	await _test_right_click_without_selection()
	await _test_right_click_on_unit_gives_no_order()
	await _test_move_to_sets_target()
	await _test_velocity_matches_move_speed()
	await _test_arrival()
	await _test_no_overshoot()
	await _test_order_is_replaced()
	await _test_fps_independence()
	await _test_no_navigation_nodes()
	_finish()


func _boot_scene() -> void:
	_scene = MAIN_SCENE.instantiate()
	root.add_child(_scene)
	_worker = _scene.get_node("World/DungeonRoot/Worker001") as WorkerRuntime
	_camera = _scene.get_node("World/CameraRig/Camera3D") as Camera3D
	_controller = _scene.get_node("Systems/SelectionController") as SelectionController
	_ground = _scene.get_node("World/Environment/TestFloorBody") as StaticBody3D
	_clock = FrameClock.new()
	_clock.name = "FrameClock"
	root.add_child(_clock)


func _test_input_actions() -> void:
	_check(InputMap.has_action("select_unit"), "ação select_unit existe")
	_check(InputMap.has_action("command_move"), "ação command_move existe")
	_check(_action_uses_mouse_button("select_unit", MOUSE_BUTTON_LEFT),
			"select_unit = botão esquerdo do mouse")
	_check(_action_uses_mouse_button("command_move", MOUSE_BUTTON_RIGHT),
			"command_move = botão direito do mouse")


func _test_ground_collision() -> void:
	_check(_ground != null, "GameMain possui TestFloorBody (StaticBody3D)")
	var shape_node := _ground.get_node_or_null("CollisionShape3D") as CollisionShape3D
	_check(shape_node != null and shape_node.shape is BoxShape3D,
			"chão possui CollisionShape3D com BoxShape3D")
	var box := shape_node.shape as BoxShape3D
	_check(_close(box.size.x, 30.0) and _close(box.size.z, 30.0) and _close(box.size.y, 0.1, 0.02),
			"shape do chão ~ 30 x 0.1 x 30, obtido %s" % box.size)
	var top := shape_node.position.y + box.size.y * 0.5
	_check(_close(top, 0.0, 0.001), "topo da colisão do chão coincide com Y=0, obtido %f" % top)
	_check(_ground.collision_layer == 1, "chão está na layer Ground (1)")


func _test_worker_collision() -> void:
	_check(_worker.collision_layer == 2, "Worker está na layer Units (2)")
	_check(_worker.collision_mask & 1 == 1, "Worker detecta a layer Ground")
	_check(_worker.collision_layer & _worker.collision_mask == 0,
			"layer e mask do Worker não se sobrepõem")


func _test_controller_wiring() -> void:
	_check(_controller != null, "SelectionController vive em GameMain/Systems")
	_check(_controller.camera == _camera, "controller recebe a Camera3D explicitamente via setup")
	_check(_controller.selected_unit == null, "nada selecionado no início")


func _test_state_not_polluted() -> void:
	_check(_worker.state.get("selected") == null, "WorkerState não guarda selected")
	_check(_worker.state.get("target_position") == null, "WorkerState não guarda target_position")
	_check(_worker.state.get("velocity") == null, "WorkerState não guarda velocity")
	_check(_worker.get("arrival_distance") != null, "arrival_distance pertence ao Runtime")


func _test_indicator_initially_hidden() -> void:
	var indicator := _worker.get_node_or_null("SelectionIndicator") as MeshInstance3D
	_check(indicator != null, "WorkerRuntime possui SelectionIndicator")
	_check(indicator != null and not indicator.visible, "indicador começa invisível")


func _test_raycast_identifies_worker() -> void:
	var hit := _ray_to(_worker.global_position, 1 | 2)
	_check(not hit.is_empty(), "ray na posição do Worker atinge algo")
	_check(hit.get("collider", null) is WorkerRuntime, "a cena real identifica o Worker pelo ray")


func _test_raycast_identifies_ground() -> void:
	var hit := _ray_to(GROUND_POINT, 1 | 2)
	_check(hit.get("collider", null) == _ground, "a cena real identifica o Ground pelo ray")
	var point := hit.get("position", Vector3.INF) as Vector3
	_check(_close(point.y, 0.0, 0.001), "ray do chão atinge Y=0, obtido %f" % point.y)
	_check(_ray_to(GROUND_POINT, 2).is_empty(),
			"ray restrito à layer Units não confunde o chão com unidade")
	_check(not _ray_to(_worker.global_position, 2).is_empty(),
			"ray restrito à layer Units encontra o Worker")
	_check(_ray_to(_worker.global_position, 1).get("collider", null) == _ground,
			"ray restrito à layer Ground vê apenas o chão sob o Worker")


func _test_left_click_selects_worker() -> void:
	_click(MOUSE_BUTTON_LEFT, _worker.global_position)
	await process_frame
	_check(_controller.selected_unit == _worker, "clique esquerdo seleciona o Worker")
	_check(_worker.get_node("SelectionIndicator").visible, "indicador aparece com a seleção")


func _test_left_click_on_ground_clears_selection() -> void:
	_click(MOUSE_BUTTON_LEFT, GROUND_POINT)
	await process_frame
	_check(_controller.selected_unit == null, "clique no chão limpa a seleção")
	_check(not _worker.get_node("SelectionIndicator").visible, "indicador some com a desseleção")


func _test_reselect_worker() -> void:
	_click(MOUSE_BUTTON_LEFT, _worker.global_position)
	await process_frame
	_check(_controller.selected_unit == _worker, "Worker pode ser selecionado novamente")
	_click(MOUSE_BUTTON_LEFT, _worker.global_position)
	await process_frame
	_check(_controller.selected_unit == _worker, "repetir o clique mantém a seleção")
	_check(_only_one_selected(), "no máximo uma unidade selecionada")


func _test_right_click_without_selection() -> void:
	_controller._select(null)
	await _reset_worker()
	_click(MOUSE_BUTTON_RIGHT, Vector3(8, 0, 6))
	await _advance(0.2)
	_check(not _worker.has_move_target(), "botão direito sem seleção não emite ordem")
	_check(_worker.global_position.distance_to(WORKER_START) < 0.0001,
			"Worker permanece parado sem seleção")


func _test_right_click_on_unit_gives_no_order() -> void:
	_controller._select(_worker)
	_click(MOUSE_BUTTON_RIGHT, _worker.global_position)
	await _advance(0.2)
	_check(not _worker.has_move_target(), "botão direito sobre a unidade não emite ordem")
	_check(_controller.selected_unit == _worker, "clicar na unidade mantém a seleção")


func _test_move_to_sets_target() -> void:
	_controller._select(_worker)
	_click(MOUSE_BUTTON_RIGHT, MOVE_TARGET)
	await process_frame
	_check(_worker.has_move_target(), "botão direito no chão envia ordem de movimento")
	_check(_worker.global_position.distance_to(WORKER_START) < 0.2,
			"a ordem não teleporta a unidade")


func _test_velocity_matches_move_speed() -> void:
	var tick_seconds := 1.0 / float(Engine.get_physics_ticks_per_second())
	var expected_step := _worker.definition.move_speed * tick_seconds
	# physics_frame é emitido antes dos _physics_process do passo: o primeiro
	# sample ainda mostra o tick anterior, entao medimos entre ticks sincronizados.
	var samples: Array[Vector3] = []
	for i in 5:
		await physics_frame
		samples.append(_worker.global_position)
	_check(_close(_worker.velocity.length(), _worker.definition.move_speed, 0.01),
			"velocidade horizontal = move_speed 3.5, obtido %f" % _worker.velocity.length())
	_check(_close(samples[4].distance_to(samples[3]), expected_step, expected_step * 0.05),
			"deslocamento por tick = speed * delta, delta usado uma vez: esperado %f, obtido %f"
			% [expected_step, samples[4].distance_to(samples[3])])
	_check(_close(_worker.velocity.y, 0.0, 0.0001), "velocity.y permanece zero")
	_check(_close(samples[4].x - samples[3].x, expected_step, expected_step * 0.05)
			and _close(samples[4].z, samples[3].z, 0.0001) and _close(samples[4].y, samples[3].y, 0.0001),
			"deslocamento acontece apenas no plano horizontal")


func _test_arrival() -> void:
	await _wait_until_arrived()
	_check(not _worker.has_move_target(), "destino é encerrado na chegada")
	_check(_worker.global_position.distance_to(MOVE_TARGET) <= 0.0001,
			"Worker chega em (5, 0, 2), obtido %s" % _worker.global_position)
	_check(_worker.velocity == Vector3.ZERO, "velocity zera na chegada")
	_check(_close(_worker.global_position.y, 0.0, 0.005),
			"Y inalterado durante o movimento, obtido %f" % _worker.global_position.y)


func _test_no_overshoot() -> void:
	await _reset_worker(Vector3(5, 0, 2))
	_controller._select(_worker)
	var samples: Array[Vector3] = []
	_worker.move_to(Vector3(5.05, 0, 2))
	for i in 6:
		await physics_frame
		samples.append(_worker.global_position)
	_check(_close(_worker.global_position.x, 5.05, 0.0001),
			"destino a 0.05 unidades não provoca overshoot, x=%f" % _worker.global_position.x)
	_check(not _worker.has_move_target(), "ordem curta encerra sem orbitar o alvo")
	_check(_worker.velocity == Vector3.ZERO, "unidade fica imediatamente parada")
	_check(samples.back().distance_to(samples[0]) < 0.0001,
			"sem oscilação nos frames seguintes, variação %f" % samples.back().distance_to(samples[0]))


func _test_order_is_replaced() -> void:
	await _reset_worker()
	_controller._select(_worker)
	_worker.move_to(Vector3(12, 0, 12))
	await _advance(0.2)
	var midway := _worker.global_position
	_check(midway.distance_to(WORKER_START) > 0.1, "Worker começa a ir para A")
	_worker.move_to(Vector3(-4, 0, 3))
	await _advance(0.1)
	var heading := _worker.velocity.normalized()
	_check(_worker.has_move_target(), "ordem B substitui A imediatamente")
	_check(heading.x < 0.0, "direção passa a apontar para B, obtido %s" % _worker.velocity)
	await _wait_until_arrived()
	_check(_worker.global_position.distance_to(Vector3(-4, 0, 3)) < 0.0001,
			"Worker termina em B e não em A, obtido %s" % _worker.global_position)


func _test_fps_independence() -> void:
	var expected_seconds := TRAVEL / _worker.definition.move_speed
	var run_30 := await _measure_run(30)
	var run_120 := await _measure_run(120)
	Engine.set_physics_ticks_per_second(60)
	await process_frame
	_check(run_30.arrived and run_120.arrived, "as duas execuções chegaram ao destino")
	_check(run_120.ticks > run_30.ticks * 3,
			"taxas físicas realmente distintas: %d ticks vs %d ticks" % [run_30.ticks, run_120.ticks])
	_check(_close(run_30.seconds, expected_seconds, 0.06),
			"trajeto a 30 Hz leva ~%f s, obtido %f" % [expected_seconds, run_30.seconds])
	_check(_close(run_120.seconds, expected_seconds, 0.06),
			"trajeto a 120 Hz leva ~%f s, obtido %f" % [expected_seconds, run_120.seconds])
	_check(absf(run_30.seconds - run_120.seconds) < 0.08,
			"tempo de chegada independe do FPS (30Hz=%f, 120Hz=%f)" % [run_30.seconds, run_120.seconds])


func _test_no_navigation_nodes() -> void:
	await process_frame
	_check(_scene.find_child("NavigationAgent3D", true, false) == null,
			"nenhum NavigationAgent3D foi criado")
	_check(_scene.find_child("NavigationRegion3D", true, false) == null,
			"nenhum NavigationRegion3D foi criado")
	_check(_controller.selected_unit == _worker, "seleção sobrevive à bateria de testes")


class RunResult:
	var arrived := false
	var ticks := 0
	var seconds := 0.0


func _measure_run(ticks_per_second: int) -> RunResult:
	Engine.set_physics_ticks_per_second(ticks_per_second)
	await process_frame
	await _reset_worker()
	_controller._select(_worker)
	_clock.reset()
	_worker.move_to(MOVE_TARGET)
	var guard := 0
	while _worker.has_move_target() and guard < ticks_per_second * 5:
		await physics_frame
		guard += 1
	var result := RunResult.new()
	result.arrived = not _worker.has_move_target()
	result.ticks = _clock.ticks
	result.seconds = _clock.elapsed
	if not (result.arrived and _worker.global_position.distance_to(MOVE_TARGET) < 0.0001):
		_check(false, "execução a %d Hz não chegou corretamente em %s"
				% [ticks_per_second, _worker.global_position])
	_check(_worker.velocity == Vector3.ZERO, "execução a %d Hz termina parada" % ticks_per_second)
	return result


func _reset_worker(position_at: Vector3 = WORKER_START) -> void:
	_worker.velocity = Vector3.ZERO
	_worker.global_position = position_at
	_worker.move_to(position_at)
	await _advance(0.05)


func _wait_until_arrived() -> void:
	var limit := Engine.get_physics_ticks_per_second() * 6
	var guard := 0
	while _worker.has_move_target() and guard < limit:
		await physics_frame
		guard += 1
	if _worker.has_move_target():
		_check(false, "Worker não chegou ao destino em %d ticks" % limit)


func _advance(seconds: float) -> void:
	var ticks := int(ceil(seconds * Engine.get_physics_ticks_per_second()))
	for i in ticks:
		await physics_frame


func _click(button: int, world_position: Vector3) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	event.position = _camera.unproject_position(world_position)
	event.global_position = event.position
	_controller._unhandled_input(event)


func _ray_to(world_position: Vector3, mask: int) -> Dictionary:
	var origin := _camera.global_position
	var direction := (world_position - origin).normalized()
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 1000.0, mask)
	return _scene.get_viewport().world_3d.direct_space_state.intersect_ray(query)


func _only_one_selected() -> bool:
	var selected := 0
	for node in _scene.find_children("*", "CharacterBody3D", true, false):
		var runtime := node as WorkerRuntime
		if runtime != null and runtime.get_node("SelectionIndicator").visible:
			selected += 1
	return selected == 1


func _action_uses_mouse_button(action: StringName, button: int) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == button:
			return true
	return false


func _close(a: float, b: float, tolerance: float = 0.001) -> bool:
	return absf(a - b) <= tolerance


func _finish() -> void:
	print("---- rts tests finished: %d asserts, %d failure(s) ----" % [_asserts, _failures])
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	_asserts += 1
	if condition:
		print("[PASS] %s" % label)
	else:
		_failures += 1
		print("[FAIL] %s" % label)
