@tool
class_name EditorDatabaseCollection

signal name_changed(new_name: StringName)
signal settings_changed(collection_settings: Dictionary)
signal entries_changed(entries_data: Dictionary)
signal categories_changed(categories: Dictionary)

const Namespace := preload("res://addons/resource_databases/editor_only/plugin_namespace.gd")

var DatabaseSettings := Namespace.get_settings_singleton()

var _emitter_flags: Dictionary

var _all_names_ref: Dictionary # Contains the used names, values are bool placeholders

# Collection name
var name: StringName:
	set(v):
		if v in _all_names_ref:
			print_rich("[color=red]Error changing collection name, already registered.")
			return
		if name != v:
			_all_names_ref.erase(name)
			name = v
			_all_names_ref[name] = true
			name_changed.emit(name)

# Settings
var _valid_classes: Array[StringName]
var _designated_folders: Array[String]
var _included_filters: Array[String]
var _excluded_filters: Array[String]

# Entries
var _ints_to_strings: Dictionary
var _strings_to_ints: Dictionary
var _ints_to_locators: Dictionary # Maps Int IDs to locator Strings (either UIDs or paths)

# Categories
var _categories_to_ints: Dictionary # Maps Categories to Int IDs (Dictionary[int, bool])

var collection_size: int:
	get:
		return _ints_to_locators.size()


func _init(collection_name: StringName, all_names: Dictionary) -> void:
	_all_names_ref = all_names
	name = collection_name


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_all_names_ref.erase(name)


#region Designation of folders
func set_designated_folders(folders: String) -> void:
	var paths := folders.split(",", false)
	var clean: Array[String]
	for u: String in paths:
		var path := u.replace(" ", "")
		if DirAccess.dir_exists_absolute(path):
			clean.append(path)
	_designated_folders = clean
	_emit_collection_settings_changed()


func set_path_filters(filters_string: String, type: int) -> void:
	var filters := filters_string.split(",", false)
	var clean: Array[String]
	for u: String in filters:
		var filter := u.replace(" ", "")
		clean.append(filter)
	match type:
		0: # Include
			_included_filters = clean
		1: # Exlcude
			_excluded_filters = clean
		_:
			assert(false, "Error on type of filter.")
	_emit_collection_settings_changed()


func update_designated_folders_resources() -> void:
	# Check existing resources
	for int_id: int in _ints_to_locators.keys():
		var locator: String = _ints_to_locators[int_id]
		if not _is_resource_inside_filters(locator):
			set_invalid_resource(int_id)
			continue
	# Add missing resources in folders
	for folder: String in _designated_folders:
		register_folder_resources(folder)
	_emit_collection_entries_changed()


func _is_resource_inside_filters(locator: String) -> bool:
	var res_path: String
	if locator.begins_with("uid://"):
		var res_id := ResourceUID.text_to_id(locator)
		if not ResourceUID.has_id(ResourceUID.text_to_id(locator)):
			return false
		res_path = ResourceUID.get_id_path(res_id)
	else:
		res_path = locator
	if not ResourceLoader.exists(res_path):
		return false
	var is_in_folders := true
	if not _designated_folders.is_empty():
		is_in_folders = _designated_folders.any(res_path.contains)
	var is_excluded := false
	if not _excluded_filters.is_empty():
		is_excluded = _excluded_filters.any(has_regex_match.bind(res_path))
	var is_included := true
	if not _included_filters.is_empty():
		is_included = _included_filters.any(has_regex_match.bind(res_path))
	return is_in_folders and not is_excluded and is_included


func has_regex_match(filter: String, subject: String) -> bool:
	var regex := RegEx.create_from_string(filter)
	if not regex.is_valid():
		print_rich("[color=orange][ResourceDatabase] Error when compiling RegEx (%s)." % filter)
		return true
	return regex.search(subject) != null
#endregion


#region Validation of resource classes
func set_valid_classes(classes: String) -> void:
	var names := classes.split(",", false)
	var clean: Array[StringName]
	for u: String in names:
		clean.append(StringName(u.replace(" ", "")))
	_valid_classes = clean
	_emit_collection_settings_changed()


func validate_resource_classes() -> void:
	for int_id: int in _ints_to_locators:
		if not ResourceLoader.exists(_ints_to_locators[int_id]):
			continue
		var is_valid := is_resource_valid_class(load(_ints_to_locators[int_id]))
		if not is_valid:
			set_invalid_resource(int_id)
	_emit_collection_entries_changed()


