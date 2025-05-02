@tool
extends Window

signal selected(category: StringName, was_added: bool)

const Namespace := preload("uid://b7ra0aicagaes")

const CATEGORY_BUTTON_SCENE := preload("uid://crtatdwnr4bgq")

@export var _categories_container: HFlowContainer

var _correctly_initialized := false

var _database_editor: Namespace.DatabaseEditor
var _collection_name: StringName:
	set(v):
		_collection_name = v
		_collection.entries_changed.connect(_update_categories)
		_update_categories()

var _collection: DatabaseCollection:
	get:
		return _database_editor.loaded_database.get_collection(_collection_name)

var _is_for_adding: bool


func setup_bulk_category_dialog(pdatabase_editor: Namespace.DatabaseEditor, pcollection_name: StringName, pis_for_adding: bool) -> void:
	_database_editor = pdatabase_editor
	_is_for_adding = pis_for_adding
	_collection_name = pcollection_name
	print(_is_for_adding)
	title = "%s category %s selected entries" % ["Add" if _is_for_adding else "Remove", "to" if _is_for_adding else "from"]
	_correctly_initialized = true


func _ready() -> void:
	assert(_correctly_initialized)
	close_requested.connect(queue_free)


func _update_categories() -> void:
	var entries_data := _collection.get_entries_data()
	var categories: Dictionary[StringName, Dictionary] = entries_data.categories_to_ints
	for child: Node in _categories_container.get_children():
		child.queue_free()
	
	for category: StringName in categories:
		var new_button: Namespace.CategoryButton = CATEGORY_BUTTON_SCENE.instantiate()
		new_button.setup_category_button(category, _is_for_adding)
		new_button.clicked.connect(_on_category_selected)
		_categories_container.add_child(new_button)


func _on_category_selected(category: StringName, _for_adding: bool) -> void:
	selected.emit(category, _is_for_adding)
	close_requested.emit()
