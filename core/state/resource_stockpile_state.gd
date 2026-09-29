class_name ResourceStockpileState
extends RefCounted

signal resource_changed(resource_definition: ResourceDefinition, new_amount: int)

var _amounts: Dictionary[StringName, int] = {}


func get_amount(resource_id: StringName) -> int:
	return _amounts.get(resource_id, 0)


func add_resource(resource_definition: ResourceDefinition, amount: int) -> void:
	if resource_definition == null or amount <= 0:
		return
	var next_amount := get_amount(resource_definition.resource_id) + amount
	_amounts[resource_definition.resource_id] = next_amount
	resource_changed.emit(resource_definition, next_amount)


func consume_resource(resource_definition: ResourceDefinition, amount: int) -> bool:
	if resource_definition == null or amount <= 0:
		return false
	var resource_id := resource_definition.resource_id
	var available := get_amount(resource_id)
	if available < amount:
		return false
	var next_amount := available - amount
	_amounts[resource_id] = next_amount
	resource_changed.emit(resource_definition, next_amount)
	return true


## §22/T18: leitura do saldo inteiro, por id semântico. O Save varre o estoque — não
## escreve "iron_ore" no serializer — e esta é a única porta de saída que não devolve o
## Dictionary interno para quem só queria ler.
func snapshot_amounts() -> Dictionary:
	return _amounts.duplicate()


## §78/T18: substituição de conteúdo para persistência. Não é `add_resource` em loop:
## somar ao saldo existente duplicaria o estoque a cada Load e emitiria um sinal por
## transação de gameplay. Aqui o que chega é o saldo final, e os sinais que saem são um
## por recurso, já com o valor que o jogador vai ver (§77/T18). Recurso com valor 0 não
## entra no estoque — é a mesma regra de `add_resource`.
func replace_contents(amounts_by_definition: Dictionary) -> void:
	_amounts.clear()
	var finalised: Array = []
	for resource_definition in amounts_by_definition:
		var definition := resource_definition as ResourceDefinition
		if definition == null:
			continue
		var stored_amount: int = amounts_by_definition[resource_definition]
		if stored_amount <= 0:
			continue
		_amounts[definition.resource_id] = stored_amount
		finalised.append([definition, stored_amount])
	for entry in finalised:
		resource_changed.emit(entry[0], entry[1])
