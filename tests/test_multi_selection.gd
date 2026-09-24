extends SceneTree

# Tarefa 09 — Seleção múltipla e ordens para vários Trabalhadores.
# A suíte dirige o GameMain real: input empurrado pela janela, ordens de grupo,
# escavação/construção cooperativa e coleta concorrente medidas em física verdadeira.

const MAIN_SCENE := preload("res://game/GameMain.tscn")
const PILE_SCENE := preload("res://world/resources/ResourcePileRuntime.tscn")
const SELECTION_BOX_SCENE := preload("res://ui/selection/SelectionBox.tscn")

const SELECTION_PATH := "res://systems/selection/selection_controller.gd"
const SELECTION_BOX_SOURCE_PATH := "res://ui/selection/selection_box.gd"
const WORKER_RUNTIME_PATH := "res://units/workers/worker_runtime.gd"
const IRON_ORE_PATH := "res://data/resources/iron_ore.tres"

const GROUND_LAYER := 1
const UNIT_LAYER := 2
const DIGGABLE_LAYER := 4
const RESOURCE_LAYER := 8
const CONSTRUCTION_LAYER := 16
const CLICKABLE := GROUND_LAYER | UNIT_LAYER | DIGGABLE_LAYER | RESOURCE_LAYER | CONSTRUCTION_LAYER

# As posições abaixo foram escolhidas pela projeção real da câmera do GameMain.
# Em headless a janela tem 64x64 pixels, então POSITION_A e POSITION_B precisam
# ficar a mais de 2*BOX_MARGIN de distância UMA DA OUTRA na tela para que uma
# caixa em torno de um Worker não engula o outro.
const POSITION_A := Vector3(0, 0, 12)
const POSITION_B := Vector3(0, 0, -12)
const GROUP_TARGET := Vector3(0, 0, 5)
const SOLO_TARGET := Vector3(4, 0, 8)
const PILE_SPOT := Vector3(-2, 0, 4)
const PILE_LEFT := Vector3(-6, 0, 4)
const PILE_RIGHT := Vector3(2, 0, 4)
const ROCK_SOLO_ID := "rock_001"
const ROCK_GROUP_ID := "rock_003"
const SPAWN_POINT := Vector3(0, 0, 4)

const SPACING := 1.2
const BOX_MARGIN := 12.0
const ARRIVAL_TOLERANCE := 0.05
const TIME_TOLERANCE := 0.3
const MISSING := 1000000.0
const ORE := &"iron_ore"

var _failures := 0
var _asserts := 0
var _frames := 0
var _scene: Node
var _dungeon: Node3D
var _camera: Camera3D
var _selection: SelectionController
var _box: SelectionBox
var _worker: WorkerRuntime
var _worker2: WorkerRuntime
var _invocation: WorkerInvocationController
var _construction: ConstructionController
var _deposit: ResourceDepositRuntime
var _core_state: CoreState
var _stockpile: ResourceStockpileState
var _ore_definition: ResourceDefinition
var _pile: ResourcePileRuntime
var _rock: RockRuntime
var _nest: NestRuntime
var _capacity_events: Array[String] = []
var _excavation_events := 0


func _initialize() -> void:
	_run_all()


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > 200000:
		_check(false, "timeout: a suíte de multi-seleção não terminou")
		_finish()
	return false


func _run_all() -> void:
	_test_input_map()
	_test_selection_box_scene()
	_test_controller_defaults()
	_boot_scene()
	await _advance(0.5)
	await _test_scene_baseline()
	await _test_single_select_compat()
	await _test_replace_selection()
	await _test_shift_add()
	await _test_shift_toggle_remove()
	await _test_ground_clear()
	await _test_shift_ground_keeps()
	await _test_drag_threshold_click()
	await _test_drag_shows_box()
	await _test_box_select_one()
	await _test_box_select_two()
	await _test_box_empty_clears()
	await _test_shift_box_adds()
	await _test_box_ignores_units_behind_camera()
	await _test_box_selection_orders_by_unit_id()
	await _test_group_move_spacing()
	await _test_individual_move_stays_exact()
	await _test_orders_survive_deselection()
	await _test_selection_does_not_disturb_orders()
	await _test_single_worker_excavation_rate()
	await _test_cooperative_excavation()
	await _test_rock_frees_once_and_workers_recover()
	await _test_pile_of_five_is_shared()
	await _test_pile_of_three_leaves_one_idle()
	await _test_delivering_worker_ignores_group_order()
	await _test_cooperative_construction()
	await _test_nest_bonus_applies_once()
	await _test_hud_region_still_reaches_rts()
	await _test_state_stays_clean()
	await _test_scope_guards()
	_finish()


# ------------------------------------------------------------------ Estáticos


func _test_input_map() -> void:
	_check(InputMap.has_action(&"select_unit"), "§80 select_unit continua registrada")
	_check(InputMap.has_action(&"command_move"), "§80 command_move continua registrada")
	_check(InputMap.has_action(&"selection_additive"), "§4 a ação selection_additive existe")
	var shift := InputEventKey.new()
	shift.keycode = KEY_SHIFT
	_check(InputMap.event_is_action(shift, &"selection_additive", false),
			"§4 Shift dispara selection_additive")
	_check(not InputMap.event_is_action(shift, &"select_unit", false),
			"§4 Shift não se confunde com o clique de seleção")
	var left := InputEventMouseButton.new()
	left.button_index = MOUSE_BUTTON_LEFT
	_check(InputMap.event_is_action(left, &"select_unit", false),
			"§80 a caixa usa o mesmo select_unit, sem botão separado")
	_check(not _source(SELECTION_PATH).contains("KEY_SHIFT"),
			"§4 o controller consulta a ação em vez de espalhar KEY_SHIFT")


