@tool
extends Window

const Namespace := preload("res://addons/resource_databases/editor_only/plugin_namespace.gd")

const CATEGORY_BUTTON_SCENE := preload("res://addons/resource_databases/editor_only/ui/components/dialogs/category_button/category_button.tscn")

@export var _categories_container: VBoxContainer
@export var _entry_name_label: RichTextLabel
@export var _current_categories_container: HFlowContainer
@export var _remaining_categories_container: HFlowContainer
@export var _no_categories_container: CenterContainer

var _correctly_initialized := false

var _database_editor: Namespace.DatabaseEditor
var _collection_name: StringName
var _collection: DatabaseCollection:
	get:
		return _database_editor.loaded_database.get_collection(_collection_name)
var _int_id: int = -1


func setup_entry_categories_dialog(pdatabase_editor: Namespace.DatabaseEditor, pcollection_name: StringName, pint_id: int) -> void:
	_collection_name = pcollection_name
	_int_id = pint_id
	_set_dialogue_title(_collection.get_entries().ints_to_strings[pint_id])
	_collection.entries_changed.connect(_on_collection_entries_changed)
	_database_editor.get_database().collections_list_changed.connect(_on_collections_list_changed)
	_collection.categories_changed.connect(_update_categories)
	_update_categories(_collection.get_categories())


func _ready() -> void:
	assert(_correctly_initialized)


func _update_categories(all_categories: Dictionary) -> void:
	var all_buttons: Array[Node] = _current_categories_container.get_children()
	all_buttons.append_array(_remaining_categories_container.get_children())
	for button in all_buttons:
		button.queue_free()
	var resource_categories := _collection.get_categories_of_resource(_int_id)
	_no_categories_container.visible = all_categories.is_empty()
	_categories_container.visible = not all_categories.is_empty()
	if all_categories.is_empty():
		return
	_entry_name_label.text = "[color=purple][i]%s[/i][color=white] categories:" % _collection.get_entries()[&"ints_to_strings"][_int_id]
	for category: StringName in all_categories:
		var nbutton := CATEGORY_BUTTON_SCENE.instantiate() as Namespace.CategoryButton
		nbutton.clicked.connect(_on_category_button_clicked)
		if category in resource_categories:
			nbutton.set_category(category, false)
			_current_categories_container.add_child(nbutton)
		else:
			nbutton.set_category(category, true)
			_remaining_categories_container.add_child(nbutton)


func _on_collections_list_changed(collection_names: Array[StringName]) -> void:
	if _collection_name not in collection_names:
		queue_free()


func _on_collection_entries_changed(entries_data: Dictionary) -> void:
	if _int_id not in entries_data.ints_to_locators:
		queue_free()
		return
	_set_dialogue_title(entries_data.ints_to_strings[_int_id])


func _set_dialogue_title(new_name: StringName) -> void:
	title = "[\"%s\"] categories" % String(new_name)


func _on_category_button_clicked(category: StringName, is_added: bool) -> void:
	if is_added:
		_collection.add_category_to_resource(category, _int_id)
	else:
		_collection.remove_category_from_resource(category, _int_id)
