class_name BarracksDefinition
extends ConstructionDefinition

## §11/T15: mesma base de obra do Ninho. O que é próprio do Quartel é a identidade,
## o rótulo e a Definition da unidade que ele destrava — não um efeito genérico.
@export var barracks_type_id: StringName = &"abyss_barracks"
@export var display_name: String = "Quartel Abissal"
@export var soldier_definition: SoldierDefinition


## §68: o padrão de trabalho do Quartel sempre foi 6.0, e a base compartilha o do Ninho
## (4.0). O valor real de partida vem do abyss_barracks.tres; isto só preserva o padrão
## da classe quando alguém cria um BarracksDefinition sem Resource.
func _init() -> void:
	work_required = 6.0
