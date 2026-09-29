class_name AbyssalCrystalState
extends RefCounted

## §7/§11/T17: o registro do que o domínio conquistou. É um contador inteiro, nunca um
## `has_crystal` booleano, porque a primeira versão entrega um Cristal só e os marcos
## seguintes podem entregar mais. O State é `RefCounted` e não tem `_process` (§101):
## ninguém vigia o Cristal por frame, porque ele só muda quando alguém o adiciona ou o
## consome.
##
## §3/§13: ele deliberadamente não se parece com `ResourceStockpileState`. Não existe
## Dictionary por recurso, pilha, carga nem depósito — o estoque do Cristal é do Núcleo,
## e os únicos caminhos para dentro e para fora são os dois métodos abaixo.

signal amount_changed(current: int)

var definition: AbyssalCrystalDefinition
var amount: int = 0


func _init(crystal_definition: AbyssalCrystalDefinition = null) -> void:
	definition = crystal_definition


func has(required: int = 1) -> bool:
	return amount >= required


## §9: adicionar é a única forma de o Cristal aparecer, e um valor que não é ganho não
## altera nada — nem o número, nem o sinal.
func add(amount_to_add: int) -> bool:
	if amount_to_add <= 0:
		return false
	amount += amount_to_add
	amount_changed.emit(amount)
	return true


## §10: consumo atômico. Não paga o que não existe, e por isso não existe meio consumo:
## ou sai inteiro e emite, ou não toca em nada e devolve false.
func consume(amount_to_consume: int) -> bool:
	if amount_to_consume <= 0 or amount_to_consume > amount:
		return false
	amount -= amount_to_consume
	amount_changed.emit(amount)
	return true


## §76/T18: o caminho da persistência. Não é `add`, porque o Save não concede nada — ele
## devolve um número que já foi ganho, inclusive um número menor que o atual, quando a
## partida carregada é mais antiga que a sessão. Um valor impossível (negativo) não é
## aceito e não emite sinal nenhum; o válido chega ao HUD por uma única emissão, já com
## o estado final (§77/T18).
func restore(value: int) -> bool:
	if value < 0:
		return false
	amount = value
	amount_changed.emit(amount)
	return true
