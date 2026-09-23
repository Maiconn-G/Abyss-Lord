extends SceneTree

const MAIN_SCENE := preload("res://game/GameMain.tscn")
const PILE_SCENE := preload("res://world/resources/ResourcePileRuntime.tscn")
const IRON_ORE_PATH := "res://data/resources/iron_ore.tres"
const IRON_ORE_ROCK_PATH := "res://data/environment/iron_ore_rock.tres"
const COMMON_ROCK_PATH := "res://data/environment/common_rock.tres"
const WORKER_DEF_PATH := "res://data/units/workers/abyss_worker.tres"
const ROCK_SCENE_PATH := "res://world/dungeon/rock/RockRuntime.tscn"

const WORKER_START := Vector3(2, 0, 2)
const MOVE_AWAY := Vector3(2, 0, -3)
const CANCEL_TARGET := Vector3(0, 0, -6)
const COMMON_ROCK_COLOR := Color(0.46, 0.43, 0.38, 1)

const GROUND_LAYER := 1
const UNIT_LAYER := 2
const DIGGABLE_LAYER := 4
const RESOURCE_LAYER := 8

var _failures := 0
var _asserts := 0
var _frames := 0
var _scene: Node
var _dungeon: Node3D
var _worker: WorkerRuntime
var _camera: Camera3D
var _controller: SelectionController
var _deposit: ResourceDepositRuntime
var _core_hud: Control
var _resource_hud: Control
var _rocks: Array[RockRuntime] = []
var _stockpile: ResourceStockpileState
var _clock: WorkClock
var _probe: CargoProbe


func _initialize() -> void:
	_run_all()


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > 20000:
		_check(false, "timeout: a suíte de recursos não terminou")
		_finish()
	return false


class WorkClock extends Node:
	var ticks := 0
	var running := false

	func _physics_process(_delta: float) -> void:
		if running:
			ticks += 1

	func reset() -> void:
		ticks = 0
		running = true

	func seconds() -> float:
		running = false
		return float(ticks) / Engine.get_physics_ticks_per_second()


func _run_all() -> void:
	await process_frame
	_test_resource_definition()
	_test_iron_ore_rock_definition()
	_test_common_rock_has_no_yield()
	_test_pile_state_initial()
	_test_pile_take()
	_test_pile_take_more_than_available()
	_test_pile_take_invalid()
	_test_pile_depleted_once()
	_test_stockpile_starts_empty()
	_test_stockpile_add_and_signal()
	_test_stockpile_invalid_amounts()
	_test_worker_cargo_initial()
	_test_worker_cargo_set_and_clear()
	_test_worker_cargo_capacity_clamp()
	_test_worker_cargo_rejects_mixed_resource()
	_boot_scene()
	await _advance(0.1)
	await _test_pile_runtime_scene()
	_test_deposit_in_scene()
	_test_ore_rock_in_scene()
	_test_physics_layers()
	_test_hud_panels_ignore_mouse()
	_test_worker_capacity_comes_from_definition()
	await _test_full_economic_cycle()
	await _test_cancel_before_pickup()
	await _test_partial_pile()
	await _test_pile_invalidation()
	await _test_common_rock_produces_no_drop()
	_test_no_managers_no_autoload()
	_finish()


func _iron_ore() -> ResourceDefinition:
	return load(IRON_ORE_PATH) as ResourceDefinition


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


# ---------------------------------------------------------------- Definitions


func _test_resource_definition() -> void:
	var ore := _iron_ore()
	_check(ore != null, "iron_ore.tres carrega")
	_check(ore is ResourceDefinition, "iron_ore.tres usa ResourceDefinition")
	_check(ore.resource_id == &"iron_ore", "resource_id = iron_ore")
	_check(ore.display_name == "Minério de Ferro", "display_name = Minério de Ferro")
	_check(_script_fields("res://core/definitions/resource_definition.gd")
			== ["resource_id", "display_name"],
			"ResourceDefinition só expõe os 2 campos previstos")


