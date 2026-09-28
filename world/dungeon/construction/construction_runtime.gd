class_name ConstructionRuntime
extends StaticBody3D

## §18/T15: o corpo compartilhado de uma obra no mundo — a Definition e o State que lhe
## deram vida, os dois visuais (canteiro e pronto) e a troca entre eles. Ninho e Quartel
## tinham este arquivo digitado duas vezes, mudando só o nome dos parâmetros.
##
## §21: a lógica é comum, a aparência não. Cada cena continua com os próprios meshes, e
## nada aqui decide forma, cor ou material.
##
## §17: nem `setup()` nem `definition` precisam de parâmetro Variant — a base aceita a
## Definition e o State de qualquer subclasse, e as cenas filhas não reescrevem a assinatura.
@export var definition: ConstructionDefinition

var state: ConstructionState

@onready var _construction_visual: Node3D = $ConstructionVisual
@onready var _completed_visual: Node3D = $CompletedVisual


func setup(
		construction_definition: ConstructionDefinition,
		construction_state: ConstructionState) -> void:
	definition = construction_definition
	state = construction_state
	refresh_visual()
	state.construction_completed.connect(refresh_visual)


func is_completed() -> bool:
	return state != null and state.is_completed()


## §18: o nome antigo (`_show_progress`) era privado e duplicado nas duas classes. Aqui
## ele é o ponto único que traduz o State em visível/oculto, chamado pela própria obra
## quando o State conclui.
func refresh_visual() -> void:
	var completed := is_completed()
	_construction_visual.visible = not completed
	_completed_visual.visible = completed