func _test_selection_box_scene() -> void:
	var box := SELECTION_BOX_SCENE.instantiate() as SelectionBox
	_check(box != null and box is Control, "§13 SelectionBox.tscn instancia um Control")
	_check(box.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"§14 a caixa usa mouse_filter IGNORE")
	_check(not box.visible, "§53 a caixa começa escondida")
	box.begin_drag(Vector2(100, 80))
	box.update_drag(Vector2(40, 150))
	_check(box.visible, "§53 begin_drag torna a caixa visível")
	_check(box.selection_rect().is_equal_approx(Rect2(40, 80, 60, 70)),
			"§11 o retângulo é normalizado, obtido %s" % box.selection_rect())
	box.end_drag()
	_check(not box.visible, "§53 end_drag esconde a caixa")
	box.free()


func _test_controller_defaults() -> void:
	var controller := SelectionController.new()
	_check(controller.selected_units is Array, "§2 selected_units é uma coleção")
	_check(controller.selected_units.is_empty(), "§2 nenhuma unidade selecionada por padrão")
	_check(controller.selected_unit == null, "§3 selected_unit é null sem seleção")
	_check(controller.camera == null and controller.unit_container == null
			and controller.selection_box == null,
			"§15 o controller não procura dependências sozinho")
	_check(is_equal_approx(controller.drag_threshold, 8.0),
			"§12 drag_threshold padrão é 8 pixels, obtido %f" % controller.drag_threshold)
	_check(is_equal_approx(controller.group_move_spacing, SPACING),
			"§23 group_move_spacing padrão é 1.2, obtido %f" % controller.group_move_spacing)
	controller._select(null)
	_check(controller.selected_units.is_empty(), "§3 selecionar null mantém a seleção vazia")
	controller.free()


# ------------------------------------------------------------------- Carga


func _boot_scene() -> void:
	_scene = MAIN_SCENE.instantiate()
	root.add_child(_scene)
	await physics_frame
	await physics_frame
	_dungeon = _scene.get_node("World/DungeonRoot") as Node3D
	_camera = _scene.get_node("World/CameraRig/Camera3D") as Camera3D
	_selection = _scene.get_node("Systems/SelectionController") as SelectionController
	_box = _scene.get_node("UI/SelectionBox") as SelectionBox
	_invocation = _scene.get_node("Systems/WorkerInvocationController") as WorkerInvocationController
	_construction = _scene.get_node("Systems/ConstructionController") as ConstructionController
	_deposit = _scene.get_node("World/DungeonRoot/Deposit001") as ResourceDepositRuntime
	_worker = _scene.get_node("World/DungeonRoot/Worker001") as WorkerRuntime
	_ore_definition = load(IRON_ORE_PATH) as ResourceDefinition
	_core_state = (_scene.get_node("World/DungeonRoot/MainCore") as CoreRuntime).core_state()
	_stockpile = _deposit.stockpile
	_core_state.population_capacity_changed.connect(_on_capacity_changed)


func _on_capacity_changed(population: int, capacity: int) -> void:
	_capacity_events.append("%d/%d" % [population, capacity])


func _test_scene_baseline() -> void:
	_check(_box != null and _box.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"§14 a caixa da cena vive em UI com IGNORE")
	_check(_selection.camera == _camera, "§15 o controller recebe a câmera")
	_check(_selection.unit_container == _dungeon, "§15 o controller recebe o DungeonRoot")
	_check(_selection.selection_box == _box, "§15 o controller recebe a SelectionBox")
	_check(_workers_in_scene().size() == 1, "a cena começa com um Worker")
	var summon := InputEventKey.new()
	summon.physical_keycode = KEY_I
	summon.pressed = true
	root.push_input(summon)
	summon.pressed = false
	root.push_input(summon)
	await _advance(0.3)
	_worker2 = _invocation.summoned_worker()
	_check(_worker2 != null and _workers_in_scene().size() == 2,
			"I invoca o segundo Worker para os testes de grupo")
	_check(_worker2.global_position.is_equal_approx(SPAWN_POINT),
			"o segundo Worker nasce no ponto de invocação")


# --------------------------------------------------------------- Seleção


func _test_single_select_compat() -> void:
	await _click_select(_worker)
	_check(_selection.selected_units.size() == 1, "§42 LMB seleciona exatamente uma unidade")
	_check(_selection.selected_unit == _worker, "§42 selected_unit continua sendo a unidade clicada")
	_check(_selection.selected_unit == _selection.selected_units[0],
			"§3 selected_unit é sempre selected_units[0]")
	_check(_indicator(_worker).visible and not _indicator(_worker2).visible,
			"§42 apenas o indicador do primeiro Worker aparece")


func _test_replace_selection() -> void:
	await _click_select(_worker2)
	_check(_selection.selected_units.size() == 1, "§43 clicar em outra unidade substitui a seleção")
	_check(_selection.selected_units[0] == _worker2, "§43 a seleção passa a ser o segundo Worker")
	_check(not _indicator(_worker).visible and _indicator(_worker2).visible,
			"§5 a unidade anterior perde o indicador")


func _test_shift_add() -> void:
	await _click_select(_worker)
	await _shift_click_select(_worker2)
	_check(_selection.selected_units.size() == 2, "§44 Shift + LMB adiciona à seleção")
	_check(_selection.selected_units.has(_worker) and _selection.selected_units.has(_worker2),
			"§6 os dois Workers estão na seleção")
	_check(_indicator(_worker).visible and _indicator(_worker2).visible,
			"§6 os dois indicadores ficam visíveis")
	_check(_selection.selected_unit == _selection.selected_units[0],
			"§3 com várias unidades selected_unit ainda é a primeira")