func _test_iron_ore_rock_definition() -> void:
	var rock := load(IRON_ORE_ROCK_PATH) as RockDefinition
	_check(rock != null, "iron_ore_rock.tres carrega")
	_check(rock.rock_type_id == &"iron_ore_rock", "rock_type_id = iron_ore_rock")
	_check(rock.display_name == "Rocha de Minério de Ferro", "display_name da rocha de minério")
	_check(_close(rock.work_required, 5.0), "work_required = 5.0")
	_check(rock.yield_resource == _iron_ore(), "yield_resource aponta para iron_ore.tres")
	_check(rock.yield_amount == 3, "yield_amount = 3")


func _test_common_rock_has_no_yield() -> void:
	var rock := load(COMMON_ROCK_PATH) as RockDefinition
	_check(rock.yield_resource == null, "Rocha Comum não referencia recurso")
	_check(rock.yield_amount == 0, "Rocha Comum produz 0 de recurso")


# ------------------------------------------------------------------ Pile State


func _test_pile_state_initial() -> void:
	var pile := ResourcePileState.new(_iron_ore(), "iron_ore_001_drop", 3)
	_check(pile.pile_id == "iron_ore_001_drop", "pile_id deriva da rocha de origem")
	_check(pile.definition == _iron_ore(), "ResourcePileState referencia a Definition")
	_check(pile.amount == 3, "amount inicial = 3")
	_check(typeof(pile.amount) == TYPE_INT, "amount é int, não float")
	_check(not pile.is_depleted(), "pile novo não nasce esgotado")


func _test_pile_take() -> void:
	var pile := ResourcePileState.new(_iron_ore(), "p", 3)
	var taken := pile.take(1)
	_check(taken == 1, "take(1) devolve 1")
	_check(pile.amount == 2, "3 - take(1) deixa 2")
	_check(typeof(taken) == TYPE_INT, "take devolve int")


func _test_pile_take_more_than_available() -> void:
	var pile := ResourcePileState.new(_iron_ore(), "p", 3)
	_check(pile.take(10) == 3, "take(10) com 3 disponível devolve 3")
	_check(pile.amount == 0, "pile esvazia")
	_check(pile.is_depleted(), "is_depleted() verdadeiro ao zerar")


func _test_pile_take_invalid() -> void:
	var pile := ResourcePileState.new(_iron_ore(), "p", 3)
	_check(pile.take(0) == 0, "take(0) devolve 0")
	_check(pile.amount == 3, "take(0) não altera estado")
	_check(pile.take(-10) == 0, "take(-10) devolve 0")
	_check(pile.amount == 3, "take(-10) não altera estado")
	pile.take(3)
	_check(pile.take(1) == 0, "take em pile esgotado devolve 0")
	_check(pile.amount == 0, "amount nunca fica negativo")


func _test_pile_depleted_once() -> void:
	var pile := ResourcePileState.new(_iron_ore(), "p", 3)
	var changes: Array[int] = []
	var depletions: Array[int] = []
	pile.amount_changed.connect(func(current: int) -> void: changes.append(current))
	pile.depleted.connect(func() -> void: depletions.append(1))
	pile.take(1)
	_check(changes == [2], "amount_changed emite o valor atual (2)")
	pile.take(0)
	_check(changes == [2], "take inválido não emite amount_changed")
	pile.take(2)
	_check(changes == [2, 0], "amount_changed emite 0 ao esvaziar")
	_check(depletions.size() == 1, "depleted emite exatamente uma vez")
	pile.take(1)
	_check(depletions.size() == 1, "depleted não reemite depois de esgotado")


# -------------------------------------------------------------- Stockpile State


func _test_stockpile_starts_empty() -> void:
	var stockpile := ResourceStockpileState.new()
	_check(stockpile is RefCounted, "ResourceStockpileState estende RefCounted")
	_check(stockpile.get_class() == "RefCounted",
			"ResourceStockpileState não é um Node: classe nativa %s" % stockpile.get_class())
	_check(stockpile.get_amount(&"iron_ore") == 0, "estoque começa em 0")


