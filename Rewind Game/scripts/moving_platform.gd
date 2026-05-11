@tool
extends AnimatableBody2D

var _channel_color: int = ColorChannels.Channel.WHITE

@export_group("Platform")
@export var move_speed: float = 100.0
@export var end_offset: Vector2 = Vector2(0, -10)

@export_group("Audio")
@export var arrival_threshold: float = 0.5
@export var mid_fade_out_time: float = 0.12
@export var mid_silent_volume_db: float = -40.0

var _start_position: Vector2
var _end_position: Vector2
var _is_powered: bool = false
var _was_moving: bool = false
var _audio_should_loop: bool = false
var _fade_tween: Tween = null

# Uses the Inspector-set volume automatically
var _mid_play_volume_db: float = 0.0

@onready var start_sound: AudioStreamPlayer2D = $StartSound
@onready var mid_sound: AudioStreamPlayer2D = $MidSound


func _ready() -> void:
	_apply_visual_color()

	if Engine.is_editor_hint():
		return

	_start_position = global_position
	_end_position = _start_position + end_offset

	if start_sound and not start_sound.finished.is_connected(_on_start_sound_finished):
		start_sound.finished.connect(_on_start_sound_finished)

	if mid_sound:
		_mid_play_volume_db = mid_sound.volume_db


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	var target := _end_position if _is_powered else _start_position

	global_position = global_position.move_toward(target, move_speed * delta)

	var is_at_target := global_position.distance_to(target) <= arrival_threshold
	var is_moving := not is_at_target

	if is_moving and not _was_moving:
		_start_platform_audio()

	if not is_moving and _was_moving:
		_stop_platform_audio()

	_was_moving = is_moving


func activate() -> void:
	if Engine.is_editor_hint():
		return

	_is_powered = true


func deactivate() -> void:
	if Engine.is_editor_hint():
		return

	_is_powered = false


func _start_platform_audio() -> void:
	_audio_should_loop = true

	if _fade_tween:
		_fade_tween.kill()
		_fade_tween = null

	if mid_sound:
		mid_sound.stop()
		mid_sound.volume_db = _mid_play_volume_db

	if start_sound:
		start_sound.play()


func _stop_platform_audio() -> void:
	_audio_should_loop = false

	if start_sound and start_sound.playing:
		start_sound.stop()

	if mid_sound and mid_sound.playing:
		if _fade_tween:
			_fade_tween.kill()

		_fade_tween = create_tween()
		_fade_tween.tween_property(
			mid_sound,
			"volume_db",
			mid_silent_volume_db,
			mid_fade_out_time
		)
		_fade_tween.tween_callback(_finish_mid_fade)


func _finish_mid_fade() -> void:
	if mid_sound:
		mid_sound.stop()
		mid_sound.volume_db = _mid_play_volume_db

	_fade_tween = null


func _on_start_sound_finished() -> void:
	if not _audio_should_loop:
		return

	if mid_sound:
		mid_sound.volume_db = _mid_play_volume_db
		mid_sound.play()


func set_channel_color(value: int) -> void:
	_channel_color = value
	_apply_visual_color()


func _apply_visual_color() -> void:
	ColorChannels.apply_to_color_fill(self, _channel_color)
