@tool
extends PanelContainer

signal change_page_requested(change: int)

@export var _counter_label: Label
@export var _page_left_button: Button
@export var _page_right_button: Button


func setup_view_page_counter(current_page: int, max_page: int) -> void:
	_counter_label.text = str(current_page)
	_page_left_button.disabled = current_page <= 1
	_page_right_button.disabled = current_page >= max_page


func _ready() -> void:
	_page_left_button.pressed.connect(change_page_requested.emit.bind(-1))
	_page_right_button.pressed.connect(change_page_requested.emit.bind(+1))