func _test_stockpile_add_and_signal() -> void:
	var stockpile := ResourceStockpileState.new()
	var events: Array[String] = []
	stockpile.resource_changed.connect(
			func(definition: ResourceDefinition, new_amount: int) -> void:
				events.append("%s=%d" % [definition.resource_id, new_amount])
	)
	stockpile.add_resource(_iron_ore(), 3)
	_check(stockpile.get_amount(&"iron_ore") == 3, "add_resource(3) deixa o estoque em 3")
	_check(events == ["iron_ore=3"], "resource_changed emite (iron_ore, 3)")
	stockpile.add_resource(_iron_ore(), 2)
	_check(stockpile.get_amount(&"iron_ore") == 5, "entregas acumulam no mesmo resource_id")
	_check(events == ["iron_ore=3", "iron_ore=5"], "o payload sempre traz o total novo")


func _test_stockpile_invalid_amounts() -> void:
	var stockpile := ResourceStockpileState.new()
	var events: Array[int] = []
	stockpile.resource_changed.connect(
			func(_definition: ResourceDefinition, _amount: int) -> void: events.append(1))
	stockpile.add_resource(_iron_ore(), 0)
	stockpile.add_resource(_iron_ore(), -5)
	stockpile.add_resource(null, 4)
	_check(stockpile.get_amount(&"iron_ore") == 0, "quantidade inválida não altera o estoque")
	_check(events.is_empty(), "nenhum sinal é emitido sem mudança real")
	_check(stockpile.get_amount(&"inexistente") >= 0, "estoque nunca fica negativo")


# ------------------------------------------------------------------ Worker cargo


func _new_worker_state() -> WorkerState:
	return WorkerState.new(load(WORKER_DEF_PATH) as WorkerDefinition, "worker_001")


func _test_worker_cargo_initial() -> void:
	var state := _new_worker_state()
	_check(state.carried_resource == null, "Worker começa sem recurso carregado")
	_check(state.carried_amount == 0, "Worker começa com carga 0")
	_check(not state.has_cargo(), "has_cargo() falso no início")


func _test_worker_cargo_set_and_clear() -> void:
	var state := _new_worker_state()
	state.set_cargo(_iron_ore(), 3)
	_check(state.carried_resource == _iron_ore(), "cargo guarda a Definition carregada")
	_check(state.carried_amount == 3, "cargo guarda a quantidade")
	_check(state.has_cargo(), "has_cargo() verdadeiro com carga")
	state.clear_cargo()
	_check(state.carried_resource == null and state.carried_amount == 0,
			"clear_cargo() zera os dois campos")


func _test_worker_cargo_capacity_clamp() -> void:
	var state := _new_worker_state()
	state.set_cargo(_iron_ore(), 10)
	_check(state.carried_amount == 3, "set_cargo(10) satura em carry_capacity = 3")
	state.clear_cargo()
	state.set_cargo(_iron_ore(), 0)
	_check(state.carried_amount == 0, "set_cargo(0) não cria carga")
	state.set_cargo(_iron_ore(), -7)
	_check(state.carried_amount == 0, "quantidade negativa recusada")
	_check(state.definition.carry_capacity == 3, "o limite vem da WorkerDefinition")


func _test_worker_cargo_rejects_mixed_resource() -> void:
	var state := _new_worker_state()
	var outro: ResourceDefinition = ResourceDefinition.new()
	outro.resource_id = &"outro_recurso"
	state.set_cargo(_iron_ore(), 2)
	state.set_cargo(outro, 1)
	_check(state.carried_resource == _iron_ore(), "Worker não mistura dois recursos")
	_check(state.carried_amount == 2, "a recusa não altera a carga atual")


# -------------------------------------------------------------------- Cena real


class CargoProbe extends Node:
	var worker: WorkerRuntime
	var anchor := Vector3.ZERO
	var armed := false
	var captured := -1.0

	func _physics_process(_delta: float) -> void:
		if armed and worker.state.carried_amount > 0:
			var offset := anchor - worker.global_position
			offset.y = 0.0
			captured = offset.length()
			armed = false


