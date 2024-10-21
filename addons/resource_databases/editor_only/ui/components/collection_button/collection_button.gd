@tool
extends Button

var collection_uid: int = -1

@export var color_bg: ColorRect
@export var collection_name_label: RichTextLabel


func set_collection(ncollection_uid: int, collection_name: String, index: int) -> void:
	collection_uid = ncollection_uid
	set_collection_name(collection_name)
	color_bg.color = Color("#181c21") if index % 2 == 0 else Color("#22272e")


func set_collection_name(collection_name: String) -> void:
	collection_name_label.text = ("[center]%s [color=7d7d7d](%s)" % [collection_name.capitalize(), collection_name])
