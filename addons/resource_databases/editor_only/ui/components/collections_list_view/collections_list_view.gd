@tool
extends PanelContainer

signal collection_selected(uid: int)
signal requested_collection_window(uid: int)

const Namespace := preload("res://addons/resource_databases/editor_only/plugin_namespace.gd")

const COLLECTION_BUTTON_SCENE := preload("res://addons/resource_databases/editor_only/ui/components/collection_button/collection_button.tscn")

@export var _connected_collection_view: Namespace.CollectionView
@export_subgroup("Components")
@export var _new_collection_line_edit: LineEdit
@export var _create_collection_button: Button
@export var _collection_buttons_container: Container

var DatabaseEditor := Namespace.get_editor_singleton()


func setup_list() -> void:
	var db := DatabaseEditor.get_database()
	db.collections_list_changed.connect(_update_list)
	_update_list(db.get_all_collection_uids())

func _update_list(collections_uids: Array[int]) -> void:
	for child: Node in _collection_buttons_container.get_children():
		child.queue_free()
	var selected_id: int = -1
	if _connected_collection_view != null:
		selected_id = _connected_collection_view.collection_uid
	var idx := 0
	for uid: int in collections_uids:
		var collection := DatabaseEditor.get_database().get_collection(uid)
		var new_button := COLLECTION_BUTTON_SCENE.instantiate() as Namespace.DatabaseCollectionButton
		new_button.disabled = uid == selected_id
		new_button.set_collection(uid, collection.name, idx)
		collection.name_changed.connect(new_button.set_collection_name)
		new_button.pressed.connect(_on_collection_selected.bind(uid))
		_collection_buttons_container.add_child(new_button)
		idx += 1


func _on_collection_selected(uid: int) -> void:
	collection_selected.emit(uid)
	if _connected_collection_view == null:
		return
	for button: Namespace.DatabaseCollectionButton in _collection_buttons_container.get_children():
		button.disabled = button.collection_uid == uid


#region Create/remove collections callbacks
func _on_new_collection_line_edit_text_changed(new_text: String) -> void:
	_create_collection_button.disabled = not DatabaseEditor.get_database().is_collection_name_available(StringName(new_text))


func _on_create_collection_button_pressed() -> void:
	DatabaseEditor.get_database().create_collection(StringName(_new_collection_line_edit.text))
	_new_collection_line_edit.text = ""
	_create_collection_button.disabled = true
#endregion
