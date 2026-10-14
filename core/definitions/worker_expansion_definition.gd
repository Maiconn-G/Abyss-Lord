class_name WorkerExpansionDefinition
extends Resource

## Tarefa 22 — a primeira expansão populacional por Biomassa. O corpo do terceiro
## Trabalhador é o mesmo do segundo (a WorkerDefinition `abyss_worker`); o que muda é a
## receita da invocação. Por isso esta Resource não repete vida, velocidade ou carga — ela
## descreve só a PORTA e o PREÇO: o nível do Núcleo que abre a invocação, a matéria viva que
## dá corpo ao servo e a Essência que o anima.
##
## A identidade semântica da unidade (worker_003) não mora aqui: ela é contrato do Save, e
## por isso é constante do controller e do CampaignSnapshot, como a do segundo Worker.
##
## Custo e nível são configuração, não estado. O Save nunca os grava — quem diz "3 de
## Biomassa e 10 de Essência no Nv.2" é este arquivo.

@export var display_name: String = "Trabalhador Abissal"
@export var required_core_level: int = 2
@export var biomass_resource: ResourceDefinition
@export var biomass_cost: int = 3
@export var essence_cost: float = 10.0
