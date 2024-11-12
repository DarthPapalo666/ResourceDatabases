@tool
extends PanelContainer

const Namespace := preload("res://addons/resource_databases/editor_only/plugin_namespace.gd")

const BulkCategoryDialog := preload("res://addons/resource_databases/editor_only/ui/components/dialogs/bulk_category_dialog/bulk_category_dialog.gd")
const BULK_CATEGORY_DIALOG_SCENE := preload("res://addons/resource_databases/editor_only/ui/components/dialogs/bulk_category_dialog/bulk_category_dialog.tscn")

const DATABASE_ENTRY_SCENE := preload("res://addons/resource_databases/editor_only/ui/components/database_entry/database_entry.tscn")

const CATEGORY_FILTER_SCENE := preload("res://addons/resource_databases/editor_only/ui/components/collection_view/category_filter/category_filter.tscn")

@export_subgroup("Menu buttons")
@export var _collection_button: MenuButton
@export var _selection_button: MenuButton
@export_subgroup("Collection info display")
@export var _selected_collection_label: RichTextLabel
@export_subgroup("Entries components")
@export var _collection_entries_container: Container
@export var _search_line_edit: LineEdit
@export var _entries_view_page_counter: Namespace.CollectionViewPageCounter
@export_subgroup("Filters components")
@export var _filters_check_button: CheckButton
@export var _filters_panel: PanelContainer
@export var _category_filters_container: VBoxContainer
@export var _expression_filter_text_edit: TextEdit
# Advanced filter options
@export var _advanced_filter_options: VBoxContainer
@export var _no_categories_label: Label
@export var _categories_option_button: OptionButton
@export var _update_category_button: Button
@export var _clear_category_button: Button

var DatabaseEditor := Namespace.get_editor_singleton()
var DatabaseSettings := Namespace.get_settings_singleton()

var collection_uid: int = -1

var _current_entries: Dictionary:
	set(v):
		_current_entries = v
		_selection_button.disabled = _current_entries.is_empty()
		_update_entries()

var _view_page: int = 1

var _selected_ids: Dictionary

var _categories_view_include_filter: Dictionary
var _categories_view_exclude_filter: Dictionary

var _was_updated := false # Flag to update the view only once per frame when needed.


func _ready() -> void:
	# NOTE This signal is also emitted when a file is moved for some reason
	ProjectSettings.settings_changed.connect(_update_entries)
	# NOTE This signal seems to be emitted a lot, when saving, etc...
	EditorInterface.get_resource_filesystem().filesystem_changed.connect(_update_entries)
	_expression_filter_text_edit.syntax_highlighter.member_keyword_colors = {"res": Color.LIGHT_SALMON, "res_type": Color.LIGHT_PINK}
	_collection_button.get_popup().id_pressed.connect(_on_collection_button_id_selected)
	_update_collection_button_options()
	_selection_button.get_popup().id_pressed.connect(_on_selection_button_id_selected)
	_update_selection_button_options()
	DatabaseEditor.get_database_opened_signal().connect(_on_database_opened)
	DatabaseEditor.get_database_closed_signal().connect(hide_view)


func setup_collection_view(ncollection_uid: int) -> void:
	collection_uid = ncollection_uid
	if collection_uid == -1:
		hide()
		return
	# Disconnect previous signals
	_disconnect_signals()
	_collection_button.disabled = false
	var collection := _get_collection()
	_set_collection_name(String(collection.name))
	collection.name_changed.connect(_on_collection_name_changed)
	collection.entries_changed.connect(_on_collection_entries_changed)
	collection.categories_changed.connect(_on_collection_categories_changed)
	_on_collection_categories_changed(collection.get_categories())
	_current_entries = collection.get_entries()
	show()


func hide_view() -> void:
	collection_uid = -1
	_collection_button.disabled = true
	_current_entries = {}
	hide()


#region Database callbacks
func _on_database_opened() -> void:
	DatabaseEditor.get_database().collections_list_changed.connect(_on_collections_list_changed)


func _on_collections_list_changed(collection_uids: Array[int]) -> void:
	if collection_uid not in collection_uids:
		hide_view()
#endregion


func _get_collection() -> EditorDatabaseCollection:
	if collection_uid == -1:
		return null
	return DatabaseEditor.get_database().get_collection(collection_uid)


#region Collection menu button
func _on_collection_button_id_selected(id: int) -> void:
	match id:
		0: # Settings
			DatabaseEditor.open_collection_settings_dialog(collection_uid)
		1: # Categories
			DatabaseEditor.open_collection_categories_dialog(collection_uid)


