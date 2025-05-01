@tool
class_name DatabaseFormatLoader
extends ResourceFormatLoader
## Class in charge of loading resource databases files as resources inside Godot.


func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray([Database.BINARY_FORMAT_EXTENSION, Database.TEXT_FORMAT_EXTENSION])


func _load(path: String, _original_path: String, _use_sub_threads: bool, _cache_mode: int) -> Variant:
	var data: Dictionary[StringName, Dictionary]
	
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return FileAccess.get_open_error()
	
	match path.get_extension().to_lower():
		Database.BINARY_FORMAT_EXTENSION:
			data = f.get_var()
		Database.TEXT_FORMAT_EXTENSION:
			data = _parse_text_database_file(f.get_as_text(true))
	
	f.close()
	
	var n := _collections_data_to_database(data)
	if n == null:
		return ERR_INVALID_DATA
	return n


func _parse_text_database_file(text: String) -> Dictionary[StringName, Dictionary]:
	var collections_data: Dictionary[StringName, Dictionary]
	var current_collection: StringName
	
	for line in text.split("\n", false):
		line = line.strip_edges()
		if line.begins_with("@"): # New collection
			current_collection = StringName(line.substr(1))
			collections_data[current_collection] = {}
			collections_data[current_collection].ints_to_strings = {}
			collections_data[current_collection].strings_to_ints = {}
			collections_data[current_collection].ints_to_locators = {}
			collections_data[current_collection].categories_to_ints = {}
		
		elif line.begins_with("{") and line.ends_with("}"): # Valid classes
			collections_data[current_collection].valid_classes = line.left(-1).right(-1)
		
		elif line.begins_with("/"): # Designated folders
			collections_data[current_collection].designated_folders = line.substr(1)
		
		elif line.begins_with("+") or line.begins_with("-"): # Path filter
			var filter_type: StringName = &"included_filters" if line.begins_with("+") else &"excluded_filters"
			collections_data[current_collection][filter_type] = line.substr(1)
		
		elif line[0] in "0123456789": # Entry
			var entry_parts := line.split("»", false, 4)
			if not entry_parts.size() == 4:
				push_error("Invalid ResourceDatabase entry text line, skipping. (%s)" % line)
				continue
			var int_id: int = entry_parts[0].to_int()
			var string_id := StringName(entry_parts[1])
			var uid := entry_parts[2]
			var categories: Array[StringName] = string_to_names_array(entry_parts[3])
			
			collections_data[current_collection].ints_to_strings[int_id] = string_id
			collections_data[current_collection].strings_to_ints[string_id] = int_id
			collections_data[current_collection].ints_to_locators[int_id] = uid
			for category in categories:
				collections_data[current_collection].categories_to_ints[category][int_id] = true
		
		elif line.begins_with("#"): # Comment
			continue
		else:
			printerr("Unparsed line in ResourceDatabase: %s" % line)
	
	return collections_data


func _collections_data_to_database(collections_data: Dictionary[StringName, Dictionary]) -> Database:
	# TODO: Add additional validation for the dictionary
	var new_database := Database.new()
	
	for collection_name: StringName in collections_data:
		var collection_data: Dictionary = collections_data[collection_name]
		var collection: DatabaseCollection = new_database.create_collection(collection_name)
		
		# Load settings
		collection.set_valid_classes(collection_data.valid_classes)
		collection.set_path_filters(collection_data.included_filters, DatabaseCollection.PathFilterType.INCLUDE)
		collection.set_path_filters(collection_data.excluded_filters, DatabaseCollection.PathFilterType.EXCLUDE)
		
		# Create the categories
		for category: StringName in collection_data.categories_to_ints.keys():
			collection.create_category(category)
		
		# Load entries
		for int_id: int in collection_data.ints_to_strings.keys():
			var string_id: StringName = collection_data.ints_to_strings[int_id]
			var locator: String = collection_data.ints_to_locators[int_id]
			collection.register_resource(locator)
			
			# Add categories to entry
			for category: StringName in collection_data.categories_to_ints:
				if int_id in collection_data.categories_to_ints[category]:
					collection.add_category_to_resource(category, int_id)
	
	return new_database


# Transform a String into a typed Array[String]
static func string_to_strings_array(text: String) -> Array[String]:
	var typed: Array[String] = []
	text = text.replace("[", "").replace("]", "")
	for u in text.split(","):
		typed.append(u.strip_edges())
	return typed


# Transform a String into a typed Array[StringName]
static func string_to_names_array(text: String) -> Array[StringName]:
	var typed: Array[StringName] = []
	text = text.replace("[", "").replace("]", "")
	for u in text.split(","):
		typed.append(StringName(u.strip_edges()))
	return typed
