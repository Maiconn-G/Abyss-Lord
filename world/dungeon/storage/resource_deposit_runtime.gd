class_name ResourceDepositRuntime
extends Node3D

var stockpile: ResourceStockpileState

@onready var _deposit_point: Marker3D = $DepositPoint


func setup(resource_stockpile: ResourceStockpileState) -> void:
	stockpile = resource_stockpile


func deposit(resource_definition: ResourceDefinition, amount: int) -> void:
	stockpile.add_resource(resource_definition, amount)


func deposit_point_position() -> Vector3:
	return _deposit_point.global_position
