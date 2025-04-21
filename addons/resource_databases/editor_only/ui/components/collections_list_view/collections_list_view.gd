@tool
extends PanelContainer

signal collection_selected(collection_name: StringName, embedded: bool)

const Namespace := preload("res://addons/resource_databases/editor_only/plugin_namespace.gd")

const COLLECTION_BUTTON_SCENE := preload("res://addons/resource_databases/editor_only/ui/components/collection_button/collection_button.tscn")

@export_subgroup("Components")
@export var _new_collection_line_edit: LineEdit
@export var _create_collection_button: Button
@export var _collection_buttons_container: Container

var _correctly_initialized := false

var _database_editor: Namespace.DatabaseEditor:
	set(v):
		_database_editor = v
		_current_database = _database_editor.loaded_database

var _current_database: Database:
	set(v):
		_current_database = v
		_update_list()
		_current_database.collections_list_changed.connect(_update_list)

var selected_collection: StringName


func setup_collections_list_view(pdatabase_editor: Namespace.DatabaseEditor) -> void:
	_database_editor = pdatabase_editor
	_correctly_initialized = true


func _ready() -> void:
	assert(_correctly_initialized)
	_new_collection_line_edit.text_changed.connect(_on_new_collection_line_edit_text_changed)
	_create_collection_button.pressed.connect(_on_create_collection_button_pressed)


func _update_list() -> void:
	for child: Node in _collection_buttons_container.get_children():
		child.queue_free()
	if _current_database == null:
		return

	var idx := 0
	for collection_name: StringName in _current_database.get_collections_list():
		var collection := _current_database.get_collection(collection_name)
		var new_button := COLLECTION_BUTTON_SCENE.instantiate() as Namespace.DatabaseCollectionButton
		new_button.disabled = collection_name == selected_collection
		new_button.set_collection(collection_name, idx)
		collection.name_changed.connect(new_button.set_collection_name)
		new_button.pressed.connect(_on_collection_selected.bind(collection_name))
		_collection_buttons_container.add_child(new_button)
		idx += 1


func _on_collection_selected(collection_name: StringName) -> void:
	collection_selected.emit(collection_name)
	# TODO move to another func called by editor
	# also set selected collection after callback
	for button: Namespace.DatabaseCollectionButton in _collection_buttons_container.get_children():
		button.disabled = button.collection_name == collection_name


#region Create/remove collections callbacks
func _on_new_collection_line_edit_text_changed(new_text: String) -> void:
	_create_collection_button.disabled = not _current_database.is_collection_name_available(StringName(new_text))


func _on_create_collection_button_pressed() -> void:
	_current_database.create_collection(StringName(_new_collection_line_edit.text))
	_new_collection_line_edit.text = ""
	_create_collection_button.disabled = true
#endregion
