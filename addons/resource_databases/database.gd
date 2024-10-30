class_name Database
extends Resource
## Database of resources. Load and access data dynamically![br]
## Part of the [i]Resource Databases[/i] plugin by DarthPapalo.

## Locator for invalid resources. (Invalid resources are not fetched and don't push errors.)
const INVALID_RESOURCE_LOCATOR := "<invalid>"

var _collections_data: Dictionary


## Given an [param id] (either String or Int) of a [param collection], it will always return the [param id] as an [int].
func get_int_id(collection: StringName, id: Variant) -> int:
	match typeof(id):
		TYPE_STRING_NAME:
			assert(_has_string_id(collection, id as StringName), "[ResourceDatabase] Error getting Int ID from String ID.")
			return _collections_data[collection][&"strings_to_ints"][id as StringName]as int
		TYPE_INT:
			assert(_has_int_id(collection, id as int), "[ResourceDatabase] Int ID doesn't exist.")
			return id as int
		_:
			assert(false, "[ResourceDatabase] Invalid ID type.")
	return -1


#region Fetch data methods
## Returns the resource from the given [param collection] and the given [param id].[br]
## Returns [code]null[/code] on invalid resource (An Invalid ID or resource locator will result in an error).
func fetch_data(collection: StringName, id: Variant) -> Resource:
	var int_id: int = get_int_id(collection, id)
	var res_path := _collections_data[collection][&"ints_to_locators"][int_id] as String
	if res_path == INVALID_RESOURCE_LOCATOR:
		return null
	assert(ResourceLoader.exists(res_path), "[ResourceDatabase] Error, can't load non-invalid resource.")
	return load(res_path)


## Returns the resource associated with a DB path:[br]
## [codeblock]
## # Get a resource from a collection:
## var item1_data := my_database.fetch_data_string("items/item1") # Resource or null
##
## # Get all resources from a collection with a specific category:
## var usable_items_data := my_database.fetch_data_string("items:usable") # Dictionary with int_id : resource
## [/codeblock]
## Pushes an error if the string is invalid.
func fetch_data_string(string: String) -> Variant:
	var valid_string_id := RegEx.create_from_string(r"[A-Za-z_][A-Za-z_0-9]*\/[A-Za-z_][A-Za-z_0-9]*").search(string) != null
	var valid_category := RegEx.create_from_string(r"[A-Za-z_][A-Za-z_0-9]*:[A-Za-z_][A-Za-z_0-9]*").search(string) != null
	assert((valid_string_id or valid_category) and not (valid_string_id and valid_category), "[ResourceDatabase] Can't fetch data string, invalid format.")
	var parts := string.split("/" if valid_string_id else ":", false)
	assert(parts.size() == 2, "[ResourceDatabase] Can't fetch data string, invalid format.")
	if valid_string_id:
		return fetch_data(StringName(parts[0]), StringName(parts[1]))
	elif valid_category:
		return fetch_category_data(StringName(parts[0]), StringName(parts[1]))
	return null


## Returns all the data from a [param collection].[br]
## The dictionary contains [code]Int ID : Resource/null[/code]
func fetch_collection_data(collection: StringName) -> Dictionary:
	assert(_has_collection(collection), "Can't fetch inexistent collection")
	var result := {}
	var locators_dict: Dictionary = _collections_data[collection][&"ints_to_locators"]
	for int_id: int in locators_dict:
		var data := fetch_data(collection, int_id)
		if data != null:
			result[int_id] = data
	return result


## Returns all the data from a [param category] of a [param collection].[br]
## The dictionary contains [code]Int ID : Resource/null[/code]
func fetch_category_data(collection: StringName, category: StringName) -> Dictionary:
	assert(_has_category(collection, category), "[ResourceDatabase] Can't fetch category data from inexistent category.")
	var result := {}
	for int_id: int in _collections_data[collection][&"categories_to_ints"][category]:
		var data := fetch_data(collection, int_id)
		if data != null:
			result[int_id] = data
	return result
#endregion


#region Category related methods
## Returns [code]true[/code] if the [param id] is inside the given [param category].[br]
## If the [param collection], [param id], or [param category] doesn't exist, returns [code]false[/code].
func is_data_in_category(collection: StringName, id: Variant, category: StringName) -> bool:
	var int_id: int = get_int_id(collection, id)
	assert(_has_category(collection, category), "[ResourceDatabase] Error, category doesn't exist.")
	return (_collections_data[collection][&"categories_to_ints"][category] as Dictionary).has(int_id)


## Return an [class Array[StringName]]
func get_data_categories(collection: StringName, id: Variant) -> Array[StringName]:
	var int_id: int = get_int_id(collection, id)
	var result: Array[StringName]
	for category: StringName in (_collections_data[collection][&"categories_to_ints"] as Dictionary):
		if (_collections_data[collection][&"categories_to_ints"][category] as Dictionary).has(int_id):
			result.append(category)
	return result
#endregion


#region Has methods
# Returns [code]true[/code] if the database has the given [param collection].
func _has_collection(collection: StringName) -> bool:
	return _collections_data.has(collection)


func _has_category(collection: StringName, category: StringName) -> bool:
	assert(_has_collection(collection), "[ResourceDatabase] Can't access inexistent collection \"%s\"" % collection)
	return (_collections_data[collection][&"categories_to_ints"] as Dictionary).has(category)


# Returns [code]true[/code] if the [param collection] has the given [param int_id].
func _has_int_id(collection: StringName, int_id: int) -> bool:
	assert(_has_collection(collection), "[ResourceDatabase] Can't access inexistent collection \"%s\"" % collection)
	return (_collections_data[collection][&"ints_to_locators"] as Dictionary).has(int_id)


# Returns [code]true[/code] if the [param collection] has the given [param string_id].
func _has_string_id(collection: StringName, string_id: StringName) -> bool:
	assert(_has_collection(collection), "[ResourceDatabase] Can't access inexistent collection \"%s\"" % collection)
	return (_collections_data[collection][&"strings_to_ints"] as Dictionary).has(string_id)
#endregion
