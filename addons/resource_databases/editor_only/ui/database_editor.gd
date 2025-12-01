@tool
extends MarginContainer
## Main UI for the database editor included in the ResourceDatabases plugin.
## All access to database data is through this class loaded_database variable.
## If loaded_database == null the database should be removed from memory.


const Namespace := preload("uid://b7ra0aicagaes")

const DATABASE_COLLECTION_LIST_VIEW_SCENE := preload("uid://bblabb1i6dmcp")
const DATABASE_COLLECTION_VIEW_SCENE := preload("uid://c6snrkt0lx7rr")

const COLLECTION_CATEGORIES_DIALOG_SCENE := preload("uid://qketvrxgm0ya")
const COLLECTION_SETTINGS_DIALOG_SCENE := preload("uid://c47p7j84pq5ci")

const ENTRY_CATEGORIES_DIALOG_SCENE := preload("uid://i0c2m81nxr42")

@export_subgroup("Editor components")
@export var _start_screen: CenterContainer
@export var _start_screen_version: RichTextLabel
@export var _database_path_label: RichTextLabel
@export var _database_view: SplitContainer
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


var loaded_database: ResourceDatabase = null:
	set(v):
		if v == loaded_database:
			print_debug("ResourceDatabase already opened.")
			return
		
		loaded_database = v
		#print_debug("Loaded database changed:\n%s" % loaded_database)
		
		# Clean UI
		for child: Node in _database_view.get_children():
			child.queue_free()
		
		_start_screen.visible = loaded_database == null
		_database_view.visible = loaded_database != null
		
		_update_database_button_options()
		
		if loaded_database != null: # ResourceDatabase opened
			# Add the CollectionsListView
			_collections_list_view = DATABASE_COLLECTION_LIST_VIEW_SCENE.instantiate()
			_collections_list_view.collection_selected.connect(_on_collection_selected)
			_collections_list_view.setup_collections_list_view(self)
			_database_view.add_child(_collections_list_view)
			
			loaded_database.changed.connect(_on_database_changed)
		
		_on_database_changed()


func _ready() -> void:
	_database_button.get_popup().id_pressed.connect(_on_database_button_id_selected)
	_update_database_button_options()
	var filters_array := PackedStringArray([
		"*.%s ; Text ResourceDatabase Files" % ResourceDatabase.TEXT_FORMAT_EXTENSION,
		"*.%s ; Binary ResourceDatabase Files" % ResourceDatabase.BINARY_FORMAT_EXTENSION,
	])
	_save_dialog.filters = filters_array
	_save_dialog.file_selected.connect(
		func(path: String) -> void:
			ResourceSaver.save(loaded_database, path, ResourceSaver.FLAG_CHANGE_PATH)
			loaded_database.has_unsaved_changes = false
	)
	_load_dialog.filters = filters_array
	_load_dialog.file_selected.connect(
		func(path: String) -> void:
			loaded_database = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	)
	$VBoxContainer/EditorTopBar/HBoxContainer/DebugButton.pressed.connect(_debug)


#region DatabaseEditor methods
# Sets the tag on the StartScreen to view the plugin version.
func set_plugin_version(version: String) -> void:
	_start_screen_version.text = "[i]Version: %s[/i]" % version


# Creates a warning and returns a signal you can await for the decision.
func warn(warning: StringName, params: Array[String] = []) -> Signal:
	var error_msg: Array[String]
	error_msg.assign(Namespace.WARNING_MSGS[warning])
	return _warning_dialog.make_warning(error_msg[0], error_msg[1] % params)


func open_collection_settings_dialog(collection_name: StringName) -> void:
	for dialogue: Namespace.CollectionSettingsDialog in _settings_dialogues_container.get_children():
		if dialogue.get_collection_name() == collection_name:
			dialogue.grab_focus()
			return
	var new_dialogue: Namespace.CollectionSettingsDialog = COLLECTION_SETTINGS_DIALOG_SCENE.instantiate()
	new_dialogue.setup_settings_dialog(self, collection_name)
	_settings_dialogues_container.add_child(new_dialogue)
	new_dialogue.popup()


