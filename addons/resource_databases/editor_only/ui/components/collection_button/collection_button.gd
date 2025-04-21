@tool
extends Button

var collection_name: StringName

@export var color_bg: ColorRect
@export var collection_name_label: RichTextLabel


func set_collection(pcollection_name: String, index: int) -> void:
	collection_name = pcollection_name
	collection_name_label.text = ("[center]%s [color=7d7d7d](%s)" %
			[String(collection_name).capitalize(), String(collection_name)])
	color_bg.color = Color("#181c21") if index % 2 == 0 else Color("#22272e")
