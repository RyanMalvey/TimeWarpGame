@tool
extends Node2D

var _outputs: Array[Node] = []
var _channel_color: int = ColorChannels.Channel.WHITE

@export_group("Wiring")
@export var outputs: Array[Node] = []:
	get:
		return _outputs
	set(value):
		_outputs = value
		call_deferred("_propagate_color")

@export_group("Color")
@export_enum("White", "Red", "Blue", "Green", "Yellow", "Purple", "Orange") var channel_color: int = ColorChannels.Channel.WHITE:
	get:
		return _channel_color
	set(value):
		_channel_color = value
		_apply_own_color()
		call_deferred("_propagate_color")

@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var press_area: Area2D = $Area2D

var _is_pressed: bool = false

func _ready() -> void:
	_apply_own_color()
	call_deferred("_propagate_color")

func _apply_own_color() -> void:
	ColorChannels.apply_to_color_fill(self, channel_color)

func _propagate_color() -> void:
	for output in outputs:
		if output != null and output.has_method("set_channel_color"):
			output.set_channel_color(channel_color)

func _on_area_2d_body_entered(body: Node) -> void:
	if Engine.is_editor_hint():
		return
	if not body.is_in_group("Players"):
		return
	if _is_pressed:
		return

	_is_pressed = true
	anim.play("pressed")

	for output in outputs:
		if output != null and output.has_method("activate"):
			output.activate()

func _on_area_2d_body_exited(body: Node) -> void:
	if Engine.is_editor_hint():
		return
	if not body.is_in_group("Players"):
		return

	call_deferred("_handle_body_exit_check")

func _handle_body_exit_check() -> void:
	for body in press_area.get_overlapping_bodies():
		if body != null and is_instance_valid(body) and body.is_in_group("Players"):
			return

	if not _is_pressed:
		return

	_is_pressed = false
	anim.play("unpressed")

	for output in outputs:
		if output != null and output.has_method("deactivate"):
			output.deactivate()
