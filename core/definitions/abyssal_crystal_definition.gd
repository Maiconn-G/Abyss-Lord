class_name AbyssalCrystalDefinition
extends Resource

## §4/§6/T17: o Cristal Abissal é chave de progressão, não material da economia. Ele tem
## definição própria em vez de herdar `ResourceDefinition` porque o fluxo operacional
## (Rocha → Pilha → carga do Worker → Depósito → Estoque) nunca o percorre, e os campos
## que fariam parte desse fluxo — valor de mercado, peso, limite de pilha — não existem
## para uma conquista. Os dois campos abaixo são tudo o que a chave precisa ter.

@export var crystal_id: StringName = &""
@export var display_name: String = ""
