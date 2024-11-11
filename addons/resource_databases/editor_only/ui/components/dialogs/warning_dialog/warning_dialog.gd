@tool
extends Window

signal decision(accepted: bool)

@export var warning_text: RichTextLabel


func make_warning(ntitle: String, text: String) -> void:
	title = ntitle
	warning_text.text = "[center]%s" % text
	popup()


func _on_accept_button_pressed() -> void:
	hide()
	decision.emit(true)


func _on_cancel_button_pressed() -> void:
	hide()
	decision.emit(false)


func _on_about_to_popup() -> void:
	# Forces the window to adopt the minimum size
	size = Vector2i.ZERO
