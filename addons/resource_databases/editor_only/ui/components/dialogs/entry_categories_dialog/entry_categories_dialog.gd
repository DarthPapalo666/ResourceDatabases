@tool
extends Window

const Namespace := preload("res://addons/resource_databases/editor_only/plugin_namespace.gd")

const CATEGORY_BUTTON_SCENE := preload("res://addons/resource_databases/editor_only/ui/components/dialogs/category_button/category_button.tscn")

@export var _categories_container: VBoxContainer
@export var _entry_name_label: RichTextLabel
@export var _current_categories_container: HFlowContainer
@export var _remaining_categories_container: HFlowContainer
@export var _no_categories_container: CenterContainer

var DatabaseEditor := Namespace.get_editor_singleton()

var collection_uid: int = -1
var resource_int_id: int = -1


func setup_categories_dialog(ncollection_uid: int, nresource_int_id: int) -> void:
	collection_uid = ncollection_uid
	resource_int_id = nresource_int_id
	_set_dialogue_title(_get_collection().get_entries().ints_to_strings[resource_int_id])
	_get_collection().entries_changed.connect(_on_collection_entries_changed)
	DatabaseEditor.get_database().collections_list_changed.connect(_on_collections_list_changed)
	_get_collection().categories_changed.connect(_update_categories)
	_update_categories(_get_collection().get_categories())


func _update_categories(all_categories: Dictionary) -> void:
	var all_buttons: Array[Node] = _current_categories_container.get_children()
	all_buttons.append_array(_remaining_categories_container.get_children())
	for button in all_buttons:
		button.queue_free()
	var resource_categories := _get_collection().get_categories_of_resource(resource_int_id)
	_no_categories_container.visible = all_categories.is_empty()
	_categories_container.visible = not all_categories.is_empty()
	if all_categories.is_empty():
		return
	_entry_name_label.text = "[color=purple][i]%s[/i][color=white] categories:" % _get_collection().get_entries()[&"ints_to_strings"][resource_int_id]
	for category: StringName in all_categories:
		var nbutton := CATEGORY_BUTTON_SCENE.instantiate() as Namespace.CategoryButton
		nbutton.clicked.connect(_on_category_button_clicked)
		if category in resource_categories:
			nbutton.set_category(category, false)
			_current_categories_container.add_child(nbutton)
		else:
			nbutton.set_category(category, true)
			_remaining_categories_container.add_child(nbutton)


func _on_collections_list_changed(collection_uids: Array[int]) -> void:
	if collection_uid not in collection_uids:
		queue_free()


func _on_collection_entries_changed(entries: Dictionary) -> void:
	if resource_int_id not in entries.ints_to_locators:
		queue_free()
		return
	_set_dialogue_title(entries.ints_to_strings[resource_int_id])


func _set_dialogue_title(new_name: StringName) -> void:
	title = "[\"%s\"] categories" % String(new_name)


func _get_collection() -> EditorDatabaseCollection:
	return DatabaseEditor.get_database().get_collection(collection_uid)


func _on_category_button_clicked(category: StringName, is_added: bool) -> void:
	if is_added:
		_get_collection().add_category_to_resource(category, resource_int_id)
	else:
		_get_collection().remove_category_from_resource(category, resource_int_id)
