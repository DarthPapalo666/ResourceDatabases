@tool
extends EditorPlugin

const Namespace := preload("res://addons/resource_databases/editor_only/plugin_namespace.gd")

const DATABASE_EDITOR_SCENE := preload("res://addons/resource_databases/editor_only/ui/database_editor.tscn")

var database_editor_instance: Namespace.DatabaseEditor = DATABASE_EDITOR_SCENE.instantiate()
var database_settings_manager: Namespace.DatabaseSettings = Namespace.DatabaseSettings.new()


# Initialization of the plugin goes here.
func _enter_tree() -> void:
	if not Engine.is_editor_hint():
		print_rich("[color=orange][ResourceDatabases][/color] [color=red]Not executing editor in game...")
		return
	
	
	# Setup editor and settings singleton
	Engine.register_singleton(Namespace.EDITOR_SINGLETON_NAME, database_editor_instance)
	Engine.register_singleton(Namespace.SETTINGS_SINGLETON_NAME, database_settings_manager)

	# Adds the database editor to the mainscreen
	database_editor_instance.set_plugin_version(get_plugin_version())
	EditorInterface.get_editor_main_screen().add_child(database_editor_instance)
	
	# Add plugin settings
	database_settings_manager.add_settings()
	
	_make_visible(false)
	
	print_rich("[color=sky_blue][Resource Databases] Plugin loaded!")


# Clean-up of the plugin goes here.
func _exit_tree() -> void:
	# Remove editor and settings singleton
	if Engine.has_singleton(Namespace.EDITOR_SINGLETON_NAME):
		Engine.unregister_singleton(Namespace.EDITOR_SINGLETON_NAME)
	if Engine.has_singleton(Namespace.SETTINGS_SINGLETON_NAME):
		Engine.unregister_singleton(Namespace.SETTINGS_SINGLETON_NAME)
	
	# Removes mainscreen instance
	if database_editor_instance:
		database_editor_instance.free()
	
	# Remove plugin settings
	database_settings_manager.remove_settings()
	database_settings_manager = null
	
	print_rich("[color=coral][Resource Databases] Plugin disabled.")


func _make_visible(visible: bool) -> void:
	if database_editor_instance:
		database_editor_instance.visible = visible


func _has_main_screen() -> bool:
	return true


func _get_plugin_name() -> String:
	return "Databases"


func _get_plugin_icon() -> Texture2D:
	# Must return some kind of Texture for the icon.
	return EditorInterface.get_editor_theme().get_icon("ResourcePreloader", "EditorIcons")


func _handles(object: Object) -> bool:
	return object is Database


func _edit(object: Object) -> void:
	if not object:
		return
	var edited_db := object as Database
	database_editor_instance.load_database(edited_db.resource_path)
