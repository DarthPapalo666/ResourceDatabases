@tool
class_name DatabaseFormatSaver
extends ResourceFormatSaver


func _save(resource: Resource, path: String, flags: int) -> Error:
	if resource is not Database:
		return ERR_INVALID_PARAMETER
	var database := resource as Database
	
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return f.get_open_error()
	
	match path.get_extension():
		Database.BINARY_FORMAT_EXTENSION:
			var database_data: Dictionary[StringName, Dictionary]
			for collection_name: StringName in database.get_collections_list():
				var data := {}
				data.merge(database.get_collection(collection_name).get_entries_data())
				data.merge(database.get_collection(collection_name).get_settings_data())
				database_data[collection_name] = data
			f.store_var(database_data)
		Database.TEXT_FORMAT_EXTENSION:
			var text := ""
			for collection_name: StringName in database.get_collections_list():
				var collection = database.get_collection(collection_name)
				var collection_entries = collection.get_entries_data()
				var collection_settings = collection.get_settings_data()
				
				f.store_line("@%s" % var_to_str(collection_name))
				f.store_line("v%s" % var_to_str(collection_settings.valid_classes))
				f.store_line("d%s" % var_to_str(collection_settings.designated_folders))
				f.store_line("+%s" % var_to_str(collection_settings.included_filters))
				f.store_line("-%s" % var_to_str(collection_settings.excluded_filters))

				for int_id: int in collection_entries.ints_to_strings.keys():
					var string_id: StringName = collection_entries.ints_to_strings[int_id]
					var locator: String = collection_entries.ints_to_locators[int_id]
					var categories: Array[StringName] = []
					for category: StringName in collection_entries.categories_to_ints:
						if int_id in collection_entries.categories_to_ints[category]:
							categories.append(category)
					f.store_line("%d»%s»%s»%s" % [
						int_id, # TODO: maybe add padding depending on the db_size
						var_to_str(string_id),
						locator,
						var_to_str(categories)
					])
				f.store_line("")
		_:
			return ERR_FILE_BAD_PATH
	return OK
