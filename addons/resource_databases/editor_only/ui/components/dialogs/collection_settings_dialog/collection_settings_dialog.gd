@tool
extends Window

const Namespace := preload("res://addons/resource_databases/editor_only/plugin_namespace.gd")

@export var _collection_name_parameter: Namespace.EditableParameter
@export var _classes_parameter: Namespace.EditableParameter
@export var _folders_parameter: Namespace.EditableParameter
@export var _included_filters_parameter: Namespace.EditableParameter
@export var _excluded_filters_parameter: Namespace.EditableParameter

var DatabaseEditor := Namespace.get_editor_singleton()

var collection_uid: int = -1


func setup_settings_dialog(ncollection_uid: int) -> void:
	collection_uid = ncollection_uid
	DatabaseEditor.get_database().collections_list_changed.connect(_on_collections_list_changed)
	DatabaseEditor.get_database_closed_signal().connect(queue_free)
	_get_collection().name_changed.connect(_on_collection_name_changed)
	_on_collection_name_changed(_get_collection().name)
	_get_collection().settings_changed.connect(_on_collection_settings_changed)
	_on_collection_settings_changed(_get_collection().get_settings())


func _get_collection() -> EditorDatabaseCollection:
	return DatabaseEditor.get_database().get_collection(collection_uid)


func _on_collections_list_changed(collection_uids: Array[int]) -> void:
	if collection_uid not in collection_uids:
		queue_free()


func _on_collection_name_changed(new_name: StringName) -> void:
	_collection_name_parameter.set_parameter(str(new_name))
	title = "%s settings" % _get_collection().name.capitalize()


func _on_collection_settings_changed(settings: Dictionary) -> void:
	_classes_parameter.set_parameter(_get_array_string(settings.valid_classes))
	_folders_parameter.set_parameter(_get_array_string(settings.designated_folders))
	_included_filters_parameter.set_parameter(_get_array_string(settings.included_filters))
	_excluded_filters_parameter.set_parameter(_get_array_string(settings.excluded_filters))


func _get_array_string(arr: Array) -> String:
	var string := ""
	for add: String in arr:
		string = string + "%s, " % add
	return string


func _on_name_editable_parameter_change_made(new_value: String, _old_value: String) -> void:
	if not DatabaseEditor.get_database().is_collection_name_available(new_value):
		DatabaseEditor.warn("Can't rename collection", "Invalid new collection name.")
		return
	_get_collection().name = new_value


func _on_classes_editable_parameter_change_made(new_value: String, _old_value: String) -> void:
	_get_collection().set_valid_classes(new_value)


func _on_validate_classes_button_pressed() -> void:
	_get_collection().validate_resource_classes()


func _on_folders_editable_parameter_change_made(new_value: String, _old_value: String) -> void:
	_get_collection().set_designated_folders(new_value)


func _on_update_folder_resources_button_pressed() -> void:
	_get_collection().update_designated_folders_resources()


func _on_included_editable_parameter_change_made(new_value: String, _old_value: String) -> void:
	_get_collection().set_path_filters(new_value, 0)


func _on_excluded_editable_parameter_change_made(new_value: String, _old_value: String) -> void:
	_get_collection().set_path_filters(new_value, 1)


func _on_remove_collection_button_pressed() -> void:
	if not await DatabaseEditor.warn("Remove [%s] collection" % _get_collection().name,
	"Are you sure you want to remove the [b][i]%s[/i][/b] collection?" % _get_collection().name):
		grab_focus()
		return
	DatabaseEditor.get_database().remove_collection(collection_uid)
	
