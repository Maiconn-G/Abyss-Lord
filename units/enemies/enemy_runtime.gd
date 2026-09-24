class_name EnemyRuntime
extends CharacterBody3D

signal enemy_died(enemy: EnemyRuntime)

var definition: EnemyDefinition
var state: EnemyState

@onready var _visual: MeshInstance3D = $Visual
@onready var _collision: CollisionShape3D = $CollisionShape3D

var _combat_target: SoldierRuntime
var _attack_cooldown := 0.0


func _ready() -> void:
	# Passiva: sem engage() a Fera não executa nada em nenhum frame.
	set_physics_process(false)


func setup(enemy_definition: EnemyDefinition, enemy_state: EnemyState) -> void:
	definition = enemy_definition
	state = enemy_state
	state.died.connect(_on_died)


func get_enemy_id() -> String:
	return state.enemy_id


func is_alive() -> bool:
	return state != null and not state.is_dead()


func receive_damage(amount: float) -> void:
	state.damage(amount)


## Raio do próprio collider, lido da forma física real para que quem nos ataque
## consiga parar do lado de fora sem duplicar medida nenhuma.
func body_radius() -> float:
	var shape := _collision.shape as CylinderShape3D
	return shape.radius if shape != null else 0.5


func engage(soldier: SoldierRuntime) -> void:
	if not is_alive() or soldier == null or not is_instance_valid(soldier):
		return
	_combat_target = soldier
	_attack_cooldown = definition.attack_interval
	set_physics_process(true)


func disengage() -> void:
	_combat_target = null
	set_physics_process(false)


func combat_target() -> SoldierRuntime:
	return _combat_target


func is_engaged() -> bool:
	return _combat_target != null and is_instance_valid(_combat_target)


func _physics_process(delta: float) -> void:
	# Nesta tarefa a Fera nunca se desloca; ela apenas revida onde está plantada.
	velocity = Vector3.ZERO
	if not is_engaged() or _combat_target.state.is_dead():
		disengage()
		return
	if _planar_gap(_combat_target.global_position) > definition.attack_range:
		return
	_attack_cooldown -= delta
	if _attack_cooldown > 0.0:
		return
	_attack_cooldown += definition.attack_interval
	_combat_target.receive_damage(definition.attack_damage)


func _on_died() -> void:
	disengage()
	_visual.visible = false
	_collision.disabled = true
	collision_layer = 0
	enemy_died.emit(self)
	queue_free()


func _planar_gap(target: Vector3) -> float:
	var offset := target - global_position
	offset.y = 0.0
	return offset.length()
