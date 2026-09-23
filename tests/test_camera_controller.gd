extends SceneTree

const MAIN_SCENE := preload("res://game/GameMain.tscn")
const DELTA := 0.5

var _failures := 0
var _rig: CameraController
var _ran := false


func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	_run_tests()
	print("---- tests finished: %d failure(s) ----" % _failures)
	quit(1 if _failures > 0 else 0)
	return true


func _run_tests() -> void:
	var scene := MAIN_SCENE.instantiate()
	root.add_child(scene)

	_rig = scene.get_node("World/CameraRig") as CameraController
	var camera: Camera3D = scene.get_node("World/CameraRig/Camera3D")
	var light: DirectionalLight3D = scene.get_node("World/Environment/DirectionalLight3D")
	_rig.set_process(false)

	_check(is_instance_valid(camera), "Camera3D existe na cena")
	_check(camera.global_position.y > 0.0, "camera inicia acima do chao")
	_check(_close(light.rotation_degrees.x, -60.0) and _close(light.rotation_degrees.y, -30.0),
			"luz em (-60, -30), obtido %s" % [light.rotation_degrees])
	_check(_close(camera.rotation_degrees.x, -_rig.tilt_degrees), "camera mantem inclinacao do rig")

	_test_movement()
	_test_bounds()
	_test_zoom(camera)


func _test_movement() -> void:
	var start := _rig.global_position
	var step := _rig.move_speed * DELTA

	_press("camera_forward")
	_step()
	_check(_close(_rig.global_position.z, start.z - step, 0.01), "W avanca em -Z")
	_check(_close(_rig.global_position.x, start.x, 0.01), "W nao altera X")
	_release("camera_forward")

	_press("camera_backward")
	_step()
	_check(_close(_rig.global_position.z, start.z, 0.01), "S retorna ao inicio")
	_release("camera_backward")

	_press("camera_right")
	_step()
	_check(_close(_rig.global_position.x, start.x + step, 0.01), "D avanca em +X")
	_release("camera_right")

	_press("camera_left")
	_step()
	_check(_close(_rig.global_position.x, start.x, 0.01), "A retorna ao inicio")
	_release("camera_left")

	_press("camera_forward")
	_press("camera_right")
	_step()
	var diagonal := (_rig.global_position - start).length()
	_check(_close(diagonal, step, 0.01), "diagonal normalizada: %f, esperado %f" % [diagonal, step])
	_release("camera_forward")
	_release("camera_right")
	_rig.global_position = start


func _test_bounds() -> void:
	_press("camera_forward")
	for i in 200:
		_step()
	_release("camera_forward")
	_check(_close(_rig.global_position.z, -_rig.movement_bound, 0.001),
			"rig para no limite -Z em %f" % _rig.global_position.z)
	_rig.global_position = Vector3.ZERO


func _test_zoom(camera: Camera3D) -> void:
	var start_distance: float = _rig.initial_zoom_distance
	_wheel(true)
	_check(_close(_rig._zoom_distance, start_distance - _rig.zoom_step, 0.001), "wheel up aproxima")
	_wheel(false)
	_check(_close(_rig._zoom_distance, start_distance, 0.001), "wheel down afasta")

	for i in 50:
		_wheel(true)
	_check(_close(_rig._zoom_distance, _rig.min_zoom_distance, 0.001),
			"zoom respeita minimo: %f" % _rig._zoom_distance)
	_check(camera.global_position.y > 0.0, "camera nao atravessa o chao no zoom minimo")

	for i in 50:
		_wheel(false)
	_check(_close(_rig._zoom_distance, _rig.max_zoom_distance, 0.001),
			"zoom respeita maximo: %f" % _rig._zoom_distance)

	_check(not is_nan(_rig.global_position.x) and not is_nan(_rig.global_position.z), "rig sem NaN")
	_check(not is_nan(camera.global_position.y), "camera sem NaN")


func _press(action: String) -> void:
	Input.action_press(action)


func _release(action: String) -> void:
	Input.action_release(action)


func _step() -> void:
	_rig._process(DELTA)


func _wheel(zoom_in: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_WHEEL_UP if zoom_in else MOUSE_BUTTON_WHEEL_DOWN
	event.pressed = true
	_rig._unhandled_input(event)


func _close(a: float, b: float, tolerance: float = 0.5) -> bool:
	return absf(a - b) <= tolerance


func _check(condition: bool, label: String) -> void:
	if condition:
		print("[PASS] %s" % label)
	else:
		_failures += 1
		print("[FAIL] %s" % label)
