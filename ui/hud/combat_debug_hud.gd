class_name CombatDebugHud
extends PanelContainer

@onready var _soldier_label: Label = %SoldierLabel
@onready var _enemy_label: Label = %EnemyLabel

## Rótulo fixo do painel de debug: a linha do inimigo usa o display_name da
## Definition, e a do Soldado fica curta o bastante para caber no painel.
const SOLDIER_LINE_PREFIX := "Soldado"

var _soldier_definition: SoldierDefinition
var _soldier_state: SoldierState
var _enemy_state: EnemyState
var _enemy_name := "Inimigo"
var _enemy_defeated := false


func bind(
		enemy: EnemyRuntime,
		recruitment: SoldierRecruitmentController,
		soldier_definition: SoldierDefinition) -> void:
	_soldier_definition = soldier_definition
	_enemy_state = enemy.state
	_enemy_name = enemy.definition.display_name
	enemy.state.health_changed.connect(_on_state_changed)
	enemy.state.died.connect(_on_enemy_died)
	recruitment.soldier_recruited.connect(_on_soldier_recruited)
	_refresh()


func _on_soldier_recruited(soldier: SoldierRuntime) -> void:
	_soldier_state = soldier.state
	soldier.state.health_changed.connect(_on_state_changed)
	_refresh()


func _on_state_changed(_current: float, _maximum: float) -> void:
	_refresh()


func _on_enemy_died() -> void:
	_enemy_defeated = true
	_refresh()


func _refresh() -> void:
	var soldier_health := _soldier_definition.max_health
	if _soldier_state != null:
		soldier_health = _soldier_state.health
	_soldier_label.text = _line_of(
			SOLDIER_LINE_PREFIX, soldier_health, _soldier_definition.max_health)
	if _enemy_defeated:
		_enemy_label.text = "%s: derrotada" % _enemy_name
	else:
		_enemy_label.text = _line_of(
				_enemy_name, _enemy_state.health, _enemy_state.definition.max_health)


func _line_of(unit_name: String, current: float, maximum: float) -> String:
	return "%s: %d / %d HP" % [unit_name, roundi(current), roundi(maximum)]
