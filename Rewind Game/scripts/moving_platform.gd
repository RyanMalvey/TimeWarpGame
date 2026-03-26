@tool
extends AnimatableBody2D

var _channel_color: int = ColorChannels.Channel.WHITE

@export_group("Platform")
@export var move_speed: float = 100.0
@export var end_offset: Vector2 = Vector2(0, -10)

var _start_position: Vector2
var _end_position: Vector2
var _is_powered: bool = false

func _ready() -> void:
	_apply_visual_color()

	if Engine.is_editor_hint():
		return

	_start_position = global_position
	_end_position = _start_position + end_offset

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	var target := _end_position if _is_powered else _start_position
	global_position = global_position.move_toward(target, move_speed * delta)

func activate() -> void:
	if Engine.is_editor_hint():
		return
	_is_powered = true

func deactivate() -> void:
	if Engine.is_editor_hint():
		return
	_is_powered = false

func set_channel_color(value: int) -> void:
	_channel_color = value
	_apply_visual_color()

func _apply_visual_color() -> void:
	ColorChannels.apply_to_color_fill(self, _channel_color)
