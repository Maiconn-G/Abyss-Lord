class_name WorkerInvocationDebugHud
extends PanelContainer

@onready var _hint_label: Label = %HintLabel
@onready var _status_label: Label = %StatusLabel

var _core_state: CoreState
var _definition: WorkerDefinition
var _invoked := false


func bind(
		controller: WorkerInvocationController,
		core_state: CoreState,
		definition: WorkerDefinition) -> void:
	_core_state = core_state
	_definition = definition
	_hint_label.text = "[I] Invocar %s — %d Essência" % [
		definition.display_name, roundi(definition.summon_essence_cost)]
	controller.worker_summoned.connect(_on_worker_summoned)
	core_state.essence_changed.connect(_on_core_changed)
	core_state.population_changed.connect(_on_core_changed)
	core_state.population_capacity_changed.connect(_on_core_changed)
	_show_status()


func _on_core_changed(_value_a, _value_b) -> void:
	_show_status()


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