func _test_shift_toggle_remove() -> void:
	_check(_selection.selected_units.size() == 2, "o toggle parte de duas unidades selecionadas")
	await _shift_click_select(_worker)
	_check(_selection.selected_units.size() == 1, "§7 Shift + LMB em selecionado remove")
	_check(_selection.selected_units[0] == _worker2, "§45 sobra apenas o segundo Worker")
	_check(not _indicator(_worker).visible and _indicator(_worker2).visible,
			"§38 um único indicador permanece visível")
	await _shift_click_select(_worker)
	_check(_selection.selected_units.size() == 2, "§7 Shift adiciona novamente")


func _test_ground_clear() -> void:
	await _click_ground(POSITION_A)
	_check(_selection.selected_units.is_empty(), "§46 LMB no chão limpa toda a seleção")
	_check(_selection.selected_unit == null, "§3 selected_unit volta a ser null")
	_check(_visible_indicators() == 0, "§38 nenhum indicador visível depois de limpar")


func _test_shift_ground_keeps() -> void:
	await _click_select(_worker)
	await _shift_click_select(_worker2)
	await _shift_click_ground(POSITION_B)
	_check(_selection.selected_units.size() == 2,
			"§8 Shift + LMB no chão não altera a seleção")
	_check(_visible_indicators() == 2, "§38 os dois indicadores permanecem")


func _test_drag_threshold_click() -> void:
	_selection.clear_selection()
	await _advance(0.05)
	await _click_select(_worker)
	await _drag(POSITION_A, POSITION_A + Vector3(0.05, 0, 0.05))
	_check(not _box.visible, "§48 um arraste mínimo nunca abre a caixa")
	_check(_selection.selected_units.is_empty(),
			"§48 arraste curto no chão é tratado como clique e limpa a seleção")
	var worker_screen := _screen(_worker.global_position)
	_press(MOUSE_BUTTON_LEFT, worker_screen)
	_motion(worker_screen + Vector2(3, 3))
	_release(MOUSE_BUTTON_LEFT, worker_screen + Vector2(3, 3))
	await _advance(0.05)
	_check(not _box.visible, "§48 mover 3 px a partir de uma unidade não vira arraste")
	_check(_selection.selected_units.size() == 1 and _selection.selected_units[0] == _worker,
			"§48 o clique curto continua sendo clique de seleção")


func _test_drag_shows_box() -> void:
	_selection.clear_selection()
	await _advance(0.05)
	var origin := _screen(POSITION_A)
	_press(MOUSE_BUTTON_LEFT, origin)
	_motion(origin + Vector2(90, 60))
	_check(_box.visible, "§11 arrastar além do threshold mostra a caixa")
	_release(MOUSE_BUTTON_LEFT, origin + Vector2(160, 120))
	_check(not _box.visible, "§53 soltar o botão esconde a caixa")


func _test_box_select_one() -> void:
	await _park_workers()
	_selection.clear_selection()
	await _advance(0.05)
	var screen := _screen(_worker.global_position)
	_check(_screen_spread(_worker, _worker2) > BOX_MARGIN * 2.0,
			"os Workers estão afastados o bastante na tela para uma caixa isolada")
	await _drag_screen(screen - Vector2(BOX_MARGIN, BOX_MARGIN),
			screen + Vector2(BOX_MARGIN, BOX_MARGIN))
	_check(_selection.selected_units.size() == 1, "§49 a caixa contém apenas um Worker")
	_check(_selection.selected_units[0] == _worker, "§49 o Worker selecionado é o correto")
	_check(_visible_indicators() == 1, "§38 um indicador visível")


func _test_box_select_two() -> void:
	_selection.clear_selection()
	await _advance(0.05)
	await _click_select(_worker)
	_check(_selection.selected_units.size() == 1, "§18 a caixa substitui uma seleção de uma unidade")
	await _drag_over_both()
	_check(_selection.selected_units.size() == 2, "§50 a caixa ampla seleciona os dois Workers")
	_check(_selection.selected_units.has(_worker) and _selection.selected_units.has(_worker2),
			"§50 ambos os Workers estão na seleção")
	_check(_visible_indicators() == 2, "§38 dois indicadores simultâneos")


func _test_box_empty_clears() -> void:
	_selection.clear_selection()
	await _advance(0.05)
	await _click_select(_worker)
	await _shift_click_select(_worker2)
	_check(_selection.selected_units.size() == 2, "§51 a caixa vazia parte de duas unidades")
	var rect := _empty_box_rect()
	_check(not rect.has_point(_screen(_worker.global_position))
			and not rect.has_point(_screen(_worker2.global_position)),
			"a região vazia escolhida realmente não toca nenhum Worker")
	await _drag_screen(rect.position, rect.end)
	_check(_selection.selected_units.is_empty(), "§51 caixa vazia sem Shift limpa a seleção")
	_check(_visible_indicators() == 0, "§38 nenhum indicador sobra depois da caixa vazia")


func _test_shift_box_adds() -> void:
	_selection.clear_selection()
	await _advance(0.05)
	await _click_select(_worker)
	var screen := _screen(_worker2.global_position)
	await _shift_drag_screen(screen - Vector2(BOX_MARGIN, BOX_MARGIN),
			screen + Vector2(BOX_MARGIN, BOX_MARGIN))
	_check(_selection.selected_units.size() == 2, "§52 Shift + caixa adiciona à seleção")
	_check(_selection.selected_units.has(_worker) and _selection.selected_units.has(_worker2),
			"§19 a unidade anterior permanece e a nova entra")
	await _shift_drag_screen(screen - Vector2(BOX_MARGIN, BOX_MARGIN),
			screen + Vector2(BOX_MARGIN, BOX_MARGIN))
	_check(_selection.selected_units.size() == 2,
			"§19 Shift + caixa não duplica quem já estava selecionado")


