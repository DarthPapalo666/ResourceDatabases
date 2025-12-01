@tool
extends EditorPlugin

const Namespace := preload("uid://b7ra0aicagaes")

const SETTINGS_PREFIX := "resource_databases"

const DATABASE_EDITOR_SCENE := preload("uid://juvgv48tbcqo")

var _database_editor_instance: Namespace.DatabaseEditor
var _settings_list: PackedStringArray


# Initialization of the plugin.
func _enter_tree() -> void:
	# If game is running in editor, add the DatabaseEditor UI
	if Engine.is_editor_hint():
		_database_editor_instance = DATABASE_EDITOR_SCENE.instantiate()
		
		# Adds the database editor to the mainscreen
		_database_editor_instance.set_plugin_version(get_plugin_version())
		EditorInterface.get_editor_main_screen().add_child(_database_editor_instance)
		
		_make_visible(false)
	
	# Add plugin settings
	_add_settings()
	
	print_rich("[color=sky_blue][Resource Databases] Plugin loaded!")


# Clean-up of the plugin.
func _exit_tree() -> void:
	# Removes mainscreen instance
	if _database_editor_instance != null:
		_database_editor_instance.free()
	
	# Remove plugin settings
	_remove_settings()
	
	print_rich("[color=coral][Resource Databases] Plugin disabled.")


func _make_visible(visible: bool) -> void:
	if _database_editor_instance != null:
		_database_editor_instance.visible = visible


func _has_main_screen() -> bool:
	return true


func _get_plugin_name() -> String:
	return "ResourcesDB"


func _get_plugin_icon() -> Texture2D:
	return EditorInterface.get_editor_theme().get_icon("ResourcePreloader", "EditorIcons")


func _handles(object: Object) -> bool:
	var db := object as ResourceDatabase
	return db != null and not db.resource_path.is_empty()


func _edit(object: Object) -> void:
	var db := object as ResourceDatabase
	if (
		db == null or
		not ResourceLoader.exists(db.resource_path) or
		_database_editor_instance == null
	):
		return
	_database_editor_instance.load_database(db.resource_path)


#region Plugin settings
func _add_settings() -> void:
	_create_setting("show_expression_evaluation_errors", false)
	_create_setting("allow_repeated_locators", false)
	_create_setting("allow_file_paths", true)
	_create_setting("recursive_folder_search", false)
	_create_setting("ask_for_deletion_confirmation", true)
	_create_setting("ask_for_invalidation_confirmation", true)
	_create_setting("max_view_entries", 25)
	ProjectSettings.save()


func _remove_settings() -> void:
	for setting_name in _settings_list:
		var full_setting_name := r"%s/%s" % [SETTINGS_PREFIX, setting_name]
		if not ProjectSettings.has_setting(full_setting_name):
			continue
		ProjectSettings.set_setting(full_setting_name, null)
	_settings_list.clear()
	ProjectSettings.save()


func _create_setting(setting_name: String, value: Variant, property_hint: int = 0, property_hint_string: String = "") -> void:
	var full_setting_name := r"%s/%s" % [SETTINGS_PREFIX, setting_name]
	_settings_list.append(setting_name)
	if ProjectSettings.has_setting(full_setting_name):
		#push_warning("Setting already existed: %s" % full_setting_name)
		# Might exist due to being saved in the project settings file
		return
	var property_info := {
		"name": full_setting_name,
		"type": typeof(value),
		"hint": property_hint,
		"hint_string": property_hint_string,
	}
	ProjectSettings.set_setting(full_setting_name, value)
	ProjectSettings.add_property_info(property_info)
	ProjectSettings.set_initial_value(full_setting_name, value)
	ProjectSettings.set_as_basic(full_setting_name, true)
#endregion
