class_name BarracksState
extends ConstructionState

## §16/T15: mesmo formato do Ninho — `BarracksState.new(definition, id)` e `barracks_id`
## seguem funcionando para quem já consumia a classe; a regra de trabalho é a da base.
var barracks_id: String:
	get:
		return instance_id


func _init(barracks_definition: BarracksDefinition, id: String) -> void:
	super(barracks_definition, id)