func _boot_scene() -> void:
	_scene = MAIN_SCENE.instantiate()
	root.add_child(_scene)
	_dungeon = _scene.get_node("World/DungeonRoot") as Node3D
	_worker = _scene.get_node("World/DungeonRoot/Worker001") as WorkerRuntime
	_camera = _scene.get_node("World/CameraRig/Camera3D") as Camera3D
	_controller = _scene.get_node("Systems/SelectionController") as SelectionController
	_deposit = _scene.get_node("World/DungeonRoot/Deposit001") as ResourceDepositRuntime
	_core_hud = _scene.get_node("UI/CoreDebugPanel") as Control
	_resource_hud = _scene.get_node("UI/ResourceDebugPanel") as Control
	for child in _dungeon.get_children():
		if child is RockRuntime:
			_rocks.append(child as RockRuntime)
	_stockpile = _deposit.stockpile
	_clock = WorkClock.new()
	_clock.name = "WorkClock"
	root.add_child(_clock)
	_probe = CargoProbe.new()
	_probe.name = "CargoProbe"
	_probe.worker = _worker
	root.add_child(_probe)


func _ore_rock() -> RockRuntime:
	for rock in _rocks:
		if rock.definition.rock_type_id == &"iron_ore_rock":
			return rock
	return null


func _piles() -> Array[ResourcePileRuntime]:
	var found: Array[ResourcePileRuntime] = []
	for child in _dungeon.get_children():
		if child is ResourcePileRuntime:
			found.append(child as ResourcePileRuntime)
	return found


func _ore_label() -> Label:
	return _resource_hud.find_child("OreLabel", true, false) as Label


func _test_pile_runtime_scene() -> void:
	var pile := PILE_SCENE.instantiate() as ResourcePileRuntime
	_dungeon.add_child(pile)
	pile.position = Vector3(0, 0, 10)
	pile.setup(_iron_ore(), ResourcePileState.new(_iron_ore(), "fixture_drop", 3))
	await process_frame
	_check(pile is StaticBody3D, "ResourcePileRuntime é StaticBody3D")
	_check(pile.get_node("Visual") is MeshInstance3D, "pile possui Visual")
	_check(pile.get_node("CollisionShape3D") is CollisionShape3D, "pile possui CollisionShape3D")
	_check(pile.collision_layer == RESOURCE_LAYER, "pile usa a layer 4 ResourcePickup")
	_check(pile.collision_mask == 0, "pile não colide com nada: é passivo")
	_check(pile.definition == _iron_ore(), "setup(definition, state) injeta a Definition")
	_check(pile.state.amount == 3, "setup injeta o State criado pelo composition root")
	var mesh := (pile.get_node("Visual") as MeshInstance3D).mesh as BoxMesh
	_check(mesh.size.x >= 0.4 and mesh.size.x <= 0.6, "pile visual entre 0.4 e 0.6: %s" % mesh.size)
	var visual := pile.get_node("Visual") as MeshInstance3D
	_check(_close(visual.position.y, mesh.size.y * 0.5, 0.001),
			"Visual repousa sobre a base do pile (y=%f)" % visual.position.y)
	_check(_close(pile.global_position.y, 0.0, 0.001),
			"a raiz do pile fica em Y=0, sem flutuar")
	_check(not pile.is_processing() and not pile.is_physics_processing(),
			"pile não roda _process nem _physics_process")
	pile.state.take(3)
	await process_frame
	_check(not is_instance_valid(pile), "pile esgotado se remove do mundo")


func _test_deposit_in_scene() -> void:
	_check(_deposit is Node3D, "ResourceDepositRuntime é Node3D")
	_check(_deposit.get_node("Visual") is MeshInstance3D, "depósito possui Visual")
	_check(_deposit.get_node("DepositPoint") is Marker3D, "depósito possui DepositPoint")
	_check(_deposit.stockpile is ResourceStockpileState, "depósito recebe o StockpileState")
	_check(_deposit.find_children("*", "CollisionBody3D", true, false).is_empty(),
			"depósito não tem corpo físico e não bloqueia nada")
	_check(_deposit.deposit_point_position().distance_to(Vector3(-2, 0, 0)) < 0.001,
			"DepositPoint em (-2, 0, 0), junto ao Núcleo: %s" % _deposit.deposit_point_position())