func _update_collection_button_options() -> void:
	var menu := _collection_button.get_popup()
	menu.clear()
	menu.add_item("Settings", 0)
	menu.add_item("Categories", 1)
#endregion


#region Selection menu button
func _on_selection_button_id_selected(id: int) -> void:
	var menu := _selection_button.get_popup()
	(menu.get_item_metadata(menu.get_item_index(id)) as Callable).call()


func _update_selection_button_options() -> void:
	var menu := _selection_button.get_popup()
	menu.clear()
	menu.add_item("Select all", 0)
	menu.set_item_metadata(0, _select_all_entries)
	menu.add_item("Unselect all", 1)
	menu.set_item_metadata(1, _unselect_entries)
	menu.add_item("Invert selection", 2)
	menu.set_item_metadata(2, _invert_entries_selection)
	menu.add_separator()
	menu.add_item("Invalidate selected", 4)
	menu.set_item_metadata(4, _invalidate_selected_entries)
	menu.add_item("Remove selected", 5)
	menu.set_item_metadata(5, _remove_selected_entries)
	menu.add_separator()
	menu.add_item("Add category to selected", 7)
	menu.set_item_metadata(7, _open_bulk_category_dialog.bind(true))
	menu.add_item("Remove category from selected", 8)
	menu.set_item_metadata(8, _open_bulk_category_dialog.bind(false))
	menu.set_item_disabled(1, _selected_ids.is_empty())
	menu.set_item_disabled(4, _selected_ids.is_empty())
	menu.set_item_disabled(5, _selected_ids.is_empty())
	menu.set_item_disabled(7, _selected_ids.is_empty())
	menu.set_item_disabled(8, _selected_ids.is_empty())
#endregion


func _disconnect_signals() -> void:
	for conn: Dictionary in get_incoming_connections():
		if (conn.signal as Signal).get_name() in [&"name_changed", &"entries_changed", &"categories_changed"]:
			(conn.signal as Signal).disconnect(conn.callable as Callable)


func _get_filtered_ids() -> Array[int]:
	if _current_entries.is_empty():
		return []
	var result: Array[int]
	result.assign((_current_entries.ints_to_locators as Dictionary).keys())
	# The category filter does a check for all categories in the categories_filter array
	# Int ID must be in all of them to appear
	if not _categories_view_include_filter.is_empty() or not _categories_view_exclude_filter.is_empty():
		result = result.filter(
			func(int_id: int) -> bool:
				for category: StringName in _categories_view_include_filter:
					if not (_current_entries.categories_to_ints[category] as Dictionary).has(int_id):
						return false
				for category: StringName in _categories_view_exclude_filter:
					if (_current_entries.categories_to_ints[category] as Dictionary).has(int_id):
						return false
				return true
				)
	if not _search_line_edit.text.is_empty():
		result = result.filter(
			func(int_id: int) -> bool:
				return (_current_entries.ints_to_strings[int_id] as String).contains(_search_line_edit.text)
				)
	# Expression filtering:
	var expr := _get_filter_expression()
	if expr == null:
		return result
	var expression_ids := _get_expression_ids()
	result = result.filter(
		func(int_id: int) -> bool:
			return int_id in expression_ids
	)
	return result


func _get_expression_ids() -> Array[int]:
	var expr := _get_filter_expression()
	assert(expr != null, "Can't get expression IDs if expression is null.")
	var entries_ids: Array[int] = []
	entries_ids.assign(_current_entries.ints_to_locators.keys())
	var ids = entries_ids.filter(
		func(int_id: int) -> bool:
			var locator := _current_entries.ints_to_locators[int_id] as String
			var locator_references_resource := false
			var res: Resource
			var res_script: Script
			var res_class: StringName
			if locator.begins_with("uid://"):
				if ResourceUID.has_id(ResourceUID.text_to_id(locator)):
					locator_references_resource = ResourceLoader.exists(locator)
			else:
				locator_references_resource = ResourceLoader.exists(locator)
			if not locator_references_resource:
				res = null
				res_script = null
				res_class = &"null"
			else:
				res = load(_current_entries.ints_to_locators[int_id])
				res_script = res.get_script()
				res_class = res.get_class() if res_script == null else res_script.get_global_name()
			var expr_result := expr.execute([res, res_class],
			null,
			DatabaseSettings.get_setting("show_expression_evaluation_errors"))
			if expr.has_execute_failed():
				return false
			if typeof(expr_result) != TYPE_BOOL:
				return false
			return expr_result as bool
	)
	return ids


