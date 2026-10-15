class_name InvasionDebugHud
extends PanelContainer

@onready var _hint_label: Label = %HintLabel
@onready var _status_label: Label = %StatusLabel
@onready var _remaining_label: Label = %RemainingLabel
## T23: a segunda origem de invasão aparece neste mesmo painel — mesma pergunta ("o que
## está vindo?"), outra ameaça. Duas linhas: a Notoriedade e o ciclo da Incursão.
@onready var _notoriety_label: Label = %NotorietyLabel
@onready var _incursion_label: Label = %IncursionLabel

var _incursion: SurfaceIncursionController

const HINT_LINE := "[F] Iniciar primeira invasão"
## §17/T13: esperar deixou de ser esperar nada — o que se espera agora é a ameaça.
const WAITING_STATUS := "Status: aguardando ameaça"
const PREPARATION_ALERT := "AMEAÇA DETECTADA"
const PREPARATION_ADVICE := "Prepare suas defesas."
const ACTIVE_STATUS := "Status: INVASÃO"
const VICTORY_STATUS := "Status: VITÓRIA"
const DEFEAT_STATUS := "Status: DERROTA"
const NO_INVASION_YET := ""


## §40: o painel só existe por causa dos sinais do controller. Sem loop, sem
## consulta por frame, sem conhecer unidade nenhuma.
func bind(controller: InvasionController) -> void:
	controller.invasion_started.connect(_on_invasion_started)
	controller.invasion_victory.connect(_on_invasion_victory)
	controller.invasion_defeat.connect(_on_invasion_defeat)
	controller.active_invaders_changed.connect(_on_active_invaders_changed)
	controller.preparation_started.connect(_on_preparation_started)
	controller.preparation_time_changed.connect(_on_preparation_time_changed)
	_hint_label.text = HINT_LINE
	_status_label.text = WAITING_STATUS
	_remaining_label.text = NO_INVASION_YET


## §45/§77/T18: o ciclo de vida restaurado vem como dado, e §75 proíbe reemitir os sinais
## de marco para isso. Este refresh é a leitura do estado em texto — a mesma linha que os
## handlers escreveriam, só que depois de uma carga.
func refresh(controller: InvasionController) -> void:
	_hint_label.text = HINT_LINE
	match controller.invasion_state():
		InvasionController.InvasionState.PREPARATION:
			_hint_label.text = PREPARATION_ALERT
			_remaining_label.text = PREPARATION_ADVICE
			_show_countdown(controller.preparation_time_remaining())
		InvasionController.InvasionState.ACTIVE:
			_status_label.text = ACTIVE_STATUS
			_show_remaining(controller.active_invaders())
		InvasionController.InvasionState.VICTORY:
			_status_label.text = VICTORY_STATUS
			_show_remaining(0)
		InvasionController.InvasionState.DEFEAT:
			_status_label.text = DEFEAT_STATUS
			_show_remaining(0)
		_:
			_status_label.text = WAITING_STATUS
			_remaining_label.text = NO_INVASION_YET


## §17/T13: durante a preparação as três linhas do painel viram o aviso. O contador de
## inimigos não existe ainda — nada foi criado (§27/T13).
func _on_preparation_started(_duration: float) -> void:
	_hint_label.text = PREPARATION_ALERT
	_remaining_label.text = PREPARATION_ADVICE
	_show_countdown(_duration)


func _on_preparation_time_changed(remaining: float, _duration: float) -> void:
	_show_countdown(remaining)


## §11/§52/T13: ceil(remaining) — a mesma política do aviso em tela, medida em inteiros.
func _show_countdown(remaining: float) -> void:
	_status_label.text = "Invasão em: %d s" % int(ceilf(remaining))


func _on_invasion_started(invaders: Array) -> void:
	_hint_label.text = HINT_LINE
	_status_label.text = ACTIVE_STATUS
	_show_remaining(invaders.size())


func _on_active_invaders_changed(current: int) -> void:
	_show_remaining(current)


func _on_invasion_victory() -> void:
	_status_label.text = VICTORY_STATUS
	_show_remaining(0)


func _on_invasion_defeat() -> void:
	_status_label.text = DEFEAT_STATUS


func _show_remaining(current: int) -> void:
	_remaining_label.text = "Inimigos restantes: %d" % current


## T23: a Incursão da Superfície é lida dos sinais do próprio controller, sem loop.
func bind_incursion(incursion: SurfaceIncursionController) -> void:
	_incursion = incursion
	incursion.notoriety().notoriety_changed.connect(_on_notoriety_changed)
	incursion.preparation_started.connect(_on_incursion_changed_float)
	incursion.preparation_time_changed.connect(_on_incursion_time_changed)
	incursion.incursion_started.connect(_on_incursion_started)
	incursion.active_raiders_changed.connect(_on_incursion_changed_int)
	incursion.incursion_ended.connect(_on_incursion_ended)
	incursion.cooldown_time_changed.connect(_on_incursion_time_changed)
	refresh_incursion()


func refresh_incursion() -> void:
	if _incursion == null:
		return
	_notoriety_label.text = "Notoriedade: %d/%d" % [
		_incursion.notoriety().value, NotorietyState.MAXIMUM]
	match _incursion.incursion_state():
		SurfaceIncursionController.IncursionState.PREPARATION:
			_incursion_label.text = "Guilda da superfície a caminho: %d s" \
					% int(ceilf(_incursion.preparation_time_remaining()))
		SurfaceIncursionController.IncursionState.ACTIVE:
			_incursion_label.text = "INCURSÃO %d — saqueadores: %d" % [
				_incursion.incursion_number(), _incursion.active_raiders()]
		SurfaceIncursionController.IncursionState.ENDED:
			# T25: a calmaria é contada; ao fim dela a próxima guilda começa a vir.
			_incursion_label.text = \
					"Incursão %d encerrada — repelidos: %d, fugiram: %d — próxima em %d s" % [
						_incursion.incursion_number(), _incursion.repelled_count(),
						_incursion.escaped_count(), int(ceilf(_incursion.cooldown_remaining()))]
		_:
			_incursion_label.text = "Superfície: o Núcleo ainda não foi notado"


func _on_notoriety_changed(_current: int, _maximum: int) -> void:
	refresh_incursion()


func _on_incursion_changed_float(_value: float) -> void:
	refresh_incursion()


func _on_incursion_changed_int(_value: int) -> void:
	refresh_incursion()


func _on_incursion_time_changed(_remaining: float, _duration: float) -> void:
	refresh_incursion()


func _on_incursion_started(_raiders: Array) -> void:
	refresh_incursion()


func _on_incursion_ended(_repelled: int, _escaped: int) -> void:
	refresh_incursion()
