@tool
extends Window

const Namespace := preload("res://addons/resource_databases/editor_only/plugin_namespace.gd")

const CATEGORY_BUTTON_SCENE := preload("res://addons/resource_databases/editor_only/ui/components/dialogs/category_button/category_button.tscn")

@export var _new_category_line_edit: LineEdit
@export var _create_category_button: Button
@export var _categories_container: HFlowContainer

var _database_editor: Namespace.DatabaseEditor:
	set(v):
		_database_editor = v
		_database_editor.loaded_database.collection_name_changed.connect(_on_collection_name_changed)
		_database_editor.loaded_database.collections_list_changed.connect(_on_collections_list_changed)

var _collection_name: StringName:
	set(v):
		_collection_name = v
		_collection.entries_changed.connect(_update_categories) # NOTE might reconnect on rename
		_update_categories(_collection.get_entries_data())
		title = "%s categories" % String(_collection_name).capitalize()

var _collection: DatabaseCollection:
	get:
		return _database_editor.loaded_database.get_collection(_collection_name)

var _correctly_initialized := false


func setup_collection_categories_dialog(pdatabase_editor: Namespace.DatabaseEditor, pcollection_name: StringName) -> void:
	_database_editor = pdatabase_editor
	_collection_name = pcollection_name
	_correctly_initialized = true


func get_collection_name() -> StringName:
	return _collection_name


func _ready() -> void:
	assert(_correctly_initialized)
	_new_category_line_edit.text_changed.connect(_on_new_category_line_edit_text_changed)
	_create_category_button.pressed.connect(_on_create_category_button_pressed)


#region Collection callbacks
func _on_collection_name_changed(old: StringName, new: StringName) -> void:
	if old == _collection_name:
		_collection_name = new


func _on_collections_list_changed() -> void:
	if _collection_name not in _database_editor.loaded_database.get_collections_list():
		queue_free()


func _update_categories(entries_data: Dictionary) -> void:
	var categories: Dictionary[StringName, Dictionary] = entries_data.categories_to_ints
	for child: Node in _categories_container.get_children():
		child.queue_free()
	for category: StringName in categories:
		var new_button: Namespace.CategoryButton = CATEGORY_BUTTON_SCENE.instantiate()
		new_button.setup_category(category, false)
		new_button.clicked.connect(_on_remove_category_button_clicked)
		_categories_container.add_child(new_button)


func _on_remove_category_button_clicked(category: StringName, _added: bool) -> void:
	if await _database_editor.warn(&"remove_category", [String(category)]):
		_collection.remove_category(category)
	grab_focus()
#endregion


#region Button callbacks
func _on_new_category_line_edit_text_changed(new_text: String) -> void:
	_create_category_button.disabled = not _collection.is_category_name_available(StringName(new_text))


func _on_create_category_button_pressed() -> void:
	_collection.create_category(_new_category_line_edit.text)
	_new_category_line_edit.text = ""
	_create_category_button.disabled = true
#endregion
