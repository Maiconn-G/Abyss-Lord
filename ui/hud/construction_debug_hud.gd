class_name ConstructionDebugHud
extends PanelContainer

@onready var _hint_label: Label = %HintLabel
@onready var _status_label: Label = %StatusLabel
@onready var _mine_label: Label = %MineStatusLabel

var _definition: NestDefinition
var _mine_definition: MineDefinition
var _controller: ConstructionController
var _stockpile: ResourceStockpileState
var _core_state: CoreState
var _nest_exists := false


func bind(
		controller: ConstructionController,
		stockpile: ResourceStockpileState,
		definition: NestDefinition,
		core_state: CoreState,
		mine_definition: MineDefinition = null) -> void:
	_definition = definition
	_mine_definition = mine_definition
	_core_state = core_state
	_controller = controller
	_stockpile = stockpile
	_hint_label.text = "[B] Construir %s — %d %s" % [
		definition.display_name, definition.build_cost, definition.build_resource.display_name]
	controller.nest_built.connect(_on_nest_built)
	controller.nest_completed.connect(_on_nest_completed)
	controller.mine_built.connect(_on_mine_built)
	controller.mine_completed.connect(_on_mine_completed)
	# §107/T20: a porta da Mina é o nível do Núcleo. A evolução é o único instante em que
	# ela abre sem que a obra seja construída, e é signal — o painel escuta, não consulta.
	core_state.evolved.connect(_on_core_evolved)
	stockpile.resource_changed.connect(_on_resource_changed)
	refresh()


## §77/T18: um load pode chegar com o Ninho pronto, inacabado ou inexistente, e nenhum
## desses casos é um signal deste painel — `nest_built` e `nest_completed` são conquistas
## (§75). É por isso que a existência volta a ser lida do controller, e não memorizada.
##
## §36/T20: a Mina usa exatamente o mesmo princípio, e é por isso que o painel é um só: a
## porta de entrada dela é a condição do Núcleo, que muda de valor ao evoluir e depois de
## um load — nenhum signal de HUD descreve esse instante.
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
	_refresh_mine()


func _refresh_mine() -> void:
	if _mine_definition == null or _core_state == null:
		_mine_label.text = ""
		return
	var mine := _controller.mine()
	if mine != null:
		if not mine.is_completed():
			_mine_label.text = "%s: em construção" % _mine_definition.display_name
			return
		_mine_label.text = "%s: operacional — +%d %s / %d s" % [
				_mine_definition.display_name, _mine_definition.production_amount,
				_mine_definition.output_resource.display_name,
				int(_mine_definition.production_interval)]
		return
	if _core_state.level < _mine_definition.required_core_level:
		_mine_label.text = "%s: bloqueada — requer Núcleo Nv.%d" % [
			_mine_definition.display_name, _mine_definition.required_core_level]
		return
	var amount := _stockpile.get_amount(_mine_definition.build_resource.resource_id)
	if amount < _mine_definition.build_cost:
		_mine_label.text = "%s: recursos insuficientes" % _mine_definition.display_name
		return
	_mine_label.text = "[M] %s — %d %s: pronto para construir" % [
		_mine_definition.display_name, _mine_definition.build_cost,
		_mine_definition.build_resource.display_name]


func _on_core_evolved(_old_level: int, _new_level: int) -> void:
	_refresh_mine()


func _on_resource_changed(
		resource_definition: ResourceDefinition, new_amount: int) -> void:
	if resource_definition == _definition.build_resource:
		if _nest_exists:
			return
		_show_availability(new_amount)
		return
	if _mine_definition != null and resource_definition == _mine_definition.build_resource \
			and _controller.mine() == null:
		_refresh_mine()


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


## §36/T20: os dois textos da Mina também vêm de signal de conquista, e o `refresh()` acima
## continua sendo o que realinha o painel depois de um load.
func _on_mine_built(_mine: MineRuntime) -> void:
	_refresh_mine()


func _on_mine_completed(_mine: MineRuntime) -> void:
	_refresh_mine()
