class_name CoreEvolutionController
extends Node

## Tarefa 14 — o único degrau de progressão que existe até aqui. O controller sabe três
## coisas: se a vitória já liberou a evolução, se a conta fecha, e como aplicar a
## transação. Ele não inventa Núcleo novo, não varre a árvore, não roda por frame e não
## conhece árvore de upgrades: quem muda de forma é o CoreState, e quem cresce é o
## CoreRuntime.
##
## §88: `mvp_completed` é um estado anunciado, não um fim de partida — nada aqui pausa,
## fecha, troca cena ou credita coisa alguma (§89). O mundo continua rodando.

signal evolution_unlocked
signal mvp_completed

var _core: CoreRuntime
var _state: CoreState
var _target_definition: CoreDefinition
var _unlocked := false


## §27: as três dependências chegam prontas pela composition root. Nenhum get_node
## perdido, nenhum grupo consultado, nenhum autoload.
func setup(core: CoreRuntime, state: CoreState, target_definition: CoreDefinition) -> void:
	_core = core
	_state = state
	_target_definition = target_definition


func is_unlocked() -> bool:
	return _unlocked


## §32/§75: o preço é um dado da Definition de destino. Não existe 25 escrito aqui — se
## o Nv.2 passar a custar outro número, o controller e o HUD passam a mostrar o novo.
func evolution_cost() -> float:
	if _target_definition == null:
		return 0.0
	return _target_definition.evolution_essence_cost


## §40/§45: o HUD anuncia o nível de destino lendo a Definition, nunca um "2" escrito na
## própria UI. Sem destino configurado não existe evolução oferecida, e o nível 0 sinaliza
## exatamente isso.
func target_level() -> int:
	if _target_definition == null:
		return 0
	return _target_definition.level


## §28/§29: a vitória chega por signal, exatamente uma vez, e só liga a chave. Repetir
## não tem efeito nenhum, e nenhum laço deste arquivo pergunta o estado da invasão.
func unlock_after_victory() -> void:
	if _unlocked:
		return
	_unlocked = true
	evolution_unlocked.emit()


## §35: esta é a pré-validação inteira. Tudo o que pode falhar falha aqui, antes de
## qualquer consumo, então o caminho abaixo do `if not can_evolve()` não tem como
## cobrar e não evoluir (§36).
func can_evolve() -> bool:
	if not _unlocked or _core == null or _state == null or _target_definition == null:
		return false
	if not _state.can_evolve_to(_target_definition):
		return false
	return _state.essence >= evolution_cost()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("evolve_core"):
		# §30/§31/§38: fora da janela certa a tecla simplesmente não faz nada.
		try_evolve()


## §14/§34: cobra, e só depois entrega a Definition nova ao Runtime. A Essence que
## sobrou é a que continua no tanque — nada aqui reaplica o starting_essence do Nv.2.
func try_evolve() -> bool:
	if not can_evolve():
		return false
	var old_level := _state.level
	_state.consume_essence(evolution_cost())
	if not _core.evolve_to(_target_definition):
		return false
	if _state.level > old_level:
		mvp_completed.emit()
	return true
