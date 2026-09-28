class_name NestDefinition
extends ConstructionDefinition

## §10/T15: custo de obra, recurso e trabalho agora vêm da ConstructionDefinition.
## Só ficam aqui os campos que descrevem o que o Ninho é: identidade, rótulo e o
## efeito populacional, que §25 proíbe generalizar.
@export var nest_type_id: StringName = &"abyss_nest"
@export var display_name: String = "Ninho Abissal"
@export var population_capacity_bonus: int = 4
