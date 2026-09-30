class_name MineRuntime
extends ConstructionRuntime

## Tarefa 20 — §17/§23: a Mina é a terceira obra da fundação da Tarefa 15. A regra de
## construção (canteiro, trabalho, conclusão, troca de visual) é toda da base; o que só
## existe aqui é o relógio de produção e o destino do minério.
##
## §20: `_process` roda quando a Mina está operacional, e fica desligado enquanto ainda é
## canteiro. Quem liga e desliga é `_sync_production()`, chamada na montagem e na
## conclusão — não há consulta por frame ao estado da obra.
##
## §22: o saldo pertence ao ResourceStockpileState. A Mina entrega a produção; não existe
## cópia de estoque aqui.

var _stockpile: ResourceStockpileState


func setup(
		construction_definition: ConstructionDefinition,
		construction_state: ConstructionState) -> void:
	super(construction_definition, construction_state)
	state.construction_completed.connect(_sync_production)
	_sync_production()


## §22: a Mina recebe o estoque por vinculação explícita na rota da Mina, exatamente como
## o Depósito o recebe. Sem isso não há para onde produzir.
func bind_stockpile(stockpile: ResourceStockpileState) -> void:
	_stockpile = stockpile


func _process(delta: float) -> void:
	var mine := state as MineState
	var produced := mine.advance_production(delta)
	if produced <= 0:
		return
	var mine_definition := definition as MineDefinition
	_stockpile.add_resource(mine_definition.output_resource, produced)


## §16/§63: a carga escreve o relógio pelo caminho de restauração do State e reavalia o
## processo no mesmo passo. Um load não produz, mas um load de Mina pronta tem que voltar
## produzindo — é por isso que o `elapsed` restaurado entra aqui, e não por advance.
func restore_production(elapsed: float) -> bool:
	var mine := state as MineState
	if not mine.restore_production_elapsed(elapsed):
		return false
	_sync_production()
	return true


## §21: ao concluir, o visual já foi trocado pela base e `production_elapsed` continua 0 —
## o primeiro minério só aparece depois de um intervalo inteiro. Aqui entra o processo.
func _sync_production() -> void:
	set_process(is_completed())
