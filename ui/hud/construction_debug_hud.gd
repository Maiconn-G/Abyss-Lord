class_name ConstructionDebugHud
extends PanelContainer

@onready var _hint_label: Label = %HintLabel
@onready var _status_label: Label = %StatusLabel

var _definition: NestDefinition
var _controller: ConstructionController
var _stockpile: ResourceStockpileState
var _nest_exists := false


func bind(
		controller: ConstructionController,
		stockpile: ResourceStockpileState,
		definition: NestDefinition) -> void:
	_definition = definition
	_controller = controller
	_stockpile = stockpile
	_hint_label.text = "[B] Construir %s — %d %s" % [
		definition.display_name, definition.build_cost, definition.build_resource.display_name]
	controller.nest_built.connect(_on_nest_built)
	controller.nest_completed.connect(_on_nest_completed)
	stockpile.resource_changed.connect(_on_resource_changed)
	refresh()


## §77/T18: um load pode chegar com o Ninho pronto, inacabado ou inexistente, e nenhum
## desses casos é um signal deste painel — `nest_built` e `nest_completed` são conquistas
## (§75). É por isso que a existência volta a ser lida do controller, e não memorizada.
func refresh() -> void:
	if _controller == null or _stockpile == null:
		return
	var nest := _controller.nest()
	_nest_exists = nest != null
	if nest == null:
		_show_availability(_stockpile.get_amount(_definition.build_resource.resource_id))
	elif nest.is_completed():
		_status_label.text = "%s: concluído" % _definition.display_name
	else:
		_status_label.text = "%s: em construção" % _definition.display_name


func _on_resource_changed(
		resource_definition: ResourceDefinition, new_amount: int) -> void:
	if _nest_exists or resource_definition != _definition.build_resource:
		return
	_show_availability(new_amount)


func _show_availability(amount: int) -> void:
	if amount >= _definition.build_cost:
		_status_label.text = "%s: pronto para construir" % _definition.display_name
	else:
		_status_label.text = "%s: recursos insuficientes" % _definition.display_name


func _on_nest_built(_nest: NestRuntime) -> void:
	_nest_exists = true
	_status_label.text = "%s: em construção" % _definition.display_name


func _on_nest_completed(_nest: NestRuntime) -> void:
	_status_label.text = "%s: concluído" % _definition.display_name
