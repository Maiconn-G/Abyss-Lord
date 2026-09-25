class_name CoreDebugHud
extends PanelContainer

@onready var _integrity_label: Label = %IntegrityLabel
@onready var _essence_label: Label = %EssenceLabel
@onready var _population_label: Label = %PopulationLabel


func bind_core(state: CoreState) -> void:
	state.essence_changed.connect(_on_essence_changed)
	state.population_changed.connect(_on_population_changed)
	state.population_capacity_changed.connect(_on_population_capacity_changed)
	# §8 da invasão: a Integrity deixou de ser estática, então ela também entra pelo
	# signal em vez de uma leitura única no bind.
	state.integrity_changed.connect(_on_integrity_changed)
	_show_integrity(state.integrity, state.definition.max_integrity)
	_show_essence(state.essence, state.definition.max_essence)
	_show_population(state.population, state.get_population_capacity())


func _on_integrity_changed(current: float, maximum: float) -> void:
	_show_integrity(current, maximum)


func _on_essence_changed(current: float, maximum: float) -> void:
	_show_essence(current, maximum)


func _on_population_changed(current: int, capacity: int) -> void:
	_show_population(current, capacity)


func _on_population_capacity_changed(current_population: int, new_capacity: int) -> void:
	_show_population(current_population, new_capacity)


func _show_integrity(current: float, maximum: float) -> void:
	_integrity_label.text = _format("Integrity", current, maximum)


func _show_essence(current: float, maximum: float) -> void:
	_essence_label.text = _format("Essence", current, maximum)


func _show_population(current: int, capacity: int) -> void:
	_population_label.text = _format("Population", current, capacity)


func _format(label: String, current: float, maximum: float) -> String:
	return "%s: %d / %d" % [label, roundi(current), roundi(maximum)]
