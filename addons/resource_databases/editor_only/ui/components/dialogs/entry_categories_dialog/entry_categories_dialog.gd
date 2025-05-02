@tool
extends Window

const Namespace := preload("uid://b7ra0aicagaes")

const CATEGORY_BUTTON_SCENE := preload("res://addons/resource_databases/editor_only/ui/components/dialogs/category_button/category_button.tscn")

@export var _categories_container: VBoxContainer
@export var _entry_name_label: RichTextLabel
@export var _current_categories_container: HFlowContainer
@export var _remaining_categories_container: HFlowContainer
@export var _no_categories_container: CenterContainer

var _database_editor: Namespace.DatabaseEditor:
	set(v):
		_database_editor = v
		_database_editor.loaded_database.collection_name_changed.connect(_on_collection_name_changed)
		_database_editor.loaded_database.collections_list_changed.connect(_on_collections_list_changed)

var _collection_name: StringName:
	set(v):
		_collection_name = v
		_collection.entries_changed.connect(_update_categories)
		_collection.int_id_changed.connect(_on_int_id_changed)

var _collection: DatabaseCollection:
	get:
		return _database_editor.loaded_database.get_collection(_collection_name)

var _int_id: int = -1:
	set(v):
		_int_id = v
		var new_name: StringName = _collection.get_entries_data().ints_to_strings[_int_id]
		_update_categories()
		title = "[\"%s\"] categories" % String(new_name)

var _correctly_initialized := false


func setup_entry_categories_dialog(pdatabase_editor: Namespace.DatabaseEditor, pcollection_name: StringName, pint_id: int) -> void:
	_database_editor = pdatabase_editor
	_collection_name = pcollection_name
	_int_id = pint_id
	_correctly_initialized = true


func get_collection_name() -> StringName:
	return _collection_name


func get_int_id() -> int:
	return _int_id


func _ready() -> void:
	assert(_correctly_initialized)
	close_requested.connect(queue_free)


#region Collection callbacks
func _on_collection_name_changed(old: StringName, new: StringName) -> void:
	if _collection_name == old:
		_collection_name = new


# Needed to ensure the dialog is updated on reassignation of IDs
func _on_int_id_changed(old: int, new: int) -> void:
	if _int_id == old:
		_int_id = new


func _update_categories() -> void:
	var entries_data := _collection.get_entries_data()
	
	if _int_id not in entries_data.ints_to_locators:
		print(_int_id)
		queue_free()
		return
	var all_categories: Dictionary[StringName, Dictionary] = entries_data.categories_to_ints
	var all_buttons: Array[Node] = _current_categories_container.get_children()
	all_buttons.append_array(_remaining_categories_container.get_children())
	for button in all_buttons:
		button.queue_free()
	var resource_categories := _collection.get_categories_of_resource(_int_id)
	_no_categories_container.visible = all_categories.is_empty()
	_categories_container.visible = not all_categories.is_empty()
	if all_categories.is_empty():
		return
	_entry_name_label.text = "[color=purple][i]%s[/i][color=white] categories:" % entries_data.ints_to_strings[_int_id]
	for category: StringName in all_categories:
		var nbutton := CATEGORY_BUTTON_SCENE.instantiate() as Namespace.CategoryButton
		nbutton.clicked.connect(_on_category_button_clicked)
		if category in resource_categories:
			nbutton.setup_category_button(category, false)
			_current_categories_container.add_child(nbutton)
		else:
			nbutton.setup_category_button(category, true)
			_remaining_categories_container.add_child(nbutton)


func _on_collections_list_changed(collection_names: Array[StringName]) -> void:
	if _collection_name not in collection_names:
		queue_free()
#endregion


func _on_category_button_clicked(category: StringName, is_added: bool) -> void:
	if is_added:
		_collection.add_category_to_resource(category, _int_id)
	else:
		_collection.remove_category_from_resource(category, _int_id)
