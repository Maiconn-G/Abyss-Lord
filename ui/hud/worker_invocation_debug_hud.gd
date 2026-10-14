class_name WorkerInvocationDebugHud
extends PanelContainer

@onready var _hint_label: Label = %HintLabel
@onready var _status_label: Label = %StatusLabel
## T22: o painel de invocação é o painel da população. A expansão por Biomassa ganha duas
## linhas aqui, em vez de um HUD novo — mesma pergunta ("posso invocar?"), outra receita.
@onready var _expansion_hint_label: Label = %ExpansionHintLabel
@onready var _expansion_status_label: Label = %ExpansionStatusLabel

var _core_state: CoreState
var _definition: WorkerDefinition
var _controller: WorkerInvocationController
var _invoked := false
var _expansion: WorkerExpansionController


func bind(
		controller: WorkerInvocationController,
		core_state: CoreState,
		definition: WorkerDefinition) -> void:
	_core_state = core_state
	_definition = definition
	_controller = controller
	_hint_label.text = "[I] Invocar %s — %d Essência" % [
		definition.display_name, roundi(definition.summon_essence_cost)]
	controller.worker_summoned.connect(_on_worker_summoned)
	core_state.essence_changed.connect(_on_core_changed)
	core_state.population_changed.connect(_on_core_changed)
	core_state.population_capacity_changed.connect(_on_core_changed)
	refresh()


## §26/§77/T18: `worker_summoned` é o instante da conquista, e a carga não o reemitiu. A
## flag histórica do controller é a mesma prova que §26 pede para o jogo, então é dela que
## a linha sai — inclusive quando o Save diz que o segundo Worker nunca existiu.
func refresh() -> void:
	if _controller == null:
		return
	_invoked = _controller.worker_ever_summoned()
	_show_status()
	_show_expansion_status()


func _on_core_changed(_value_a, _value_b) -> void:
	_show_status()
	_show_expansion_status()


## T22: a linha da expansão é lida do `gate()` do próprio controller — o painel não tem regra
## de porta própria. A receita do texto vem das Definitions: nome do servo, custo em Biomassa
## (com o nome do recurso) e custo em Essência.
func bind_expansion(expansion: WorkerExpansionController, stockpile: ResourceStockpileState) -> void:
	_expansion = expansion
	var recipe := expansion.expansion_definition()
	_expansion_hint_label.text = "[U] Invocar %s — %d %s + %d Essência" % [
		recipe.display_name, recipe.biomass_cost, recipe.biomass_resource.display_name,
		roundi(recipe.essence_cost)]
	expansion.worker_expanded.connect(_on_worker_expanded)
	stockpile.resource_changed.connect(_on_stockpile_changed)
	_core_state.evolved.connect(_on_core_changed)
	_show_expansion_status()


func _on_worker_expanded(_worker: WorkerRuntime) -> void:
	_show_expansion_status()


func _on_stockpile_changed(_resource: ResourceDefinition, _amount: int) -> void:
	_show_expansion_status()


func _show_expansion_status() -> void:
	if _expansion == null:
		return
	var recipe := _expansion.expansion_definition()
	match _expansion.gate():
		WorkerExpansionController.Gate.ALREADY_SUMMONED:
			_expansion_status_label.text = "Terceiro trabalhador invocado"
		WorkerExpansionController.Gate.CORE_LEVEL:
			_expansion_status_label.text = "Terceiro trabalhador: requer Núcleo Nv.%d" \
					% recipe.required_core_level
		WorkerExpansionController.Gate.CAPACITY:
			_expansion_status_label.text = "Terceiro trabalhador: capacidade cheia"
		WorkerExpansionController.Gate.BIOMASS:
			_expansion_status_label.text = "Terceiro trabalhador: %s insuficiente" \
					% recipe.biomass_resource.display_name
		WorkerExpansionController.Gate.ESSENCE:
			_expansion_status_label.text = "Terceiro trabalhador: Essência insuficiente"
		_:
			_expansion_status_label.text = "Terceiro trabalhador: pronto"


func _on_worker_summoned(_worker: WorkerRuntime) -> void:
	_invoked = true
	_show_status()


func _show_status() -> void:
	if _invoked:
		_status_label.text = "Segundo trabalhador invocado"
	elif not _core_state.can_add_population(1):
		_status_label.text = "Capacidade cheia"
	elif _core_state.essence < _definition.summon_essence_cost:
		_status_label.text = "Essência insuficiente"
	else:
		_status_label.text = "Pronto"
