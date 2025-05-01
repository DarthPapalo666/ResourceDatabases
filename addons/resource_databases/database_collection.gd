@tool
class_name DatabaseCollection

signal settings_changed
signal entries_changed
signal int_id_changed(old: int, new: int)
signal string_id_changed(old: StringName, new: StringName)

enum PathFilterType {INCLUDE, EXCLUDE}

## Locator for invalid resources. (Invalid resources are not fetched and don't push errors.)[br]
## Used for empty entries or as an ID placeholder.
const INVALID_RESOURCE_LOCATOR := "<invalid>"


# Settings
var _valid_classes: Array[StringName]
var _designated_folders: Array[String]
var _included_filters: Array[String]
var _excluded_filters: Array[String]

# Entries
var _ints_to_strings: Dictionary[int, StringName]
var _strings_to_ints: Dictionary[StringName, int]
var _ints_to_locators: Dictionary[int, String] # Maps Int IDs to locator Strings (either UIDs or paths)

# Categories
var _categories_to_ints: Dictionary[StringName, Dictionary] # Maps Categories to Int IDs (Dictionary[int, bool])

var collection_size: int:
	get:
		return _ints_to_locators.size()


#region Fetching methods
## Returns the corresponding resource from the collection by it's Int ID.
func fetch_resource(id: Variant) -> Resource:
	var int_id: int = ensure_int_id(id)
	if not _has_id(int_id):
		push_error("Can't fetch non-invalid resource, inexistent ID (%s)." % int_id)
		return null
	if get_locator(int_id) == INVALID_RESOURCE_LOCATOR:
		return null
	if not ResourceLoader.exists(get_locator(int_id)):
		push_error("Can't load non-invalid resource, doesn't exist (%s)." % get_locator(int_id))
		return null
	return load(get_locator(int_id))


## Returns all resources from the collection.
func fetch_all_resources(include_invalid: bool) -> Dictionary[int, Resource]:
	var fetched: Dictionary[int, Resource] = {}
	for int_id: int in _ints_to_locators:
		var res = fetch_resource(int_id)
		if res != null or include_invalid:
			fetched[int_id] = res
	return fetched


## Returns all then resources from a given [param category].
func fetch_category_resources(category: StringName, include_invalid: bool) -> Dictionary[int, Resource]:
	if not has_category(category):
		push_error("Can't fetch category data from inexistent category.")
	var fetched: Dictionary[int, Resource] = {}
	for int_id: int in _categories_to_ints[category] as Dictionary[int, bool]:
		var data := fetch_resource(int_id)
		if data != null or include_invalid:
			fetched[int_id] = data
	return fetched
#endregion


#region Designation of resources
## Sets the folder which contains the resources for the collection.
func set_designated_folders(folders: String) -> void:
	var folders_array := DatabaseFormatLoader.string_to_strings_array(folders)
	for u in folders_array:
		if not DirAccess.dir_exists_absolute(u):
			push_error("Can't change designated folders, inexistent path: (%s)." % u)
	_designated_folders = folders_array
	update_designated_resources()

## Sets the include and exclude filters for the resource paths.
func set_path_filters(filters_string: String, type: PathFilterType) -> void:
	var filters: Array[String] = DatabaseFormatLoader.string_to_strings_array(filters_string)
	match type:
		PathFilterType.INCLUDE:
			_included_filters = filters
		PathFilterType.EXCLUDE:
			_excluded_filters = filters
		_:
			push_error("Invalid type of path filter.")
	settings_changed.emit()