func _test_ore_rock_in_scene() -> void:
	var rock := _ore_rock()
	_check(rock != null, "GameMain contém uma Rocha de Minério de Ferro")
	_check(rock.state.remaining_work > 4.9, "rocha de minério começa com 5.0 de trabalho")
	_check(rock.collision_layer == DIGGABLE_LAYER, "rocha de minério usa a mesma layer Diggable")
	_check(rock.get_node("Visual") is MeshInstance3D,
			"a rocha de minério reusa o mesmo RockRuntime, sem segundo Runtime")
	var rock_visual := rock.get_node("Visual") as MeshInstance3D
	var common_visual := (_rocks[0].get_node("Visual") as MeshInstance3D)
	_check(rock_visual.material_override is StandardMaterial3D,
			"a rocha de minério tem material próprio")
	_check(rock_visual.material_override != common_visual.material_override,
			"a rocha de minério é visualmente distinguível da Rocha Comum")
	_check(rock_visual.material_override.albedo_color != COMMON_ROCK_COLOR,
			"a cor da rocha de minério difere da Rocha Comum: %s"
			% rock_visual.material_override.albedo_color)
	_check(rock_visual.mesh == (common_visual.mesh as Mesh),
			"a geometria compartilhada vem da mesma cena RockRuntime")
	_check(rock.rock_id == "iron_ore_001", "rock_id da rocha de minério")


func _test_physics_layers() -> void:
	var names: Array = []
	for index in range(1, 5):
		names.append(ProjectSettings.get_setting("layer_names/3d_physics/layer_%d" % index, ""))
	_check(names == ["Ground", "Units", "Diggable", "ResourcePickup"],
			"camadas físicas nomeadas: %s" % [names])
	_check(_worker.collision_mask & RESOURCE_LAYER == 0,
			"Worker não colide fisicamente com o pile")
	_check(_worker.collision_mask & DIGGABLE_LAYER == DIGGABLE_LAYER,
			"Worker continua colidindo com rochas")
	_check(_deposit.get_class() == "Node3D",
			"depósito não é um PhysicsBody3D: classe nativa %s" % _deposit.get_class())


func _test_hud_panels_ignore_mouse() -> void:
	_check(_core_hud.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"CoreDebugPanel continua IGNORE")
	_check(_resource_hud.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"ResourceDebugPanel usa IGNORE")
	_check((_resource_hud.get_node("VBox") as Control).mouse_filter
			== Control.MOUSE_FILTER_IGNORE, "o VBox do novo HUD usa IGNORE")
	_check(_ore_label() != null, "HUD de recursos tem um Label de minério")
	_check(_ore_label().text == "Minério de Ferro: 0",
			"HUD mostra Minério de Ferro: 0 antes de qualquer entrega, obtido '%s'"
			% _ore_label().text)


func _test_worker_capacity_comes_from_definition() -> void:
	_check(_worker.get("carry_capacity") == null,
			"WorkerRuntime não guarda carry_capacity próprio")
	_check(_worker.definition.carry_capacity == 3, "a capacidade é lida da Definition no uso")
	_check(_worker.get("pickup_range") != null and _worker.get("deposit_range") != null,
			"os alcances de coleta e entrega pertencem ao Runtime")


# ------------------------------------------------------ Ciclo econômico completo


