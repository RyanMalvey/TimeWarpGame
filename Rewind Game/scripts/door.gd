@tool
extends StaticBody2D

var _channel_color: int = ColorChannels.Channel.WHITE

@export_group("Door")
@export var open_alpha: float = 0.35
@export var closed_alpha: float = 1.0
@export var closed_layer: int = 1
@export var starts_open: bool = false

var _is_powered: bool = false
var _is_open: bool = false

func _ready() -> void:
	_update_door_state()

func activate() -> void:
	if Engine.is_editor_hint():
		return
	if _is_powered:
		return

	_is_powered = true
	_update_door_state()

func deactivate() -> void:
	if Engine.is_editor_hint():
		return
	if not _is_powered:
		return

	_is_powered = false
	_update_door_state()

func set_channel_color(value: int) -> void:
	_channel_color = value
	_apply_visual_only()

func _update_door_state() -> void:
	if _is_powered:
		_is_open = not starts_open
	else:
		_is_open = starts_open

	_apply_state_runtime()

func _apply_visual_only() -> void:
	var alpha := open_alpha if _is_open else closed_alpha
	ColorChannels.apply_to_color_fill(self, _channel_color, alpha)

func _apply_state_runtime() -> void:
	_apply_visual_only()

	var collision_shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape != null:
		collision_shape.set_deferred("disabled", _is_open)

	if _is_open:
		collision_layer = 0
		collision_mask = 0
	else:
		collision_layer = closed_layer
