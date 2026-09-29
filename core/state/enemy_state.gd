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


## §76/T18: devolver ao invasor a vida que o arquivo registrou. Não é `damage`: o Save
## não reinterpreta o combate, ele restaura o número. Valida faixa e emite o sinal com o
## valor final, uma vez. Nunca emite `died` — um inim vivo com vida zerada não é uma
## campanha possível, e o sinal derrubaria contagem e recompensa numa carga limpa.
func restore_health(value: float) -> bool:
	if value <= 0.0 or value > definition.max_health:
		return false
	health = value
	health_changed.emit(health, definition.max_health)
	return true


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
