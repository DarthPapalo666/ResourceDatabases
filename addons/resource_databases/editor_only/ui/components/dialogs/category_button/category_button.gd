@tool
extends PanelContainer

signal clicked(category_name: StringName, added: bool)

var _category: StringName
var _for_adding: bool

@export var _button: Button
@export var _texture_rect: TextureRect

var _correctly_initialized := false


func setup_category_button(pcategory: StringName, pfor_adding: bool) -> void:
	_button.text = pcategory + "      "
	_category = pcategory
	_for_adding = pfor_adding
	if _for_adding:
		_texture_rect.texture = preload("uid://pitjyqj7brld")
		_button.add_theme_color_override(&"font_hover_color", Color.LIGHT_GREEN)
	else:
		_texture_rect.texture = preload("uid://be0kkccg6cvjd")
		_button.add_theme_color_override(&"font_hover_color", Color.LIGHT_CORAL)
	_correctly_initialized = true


func _ready() -> void:
	assert(_correctly_initialized)
	_button.pressed.connect(_on_button_pressed)


func _on_button_pressed() -> void:
	clicked.emit(_category, _for_adding)
