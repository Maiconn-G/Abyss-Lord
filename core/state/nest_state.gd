class_name NestState
extends ConstructionState

## §15/T15: a classe pública do Ninho continua existindo e continua respondendo por
## `nest_id`; o que mudou é que ela não reimplementa mais a regra de obra. O id é lido
## do campo único da base — não há duas cópias do mesmo valor.
var nest_id: String:
	get:
		return instance_id


func _init(nest_definition: NestDefinition, id: String) -> void:
	super(nest_definition, id)
