class_name SelectionBox
extends Control

@export var fill_color := Color(0.45, 0.9, 0.55, 0.12)
@export var border_color := Color(0.45, 0.9, 0.55, 0.9)
@export var border_width := 1.0

var _origin := Vector2.ZERO
var _current := Vector2.ZERO


func _ready() -> void:
	hide()


func begin_drag(screen_origin: Vector2) -> void:
	_origin = screen_origin
	_current = screen_origin
	show()
	queue_redraw()


func update_drag(screen_position: Vector2) -> void:
	_current = screen_position
	queue_redraw()


func end_drag() -> void:
	hide()


func selection_rect() -> Rect2:
	return Rect2(_origin, _current - _origin).abs()


func _draw() -> void:
	var rect := selection_rect()
	draw_rect(rect, fill_color, true)
	draw_rect(rect, border_color, false, border_width)