func _test_box_ignores_units_behind_camera() -> void:
	_selection.clear_selection()
	await _advance(0.05)
	var behind := _camera.global_position + _camera.global_transform.basis.z * 4.0
	_place(_worker2, behind)
	await _advance(0.1)
	var size := _viewport_size()
	await _drag_screen(Vector2.ZERO - Vector2(10, 10), size + Vector2(10, 10))
	_check(_selection.selected_units.size() == 1
			and _selection.selected_units[0] == _worker,
			"§17 unidades atrás da câmera não entram pela caixa")
	_place(_worker2, POSITION_B)
	await _advance(0.1)


func _test_box_selection_orders_by_unit_id() -> void:
	_selection.clear_selection()
	await _advance(0.05)
	await _drag_over_both()
	_check(_selection.selected_units.size() == 2, "§75 a caixa pegou os dois Workers")
	_check(_selection.selected_units[0].state.unit_id < _selection.selected_units[1].state.unit_id,
			"§75 a ordem da caixa é estável por unit_id")
	_check(_selection.selected_unit == _selection.selected_units[0],
			"§3 selected_unit acompanha a primeira da ordem estável")


# ---------------------------------------------------------------- Ordens


func _test_group_move_spacing() -> void:
	_selection.clear_selection()
	await _park_workers()
	await _box_select_both()
	var hit := _ground_hit(GROUP_TARGET)
	_check(hit.get("collider", null) is StaticBody3D,
			"o alvo do movimento de grupo está em chão livre")
	await _right_click(GROUP_TARGET)
	_check(_worker.has_move_target() and _worker2.has_move_target(),
			"§54 os dois Workers receberam destino")
	_check(_worker.global_position != _worker2.global_position,
			"a ordem de grupo não teleporta ninguém para o mesmo ponto")
	await _wait_until(func() -> bool:
		return not _worker.has_move_target() and not _worker2.has_move_target(), 25.0)
	var clicked: Vector3 = hit.position
	var first := clicked + Vector3(-SPACING * 0.5, 0.0, 0.0)
	var second := clicked + Vector3(SPACING * 0.5, 0.0, 0.0)
	_check(_planar_distance(_worker.global_position, first) < ARRIVAL_TOLERANCE,
			"§23 o primeiro da seleção fica à esquerda do clique, erro %f"
			% _planar_distance(_worker.global_position, first))
	_check(_planar_distance(_worker2.global_position, second) < ARRIVAL_TOLERANCE,
			"§23 o segundo da seleção fica à direita do clique, erro %f"
			% _planar_distance(_worker2.global_position, second))
	var separation := _planar_distance(_worker.global_position, _worker2.global_position)
	_check(absf(separation - SPACING) < ARRIVAL_TOLERANCE,
			"§55 distância final entre eles = spacing 1.2, obtido %f" % separation)
	_check(separation > 0.5, "§22 os Workers não terminam sobrepostos")


func _test_individual_move_stays_exact() -> void:
	_selection.clear_selection()
	await _advance(0.05)
	await _click_select(_worker)
	var hit := _ground_hit(SOLO_TARGET)
	_check(hit.get("collider", null) is StaticBody3D, "o alvo individual está em chão livre")
	await _right_click(SOLO_TARGET)
	await _wait_until(func() -> bool: return not _worker.has_move_target(), 20.0)
	_check(_planar_distance(_worker.global_position, hit.position) < 0.0001,
			"§56 com um Worker o destino é exatamente o ponto clicado, erro %f"
			% _planar_distance(_worker.global_position, hit.position))
	_check(not _worker2.has_move_target(),
			"§27 a ordem individual não move quem não está selecionado")


func _test_orders_survive_deselection() -> void:
	_selection.clear_selection()
	await _park_workers()
	await _box_select_both()
	var hit := _ground_hit(GROUP_TARGET)
	await _right_click(GROUP_TARGET)
	await _advance(0.1)
	_selection.clear_selection()
	await _advance(0.1)
	_check(_selection.selected_units.is_empty(), "§40 a seleção foi limpa durante o deslocamento")
	_check(_worker.has_move_target() and _worker2.has_move_target(),
			"§40 as ordens continuam mesmo sem seleção")
	await _wait_until(func() -> bool:
		return not _worker.has_move_target() and not _worker2.has_move_target(), 25.0)
	var clicked: Vector3 = hit.position
	_check(_planar_distance(_worker.global_position,
			clicked + Vector3(-SPACING * 0.5, 0, 0)) < ARRIVAL_TOLERANCE,
			"§57 o primeiro Worker chega ao seu destino")
	_check(_planar_distance(_worker2.global_position,
			clicked + Vector3(SPACING * 0.5, 0, 0)) < ARRIVAL_TOLERANCE,
			"§57 o segundo Worker chega ao seu destino")


func _test_selection_does_not_disturb_orders() -> void:
	await _park_workers()
	_selection.clear_selection()
	await _advance(0.05)
	await _click_select(_worker)
	await _right_click(GROUP_TARGET)
	await _advance(0.1)
	_check(_worker.has_move_target(), "o primeiro Worker está em deslocamento")
	await _click_select(_worker2)
	await _advance(0.2)
	_check(_worker.has_move_target(),
			"§39 selecionar outro Worker não cancela a ordem do primeiro")


# ------------------------------------------------------ Escavação conjunta


