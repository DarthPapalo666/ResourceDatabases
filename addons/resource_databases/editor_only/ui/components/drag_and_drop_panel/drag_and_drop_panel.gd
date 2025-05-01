@tool
extends Panel

signal paths_dropped(paths: PackedStringArray)


#func _process(delta: float) -> void:
#	visible = get_tree().get_root().gui_is_dragging()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_DRAG_BEGIN:
			visible = true
		NOTIFICATION_DRAG_END:
			visible = false


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if data is Dictionary:
		if (data as Dictionary).has("type"):
			return data["type"] == "files" or data["type"] == "files_and_dirs"
	return false


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	paths_dropped.emit(data["files"] as PackedStringArray)