## Adds all new resources from the designated filters and invalidates entries of missing ones.
func update_designated_resources() -> void:
	# Check existing resources
	for int_id: int in _ints_to_locators.keys():
		var locator: String = get_locator(int_id)
		if not _is_resource_inside_filters(locator) or ResourceLoader.exists(locator):
			set_invalid_resource(int_id)
			continue
	
	# Add missing resources in filters
	for folder: String in _designated_folders if not _designated_folders.is_empty() else ["res://"]:
		register_folder_resources(folder)
	entries_changed.emit()


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
	var is_excluded := false
	if not _excluded_filters.is_empty():
		is_excluded = _excluded_filters.any(_has_regex_match.bind(res_path))
	var is_included := true
	if not _included_filters.is_empty():
		is_included = _included_filters.any(_has_regex_match.bind(res_path))
	return not is_excluded and is_included


func _has_regex_match(filter: String, subject: String) -> bool:
	var regex := RegEx.create_from_string(filter)
	if not regex.is_valid():
		push_error("RegEx is invalid (%s)." % filter)
		return true
	return regex.search(subject) != null
#endregion


#region Validation of resource classes
func set_valid_classes(classes: String) -> void:
	_valid_classes = DatabaseFormatLoader.string_to_names_array(classes)
	settings_changed.emit()


func validate_resource_classes() -> void:
	for int_id: int in _ints_to_locators:
		if not ResourceLoader.exists(_ints_to_locators[int_id]):
			continue
		var is_valid := is_resource_valid_class(load(_ints_to_locators[int_id]))
		if not is_valid:
			set_invalid_resource(int_id)
	entries_changed.emit()


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
## Creates a new empty category provided that the name is valid.
func create_category(category: StringName) -> void:
	if has_category(category):
		push_error("Can't register category, already registered.")
		return
	if category.is_empty() or not category.is_valid_ascii_identifier():
		push_error("Can't register category, invalid identifier.")
		return
	_categories_to_ints[category] = {}
	entries_changed.emit()


## Removes a category from the collection provided it exists.
func remove_category(category: StringName) -> void:
	if not _categories_to_ints.has(category):
		push_error("Can't remove inexistent category.")
		return
	_categories_to_ints.erase(category)
	entries_changed.emit()


## Erases all IDs assigned to a category.
func clear_category(category: StringName) -> void:
	if not has_category(category):
		push_error("Can't clear inexsistent category.")
		return
	(_categories_to_ints[category] as Dictionary[int, bool]).clear()
	entries_changed.emit()


## Returns the names of all categories.
func get_all_categories() -> Array[StringName]:
	var arr: Array[StringName]
	arr.assign(_categories_to_ints.keys())
	return arr


## Returns [code]true[/code] if [param category] is present in the collection.
func has_category(category: StringName) -> bool:
	return category in get_all_categories()


## Returns [code]true[/code] if the category name is available to add to the collection.
func is_category_name_available(category: StringName) -> bool:
	return not category.is_empty() and category.is_valid_ascii_identifier() and not has_category(category)


## Adds a [param category] to a resource by it's [param id].
func add_category_to_resource(category: StringName, id: Variant, show_error := true) -> void:
	if not has_category(category):
		push_error("Can't add inexistent category to resource.")
		return
	var category_dict := _categories_to_ints[category] as Dictionary
	var int_id: int = ensure_int_id(id)
	if category_dict.has(int_id):
		if show_error:
			push_error("Resource already in category.")
		return
	category_dict[int_id] = true # NOTE: true is a placeholder
	entries_changed.emit()


## Removes a [param category] from a resource by it's [param id].
func remove_category_from_resource(category: StringName, id: Variant, show_error := true) -> void:
	if not _categories_to_ints.has(category):
		push_error("Can't remove resource from inexistent category.")
		return
	var category_dict := _categories_to_ints[category] as Dictionary[int, bool]
	var int_id: int = ensure_int_id(id)
	if not category_dict.has(int_id):
		if show_error:
			push_error("Resource (ID: %s) is not in the specified category (%s), can't remove it." % [id, category])
		return
	category_dict.erase(int_id)
	entries_changed.emit()


