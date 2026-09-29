class_name CombatDebugHud
extends PanelContainer

@onready var _soldier_label: Label = %SoldierLabel
@onready var _enemy_label: Label = %EnemyLabel

## Rótulo fixo do painel de debug: a linha do inimigo usa o display_name da
## Definition, e a do Soldado fica curta o bastante para caber no painel.
const SOLDIER_LINE_PREFIX := "Soldado"
## §32 da Tarefa 12: a partida normal abre sem nenhum inimigo em campo, então o
## painel precisa dizer isso antes de o primeiro invasor ser ligado a ele.
const NO_ENEMY_LINE := "Sem inimigo em campo"

var _soldier_definition: SoldierDefinition
var _soldier_state: SoldierState
var _enemy_name := "Inimigo"
var _enemy_states: Array[EnemyState] = []


func bind_recruitment(
		recruitment: SoldierRecruitmentController,
		soldier_definition: SoldierDefinition) -> void:
	_soldier_definition = soldier_definition
	recruitment.soldier_recruited.connect(_on_soldier_recruited)
	_refresh()


## Uma Fera entra no painel. Exibimos sempre a primeira ainda viva das ligadas:
## quando a invasora do momento cai, a próxima assume o rótulo sozinha, e o único
## gatilho disso continua sendo o signal do State.
func bind_enemy(enemy: EnemyRuntime) -> void:
	if enemy == null or _enemy_states.has(enemy.state):
		return
	_enemy_states.append(enemy.state)
	_enemy_name = enemy.definition.display_name
	if not enemy.state.health_changed.is_connected(_on_state_changed):
		enemy.state.health_changed.connect(_on_state_changed)
	if not enemy.state.died.is_connected(_on_enemy_died):
		enemy.state.died.connect(_on_enemy_died)
	_refresh()


## §77/T18: a carga restaura unidades sem emitir `soldier_recruited` nem `invasion_started`
## (§75), e os States recriados não são os que este painel conhecia. `refresh_units` troca
## a coleção por quem está em campo agora — ligação repetida no mesmo State é descartada
## pelo guard de `bind_enemy`, porque um load duas vezes é a mesma tela.
func refresh_units(soldier: SoldierRuntime, invaders: Array) -> void:
	_enemy_states.clear()
	_soldier_state = null
	for invader in invaders:
		bind_enemy(invader)
	bind_soldier(soldier)


func bind_soldier(soldier: SoldierRuntime) -> void:
	if soldier == null:
		_soldier_state = null
		_refresh()
		return
	_soldier_state = soldier.state
	if not soldier.state.health_changed.is_connected(_on_state_changed):
		soldier.state.health_changed.connect(_on_state_changed)
	_refresh()


func _on_soldier_recruited(soldier: SoldierRuntime) -> void:
	bind_soldier(soldier)


func _on_state_changed(_current: float, _maximum: float) -> void:
	_refresh()


## O signal died do State não leva número nenhum: quem morreu não tem o que reportar,
## e o painel só precisa trocar a linha para a próxima Fera viva.
func _on_enemy_died() -> void:
	_refresh()


func _refresh() -> void:
	var soldier_health := _soldier_definition.max_health
	if _soldier_state != null:
		soldier_health = _soldier_state.health
	_soldier_label.text = _line_of(
			SOLDIER_LINE_PREFIX, soldier_health, _soldier_definition.max_health)
	_enemy_label.text = _enemy_line()


func _enemy_line() -> String:
	var displayed: EnemyState = null
	for enemy_state in _enemy_states:
		if not enemy_state.is_dead():
			displayed = enemy_state
			break
	if displayed != null:
		return _line_of(_enemy_name, displayed.health, displayed.definition.max_health)
	if _enemy_states.is_empty():
		return NO_ENEMY_LINE
	return "%s: derrotada" % _enemy_name


func _line_of(unit_name: String, current: float, maximum: float) -> String:
	return "%s: %d / %d HP" % [unit_name, roundi(current), roundi(maximum)]
