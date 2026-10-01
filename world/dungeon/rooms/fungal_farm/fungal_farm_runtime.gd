class_name FungalFarmRuntime
extends ConstructionRuntime

## Tarefa 21 — §20/§21/§22: a Fazenda Fúngica é a quarta obra da fundação da Tarefa 15. A
## regra de construção (canteiro, trabalho, conclusão, troca de visual) é toda da base; o
## que só existe aqui é o relógio de produção **com porta de energia** e o destino da
## Biomassa.
##
## §22: o Runtime é o único ponto do sistema que conhece os dois mundos ao mesmo tempo — o
## estoque (para onde a Biomassa vai) e o Núcleo (de onde a Essência sai). Por isso os dois
## chegam por vinculação explícita na rota da Fazenda, e não por busca na árvore. O State
## continua puro: ele recebe o número de ciclos pagáveis, não o CoreState.
##
## §20: `_process` roda quando a Fazenda está operacional, e fica desligado enquanto ainda é
## canteiro. Quem liga e desliga é `_sync_production()`, chamada na montagem e na conclusão.
##
## §23: o saldo de Biomassa pertence ao ResourceStockpileState, o mesmo do Minério. Não há
## segunda pilha nem cópia de estoque aqui.

var _stockpile: ResourceStockpileState
var _core_state: CoreState


func setup(
		construction_definition: ConstructionDefinition,
		construction_state: ConstructionState) -> void:
	super(construction_definition, construction_state)
	state.construction_completed.connect(_sync_production)
	_sync_production()


## §22: estoque e Núcleo por vinculação explícita, exatamente como a Mina recebe o estoque.
## Sem o estoque não há para onde produzir; sem o Núcleo não há de onde pagar.
func bind_stockpile(stockpile: ResourceStockpileState) -> void:
	_stockpile = stockpile


## §15/§22: o CoreState é vinculado, mas nunca consultado pelo State — só por este Runtime.
func bind_core_state(core_state: CoreState) -> void:
	_core_state = core_state


## §15/§16/§17: a ponte entre a energia do Núcleo e o relógio puro do State. O Runtime mede
## quantos ciclos a Essência cobre, entrega esse número ao State e, se algum ciclo fechou,
## cobra a Essência e entrega a Biomassa. Nada aqui é por frame: é a mesma chamada, uma vez
## por `_process`, com a conta resolvida antes de qualquer escrita.
func _process(delta: float) -> void:
	if _stockpile == null or _core_state == null:
		return
	var farm := state as FungalFarmState
	var farm_definition := definition as FungalFarmDefinition
	var affordable := _affordable_cycles(farm, farm_definition)
	var produced := farm.advance_production(delta, affordable)
	if produced <= 0:
		return
	var cycles := produced / farm_definition.production_amount
	# §15: a Essência só é gasta pelos ciclos que realmente produziram. `consume_essence`
	# é atômico e a conta já foi feita contra o saldo atual, então ele não recusa aqui.
	_core_state.consume_essence(farm_definition.essence_cost_per_cycle * float(cycles))
	_stockpile.add_resource(farm_definition.output_resource, produced)


## §16: quantos ciclos a Essência atual cobre. Um ciclo pronto e parado (elapsed == interval)
## já conta como um ciclo pagável, porque é justamente esse o ciclo que este avanço vai
## fechar. Sem Núcleo vinculado não há energia e a resposta é zero.
func _affordable_cycles(
		farm: FungalFarmState, farm_definition: FungalFarmDefinition) -> int:
	if _core_state == null:
		return 0
	var cost := farm_definition.essence_cost_per_cycle
	if cost <= 0.0:
		# Uma Definition sem custo é uma Fazenda sem porta de energia: tudo passa.
		return 1
	return int(floorf(_core_state.essence / cost))


## §19/§24: a carga escreve o relógio pelo caminho de restauração do State e reavalia o
## processo no mesmo passo. Um load não produz, mas um load de Fazenda pronta tem que voltar
## produzindo — é por isso que o `elapsed` restaurado entra aqui, e não por advance.
func restore_production(elapsed: float) -> bool:
	var farm := state as FungalFarmState
	if not farm.restore_production_elapsed(elapsed):
		return false
	_sync_production()
	return true


## §21: ao concluir, o visual já foi trocado pela base e `production_elapsed` continua 0 —
## a primeira Biomassa só aparece depois de um intervalo inteiro. Aqui entra o processo.
func _sync_production() -> void:
	set_process(is_completed())
