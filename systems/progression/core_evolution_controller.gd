class_name CoreEvolutionController
extends Node

## Tarefa 14 — o único degrau de progressão que existe até aqui. O controller sabe três
## coisas: se a vitória já liberou a evolução, se a conta fecha, e como aplicar a
## transação. Ele não inventa Núcleo novo, não varre a árvore, não roda por frame e não
## conhece árvore de upgrades: quem muda de forma é o CoreState, e quem cresce é o
## CoreRuntime.
##
## Tarefa 17 — a conta passou a ter duas metades. A Essência paga a energia e o Cristal
## Abissal prova a conquista; o controller conhece o mesmo `AbyssalCrystalState` da
## campanha por injeção (§29), lê o preço na Definition de destino (§27) e cobra as duas
## juntas ou nenhuma (§37/§40).
##
## §88: `mvp_completed` é um estado anunciado, não um fim de partida — nada aqui pausa,
## fecha, troca cena ou credita coisa alguma (§89). O mundo continua rodando.

signal evolution_unlocked
signal mvp_completed

var _core: CoreRuntime
var _state: CoreState
var _target_definition: CoreDefinition
var _crystal: AbyssalCrystalState
var _unlocked := false


## §27: as três dependências chegam prontas pela composition root. Nenhum get_node
## perdido, nenhum grupo consultado, nenhum autoload.
func setup(core: CoreRuntime, state: CoreState, target_definition: CoreDefinition) -> void:
	_core = core
	_state = state
	_target_definition = target_definition


## §29/§30/T17: o Cristal entra por passagem explícita, e não por parâmetro novo de
## `setup`, porque dezenas de harnesses da Tarefa 14 chamam `setup` com três argumentos e
## a regra antiga que eles testam continua válida. Sem este bind o controller simplesmente
## não tem chave nenhuma: `can_evolve` fecha para todo destino que exija Cristal (§33),
## que é exatamente o comportamento pedido, em vez de um estado de cristal inventado aqui.
func bind_abyssal_crystal_state(crystal: AbyssalCrystalState) -> void:
	_crystal = crystal


## §15/T17: a leitura que o HUD usa para mostrar "0 / 1" sem ter um State próprio.
func abyssal_crystal_state() -> AbyssalCrystalState:
	return _crystal


func is_unlocked() -> bool:
	return _unlocked


## §32/§75: o preço é um dado da Definition de destino. Não existe 25 escrito aqui — se
## o Nv.2 passar a custar outro número, o controller e o HUD passam a mostrar o novo.
func evolution_cost() -> float:
	if _target_definition == null:
		return 0.0
	return _target_definition.evolution_essence_cost


## §24/§27/T17: a mesma regra para o Cristal. O valor mora no destino, e este arquivo não
## escreve `1` em lugar nenhum — se o Nv.2 passar a exigir duas chaves, o preço, a
## validação e o HUD acompanham o dado.
func evolution_crystal_cost() -> int:
	if _target_definition == null:
		return 0
	return _target_definition.evolution_crystal_cost


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


## §53/T18: o degrau já fechado é uma leitura derivada do CoreState, não uma flag copiada
## do arquivo. Se o Nível do Núcleo no Save já é o do destino, a campanha passou pelo MVP
## — e só isso o painel precisa saber.
func is_at_target_level() -> bool:
	if _state == null or _target_definition == null:
		return false
	return _state.level >= _target_definition.level


## §53/§20/§54/T18: o estado do controller volta por derivação, como o próprio §53 pede.
## A vitória liberta a chave; o Nv.2 no CoreState diz que a transação já aconteceu. Nada
## aqui cobra Essência, gasta Cristal ou emite `mvp_completed` — os dois primeiros são
## custo e o terceiro é conquista, e reexecutar qualquer um num load seria reproduzir a
## história em vez de restaurar o estado. `evolution_unlocked` também não é reemitido: o
## painel é atualizado pela passagem de refresh do controller de persistência, e uma carga
## não é o instante em que a conquista aconteceu.
func restore_progression(victory_achieved: bool) -> bool:
	if _state == null:
		return false
	_unlocked = victory_achieved or is_at_target_level()
	return true


## §35/§38: esta é a pré-validação inteira. Tudo o que pode falhar falha aqui, antes de
## qualquer consumo, então o caminho abaixo do `if not can_evolve()` não tem como
## cobrar e não evoluir (§36). As três condições são independentes e somadas: a vitória
## destrava, a Essência paga, o Cristal prova (§31).
func can_evolve() -> bool:
	if not _unlocked or _core == null or _state == null or _target_definition == null:
		return false
	if not _state.can_evolve_to(_target_definition):
		return false
	if _state.essence < evolution_cost():
		return false
	return has_crystal_for_evolution()


## §33/§34: o Cristal é a segunda metade da conta, e a forma de olhar para ele é
## perguntar ao mesmo State que a invasão escreve. Sem State vinculado o contador é 0,
## então um destino que exija chave jamais evolui com o controller desatado — que é o
## comportamento correto, não uma tolerância.
func has_crystal_for_evolution() -> bool:
	var required := evolution_crystal_cost()
	if required <= 0:
		return true
	return _crystal != null and _crystal.has(required)


## §45/T17: leitura para o HUD mostrar "0 / 1". Sem State vinculado não existe chave
## nenhuma no domínio, e 0 é a resposta honesta.
func crystal_count() -> int:
	return _crystal.amount if _crystal != null else 0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("evolve_core"):
		# §30/§31/§38: fora da janela certa a tecla simplesmente não faz nada.
		try_evolve()


## §14/§34: cobra, e só depois entrega a Definition nova ao Runtime. A Essence que
## sobrou é a que continua no tanque — nada aqui reaplica o starting_essence do Nv.2.
##
## §37/§40/T17: pagar Essência e Cristal é uma transação só. Os dois consumos acontecem
## depois de `can_evolve` já ter provado os dois saldos, e se ainda assim o destino
## recusar a transição, as duas metades voltam juntas — nunca existe um instante em que o
## jogador pagou uma e ficou com a outra.
func try_evolve() -> bool:
	if not can_evolve():
		return false
	var old_level := _state.level
	var essence_cost := evolution_cost()
	var crystal_cost := evolution_crystal_cost()
	var essence_before := _state.essence
	var crystal_before := crystal_count()
	_state.consume_essence(essence_cost)
	if crystal_cost > 0:
		_crystal.consume(crystal_cost)
	if not _core.evolve_to(_target_definition):
		_state.add_essence(essence_before - _state.essence)
		if crystal_before > crystal_count():
			_crystal.add(crystal_before - crystal_count())
		return false
	if _state.level > old_level:
		mvp_completed.emit()
	return true
