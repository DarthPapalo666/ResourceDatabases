@tool
class_name ResourceDatabaseCollection

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
		printerr("Can't fetch non-invalid resource, inexistent ID (%s)." % int_id)
		return null
	if get_locator(int_id) == INVALID_RESOURCE_LOCATOR:
		return null
	if not ResourceLoader.exists(get_locator(int_id)):
		printerr("Can't load non-invalid resource, doesn't exist (%s)." % get_locator(int_id))
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
		printerr("Can't fetch category data from inexistent category.")
	var fetched: Dictionary[int, Resource] = {}
	for int_id: int in _categories_to_ints[category] as Dictionary[int, bool]:
		var data := fetch_resource(int_id)
		if data != null or include_invalid:
			fetched[int_id] = data
	return fetched
#endregion


#region Validation of resource classes
# Sets the valid classes of the collection from a correctly formatted string or array.
func set_valid_classes(classes: Variant) -> void:
	match typeof(classes):
		TYPE_STRING:
			_valid_classes = ResourceDatabaseFormatLoader.string_to_names_array(classes)
		TYPE_ARRAY:
			_valid_classes.assign(classes)
		_:
			printerr("Invalid type for valid classes.")
	print_debug("Setted valid classes: %s" % [_valid_classes])
	settings_changed.emit()


# Validates if the resources from the collection have valid classes.
func validate_resource_classes() -> void:
	print_debug("Validating resource classses")
	for int_id: int in _ints_to_locators:
		if not ResourceLoader.exists(_ints_to_locators[int_id]):
			continue
		var is_valid := _is_resource_class_valid(load(_ints_to_locators[int_id]))
		if not is_valid:
			set_invalid_resource(int_id)
	print_debug("Validated resource classes.")
	entries_changed.emit()


# Checks if a resource class is valid.
func _is_resource_class_valid(res: Resource) -> bool:
	if _valid_classes.is_empty():
		return true
	var res_script := res.get_script() as Script
	if res_script == null:
		return false
	var global_name := res_script.get_global_name()
	if global_name.is_empty():
		return false
	return global_name in _valid_classes
#endregion


#region Designated folders and path filters
## Sets the folder which contains the resources for the collection.
func set_designated_folders(folders: Variant) -> void:
	var folders_array: Array[String]
	match typeof(folders):
		TYPE_STRING:
			folders_array = ResourceDatabaseFormatLoader.string_to_strings_array(folders)
		TYPE_ARRAY:
			folders_array = folders
		_:
			printerr("Invalid type for designated folders.")
	
	for u in folders_array:
		if not DirAccess.dir_exists_absolute(u):
			printerr("Can't change designated folders, inexistent path: (%s)." % u)
			return
	
	_designated_folders = folders_array
	print_debug("Setted designated folders: ", _designated_folders)
	settings_changed.emit()
	update_designated_resources()


## Sets the include and exclude filters for the resource paths.
func set_path_filters(filters: Variant, type: PathFilterType) -> void:
	var filters_array: Array[String]
	match typeof(filters):
		TYPE_STRING:
			filters_array = ResourceDatabaseFormatLoader.string_to_strings_array(filters)
		TYPE_ARRAY:
			filters_array = filters
		_:
			printerr("Invalid type for path filters.")
	
	match type:
		PathFilterType.INCLUDE:
			_included_filters = filters_array
			print_debug("Setted include filters: %s" % [_included_filters])
		PathFilterType.EXCLUDE:
			_excluded_filters = filters_array
			print_debug("Setted exclude filters: %s" % [_excluded_filters])
		_:
			printerr("Invalid type of path filter.")
	settings_changed.emit()