func _test_full_economic_cycle() -> void:
	var rock := _ore_rock()
	_click(MOUSE_BUTTON_LEFT, _worker.global_position)
	await process_frame
	_check(_controller.selected_unit == _worker, "clique esquerdo seleciona o Worker")

	_click(MOUSE_BUTTON_RIGHT, rock.global_position)
	await process_frame
	_check(_worker.action_mode() == WorkerRuntime.ActionMode.EXCAVATE,
			"botão direito na rocha de minério inicia escavação")
	await _wait_until_not_moving(8.0)
	_check(_planar_distance(rock.global_position) <= _worker.work_range + 0.05,
			"Worker alcança a rocha de minério a %f" % _planar_distance(rock.global_position))

	_clock.reset()
	await _advance(1.0)
	_check(_close(rock.state.remaining_work, 4.0, 0.15),
			"1 s de trabalho em work_required 5.0 deixa ~4.0, obtido %f"
			% rock.state.remaining_work)
	_check(_piles().is_empty(), "nenhum pile existe antes da escavação concluir")

	var guard := 0
	while is_instance_valid(rock) and guard < 60 * 12:
		await physics_frame
		guard += 1
	var work_seconds := _clock.seconds()
	_check(not is_instance_valid(rock), "a rocha de minério é removida ao concluir")
	_check(_close(work_seconds, 5.0, 0.35),
			"trabalho puro durou ~5 s medidos: %f s" % work_seconds)

	var piles := _piles()
	_check(piles.size() == 1, "exatamente um ResourcePile nasceu da rocha: %d" % piles.size())
	var pile := piles[0]
	var pile_state := pile.state
	_check(pile.definition == _iron_ore(), "o pile usa a Definition iron_ore")
	_check(pile_state.amount == 3, "o pile nasceu com 3 minérios")
	_check(pile_state.pile_id == "iron_ore_001_drop", "pile_id deriva do rock_id")
	_check(_close(pile.global_position.y, 0.0, 0.001),
			"o pile pousa no piso (Y=%f)" % pile.global_position.y)
	_check(_close(pile.global_position.x, -8.0, 0.001)
			and _close(pile.global_position.z, 6.0, 0.001),
			"o pile aparece no lugar da rocha: %s" % pile.global_position)
	_check(_stockpile.get_amount(&"iron_ore") == 0, "stockpile continua 0 logo após escavar")
	_check(_ore_label().text == "Minério de Ferro: 0",
			"o HUD continua 0 com o minério no chão, obtido '%s'" % _ore_label().text)
	_check(not _ray_at(_pile_top(pile), RESOURCE_LAYER).is_empty(),
			"raycast na layer ResourcePickup encontra o pile")

	_click(MOUSE_BUTTON_RIGHT, _pile_top(pile))
	await process_frame
	_check(_worker.action_mode() == WorkerRuntime.ActionMode.COLLECT,
			"botão direito REAL sobre o pile inicia coleta")
	_check(not _worker.is_excavating(), "a ordem de coleta substitui a escavação")
	var distance_at_pickup := await _wait_until_carrying(pile)
	_check(distance_at_pickup >= 0.0, "o instante da coleta foi capturado pelo probe")
	_check(distance_at_pickup <= _worker.pickup_range + 0.001,
			"Worker coleta de dentro do pickup_range: %f" % distance_at_pickup)
	_check(distance_at_pickup >= _worker.pickup_range - _worker.arrival_distance - 0.15,
			"Worker para no anel de aproximação, sem invadir o pile: %f" % distance_at_pickup)
	_check(pile_state.amount == 0, "pile foi a 0")
	_check(_worker.state.carried_amount == 3, "Worker carregou 3")
	_check(_worker.state.carried_resource == _iron_ore(), "Worker carrega iron_ore")
	_check(_worker.get_node("CarryIndicator").visible, "o indicador de carga aparece")
	_check(_worker.action_mode() == WorkerRuntime.ActionMode.DELIVER,
			"Worker entra em transporte automaticamente")
	_check(_stockpile.get_amount(&"iron_ore") == 0, "stockpile ainda 0 durante o transporte")

	_click(MOUSE_BUTTON_RIGHT, MOVE_AWAY)
	await process_frame
	_check(_worker.action_mode() == WorkerRuntime.ActionMode.DELIVER,
			"ordem de movimento é ignorada durante a entrega atômica")
	_check(_worker.state.carried_amount == 3, "a carga não é perdida pela ordem ignorada")

	await _wait_until_idle(8.0)
	_check(_stockpile.get_amount(&"iron_ore") == 3, "o estoque vira 3 ao entregar")
	_check(_worker.state.carried_amount == 0, "Worker descarrega a carga")
	_check(_worker.state.carried_resource == null, "Worker esquece o tipo carregado")
	_check(not _worker.get_node("CarryIndicator").visible, "o indicador de carga desaparece")
	_check(_worker.velocity == Vector3.ZERO, "Worker para após entregar")
	_check(_worker.action_mode() == WorkerRuntime.ActionMode.IDLE, "Worker volta a IDLE")
	_check(_ore_label().text == "Minério de Ferro: 3",
			"o HUD reage ao sinal e mostra 3, obtido '%s'" % _ore_label().text)
	_check(not is_instance_valid(pile), "o pile esgotado saiu do mundo")

	await _advance(2.0)
	_check(_stockpile.get_amount(&"iron_ore") == 3, "o estoque não duplica com o tempo passando")

	_click(MOUSE_BUTTON_RIGHT, MOVE_AWAY)
	await process_frame
	_check(_worker.action_mode() == WorkerRuntime.ActionMode.MOVE,
			"novas ordens funcionam normalmente após a entrega")
	await _wait_until_not_moving(8.0)


