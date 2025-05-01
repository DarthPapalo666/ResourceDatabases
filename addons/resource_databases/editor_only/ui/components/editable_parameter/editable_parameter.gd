@tool
extends HBoxContainer
## Double click enables to modify de value.
## When changed, [signal change_made] is emmited with an argument holding the new value.

# Signal emmited when the parameter is changed.
signal change_made(old_value: String, new_value: String)

@export var line_edit: LineEdit
@export var confirm_button: Button

@export_group("Parameter visuals")
@export var parameter_read_box: StyleBox
@export var parameter_font: Font
@export var parameter_color: Color
@export var parameter_placeholder: String
@export var parameter_alignment: HorizontalAlignment

var _original: String # Variable used to keep track of the original value, prior to editing.

var _correctly_initialized := false


func _ready() -> void:
	assert(_correctly_initialized)
	if parameter_read_box:
		line_edit.add_theme_stylebox_override(&"read_only", parameter_read_box)
	if parameter_font:
		line_edit.add_theme_font_override(&"font", parameter_font)
	line_edit.add_theme_color_override(&"font_uneditable_color", parameter_color)
	line_edit.placeholder_text = parameter_placeholder
	line_edit.alignment = parameter_alignment
	line_edit.gui_input.connect(_on_line_edit_gui_input)
	confirm_button.pressed.connect(_on_confirm_button_pressed)


func setup_parameter(param: String) -> void:
	_original = param
	line_edit.text = param
	_correctly_initialized = true


func get_value() -> String:
	return _original


func _set_editable(editing: bool) -> void:
	line_edit.editable = editing
	line_edit.selecting_enabled = editing
	confirm_button.visible = editing


func _on_line_edit_gui_input(event: InputEvent) -> void:
	if not line_edit.editable and event is InputEventMouseButton:
		if (event as InputEventMouseButton).double_click:
			_set_editable(true)


func _input(event: InputEvent) -> void:
	if line_edit.editable and event is InputEventMouseButton:
		if not event.is_released():
			return
		if not get_global_rect().grow(16.0).has_point((event as InputEventMouseButton).global_position):
			_set_editable(false)
			line_edit.text = _original


func _on_confirm_button_pressed() -> void:
	if not line_edit.text == _original:
		change_made.emit(_original, line_edit.text)
	_set_editable(false)
	# The EditableParameter never changes it's own _original
	# It has to be set externally using setup_parameter()
	line_edit.text = _original
