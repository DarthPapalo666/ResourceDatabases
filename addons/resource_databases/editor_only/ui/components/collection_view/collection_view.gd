@tool
extends PanelContainer

const Namespace := preload("uid://b7ra0aicagaes")

const BulkCategoryDialog := preload("uid://cvpspfh7y3qjx")
const BULK_CATEGORY_DIALOG_SCENE := preload("uid://1px3v5fmg1dx")

const DATABASE_ENTRY_SCENE := preload("uid://xy4e3kkw44ru")

const CATEGORY_FILTER_SCENE := preload("uid://cwy0p6kbmufgt")

@export_subgroup("Menu buttons")
@export var _collection_button: MenuButton
@export var _selection_button: MenuButton
@export_subgroup("Collection info display")
@export var _selected_collection_label: RichTextLabel
@export_subgroup("Entries components")
@export var _drag_and_drop_panel: Namespace.DragAndDropPanel
@export var _collection_entries_container: Container
@export var _search_line_edit: LineEdit
@export var _entries_view_page_counter: Namespace.CollectionViewPageCounter
@export_subgroup("Filters components")
@export var _filters_check_button: CheckButton
@export var _filters_panel: PanelContainer
@export var _category_filters_container: VBoxContainer
@export var _expression_filter_text_edit: TextEdit
@export var _filter_with_expression_button: Button
@export var _clear_expression_button: Button
# Advanced filter options
@export var _advanced_filter_options_button: Button
@export var _advanced_filter_options_container: VBoxContainer
@export var _no_categories_label: Label
@export var _categories_option_button: OptionButton
@export var _update_category_button: Button
@export var _clear_category_button: Button

var _database_editor: Namespace.DatabaseEditor:
	set(v):
		_database_editor = v
		_database_editor.loaded_database.collection_name_changed.connect(
			func(old_name: StringName, new_name: StringName) -> void:
				if old_name == _collection_name:
					_collection_name = new_name
		)
		_database_editor.loaded_database.collections_list_changed.connect(
			func() -> void:
				if _collection_name not in _database_editor.loaded_database.get_collections_list():
					queue_free()
		)

var _collection_name: StringName:
	set(v):
		_collection_name = v
		if (not _collection.entries_changed.is_connected(_update_entries) and
			not _collection.settings_changed.is_connected(_update_entries)
		):
			_collection.entries_changed.connect(_update_entries)
			_collection.settings_changed.connect(_update_entries)
		_collection_button.disabled = false
		_selected_collection_label.text = "[b]%s" % _collection_name

var _collection: ResourceDatabaseCollection:
	get:
		return _database_editor.loaded_database.get_collection(_collection_name)

var _current_entries: Dictionary[StringName, Variant]:
	get:
		return _collection.get_entries_data()

# Indicates the current viewed page of the database collection
var _view_page: int = 1

# Dictionary used for speed on many IDs selected, bool is just a placeholder
var _selected_ids: Dictionary[int, bool]

var _categories_view_include_filter: Dictionary[StringName, bool]
var _categories_view_exclude_filter: Dictionary[StringName, bool]

# Flag to update the view only once per frame when needed.
var _was_updated := false

var correctly_initialized := false


func setup_collection_view(pdatabase_editor: Namespace.DatabaseEditor, pcollection_name: StringName) -> void:
	_database_editor = pdatabase_editor
	_collection_name = pcollection_name
	correctly_initialized = true


func _ready() -> void:
	assert(correctly_initialized)
	
	# Connect editor signals with DatabaseEditor
	if Engine.is_editor_hint():
		# NOTE This signal is also emitted when a file is moved for some reason
		ProjectSettings.settings_changed.connect(_update_entries)
		# NOTE This signal seems to be emitted a lot, when saving, etc...
		EditorInterface.get_resource_filesystem().filesystem_changed.connect(_update_entries)
	
	# Syntax highlighting in expression editor
	_expression_filter_text_edit.syntax_highlighter.member_keyword_colors = {"res": Color.LIGHT_SALMON, "res_type": Color.LIGHT_PINK}
	
	# Menu buttons
	_collection_button.get_popup().id_pressed.connect(_on_collection_button_id_selected)
	_update_collection_button_options()
	_selection_button.get_popup().id_pressed.connect(_on_selection_button_id_selected)
	_update_selection_button_options()
	
	# Drag and Drop
	_drag_and_drop_panel.paths_dropped.connect(_register_resources_from_paths)
	
	# Search box
	_search_line_edit.text_changed.connect(_update_entries.unbind(1))
	
	# View page counter
	_entries_view_page_counter.change_page_requested.connect(
		func(change: int) -> void: _update_entries(_view_page + change)
	)
	
	# Filters buttons
	_filters_check_button.toggled.connect(_on_filters_check_button_toggled)
	_filter_with_expression_button.pressed.connect(_update_entries)
	_clear_expression_button.pressed.connect(_on_clear_expression_button_pressed)
	# Advanced filters
	_advanced_filter_options_button.toggled.connect(_on_advanced_filter_options_button_toggled)
	_update_category_button.pressed.connect(_on_update_category_button_pressed)
	_clear_category_button.pressed.connect(_on_clear_category_button_pressed)
	
	# Initialize entries when ready
	_update_entries()


