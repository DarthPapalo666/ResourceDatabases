
const EDITOR_SINGLETON_NAME := &"DatabaseEditor"
const DatabaseEditor := preload("res://addons/resource_databases/editor_only/ui/database_editor.gd")

const SETTINGS_SINGLETON_NAME := &"DatabaseSettings"
const DatabaseSettings := preload("res://addons/resource_databases/editor_only/database_settings_manager.gd")

# Database editor interface components
const CollectionsListView := preload("res://addons/resource_databases/editor_only/ui/components/collections_list_view/collections_list_view.gd")
const CollectionView := preload("res://addons/resource_databases/editor_only/ui/components/collection_view/collection_view.gd")

const DatabaseCollectionButton := preload("res://addons/resource_databases/editor_only/ui/components/collection_button/collection_button.gd")

const CollectionViewPageCounter := preload("res://addons/resource_databases/editor_only/ui/components/view_page_counter/view_page_counter.gd")
const CollectionEntry := preload("res://addons/resource_databases/editor_only/ui/components/database_entry/database_entry.gd")

const EditableParameter := preload("res://addons/resource_databases/editor_only/ui/components/editable_parameter/editable_parameter.gd")

const CategoryButton := preload("res://addons/resource_databases/editor_only/ui/components/dialogs/category_button/category_button.gd")
const CategoryFilter := preload("res://addons/resource_databases/editor_only/ui/components/collection_view/category_filter/category_filter.gd")

# Dialogs
const WarningDialog := preload("res://addons/resource_databases/editor_only/ui/components/dialogs/warning_dialog/warning_dialog.gd")

const CollectionCategoriesDialog := preload("res://addons/resource_databases/editor_only/ui/components/dialogs/collection_categories_dialog/collection_categories_dialog.gd")
const CollectionSettingsDialog := preload("res://addons/resource_databases/editor_only/ui/components/dialogs/collection_settings_dialog/collection_settings_dialog.gd")
const EntryCategoriesDialog := preload("res://addons/resource_databases/editor_only/ui/components/dialogs/entry_categories_dialog/entry_categories_dialog.gd")


static func get_editor_singleton() -> DatabaseEditor:
	if not Engine.has_singleton(EDITOR_SINGLETON_NAME):
		print_rich("[color=orange][ResourceDatabases][color=red] Error accessing database editor singleton!")
		return null
	return Engine.get_singleton(EDITOR_SINGLETON_NAME)


static func get_settings_singleton() -> DatabaseSettings:
	if not Engine.has_singleton(SETTINGS_SINGLETON_NAME):
		print_rich("[color=orange][ResourceDatabases][color=red] Error accessing database settings singleton!")
		return null
	return Engine.get_singleton(SETTINGS_SINGLETON_NAME)
