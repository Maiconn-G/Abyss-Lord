class_name ResourceDebugHud
extends PanelContainer

## §38/T21: o painel de recursos passou a ter dois slots — Minério de Ferro e Biomassa.
## A Tarefa 20 provou, com uma varredura de fonte, que este painel não precisava saber da
## Mina; a Tarefa 21 faz a mudança oposta e a assume: o painel agora conhece os dois
## recursos operacionais, porque são dois de verdade. Não há HUD novo, e a assinatura de um
## recurso continua válida — a Biomassa é um segundo slot opcional.

@onready var _ore_label: Label = %OreLabel
@onready var _biomass_label: Label = %BiomassLabel

var _stockpile: ResourceStockpileState
var _tracked_resource: ResourceDefinition
var _second_resource: ResourceDefinition


func bind_stockpile(
		state: ResourceStockpileState,
		resource_definition: ResourceDefinition,
		second_resource: ResourceDefinition = null) -> void:
	_stockpile = state
	_tracked_resource = resource_definition
	_second_resource = second_resource
	_ore_label.text = _format(resource_definition.display_name,
			state.get_amount(resource_definition.resource_id))
	if second_resource != null:
		_biomass_label.text = _format(second_resource.display_name,
				state.get_amount(second_resource.resource_id))
	else:
		_biomass_label.text = ""
	state.resource_changed.connect(_on_resource_changed)


func _on_resource_changed(resource_definition: ResourceDefinition, new_amount: int) -> void:
	if resource_definition == _tracked_resource:
		_ore_label.text = _format(resource_definition.display_name, new_amount)
		return
	if resource_definition == _second_resource:
		_biomass_label.text = _format(resource_definition.display_name, new_amount)


## §78/T18: `resource_changed` só fala de saldo que existe. Um load que esvazia o estoque
## não emite nada para o recurso que zerou — sem esta leitura a linha continuaria com o
## número da partida anterior. §38/T21: a leitura vale para os dois slots.
func refresh() -> void:
	if _stockpile == null or _tracked_resource == null:
		return
	_ore_label.text = _format(_tracked_resource.display_name,
			_stockpile.get_amount(_tracked_resource.resource_id))
	if _second_resource != null:
		_biomass_label.text = _format(_second_resource.display_name,
				_stockpile.get_amount(_second_resource.resource_id))


func _format(display_name: String, amount: int) -> String:
	return "%s: %d" % [display_name, amount]