func _test_single_worker_excavation_rate() -> void:
	_rock = _rock_with_id(ROCK_SOLO_ID)
	_check(_rock != null and is_equal_approx(_rock.state.remaining_work, 4.0),
			"a Rocha Comum do teste tem work_required 4.0")
	_excavation_events = 0
	_rock.state.excavated.connect(_on_excavated)
	_selection.clear_selection()
	await _park_near_rock(_worker, _rock, 0.9)
	await _click_select(_worker)
	await _right_click(_rock.global_position)
	await _advance(0.1)
	_check(_worker.is_excavating(), "§28 um Worker escava a rocha")
	var half := await _time_until(func() -> bool: return _rock_work() <= 2.0, 12.0)
	_check(absf(half - 2.0) < TIME_TOLERANCE,
			"§29 um Worker remove 2.0 de trabalho em ~2 s, obtido %f" % half)
	var rest := await _time_until(func() -> bool: return not _rock_present(), 12.0)
	var total := half + rest
	_check(absf(total - 4.0) < TIME_TOLERANCE,
			"§59 um Worker conclui 4.0 de trabalho em ~4 s, obtido %f" % total)
	_check(_excavation_events == 1, "§30 excavated foi emitido exatamente uma vez")
	await _advance(0.2)
	_check(_worker.action_mode() == WorkerRuntime.ActionMode.IDLE,
			"§60 o Worker volta a IDLE depois de a rocha ser liberada")


func _test_cooperative_excavation() -> void:
	_rock = _rock_with_id(ROCK_GROUP_ID)
	_check(_rock != null and is_equal_approx(_rock.state.remaining_work, 4.0),
			"a rocha da escavação conjunta começa com 4.0 de trabalho")
	_excavation_events = 0
	_rock.state.excavated.connect(_on_excavated)
	_selection.clear_selection()
	await _park_near_rock(_worker, _rock, 0.9)
	await _park_near_rock(_worker2, _rock, -0.9)
	var approach_a := _worker.global_position
	var approach_b := _worker2.global_position
	await _box_select_both()
	await _right_click(_rock.global_position)
	await _advance(0.1)
	_check(_worker.is_excavating() and _worker2.is_excavating(),
			"§28 ambos receberam a mesma rocha como alvo")
	_check(approach_a != approach_b,
			"§28 cada Worker calcula o próprio ponto de aproximação")
	var half := await _time_until(func() -> bool: return _rock_work() <= 2.0, 8.0)
	_check(absf(half - 1.0) < TIME_TOLERANCE,
			"§58 dois Workers removem 2.0 em ~1 s (2.0 work/s), obtido %f" % half)
	var rest := await _time_until(func() -> bool: return not _rock_present(), 8.0)
	var total := half + rest
	_check(absf(total - 2.0) < TIME_TOLERANCE,
			"§59 dois Workers concluem 4.0 em ~2 s, obtido %f" % total)
	_check(_excavation_events == 1, "§30 a rocha avisa a escavação uma única vez")


func _on_excavated() -> void:
	_excavation_events += 1


func _test_rock_frees_once_and_workers_recover() -> void:
	await _advance(0.3)
	_check(not _rock_present(), "§30 a rocha saiu da árvore uma única vez")
	_check(_rock_with_id(ROCK_GROUP_ID) == null, "§30 não restou instância fantasma da rocha")
	_check(_worker.action_mode() == WorkerRuntime.ActionMode.IDLE
			and _worker2.action_mode() == WorkerRuntime.ActionMode.IDLE,
			"§60 os dois Workers voltaram para IDLE sem referência inválida")
	_check(not _worker.has_move_target() and not _worker2.has_move_target(),
			"§60 nenhum dos dois mantém destino apontando para a rocha removida")


# ------------------------------------------------------- Coleta concorrente


func _test_pile_of_five_is_shared() -> void:
	var before := _stockpile.get_amount(ORE)
	await _spawn_pile(5)
	_selection.clear_selection()
	await _park_around_pile()
	await _box_select_both()
	await _right_click(_pile.global_position)
	var drained := await _wait_until(func() -> bool: return _pile_amount() == 0, 25.0)
	_check(drained, "§63 o pile de 5 foi esvaziado")
	var carried := _total_cargo()
	_check(carried == 5, "§34 a soma das cargas é exatamente 5, obtido %d" % carried)
	_check(_worker.state.carried_amount <= 3 and _worker2.state.carried_amount <= 3,
			"§34 nenhum Worker ultrapassou a própria capacidade")
	_check(_worker.state.carried_amount > 0 and _worker2.state.carried_amount > 0,
			"§33 os dois Workers coletaram do mesmo pile")
	await _wait_until(func() -> bool: return _total_cargo() == 0, 30.0)
	_check(_stockpile.get_amount(ORE) - before == 5,
			"§35 o estoque cresce exatamente +5, obtido +%d"
			% (_stockpile.get_amount(ORE) - before))
	await _advance(1.0)
	_check(_stockpile.get_amount(ORE) - before == 5,
			"§65 o estoque continua +5 depois de mais frames")
	_check(_total_cargo() == 0, "§63 nenhuma carga ficou pendurada")


func _test_pile_of_three_leaves_one_idle() -> void:
	var before := _stockpile.get_amount(ORE)
	await _spawn_pile(3)
	_selection.clear_selection()
	await _park_around_pile()
	await _box_select_both()
	await _right_click(_pile.global_position)
	var settled := await _wait_until(func() -> bool:
		return _total_cargo() == 3 and _not_collecting(_worker) and _not_collecting(_worker2), 25.0)
	_check(settled, "§64 um Worker pegou os 3 e o outro se resolveu")
	await _advance(0.3)
	_check(_total_cargo() == 3, "§36 a carga combinada é exatamente 3, obtido %d" % _total_cargo())
	_check(_worker.state.carried_amount == 0 or _worker2.state.carried_amount == 0,
			"§36 quem ficou sem recurso ficou sem carga")
	_check(_empty_handed_worker().action_mode() == WorkerRuntime.ActionMode.IDLE,
			"§36 o Worker sem carga voltou para IDLE em vez de travar em COLLECT")
	_check(_pile_amount() == 0, "§36 o pile esvaziou")
	await _wait_until(func() -> bool: return _total_cargo() == 0, 30.0)
	_check(_stockpile.get_amount(ORE) - before == 3,
			"§35 a entrega do pile de 3 soma exatamente +3, obtido +%d"
			% (_stockpile.get_amount(ORE) - before))