func _pile_top(pile: ResourcePileRuntime) -> Vector3:
	return pile.global_position + Vector3(0, 0.25, 0)


# ---------------------------------------------------------------- Casos de borda


func _spawn_fixture_pile(amount: int, at: Vector3) -> ResourcePileRuntime:
	var pile := PILE_SCENE.instantiate() as ResourcePileRuntime
	pile.position = at
	_dungeon.add_child(pile)
	pile.setup(_iron_ore(), ResourcePileState.new(_iron_ore(), "fixture_%d_drop" % amount, amount))
	return pile


func _test_cancel_before_pickup() -> void:
	var pile := _spawn_fixture_pile(3, Vector3(0, 0, 10))
	await process_frame
	_controller._select(_worker)
	await process_frame
	_check(_planar_distance(_pile_top(pile)) > _worker.pickup_range,
			"o Worker começa fora do alcance do pile de teste")
	_click(MOUSE_BUTTON_RIGHT, _pile_top(pile))
	await process_frame
	_check(_worker.action_mode() == WorkerRuntime.ActionMode.COLLECT, "ordem de coleta aceita")
	await _advance(0.3)
	_check(_worker.action_mode() == WorkerRuntime.ActionMode.COLLECT,
			"Worker ainda está a caminho do pile")
	_check(_worker.state.carried_amount == 0, "nada foi coletado ainda")
	_click(MOUSE_BUTTON_RIGHT, CANCEL_TARGET)
	await process_frame
	_check(_worker.action_mode() == WorkerRuntime.ActionMode.MOVE,
			"antes do pickup uma nova ordem cancela a coleta")
	_check(is_instance_valid(pile) and pile.state.amount == 3, "o pile permanece intacto")
	await _wait_until_not_moving(8.0)
	pile.queue_free()
	await _advance(0.1)


func _test_partial_pile() -> void:
	var pile := _spawn_fixture_pile(5, Vector3(0, 0, 10))
	await process_frame
	_controller._select(_worker)
	await process_frame
	_click(MOUSE_BUTTON_RIGHT, _pile_top(pile))
	await _wait_until_carrying(pile)
	_check(_worker.state.carried_amount == 3, "a capacidade limita a coleta em 3")
	_check(pile.state.amount == 2, "pile de 5 fica com 2, obtido %d" % pile.state.amount)
	_check(is_instance_valid(pile), "o pile parcial não é removido")
	_check(not (pile.get_node("CollisionShape3D") as CollisionShape3D).disabled,
			"o pile parcial continua clicável")
	_check(not _ray_at(_pile_top(pile), RESOURCE_LAYER).is_empty(),
			"o pile parcial ainda é atingido pelo raycast")
	await _wait_until_idle(8.0)
	_check(_stockpile.get_amount(&"iron_ore") == 6, "a entrega parcial soma ao estoque")
	_check(pile.state.amount == 2, "a sobra do pile continua no chão")
	pile.queue_free()
	await _advance(0.1)


