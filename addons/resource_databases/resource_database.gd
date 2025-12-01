@tool
class_name ResourceDatabase
extends Resource
## Database of resources. Load and access data dynamically![br]
## Part of the Resource Databases plugin by DarthPapalo.

## Emitted when the name of a collection is changed.
signal collection_name_changed(old: StringName, new: StringName)
## Emitted when the list of collections from the database changes.
signal collections_list_changed

const BINARY_FORMAT_EXTENSION := "gddb"
const TEXT_FORMAT_EXTENSION := "tgddb"

var _collections: Dictionary[StringName, ResourceDatabaseCollection]

## Number of entries from the database.
var db_size: int:
	get:
		var size: int = 0
		for coll: ResourceDatabaseCollection in _collections.values():
			size += coll.collection_size
		return size

## If the database has changes.[br]
## Note: This is used in the database editor provided with the plugin, modifying the database at runtime is not recommended.
var has_unsaved_changes := false: set = _set_unsaved_changes


#region Fetch methods
## Returns the resource from the given [param collection] with the given [param id].[br]
## Returns [code]null[/code] on invalid resource (An Invalid ID or resource locator will result in an error).
func fetch_data(collection: StringName, id: Variant) -> Resource:
	return get_collection(collection).fetch_resource(id)


## Returns all the data from a [param collection].[br]
## The dictionary contains [code]IntID : Resource / null[/code]
func fetch_collection_data(collection: StringName, include_invalid: bool = false) -> Dictionary[int, Resource]:
	return get_collection(collection).fetch_all_resources(include_invalid)


## Returns all the data from a [param category] of a [param collection].[br]
## The dictionary contains [code]IntID : Resource / null[/code]
func fetch_category_data(collection: StringName, category: StringName, include_invalid := false) -> Dictionary[int, Resource]:
	return get_collection(collection).fetch_category_resources(category, include_invalid)


## Return an [class Array[StringName]] with the categories of the resource with the given [param id].
func fetch_data_categories(collection: StringName, id: Variant) -> Array[StringName]:
	return get_collection(collection).get_categories_of_resource(id)
#endregion


#region Common methods
## Given an [param id] (either String or Int) of a [param collection], it will always return the [param id] as an [int].
func ensure_int_id(collection: StringName, id: Variant) -> int:
	return get_collection(collection).ensure_int_id(id)


# Used internally,updates the database's state to reflect unsaved changes.
func _set_unsaved_changes(value: bool) -> void:
	has_unsaved_changes = value
	emit_changed()


# Used internally when the collections list changes.
func _emit_collections_list_changed() -> void:
	collections_list_changed.emit()
	_set_unsaved_changes(true)
#endregion


#region Collection methods
## Returns [code]true[/code] if the database has the given [param collection].
func has_collection(collection: StringName) -> bool:
	return _collections.has(collection)

## Returns the names of the collections present in the database.
func get_collections_list() -> Array[StringName]:
	return _collections.keys()


## Returns the collection with the given [param collection_name].
func get_collection(collection_name: StringName) -> ResourceDatabaseCollection:
	if not has_collection(collection_name):
		printerr("Can't get inexistent collection from resource database. (%s)" % collection_name)
		return null
	return _collections[collection_name]


## Checks if a collection name is available in the database.
func is_collection_name_available(name: StringName) -> bool:
	return not name.is_empty() and name.is_valid_ascii_identifier() and not has_collection(name)


## Creates a collection in the database if the given name is available.
func create_collection(collection_name: StringName) -> ResourceDatabaseCollection:
	if not is_collection_name_available(collection_name):
		printerr("Can't create new collection in resource database, name is not available. (%s)" % collection_name)
		return null
	var new_collection := ResourceDatabaseCollection.new()
	_collections[collection_name] = new_collection
	_connect_collection_signals(new_collection)
	_emit_collections_list_changed()
	return new_collection


# Used interanally to update unsaved changes when collections change.
func _connect_collection_signals(collection: ResourceDatabaseCollection) -> void:
	var relevant_signals: Array[Signal] = [
		collection.entries_changed,
		collection.settings_changed,
		]
	for s in relevant_signals:
		s.connect(_set_unsaved_changes.bind(true))


## Removes a colelction from the database if it exists.
func remove_collection(collection_name: StringName) -> void:
	if not has_collection(collection_name):
		printerr("Can't rename inexistent collection from resource database. (%s)" % collection_name)
		return
	_collections.erase(collection_name)
	_emit_collections_list_changed()


## Changes the name of a collection from [param old] to [param new].
func rename_collection(old: StringName, new: StringName) -> void:
	if not has_collection(old):
		printerr("Can't rename inexistent collection from resource database. (%s)" % old)
		return
	_collections[new] = _collections[old]
	_collections.erase(old)
	collection_name_changed.emit(old, new)
	collections_list_changed.emit()
#endregion


#region Category methods
## Returns [code]true[/code] if the [param id] is inside the given [param category].[br]
## If the [param collection], [param id], or [param category] doesn't exist, returns [code]false[/code].
func is_data_in_category(collection: StringName, id: Variant, category: StringName) -> bool:
	return category in get_collection(collection).get_categories_of_resource(id)
#endregion


# TESTING
func _to_string() -> String:
	var t: String = ""
	for u in _collections:
		t = t + "%s	:	%s\n" % [u, str(_collections[u])]
	return t