#region Collection menu button
func _on_collection_button_id_selected(id: int) -> void:
	match id:
		0: # Settings
			_database_editor.open_collection_settings_dialog(_collection_name)
		1: # Categories
			_database_editor.open_collection_categories_dialog(_collection_name)


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


#region IDs quering methods
# Gets all the entries that should be visible with the current filters
func _get_filtered_ids() -> Array[int]:
	if _current_entries.is_empty():
		return []
	var result: Array[int]
	result.assign((_current_entries.ints_to_locators as Dictionary[int, String]).keys())
	
	# Search box filtering
	if not _search_line_edit.text.is_empty():
		result = result.filter(
			func(int_id: int) -> bool:
				return (
					_search_line_edit.text in (_current_entries.ints_to_strings[int_id] as String) or
					_search_line_edit.text in ResourceDatabaseCollection.resource_path_from_locator(_current_entries.ints_to_locators[int_id], false)
				)
		)
	
	# If the right-side filters panel is closed don't execute the rest of filters
	if not _filters_check_button.button_pressed:
		return result
	
	# The category filter does a check for all categories in the categories_filter array
	# Int ID must be in all of them to appear
	if not _categories_view_include_filter.is_empty() or not _categories_view_exclude_filter.is_empty():
		result = result.filter(
			func(int_id: int) -> bool:
				for category: StringName in _categories_view_include_filter:
					if not (_current_entries.categories_to_ints[category] as Dictionary[int, bool]).has(int_id):
						return false
				for category: StringName in _categories_view_exclude_filter:
					if (_current_entries.categories_to_ints[category] as Dictionary[int, bool]).has(int_id):
						return false
				return true
				)
	
	# Expression filtering:
	var expr := _get_filter_expression()
	if expr != null:
		var expression_ids := _get_expression_ids()
		result = result.filter(
			func(int_id: int) -> bool:
				return int_id in expression_ids
		)
	
	return result


# Executes the expression and returns the IDs of the entries that satisfy it
func _get_expression_ids() -> Array[int]:
	var entries_ids: Array[int] = []
	entries_ids.assign(_current_entries.ints_to_locators.keys())
	
	var expr := _get_filter_expression()
	if expr == null:
		printerr("Can't get expression IDs if expression is null.")
		return entries_ids
	
	var ids = entries_ids.filter(
		func(int_id: int) -> bool:
			var locator := _current_entries.ints_to_locators[int_id] as String
			var locator_references_resource := ResourceLoader.exists(locator)
			var res: Resource
			var res_script: Script
			var res_class: String
			
			if not locator_references_resource:
				res = null
				res_script = null
				res_class = &"null"
			else:
				res = load(_current_entries.ints_to_locators[int_id])
				res_script = res.get_script()
				res_class = res.get_class() if res_script == null else res_script.get_global_name()
			
			var expr_result := expr.execute(
				[res, res_class],
				null,
				ProjectSettings.get_setting("resource_databases/show_expression_evaluation_errors")
			)
			if expr.has_execute_failed():
				return false
			if typeof(expr_result) != TYPE_BOOL:
				return false
			return expr_result as bool
	)
	return ids


# Returns the expression specified in the code editor control
func _get_filter_expression() -> Expression:
	if _expression_filter_text_edit.text.is_empty():
		return null
	var expr := Expression.new()
	if expr.parse(_expression_filter_text_edit.text, PackedStringArray(["res", "res_type"])) != OK:
		printerr("Error parsing filter expression.")
		return null
	return expr
#endregion

# Erases the current expression and reloads the entries
func _on_clear_expression_button_pressed() -> void:
	if not _expression_filter_text_edit.text.is_empty():
		_expression_filter_text_edit.clear()
	_update_entries()


