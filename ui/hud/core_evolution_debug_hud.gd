class_name CoreEvolutionDebugHud
extends PanelContainer

## Tarefa 14 — §40/§41/§42: o painel da única progressão que existe no MVP. Ele não
## decide nada: cada linha é lida do controller e do CoreState no instante em que um
## signal deles chega. Não existe `_process`, não existe consulta à invasão, não existe
## literal de nível ou de custo — `Nv.2` e `25` vêm da Definition de destino.

@onready var _level_label: Label = %LevelLabel
@onready var _offer_label: Label = %OfferLabel
@onready var _status_label: Label = %StatusLabel
@onready var _stats_label: Label = %StatsLabel

var _controller: CoreEvolutionController
var _state: CoreState

## §38/§42: depois do MVP o painel congela na celebração. A Essence continua sendo
## gerada e continua emitindo essence_changed; sem esta trava a linha de oferta
## voltaria a aparecer em uma partida que já evoluiu.
var _completed := false

const LOCKED_STATUS := "Sobreviva à primeira invasão."
const INSUFFICIENT_STATUS := "Essência insuficiente"
const READY_STATUS := "Pronto para evoluir"
const MVP_LINE := "MVP CONCLUÍDO"


## §43: as quatro passagens são signals. `evolution_unlocked` é o retransmitido de
## `invasion_victory` (a conexão física vive no GameMain, §27), então este arquivo não
## conhece o InvasionController — nem por referência, nem por busca.
func bind(controller: CoreEvolutionController, state: CoreState) -> void:
	_controller = controller
	_state = state
	controller.evolution_unlocked.connect(_on_unlocked)
	controller.mvp_completed.connect(_on_mvp_completed)
	state.essence_changed.connect(_on_essence_changed)
	state.evolved.connect(_on_evolved)
	_show_status()


func _on_unlocked() -> void:
	_show_status()


func _on_mvp_completed() -> void:
	_completed = true
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
		_stats_label.text = _completed_stats()
		_stats_label.visible = true
		return
	_stats_label.visible = false
	_stats_label.text = ""
	if not _controller.is_unlocked():
		_offer_label.text = "Evolução: bloqueada"
		_status_label.text = LOCKED_STATUS
		return
	_offer_label.text = "[V] Evoluir para Nv.%d — %d Essência" % [
		_controller.target_level(), roundi(_controller.evolution_cost())]
	_status_label.text = READY_STATUS if _controller.can_evolve() else INSUFFICIENT_STATUS


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
