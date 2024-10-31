@tool
extends Window

const Namespace := preload("res://addons/resource_databases/editor_only/plugin_namespace.gd")

const CATEGORY_BUTTON_SCENE := preload("res://addons/resource_databases/editor_only/ui/components/dialogs/category_button/category_button.tscn")

@export var _new_category_line_edit: LineEdit
@export var _create_category_button: Button
@export var _categories_container: HFlowContainer

var DatabaseEditor := Namespace.get_editor_singleton()

var collection_uid: int = -1


func setup_collection_categories_dialog(ncollection_uid: int) -> void:
	collection_uid = ncollection_uid
	_get_collection().name_changed.connect(_on_collection_name_changed)
	_on_collection_name_changed(_get_collection().name)
	_get_collection().categories_changed.connect(_update_categories)
	_update_categories(_get_collection().get_categories())


func _get_collection() -> EditorDatabaseCollection:
	return DatabaseEditor.get_database().get_collection(collection_uid)


func _on_collection_name_changed(new_name: StringName) -> void:
	title = "%s categories" % new_name.capitalize()


func _update_categories(categories: Dictionary) -> void:
	for child: Node in _categories_container.get_children():
		child.queue_free()
	for category: StringName in categories:
		var new_button: Namespace.CategoryButton = CATEGORY_BUTTON_SCENE.instantiate()
		new_button.set_category(category, false)
		new_button.clicked.connect(_category_removed)
		_categories_container.add_child(new_button)


func _category_removed(category: StringName, _added: bool) -> void:
	if await DatabaseEditor.warn("Remove category",
	"Are you sure you want to remove the [b]%s[/b] category?" % String(category)):
		_get_collection().remove_category(category)
	grab_focus()


func _on_new_category_line_edit_text_changed(new_text: String) -> void:
	_create_category_button.disabled = not _get_collection().is_category_name_available(StringName(new_text))


func _on_create_category_button_pressed() -> void:
	_get_collection().create_category(_new_category_line_edit.text)
	_new_category_line_edit.text = ""
	_create_category_button.disabled = true
