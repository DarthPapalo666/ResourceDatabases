@tool
extends MarginContainer

const Namespace := preload("res://addons/resource_databases/editor_only/plugin_namespace.gd")

const DATABASE_COLLECTION_LIST_VIEW_SCENE := preload("uid://bblabb1i6dmcp")
const DATABASE_COLLECTION_VIEW_SCENE := preload("uid://c6snrkt0lx7rr")

const COLLECTION_CATEGORIES_DIALOG_SCENE := preload("res://addons/resource_databases/editor_only/ui/components/dialogs/collection_categories_dialog/collection_categories_dialog.tscn")
const COLLECTION_SETTINGS_DIALOG_SCENE := preload("res://addons/resource_databases/editor_only/ui/components/dialogs/collection_settings_dialog/collection_settings_dialog.tscn")

const ENTRY_CATEGORIES_DIALOG_SCENE := preload("res://addons/resource_databases/editor_only/ui/components/dialogs/entry_categories_dialog/entry_categories_dialog.tscn")

@export_subgroup("Editor components")
@export var _start_screen: CenterContainer
@export var _start_screen_version: RichTextLabel
@export var _database_path_label: RichTextLabel
var _collections_list_view: Namespace.CollectionsListView
var _embedded_collection_view: Namespace.CollectionView

@export_subgroup("Menu buttons")
@export var _database_button: MenuButton
@export_subgroup("Dialogs")
@export var _warning_dialog: Namespace.WarningDialog
@export var _load_dialog: FileDialog
@export var _save_dialog: FileDialog
@export var _settings_dialogues_container: Node
@export var _categories_dialogues_container: Node
@export var _collection_categories_dialogues_container: Node


var loaded_database: Database = null:
	set(v):
		loaded_database = v
		_collections_list_view = DATABASE_COLLECTION_LIST_VIEW_SCENE.instantiate()
		_collections_list_view.collection_selected.connect(_on_collection_selected)
		_collections_list_view.database_editor = self


func _ready() -> void:
	_database_button.get_popup().id_pressed.connect(_on_database_button_id_selected)
	_update_database_button_options()
	var filters_array := PackedStringArray([
		"*.%s ; Text Database Files" % Database.TEXT_FORMAT_EXTENSION,
		"*.%s ; Binary Database Files" % Database.BINARY_FORMAT_EXTENSION,
	])
	_save_dialog.filters = filters_array
	_save_dialog.file_selected.connect(
		func(path: String) -> void:
			ResourceSaver.save(loaded_database, path)
	)
	_load_dialog.filters = filters_array
	_load_dialog.files_selected.connect(
		func(path: String) -> void:
			loaded_database = load(path)
	)


# Sets the tag on the StartScreen to view the plugin version.
func set_plugin_version(version: String) -> void:
	_start_screen_version.text = "[i]Version: %s[/i]" % version


# Creates a warning and returns a signal you can await for the decision.
func warn(title: String, msg: String) -> Signal:
	return _warning_dialog.make_warning(title, msg)


func open_collection_settings_dialog(collection_name: StringName) -> void:
	var collection := loaded_database.get_collection(collection_name)
	for dialogue: Namespace.CollectionSettingsDialog in _settings_dialogues_container.get_children():
		if dialogue.collection == collection:
			dialogue.grab_focus()
			return
	var new_dialogue: Namespace.CollectionSettingsDialog = COLLECTION_SETTINGS_DIALOG_SCENE.instantiate()
	new_dialogue.setup_settings_dialog(self, collection_name)
	_settings_dialogues_container.add_child(new_dialogue)
	new_dialogue.popup()


func open_collection_categories_dialog(collection_name: StringName) -> void:
	var collection := loaded_database.get_collection(collection_name)
	for dialogue: Namespace.CollectionCategoriesDialog in _collection_categories_dialogues_container.get_children():
		if dialogue.collection == collection:
			dialogue.grab_focus()
			return
	var new_dialogue: Namespace.CollectionCategoriesDialog = COLLECTION_CATEGORIES_DIALOG_SCENE.instantiate()
	new_dialogue.setup_collection_categories_dialog(self, collection_name)
	_collection_categories_dialogues_container.add_child(new_dialogue)
	new_dialogue.popup()


