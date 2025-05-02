@tool
extends PanelContainer

signal collection_selected(collection_name: StringName, embedded: bool)

const Namespace := preload("uid://b7ra0aicagaes")

const COLLECTION_BUTTON_SCENE := preload("res://addons/resource_databases/editor_only/ui/components/collection_button/collection_button.tscn")

@export_subgroup("Components")
@export var _new_collection_line_edit: LineEdit
@export var _create_collection_button: Button
@export var _collection_buttons_container: Container

var _correctly_initialized := false

var _database_editor: Namespace.DatabaseEditor:
	set(v):
		_database_editor = v
		_current_database.collections_list_changed.connect(
			func() -> void:
				if selected_collection in _current_database.get_collections_list():
					_update_list()
				else:
					selected_collection = StringName()
		)
		selected_collection = StringName()

var _current_database: Database:
	get:
		return _database_editor.loaded_database
		

var selected_collection: StringName:
	set(v):
		selected_collection = v
		_update_list()


func setup_collections_list_view(pdatabase_editor: Namespace.DatabaseEditor) -> void:
	_database_editor = pdatabase_editor
	_correctly_initialized = true


func _ready() -> void:
	assert(_correctly_initialized)
	_new_collection_line_edit.text_changed.connect(_on_new_collection_line_edit_text_changed)
	_new_collection_line_edit.text_submitted.connect(_on_create_collection_button_pressed.unbind(1))
	_create_collection_button.pressed.connect(_on_create_collection_button_pressed)


func _update_list() -> void:
	print_debug("Updating collections list view")
	for child: Node in _collection_buttons_container.get_children():
		child.queue_free()
	
	if _current_database == null:
		return
	
	var idx := 0
	for collection_name: StringName in _current_database.get_collections_list():
		var new_button := COLLECTION_BUTTON_SCENE.instantiate() as Namespace.DatabaseCollectionButton
		new_button.setup_collection_button(collection_name, idx)
		new_button.disabled = collection_name == selected_collection
		_current_database.collection_name_changed.connect(new_button._on_collection_renamed)
		new_button.selected.connect(_database_editor._on_collection_selected)
		_collection_buttons_container.add_child(new_button)
		idx += 1


#region Create/remove collections callbacks
func _on_new_collection_line_edit_text_changed(new_text: String) -> void:
	_create_collection_button.disabled = not _current_database.is_collection_name_available(StringName(new_text))


func _on_create_collection_button_pressed() -> void:
	_current_database.create_collection(StringName(_new_collection_line_edit.text))
	_new_collection_line_edit.text = ""
	_create_collection_button.disabled = true # NOTE: Maybe not needed if text_changed signal is emitted with previous line
#endregion
