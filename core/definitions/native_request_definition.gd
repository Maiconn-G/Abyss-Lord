class_name NativeRequestDefinition
extends Resource

## Tarefa 24 — um pedido de um Povo Nativo (GDD §51.1: "cumpre pedidos e promessas"). O
## pedido é uma entrega única de recurso do estoque genérico, e cumpri-lo soma Legitimidade.
## Não é compra de Legitimidade: é o povo dizendo do que precisa, e o Regente decidindo se
## atende.

@export var request_id: StringName = &""
@export var display_name: String = ""
@export var resource: ResourceDefinition
@export var amount: int = 1
@export var legitimacy_gain: int = 10