func open_entry_categories_dialog(collection_name: StringName, entry_int_id: int) -> void:
	var collection := loaded_database.get_collection(collection_name)
	for dialogue: Namespace.EntryCategoriesDialog in _categories_dialogues_container.get_children():
		if dialogue.collection == collection and dialogue.resource_int_id == entry_int_id:
			dialogue.grab_focus()
			return
	var new_dialogue: Namespace.EntryCategoriesDialog = ENTRY_CATEGORIES_DIALOG_SCENE.instantiate()
	new_dialogue.setup_categories_dialog(collection, entry_int_id)
	_categories_dialogues_container.add_child(new_dialogue)
	new_dialogue.popup()
#endregion


#region Database menu button
# Callback for the database menu buttons popup.
func _on_database_button_id_selected(id: int) -> void:
	var menu := _database_button.get_popup()
	(menu.get_item_metadata(menu.get_item_index(id)) as Callable).call()

# Updates the database menu button options.
func _update_database_button_options() -> void:
	var menu := _database_button.get_popup()
	menu.clear()
	menu.add_item("New", 0)
	menu.set_item_metadata(0, create_new_database)
	menu.add_item("Load", 1)
	menu.set_item_metadata(1, load_database)
	menu.add_separator()
	menu.add_item("Save", 3)
	menu.set_item_metadata(3, save_database)
	menu.add_item("Save As...", 4)
	menu.set_item_metadata(4, save_database.bind(true))
	menu.add_separator()
	menu.add_item("Close", 6)
	menu.set_item_metadata(6, close_loaded_database)
	if loaded_database == null:
		menu.set_item_disabled(3, true)
		menu.set_item_disabled(4, true)
		menu.set_item_disabled(6, true)
#endregion


#region Database management
# Callback for when the database changes.
func _on_database_changed(is_saved: bool) -> void:
	_database_path_label.text = "%s%s" % ["" if is_saved else "[i]*", loaded_database.last_save_path]

# Closes the currently loaded database if any is loaded.
func close_loaded_database() -> void:
	if loaded_database == null:
		return
	if (
		loaded_database.has_unsaved_changes or
		loaded_database.last_save_path.is_empty()
	):
		if await warn(
			"Unsaved changes in Database",
			"You have unsaved changes in the current database,\nare you sure you want to close it?"
		):
			loaded_database = null


# Creates a new Database notifying the user if any data might be lost.
func create_new_database() -> void:
	if loaded_database != null:
		if loaded_database.has_unsaved_changes:
			if not await warn(
				"Unsaved changes in Database!",
				"You have unsaved changes in the current database,\nare you sure you want to create a new one?"
			):
				return
	loaded_database = Database.new()


# Loads a database into the editor. If the path is empty, the load_dialog will be prompted.
func load_database(path := "") -> void:
	if loaded_database != null and loaded_database.has_unsaved_changes:
		if not await warn(
			"Unsaved changes in Database!",
			"You have unsaved changes in the current database,\nare you sure you want to load a new one?"
		):
			return
	if path.is_empty():
		_load_dialog.popup()
		return
	loaded_database = load(path)


# Saves the currently loaded database to its last save path.
# Opens the save dialog if [code]force_dialog = true[/code] or
# if the database was never saved.
func save_database(force_dialog := false) -> void:
	if not loaded_database:
		return
	if loaded_database.last_save_path.is_empty() or force_dialog:
		_save_dialog.popup()
	else:
		ResourceSaver.save(loaded_database, loaded_database.last_save_path)
#endregion


func _on_collection_selected(collection_name: StringName, embedded: bool) -> void:
	assert(loaded_database.has_collection(collection_name))
	var collection =  loaded_database.get_collection(collection_name)
	var new_collection_view: Namespace.CollectionView = DATABASE_COLLECTION_VIEW_SCENE.instantiate()
	new_collection_view.database_editor = self
	new_collection_view.current_collection = collection
	new_collection_view.current_collection_name = collection_name
	
	if embedded:
		_collections_list_view.selected_collection = collection_name
		_embedded_collection_view = new_collection_view
		# TODO add child
	else:
		pass # TODO floating windows
		
	
	
