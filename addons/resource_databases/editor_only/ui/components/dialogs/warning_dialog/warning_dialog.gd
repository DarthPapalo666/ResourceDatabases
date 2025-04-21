@tool
extends Window

signal accepted(yes_or_no: bool)

@export var _warning_text: RichTextLabel

@onready var _accept_button: Button = $PanelContainer/VBoxContainer/HBoxContainer/AcceptButton
@onready var _cancel_button: Button = $PanelContainer/VBoxContainer/HBoxContainer/CancelButton


func _ready() -> void:
	about_to_popup.connect(_on_about_to_popup)
	close_requested.connect(_on_cancel_button_pressed)
	
	_accept_button.pressed.connect(_on_accept_button_pressed)
	_cancel_button.pressed.connect(_on_cancel_button_pressed)


func make_warning(ntitle: String, text: String) -> Signal:
	title = ntitle
	_warning_text.text = "[center]%s" % text
	popup()
	return accepted


func _on_accept_button_pressed() -> void:
	hide()
	accepted.emit(true)


func _on_cancel_button_pressed() -> void:
	hide()
	accepted.emit(false)


func _on_about_to_popup() -> void:
	# Forces the window to adopt the minimum size
	size = Vector2i.ZERO
