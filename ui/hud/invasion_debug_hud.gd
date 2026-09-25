class_name InvasionDebugHud
extends PanelContainer

@onready var _hint_label: Label = %HintLabel
@onready var _status_label: Label = %StatusLabel
@onready var _remaining_label: Label = %RemainingLabel

const HINT_LINE := "[F] Iniciar primeira invasão"
const WAITING_STATUS := "Status: aguardando"
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
	_hint_label.text = HINT_LINE
	_status_label.text = WAITING_STATUS
	_remaining_label.text = NO_INVASION_YET


func _on_invasion_started(invaders: Array) -> void:
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
