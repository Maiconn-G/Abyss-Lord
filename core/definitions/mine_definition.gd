class_name MineDefinition
extends ConstructionDefinition

## Tarefa 20 — §8: a primeira obra exclusiva do Núcleo Nv.2. Os três campos de obra
## (recurso, custo e trabalho) continuam herdados da ConstructionDefinition; aqui só vive
## o que descreve a Mina como produtora: identidade, rótulo, a exigência de nível e o
## par (montante, intervalo) do rendimento.
##
## §49: o intervalo e o montante são configuração, não estado. O Save grava apenas o
## relógio da obra; quem diz "1 minério a cada 10 s" é esta Resource.

@export var mine_type_id: StringName = &"abyss_mine"
@export var display_name: String = "Mina Abissal"
@export var required_core_level: int = 2
@export var output_resource: ResourceDefinition
@export var production_amount: int = 1
@export var production_interval: float = 10.0
