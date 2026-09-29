class_name CoreRuntime
extends Node3D

## §7: raio do corpo de combate do Núcleo. É geometria do Runtime, lida da mesma
## medida da esfera visual (radius 0.8), para que o inimigo pare do lado de fora
## sem que ninguém duplique medida nenhuma.
@export var combat_radius: float = 0.8

## §23/T14: o Nv.2 é o mesmo corpo, só mais alto. O número é constante porque é
## apresentação pura, e o detalhe novo já mora na cena — escondido, esperando a evolução.
const LEVEL_2_VISUAL_SCALE := 1.25
const LEVEL_2_DETAIL_PATH := "Level2Detail"

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


## §22/T14: o Runtime não evolui nada sozinho — ele pede ao State, troca a própria
## referência de Definition se (e somente se) o State aceitou, e acende o detalhe
## visual do nível novo. Nenhuma instância nova nasce aqui: o Núcleo da partida é o
## mesmo Node3D, na mesma posição, com o mesmo State (§2/§94).
func evolve_to(new_definition: CoreDefinition) -> bool:
	if not _state.evolve_to(new_definition):
		return false
	_definition = new_definition
	scale = Vector3.ONE * LEVEL_2_VISUAL_SCALE
	var detail := get_node_or_null(LEVEL_2_DETAIL_PATH) as MeshInstance3D
	if detail != null:
		detail.visible = true
	return true


## §68/T18: a cena sempre nasce no Nv.1 e o Save pode trazer o Nv.2 — ou o contrário, se
## a campanha salva era evoluída e o arquivo carregado é anterior. Aqui só se troca a
## referência de Definition e a casca visual que dela depende: escala e detalhe. Não é
## `evolve_to`: não se cobra Essência nem Cristal para abrir um arquivo, nenhum sinal de
## evolução é emitido, e a operação é bidirecional porque apresentação não tem história.
func restore_level_view(core_definition: CoreDefinition) -> void:
	if core_definition == null:
		return
	_definition = core_definition
	var at_target := core_definition.level > 1
	scale = Vector3.ONE * LEVEL_2_VISUAL_SCALE if at_target else Vector3.ONE
	var detail := get_node_or_null(LEVEL_2_DETAIL_PATH) as MeshInstance3D
	if detail != null:
		detail.visible = at_target


## §16/T14: como a geração lê a taxa da própria referência, atualizar `_definition` é
## o único trabalho necessário para o Nv.2 passar a produzir 1.5/s.
func definition() -> CoreDefinition:
	return _definition
