
const SETTINGS_PREFIX := "resource_databases/"

var settings_list: PackedStringArray
var default_settings: Dictionary

func add_settings() -> void:
	_create_setting("show_expression_evaluation_errors", false)
	_create_setting("allow_repeated_locators", false)
	_create_setting("allow_file_paths", true)
	_create_setting("recursive_folder_search", false)
	_create_setting("ask_for_deletion_confirmation", true)
	_create_setting("ask_for_invalidation_confirmation", true)
	_create_setting("max_view_entries", 25)
	ProjectSettings.save()


func remove_settings() -> void:
	for setting_name in settings_list:
		var full_setting_name := SETTINGS_PREFIX + setting_name
		if not ProjectSettings.has_setting(full_setting_name):
			continue
		ProjectSettings.set_setting(full_setting_name, null)
	settings_list.clear()
	default_settings.clear()
	ProjectSettings.save()


func get_setting(setting_name: String) -> Variant:
	return ProjectSettings.get_setting(SETTINGS_PREFIX + setting_name,
	default_settings[setting_name])


func _create_setting(setting_name: String, value: Variant, property_hint: int = 0, property_hint_string: String = "") -> void:
	var full_setting_name := SETTINGS_PREFIX + setting_name
	settings_list.append(setting_name)
	default_settings[setting_name] = value
	if ProjectSettings.has_setting(full_setting_name):
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
	default_settings[setting_name] = value
