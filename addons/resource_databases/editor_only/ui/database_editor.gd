@tool
extends MarginContainer

signal database_opened
signal database_closed

const Namespace := preload("res://addons/resource_databases/editor_only/plugin_namespace.gd")

const DatabaseIO := preload("res://addons/resource_databases/database_io.gd")

const COLLECTION_CATEGORIES_DIALOG_SCENE := preload("res://addons/resource_databases/editor_only/ui/components/dialogs/collection_categories_dialog/collection_categories_dialog.tscn")
const COLLECTION_SETTINGS_DIALOG_SCENE := preload("res://addons/resource_databases/editor_only/ui/components/dialogs/collection_settings_dialog/collection_settings_dialog.tscn")

const ENTRY_CATEGORIES_DIALOG_SCENE := preload("res://addons/resource_databases/editor_only/ui/components/dialogs/entry_categories_dialog/entry_categories_dialog.tscn")

@export_subgroup("Editor components")
@export var _start_screen: CenterContainer
@export var _start_screen_version: RichTextLabel
@export var _database_path_label: RichTextLabel
@export var _database_interface_parent: Control
var _database_interface: Control
@export_subgroup("Menu buttons")
@export var _database_button: MenuButton
@export_subgroup("Dialogs")
@export var _warning_dialog: Namespace.WarningDialog
@export var _load_dialog: FileDialog
@export var _save_dialog: FileDialog
@export var _settings_dialogues_container: Node
@export var _categories_dialogues_container: Node
@export var _collection_categories_dialogues_container: Node

var loaded_database: EditorDatabase = null:
	set(v):
		loaded_database = v
		# Handle editor components visibility
		_start_screen.visible = loaded_database == null
		_database_interface_parent.visible = not _start_screen.visible
		_update_database_button_options(loaded_database != null)
		if _database_interface != null:
			_database_interface.queue_free()
			_database_interface = null
		if loaded_database != null:
			var database_interface: HSplitContainer = preload("res://addons/resource_databases/editor_only/ui/database_interface.tscn").instantiate()
			_database_interface = database_interface
			(_database_interface.get_node(^"CollectionsListView") as Namespace.CollectionsListView).setup_list()
			_database_interface_parent.add_child(_database_interface)
			_database_path_label.text = loaded_database.last_save_path
			loaded_database.saved_changes.connect(_on_database_changed.bind(true))
			loaded_database.unsaved_changes.connect(_on_database_changed.bind(false))
			database_opened.emit()
		else:
			_database_path_label.text = ""
			database_closed.emit()


func _ready() -> void:
	_database_button.get_popup().id_pressed.connect(_on_database_button_id_selected)
	_update_database_button_options(false)
	var filter_string := "*.%s;Database files" % DatabaseIO.DATABASE_FILE_EXTENSION
	_save_dialog.filters = PackedStringArray([filter_string])
	_load_dialog.filters = PackedStringArray([filter_string])


func set_plugin_version(version: String) -> void:
	_start_screen_version.text = "[i]Version: %s[/i]" % version


#region Singleton methods
func get_database_opened_signal() -> Signal:
	return database_opened


func get_database_closed_signal() -> Signal:
	return database_closed


func get_database() -> EditorDatabase:
	return loaded_database


func warn(title: String, msg: String) -> Signal:
	_warning_dialog.make_warning(title, msg)
	return _warning_dialog.decision


func open_collection_settings_dialog(collection_uid: int) -> void:
	for dialogue: Namespace.CollectionSettingsDialog in _settings_dialogues_container.get_children():
		if dialogue.collection_uid == collection_uid:
			dialogue.grab_focus()
			return
	var new_dialogue: Namespace.CollectionSettingsDialog = COLLECTION_SETTINGS_DIALOG_SCENE.instantiate()
	new_dialogue.setup_settings_dialog(collection_uid)
	_settings_dialogues_container.add_child(new_dialogue)
	new_dialogue.popup()