func _get_filter_expression() -> Expression:
	if _expression_filter_text_edit.text.is_empty():
		return null
	var expr := Expression.new()
	if expr.parse(_expression_filter_text_edit.text, PackedStringArray(["res", "res_type"])) != OK:
		print_rich("[color=orange][ResourceDatabase] Error parsing filter expression.")
		return null
	return expr


func _on_filter_with_expression_button_pressed() -> void:
	_update_entries()


func _on_clear_expression_button_pressed() -> void:
	if not _expression_filter_text_edit.text.is_empty():
		_expression_filter_text_edit.clear()
	_update_entries()


func _register_resources_in_collection(paths: PackedStringArray) -> void:
	for path: String in paths:
		if FileAccess.file_exists(path): # Is file
			_get_collection().register_resource(path)
		elif DirAccess.dir_exists_absolute(path): # Is folder
			_get_collection().register_folder_resources(path)
		else:
			print_rich("[color=orange][ResourceDatabase] Error on drag and drop, invalid path [color=yellow](%s)" % path)


#region Collection callbacks
func _on_collection_name_changed(new_name: StringName) -> void:
	_set_collection_name(String(new_name))


func _on_collection_entries_changed(entries: Dictionary) -> void:
	_current_entries = entries


func _on_collection_categories_changed(categories: Dictionary) -> void:
	# Free category filters
	for category_filter: Namespace.CategoryFilter in _category_filters_container.get_children():
		category_filter.queue_free()
	# Remove filters of removed categories
	for category: StringName in _categories_view_include_filter.keys():
		if category not in categories:
			_categories_view_include_filter.erase(category)
	for category: StringName in _categories_view_exclude_filter.keys():
		if category not in categories:
			_categories_view_exclude_filter.erase(category)
	# Remove categories from option button of advanced expression options
	_categories_option_button.clear()
	# Add new filters
	for category: StringName in categories:
		# Update category filters
		var new_filter: Namespace.CategoryFilter = CATEGORY_FILTER_SCENE.instantiate()
		var initial_state := 0
		if _categories_view_include_filter.has(category):
			initial_state = 1
		elif _categories_view_exclude_filter.has(category):
			initial_state = 2
		new_filter.set_category(category, initial_state)
		new_filter.filter_changed.connect(_on_category_filter_state_changed.bind(category))
		_category_filters_container.add_child(new_filter)
		# Update category option button for advanced expression options
		_categories_option_button.add_item(String(category))
		_categories_option_button.set_item_metadata(_categories_option_button.item_count - 1, category)
	_update_entries()
	_update_category_button.disabled = _categories_option_button.selected == -1
	_clear_category_button.disabled = _categories_option_button.selected == -1
	_no_categories_label.visible = _categories_option_button.selected == -1
	_categories_option_button.visible = _categories_option_button.selected != -1
#endregion


func _on_category_filter_state_changed(state: int, category: StringName) -> void:
	match state:
		0:
			_categories_view_include_filter.erase(category)
			_categories_view_exclude_filter.erase(category)
		1:
			_categories_view_include_filter[category] = true
			_categories_view_exclude_filter.erase(category)
		2:
			_categories_view_include_filter.erase(category)
			_categories_view_exclude_filter[category] = true
	_update_entries()


func _update_entries(page: int = -1) -> void:
	if _was_updated: # HACK This makes the view just update once per frame at most, but I dont like it
		return
	_was_updated = true
	(func() -> void: _was_updated = false).call_deferred()
	await get_tree().process_frame
	# Clean entries
	for child in _collection_entries_container.get_children():
		child.queue_free()
	if _current_entries.is_empty():
		return
	# Get all data
	var ints_to_strings: Dictionary = _current_entries.ints_to_strings
	var ints_to_locators: Dictionary = _current_entries.ints_to_locators
	# Clean selected ids in case of removed...
	for int_id: int in _selected_ids.keys():
		if int_id not in ints_to_locators:
			_selected_ids.erase(int_id)
	_update_selection_button_options()
	# Get sorted int ids
	var ordered_ids: Array[int]
	# Just display filtered ids if the filters button is checked
	if _filters_check_button.button_pressed:
		ordered_ids = _get_filtered_ids()
	else:
		ordered_ids.assign(ints_to_strings.keys())
	ordered_ids.sort()
	var max_entries: int = DatabaseSettings.get_setting("max_view_entries")
	var max_page: int = maxi(1, ceili(float(ordered_ids.size()) / max_entries))
	# Updates the view page to clamp it in case filters are active
	_set_view_page(_view_page if page < 0 else page, max_page)
	if ordered_ids.is_empty():
		return # Nothing to update
	var ids_in_view := ordered_ids.slice(max_entries * (_view_page - 1), (max_entries * (_view_page - 1)) + max_entries)
	var index: int = 0
	for int_id: int in ids_in_view:
		var n_entry := DATABASE_ENTRY_SCENE.instantiate() as Namespace.CollectionEntry
		n_entry.set_entry(collection_uid, int_id, ints_to_strings[int_id], ints_to_locators[int_id], int_id in _selected_ids, index)
		n_entry.entry_selection_changed.connect(_on_entry_selection_changed)
		_collection_entries_container.add_child(n_entry)
		index += 1