# Registers the resources in paths to the collection
func _register_resources_from_paths(paths: PackedStringArray) -> void:
	for path: String in paths:
		if FileAccess.file_exists(path): # Is file
			_collection.register_resource(path)
		elif DirAccess.dir_exists_absolute(path): # Is folder
			_collection.register_folder_resources(path)
		else:
			print_rich(Namespace.CONSOLE_MSGS.drag_and_drop_error % path)


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
	if _was_updated:
		return
	_was_updated = true
	await get_tree().process_frame # We wait for the whole frame in order to process all the modifications
	_was_updated = false
	
	#print_debug("Updating collection view entries.")
	_selection_button.disabled = _current_entries.is_empty()
	
	# Free category filters
	for category_filter: Namespace.CategoryFilter in _category_filters_container.get_children():
		category_filter.queue_free()
	
	# Remove removed categories from filters
	for category: StringName in _categories_view_include_filter.keys():
		if category not in _current_entries.categories_to_ints:
			_categories_view_include_filter.erase(category)
	for category: StringName in _categories_view_exclude_filter.keys():
		if category not in _current_entries.categories_to_ints:
			_categories_view_exclude_filter.erase(category)
	
	# Remove categories from option button of advanced expression options
	_categories_option_button.clear()
	
	# Add new category filters
	for category: StringName in _current_entries.categories_to_ints:
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
	
	# Disable advanced filter options buttons if there is no category selected
	_update_category_button.disabled = _categories_option_button.selected == -1
	_clear_category_button.disabled = _categories_option_button.selected == -1
	_no_categories_label.visible = _categories_option_button.selected == -1
	_categories_option_button.visible = _categories_option_button.selected != -1
	
	# Clean entries
	for child in _collection_entries_container.get_children():
		child.queue_free()
		
	# Get all data
	var ints_to_strings: Dictionary[int, StringName] = _current_entries.ints_to_strings
	var ints_to_locators: Dictionary[int, String] = _current_entries.ints_to_locators
	
	# Clean selected ids in case some were removed
	for int_id: int in _selected_ids.keys():
		if int_id not in ints_to_locators:
			_selected_ids.erase(int_id)
	_update_selection_button_options()
	
	var ordered_ids: Array[int] = _get_filtered_ids()
	ordered_ids.sort()
	var max_entries: int = ProjectSettings.get_setting("resource_databases/max_view_entries", 25)
	var max_page: int = maxi(1, ceili(float(ordered_ids.size()) / max_entries))
	
	# Updates the view page to clamp it in case filters are active
	_view_page = clampi(_view_page if page < 0 else page, 1, max_page)
	_entries_view_page_counter.setup_view_page_counter(_view_page, max_page)
	
	if ordered_ids.is_empty():
		return # Nothing to update
	
	var ids_in_view := ordered_ids.slice(
		max_entries * (_view_page - 1),
		(max_entries * (_view_page - 1)) + max_entries
	)
	var index: int = 0
	for int_id: int in ids_in_view:
		var n_entry := DATABASE_ENTRY_SCENE.instantiate() as Namespace.CollectionEntry
		n_entry.setup_entry(
			_database_editor,
			_collection_name,
			int_id,
			ints_to_strings[int_id],
			ints_to_locators[int_id],
			int_id in _selected_ids,
			index
		)
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
	var result: Dictionary[int, bool]
	for int_id: int in _collection.get_entries_data().ints_to_locators:
		if int_id not in _selected_ids:
			result[int_id] = true
	_selected_ids = result
	_update_entries()


func _invalidate_selected_entries() -> void:
	if not await _database_editor.warn(&"bulk_invalidation"):
		return
	for int_id: int in _selected_ids:
		_collection.set_invalid_resource(int_id)


func _remove_selected_entries() -> void:
	if not await _database_editor.warn(&"bulk_removal"):
		return
	for int_id: int in _selected_ids:
		_collection.unregister_resource(int_id)


func _open_bulk_category_dialog(for_adding: bool) -> void:
	if _selected_ids.is_empty():
		return
	var new_popup: BulkCategoryDialog = BULK_CATEGORY_DIALOG_SCENE.instantiate()
	new_popup.setup_bulk_category_dialog(_database_editor, _collection_name, for_adding)
	new_popup.selected.connect(_bulk_category_selected)
	add_child(new_popup)
	new_popup.popup()


func _bulk_category_selected(category: StringName, was_added: bool) -> void:
	for int_id: int in _selected_ids:
		if was_added:
			_collection.add_category_to_resource(category, int_id, false)
		else:
			_collection.remove_category_from_resource(category, int_id, false)
#endregion


func _on_filters_check_button_toggled(toggled_on: bool) -> void:
	_filters_panel.visible = toggled_on
	_update_entries()


#region Advanced filter options
func _on_advanced_filter_options_button_toggled(toggled_on: bool) -> void:
	_advanced_filter_options_container.visible = toggled_on


func _on_update_category_button_pressed() -> void:
	var category: StringName = _categories_option_button.get_item_metadata(_categories_option_button.selected)
	if not await _database_editor.warn(&"update_category", [category]):
		return
	var filtered_ids := _get_filtered_ids()
	_collection.clear_category(category)
	for id: int in filtered_ids:
		_collection.add_category_to_resource(category, id, false)


func _on_clear_category_button_pressed() -> void:
	var category: StringName = _categories_option_button.get_item_metadata(_categories_option_button.selected)
	if not await _database_editor.warn(&"clean_category", [category]):
		return
	_collection.clear_category(category)
#endregion
