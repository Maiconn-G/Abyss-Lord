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
## T27: a identidade da obra do selo. Cada povo tem o seu.
@export var seal_instance_id: String = "ancient_seal_001"
## A Legitimidade com que o povo recebe o Regente no instante da descoberta.
@export var starting_legitimacy: int = 25
## Os pedidos, em ordem. Um de cada vez; cada um uma única vez.
@export var requests: Array[NativeRequestDefinition] = []
## T27: a ação do InputMap que entrega o pedido atual deste povo, e a letra que o painel mostra.
## Cada povo tem a sua tecla.
@export var request_action: StringName = &"fulfill_native_request"
@export var request_key_label: String = "J"
## Os atos que a Guarda observa (GDD §51.1).
@export var legitimacy_per_raider_slain: int = 5
@export var legitimacy_per_raider_fled: int = 10
@export var legitimacy_per_guardian_fallen: int = 10
## Ao alcançar esta Legitimidade o povo presta juramento (faixa "leal").
@export var oath_threshold: int = 61
## O corpo do Guardião que o juramento entrega. É um Soldado: o jogador o comanda pelo
## mesmo caminho e ele combate pelo mesmo caminho.
@export var guardian_definition: SoldierDefinition
## T27: o juramento pode entregar outra coisa além de um Guardião — os Elfos abrem as galerias
## das Raízes aos servos do domínio (capacidade populacional). Zero = nenhum bônus.
@export var oath_population_bonus: int = 0
## T27: os textos do painel que dependem do povo (gênero, número, o que o juramento entrega).
@export var discovered_text: String = "Guarda Decapitada encontrada"
@export var requests_done_text: String = "Todos os pedidos da Guarda foram cumpridos"
@export var oath_effect_text: String = ""
