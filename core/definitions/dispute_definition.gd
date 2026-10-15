class_name DisputeDefinition
extends Resource

## Tarefa 27 — uma disputa entre dois Povos Nativos (GDD §51.1: "Uma disputa é uma decisão
## sem resposta certa: atender um povo quase sempre custa Legitimidade com outro").
##
## A disputa nomeia os dois lados por `people_id`, conta o que cada um quer e diz quanto pesa:
## o lado favorecido ganha `legitimacy_swing`, o outro perde o mesmo tanto. O que a disputa
## decidiu é estado e vai para o Save; nada daqui vai.

@export var dispute_id: StringName = &"hall_against_roots"
@export var display_name: String = "O Salão contra as Raízes"
@export_multiline var summary: String = ""
@export var first_people_id: StringName = &"decapitated_guard"
@export var first_side_text: String = ""
@export var second_people_id: StringName = &"grey_elves"
@export var second_side_text: String = ""
@export var legitimacy_swing: int = 15
