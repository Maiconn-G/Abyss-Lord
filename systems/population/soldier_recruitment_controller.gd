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


## §28/T18: a regra da Tarefa 11 é um Soldado só e a morte não libera substituição. Quem
## garante isso depois de um load é a flag histórica, nunca a existência do Runtime — um
## soldado morto tem `recruited = true` e nenhum Node.
func ever_recruited() -> bool:
	return _recruited


## §27/§28/§54/§95/T18: o recrutamento que o arquivo registra é restaurado como fato, não
## refeito como jogada. Não se cobra Essência, não se soma Population (o número volta pelo
## CoreState, §29) e não se emite `soldier_recruited` — o sinal conta a conquista do
## instante, e a UI é alinhada pelo refresh da carga. Com `value_alive` em false só a flag
## histórica é escrita: morto não ressuscita, e `R` continua bloqueado.
##
## §95/§100: a rota sincroniza a campanha com o arquivo. `recruited = false` liberta o
## Soldado que a partida criou depois do save, e um load repetido ajusta o Runtime que já
## está em cena em vez de recusar — é isso que torna a quinta carga igual à primeira.
func restore_soldier(
		value_recruited: bool,
		value_alive: bool,
		value_health: float,
		value_level: int,
		value_experience: float,
		unit_position: Vector3) -> bool:
	if not value_recruited:
		_remove_soldier()
		_recruited = false
		return true
	_recruited = true
	if not value_alive:
		_remove_soldier()
		return true
	if is_instance_valid(_soldier) and not _soldier.is_queued_for_deletion():
		if not _soldier.state.restore_persistent_state(
				value_health, value_level, value_experience):
			return false
		_soldier.global_position = unit_position
		_soldier.reset_transient_order()
		return true
	var state := SoldierState.new(_definition, RECRUITED_UNIT_ID)
	if not state.restore_persistent_state(value_health, value_level, value_experience):
		return false
	var soldier := _scene.instantiate() as SoldierRuntime
	soldier.setup(_definition, state)
	_dungeon_root.add_child(soldier)
	soldier.global_position = unit_position
	soldier.reset_transient_order()
	_soldier = soldier
	soldier.soldier_died.connect(_on_soldier_died)
	return true


## §95/T18: sair sem `soldier_died` é o que impede a cadeia de morte de rodar como efeito
## de carga — sem recompensa, sem luto na UI e sem Population descontada.
func _remove_soldier() -> void:
	if _soldier != null and is_instance_valid(_soldier):
		_soldier.reset_transient_order()
		_soldier.queue_free()
	_soldier = null


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