func _test_pile_invalidation() -> void:
	var pile := _spawn_fixture_pile(3, Vector3(-10, 0, -10))
	await process_frame
	_controller._select(_worker)
	await process_frame
	_click(MOUSE_BUTTON_RIGHT, _pile_top(pile))
	await _advance(0.3)
	_check(_worker.action_mode() == WorkerRuntime.ActionMode.COLLECT, "Worker caminha ao pile")
	pile.queue_free()
	await _advance(0.2)
	_check(_worker.action_mode() == WorkerRuntime.ActionMode.IDLE,
			"pile liberado cancela a coleta sem erro")
	_check(_worker.velocity == Vector3.ZERO, "Worker para ao perder o alvo")
	_check(_worker.state.carried_amount == 0, "nenhuma carga é criada do nada")


func _test_common_rock_produces_no_drop() -> void:
	var rock := _rocks[1]
	var piles_before := _piles().size()
	var stock_before := _stockpile.get_amount(&"iron_ore")
	rock.state.apply_work(rock.state.remaining_work)
	await process_frame
	_check(not is_instance_valid(rock), "Rocha Comum escavada desaparece")
	_check(_piles().size() == piles_before, "Rocha Comum não gera ResourcePile")
	_check(_stockpile.get_amount(&"iron_ore") == stock_before,
			"Rocha Comum não altera o estoque")


func _test_no_managers_no_autoload() -> void:
	_check(_scene.find_child("*Manager*", true, false) == null, "nenhum Manager foi criado")
	_check(_scene.find_child("Economy*", true, false) == null, "nenhum EconomyManager existe")
	_check(_scene.find_child("Navigation*", true, false) == null, "nenhum nó de navegação existe")
	var autoloads: Dictionary = ProjectSettings.get_setting("autoload", {})
	_check(autoloads.is_empty(), "nenhum autoload/singleton foi adicionado")
	_check(_deposit.stockpile == _stockpile,
			"existe um único StockpileState compartilhado por injeção")


# ---------------------------------------------------------------------- Helpers


func _planar_distance(target: Vector3) -> float:
	var offset := target - _worker.global_position
	offset.y = 0.0
	return offset.length()


func _click(button: int, world_position: Vector3) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	event.position = _camera.unproject_position(world_position)
	event.global_position = event.position
	root.push_input(event)


func _ray_at(world_position: Vector3, mask: int) -> Dictionary:
	var origin := _camera.global_position
	var direction := (world_position - origin).normalized()
	var space := _scene.get_viewport().world_3d.direct_space_state
	return space.intersect_ray(
			PhysicsRayQueryParameters3D.create(origin, origin + direction * 1000.0, mask))


func _wait_until_not_moving(max_seconds: float) -> void:
	var limit := int(max_seconds * Engine.get_physics_ticks_per_second())
	var guard := 0
	while _worker.has_move_target() and guard < limit:
		await physics_frame
		guard += 1
	if _worker.has_move_target():
		_check(false, "Worker não parou de se mover em %f s" % max_seconds)


func _wait_until_idle(max_seconds: float) -> void:
	var limit := int(max_seconds * Engine.get_physics_ticks_per_second())
	var guard := 0
	while _worker.action_mode() != WorkerRuntime.ActionMode.IDLE and guard < limit:
		await physics_frame
		guard += 1
	if _worker.action_mode() != WorkerRuntime.ActionMode.IDLE:
		_check(false, "Worker não chegou a IDLE em %f s" % max_seconds)


func _wait_until_carrying(pile: ResourcePileRuntime, max_seconds: float = 8.0) -> float:
	_probe.anchor = pile.global_position
	_probe.captured = -1.0
	_probe.armed = true
	var limit := int(max_seconds * Engine.get_physics_ticks_per_second())
	var guard := 0
	while _worker.state.carried_amount == 0 and guard < limit:
		await physics_frame
		guard += 1
	_probe.armed = false
	return _probe.captured


func _finish() -> void:
	print("---- resource tests finished: %d asserts, %d failure(s) ----" % [_asserts, _failures])
	quit(1 if _failures > 0 else 0)
