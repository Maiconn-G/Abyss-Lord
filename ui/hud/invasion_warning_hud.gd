class_name InvasionWarningHud
extends PanelContainer

## §18/§19/T13: o aviso existe para não ser confundido com o debug de sempre. É UI
## simples — PanelContainer e Labels —, sem animação, VFX nem som, e cada Control da
## cena tem mouse_filter IGNORE (§21) para que a ameaça atravesse a tela sem nunca
## engolir um clique de seleção.

@onready var _title_label: Label = %TitleLabel
@onready var _countdown_label: Label = %CountdownLabel

const TITLE_LINE := "AMEAÇA DETECTADA"


## §20: visível somente durante PREPARATION. Antes do Ninho, depois do zero e durante o
## combate o painel está fora da tela, e quem manda na visibilidade é o signal.
func bind(controller: InvasionController) -> void:
	controller.preparation_started.connect(_on_preparation_started)
	controller.preparation_time_changed.connect(_on_preparation_time_changed)
	controller.invasion_started.connect(_on_invasion_started)
	refresh(controller)


## §46/§77/T18: um load em PREPARATION traz o aviso de volta com o segundo exato do
## arquivo. §75 proíbe reemitir `preparation_started` para isso, então a visibilidade e a
## linha são lidas do estado, não de um signal que já aconteceu.
func refresh(controller: InvasionController) -> void:
	var preparing := controller.invasion_state() == InvasionController.InvasionState.PREPARATION
	visible = preparing
	if not preparing:
		return
	_title_label.text = TITLE_LINE
	_show_countdown(controller.preparation_time_remaining())


func _on_preparation_started(_duration: float) -> void:
	_title_label.text = TITLE_LINE
	visible = true


## §11/§52: o número exibido é ceil(remaining). Com 42.01 s restantes o jogador lê 43,
## e o "0" só existiria no frame em que a invasão já começou — nunca fica na tela.
func _on_preparation_time_changed(remaining: float, _duration: float) -> void:
	_show_countdown(remaining)


func _show_countdown(remaining: float) -> void:
	_countdown_label.text = "INVASÃO EM %d s" % int(ceilf(remaining))


## §70: no mesmo instante da largada o aviso sai da tela para não cobrir o combate.
func _on_invasion_started(_invaders: Array) -> void:
	visible = false
