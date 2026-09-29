class_name WorkerState
extends RefCounted

signal health_changed(current: float, maximum: float)

var definition: WorkerDefinition
var unit_id: String
var health: float
var level: int = 1
var experience: float = 0.0
var carried_resource: ResourceDefinition
var carried_amount: int = 0


func _init(worker_definition: WorkerDefinition, id: String) -> void:
	definition = worker_definition
	unit_id = id
	health = worker_definition.max_health


func damage(amount: float) -> void:
	if amount <= 0.0:
		return
	_apply_health(health - amount)


func heal(amount: float) -> void:
	if amount <= 0.0:
		return
	_apply_health(health + amount)


func set_cargo(resource_definition: ResourceDefinition, amount: int) -> void:
	if resource_definition == null or amount <= 0:
		return
	if carried_resource != null and carried_resource != resource_definition:
		return
	carried_resource = resource_definition
	carried_amount = mini(amount, definition.carry_capacity)


func clear_cargo() -> void:
	carried_resource = null
	carried_amount = 0


func has_cargo() -> bool:
	return carried_amount > 0


## §23/§25/T18: devolução do que o Worker é e do que ele carrega. A carga entra pelo
## mesmo par (recurso, quantidade) que o Save nomeia por id semântico, e a faixa é a do
## `carry_capacity` da Definition — uma pilha de 3 no arquivo não vira 30 por engano de
## dígito. `level` e `experience` são persistidos porque §23 os pede e o State os tem;
## hoje nada os muda em gameplay, e restaurar 1/0.0 é devolver o que já estava lá.
func restore_persistent_state(
		value_health: float,
		value_level: int,
		value_experience: float,
		cargo_definition: ResourceDefinition,
		cargo_amount: int) -> bool:
	if value_health < 0.0 or value_health > definition.max_health:
		return false
	if value_level < 1 or value_experience < 0.0:
		return false
	if cargo_amount < 0 or cargo_amount > definition.carry_capacity:
		return false
	if cargo_amount > 0 and cargo_definition == null:
		return false
	if cargo_amount == 0 and cargo_definition != null:
		return false
	_apply_health(value_health)
	level = value_level
	experience = value_experience
	carried_resource = cargo_definition
	carried_amount = cargo_amount
	return true


func _apply_health(value: float) -> void:
	var maximum := definition.max_health
	var next := clampf(value, 0.0, maximum)
	if is_equal_approx(next, health):
		return
	health = next
	health_changed.emit(health, maximum)
