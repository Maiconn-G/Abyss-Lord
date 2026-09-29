class_name SoldierState
extends RefCounted

signal health_changed(current: float, maximum: float)
signal died

var definition: SoldierDefinition
var unit_id: String
var health: float
var level: int = 1
var experience: float = 0.0


func _init(soldier_definition: SoldierDefinition, id: String) -> void:
	definition = soldier_definition
	unit_id = id
	health = soldier_definition.max_health


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


## §76/T18: o caminho da persistência. Não é `damage` nem `heal`, porque o Save não
## reconta uma história de combate — ele devolve a tropa ao número que estava no
## arquivo. Por isso a validação é de faixa e o sinal é do valor final, emitido uma
## vez. Nunca emite `died`: um soldado ferido que carrega vida zero não existe no
## Save, e recriar um morto dispararia a cadeia de baixa do recrutamento.
func restore_persistent_state(
		value_health: float,
		value_level: int,
		value_experience: float) -> bool:
	if value_health <= 0.0 or value_health > definition.max_health:
		return false
	if value_level < 1 or value_experience < 0.0:
		return false
	health = value_health
	level = value_level
	experience = value_experience
	health_changed.emit(health, definition.max_health)
	return true


func _apply_health(value: float) -> void:
	var maximum := definition.max_health
	var next := clampf(value, 0.0, maximum)
	if is_equal_approx(next, health):
		return
	health = next
	health_changed.emit(health, maximum)
	# Mesma semântica de EnemyState: chegar a zero emite died uma única vez, porque
	# qualquer dano posterior cai no retorno cedo de _apply_health.
	if is_dead():
		died.emit()
