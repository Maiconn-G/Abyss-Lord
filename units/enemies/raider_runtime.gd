class_name RaiderRuntime
extends EnemyRuntime

## Tarefa 23 — o Saqueador de Guilda. Ele é um EnemyRuntime de verdade: o Soldado o
## seleciona, persegue e golpeia pelo mesmo caminho da Fera (grupo combat_target, vida no
## EnemyState, `engage`/`disengage`), e por isso nenhum controller de combate ganhou branch
## de tipo. O que muda é o objetivo: a Fera marcha sobre o Núcleo; o saqueador ignora o
## Núcleo, vai ao Depósito, rouba e recua para a superfície.
##
## O ciclo do saque é a fase do RaiderState (APPROACH → LOOT → RETREAT), não um modo novo
## do EnemyRuntime: enquanto saqueia, o modo base é ADVANCE (o processo físico ligado), e
## COMBAT continua sendo o duelo herdado.

signal loot_stolen(raider: RaiderRuntime, resource: ResourceDefinition, amount: int)
signal raider_escaped(raider: RaiderRuntime)

const EXIT_TOLERANCE := 0.5

var _stockpile: ResourceStockpileState
var _deposit_position := Vector3.ZERO
var _exit_position := Vector3.ZERO
var _steal_cooldown := 0.0
var _escaped := false


func raider_state() -> RaiderState:
	return state as RaiderState


func raider_definition() -> RaiderDefinition:
	return definition as RaiderDefinition


## Tudo que o saque precisa chega por binding explícito, da mão de quem detém o ciclo da
## incursão: o estoque de onde se rouba, onde fica o Depósito e por onde se foge.
func bind_raid(stockpile: ResourceStockpileState, deposit_position: Vector3,
		exit_position: Vector3) -> void:
	_stockpile = stockpile
	_deposit_position = deposit_position
	_exit_position = exit_position


func exit_position() -> Vector3:
	return _exit_position


## Começa (ou retoma, depois de uma carga) o saque na fase que o State registra.
func begin_raid() -> void:
	if not is_alive() or _stockpile == null:
		return
	_steal_cooldown = raider_definition().steal_interval
	_enter_mode(ActionMode.ADVANCE)


func has_escaped() -> bool:
	return _escaped


func _physics_process(delta: float) -> void:
	if _mode == ActionMode.COMBAT:
		# Ferido demais, ele larga a briga e foge, mesmo cercado.
		if raider_state().should_retreat():
			_start_retreat()
			_combat_target = null
			_enter_mode(ActionMode.ADVANCE)
			return
		_process_combat(delta)
		return
	if _mode == ActionMode.ADVANCE:
		_process_raid(delta)


## O duelo herdado chama aqui quando o Soldado morre ou o solta: o saqueador volta ao saque
## na fase em que estava, nunca à marcha sobre o Núcleo.
func _resume_advance() -> void:
	_in_core_stance = false
	_attack_cooldown = 0.0
	if is_alive() and _stockpile != null:
		_enter_mode(ActionMode.ADVANCE)
		return
	_enter_mode(ActionMode.IDLE)


func _process_raid(delta: float) -> void:
	var raid := raider_state()
	if raid.phase != RaiderState.Phase.RETREAT and raid.should_retreat():
		_start_retreat()
	match raid.phase:
		RaiderState.Phase.APPROACH:
			if _walk_towards(_deposit_position, raider_definition().loot_range, delta):
				raid.phase = RaiderState.Phase.LOOT
				_steal_cooldown = raider_definition().steal_interval
		RaiderState.Phase.LOOT:
			velocity = Vector3.ZERO
			_steal_cooldown -= delta
			if _steal_cooldown > 0.0:
				return
			_steal_cooldown += raider_definition().steal_interval
			if not _steal_one():
				_start_retreat()
		RaiderState.Phase.RETREAT:
			if _walk_towards(_exit_position, EXIT_TOLERANCE, delta):
				_escape()


## Uma unidade por golpe de saque, pela ordem de preferência da Definition. Devolve false
## quando não há mais o que levar — bolso cheio ou Depósito vazio.
func _steal_one() -> bool:
	var raid := raider_state()
	if not raid.has_room():
		return false
	for resource in raider_definition().loot_priority:
		if resource == null:
			continue
		if _stockpile.get_amount(resource.resource_id) <= 0:
			continue
		if not _stockpile.consume_resource(resource, 1):
			continue
		raid.carry(resource.resource_id, 1)
		loot_stolen.emit(self, resource, 1)
		return raid.has_room()
	return false


func _start_retreat() -> void:
	raider_state().phase = RaiderState.Phase.RETREAT


## Chegou à superfície: o saqueador sai de cena levando o que carrega. Não é morte — não há
## `died` nem `enemy_died` —, é fuga, e quem decide o que isso significa é o controller.
func _escape() -> void:
	if _escaped:
		return
	_escaped = true
	_enter_mode(ActionMode.IDLE)
	_visual.visible = false
	_collision.disabled = true
	collision_layer = 0
	remove_from_group(&"combat_target")
	raider_escaped.emit(self)
	queue_free()


## Anda em linha reta no plano. Devolve true quando já está dentro de `tolerance`.
func _walk_towards(target: Vector3, tolerance: float, _delta: float) -> bool:
	var offset := _planar_offset(target)
	if offset.length() <= tolerance:
		velocity = Vector3.ZERO
		return true
	velocity = offset.normalized() * definition.move_speed
	velocity.y = 0.0
	move_and_slide()
	return false
