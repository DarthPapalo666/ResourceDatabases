@tool
extends PanelContainer

signal clicked(category_name: StringName, added: bool)

var category: StringName
var for_adding: bool

@export var _button: Button
@export var _texture_rect: TextureRect


func set_category(ncategory: StringName, nfor_adding: bool) -> void:
	_button.text = ncategory + "      "
	category = ncategory
	for_adding = nfor_adding
	if for_adding:
		_texture_rect.texture = preload("res://addons/resource_databases/editor_only/ui/icons/create_clean.svg")
		_button.add_theme_color_override(&"font_hover_color", Color.LIGHT_GREEN)
	else:
		_texture_rect.texture = preload("res://addons/resource_databases/editor_only/ui/icons/remove_clean.svg")
		_button.add_theme_color_override(&"font_hover_color", Color.LIGHT_CORAL)


func _on_button_pressed() -> void:
	clicked.emit(category, for_adding)