#region Selection methods
func _on_entry_selection_changed(int_id: int, is_selected: bool) -> void:
	if is_selected:
		_selected_ids[int_id] = true
	else:
		_selected_ids.erase(int_id)
	_update_entries()


func _select_all_entries() -> void:
	_selected_ids.clear()
	for int_id: int in _get_filtered_ids():
		_selected_ids[int_id] = true
	_update_entries()


func _unselect_entries() -> void:
	_selected_ids.clear()
	_update_entries()


func _invert_entries_selection() -> void:
	var result: Dictionary
	for int_id: int in _current_entries[&"ints_to_locators"]:
		if int_id not in _selected_ids:
			result[int_id] = true
	_selected_ids = result
	_update_entries()


func _invalidate_selected_entries() -> void:
	if not await DatabaseEditor.warn("Bulk invalidation",
	"Are you sure you want to invalidate all selected resources?"):
		return
	for int_id: int in _selected_ids:
		_get_collection().set_invalid_resource(int_id)


func _remove_selected_entries() -> void:
	if not await DatabaseEditor.warn("Bulk removal",
	"Are you sure you want to remove all selected resources?"):
		return
	for int_id: int in _selected_ids:
		_get_collection().unregister_resource(int_id)


func _open_bulk_category_dialog(for_adding: bool) -> void:
	if _selected_ids.is_empty():
		return
	var new_popup: BulkCategoryDialog = BULK_CATEGORY_DIALOG_SCENE.instantiate()
	new_popup.setup_bulk_category_dialog(collection_uid, for_adding)
	new_popup.selected.connect(_bulk_category_selected)
	add_child(new_popup)
	new_popup.popup()


func _bulk_category_selected(category: StringName, was_added: bool) -> void:
	for int_id: int in _selected_ids:
		if was_added:
			_get_collection().add_category_to_resource(category, int_id, false)
		else:
			_get_collection().remove_category_from_resource(category, int_id, false)
#endregion


func _set_view_page(page: int, max_page: int) -> void:
	_view_page = clampi(page, 1, max_page)
	_entries_view_page_counter.set_page(_view_page, max_page)


func _set_collection_name(collection_name: String) -> void:
	_selected_collection_label.text = "[b]%s" % collection_name


func _on_view_page_counter_change_page_requested(change: int) -> void:
	_update_entries(_view_page + change)


func _on_search_line_edit_text_changed(_new_text: String) -> void:
	_update_entries()


func _on_filters_check_button_toggled(toggled_on: bool) -> void:
	_filters_panel.visible = toggled_on
	_update_entries()


#region Advanced filter options
func _on_advanced_filter_options_check_button_toggled(toggled_on: bool) -> void:
	_advanced_filter_options.visible = toggled_on


func _on_update_category_button_pressed() -> void:
	var category: StringName = _categories_option_button.get_item_metadata(_categories_option_button.selected)
	if not await DatabaseEditor.warn("Update category", "Are you sure you want to update the [b]%s[/b] category with the currently filtered IDs?" % category):
		return
	var filtered_ids := _get_filtered_ids()
	_get_collection().clear_category(category)
	for id: int in filtered_ids:
		_get_collection().add_category_to_resource(category, id, false)


func _on_clear_category_button_pressed() -> void:
	var category: StringName = _categories_option_button.get_item_metadata(_categories_option_button.selected)
	if not await DatabaseEditor.warn("Clear category", "Are you sure you want to clear the [b]%s[/b] category?" % category):
		return
	_get_collection().clear_category(category)
#endregion
