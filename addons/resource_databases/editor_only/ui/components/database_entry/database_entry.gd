@tool
extends Control

signal entry_selection_changed(int_id: int, selected: bool)

const Namespace := preload("res://addons/resource_databases/editor_only/plugin_namespace.gd")

const CHANGE_RESOURCE_DIALOG := preload("res://addons/resource_databases/editor_only/ui/components/dialogs/change_resource_dialog.tscn")

@export var _int_id_parameter: Namespace.EditableParameter
@export var _string_id_parameter: Namespace.EditableParameter
@export var _resource_locator_label: RichTextLabel
@export var _selection_box: CheckBox
@export var _make_invalid_button: Button
@export var _open_categories_button: Button
@export var _open_inspector_button: Button
@export var _color_bg: ColorRect

var DatabaseEditor := Namespace.get_editor_singleton()
var DatabaseSettings := Namespace.get_settings_singleton()

var _collection_uid: int = -1
var _text_locator: String
var _is_invalid: bool


func set_entry(collection_id: int, int_id: int, string_id: StringName, locator: String, is_selected: bool, index: int) -> void:
	_collection_uid = collection_id
	var string_int := str(int_id)
	_int_id_parameter.set_parameter(string_int)
	_string_id_parameter.set_parameter(string_id)
	_text_locator = locator
	var locator_references_resource := false
	if locator.begins_with("uid://"):
		locator_references_resource = ResourceUID.has_id(ResourceUID.text_to_id(locator))
		if locator_references_resource:
			_resource_locator_label.tooltip_text = ResourceUID.get_id_path(ResourceUID.text_to_id(locator))
	else:
		locator_references_resource = ResourceLoader.exists(locator)
	var locator_visible_text := "[right][color=%s]%s"
	var truncated_locator := locator.right(47)
	if not locator == truncated_locator:
		locator_visible_text = locator_visible_text % ["light_blue" if locator_references_resource else "light_coral", "..." + truncated_locator]
	else:
		locator_visible_text = locator_visible_text % ["light_blue" if locator_references_resource else "light_coral", locator]
	_resource_locator_label.text = locator_visible_text
	
	_selection_box.set_pressed_no_signal(is_selected)
	_color_bg.color = Color("#181c21") if index % 2 == 0 else Color("#22272e")
	_is_invalid = not locator_references_resource
	_open_inspector_button.disabled = not locator_references_resource
	if locator == Database.INVALID_RESOURCE_LOCATOR:
		_make_invalid_button.disabled = true


func _get_collection() -> EditorDatabaseCollection:
	return DatabaseEditor.get_database().get_collection(_collection_uid)


func _on_parameter_changed(new_value: String, old_value: String, param_type: int) -> void:
	match param_type:
		0: # Int ID
			if not new_value.is_valid_int():
				print_rich("[color=orange]New Int ID not valid.")
				return
			_get_collection().change_resource_int_id(new_value.to_int(), old_value.to_int())
		1: # String ID
			if not new_value.is_valid_identifier():
				print_rich("[color=orange]New String ID not valid.")
				return
			_get_collection().change_resource_string_id(StringName(new_value), StringName(old_value))


func _on_resource_locator_label_gui_input(event: InputEvent) -> void:
	if _is_invalid or not ResourceLoader.exists(_text_locator):
		return
	if event is InputEventMouseButton:
		if ((event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
		and (event as InputEventMouseButton).pressed):
			var path := _text_locator
			if path.begins_with("uid://"):
				path = ResourceUID.get_id_path(ResourceUID.text_to_id(path))
			EditorInterface.get_file_system_dock().navigate_to_path(path)


func _on_change_resource_button_pressed() -> void:
	var new_dialog: FileDialog = CHANGE_RESOURCE_DIALOG.instantiate()
	new_dialog.file_selected.connect(_on_resource_changed)
	add_child(new_dialog)
	new_dialog.popup()


func _on_resource_changed(new_locator: String) -> void:
	_get_collection().change_resource_locator(_int_id_parameter.get_value().to_int(), new_locator)


func _on_make_invalid_button_pressed() -> void:
	if DatabaseSettings.get_setting("ask_for_invalidation_confirmation"):
		if not await DatabaseEditor.warn("Make resource invalid?",
		"Are you sure you want to make this resource invalid?"):
			return
	_get_collection().set_invalid_resource(_int_id_parameter.get_value().to_int())


func _on_remove_button_pressed() -> void:
	if DatabaseSettings.get_setting("ask_for_deletion_confirmation"):
		if not await DatabaseEditor.warn("Unregistering resource",
		"Are you sure you want to unregister this resource?"):
			return
	_get_collection().unregister_resource(_int_id_parameter.get_value().to_int())


func _on_categories_button_pressed() -> void:
	DatabaseEditor.open_entry_categories_dialog(_collection_uid, _int_id_parameter.get_value().to_int())


func _on_open_inspector_button_pressed() -> void:
	if _is_invalid:
		return
	var res := load(_text_locator)
	EditorInterface.edit_resource(res)


func _on_selection_box_toggled(toggled_on: bool) -> void:
	entry_selection_changed.emit(_int_id_parameter.get_value().to_int(), toggled_on)
