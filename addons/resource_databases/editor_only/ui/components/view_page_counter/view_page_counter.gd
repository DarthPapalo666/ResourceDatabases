@tool
extends PanelContainer

signal change_page_requested(change: int)

@export var counter_label: Label
@export var left_button: Button
@export var right_button: Button


func set_page(current_page: int, max_page: int) -> void:
	counter_label.text = str(current_page)
	left_button.disabled = current_page <= 1
	right_button.disabled = current_page >= max_page


func _on_page_left_button_pressed() -> void:
	change_page_requested.emit(-1)


func _on_page_right_button_pressed() -> void:
	change_page_requested.emit(+1)