## Adds all new resources from the designated filters and invalidates entries of missing ones.
func update_designated_resources() -> void:
	print_debug("Updating designated resources.")
	# Check existing resources
	for int_id: int in _ints_to_locators.keys():
		var locator: String = get_locator(int_id)
		if not ResourceLoader.exists(locator) or not _is_locator_inside_filters(locator):
			set_invalid_resource(int_id)
			continue
	
	# Add missing resources in filters
	if not _designated_folders.is_empty():
		for folder: String in _designated_folders:
			register_folder_resources(folder)
	
	print_debug("Designated resources updated.")
	entries_changed.emit()


# Checks if a given locator should be included with the given filters.
func _is_locator_inside_filters(locator: String) -> bool:
	var res_path := resource_path_from_locator(locator)
	if not ResourceLoader.exists(res_path):
		return false
	
	var is_in_designated_folder := true
	if not _designated_folders.is_empty():
		is_in_designated_folder = _designated_folders.any(_has_regex_match.bind(res_path))
	
	var is_excluded := false
	if not _excluded_filters.is_empty():
		is_excluded = _excluded_filters.any(_has_regex_match.bind(res_path))
	
	var is_included := true
	if not _included_filters.is_empty():
		is_included = _included_filters.any(_has_regex_match.bind(res_path))
	
	return is_in_designated_folder and not is_excluded and is_included


# Helper method to create and evaluate RegEx.
func _has_regex_match(filter: String, subject: String) -> bool:
	var regex := RegEx.create_from_string(filter)
	if not regex.is_valid():
		printerr("RegEx is invalid (%s)." % filter)
		return true
	return regex.search(subject) != null
#endregion


#region Category management
## Creates a new empty category provided that the name is valid.
func create_category(category: StringName) -> void:
	if has_category(category):
		printerr("Can't register category, already registered.")
		return
	if category.is_empty() or not category.is_valid_ascii_identifier():
		printerr("Can't register category, invalid identifier.")
		return
	_categories_to_ints[category] = {}
	print_debug("Category created: %s." % category)
	entries_changed.emit()


## Removes a category from the collection provided it exists.
func remove_category(category: StringName) -> void:
	if not _categories_to_ints.has(category):
		printerr("Can't remove inexistent category.")
		return
	_categories_to_ints.erase(category)
	print_debug("Category removed: %s." % category)
	entries_changed.emit()


## Erases all IDs assigned to a category.
func clear_category(category: StringName) -> void:
	if not has_category(category):
		printerr("Can't clear inexsistent category.")
		return
	(_categories_to_ints[category] as Dictionary[int, bool]).clear()
	print_debug("Category cleared: %s." % category)
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
		printerr("Can't add inexistent category to resource.")
		return
	var category_dict := _categories_to_ints[category] as Dictionary
	var int_id: int = ensure_int_id(id)
	if category_dict.has(int_id):
		if show_error:
			printerr("Resource already in category.")
		return
	category_dict[int_id] = true # NOTE: true is a placeholder
	print_debug("Category %s added to resource with ID %s." % [category, id])
	entries_changed.emit()


## Removes a [param category] from a resource by it's [param id].
func remove_category_from_resource(category: StringName, id: Variant, show_error := true) -> void:
	if not has_category(category):
		printerr("Can't remove resource from inexistent category.")
		return
	var category_dict: Dictionary = _categories_to_ints[category]
	var int_id: int = ensure_int_id(id)
	if not category_dict.has(int_id):
		if show_error:
			printerr("Resource (ID: %s) is not in the specified category (%s), can't remove it." % [id, category])
		return
	category_dict.erase(int_id)
	print_debug("Category %s removed from resource with ID %s." % [category, id])
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
	print_debug("Registering folder of resources: %s." % dir)
	if not DirAccess.dir_exists_absolute(dir):
		printerr("Path doesn't exist: (%s)" % dir)
		return
	var all_resource_paths: PackedStringArray = _resource_search(dir)
	for path in all_resource_paths:
		register_resource(path, true)
	print_debug("Registered folder of resources.")
	entries_changed.emit()


