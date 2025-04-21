@tool
extends Window

const Namespace := preload("res://addons/resource_databases/editor_only/plugin_namespace.gd")

@export var _collection_name_parameter: Namespace.EditableParameter
@export var _classes_parameter: Namespace.EditableParameter
@export var _folders_parameter: Namespace.EditableParameter
@export var _included_filters_parameter: Namespace.EditableParameter
@export var _excluded_filters_parameter: Namespace.EditableParameter

var _correctly_initialized := false

var _database_editor: Namespace.DatabaseEditor

var _collection_name: StringName:
	set(v):
		_collection_name = v
		_collection = _database_editor.loaded_database.get_collection(_collection_name)

var _collection: DatabaseCollection:
	set(v):
		_collection = v
		_collection.settings_changed.connect(_on_collection_settings_changed)
		_on_collection_settings_changed(_collection.get_settings())


func setup_settings_dialog(pdatabase_editor: Namespace.DatabaseEditor, pcollection_name: StringName) -> void:
	_database_editor = pdatabase_editor
	_collection_name = pcollection_name
	_correctly_initialized = true


func _on_collection_name_changed(new_name: StringName) -> void:
	_collection_name_parameter.set_parameter(String(new_name))
	title = "%s settings" % new_name.capitalize()


func _on_collection_settings_changed(settings: Dictionary) -> void:
	_classes_parameter.set_parameter(var_to_str(settings.valid_classes))
	_folders_parameter.set_parameter(var_to_str(settings.designated_folders))
	_included_filters_parameter.set_parameter(var_to_str(settings.included_filters))
	_excluded_filters_parameter.set_parameter(var_to_str(settings.excluded_filters))


func _on_name_editable_parameter_change_made(old_value: String, new_value: String) -> void:
	if not _database_editor.loaded_database.is_collection_name_available(new_value):
		_database_editor.warn(
			"Can't rename _collection",
			"Invalid new _collection name."
		)
		return
	_database_editor.loaded_database.change_collection_name(old_value, new_value)


func _on_classes_editable_parameter_change_made(_old: String, new: String) -> void:
	_collection.set_valid_classes(new)


func _on_validate_classes_button_pressed() -> void:
	_collection.validate_resource_classes()


func _on_folders_editable_parameter_change_made(_old: String, new: String) -> void:
	_collection.set_designated_folders(new)


func _on_update_folder_resources_button_pressed() -> void:
	_collection.update_designated_folders_resources()


func _on_included_editable_parameter_change_made(_old: String, new: String) -> void:
	_collection.set_path_filters(new, DatabaseCollection.PathFilterType.INCLUDE)


func _on_excluded_editable_parameter_change_made(_old: String, new: String) -> void:
	_collection.set_path_filters(new, DatabaseCollection.PathFilterType.EXCLUDE)


func _on_remove_collection_button_pressed() -> void:
	if not await _database_editor.warn(
		"Remove [%s] _collection" % _collection_name_parameter.get_value(),
		"Are you sure you want to remove the [b][i]%s[/i][/b] _collection?" % _collection_name_parameter.get_value()
	):
		grab_focus()
		return
	_database_editor.loaded_database.remove_collection(_collection_name_parameter.get_value())
	
