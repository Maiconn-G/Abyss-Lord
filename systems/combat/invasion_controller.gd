class_name InvasionController
extends Node

enum InvasionState { NOT_STARTED, ACTIVE, VICTORY, DEFEAT }

## §30: a primeira invasão é exatamente isto — duas Feras Cavernosas da mesma
## Definition, uma largada, um desfecho. Não existe fila de largadas nem fábrica de
## inimigos: só uma criatura conhecida, criada por quem detém o ciclo de vida.
const INVADER_COUNT := 2

signal invasion_started(invaders: Array)
signal invasion_victory
signal invasion_defeat
signal active_invaders_changed(current: int)

var _definition: EnemyDefinition
var _scene: PackedScene
var _dungeon_root: Node3D
var _core: CoreRuntime
var _spawn_points: Array[Node3D] = []
var _invaders: Array[EnemyRuntime] = []
var _state: InvasionState = InvasionState.NOT_STARTED
var _active_invaders := 0


## §28: tudo que o ciclo de vida precisa chega por parâmetro. Nenhum lookup global,
## nenhum grupo varrido, nenhum autoload.
func setup(
		definition: EnemyDefinition,
		enemy_scene: PackedScene,
		dungeon_root: Node3D,
		core: CoreRuntime,
		spawn_points: Array) -> void:
	_definition = definition
	_scene = enemy_scene
	_dungeon_root = dungeon_root
	_core = core
	_spawn_points.assign(spawn_points)


func invasion_state() -> InvasionState:
	return _state


func active_invaders() -> int:
	return _active_invaders


func invaders() -> Array[EnemyRuntime]:
	return _invaders


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("start_invasion"):
		start_invasion()


func start_invasion() -> bool:
	if _state != InvasionState.NOT_STARTED:
		return false
	for index in INVADER_COUNT:
		var enemy := _scene.instantiate() as EnemyRuntime
		enemy.name = "Invader%03d" % (index + 1)
		# §35: cada invasor tem o próprio State; a única coisa compartilhada é a
		# Definition, que nunca guarda número mutável.
		enemy.setup(_definition, EnemyState.new(_definition, "invader_%03d" % (index + 1)))
		_dungeon_root.add_child(enemy)
		enemy.global_position = _spawn_points[index].global_position
		enemy.enemy_died.connect(_on_invader_died)
		_invaders.append(enemy)
		_active_invaders += 1
		# §42: o alvo estratégico é entregue por referência direta.
		enemy.start_invasion(_core)
	_core.core_state().destroyed.connect(_on_core_destroyed)
	_state = InvasionState.ACTIVE
	invasion_started.emit(_invaders.duplicate())
	active_invaders_changed.emit(_active_invaders)
	return true


func _on_invader_died(_defeated: EnemyRuntime) -> void:
	if _state != InvasionState.ACTIVE:
		return
	_active_invaders -= 1
	active_invaders_changed.emit(_active_invaders)
	# §36: vitória só existe com o Núcleo de pé. Derrubar as duas Feras depois de
	# Zero não ressuscita ninguém — e não entrega ganho algum (§41).
	if _active_invaders == 0:
		_state = InvasionState.VICTORY
		invasion_victory.emit()


func _on_core_destroyed() -> void:
	if _state != InvasionState.ACTIVE:
		return
	_state = InvasionState.DEFEAT
	for enemy in _invaders:
		if is_instance_valid(enemy):
			enemy.stand_down()
	# §23: o Núcleo não sai da árvore — apenas o estado mudaria isso, e ele é do
	# CoreState, não daqui.
	invasion_defeat.emit()