func open_collection_categories_dialog(collection_name: StringName) -> void:
	for dialogue: Namespace.CollectionCategoriesDialog in _collection_categories_dialogues_container.get_children():
		if dialogue.get_collection_name() == collection_name:
			dialogue.grab_focus()
			return
	var new_dialogue: Namespace.CollectionCategoriesDialog = COLLECTION_CATEGORIES_DIALOG_SCENE.instantiate()
	new_dialogue.setup_collection_categories_dialog(self, collection_name)
	_collection_categories_dialogues_container.add_child(new_dialogue)
	new_dialogue.popup()


func open_entry_categories_dialog(collection_name: StringName, entry_int_id: int) -> void:
	for dialogue: Namespace.EntryCategoriesDialog in _categories_dialogues_container.get_children():
		if dialogue.get_collection_name() == collection_name and dialogue.get_int_id() == entry_int_id:
			dialogue.grab_focus()
			return
	var new_dialogue: Namespace.EntryCategoriesDialog = ENTRY_CATEGORIES_DIALOG_SCENE.instantiate()
	new_dialogue.setup_entry_categories_dialog(self, collection_name, entry_int_id)
	_categories_dialogues_container.add_child(new_dialogue)
	new_dialogue.popup()
#endregion


#region ResourceDatabase menu button
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


#region ResourceDatabase management
# Callback for when the database changes.
func _on_database_changed() -> void:
	if loaded_database == null:
		_database_path_label.text = ""
	else:
		_database_path_label.text = "%s%s" % [
			"[i]*" if loaded_database.has_unsaved_changes else "",
			"unnamed_database" if loaded_database.resource_path.is_empty() else loaded_database.resource_path
		]


# Closes the currently loaded database if any is loaded.
func close_loaded_database() -> void:
	if loaded_database == null:
		return
	if (
		loaded_database.has_unsaved_changes or
		loaded_database.resource_path.is_empty()
	):
		if not await warn(&"unsaved_database"):
			return
	loaded_database = null


# Creates a new ResourceDatabase notifying the user if any data might be lost.
func create_new_database() -> void:
	if loaded_database != null:
		if loaded_database.has_unsaved_changes:
			if not await warn(&"unsaved_database"):
				return
	loaded_database = ResourceDatabase.new()


# Prompts the load dialog.
func load_database() -> void:
	print_debug("Loading database with dialog.")
	if loaded_database != null and loaded_database.has_unsaved_changes:
		if not await warn(&"unsaved_database"):
			return
	_load_dialog.popup()


# Saves the currently loaded database to its last save path.
# Opens the save dialog if [code]force_dialog = true[/code] or
# if the database was never saved.
func save_database(force_dialog := false) -> void:
	if not loaded_database:
		return
	if loaded_database.resource_path.is_empty() or force_dialog:
		_save_dialog.popup()
	else:
		ResourceSaver.save(loaded_database, loaded_database.resource_path, ResourceSaver.FLAG_CHANGE_PATH)
		loaded_database.has_unsaved_changes = false
#endregion


# Manages what happens when a collection is selected.
func _on_collection_selected(collection_name: StringName, embedded: bool) -> void:
	assert(loaded_database.has_collection(collection_name) and
			_collections_list_view != null)
	
	print_debug("Loading new collection view for: %s" % collection_name)
	var new_collection_view: Namespace.CollectionView = DATABASE_COLLECTION_VIEW_SCENE.instantiate()
	new_collection_view.setup_collection_view(self, collection_name)
	
	if embedded:
		# Free previous collection view
		if _embedded_collection_view != null:
			_embedded_collection_view.queue_free()

		# As is embedded, set it as selected in the collection list view
		_collections_list_view.selected_collection = collection_name
		
		# Add the new collection view to the editor UI
		_embedded_collection_view = new_collection_view
		_database_view.add_child(_embedded_collection_view)
	else:
		pass # TODO floating windows

# TESTING
func _debug() -> void:
	print(loaded_database)
