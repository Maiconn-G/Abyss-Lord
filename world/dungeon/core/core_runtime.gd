class_name CoreRuntime
extends Node3D

## §7: raio do corpo de combate do Núcleo. É geometria do Runtime, lida da mesma
## medida da esfera visual (radius 0.8), para que o inimigo pare do lado de fora
## sem que ninguém duplique medida nenhuma.
@export var combat_radius: float = 0.8

var _definition: CoreDefinition
var _state: CoreState


func _ready() -> void:
	set_process(false)


func setup(definition: CoreDefinition, state: CoreState) -> void:
	_definition = definition
	_state = state
	set_process(true)


func core_state() -> CoreState:
	return _state


## §6: o Runtime é o alvo físico do ataque; a única Integrity existente mora no
## CoreState, então aqui só existe passagem.
func receive_damage(amount: float) -> void:
	_state.damage(amount)


func _process(delta: float) -> void:
	_state.add_essence(_definition.essence_generation_rate * delta)