func _test_delivering_worker_ignores_group_order() -> void:
	await _spawn_pile(3)
	_selection.clear_selection()
	await _park_around_pile()
	await _box_select_both()
	await _right_click(_pile.global_position)
	var loaded := await _wait_until(func() -> bool: return _total_cargo() == 3, 25.0)
	_check(loaded, "o Worker que chegou ao pile carregou os 3")
	var carrier := _carrying_worker()
	var idle := _empty_handed_worker()
	await _wait_until(func() -> bool:
		return carrier.action_mode() == WorkerRuntime.ActionMode.DELIVER, 5.0)
	_check(carrier.action_mode() == WorkerRuntime.ActionMode.DELIVER,
			"§66 o Worker carregado está em DELIVER")
	await _advance(0.2)
	_selection.clear_selection()
	await _click_select(carrier)
	await _shift_click_select(idle)
	await _right_click(GROUP_TARGET)
	await _advance(0.2)
	_check(carrier.action_mode() == WorkerRuntime.ActionMode.DELIVER,
			"§66 o Worker em DELIVER ignora a ordem de grupo")
	_check(carrier.state.carried_amount == 3,
			"§37 a carga em trânsito não foi perdida nem duplicada")
	_check(idle.has_move_target() and idle.action_mode() == WorkerRuntime.ActionMode.MOVE,
			"§66 o outro Worker aceita a ordem de grupo")
	await _wait_until(func() -> bool: return _total_cargo() == 0, 30.0)
	_check(carrier.state.carried_amount == 0,
			"§37 a entrega própria do Worker terminou normalmente")


# ------------------------------------------------------ Construção conjunta


func _test_cooperative_construction() -> void:
	_selection.clear_selection()
	await _wait_until(func() -> bool: return _total_cargo() == 0, 20.0)
	_check(_core_state.get_population_capacity() == 8,
			"§32 a capacidade ainda é 8 antes do Ninho")
	_check(_stockpile.get_amount(ORE) >= 3,
			"o estoque tem minério para pagar o Ninho (%d)" % _stockpile.get_amount(ORE))
	var key := InputEventKey.new()
	key.physical_keycode = KEY_B
	key.pressed = true
	root.push_input(key)
	key.pressed = false
	root.push_input(key)
	await _advance(0.3)
	_nest = _construction.nest()
	_check(_nest != null and not _nest.state.is_completed(),
			"§31 o canteiro do Ninho foi criado e está incompleto")
	_check(is_equal_approx(_nest.state.remaining_work, 4.0),
			"§61 o Ninho exige 4.0 de trabalho")
	var nest_position := _nest.global_position
	await _park_near_nest(_worker, 0.9)
	await _park_near_nest(_worker2, -0.9)
	await _box_select_both()
	await _right_click(nest_position)
	await _advance(0.1)
	_check(_worker.is_building() and _worker2.is_building(),
			"§31 ambos constroem o mesmo Ninho")
	var before := _nest.state.remaining_work
	await _advance(1.0)
	var rate := before - _nest.state.remaining_work
	_check(absf(rate - 2.0) < TIME_TOLERANCE,
			"§61 dois Workers rendem ~2.0 de trabalho em ~1 s, obtido %f" % rate)
	await _wait_until(func() -> bool: return _nest.state.is_completed(), 10.0)
	_check(_nest.state.is_completed(), "§32 o Ninho foi concluído pelo trabalho conjunto")
	await _advance(0.2)
	_check(_worker.action_mode() == WorkerRuntime.ActionMode.IDLE
			and _worker2.action_mode() == WorkerRuntime.ActionMode.IDLE,
			"§32 os dois saem de BUILD ao concluir")


func _test_nest_bonus_applies_once() -> void:
	_check(_core_state.get_population_capacity() == 12,
			"§62 a capacidade efetiva passou de 8 para exatamente 12")
	_check(_core_state.population == 2, "§25 construir o Ninho não altera a população")
	_check(_capacity_events.count("2/12") == 1,
			"§62 o sinal de capacidade emite 2/12 exatamente uma vez, eventos %s"
			% _capacity_events)
	_check(_nest.state.is_completed(), "o Ninho permanece concluído")


# ----------------------------------------------------------------- Interface


func _test_hud_region_still_reaches_rts() -> void:
	var size := _viewport_size()
	var over_hud := size * 0.15
	_check(over_hud.x < size.x and over_hud.y < size.y, "o ponto de teste está dentro da viewport")
	await _park_workers()
	_selection.clear_selection()
	await _advance(0.05)
	await _click_select(_worker)
	_press(MOUSE_BUTTON_LEFT, over_hud)
	_motion(over_hud + size * 0.4)
	_check(_box.visible, "§82 arrastar sobre a região do HUD chega ao RTS")
	_release(MOUSE_BUTTON_LEFT, over_hud + size * 0.5)
	_check(not _box.visible, "§82 a caixa some ao soltar mesmo começando sobre o HUD")
	await _click_select(_worker)
	_press(MOUSE_BUTTON_LEFT, over_hud)
	_release(MOUSE_BUTTON_LEFT, over_hud)
	await _advance(0.1)
	_check(_selection.selected_units.is_empty(),
			"§82 o clique atravessando o HUD continua limpa a seleção")