func is_resource_valid_class(res: Resource) -> bool:
	if _valid_classes.is_empty():
		return true
	var res_script: Script = res.get_script()
	if res_script == null:
		return false
	var global_name := res_script.get_global_name()
	if global_name.is_empty():
		return false
	for valid_class in _valid_classes:
		if global_name == valid_class or ClassDB.is_parent_class(global_name, valid_class):
			return true
	return false
#endregion


#region Category management
func create_category(category: StringName) -> void:
	if _categories_to_ints.has(category):
		print_rich("[color=red]Can't register category, already registered.")
		return
	if category.is_empty() or not category.is_valid_identifier():
		print_rich("[color=red]Can't register category, invalid identifier.")
		return
	_categories_to_ints[category] = {}
	_emit_categories_changed()


func remove_category(category: StringName) -> void:
	if not _categories_to_ints.has(category):
		print_rich("[color=red]Can't remove inexistent category.")
		return
	var was_empty := (_categories_to_ints[category] as Dictionary).size() == 0
	_categories_to_ints.erase(category)
	_emit_categories_changed()
	if not was_empty:
		_emit_collection_entries_changed()


func clear_category(category: StringName) -> void:
	assert(has_category(category))
	var was_empty := (_categories_to_ints[category] as Dictionary).size() == 0
	(_categories_to_ints[category] as Dictionary).clear()
	_emit_categories_changed()
	if not was_empty:
		_emit_collection_entries_changed()


func get_all_categories() -> Array[StringName]:
	var arr: Array[StringName]
	arr.assign(_categories_to_ints.keys())
	return arr


func has_category(category: StringName) -> bool:
	return category in get_all_categories()


func is_category_name_available(category: StringName) -> bool:
	return not category.is_empty() and category.is_valid_identifier() and not has_category(category)


## Adds a category to a resource.
func add_category_to_resource(category: StringName, res_id: int, show_error := true) -> void:
	if not _categories_to_ints.has(category):
		print_rich("[color=orange]Can't add inexistent category to resource.")
		return
	var category_dict := _categories_to_ints[category] as Dictionary
	if category_dict.has(res_id):
		if show_error:
			print_rich("[color=red]Resource already in category.")
		return
	category_dict[res_id] = true # true is a placeholder
	_emit_categories_changed()


## Removes a category from a resource
func remove_category_from_resource(category: StringName, res_id: int, show_error := true) -> void:
	if not _categories_to_ints.has(category):
		print_rich("[color=red]Can't remove resource from inexistent category.")
		return
	var category_dict := _categories_to_ints[category] as Dictionary
	if not category_dict.has(res_id):
		if show_error:
			print_rich("[color=red]Resource is not in category, can't remove it.")
		return
	category_dict.erase(res_id)
	_emit_categories_changed()


func get_categories_of_resource(res_id: int) -> Array[StringName]:
	var arr: Array[StringName]
	for category: StringName in _categories_to_ints:
		if (_categories_to_ints[category] as Dictionary).has(res_id):
			arr.append(category)
	return arr
#endregion


#region Resource registering
func register_test_res() -> void:
	var rand := randi()
	_ints_to_strings[rand] = str(rand)
	_strings_to_ints[str(rand)] = rand
	_ints_to_locators[rand] = "test_locator%s" % rand
	_emit_collection_entries_changed()