func open_collection_categories_dialog(collection_uid: int) -> void:
	for dialogue: Namespace.CollectionCategoriesDialog in _collection_categories_dialogues_container.get_children():
		if dialogue.collection_uid == collection_uid:
			dialogue.grab_focus()
			return
	var new_dialogue: Namespace.CollectionCategoriesDialog = COLLECTION_CATEGORIES_DIALOG_SCENE.instantiate()
	new_dialogue.setup_collection_categories_dialog(collection_uid)
	_collection_categories_dialogues_container.add_child(new_dialogue)
	new_dialogue.popup()


func open_entry_categories_dialog(collection_uid: int, entry_int_id: int) -> void:
	for dialogue: Namespace.EntryCategoriesDialog in _categories_dialogues_container.get_children():
		if dialogue.collection_uid == collection_uid and dialogue.resource_int_id == entry_int_id:
			dialogue.grab_focus()
			return
	var new_dialogue: Namespace.EntryCategoriesDialog = ENTRY_CATEGORIES_DIALOG_SCENE.instantiate()
	new_dialogue.setup_categories_dialog(collection_uid, entry_int_id)
	_categories_dialogues_container.add_child(new_dialogue)
	new_dialogue.popup()
#endregion


#region Database menu button
func _on_database_button_id_selected(id: int) -> void:
	var menu := _database_button.get_popup()
	(menu.get_item_metadata(menu.get_item_index(id)) as Callable).call()


func _update_database_button_options(is_db_loaded: bool) -> void:
	var menu := _database_button.get_popup()
	menu.clear()
	menu.add_item("New", 0)
	menu.set_item_metadata(0, new_database)
	menu.add_item("Load", 1)
	menu.set_item_metadata(1, load_database)
	menu.add_separator()
	menu.add_item("Save", 3)
	menu.set_item_metadata(3, save_database)
	menu.add_item("Save As...", 4)
	menu.set_item_metadata(4, save_database.bind(true))
	menu.add_separator()
	menu.add_item("Close", 6)
	menu.set_item_metadata(6, close_database)
	if not is_db_loaded:
		menu.set_item_disabled(3, true)
		menu.set_item_disabled(4, true)
		menu.set_item_disabled(6, true)
#endregion


#region Database management
func _on_database_changed(is_saved: bool) -> void:
	_database_path_label.text = "%s%s" % ["" if is_saved else "[i]*", loaded_database.last_save_path]


func close_database() -> void:
	if loaded_database == null:
		return
	if loaded_database.has_unsaved_changes or (
		not loaded_database.last_save_path.is_empty() and not FileAccess.file_exists(loaded_database.last_save_path)
	):
		warn("Unsaved changes in Database",
		"You have unsaved changes in the current database,\nare you sure you want to close it?")
		if not await _warning_dialog.decision:
			return
	loaded_database = null


## Creates a new Database notifying the user if any data might be lost.
func new_database() -> void:
	if loaded_database != null:
		if loaded_database.has_unsaved_changes:
			if not await warn("Unsaved changes in Database!",
			"You have unsaved changes in the current database,\nare you sure you want to create a new one?"):
				return
	loaded_database = EditorDatabase.new()


## Loads a database into the editor using a file path.
func load_database(path := "") -> void:
	if loaded_database != null: # Has loaded
		if loaded_database.has_unsaved_changes:
			if not await warn("Unsaved changes in Database!",
			"You have unsaved changes in the current database,\nare you sure you want to load a new one?"):
				return
	if path.is_empty():
		_load_dialog.popup()
		return
	loaded_database = EditorDatabase.load_from_file(path)


# Callback for the load dialog.
func _on_load_database_file_dialog_file_selected(path: String) -> void:
	loaded_database = EditorDatabase.load_from_file(path)


## Saves the currently loaded database to its last save path.
## Opens the save dialog if [code]force_dialog = true[/code] or
## if the database was never saved.
func save_database(force_dialog: bool = false) -> void:
	if not loaded_database:
		return
	if loaded_database.last_save_path.is_empty() or force_dialog:
		_save_dialog.popup()
	else:
		loaded_database.save_to_file(loaded_database.last_save_path)


# Callback for the save dialog.
func _on_save_database_file_dialog_file_selected(path: String) -> void:
	loaded_database.save_to_file(path)
#endregion
