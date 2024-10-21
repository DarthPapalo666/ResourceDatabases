@tool
extends Window

signal selected(category: StringName, was_added: bool)

const Namespace := preload("res://addons/resource_databases/editor_only/plugin_namespace.gd")

const CATEGORY_BUTTON_SCENE := preload("res://addons/resource_databases/editor_only/ui/components/dialogs/category_button/category_button.tscn")

@export var _categories_container: HFlowContainer

var DatabaseEditor := Namespace.get_editor_singleton()

var _collection_uid: int = -1

var _is_for_adding: bool


func setup_bulk_category_dialog(ncollection_uid: int, for_adding: bool) -> void:
	_collection_uid = ncollection_uid
	_is_for_adding = for_adding
	title = "%s category %s selected entries" % ["Add" if _is_for_adding else "Remove", "to" if _is_for_adding else "from"]
	_get_collection().categories_changed.connect(_on_categories_changed)
	_on_categories_changed(_get_collection().get_categories())


func _get_collection() -> EditorDatabaseCollection:
	return DatabaseEditor.get_database().get_collection(_collection_uid)


func _on_categories_changed(categories: Dictionary) -> void:
	for child: Node in _categories_container.get_children():
		child.queue_free()
	for category: StringName in categories:
		var new_button: Namespace.CategoryButton = CATEGORY_BUTTON_SCENE.instantiate()
		new_button.set_category(category, _is_for_adding)
		new_button.clicked.connect(_on_category_selected)
		_categories_container.add_child(new_button)


func _on_category_selected(category: StringName, _for_adding: bool) -> void:
	selected.emit(category, _is_for_adding)
	close_requested.emit()
