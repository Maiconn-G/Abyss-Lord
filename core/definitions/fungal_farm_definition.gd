class_name FungalFarmDefinition
extends ConstructionDefinition

## Tarefa 21 — §6/§10: a segunda obra exclusiva do Núcleo Nv.2 e a primeira com custo
## recorrente de energia. Os três campos de obra (recurso, custo e trabalho) continuam
## herdados da ConstructionDefinition; aqui vive o que descreve a Fazenda como produtora
## orgânica: identidade, rótulo, a exigência de nível, o par (montante, intervalo) do
## rendimento e o preço em Essência que cada ciclo cobra.
##
## §11: a porta de entrada da Fazenda não é só o nível do Núcleo — ela exige a Mina
## concluída. Esse acoplamento é de progressão, não de construção, e por isso é o
## ConstructionController que o aplica; a Definition apenas declara a identidade.
##
## §49: intervalo, montante, recurso produzido e custo de Essência são configuração, não
## estado. O Save grava apenas o relógio da obra; quem diz "1 Biomassa a cada 8 s por 4 de
## Essência" é esta Resource.

@export var farm_type_id: StringName = &"fungal_farm"
@export var display_name: String = "Fazenda Fúngica"
@export var required_core_level: int = 2
@export var output_resource: ResourceDefinition
@export var production_amount: int = 1
@export var production_interval: float = 8.0
@export var essence_cost_per_cycle: float = 4.0
