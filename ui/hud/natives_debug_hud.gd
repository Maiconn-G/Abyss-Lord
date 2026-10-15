class_name NativesDebugHud
extends PanelContainer

## Tarefa 24 — o painel dos Povos Nativos. Quatro linhas: o selo (ou o povo), a
## Legitimidade, o pedido atual e o juramento. Tudo é lido do NativePeopleController por
## sinal; o painel não tem regra própria de porta nem de faixa.

@onready var _people_label: Label = %PeopleLabel
@onready var _legitimacy_label: Label = %LegitimacyLabel
@onready var _request_label: Label = %RequestLabel
@onready var _oath_label: Label = %OathLabel

var _natives: NativePeopleController
var _core_state: CoreState
var _bound_seal: AncientSealRuntime


func bind(natives: NativePeopleController, core_state: CoreState,
		stockpile: ResourceStockpileState) -> void:
	_natives = natives
	_core_state = core_state
	natives.seal_awakened.connect(_on_seal_awakened)
	natives.people_discovered.connect(refresh)
	natives.request_fulfilled.connect(_on_int_changed)
	natives.oath_sworn.connect(_on_oath_sworn)
	natives.guardian_fallen.connect(refresh)
	natives.legitimacy().legitimacy_changed.connect(_on_pair_changed)
	stockpile.resource_changed.connect(_on_stockpile_changed)
	core_state.evolved.connect(_on_pair_changed)
	refresh()


func refresh() -> void:
	if _natives == null:
		return
	_bind_seal_progress()
	var people := _natives.definition()
	var seal := _natives.seal()
	if not _natives.is_discovered():
		if seal == null:
			_people_label.text = "%s: adormecido — requer Núcleo Nv.%d" % [
				people.seal_display_name, people.required_core_level]
		else:
			_people_label.text = "%s: desperto — rompa-o com Trabalhadores (%d%%)" % [
				people.seal_display_name,
				roundi(100.0 * _natives.seal_work_done() / people.seal_definition.work_required)]
		_legitimacy_label.text = ""
		_request_label.text = ""
		_oath_label.text = ""
		return
	_people_label.text = "%s encontrada" % people.display_name
	_legitimacy_label.text = "Legitimidade: %d/%d (%s)" % [
		_natives.legitimacy().value, LegitimacyState.MAXIMUM, _natives.legitimacy().band_name()]
	var request := _natives.current_request()
	match _natives.request_gate():
		NativePeopleController.RequestGate.READY:
			_request_label.text = "[J] Pedido: %s — %d %s (+%d)" % [
				request.display_name, request.amount, request.resource.display_name,
				request.legitimacy_gain]
		NativePeopleController.RequestGate.INSUFFICIENT:
			_request_label.text = "Pedido: %s — %d %s (recursos insuficientes)" % [
				request.display_name, request.amount, request.resource.display_name]
		_:
			_request_label.text = "Todos os pedidos da Guarda foram cumpridos"
	if not _natives.has_sworn_oath():
		_oath_label.text = "Juramento: aos %d de Legitimidade" % people.oath_threshold
	elif _natives.guardian() != null:
		_oath_label.text = "Juramento prestado — o Guardião Decapitado está em vigília"
	else:
		_oath_label.text = "Juramento prestado — o Guardião caiu em combate"


## O progresso do selo vem do próprio ConstructionState dele. Quando o selo é trocado
## (despertar ou carga), a escuta acompanha o novo.
func _bind_seal_progress() -> void:
	var seal := _natives.seal()
	if seal == _bound_seal:
		return
	_bound_seal = seal
	if seal != null and not seal.state.work_changed.is_connected(_on_pair_changed_float):
		seal.state.work_changed.connect(_on_pair_changed_float)


func _on_seal_awakened(_seal: AncientSealRuntime) -> void:
	refresh()


func _on_oath_sworn(_guardian: SoldierRuntime) -> void:
	refresh()


func _on_int_changed(_value: int) -> void:
	refresh()


func _on_pair_changed(_a: int, _b: int) -> void:
	refresh()


func _on_pair_changed_float(_a: float, _b: float) -> void:
	refresh()


func _on_stockpile_changed(_resource: ResourceDefinition, _amount: int) -> void:
	refresh()
