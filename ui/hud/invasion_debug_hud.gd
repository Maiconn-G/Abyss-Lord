class_name InvasionDebugHud
extends PanelContainer

@onready var _hint_label: Label = %HintLabel
@onready var _status_label: Label = %StatusLabel
@onready var _remaining_label: Label = %RemainingLabel

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
