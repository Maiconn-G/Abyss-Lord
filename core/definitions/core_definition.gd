class_name CoreDefinition
extends Resource

@export var level: int = 1
@export var max_integrity: float = 100.0
@export var max_essence: float = 50.0
@export var starting_essence: float = 20.0
@export var population_capacity: int = 8
@export var essence_generation_rate: float = 1.0
## §4/T14: quanto custa evoluir PARA esta Definition, e não a partir dela. O valor fica
## na Definition de destino porque é ela que diz o que vale existir como Nv.2; o
## controller lê daqui em vez de carregar um literal espalhado.
@export var evolution_essence_cost: float = 0.0
## §24/T17: mesma regra do custo de Essência, agora para o Cristal Abissal. É um `int`
## porque a chave é contada, não medida, e vive aqui em vez de um "1" solto no controller
## para que o preço continue sendo dado da Definition de destino (§27).
@export var evolution_crystal_cost: int = 0
