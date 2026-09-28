class_name ConstructionDefinition
extends Resource

## §9/T15: os três campos que Ninho e Quartel declaravam campo a campo, com o mesmo
## nome, o mesmo tipo e o mesmo significado. A base existe porque já há dois tipos
## independentes de obra — não é aposta em um terceiro.
##
## §17: nada aqui é Variant. Os três campos mantêm tipagem explícita, e o recurso de
## custo continua sendo a mesma ResourceDefinition compartilhada pelo estoque.
@export var build_resource: ResourceDefinition
@export var build_cost: int = 3
@export var work_required: float = 4.0
