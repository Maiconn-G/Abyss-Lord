class_name SoldierRecruitmentController
extends Node

const RECRUITED_UNIT_ID := "soldier_001"

signal soldier_recruited(soldier: SoldierRuntime)

var _core_state: CoreState
var _definition: SoldierDefinition
var _scene: PackedScene
var _dungeon_root: Node3D
var _spawn_point: Node3D
var _construction: ConstructionController
var _soldier: SoldierRuntime
var _recruited := false


func setup(
		core_state: CoreState,
		soldier_definition: SoldierDefinition,
		soldier_scene: PackedScene,
		dungeon_root: Node3D,
		spawn_point: Node3D,
		construction: ConstructionController) -> void:
	_core_state = core_state
	_definition = soldier_definition
	_scene = soldier_scene
	_dungeon_root = dungeon_root
	_spawn_point = spawn_point
	_construction = construction


func soldier() -> SoldierRuntime:
	return _soldier


func barracks_completed() -> bool:
	var barracks := _construction.barracks()
	return barracks != null and barracks.is_completed()


func can_recruit() -> bool:
	# §47: continua existindo um único Soldado recrutável. A morte não libera
	# substituição nesta tarefa, por isso a flag permanente é a guarda.
	if _recruited:
		return false
	if not barracks_completed():
		return false
	if not _core_state.can_add_population(1):
		return false
	return _core_state.essence >= _definition.recruit_essence_cost


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("recruit_soldier"):
		recruit_soldier()


func recruit_soldier() -> bool:
	if not can_recruit():
		return false
	var soldier := _scene.instantiate() as SoldierRuntime
	soldier.setup(_definition, SoldierState.new(_definition, RECRUITED_UNIT_ID))
	# can_recruit() espelha exatamente as guardas de consume_essence() e
	# can_add_population(), então nenhum destes dois passos pode falhar aqui.
	_core_state.consume_essence(_definition.recruit_essence_cost)
	_core_state.try_add_population(1)
	_dungeon_root.add_child(soldier)
	soldier.global_position = _spawn_point.global_position
	_soldier = soldier
	_recruited = true
	# §45: quem criou a unidade conecta a morte dela à população que ela ocupava.
	soldier.soldier_died.connect(_on_soldier_died)
	soldier_recruited.emit(soldier)
	return true


func _on_soldier_died(_defeated: SoldierRuntime) -> void:
	# §46: soldier_died emite uma única vez, então Population cai exatamente 1.
	_core_state.try_remove_population(1)
	# A referência é limpa para ninguém consultar um Node já libertado; o que impede
	# um segundo recruta nesta tarefa é _recruited, não o ponteiro (§47).
	_soldier = null
