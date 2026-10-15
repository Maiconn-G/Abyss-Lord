class_name NativesDebugHud
extends PanelContainer

## Tarefa 24 — o painel dos Povos Nativos. T27: um bloco de quatro linhas por povo (selo ou
## povo, Legitimidade, pedido atual, juramento) e duas linhas da disputa entre eles. Tudo é
## lido dos controllers por sinal; o painel não tem regra própria de porta, faixa ou decisão.

@onready var _people_label: Label = %PeopleLabel
@onready var _legitimacy_label: Label = %LegitimacyLabel
@onready var _request_label: Label = %RequestLabel
@onready var _oath_label: Label = %OathLabel
@onready var _second_people_label: Label = %SecondPeopleLabel
@onready var _second_legitimacy_label: Label = %SecondLegitimacyLabel
@onready var _second_request_label: Label = %SecondRequestLabel
@onready var _second_oath_label: Label = %SecondOathLabel
@onready var _dispute_label: Label = %DisputeLabel
@onready var _dispute_choice_label: Label = %DisputeChoiceLabel

var _natives: NativePeopleController
var _second: NativePeopleController
var _dispute: DisputeController
var _bound_seals: Dictionary = {}


func bind(natives: NativePeopleController, core_state: CoreState,
		stockpile: ResourceStockpileState) -> void:
	_natives = natives
	_listen_to(natives)
	stockpile.resource_changed.connect(_on_stockpile_changed)
	core_state.evolved.connect(_on_pair_changed)
	refresh()


## T27: o segundo povo usa o mesmo desenho, em linhas próprias.
func bind_second_people(people: NativePeopleController) -> void:
	_second = people
	_listen_to(people)
	refresh()


func bind_dispute(dispute: DisputeController) -> void:
	_dispute = dispute
	dispute.dispute_opened.connect(refresh)
	dispute.dispute_resolved.connect(_on_int_changed)
	refresh()


func refresh() -> void:
	if _natives == null:
		return
	_render(_natives, _people_label, _legitimacy_label, _request_label, _oath_label)
	if _second != null:
		_render(_second, _second_people_label, _second_legitimacy_label,
				_second_request_label, _second_oath_label)
	_render_dispute()


func _listen_to(people: NativePeopleController) -> void:
	people.seal_awakened.connect(_on_seal_awakened)
	people.people_discovered.connect(refresh)
	people.request_fulfilled.connect(_on_int_changed)
	people.oath_sworn.connect(_on_oath_sworn)
	people.guardian_fallen.connect(refresh)
	people.legitimacy().legitimacy_changed.connect(_on_pair_changed)


func _render(people: NativePeopleController, people_label: Label, legitimacy_label: Label,
		request_label: Label, oath_label: Label) -> void:
	_bind_seal_progress(people)
	var definition := people.definition()
	if not people.is_discovered():
		if people.seal() == null:
			people_label.text = "%s: adormecido — requer Núcleo Nv.%d" % [
				definition.seal_display_name, definition.required_core_level]
		else:
			people_label.text = "%s: desperto — rompa-o com Trabalhadores (%d%%)" % [
				definition.seal_display_name,
				roundi(100.0 * people.seal_work_done() / definition.seal_definition.work_required)]
		legitimacy_label.text = ""
		request_label.text = ""
		oath_label.text = ""
		return
	people_label.text = definition.discovered_text
	legitimacy_label.text = "Legitimidade: %d/%d (%s)" % [
		people.legitimacy().value, LegitimacyState.MAXIMUM, people.legitimacy().band_name()]
	var request := people.current_request()
	match people.request_gate():
		NativePeopleController.RequestGate.READY:
			request_label.text = "[%s] Pedido: %s — %d %s (+%d)" % [
				definition.request_key_label, request.display_name, request.amount,
				request.resource.display_name, request.legitimacy_gain]
		NativePeopleController.RequestGate.INSUFFICIENT:
			request_label.text = "Pedido: %s — %d %s (recursos insuficientes)" % [
				request.display_name, request.amount, request.resource.display_name]
		_:
			request_label.text = definition.requests_done_text
	if not people.has_sworn_oath():
		oath_label.text = "Juramento: aos %d de Legitimidade" % definition.oath_threshold
	elif definition.guardian_definition == null:
		oath_label.text = "Juramento prestado — %s" % definition.oath_effect_text
	elif people.guardian() != null:
		oath_label.text = "Juramento prestado — o Guardião Decapitado está em vigília"
	else:
		oath_label.text = "Juramento prestado — o Guardião caiu em combate"


func _render_dispute() -> void:
	if _dispute == null:
		_dispute_label.text = ""
		_dispute_choice_label.text = ""
		return
	var definition := _dispute.definition()
	match _dispute.resolution():
		DisputeController.Resolution.FIRST:
			_dispute_label.text = "%s — decidida: %s" % [definition.display_name,
				definition.first_side_text]
			_dispute_choice_label.text = ""
		DisputeController.Resolution.SECOND:
			_dispute_label.text = "%s — decidida: %s" % [definition.display_name,
				definition.second_side_text]
			_dispute_choice_label.text = ""
		_:
			if not _dispute.is_open():
				_dispute_label.text = ""
				_dispute_choice_label.text = ""
				return
			var first := _dispute.first_people().definition().display_name
			var second := _dispute.second_people().definition().display_name
			_dispute_label.text = "DISPUTA: %s\n%s" % [definition.display_name, definition.summary]
			_dispute_choice_label.text = "[O] %s (%s +%d, %s −%d)\n[P] %s (%s +%d, %s −%d)" % [
				definition.first_side_text, first, definition.legitimacy_swing, second,
				definition.legitimacy_swing, definition.second_side_text, second,
				definition.legitimacy_swing, first, definition.legitimacy_swing]


## O progresso de cada selo vem do próprio ConstructionState dele; quando o selo é trocado
## (despertar ou carga), a escuta acompanha o novo.
func _bind_seal_progress(people: NativePeopleController) -> void:
	var seal := people.seal()
	if _bound_seals.get(people) == seal:
		return
	_bound_seals[people] = seal
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
