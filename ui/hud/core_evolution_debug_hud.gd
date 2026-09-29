class_name CoreEvolutionDebugHud
extends PanelContainer

## Tarefa 14 — §40/§41/§42: o painel da única progressão que existe no MVP. Ele não
## decide nada: cada linha é lida do controller e do CoreState no instante em que um
## signal deles chega. Não existe `_process`, não existe consulta à invasão, não existe
## literal de nível ou de custo — `Nv.2` e `25` vêm da Definition de destino.
##
## Tarefa 17 — §43/§50: o Cristal ganhou linha neste mesmo painel, e não um décimo
## painel na tela. A dívida de HUDs fragmentados registrada na Tarefa 15 é exatamente o
## motivo: a condição de evolução e o registro da conquista são a mesma informação.

@onready var _level_label: Label = %LevelLabel
@onready var _offer_label: Label = %OfferLabel
@onready var _status_label: Label = %StatusLabel
@onready var _crystal_label: Label = %CrystalLabel
@onready var _stats_label: Label = %StatsLabel

var _controller: CoreEvolutionController
var _state: CoreState
var _crystal: AbyssalCrystalState

## §38/§42: depois do MVP o painel congela na celebração. A Essence continua sendo
## gerada e continua emitindo essence_changed; sem esta trava a linha de oferta
## voltaria a aparecer em uma partida que já evoluiu.
var _completed := false

const LOCKED_STATUS := "Sobreviva à primeira invasão."
const INSUFFICIENT_STATUS := "Essência insuficiente"
const CRYSTAL_STATUS := "Cristal Abissal necessário"
const READY_STATUS := "Pronto para evoluir"
const MVP_LINE := "MVP CONCLUÍDO"
## Rótulo de reserva para quando o painel é montado sem Definition de Cristal (harness
## isolado). Em produção a linha lê o `display_name` do próprio recurso.
const CRYSTAL_FALLBACK_NAME := "Cristal Abissal"


## §43: as quatro passagens são signals. `evolution_unlocked` é o retransmitido de
## `invasion_victory` (a conexão física vive no GameMain, §27), então este arquivo não
## conhece o InvasionController — nem por referência, nem por busca.
##
## §15/§49/T17: o terceiro parâmetro é o mesmo `AbyssalCrystalState` da campanha, e tem
## default nulo para não quebrar os harnesses que ligavam o painel com dois. Sem ele a
## linha do Cristal mostra 0, que é a verdade de um domínio sem conquista registrada.
func bind(
		controller: CoreEvolutionController,
		state: CoreState,
		crystal: AbyssalCrystalState = null) -> void:
	_controller = controller
	_state = state
	_crystal = crystal
	controller.evolution_unlocked.connect(_on_unlocked)
	controller.mvp_completed.connect(_on_mvp_completed)
	state.essence_changed.connect(_on_essence_changed)
	state.evolved.connect(_on_evolved)
	if crystal != null:
		# §49: o Cristal muda por signal, no instante em que a invasão o concede. Nada
		# aqui pergunta o valor por frame.
		crystal.amount_changed.connect(_on_crystal_changed)
	_show_status()


func _on_unlocked() -> void:
	_show_status()


func _on_mvp_completed() -> void:
	_completed = true
	_show_status()


func _on_crystal_changed(_current: int) -> void:
	_show_status()


## §45: a evolução troca a Definition do mesmo State, e o clamp/renovação disparam os
## signals normais de valor. Aqui isso é só mais um empurrão para redesenhar.
func _on_evolved(_old_level: int, _new_level: int) -> void:
	_show_status()


func _on_essence_changed(_current: float, _maximum: float) -> void:
	_show_status()


func _show_status() -> void:
	_level_label.text = _level_line()
	if _completed:
		_offer_label.text = MVP_LINE
		_status_label.text = ""
		_crystal_label.text = "%s restante: %d" % [_crystal_name(), _controller.crystal_count()]
		_crystal_label.visible = true
		_stats_label.text = _completed_stats()
		_stats_label.visible = true
		return
	_stats_label.visible = false
	_stats_label.text = ""
	var required := _controller.evolution_crystal_cost()
	# §44: a linha existe antes mesmo de a vitória chegar, porque a pergunta
	# "quantas chaves eu tenho?" é feita desde o primeiro minuto. Sem custo de Cristal no
	# destino não há linha — ela não mente sobre uma condição que não existe.
	_crystal_label.visible = required > 0
	if required > 0:
		_crystal_label.text = "%s: %d / %d" % [_crystal_name(), _controller.crystal_count(), required]
	if not _controller.is_unlocked():
		_offer_label.text = "Evolução: bloqueada"
		_status_label.text = LOCKED_STATUS
		return
	_offer_label.text = "[V] Evoluir para Nv.%d — %d Essência" % [
		_controller.target_level(), roundi(_controller.evolution_cost())]
	_status_label.text = _missing_requirement(required)


## §45/§46: o painel diz qual metade da conta falta, e a Essência é a primeira porque é
## ela que o jogador vem acumulando. Com a vitória no bolso e o tanque cheio, o que
## bloqueia é a chave — e é isso que aparece.
func _missing_requirement(required: int) -> String:
	if _controller.can_evolve():
		return READY_STATUS
	if _state.essence < _controller.evolution_cost():
		return INSUFFICIENT_STATUS
	if required > 0 and _controller.crystal_count() < required:
		return CRYSTAL_STATUS
	return INSUFFICIENT_STATUS


## §44/T17: o nome vem do recurso de progressão. O texto fixo só existe como reserva
## para painel sem State vinculado.
func _crystal_name() -> String:
	if _crystal != null and _crystal.definition != null \
			and not _crystal.definition.display_name.is_empty():
		return _crystal.definition.display_name
	return CRYSTAL_FALLBACK_NAME


## §40/§42: o mesmo painel usa a caixa alta só na celebração, para que a mudança de
## estado seja visível sem trocar de cena (§89).
func _level_line() -> String:
	if _completed:
		return "NÚCLEO NV.%d" % _state.level
	return "Núcleo Nv.%d" % _state.level


## §42/§47/T14: tudo vem da Definition que o State carrega agora. Se o Nv.2 mudar de
## números, esta linha muda junto — e continua sendo uma legenda, não uma tela final.
func _completed_stats() -> String:
	var definition := _state.definition
	return "Integrity: %d   Essence Capacity: %d\nGeneration: %.1f/s   Population Base: %d" % [
		roundi(definition.max_integrity),
		roundi(definition.max_essence),
		definition.essence_generation_rate,
		definition.population_capacity]
