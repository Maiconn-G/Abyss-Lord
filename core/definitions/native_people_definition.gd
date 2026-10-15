class_name NativePeopleDefinition
extends Resource

## Tarefa 24 — um Povo Nativo do domínio herdado (GDD §51.1). A Guarda Decapitada é o
## primeiro: cavaleiros sem cabeça que juraram proteger o antigo Regente e que testam o novo
## pelo mérito em combate.
##
## Tudo que descreve o povo mora aqui — o selo que o guarda, a Legitimidade inicial, os
## pedidos em ordem, o peso de cada ato e o Guardião que o juramento entrega. O que é estado
## (selo rompido, Legitimidade atual, pedidos cumpridos, juramento, Guardião vivo) mora no
## controller e vai para o Save; nada daqui vai.

@export var people_id: StringName = &"decapitated_guard"
@export var display_name: String = "Guarda Decapitada"
## O Núcleo desperta o selo ao alcançar este nível.
@export var required_core_level: int = 2
## A obra que os Trabalhadores rompem para encontrar o povo (trabalho, sem custo).
@export var seal_definition: ConstructionDefinition
@export var seal_display_name: String = "Selo Antigo"
## A Legitimidade com que o povo recebe o Regente no instante da descoberta.
@export var starting_legitimacy: int = 25
## Os pedidos, em ordem. Um de cada vez; cada um uma única vez.
@export var requests: Array[NativeRequestDefinition] = []
## Os atos que a Guarda observa (GDD §51.1).
@export var legitimacy_per_raider_slain: int = 5
@export var legitimacy_per_raider_fled: int = 10
@export var legitimacy_per_guardian_fallen: int = 10
## Ao alcançar esta Legitimidade o povo presta juramento (faixa "leal").
@export var oath_threshold: int = 61
## O corpo do Guardião que o juramento entrega. É um Soldado: o jogador o comanda pelo
## mesmo caminho e ele combate pelo mesmo caminho.
@export var guardian_definition: SoldierDefinition
