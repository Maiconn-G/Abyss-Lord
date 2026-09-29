class_name CoreDebugHud
extends PanelContainer

@onready var _title_label: Label = %TitleLabel
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
	# §44/T14: o título acompanhava a Definition estática da cena. Com evolução, o nível
	# passa a ser dado do State, então ele também entra pelo signal.
	state.evolved.connect(_on_evolved)
	refresh(state)


func _on_evolved(_old_level: int, new_level: int) -> void:
	_show_level(new_level)


func _on_integrity_changed(current: float, maximum: float) -> void:
	_show_integrity(current, maximum)


func _on_essence_changed(current: float, maximum: float) -> void:
	_show_essence(current, maximum)


func _on_population_changed(current: int, capacity: int) -> void:
	_show_population(current, capacity)


func _on_population_capacity_changed(current_population: int, new_capacity: int) -> void:
	_show_population(current_population, new_capacity)


## §77/T18: o nível é a única linha que não tem signal próprio de carga — §75 proíbe
## reemitir `evolved` para restaurar, e sem esta leitura o título ficaria preso ao nível
## da cena enquanto o resto do painel já mostra o Núcleo carregado.
func refresh(state: CoreState) -> void:
	_show_level(state.level)
	_show_integrity(state.integrity, state.definition.max_integrity)
	_show_essence(state.essence, state.definition.max_essence)
	_show_population(state.population, state.get_population_capacity())


func _show_level(level: int) -> void:
	_title_label.text = "Abyssal Core Lv. %d" % level


func _show_integrity(current: float, maximum: float) -> void:
	_integrity_label.text = _format("Integrity", current, maximum)


func _show_essence(current: float, maximum: float) -> void:
	_essence_label.text = _format("Essence", current, maximum)


func _show_population(current: int, capacity: int) -> void:
	_population_label.text = _format("Population", current, capacity)


func _format(label: String, current: float, maximum: float) -> String:
	return "%s: %d / %d" % [label, roundi(current), roundi(maximum)]
