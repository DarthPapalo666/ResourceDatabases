@tool
extends Panel

signal paths_dropped(paths: PackedStringArray)


func _process(delta: float) -> void:
	visible = get_tree().get_root().gui_is_dragging()


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if data is Dictionary:
		if (data as Dictionary).has("type"):
			return data["type"] == "files" or data["type"] == "files_and_dirs"
	return false


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	_on_paths_container_paths_dropped(data["files"] as PackedStringArray)


func _on_paths_container_paths_dropped(paths: PackedStringArray) -> void:
	paths_dropped.emit(paths)
