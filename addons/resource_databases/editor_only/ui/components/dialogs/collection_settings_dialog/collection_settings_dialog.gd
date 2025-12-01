@tool
extends Window

const Namespace := preload("uid://b7ra0aicagaes")

@export var _collection_name_parameter: Namespace.EditableParameter
@export var _classes_parameter: Namespace.EditableParameter
@export var _validate_classes_button: Button
@export var _designated_folders_parameter: Namespace.EditableParameter
@export var _included_filters_parameter: Namespace.EditableParameter
@export var _excluded_filters_parameter: Namespace.EditableParameter
@export var _update_folder_resources_button: Button
@export var _remove_collection_button: Button

var _database_editor: Namespace.DatabaseEditor:
	set(v):
		_database_editor = v
		_database_editor.loaded_database.collection_name_changed.connect(_on_collection_name_changed)
		_database_editor.loaded_database.collections_list_changed.connect(_on_collections_list_changed)

var _collection_name: StringName:
	set(v):
		_collection_name = v
		if not _collection.settings_changed.is_connected(_on_collection_settings_changed):
			_collection.settings_changed.connect(_on_collection_settings_changed)
		_on_collection_settings_changed()
		_collection_name_parameter.setup_parameter(String(_collection_name))
		title = "%s settings" % _collection_name.capitalize()

var _collection: ResourceDatabaseCollection:
	get:
		return _database_editor.loaded_database.get_collection(_collection_name)

var _correctly_initialized := false


func setup_settings_dialog(pdatabase_editor: Namespace.DatabaseEditor, pcollection_name: StringName) -> void:
	_database_editor = pdatabase_editor
	_collection_name = pcollection_name
	_correctly_initialized = true


func get_collection_name() -> StringName:
	return _collection_name


func _ready() -> void:
	assert(_correctly_initialized)
	close_requested.connect(queue_free)
	# Editable parameters signals
	_collection_name_parameter.change_made.connect(_on_collection_name_editable_parameter_change_made)
	_classes_parameter.change_made.connect(_on_classes_editable_parameter_change_made)
	_designated_folders_parameter.change_made.connect(_on_designated_folders_editable_parameter_change_made)
	_included_filters_parameter.change_made.connect(_on_included_editable_parameter_change_made)
	_excluded_filters_parameter.change_made.connect(_on_excluded_editable_parameter_change_made)
	
	# Button signals
	_validate_classes_button.pressed.connect(_on_validate_classes_button_pressed)
	_update_folder_resources_button.pressed.connect(_on_update_folder_resources_button_pressed)
	_remove_collection_button.pressed.connect(_on_remove_collection_button_pressed)


#region Collection callbacks
func _on_collection_name_changed(old: StringName, new: StringName) -> void:
	if _collection_name == old:
		_collection_name = new


func _on_collections_list_changed() -> void:
	if _collection_name not in _database_editor.loaded_database.get_collections_list():
		queue_free()


func _on_collection_settings_changed() -> void:
	var settings: Dictionary[StringName, Variant] = _collection.get_settings_data()
	_classes_parameter.setup_parameter(ResourceDatabaseFormatSaver.array_to_string(settings.valid_classes, false))
	_designated_folders_parameter.setup_parameter(ResourceDatabaseFormatSaver.array_to_string(settings.designated_folders))
	_included_filters_parameter.setup_parameter(ResourceDatabaseFormatSaver.array_to_string(settings.included_filters))
	_excluded_filters_parameter.setup_parameter(ResourceDatabaseFormatSaver.array_to_string(settings.excluded_filters))
#endregion


#region Editable parameters callbacks
func _on_collection_name_editable_parameter_change_made(old: String, new: String) -> void:
	if not _database_editor.loaded_database.is_collection_name_available(new):
		_database_editor.warn(&"cant_rename_collection", [new])
		grab_focus()
		return
	_database_editor.loaded_database.rename_collection(old, new)


func _on_classes_editable_parameter_change_made(_old: String, new: String) -> void:
	_collection.set_valid_classes(new)


func _on_designated_folders_editable_parameter_change_made(_old: String, new: String) -> void:
	_collection.set_designated_folders(new)


func _on_included_editable_parameter_change_made(_old: String, new: String) -> void:
	_collection.set_path_filters(new, ResourceDatabaseCollection.PathFilterType.INCLUDE)


func _on_excluded_editable_parameter_change_made(_old: String, new: String) -> void:
	_collection.set_path_filters(new, ResourceDatabaseCollection.PathFilterType.EXCLUDE)
#endregion

#region Button callbacks
func _on_validate_classes_button_pressed() -> void:
	_collection.validate_resource_classes()


func _on_update_folder_resources_button_pressed() -> void:
	_collection.update_designated_resources()


func _on_remove_collection_button_pressed() -> void:
	if not await _database_editor.warn(&"remove_collection", [_collection_name_parameter.get_value()]):
		grab_focus()
		return
	_database_editor.loaded_database.remove_collection(_collection_name_parameter.get_value())
#endregion
