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

@export_group("Lever")
@export var max_angle: float = 30.0
@export var sensitivity: float = 5.0
@export var snap_speed: float = 20.0
@export var friction: float = 0.8

var momentum: float = 0.0
var active_body: CharacterBody2D = null
var last_confirmed_side: String = "LEFT"

@onready var arm: Node2D = $LeverArm
@onready var push_area: Area2D = $LeverArm/PushArea

func _ready() -> void:
	_apply_own_color()
	call_deferred("_propagate_color")

	if Engine.is_editor_hint():
		return

	push_area.body_entered.connect(_on_body_entered)
	push_area.body_exited.connect(_on_body_exited)

	arm.rotation_degrees = -max_angle
	last_confirmed_side = "LEFT"

func _apply_own_color() -> void:
	ColorChannels.apply_to_color_fill(self, channel_color)

func _propagate_color() -> void:
	for output in outputs:
		if output != null and output.has_method("set_channel_color"):
			output.set_channel_color(channel_color)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Players"):
		active_body = body as CharacterBody2D

func _on_body_exited(body: Node2D) -> void:
	if body == active_body:
		active_body = null

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	var is_pushing := false

	if active_body:
		var input_dir := _get_body_push_direction(active_body)
		if input_dir != 0.0:
			is_pushing = true
			momentum += input_dir * 800.0 * sensitivity * delta

	if not is_pushing:
		if arm.rotation_degrees < max_angle and arm.rotation_degrees > -max_angle:
			var snap_dir := 1.0 if arm.rotation_degrees > 0.0 else -1.0
			momentum += snap_dir * snap_speed * delta * 60.0

	momentum *= friction
	arm.rotation_degrees += momentum * delta

	if arm.rotation_degrees >= max_angle:
		arm.rotation_degrees = max_angle
		momentum = 0.0

		if last_confirmed_side != "RIGHT":
			last_confirmed_side = "RIGHT"
			on_lever_flipped_right()

	elif arm.rotation_degrees <= -max_angle:
		arm.rotation_degrees = -max_angle
		momentum = 0.0

		if last_confirmed_side != "LEFT":
			last_confirmed_side = "LEFT"
			on_lever_flipped_left()

func _get_body_push_direction(body: CharacterBody2D) -> float:
	if body.has_method("get_lever_push_direction"):
		return clamp(body.get_lever_push_direction(), -1.0, 1.0)
	return 0.0

func on_lever_flipped_right() -> void:
	for output in outputs:
		if output != null and output.has_method("activate"):
			output.activate()

func on_lever_flipped_left() -> void:
	for output in outputs:
		if output != null and output.has_method("deactivate"):
			output.deactivate()

func set_channel_color(value: int) -> void:
	_channel_color = value
	_apply_own_color()
