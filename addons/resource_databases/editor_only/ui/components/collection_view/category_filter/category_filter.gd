@tool
extends PanelContainer

signal filter_changed(state: int)

var _state: int = 0:
	set(v):
		_state = v
		match _state:
			0:
				_texture.texture = preload("uid://duf7splcl7ddr")
			1:
				_texture.texture = preload("uid://bisy3524ellsk")
			2:
				_texture.texture = preload("uid://cce1hito70j7w")
		filter_changed.emit(_state)

@export var _button: Button
@export var _texture: TextureRect


func set_category(ncategory: StringName, nstate: int = 0) -> void:
	_state = clampi(nstate, 0, 2)
	_button.text = "       " + String(ncategory)


func _on_button_pressed() -> void:
	_state = wrapi(_state + 1, 0, 3) # 3 not included