## Registers the resources of a folder.
func register_folder_resources(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		print_rich("[color=orange]Error registering resources from: %s" % dir)
		return
	var all_paths: PackedStringArray
	if DatabaseSettings.get_setting("recursive_folder_search"):
		all_paths = _recursive_file_search(dir)
	else:
		all_paths = _get_files_from_dir(dir)
	for path: String in all_paths:
		register_resource(path, true)
	_emit_collection_entries_changed()


## Registers resources by path within the database with locators.
func register_resource(path: String, in_bulk := false) -> void:
	if not ResourceLoader.exists(path):
		print_rich("[color=red]Error registering resource, doesn't exist. [color=yellow](%s)" % path)
		return
	var locator := _resource_locator_from_path(path)
	if locator.is_empty():
		if not in_bulk:
			print_rich("[color=red]Error registering resource, invalid locator. [color=yellow](%s)" % path)
		return
	if not _is_resource_inside_filters(locator):
		if not in_bulk:
			print_rich("[color=red]Can't register resource, not included in path filters. [color=yellow](%s)" % path)
		return
	if not is_resource_valid_class(load(locator)):
		if not in_bulk:
			print_rich("[color=red]Resource class is not valid in this collection. [color=yellow](%s)" % path)
		return
	if not DatabaseSettings.get_setting("allow_repeated_locators"):
		if _ints_to_locators.values().has(locator):
			if not in_bulk:
				print_rich("[color=red]Can't add resource to collection, locator already registered. [color=yellow](%s)" % path)
			return
	var file_name: String
	if locator.begins_with("uid://"):
		var resource_path := ResourceUID.get_id_path(ResourceUID.text_to_id(locator))
		file_name = _get_file_name(resource_path)
	else:
		file_name = _get_file_name(locator)
	while file_name in _strings_to_ints: # Generation of unique String ID.
		if file_name[-1] in "012345678":
			file_name = file_name.left(len(file_name)-1) + str(int(file_name[-1]) + 1)
		else:
			file_name = file_name + "0"
	var int_id: int = (_ints_to_locators.keys().max() + 1) as int if _ints_to_locators.size() > 0 else 0
	_ints_to_strings[int_id] = file_name
	_strings_to_ints[file_name] = int_id
	_ints_to_locators[int_id] = locator
	_emit_collection_entries_changed()


func set_invalid_resource(int_id: int) -> void:
	assert(_ints_to_locators.has(int_id), "Can't make inexistent resource invalid")
	_ints_to_locators[int_id] = Database.INVALID_RESOURCE_LOCATOR
	_emit_collection_entries_changed()


func unregister_resource(int_id: int) -> void:
	assert(_ints_to_locators.has(int_id), "Can't unregister inexistent resource.")
	_ints_to_locators.erase(int_id)
	for category: StringName in _categories_to_ints:
		(_categories_to_ints[category] as Dictionary).erase(int_id)
	_strings_to_ints.erase(_ints_to_strings[int_id])
	_ints_to_strings.erase(int_id)
	_emit_collection_entries_changed()
#endregion


#region Changing IDs
func change_resource_locator(int_id: int, path: String) -> void:
	if not _ints_to_locators.has(int_id):
		print_rich("[color=red]Error changing the locator, inexistent resource.")
		return
	var locator := _resource_locator_from_path(path)
	if locator.is_empty():
		return
	if not DatabaseSettings.get_setting("allow_repeated_locators"):
		if _ints_to_locators.values().has(locator):
			print_rich("[color=red]Can't change locator, already registered.")
			return
	_ints_to_locators[int_id] = locator
	_emit_collection_entries_changed()


## Changes a String ID from the collection.
func change_resource_string_id(new_string: String, old_string: String) -> void:
	assert(_strings_to_ints.has(old_string), "Inexistent old String ID.")
	if _strings_to_ints.has(new_string):
		print_rich("[color=red]Can't change String ID, [/color][color=indian_red][\"%s\"][/color][color=red] already exists." % new_string)
		return
	var int_id: int = _strings_to_ints[old_string]
	_strings_to_ints.erase(old_string)
	_strings_to_ints[new_string] = int_id
	_ints_to_strings[int_id] = new_string
	_emit_collection_entries_changed()


## Changes a Int ID from the collection.
func change_resource_int_id(new_int: int, old_int: int) -> void:
	assert(_ints_to_strings.has(old_int), "Intexistent old Int id")
	if _ints_to_strings.has(new_int):
		print_rich("[color=red]Can't change Int ID, [/color][color=indian_red][%s][/color][color=red] already exists." % new_int)
		return
	var string_id: StringName = _ints_to_strings[old_int]
	var res_locator: String = _ints_to_locators[old_int]
	_ints_to_strings.erase(old_int)
	_ints_to_strings[new_int] = string_id
	_strings_to_ints[string_id] = new_int
	_ints_to_locators.erase(old_int)
	_ints_to_locators[new_int] = res_locator
	for category: StringName in _categories_to_ints:
		if (_categories_to_ints[category] as Dictionary).has(old_int):
			(_categories_to_ints[category] as Dictionary).erase(old_int)
			(_categories_to_ints[category] as Dictionary)[new_int] = true
	_emit_collection_entries_changed()
#endregion


#region Collection data secure getters
## Returns only readeable copies of the collection data dictionaries.
func get_entries() -> Dictionary:
	var copy_int := _ints_to_strings.duplicate()
	copy_int.make_read_only()
	var copy_locator := _ints_to_locators.duplicate()
	copy_locator.make_read_only()
	return {
		ints_to_strings = copy_int,
		ints_to_locators = copy_locator,
		categories_to_ints = _categories_to_ints,
		valid_classes = _valid_classes,
	}


## Returns the collection settings data dictionary.
func get_settings() -> Dictionary:
	var copy_classes := _valid_classes.duplicate()
	copy_classes.make_read_only()
	var copy_folders := _designated_folders.duplicate()
	copy_folders.make_read_only()
	return {
		valid_classes = copy_classes,
		designated_folders = _designated_folders,
		included_filters = _included_filters,
		excluded_filters = _excluded_filters,
	}


func get_categories() -> Dictionary:
	var copy_categories := _categories_to_ints.duplicate()
	copy_categories.make_read_only()
	return copy_categories
#endregion


#region Serialization
## Serializes the collection into a Dictionary
func serialize() -> Dictionary:
	return {
		name = name,
		ints_to_strings = _ints_to_strings,
		strings_to_ints = _strings_to_ints,
		ints_to_locators = _ints_to_locators,
		categories_to_ints = _categories_to_ints,
		valid_classes = _valid_classes,
		designated_folders = _designated_folders,
		included_filters = _included_filters,
		excluded_filters = _excluded_filters,
	}


## Creates a collection from a serialization dictionary.
static func load_serialized(name: StringName, data: Dictionary, all_names: Dictionary) -> EditorDatabaseCollection:
	var n := EditorDatabaseCollection.new(name, all_names)
	n._ints_to_strings = data.ints_to_strings
	n._strings_to_ints = data.strings_to_ints
	n._ints_to_locators = data.ints_to_locators
	n._categories_to_ints = data.categories_to_ints
	n._valid_classes = data.valid_classes
	n._designated_folders = data.designated_folders
	n._included_filters = data.included_filters
	n._excluded_filters = data.excluded_filters
	return n
#endregion


#region Helper methods
func _resource_locator_from_path(path: String) -> String:
	var int_uid := ResourceLoader.get_resource_uid(path)
	if int_uid == -1:
		if DatabaseSettings.get_setting("allow_file_paths"):
			if ResourceLoader.exists(path):
				return path
			else:
				return "" # Invalid path
		else:
			print_rich("[color]Can't get locator for resource, UID not available.")
			return ""
	else:
		return ResourceUID.id_to_text(int_uid)


## Recursively searches folder and subfolders.
func _recursive_file_search(directory_path: String) -> PackedStringArray:
	var array: PackedStringArray
	array.append_array(_get_files_from_dir(directory_path))
	var folders := DirAccess.get_directories_at(directory_path)
	for folder_path: String in folders:
		array.append_array(_recursive_file_search(directory_path.path_join(folder_path)))
	return array


## Returns all files from a directory (if any).
func _get_files_from_dir(directory_path: String) -> PackedStringArray:
	var array: PackedStringArray
	var files := DirAccess.get_files_at(directory_path)
	for file_path: String in files:
		array.append(directory_path.path_join(file_path))
	return array


## Method that returns the name of a file from its path.
func _get_file_name(path: String) -> String:
	return path.get_file().left(len(path.get_file()) - len(path.get_extension()) -1)
#endregion


#region Signal emission methods
func _has_emitter_flag(flag: StringName) -> bool:
	return _emitter_flags.has(flag)

func _add_emitter_flag(flag: StringName) -> void:
	_emitter_flags[flag] = true
	Callable.create(_emitter_flags, &"erase").call_deferred(flag)


func _emit_collection_entries_changed() -> void:
	if not _has_emitter_flag(&"entries"):
		(func() -> void: entries_changed.emit(get_entries())).call_deferred()
		_add_emitter_flag(&"entries")


func _emit_collection_settings_changed() -> void:
	if not _has_emitter_flag(&"settings"):
		(func() -> void: settings_changed.emit(get_settings())).call_deferred()
		_add_emitter_flag(&"settings")


func _emit_categories_changed() -> void:
	if not _has_emitter_flag(&"categories"):
		(func() -> void: categories_changed.emit(get_categories())).call_deferred()
		_add_emitter_flag(&"categories")
#endregion


## Prints the collection as text, used for debugging purposes.
func _to_string() -> String:
	return """
	ints_to_strings : %s
	strings_to_ints : %s
	ints_to_locators : %s""" % [str(_ints_to_strings), str(_strings_to_ints), str(_ints_to_locators)]
