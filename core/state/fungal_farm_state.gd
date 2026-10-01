class_name FungalFarmState
extends ConstructionState

## Tarefa 21 — §14/§15/§16: a Fazenda Fúngica é uma obra (a regra de trabalho é toda da
## base) e um relógio **com porta de energia**. `production_elapsed` continua sendo o único
## estado próprio, mas agora o avanço do tempo não basta: o State não decide produzir
## sozinho, ele só avança o relógio na medida em que o domínio pode pagar.
##
## §15: o State NÃO conhece o CoreState. Quem sabe quantas Essências existem é o Runtime,
## que tem o CoreState vinculado. O State recebe a resposta pronta em `affordable_cycles` —
## quantos ciclos o chamador pode pagar neste avanço — e não pergunta nada a ninguém.
##
## §16/§17: sem energia não há acúmulo infinito. O relógio **satura em um ciclo pronto**:
## se o tempo já cobriu um intervalo e a Essência não veio, o elapsed trava em
## `production_interval` e espera; não vira dois, três, quatro ciclos de dívida. Quando a
## energia chega, exatamente um ciclo fecha — a produção não "explode" com o tempo parado.

## §14: o relógio, em segundos, dentro de [0, production_interval].
var production_elapsed := 0.0

## §13: o id da Fazenda é o `instance_id` da base, lido pelo nome que o arquivo e o
## controller usam — o mesmo arranjo de Ninho, Quartel e Mina.
var farm_id: String:
	get:
		return instance_id


func _init(farm_definition: FungalFarmDefinition, id: String) -> void:
	super(farm_definition, id)


## §16/§17/§18: devolve quantos ciclos de produção o avanço fechou — e não mais que os
## ciclos que o chamador disse serem pagáveis.
##
## A conta é feita em duas etapas, e a ordem importa:
##   1) o tempo disponível é acumulado e convertido em ciclos inteiros, com o teto de
##      saturação de §17: o relógio nunca passa de `production_interval`;
##   2) os ciclos que efetivamente fecham são `min(ciclos_de_tempo, affordable_cycles)`.
##      Os que não cabem no orçamento de energia simplesmente não acontecem — o relógio
##      fica onde está, esperando, em vez de guardar dívida.
##
## §15: obra inacabada não produz e o relógio nem começa a andar.
func advance_production(delta: float, affordable_cycles: int) -> int:
	if delta <= 0.0:
		return 0
	if not is_completed():
		return 0
	var farm_definition := definition as FungalFarmDefinition
	var interval := farm_definition.production_interval
	# §17: o tempo satura em um intervalo. Acumular além disso seria prometer produção
	# que a energia não paga — e §17 é explícito: 100 s num único avanço fecham UM ciclo,
	# não doze, mesmo com energia para dois. O teto vem antes da contagem de ciclos.
	var elapsed := minf(production_elapsed + delta, interval)
	var timed_cycles := int(elapsed / interval)
	var produced := mini(timed_cycles, maxi(affordable_cycles, 0))
	if produced <= 0:
		# §17: nada fechou, mas o tempo saturado permanece no relógio.
		production_elapsed = elapsed
		return 0
	# §16: só o tempo dos ciclos que realmente fecharam é consumido; o resto continua
	# acumulado, sem nunca passar de um intervalo.
	production_elapsed = minf(elapsed - float(produced) * interval, interval)
	return produced * farm_definition.production_amount


## §19: restaurar é escrever o relógio que o arquivo guardou, com a faixa verificada contra
## a Definition. Diferente da Mina, o topo da faixa é **inclusive**: `elapsed == interval`
## é um estado legítimo de §17 — um ciclo pronto esperando Essência. `advance_production()`
## não serve aqui: ele produz, cobra e é exatamente o "gameplay falso" que a carga proíbe.
func restore_production_elapsed(value: float) -> bool:
	var farm_definition := definition as FungalFarmDefinition
	if value < 0.0 or value > farm_definition.production_interval:
		return false
	production_elapsed = value
	return true