func _test_state_stays_clean() -> void:
	for worker in [_worker, _worker2]:
		var state: WorkerState = worker.state
		_check(state.get("selected") == null, "§67 WorkerState não guarda selected")
		_check(state.get("is_selected") == null, "§67 WorkerState não guarda is_selected")
		_check(state.get("selection_index") == null, "§67 WorkerState não guarda selection_index")
		_check(state.get("formation_slot") == null, "§67 WorkerState não guarda formation_slot")
		_check(state.get("group_offset") == null, "§25 o deslocamento de grupo não é persistido")
	_check(_worker.definition == _worker2.definition,
			"§21 os dois compartilham a mesma WorkerDefinition")
	_check(_worker.state != _worker2.state, "§67 os States continuam individuais")


func _test_scope_guards() -> void:
	var controller_source := _source(SELECTION_PATH)
	var box_source := _source(SELECTION_BOX_SOURCE_PATH)
	var runtime_source := _source(WORKER_RUNTIME_PATH)
	_check(not controller_source.contains("_process(")
			and not controller_source.contains("_physics_process"),
			"§76 o controller não roda nada por frame")
	_check(not controller_source.contains("get_nodes_in_group")
			and not controller_source.contains("get_first_node_in_group"),
			"§68 nenhuma unidade é procurada por grupo global")
	_check(not controller_source.contains("randf") and not controller_source.contains("randi"),
			"§24 os offsets de grupo não usam aleatoriedade")
	_check(controller_source.contains("for unit in selected_units"),
			"§21 a ordem de grupo itera selected_units chamando a API existente")
	for forbidden in ["ICommand", "MoveCommand", "BuildCommand", "ExcavateCommand",
			"CommandBus", "CommandQueue"]:
		_check(not controller_source.contains(forbidden),
				"§73 nenhuma abstração %s foi criada" % forbidden)
	for forbidden in ["SelectableUnitBase", "ISelectable", "RTSUnitInterface"]:
		_check(not controller_source.contains(forbidden)
				and not runtime_source.contains(forbidden),
				"§74 nenhuma base genérica %s foi criada" % forbidden)
	_check(not box_source.contains("_process("),
			"§13 a caixa desenha por evento, não por polling")
	var node_names: Array[String] = []
	for node in _scene.find_children("*", "*", true, false):
		node_names.append(String(node.name))
	for forbidden in ["UnitRegistry", "UnitManager", "SelectionManager", "WorkerRoster",
			"GlobalUnitList", "DragSelection", "Formation", "ControlGroup", "ArmyManager",
			"NavigationAgent", "NavigationRegion", "CommandQueue"]:
		_check(not node_names.has(forbidden), "§68 nenhum nó %s existe na cena" % forbidden)
	_check(_scene.find_children("*", "NavigationAgent3D", true, false).is_empty(),
			"§72 nenhum NavigationAgent3D foi criado")
	_check(WorkerRuntime.ActionMode.size() == 6,
			"§12 nenhum modo de ação novo foi adicionado ao Runtime")
	var autoloads: Dictionary = ProjectSettings.get_setting("autoload", {})
	_check(autoloads.is_empty(), "§68 nenhum autoload foi criado")
	_check(_workers_in_scene().size() == 2, "a cena termina com exatamente 2 Workers")
	for control in _controls_in_ui():
		_check(control.mouse_filter == Control.MOUSE_FILTER_IGNORE,
				"§14 %s continua com mouse_filter IGNORE" % control.name)
	_check(_source("res://project.godot").contains("selection_additive="),
			"§4 selection_additive está no input map do projeto")


# ------------------------------------------------------------------- Helpers


func _workers_in_scene() -> Array[WorkerRuntime]:
	var workers: Array[WorkerRuntime] = []
	for child in _dungeon.get_children():
		if child is WorkerRuntime:
			workers.append(child as WorkerRuntime)
	return workers


func _controls_in_ui() -> Array[Control]:
	var controls: Array[Control] = []
	for node in (_scene.get_node("UI") as Node).find_children("*", "Control", true, false):
		controls.append(node as Control)
	return controls


func _rock_with_id(id: String) -> RockRuntime:
	for child in _dungeon.get_children():
		if child is RockRuntime and (child as RockRuntime).rock_id == id:
			return child as RockRuntime
	return null


func _rock_work() -> float:
	return MISSING if not is_instance_valid(_rock) else _rock.state.remaining_work


func _rock_present() -> bool:
	return is_instance_valid(_rock)


func _pile_amount() -> int:
	return 0 if not is_instance_valid(_pile) else _pile.state.amount


func _spawn_pile(amount: int) -> void:
	_pile = PILE_SCENE.instantiate() as ResourcePileRuntime
	_pile.position = PILE_SPOT
	_dungeon.add_child(_pile)
	_pile.setup(_ore_definition, ResourcePileState.new(_ore_definition, "multi_test_pile", amount))
	await _advance(0.1)


func _total_cargo() -> int:
	return _worker.state.carried_amount + _worker2.state.carried_amount


func _carrying_worker() -> WorkerRuntime:
	return _worker if _worker.state.carried_amount > 0 else _worker2


func _empty_handed_worker() -> WorkerRuntime:
	return _worker if _worker.state.carried_amount == 0 else _worker2


func _not_collecting(worker: WorkerRuntime) -> bool:
	return worker.action_mode() != WorkerRuntime.ActionMode.COLLECT


func _indicator(worker: WorkerRuntime) -> MeshInstance3D:
	return worker.find_child("SelectionIndicator", true, false) as MeshInstance3D


