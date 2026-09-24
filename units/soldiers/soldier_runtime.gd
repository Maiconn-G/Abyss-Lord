class_name SoldierRuntime
extends CharacterBody3D

enum ActionMode { IDLE, MOVE, ATTACK }

const RTS_SELECTABLE_GROUP := &"rts_selectable"
const COMBAT_TARGET_GROUP := &"combat_target"
const ENEMY_LAYER := 32
const BODY_CLEARANCE := 0.1
const ATTACK_RANGE_MARGIN := 0.1
## Folga da postura de golpe: o Soldado pode parar a essa distância do ponto ideal
## sem precisar cravar o último centímetro em cada frame.
const STANCE_TOLERANCE := 0.02

@export var arrival_distance: float = 0.1

signal soldier_died(soldier: SoldierRuntime)

var definition: SoldierDefinition
var state: SoldierState

@onready var _selection_indicator: MeshInstance3D = $SelectionIndicator
@onready var _visual: MeshInstance3D = $Visual
@onready var _collision: CollisionShape3D = $CollisionShape3D

var _mode: ActionMode = ActionMode.IDLE
var _target_position := Vector3.ZERO
var _has_move_target := false
var _attack_target: EnemyRuntime
var _attack_cooldown := 0.0
var _defeated := false


func _ready() -> void:
	# Fora de movimento ou de combate o Soldado não consome física nenhuma.
	if not _has_move_target:
		set_physics_process(false)


func setup(soldier_definition: SoldierDefinition, soldier_state: SoldierState) -> void:
	definition = soldier_definition
	state = soldier_state
	state.died.connect(_on_died)


func get_unit_id() -> String:
	return state.unit_id


func set_selected(value: bool) -> void:
	_selection_indicator.visible = value


func action_mode() -> ActionMode:
	return _mode


func body_radius() -> float:
	var shape := _collision.shape as CapsuleShape3D
	return shape.radius if shape != null else 0.5


func move_to(target: Vector3) -> void:
	if _defeated:
		return
	_cancel_attack()
	_mode = ActionMode.MOVE
	_target_position = Vector3(target.x, global_position.y, target.z)
	_has_move_target = true
	set_physics_process(true)


func has_move_target() -> bool:
	return _has_move_target


func attack_target(target) -> bool:
	if _defeated or not _is_attackable(target):
		return false
	_mode = ActionMode.ATTACK
	_attack_target = target
	_target_position = _strike_point(target)
	_has_move_target = true
	# §30: entrar em ATTACK arma o cooldown cheio, então o primeiro golpe nunca é
	# instantâneo e o timing fica determinístico.
	_attack_cooldown = definition.attack_interval
	set_physics_process(true)
	# A retaliação é provocada por esta ordem, não descoberta por busca global.
	target.engage(self)
	return true


func current_attack_target() -> EnemyRuntime:
	return _attack_target


func attack_cooldown() -> float:
	return _attack_cooldown


func receive_damage(amount: float) -> void:
	state.damage(amount)


func _physics_process(delta: float) -> void:
	if _mode == ActionMode.ATTACK:
		_process_attack(delta)
	elif _mode == ActionMode.MOVE:
		_process_move()


func _process_move() -> void:
	if not _has_move_target:
		set_physics_process(false)
		return
	if _walk_step():
		return
	_mode = ActionMode.IDLE
	set_physics_process(false)


func _process_attack(delta: float) -> void:
	if _attack_target == null or not is_instance_valid(_attack_target) \
			or not _attack_target.is_alive():
		_finish_attack()
		return
	# §27/§28: só se golpeia de fora do corpo do inimigo e dentro do próprio alcance.
	# A distância de postura já é limitada por attack_range - margem, então chegar a
	# ela garante as duas condições de uma vez.
	if not _in_striking_stance(_attack_target):
		_target_position = _strike_point(_attack_target)
		_has_move_target = true
		_walk_step()
		return
	_stop_walking()
	_attack_cooldown -= delta
	if _attack_cooldown > 0.0:
		return
	_attack_cooldown += definition.attack_interval
	_attack_target.receive_damage(definition.attack_damage)


## Retorna true enquanto houver caminho a percorrer.
func _walk_step() -> bool:
	var offset := _planar_offset(_target_position)
	if offset.length() <= arrival_distance:
		global_position = Vector3(_target_position.x, global_position.y, _target_position.z)
		_stop_walking()
		return false
	velocity = offset.normalized() * definition.move_speed
	velocity.y = 0.0
	move_and_slide()
	return true


func _is_attackable(target) -> bool:
	if not (target is EnemyRuntime):
		return false
	var enemy := target as EnemyRuntime
	return enemy.is_in_group(COMBAT_TARGET_GROUP) and enemy.is_alive()


func _strike_point(enemy: EnemyRuntime) -> Vector3:
	var to_enemy := _planar_offset(enemy.global_position)
	if to_enemy.length() <= 0.0001:
		return global_position
	var center := enemy.global_position
	return Vector3(center.x, global_position.y, center.z) \
			- to_enemy.normalized() * _strike_distance(enemy)


## Ponto de parada: o mais perto que o Soldado pode chegar sem sobrepor os dois
## colisores, nunca além do alcance do golpe.
func _strike_distance(enemy: EnemyRuntime) -> float:
	var separation := enemy.body_radius() + body_radius() + BODY_CLEARANCE
	return minf(separation, definition.attack_range - ATTACK_RANGE_MARGIN)


func _in_striking_stance(enemy: EnemyRuntime) -> bool:
	var gap := _planar_gap(enemy.global_position)
	return gap <= definition.attack_range \
			and gap <= _strike_distance(enemy) + STANCE_TOLERANCE \
			and not _overlaps_target()


func _overlaps_target() -> bool:
	var probe := SphereShape3D.new()
	probe.radius = body_radius()
	var parameters := PhysicsShapeQueryParameters3D.new()
	parameters.shape = probe
	parameters.transform = Transform3D(Basis.IDENTITY,
			Vector3(global_position.x, 0.5, global_position.z))
	parameters.collision_mask = ENEMY_LAYER
	return not get_world_3d().direct_space_state.intersect_shape(parameters, 4).is_empty()


func _finish_attack() -> void:
	_cancel_attack()
	_mode = ActionMode.IDLE
	_stop_walking()
	set_physics_process(false)


func _cancel_attack() -> void:
	if _attack_target != null and is_instance_valid(_attack_target):
		_attack_target.disengage()
	_attack_target = null
	_attack_cooldown = 0.0


func _stop_walking() -> void:
	velocity = Vector3.ZERO
	_has_move_target = false


func _on_died() -> void:
	if _defeated:
		return
	_defeated = true
	_cancel_attack()
	_mode = ActionMode.IDLE
	_stop_walking()
	set_physics_process(false)
	set_selected(false)
	remove_from_group(RTS_SELECTABLE_GROUP)
	_visual.visible = false
	_collision.disabled = true
	collision_layer = 0
	soldier_died.emit(self)
	queue_free()


func _planar_gap(target: Vector3) -> float:
	return _planar_offset(target).length()


func _planar_offset(target: Vector3) -> Vector3:
	var offset := target - global_position
	offset.y = 0.0
	return offset
