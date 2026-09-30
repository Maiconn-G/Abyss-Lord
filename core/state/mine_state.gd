class_name MineState
extends ConstructionState

## Tarefa 20 — §10/§11: a Mina é uma obra (a regra de trabalho é toda da base) e um
## relógio. `production_elapsed` é o único estado próprio, porque é a única coisa que
## sobrevive entre uma sessão e outra sem ser configuração da Definition.
##
## §23: nada aqui decide quem consome o produto, nem conta estoque, nem sabe de Worker.
## O State avança o tempo que lhe é entregue e devolve o que nasceu naquele avanço.

var production_elapsed := 0.0

## §10: o id da Mina é o `instance_id` da base, lido pelo nome que o arquivo e o
## controller usam — exatamente o mesmo arranjo de Ninho e Quartel.
var mine_id: String:
	get:
		return instance_id


func _init(mine_definition: MineDefinition, id: String) -> void:
	super(mine_definition, id)


## §12/§13: devolve quantos ciclos de produção o avanço fechou. O tempo é acumulado e
## consumido em blocos de `production_interval`, então um `delta` grande produz tantos
## minérios quanto os segundos que ele cobre — nada depende de "um frame, uma produção".
##
## §15: obra inacabada não produz, e o relógio nem começa a andar. §11 é a mesma regra
## vista pelo outro lado: enquanto há trabalho restante, o elapsed permanece em zero.
func advance_production(delta: float) -> int:
	if delta <= 0.0:
		return 0
	if not is_completed():
		return 0
	var mine_definition := definition as MineDefinition
	var elapsed := production_elapsed + delta
	var produced := int(elapsed / mine_definition.production_interval)
	if produced <= 0:
		production_elapsed = elapsed
		return 0
	production_elapsed = elapsed - float(produced) * mine_definition.production_interval
	return produced * mine_definition.production_amount


## §16: restaurar é escrever o relógio que o arquivo guardou, com a faixa verificada
## contra a Definition. `advance_production()` não serve para isso: ele produz, emite
## saldo no jogo e é exatamente o "gameplay falso" que §63 proíbe durante a carga.
func restore_production_elapsed(value: float) -> bool:
	var mine_definition := definition as MineDefinition
	if value < 0.0 or value >= mine_definition.production_interval:
		return false
	production_elapsed = value
	return true
