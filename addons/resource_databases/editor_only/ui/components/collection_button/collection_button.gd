@tool
extends Button

signal selected(selected_collection: StringName, embedded: bool)

var collection_name: StringName:
	set(v):
		collection_name = v
		collection_name_label.text = ("[center]%s [color=7d7d7d](%s)" %
				[String(collection_name).capitalize(), String(collection_name)])

@export var color_bg: ColorRect
@export var collection_name_label: RichTextLabel

var _correctly_initialized := false


func _ready() -> void:
	assert(_correctly_initialized)
	pressed.connect(selected.emit.bind(collection_name, true))
	# TODO add floating option


func setup_collection_button(pcollection_name: String, index: int) -> void:
	collection_name = pcollection_name
	color_bg.color = Color("#181c21") if index % 2 == 0 else Color("#22272e")
	_correctly_initialized = true


func _on_collection_renamed(old: StringName, new: StringName) -> void:
	if old == collection_name:
		collection_name = new
