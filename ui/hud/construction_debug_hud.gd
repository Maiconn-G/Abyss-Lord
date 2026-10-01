class_name ConstructionDebugHud
extends PanelContainer

@onready var _hint_label: Label = %HintLabel
@onready var _status_label: Label = %StatusLabel
@onready var _mine_label: Label = %MineStatusLabel
@onready var _fungal_farm_label: Label = %FungalFarmStatusLabel

var _definition: NestDefinition
var _mine_definition: MineDefinition
var _fungal_farm_definition: FungalFarmDefinition
var _controller: ConstructionController
var _stockpile: ResourceStockpileState
var _core_state: CoreState
var _nest_exists := false


func bind(
		controller: ConstructionController,
		stockpile: ResourceStockpileState,
		definition: NestDefinition,
		core_state: CoreState,
		mine_definition: MineDefinition = null,
		fungal_farm_definition: FungalFarmDefinition = null) -> void:
	_definition = definition
	_mine_definition = mine_definition
	_fungal_farm_definition = fungal_farm_definition
	_core_state = core_state
	_controller = controller
	_stockpile = stockpile
	_hint_label.text = "[B] Construir %s — %d %s" % [
		definition.display_name, definition.build_cost, definition.build_resource.display_name]
	controller.nest_built.connect(_on_nest_built)
	controller.nest_completed.connect(_on_nest_completed)
	controller.mine_built.connect(_on_mine_built)
	controller.mine_completed.connect(_on_mine_completed)
	controller.fungal_farm_built.connect(_on_fungal_farm_built)
	controller.fungal_farm_completed.connect(_on_fungal_farm_completed)
	# §107/T20/§39/T21: a porta da Mina é o nível do Núcleo, e a da Fazenda é o nível mais a
	# Mina concluída. O instante que abre a porta da Mina é a evolução; o que abre a da
	# Fazenda é a evolução ou a conclusão da Mina — os dois são signal, não consulta.
	core_state.evolved.connect(_on_core_evolved)
	# §96/T21: a linha operacional da Fazenda fala de Essência, e o saldo dela muda a cada
	# frame pela geração do Núcleo — nenhum signal de obra nem de estoque conta esse
	# instante. É `essence_changed` que avisa o painel de que a porta de energia fechou, do
	# mesmo jeito que o painel do Núcleo e o militar já escutam essa mudança.
	core_state.essence_changed.connect(_on_essence_changed)
	stockpile.resource_changed.connect(_on_resource_changed)
	refresh()


## §77/T18: um load pode chegar com o Ninho pronto, inacabado ou inexistente, e nenhum
## desses casos é um signal deste painel — `nest_built` e `nest_completed` são conquistas
## (§75). É por isso que a existência volta a ser lida do controller, e não memorizada.
##
## §36/T20/§39/T21: Mina e Fazenda usam exatamente o mesmo princípio, e é por isso que o
## painel é um só: as portas de entrada delas são condições que mudam de valor ao evoluir e
## depois de um load — nenhum signal de HUD descreve esses instantes.
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
	_refresh_fungal_farm()


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


## §39/§96/T21: a linha da Fazenda tem mais estados que as outras obras porque tem mais
## condições e uma dependência de energia que muda enquanto a obra opera. A ordem das recusas
## de construção é a mesma do controller — Núcleo, depois Mina, depois saldo — para que o
## texto nunca prometa algo que `build_fungal_farm()` recusaria.
func _refresh_fungal_farm() -> void:
	if _fungal_farm_definition == null or _core_state == null:
		_fungal_farm_label.text = ""
		return
	var farm := _controller.fungal_farm()
	if farm != null:
		if not farm.is_completed():
			_fungal_farm_label.text = "%s: em construção" % _fungal_farm_definition.display_name
			return
		_fungal_farm_label.text = _operational_text(farm)
		return
	if _core_state.level < _fungal_farm_definition.required_core_level:
		_fungal_farm_label.text = "%s: bloqueada — requer Núcleo Nv.%d" % [
			_fungal_farm_definition.display_name, _fungal_farm_definition.required_core_level]
		return
	var mine := _controller.mine()
	if mine == null or not mine.is_completed():
		_fungal_farm_label.text = "%s: bloqueada — requer Mina concluída" % (
				_fungal_farm_definition.display_name)
		return
	var amount := _stockpile.get_amount(_fungal_farm_definition.build_resource.resource_id)
	if amount < _fungal_farm_definition.build_cost:
		_fungal_farm_label.text = "%s: recursos insuficientes" % (
				_fungal_farm_definition.display_name)
		return
	_fungal_farm_label.text = "[G] %s — %d %s: pronto para construir" % [
		_fungal_farm_definition.display_name, _fungal_farm_definition.build_cost,
		_fungal_farm_definition.build_resource.display_name]


## §40/§96/T21: a Fazenda operacional tem dois textos porque produzir depende de Essência.
## Com o ciclo fechado e a energia curta, a linha diz explicitamente que ela está esperando
## Essência — é o estado que a Tarefa 21 introduz, e escondê-lo seria esconder o sistema.
func _operational_text(farm: FungalFarmRuntime) -> String:
	var definition := _fungal_farm_definition
	var base := "%s: operacional — +%d %s / %d s por %d Essência" % [
		definition.display_name, definition.production_amount,
		definition.output_resource.display_name, int(definition.production_interval),
		int(definition.essence_cost_per_cycle)]
	if _core_state.essence < definition.essence_cost_per_cycle:
		return "%s (aguardando Essência)" % base
	return base


func _on_core_evolved(_old_level: int, _new_level: int) -> void:
	_refresh_mine()
	_refresh_fungal_farm()


## §96/T21: só a Fazenda consome Essência, então a mudança de saldo reavalia a linha dela.
## A Mina e o Ninho não dependem de energia e continuam intocados.
func _on_essence_changed(_current: float, _maximum: float) -> void:
	_refresh_fungal_farm()


func _on_resource_changed(
		resource_definition: ResourceDefinition, new_amount: int) -> void:
	if resource_definition == _definition.build_resource:
		if not _nest_exists:
			_show_availability(new_amount)
		# §39/T21: o Minério de Ferro é o mesmo custo do Ninho, da Mina e da Fazenda.
		if _mine_definition != null and _controller.mine() == null:
			_refresh_mine()
		if _fungal_farm_definition != null and _controller.fungal_farm() == null:
			_refresh_fungal_farm()
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


## §36/T20/§39/T21: os textos de Mina e Fazenda também vêm de signal de conquista, e o
## `refresh()` acima continua sendo o que realinha o painel depois de um load. A conclusão da
## Mina é, ao mesmo tempo, a conquista dela e a porta da Fazenda — por isso o handler reavalia
## as duas linhas em uma passada só.
func _on_mine_built(_mine: MineRuntime) -> void:
	_refresh_mine()


func _on_mine_completed(_mine: MineRuntime) -> void:
	_refresh_mine()
	_refresh_fungal_farm()


func _on_fungal_farm_built(_fungal_farm: FungalFarmRuntime) -> void:
	_refresh_fungal_farm()


func _on_fungal_farm_completed(_fungal_farm: FungalFarmRuntime) -> void:
	_refresh_fungal_farm()