## Registers resources by path or UID within the database with locators.[br]
## IDs are assigned automatically, can be modified later.
func register_resource(locator: String, in_bulk := false) -> void:
	if not ResourceLoader.exists(locator):
		if not in_bulk:
			printerr("Resource doesn't exist (%s)." % locator)
		return
	
	# Try to transform locator into UID
	locator = resource_uid_from_locator(locator)
	
	if not _is_locator_inside_filters(locator):
		if not in_bulk:
			printerr("Not included in path filters (%s)." % locator)
		return
	if not _is_resource_class_valid(load(locator)):
		if not in_bulk:
			printerr("Resource class is not valid in this collection (%s)." % locator)
		return
	if not ProjectSettings.get_setting("resource_databases/allow_repeated_locators"):
		if _ints_to_locators.values().has(locator): # WARNING computer cost
			if not in_bulk:
				printerr("Can't add resource to collection, locator already registered. (%s)" % locator)
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
	if int_id < 0:
		printerr("New Int ID shouldn't be negative.")
		return
	_ints_to_strings[int_id] = file_name
	_strings_to_ints[file_name] = int_id
	_ints_to_locators[int_id] = locator
	print_debug("New resource registered: %s." % locator)
	entries_changed.emit()


## Removes a resource from the collection by it's [param id]
func unregister_resource(id: Variant) -> void:
	var int_id: int = ensure_int_id(id)
	if not _has_id(int_id):
		printerr("Can't unregister inexistent resource.")
		return
	_ints_to_locators.erase(int_id)
	for category: StringName in _categories_to_ints:
		(_categories_to_ints[category] as Dictionary).erase(int_id)
	_strings_to_ints.erase(_ints_to_strings[int_id])
	_ints_to_strings.erase(int_id)
	print_debug("Unregistered resource with ID: %s." % id)
	entries_changed.emit()


## Sets the locator of an entry to: [constant ResourceDatabaseCollection.INVALID_RESOURCE_LOCATOR][br]
## The invalid locator enables entries to act as [b]placeholders[/b].
func set_invalid_resource(id: Variant) -> void:
	var int_id: int = ensure_int_id(id)
	if not _has_id(id):
		printerr("Can't make inexistent resource invalid")
		return
	_ints_to_locators[int_id] = INVALID_RESOURCE_LOCATOR
	print_debug("Invalidated resource with ID: %s." % id)
	entries_changed.emit()
#endregion


#region Entry modification methods
## Changes the locator of a collection entry by it's [param id].
func change_resource_locator(id: Variant, locator: String) -> void:
	if not _has_id(id):
		printerr("Inexistent resource Int ID.")
		return
	if locator.is_empty():
		printerr("Empty locator provided.")
		return
	
	if not _is_locator_inside_filters(locator):
		printerr("Can't change resource locator, new locator not included within current path filters: %s." % locator)
		return
	
	var tried_uid := resource_uid_from_locator(locator)
	
	if not ProjectSettings.get_setting("resource_databases/allow_repeated_locators"):
		if _ints_to_locators.values().has(tried_uid): # WARNING compute cost
			printerr("Can't change locator, already registered: %s." % tried_uid)
			return
	
	_ints_to_locators[ensure_int_id(id)] = tried_uid
	entries_changed.emit()


## Changes a String ID from the collection.
func change_resource_string_id(old: StringName, new: StringName) -> void:
	if not _has_id(old):
		printerr("Inexistent old String ID.")
		return
	if _strings_to_ints.has(new):
		printerr("[Can't change String ID, [\"%s\"] already exists." % new)
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
		printerr("Intexistent old Int ID.")
		return
	if _has_id(new):
		printerr("Can't change Int ID, [%s] already exists." % new)
		return
	if new < 0:
		printerr("Can't change Int ID, new ID is negative.")
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
func ensure_int_id(id: Variant, show_error := true) -> int:
	match typeof(id):
		TYPE_STRING_NAME:
			if not _strings_to_ints.has(id):
				if show_error:
					printerr("String ID doesn't exist (%s)." % id)
				return -1
			return _strings_to_ints[id]
		TYPE_INT:
			if not _ints_to_locators.has(id):
				if show_error:
					printerr("Int ID doesn't exist (%s)." % id)
				return -1
			return id
		_:
			printerr("Invalid ID type.")
			return -1


