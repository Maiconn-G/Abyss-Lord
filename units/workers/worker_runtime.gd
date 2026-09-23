class_name WorkerRuntime
extends CharacterBody3D

var definition: WorkerDefinition
var state: WorkerState


func setup(worker_definition: WorkerDefinition, worker_state: WorkerState) -> void:
	definition = worker_definition
	state = worker_state
