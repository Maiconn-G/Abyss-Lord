class_name EnemyState
extends RefCounted

signal health_changed(current: float, maximum: float)
signal died

var definition: EnemyDefinition
var enemy_id: String
var health: float


func _init(enemy_definition: EnemyDefinition, id: String) -> void:
	definition = enemy_definition
	enemy_id = id
	health = enemy_definition.max_health


func damage(amount: float) -> void:
	if amount <= 0.0:
		return
	_apply_health(health - amount)


func heal(amount: float) -> void:
	if amount <= 0.0:
		return
	_apply_health(health + amount)


func is_dead() -> bool:
	return health <= 0.0


func _apply_health(value: float) -> void:
	var maximum := definition.max_health
	var next := clampf(value, 0.0, maximum)
	if is_equal_approx(next, health):
		return
	health = next
	health_changed.emit(health, maximum)
	# Chegar a zero emite died uma única vez: depois disso _apply_health retorna
	# cedo em qualquer novo dano, então o sinal não pode se repetir.
	if is_dead():
		died.emit()
