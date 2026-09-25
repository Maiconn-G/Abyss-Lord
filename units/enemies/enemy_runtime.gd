class_name EnemyRuntime
extends CharacterBody3D

enum ActionMode { IDLE, ADVANCE, COMBAT }

const BODY_CLEARANCE := 0.1

signal enemy_died(enemy: EnemyRuntime)

var definition: EnemyDefinition
var state: EnemyState

@onready var _visual: MeshInstance3D = $Visual
@onready var _collision: CollisionShape3D = $CollisionShape3D

var _mode: ActionMode = ActionMode.IDLE
var _combat_target: SoldierRuntime
var _invasion_target: CoreRuntime
var _attack_cooldown := 0.0
var _in_core_stance := false


func _ready() -> void:
	# Sem engage() nem start_invasion() a Fera não executa nada em nenhum frame.
	set_physics_process(false)


func setup(enemy_definition: EnemyDefinition, enemy_state: EnemyState) -> void:
	definition = enemy_definition
	state = enemy_state
	state.died.connect(_on_died)


func get_enemy_id() -> String:
	return state.enemy_id


func action_mode() -> ActionMode:
	return _mode


func is_alive() -> bool:
	return state != null and not state.is_dead()


func receive_damage(amount: float) -> void:
	state.damage(amount)


## Raio do próprio collider, lido da forma física real para que quem nos ataque
## consiga parar do lado de fora sem duplicar medida nenhuma.
func body_radius() -> float:
	var shape := _collision.shape as CylinderShape3D
	return shape.radius if shape != null else 0.5


## §11: o Núcleo é entregue por injeção (§42), nunca descoberto por física ou scan.
func start_invasion(core: CoreRuntime) -> void:
	if not is_alive() or core == null:
		return
	_invasion_target = core
	_enter_mode(ActionMode.ADVANCE)


func invasion_target() -> CoreRuntime:
	return _invasion_target


func engage(soldier: SoldierRuntime) -> void:
	if not is_alive() or soldier == null or not is_instance_valid(soldier):
		return
	_combat_target = soldier
	# §16: o alvo novo arma o intervalo cheio, então trocar de alvo nunca acelera um golpe.
	_attack_cooldown = definition.attack_interval
	_enter_mode(ActionMode.COMBAT)


## §19: soltar o Soldado não devolve a Fera ao ócio da Tarefa 11 quando ela tem
## para onde marchar — aí o modo volta a ser ADVANCE.
func disengage() -> void:
	_combat_target = null
	if _mode != ActionMode.COMBAT:
		return
	_resume_advance()


func combat_target() -> SoldierRuntime:
	return _combat_target


func is_engaged() -> bool:
	return _combat_target != null and is_instance_valid(_combat_target)


## §22: com o Núcleo destruído a invasão acabou; quem manda parar é o dono do
## ciclo de vida, e aqui só se desliga o comportamento.
func stand_down() -> void:
	_combat_target = null
	_invasion_target = null
	_in_core_stance = false
	_attack_cooldown = 0.0
	_enter_mode(ActionMode.IDLE)


func _physics_process(delta: float) -> void:
	if _mode == ActionMode.COMBAT:
		_process_combat(delta)
	elif _mode == ActionMode.ADVANCE:
		_process_advance(delta)


func _process_combat(delta: float) -> void:
	# Em COMBAT a Fera bate parada: quem anda até ela continua sendo o Soldado.
	velocity = Vector3.ZERO
	if _combat_target == null or not is_instance_valid(_combat_target) \
			or _combat_target.state.is_dead():
		_combat_target = null
		_resume_advance()
		return
	if _planar_gap(_combat_target.global_position) > definition.attack_range:
		return
	_attack_cooldown -= delta
	if _attack_cooldown > 0.0:
		return
	_attack_cooldown += definition.attack_interval
	_combat_target.receive_damage(definition.attack_damage)


func _process_advance(delta: float) -> void:
	if _invasion_target == null or not is_instance_valid(_invasion_target):
		_enter_mode(ActionMode.IDLE)
		return
	var offset := _planar_offset(_invasion_target.global_position)
	if offset.length() > _core_stance_distance():
		_in_core_stance = false
		velocity = offset.normalized() * definition.move_speed
		velocity.y = 0.0
		move_and_slide()
		return
	# §14/§15/§16: para do lado de fora do corpo do Núcleo e só golpeia depois de um
	# attack_interval completo, com a mesma semântica temporal do duelo da Tarefa 11.
	velocity = Vector3.ZERO
	if not _in_core_stance:
		_in_core_stance = true
		_attack_cooldown = definition.attack_interval
	_attack_cooldown -= delta
	if _attack_cooldown > 0.0:
		return
	_attack_cooldown += definition.attack_interval
	_invasion_target.receive_damage(definition.attack_damage)


## §14: distância de postura medida entre centros, somando o raio de combate do
## Núcleo e o próprio corpo, de forma que as duas primitivas nunca se sobreponham.
func _core_stance_distance() -> float:
	return _invasion_target.combat_radius + body_radius() + BODY_CLEARANCE


func _resume_advance() -> void:
	_in_core_stance = false
	_attack_cooldown = 0.0
	if _invasion_target != null and is_instance_valid(_invasion_target):
		_enter_mode(ActionMode.ADVANCE)
		return
	_enter_mode(ActionMode.IDLE)


func _enter_mode(mode: ActionMode) -> void:
	_mode = mode
	set_physics_process(mode != ActionMode.IDLE)
	if mode == ActionMode.IDLE:
		velocity = Vector3.ZERO


func _on_died() -> void:
	_combat_target = null
	_invasion_target = null
	_in_core_stance = false
	_attack_cooldown = 0.0
	_mode = ActionMode.IDLE
	velocity = Vector3.ZERO
	set_physics_process(false)
	_visual.visible = false
	_collision.disabled = true
	collision_layer = 0
	enemy_died.emit(self)
	queue_free()


func _planar_gap(target: Vector3) -> float:
	return _planar_offset(target).length()


func _planar_offset(target: Vector3) -> Vector3:
	var offset := target - global_position
	offset.y = 0.0
	return offset