func _visible_indicators() -> int:
	var count := 0
	for worker in [_worker, _worker2]:
		if _indicator(worker).visible:
			count += 1
	return count


func _screen(world_position: Vector3) -> Vector2:
	return _camera.unproject_position(world_position)


# Distância em pixels apenas no eixo dominante: é o que decide se uma caixa em
# torno de um Worker alcança ou não o outro.
func _screen_spread(a: WorkerRuntime, b: WorkerRuntime) -> float:
	var offset := _screen(a.global_position) - _screen(b.global_position)
	return maxf(absf(offset.x), absf(offset.y))


func _empty_box_rect() -> Rect2:
	var size := _viewport_size()
	var side := BOX_MARGIN * 2.0
	for row in range(1, 10):
		for column in range(1, 10):
			var center := size * Vector2(float(column), float(row)) / 10.0
			var rect := Rect2(center - Vector2(BOX_MARGIN, BOX_MARGIN), Vector2(side, side))
			if _rect_has_no_worker(rect):
				return rect
	return Rect2()


func _rect_has_no_worker(rect: Rect2) -> bool:
	var safe := rect.grow(6.0)
	for worker in _workers_in_scene():
		if safe.has_point(_screen(worker.global_position)):
			return false
	return true


func _viewport_size() -> Vector2:
	return Vector2(root.size)


func _ground_hit(world_position: Vector3) -> Dictionary:
	var origin := _camera.project_ray_origin(_screen(world_position))
	var direction := _camera.project_ray_normal(_screen(world_position))
	var space := _scene.get_viewport().world_3d.direct_space_state
	return space.intersect_ray(
			PhysicsRayQueryParameters3D.create(origin, origin + direction * 1000.0, CLICKABLE))


func _planar_distance(from: Vector3, to: Vector3) -> float:
	var offset := to - from
	offset.y = 0.0
	return offset.length()


func _place(worker: WorkerRuntime, position_at: Vector3) -> void:
	worker.velocity = Vector3.ZERO
	worker.global_position = position_at
	worker.move_to(position_at)


func _park_workers() -> void:
	_place(_worker, POSITION_A)
	_place(_worker2, POSITION_B)
	await _advance(0.1)


func _park_around_pile() -> void:
	_place(_worker, PILE_LEFT)
	_place(_worker2, PILE_RIGHT)
	await _advance(0.1)


func _park_near_rock(worker: WorkerRuntime, rock: RockRuntime, z_offset: float) -> void:
	_place(worker, Vector3(rock.global_position.x + 1.5, 0.0, rock.global_position.z + z_offset))
	await _advance(0.1)


func _park_near_nest(worker: WorkerRuntime, z_offset: float) -> void:
	_place(worker, Vector3(_nest.global_position.x + 1.5, 0.0, _nest.global_position.z + z_offset))
	await _advance(0.1)


func _box_select_both() -> void:
	await _drag_over_both()
	_check(_selection.selected_units.size() == 2, "os dois Workers ficaram selecionados")


func _drag_over_both() -> void:
	var a := _screen(_worker.global_position)
	var b := _screen(_worker2.global_position)
	await _drag_screen(Vector2(minf(a.x, b.x) - 40.0, minf(a.y, b.y) - 40.0),
			Vector2(maxf(a.x, b.x) + 40.0, maxf(a.y, b.y) + 40.0))


func _click_select(worker: WorkerRuntime) -> void:
	await _press_release(MOUSE_BUTTON_LEFT, _screen(worker.global_position))


func _shift_click_select(worker: WorkerRuntime) -> void:
	await _shift_press_release(MOUSE_BUTTON_LEFT, _screen(worker.global_position))


func _click_ground(world_position: Vector3) -> void:
	await _press_release(MOUSE_BUTTON_LEFT, _screen(world_position))


func _shift_click_ground(world_position: Vector3) -> void:
	await _shift_press_release(MOUSE_BUTTON_LEFT, _screen(world_position))


func _right_click(world_position: Vector3) -> void:
	var screen := _screen(world_position)
	_press(MOUSE_BUTTON_RIGHT, screen)
	_release(MOUSE_BUTTON_RIGHT, screen)
	await _advance(0.05)


func _drag(from_world: Vector3, to_world: Vector3) -> void:
	await _drag_screen(_screen(from_world), _screen(to_world))


func _drag_screen(from_screen: Vector2, to_screen: Vector2) -> void:
	_press(MOUSE_BUTTON_LEFT, from_screen)
	_motion(from_screen.lerp(to_screen, 0.5))
	_motion(to_screen)
	_release(MOUSE_BUTTON_LEFT, to_screen)
	await _advance(0.05)


func _shift_drag_screen(from_screen: Vector2, to_screen: Vector2) -> void:
	Input.action_press(&"selection_additive")
	await _drag_screen(from_screen, to_screen)
	Input.action_release(&"selection_additive")


func _press_release(button: int, screen: Vector2) -> void:
	_press(button, screen)
	_release(button, screen)
	await _advance(0.05)


func _shift_press_release(button: int, screen: Vector2) -> void:
	Input.action_press(&"selection_additive")
	await _press_release(button, screen)
	Input.action_release(&"selection_additive")


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


func _motion(screen: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = screen
	event.global_position = screen
	root.push_input(event)


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


func _source(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func _check(condition: bool, label: String) -> void:
	_asserts += 1
	if condition:
		print("[PASS] %s" % label)
	else:
		_failures += 1
		print("[FAIL] %s" % label)


func _finish() -> void:
	print("---- multi selection tests finished: %d asserts, %d failure(s) ----"
			% [_asserts, _failures])
	quit(1 if _failures > 0 else 0)