## Returns the list of categories of a resource by it's [param id].
func get_categories_of_resource(id: Variant) -> Array[StringName]:
	var arr: Array[StringName]
	for category: StringName in _categories_to_ints:
		if (_categories_to_ints[category] as Dictionary[int, bool]).has(ensure_int_id(id)):
			arr.append(category)
	return arr
#endregion


#region Resource registering
## Registers the resources of a folder.
func register_folder_resources(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		push_error("Path doesn't exist: (%s)" % dir)
		return
	var all_paths: PackedStringArray
	if ProjectSettings.get_setting("resource_databases/recursive_folder_search"):
		all_paths = _recursive_file_search(dir)
	else:
		all_paths = _get_files_from_dir(dir)
	for path: String in all_paths:
		register_resource(path, true)
	entries_changed.emit()


## Registers resources by path within the database with locators.[br]
## IDs are assigned automatically, can be modified later.
func register_resource(locator: String, in_bulk := false) -> void:
	if not ResourceLoader.exists(locator):
		if not in_bulk:
			push_error("Resource doesn't exist (%s)." % locator)
		return
	if locator.is_empty():
		if not in_bulk:
			push_error("Invalid resource locator (%s)." % locator)
		return
	if not _is_resource_inside_filters(locator):
		if not in_bulk:
			push_error("Not included in path filters (%s)." % locator)
		return
	if not is_resource_valid_class(load(locator)):
		if not in_bulk:
			push_error("Resource class is not valid in this collection (%s)." % locator)
		return
	if not ProjectSettings.get_setting("resource_databases/allow_repeated_locators"):
		if _ints_to_locators.values().has(locator):
			if not in_bulk:
				push_error("Can't add resource to collection, locator already registered. (%s)" % locator)
			return
	
	var file_name: String
	if locator.begins_with("uid://"):
		var resource_path := ResourceUID.get_id_path(ResourceUID.text_to_id(locator))
		file_name = _get_file_name(resource_path)
	else:
		file_name = _get_file_name(locator)
		
	# Generation of unique String ID
	while file_name in _strings_to_ints: 
		if file_name[-1] in "0123456789":
			file_name = file_name.left(len(file_name)-1) + str(int(file_name[-1]) + 1)
		else:
			file_name = file_name + "0"
	
	# Assignation of new Int ID
	var int_id: int = (_ints_to_locators.keys().max() + 1) as int if _ints_to_locators.size() > 0 else 0
	if int_id:
		push_error("New Int ID shouldn't be negative.")
	_ints_to_strings[int_id] = file_name
	_strings_to_ints[file_name] = int_id
	_ints_to_locators[int_id] = locator
	entries_changed.emit()


## Sets the locator of an entry to: [constant DatabaseCollection.INVALID_RESOURCE_LOCATOR][br]
## The invalid locator enables entries to act as [b]placeholders[/b].
func set_invalid_resource(id: Variant) -> void:
	var int_id: int = ensure_int_id(id)
	if not _has_id(id):
		push_error("Can't make inexistent resource invalid")
		return
	_ints_to_locators[int_id] = INVALID_RESOURCE_LOCATOR
	entries_changed.emit()


## Removes a resource from the collection by it's [param id]
func unregister_resource(id: Variant) -> void:
	var int_id: int = ensure_int_id(id)
	if not _has_id(int_id):
		push_error("Can't unregister inexistent resource.")
		return
	_ints_to_locators.erase(int_id)
	for category: StringName in _categories_to_ints:
		(_categories_to_ints[category] as Dictionary).erase(int_id)
	_strings_to_ints.erase(_ints_to_strings[int_id])
	_ints_to_strings.erase(int_id)
	entries_changed.emit()
#endregion


#region Entry modification methods
## Changes the locator of a collection entry by it's [param id].
func change_resource_locator(id: Variant, locator: String) -> void:
	var int_id: int = ensure_int_id(id)
	if not _ints_to_locators.has(int_id):
		push_error("Inexistent resource Int ID.")
		return
	if locator.is_empty():
		push_error("Empty locator provided.")
		return
	if not ProjectSettings.get_setting("resource_databases/allow_repeated_locators"):
		if _ints_to_locators.values().has(locator): # WARNING compute cost :p
			push_error("Can't change locator, already registered.")
			return
	_ints_to_locators[int_id] = locator
	entries_changed.emit()


## Changes a String ID from the collection.
func change_resource_string_id(old: StringName, new: StringName) -> void:
	if not _has_id(old):
		push_error("Inexistent old String ID.")
		return
	if _strings_to_ints.has(new):
		push_error("[Can't change String ID, [\"%s\"] already exists." % new)
		return
	var int_id: int = _strings_to_ints[old]
	_strings_to_ints.erase(old)
	_strings_to_ints[new] = int_id
	_ints_to_strings[int_id] = new
	string_id_changed.emit(old, new)
	entries_changed.emit()


## Changes a Int ID from the collection.
func change_resource_int_id(old: int, new: int) -> void:
	if not _has_id(old):
		push_error("Intexistent old Int ID.")
		return
	if _ints_to_strings.has(new):
		push_error("Can't change Int ID, [%s] already exists." % new)
		return
	var string_id: StringName = _ints_to_strings[old]
	var res_locator: String = _ints_to_locators[old]
	_ints_to_strings.erase(old)
	_ints_to_strings[new] = string_id
	_strings_to_ints[string_id] = new
	_ints_to_locators.erase(old)
	_ints_to_locators[new] = res_locator
	for category: StringName in _categories_to_ints:
		if (_categories_to_ints[category] as Dictionary).has(old):
			(_categories_to_ints[category] as Dictionary).erase(old)
			(_categories_to_ints[category] as Dictionary)[new] = true
	int_id_changed.emit(old, new)
	entries_changed.emit()
#endregion


#region Common methods
## Ensures that the id results in the Int ID of the resource (If valid).
func ensure_int_id(id: Variant) -> int:
	match typeof(id):
		TYPE_STRING_NAME:
			if not _strings_to_ints.has(id):
				push_error("String ID doesn't exist (%s)." % id)
				return -1
			return _strings_to_ints[id]
		TYPE_INT:
			if not _ints_to_locators.has(id):
				push_error("Int ID doesn't exist (%s)." % id)
				return -1
			return id
		_:
			push_error("Invalid ID type.")
			return -1


func _has_id(id: Variant) -> bool:
	return ensure_int_id(id) != -1


## Returns data related with the entries of the collection.
func get_entries_data() -> Dictionary[StringName, Variant]:
	return {
		ints_to_strings = _ints_to_strings,
		strings_to_ints = _strings_to_ints,
		ints_to_locators = _ints_to_locators,
		categories_to_ints = _categories_to_ints,
	}


## Returns data related with the settings of the collection.
func get_settings_data() -> Dictionary[StringName, Variant]:
	return {
		valid_classes = _valid_classes,
		designated_folders = _designated_folders,
		included_filters = _included_filters,
		excluded_filters = _excluded_filters,
	}


## Returns the corresponding locator for an ID.
func get_locator(id: Variant) -> String:
	return _ints_to_locators[ensure_int_id(id)]


# Prints the collection as text, used for debugging purposes.
func _to_string() -> String:
	return """ints_to_strings : %s
	strings_to_ints : %s
	ints_to_locators : %s""" % [str(_ints_to_strings), str(_strings_to_ints), str(_ints_to_locators)]


func _resource_locator_from_path(path: String) -> String:
	var int_uid := ResourceLoader.get_resource_uid(path)
	if int_uid == -1:
		if ProjectSettings.get_setting("resource_databases/allow_file_paths"):
			if ResourceLoader.exists(path):
				return path
			else:
				return "" # Invalid path
		else:
			push_error("Can't get locator for resource, UID not available.")
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
