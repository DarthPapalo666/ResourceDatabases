@tool
class_name DatabaseFormatLoader
extends ResourceFormatLoader
## Class in charge of loading resource database files as resources inside Godot.

const DatabaseIO := preload("res://addons/resource_databases/database_io.gd")


func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray([DatabaseIO.DATABASE_FILE_EXTENSION])


func _get_resource_type(path: String) -> String:
	var ext := path.get_extension().to_lower()
	if ext in _get_recognized_extensions():
		return "Resource"
	return ""


func _get_resource_script_class(path:String) -> String:
	return "Database"


func _handles_type(type: StringName) -> bool:
	return ClassDB.is_parent_class(type, "Resource")


func _load(path: String, _original_path: String, _use_sub_threads: bool, _cache_mode: int) -> Variant:
	var n := Database.new()
	var data: Variant = DatabaseIO.load_database_data(path)
	if data == null:
		return ERR_PARSE_ERROR
	if typeof(data) != TYPE_DICTIONARY:
		return ERR_INVALID_DATA
	n._collections_data = data as Dictionary
	return n