func _has_id(id: Variant) -> bool:
	return ensure_int_id(id, false) != -1


## Returns data related with the entries of the collection.
func get_entries_data() -> Dictionary[StringName, Variant]:
	return {
		ints_to_strings = _ints_to_strings.duplicate(true),
		strings_to_ints = _strings_to_ints.duplicate(true),
		ints_to_locators = _ints_to_locators.duplicate(true),
		categories_to_ints = _categories_to_ints.duplicate(true),
	}


## Returns data related with the settings of the collection.
func get_settings_data() -> Dictionary[StringName, Variant]:
	return {
		valid_classes = _valid_classes.duplicate(true),
		designated_folders = _designated_folders.duplicate(true),
		included_filters = _included_filters.duplicate(true),
		excluded_filters = _excluded_filters.duplicate(true),
	}


## Returns the corresponding locator for an ID.
func get_locator(id: Variant) -> String:
	return _ints_to_locators[ensure_int_id(id)]


# Prints the collection as text, used for debugging purposes.
func _to_string() -> String:
	return """
	ints_to_strings : %s
	strings_to_ints : %s
	ints_to_locators : %s
	categories_to_ints : %s
	----------------
	valid_classes : %s
	designated_folders : %s
	included_filters : %s
	excluded_filters: %s""" % [
		_ints_to_strings,
		_strings_to_ints,
		_ints_to_locators,
		_categories_to_ints,
		_valid_classes,
		_designated_folders,
		_included_filters,
		_excluded_filters,
		]


# Tries to convert a locator into its UID if possible.
static func resource_uid_from_locator(locator: String) -> String:
	if not ResourceLoader.exists(locator):
		printerr("Tried obtaining UID from path but resource doesn't exist.")
		return ""
	
	if locator.begins_with("uid://"):
		return locator
	
	var int_uid := ResourceLoader.get_resource_uid(locator)
	if int_uid == -1: # Resource doesn't have a UID
		if ProjectSettings.get_setting("resource_databases/allow_file_paths"):
			return locator
		else:
			printerr("Can't get UID for resource, file paths not allowed.")
			return ""
	else:
		return ResourceUID.id_to_text(int_uid)


# Converts a resource locator into its path.
static func resource_path_from_locator(locator: String, show_error_on_inexistent := true) -> String:
	if not ResourceLoader.exists(locator):
		if show_error_on_inexistent:
			printerr("Tried obtaining path from uid but resource doesn't exist.")
		return ""
	
	if not locator.begins_with("uid://"):
		return locator
	
	if not ResourceUID.has_id(ResourceUID.text_to_id(locator)):
		printerr("Can't get path from UID, UID is not recognised.")
		return ""
	
	return ResourceUID.get_id_path(ResourceUID.text_to_id(locator))



## Searches for resources in a given dir.
func _resource_search(dir_path: String) -> PackedStringArray:
	var resources_found: PackedStringArray
	var dir := DirAccess.open(dir_path)
	
	for path in ResourceLoader.list_directory(dir_path):
		if (
			dir.dir_exists(path) and
			ProjectSettings.get_setting("resource_databases/recursive_folder_search")
			):
				resources_found.append_array(_resource_search(dir_path.path_join(path)))
		
		elif ResourceLoader.exists(dir_path.path_join(path)):
			resources_found.append(dir_path.path_join(path))
	
	return resources_found


## Method that returns the name of a file from its path.
func _get_file_name(path: String) -> String:
	return path.get_file().left(len(path.get_file()) - len(path.get_extension()) -1)
#endregion
