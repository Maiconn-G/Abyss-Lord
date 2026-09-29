class_name ConstructionState
extends RefCounted

signal work_changed(remaining: float, total: float)
signal construction_completed

## §13/T15: todo o ciclo de uma obra — quanto falta, o que acontece quando se aplica
## trabalho, e o sinal de conclusão. Ninho e Quartel têm exatamente esta regra, e ela
## estava escrita duas vezes palavra por palavra.
##
## §17: `definition` é tipada pela base, não por `Variant`. Uma subclasse não pode
## redeclarar um campo herdado em GDScript 4.6, então quem precisa de um campo próprio
## da Definition (como o bônus populacional do Ninho) continua lendo a Definition que
## injetou, tipada no próprio controller. Este é o único ponto dinâmico da hierarquia.
var definition: ConstructionDefinition
var instance_id: String
var remaining_work: float


func _init(construction_definition: ConstructionDefinition, id: String) -> void:
	definition = construction_definition
	instance_id = id
	remaining_work = construction_definition.work_required


## Trabalho inválido não toca no estado, e trabalho além do fim da obra não emite nada:
## depois de concluir, apply_work() sai pela guarda de is_completed(). É isso que faz
## construction_completed disparar uma única vez (§14).
func apply_work(amount: float) -> void:
	if amount <= 0.0 or is_completed():
		return
	remaining_work = maxf(remaining_work - amount, 0.0)
	work_changed.emit(remaining_work, definition.work_required)
	if remaining_work <= 0.0:
		construction_completed.emit()


func is_completed() -> bool:
	return remaining_work <= 0.0


## §36/T18: "Restore não é gameplay". `apply_work(999)` simularia trabalho e, se a obra
## fechasse, dispararia `construction_completed` — que é exatamente o evento que paga o
## bônus populacional e anuncia a ameaça (§32/T18 proíbe as duas coisas). Aqui só existe
## escrita do número salvo, com a mesma regra de faixa do trabalho normal, e o sinal que
## sai é o de progresso, já com o valor carregado.
func restore_remaining_work(value: float) -> bool:
	if value < 0.0 or value > definition.work_required:
		return false
	remaining_work = value
	work_changed.emit(remaining_work, definition.work_required)
	return true
