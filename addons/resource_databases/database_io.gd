@tool
const DATABASE_FILE_EXTENSION := "gddb"


static func export_database_data(path: String, data: Dictionary) -> bool:
	if not path.get_extension() == DATABASE_FILE_EXTENSION:
		print_rich("[color=orange][DatabaseIO] [color=red]Can't export database, invalid file path.")
		return false
	if not _is_database_data_valid(data):
		print_rich("[color=orange][DatabaseIO] [color=red]Can't export database, invalid data.")
		return false
	var f := FileAccess.open(path, FileAccess.WRITE)
	if not f:
		printerr(FileAccess.get_open_error())
		return false
	f.store_var(data)
	f.close()
	# Update cached reference
	if ResourceLoader.has_cached(path):
		# ResourceLoader.load with CACHE_MODE_REPLACE doesn't replace cache at all...
		# We have to take_over_path with an un-updated resource copy to actually change the cache
		# This is solved in 2.0 by using a proper ResourceFormatSaver
		load(path).duplicate().take_over_path(path)
	return true


static func load_database_data(path: String) -> Variant:
	if not path.get_extension() == DATABASE_FILE_EXTENSION:
		print_rich("[color=orange][DatabaseIO] [color=red]Can't load database, invalid file path.")
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		printerr(FileAccess.get_open_error())
		return null
	var data: Variant = f.get_var()
	f.close()
	if not _is_database_data_valid(data):
		print_rich("[color=orange][DatabaseIO] [color=red]Can't load database, invalid data.")
		return null
	return data as Dictionary


static func _is_database_data_valid(data: Variant) -> bool:
	if not typeof(data) == TYPE_DICTIONARY:
		return false
	for collection_name: StringName in data:
		if typeof(data[collection_name]) != TYPE_DICTIONARY:
			return false
		if not (data[collection_name] as Dictionary).has_all([&"ints_to_strings", &"strings_to_ints", &"ints_to_locators", &"categories_to_ints"]):
			return false
	return true
