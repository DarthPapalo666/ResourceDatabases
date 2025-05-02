
const DatabaseEditor := preload("uid://dj55qe48saxx5")

# Database editor components
const CollectionsListView := preload("uid://dgei1m2w0su5r")
const CollectionView := preload("uid://bx01vht87edo1")

const DatabaseCollectionButton := preload("uid://ck21x43kxka3p")

const DragAndDropPanel := preload("uid://dy7it7ik2ss88")

const CollectionViewPageCounter := preload("uid://dt055ean1tevg")
const CollectionEntry := preload("uid://brtfc00xcsds3")

const EditableParameter := preload("uid://cstdhmmgda4i2")

const CategoryButton := preload("uid://q2ox3sai3uxl")
const CategoryFilter := preload("uid://b7n8ttvu02pfx")

# Dialogs
const WarningDialog := preload("uid://d0h8rwjnol7xd")

const CollectionCategoriesDialog := preload("uid://bq84swcbye2yf")
const CollectionSettingsDialog := preload("uid://be8tnygu74agg")
const EntryCategoriesDialog := preload("uid://baab10j63h87u")

# DatabaseEditor warning messages
const WARNING_MSGS := {
	bulk_invalidation = [
		"Bulk invalidation",
		"Are you sure you want to invalidate all selected entries?"
	],
	bulk_removal = [
		"Bulk removal",
		"Are you sure you want to remove all selected resources?"
	],
	update_category = [
		"Update category",
		"Are you sure you want to update the \"[i]%s[/i]\" category with the currently filtered IDs?"
	],
	remove_category = [
		"Remove category",
		"Are you sure you want to remove the \"[i]%s[/i]\" category?"
	],
	unsaved_database = [
		"Unsaved changes in Database",
		"You have unsaved changes in the current database,\nare you sure you want to continue?"
	],
	clean_category = [
		"Clear category",
		"Are you sure you want to clear the \"[i]%s[/i]\" category?"
	],
	make_resource_invalid = [
		"Make resource invalid?",
		"Are you sure you want to make this resource invalid?"
	],
	unregister_resource = [
		"Unregistering resource",
		"Are you sure you want to unregister this resource?"
	],
	cant_rename_collection = [
		"Can't rename collection",
		"Invalid new collection name: %s"
	],
	remove_collection = [
		"Remove collection",
		"Are you sure you want to remove the \"[i]%s[/i]\" collection?"
	]
}

# ResourceDatabases error messages
const NOTIFICATION_PREFIX := "[color=magenta][ResourceDatabases] [color=pink]>> [/color]"
const ERROR_PREFIX := NOTIFICATION_PREFIX + "[color=tomato][ERROR]: [color=lightsalmon] [/color]"
const CONSOLE_MSGS := {
	expression_parsing_error = ERROR_PREFIX + "Error parsing filter expression.",
	drag_and_drop_error = ERROR_PREFIX + "Error on drag and drop, invalid path [color=yellow](%s)."
}
