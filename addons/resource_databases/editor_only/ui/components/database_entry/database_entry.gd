@tool
extends Control

signal entry_selection_changed(_int_id: int, selected: bool)

const Namespace := preload("res://addons/resource_databases/editor_only/plugin_namespace.gd")

const CHANGE_RESOURCE_DIALOG := preload("res://addons/resource_databases/editor_only/ui/components/dialogs/change_resource_dialog.tscn")

@export var _int_id_parameter: Namespace.EditableParameter
@export var _string_id_parameter: Namespace.EditableParameter
@export var _resource_locator_label: RichTextLabel
@export var _change_resource_button: Button
@export var _selection_box: CheckBox
@export var _make_invalid_button: Button
@export var _remove_button: Button
@export var _open_categories_button: Button
@export var _open_inspector_button: Button
@export var _color_bg: ColorRect

var correctly_initialized := false

var _database_editor: Namespace.DatabaseEditor
var _collection_name: StringName
var _collection: DatabaseCollection:
	get:
		return _database_editor.loaded_database.get_collection(_collection_name)

var _int_id: int:
	set(v):
		_int_id = v
		_int_id_parameter.set_parameter(var_to_str(_int_id))

var _string_id: StringName:
	set(v):
		_string_id = v
		_string_id_parameter.set_parameter(String(_string_id))

var _locator: String:
	set(v):
		_locator = v
		if _locator.begins_with("uid://"):
			if not _is_invalid:
				_resource_locator_label.tooltip_text = ResourceUID.get_id_path(ResourceUID.text_to_id(_locator))
		var locator_visible_text := "[right][color=%s]%s"
		var truncated_locator := _locator.right(47) # WARNING magic number :o
		if not _locator == truncated_locator:
			locator_visible_text = locator_visible_text % ["light_blue" if not _is_invalid else "light_coral", "..." + truncated_locator]
		else:
			locator_visible_text = locator_visible_text % ["light_blue" if not _is_invalid else "light_coral", _locator]
		_resource_locator_label.text = locator_visible_text
		_open_inspector_button.disabled = _is_invalid
		if _locator == DatabaseCollection.INVALID_RESOURCE_LOCATOR:
			_make_invalid_button.disabled = true

var _is_invalid: bool:
	get:
		return ResourceLoader.exists(_locator)


func setup_entry(pcollection_name: StringName, pint_id: int, pstring_id: StringName, plocator: String, is_selected: bool, index: int) -> void:
	_collection_name = pcollection_name
	_int_id = pint_id
	_string_id = pstring_id
	_locator = plocator
	_selection_box.set_pressed_no_signal(is_selected)
	_color_bg.color = Color("#181c21") if index % 2 == 0 else Color("#22272e")
	correctly_initialized = true


func _ready() -> void:
	assert(correctly_initialized)
	_int_id_parameter.change_made.connect(_on_parameter_changed.bind(0))
	_string_id_parameter.change_made.connect(_on_parameter_changed.bind(1))
	_resource_locator_label.gui_input.connect(_on_resource_locator_label_gui_input)
	_change_resource_button.pressed.connect(_on_change_resource_button_pressed)
	_selection_box.toggled.connect(_on_selection_box_toggled)
	_make_invalid_button.pressed.connect(_on_make_invalid_button_pressed)
	_remove_button.pressed.connect(_on_remove_button_pressed)
	_open_categories_button.pressed.connect(_on_open_categories_button_pressed)
	_open_inspector_button.pressed.connect(_on_open_inspector_button_pressed)


func _on_parameter_changed(new_value: String, old_value: String, param_type: int) -> void:
	match param_type:
		0: # Int ID
			if not new_value.is_valid_int():
				print_rich("[color=orange]New Int ID not valid.")
				return
			_collection.change_resource_int_id(new_value.to_int(), old_value.to_int())
		1: # String ID
			if not new_value.is_valid_identifier():
				print_rich("[color=orange]New String ID not valid.")
				return
			_collection.change_resource_string_id(StringName(new_value), StringName(old_value))


func _on_resource_locator_label_gui_input(event: InputEvent) -> void:
	if not ResourceLoader.exists(_locator):
		return
	if event is InputEventMouseButton:
		if ((event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
		and (event as InputEventMouseButton).pressed):
			var path := _locator
			if path.begins_with("uid://"):
				path = ResourceUID.get_id_path(ResourceUID.text_to_id(path))
			EditorInterface.get_file_system_dock().navigate_to_path(path) # TODO try with uid directly


func _on_change_resource_button_pressed() -> void:
	var new_dialog: FileDialog = CHANGE_RESOURCE_DIALOG.instantiate()
	new_dialog.file_selected.connect(_on_resource_changed)
	add_child(new_dialog)
	new_dialog.popup()


func _on_resource_changed(new_locator: String) -> void:
	_collection.change_resource_locator(
		_int_id_parameter.get_value().to_int(),
		new_locator
	)


func _on_selection_box_toggled(toggled_on: bool) -> void:
	entry_selection_changed.emit(_int_id_parameter.get_value().to_int(), toggled_on)


func _on_make_invalid_button_pressed() -> void:
	if ProjectSettings.get_setting("resource_databases/ask_for_invalidation_confirmation"):
		if not await _database_editor.warn(
			"Make resource invalid?",
			"Are you sure you want to make this resource invalid?"
		):
			return
	_collection.set_invalid_resource(_int_id_parameter.get_value().to_int())


func _on_remove_button_pressed() -> void:
	if ProjectSettings.get_setting("resource_databases/ask_for_deletion_confirmation"):
		if not await _database_editor.warn(
			"Unregistering resource",
			"Are you sure you want to unregister this resource?"
		):
			return
	_collection.unregister_resource(_int_id_parameter.get_value().to_int())


func _on_open_categories_button_pressed() -> void:
	_database_editor.open_entry_categories_dialog(_collection_name, _int_id)


func _on_open_inspector_button_pressed() -> void:
	if not ResourceLoader.exists(_locator):
		return
	var res := load(_locator)
	EditorInterface.edit_resource(res)
