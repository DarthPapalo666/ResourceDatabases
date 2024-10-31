@tool
class_name EditorDatabase
## Editor class to edit resource databases.

signal collections_list_changed(collection_uids: Array[int])
signal saved_changes
signal unsaved_changes

const DatabaseIO := preload("res://addons/resource_databases/database_io.gd")

var has_unsaved_changes := true:
	set(v):
		has_unsaved_changes = v
		if has_unsaved_changes:
			unsaved_changes.emit()
		else:
			saved_changes.emit()

var last_save_path: String

var _collections: Dictionary

var _all_collection_names := {}

var db_size: int:
	get:
		var size: int = 0
		for coll: EditorDatabaseCollection in _collections.values():
			size += coll.collection_size
		return size


#region Save/Export
static func load_from_file(path: String) -> EditorDatabase:
	var data := DatabaseIO.load_database_data(path)
	var editor_db: EditorDatabase
	if data.is_empty():
		editor_db = EditorDatabase.new()
	else:
		editor_db = EditorDatabase.load_serialized(data)
	editor_db.last_save_path = path
	editor_db.has_unsaved_changes = false
	print_rich("[color=lawngreen]Database loaded successfully at: [color=yellow]%s" % path)
	return editor_db


func save_to_file(path: String) -> void:
	var was_succesful := DatabaseIO.export_database_data(path, serialize())
	last_save_path = path if was_succesful else last_save_path
	has_unsaved_changes = not was_succesful
	if was_succesful:
		print_rich("[color=lawngreen]Database exported succesfully!")
	if not has_unsaved_changes:
		EditorInterface.get_resource_filesystem().scan_sources()
#endregion


#region Collections management
func has_collection(collection_uid: int) -> bool:
	return _collections.has(collection_uid)


func get_collection(collection_uid: int) -> EditorDatabaseCollection:
	assert(has_collection(collection_uid), "Can't return inexistent collection")
	return _collections[collection_uid]


func get_all_collection_uids() -> Array[int]:
	var typed: Array[int]
	typed.assign(_collections.keys())
	return typed


func _generate_collection_uid() -> int:
	var uid := randi()
	while uid in _collections or uid == -1:
		uid = randi()
	return uid


func is_collection_name_available(name: StringName) -> bool:
	return not name.is_empty() and name.is_valid_identifier() and name not in _all_collection_names


func create_collection(collection_name: StringName) -> int:
	assert(is_collection_name_available(collection_name))
	var collection_uid := _generate_collection_uid()
	var new_collection := EditorDatabaseCollection.new(collection_name, _all_collection_names)
	_collections[collection_uid] = new_collection
	_connect_collection_signals(collection_uid, new_collection)
	_emit_collections_list_changed()
	return collection_uid


func remove_collection(collection_uid: int) -> void:
	if not has_collection(collection_uid):
		print_rich("[color=orange]Can't remove inexistent collection.")
		return
	_collections.erase(collection_uid)
	_emit_collections_list_changed()


func _connect_collection_signals(uid: int, collection: EditorDatabaseCollection) -> void:
	collection.name_changed.connect(_collection_changed.unbind(1))
	collection.entries_changed.connect(_collection_changed.unbind(1))
	collection.settings_changed.connect(_collection_changed.unbind(1))
	collection.categories_changed.connect(_collection_changed.unbind(1))
#endregion


#region Signals emission methods
func _emit_collections_list_changed() -> void:
	var typed: Array[int]
	typed.assign(_collections.keys())
	collections_list_changed.emit(typed)
	has_unsaved_changes = true


func _collection_changed() -> void:
	has_unsaved_changes = true
#endregion


#region Serialization
func serialize() -> Dictionary:
	var database_data: Dictionary
	for collection: EditorDatabaseCollection in _collections.values():
		assert(not database_data.has(collection.name), "Error while serializing DB, repeated collection name.")
		database_data[collection.name] = collection.serialize()
	return database_data


static func load_serialized(data: Dictionary) -> EditorDatabase:
	var n := EditorDatabase.new()
	for collection_name: StringName in data:
		var loaded_collection := EditorDatabaseCollection.load_serialized(collection_name,
		data[collection_name],
		n._all_collection_names)
		var uid := n._generate_collection_uid()
		n._collections[uid] = loaded_collection
		n._connect_collection_signals(uid, loaded_collection)
	return n
#endregion


func _to_string() -> String:
	return """
	%s
	""" % _collections
