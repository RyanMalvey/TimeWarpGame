extends CharacterBody2D

# =========================
# Core movement tuning
# =========================
@export var speed: float = 150.0
@export var jump_velocity: float = -300.0
@export var ground_stop_rate: float = 150.0

# =========================
# Variable jump height
# =========================
@export_range(0.0, 1.0, 0.01) var jump_cut_multiplier: float = 0.45

# =========================
# Jump buffering / Coyote time
# =========================
@export var jump_buffer_time: float = 0.12
@export var coyote_time: float = 0.10

# =========================
# Apex modifiers
# =========================
@export var apex_velocity_threshold: float = 35.0
@export_range(0.0, 2.0, 0.01) var apex_gravity_multiplier: float = 0.65
@export_range(1.0, 2.0, 0.01) var apex_speed_multiplier: float = 1.08

# =========================
# Fall tuning
# =========================
@export var max_fall_speed: float = 500.0

# =========================
# Edge detection / forgiveness
# =========================
@export_range(0, 8, 1) var corner_correction_pixels: int = 4
@export_range(0, 8, 1) var ledge_catch_pixels: int = 4

# =========================
# Rewind animation tuning
# =========================
@export var rewind_move_threshold: float = 0.5
@export var rewind_vertical_threshold: float = 0.15

# =========================
# Audio
# =========================
@export var footstep_1: AudioStream
@export var footstep_2: AudioStream
@export var footstep_interval: float = 0.28
@export var footstep_min_speed: float = 10.0

@export var rewind_loop_fade_out_time: float = 0.12
@export var rewind_loop_silent_volume_db: float = -40.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var jump_sound: AudioStreamPlayer2D = $JumpSound
@onready var land_sound: AudioStreamPlayer2D = $LandSound
@onready var footstep_sound: AudioStreamPlayer2D = $FootstepSound
@onready var rewind_start_sound: AudioStreamPlayer2D = $RewindStart
@onready var rewind_loop_sound: AudioStreamPlayer2D = $RewindLoop

var alive := true
var gravity: float = float(ProjectSettings.get_setting("physics/2d/default_gravity"))

var _jump_buffer_timer: float = 0.0
var _coyote_timer: float = 0.0
var _was_on_floor: bool = false
var _footstep_timer: float = 0.0

var _facing_right: bool = true
var _last_rewind_position: Vector2

var _was_rewinding: bool = false
var _rewind_audio_should_loop: bool = false
var _rewind_fade_tween: Tween = null
var _rewind_loop_play_volume_db: float = 0.0


func _ready() -> void:
	_last_rewind_position = global_position

	if not RewindManager.rewind_started.is_connected(_on_rewind_started):
		RewindManager.rewind_started.connect(_on_rewind_started)

	if rewind_start_sound and not rewind_start_sound.finished.is_connected(_on_rewind_start_finished):
		rewind_start_sound.finished.connect(_on_rewind_start_finished)

	if rewind_loop_sound:
		_rewind_loop_play_volume_db = rewind_loop_sound.volume_db


func _process(_delta: float) -> void:
	if not alive:
		return

	if RewindManager.is_rewinding and not _was_rewinding:
		_start_rewind_audio()

	if not RewindManager.is_rewinding and _was_rewinding:
		_stop_rewind_audio()

	if RewindManager.is_rewinding:
		_handle_rewind_animation()

	_was_rewinding = RewindManager.is_rewinding
	_last_rewind_position = global_position


func _on_rewind_started() -> void:
	_last_rewind_position = global_position
	_footstep_timer = 0.0


func _start_rewind_audio() -> void:
	_rewind_audio_should_loop = true

	if _rewind_fade_tween:
		_rewind_fade_tween.kill()
		_rewind_fade_tween = null

	if rewind_loop_sound:
		rewind_loop_sound.stop()
		rewind_loop_sound.volume_db = _rewind_loop_play_volume_db

	if rewind_start_sound:
		rewind_start_sound.play()


func _stop_rewind_audio() -> void:
	_rewind_audio_should_loop = false

	if rewind_start_sound and rewind_start_sound.playing:
		rewind_start_sound.stop()

	if rewind_loop_sound and rewind_loop_sound.playing:
		if _rewind_fade_tween:
			_rewind_fade_tween.kill()

		_rewind_fade_tween = create_tween()
		_rewind_fade_tween.tween_property(
			rewind_loop_sound,
			"volume_db",
			rewind_loop_silent_volume_db,
			rewind_loop_fade_out_time
		)
		_rewind_fade_tween.tween_callback(_finish_rewind_loop_fade)


func _finish_rewind_loop_fade() -> void:
	if rewind_loop_sound:
		rewind_loop_sound.stop()
		rewind_loop_sound.volume_db = _rewind_loop_play_volume_db

	_rewind_fade_tween = null


func _on_rewind_start_finished() -> void:
	if not _rewind_audio_should_loop:
		return

	if rewind_loop_sound:
		rewind_loop_sound.volume_db = _rewind_loop_play_volume_db
		rewind_loop_sound.play()


func kill_player() -> void:
	alive = false
	_stop_rewind_audio()

	if RewindManager.is_rewinding:
		RewindManager.stop_rewind()


func get_lever_push_direction() -> float:
	if not alive or RewindManager.is_rewinding:
		return 0.0

	return Input.get_axis("move_left", "move_right")


func _physics_process(delta: float) -> void:
	if not alive or RewindManager.is_rewinding:
		return

	var on_floor_now := is_on_floor()

	if on_floor_now:
		_coyote_timer = coyote_time
	else:
		_coyote_timer = max(_coyote_timer - delta, 0.0)

	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time
	else:
		_jump_buffer_timer = max(_jump_buffer_timer - delta, 0.0)

	if not on_floor_now:
		velocity.y += _get_current_gravity() * delta

	if velocity.y > max_fall_speed:
		velocity.y = max_fall_speed

	if _jump_buffer_timer > 0.0 and (on_floor_now or _coyote_timer > 0.0):
		_do_jump()

	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_cut_multiplier

	var direction := Input.get_axis("move_left", "move_right")
	_handle_horizontal_movement(direction)

	_try_corner_correction(delta)
	_try_ledge_catch(delta)

	move_and_slide()

	if not _was_on_floor and is_on_floor():
		land_sound.play()

	_handle_footsteps(delta)
	_handle_animations(direction)

	_was_on_floor = is_on_floor()


func _do_jump() -> void:
	velocity.y = jump_velocity
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0
	_footstep_timer = 0.0

	jump_sound.play()


func _handle_footsteps(delta: float) -> void:
	var is_walking: bool = is_on_floor() and abs(velocity.x) > footstep_min_speed

	if not is_walking:
		_footstep_timer = 0.0
		return

	_footstep_timer -= delta

	if _footstep_timer <= 0.0:
		var possible_steps: Array[AudioStream] = []

		if footstep_1 != null:
			possible_steps.append(footstep_1)
		if footstep_2 != null:
			possible_steps.append(footstep_2)

		if possible_steps.is_empty():
			return

		footstep_sound.stream = possible_steps.pick_random()
		footstep_sound.play()
		_footstep_timer = footstep_interval


func _get_current_gravity() -> float:
	var g := gravity

	if not is_on_floor() and abs(velocity.y) <= apex_velocity_threshold:
		g *= apex_gravity_multiplier

	return g


func _handle_horizontal_movement(direction: float) -> void:
	var current_speed := speed

	if not is_on_floor() and abs(velocity.y) <= apex_velocity_threshold:
		current_speed *= apex_speed_multiplier

	if direction != 0.0:
		velocity.x = direction * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, ground_stop_rate)


func _try_corner_correction(delta: float) -> void:
	if corner_correction_pixels <= 0:
		return
	if velocity.y >= 0.0:
		return

	var vertical_motion := Vector2(0.0, velocity.y * delta)

	if not test_move(global_transform, vertical_motion):
		return

	for i in range(1, corner_correction_pixels + 1):
		for offset in [-i, i]:
			var test_transform := global_transform
			test_transform.origin.x += offset

			if not test_move(test_transform, vertical_motion):
				global_position.x += offset
				return


func _try_ledge_catch(delta: float) -> void:
	if ledge_catch_pixels <= 0:
		return
	if is_on_floor():
		return
	if velocity.y < 0.0:
		return
	if abs(velocity.x) < 0.01:
		return

	var full_motion := velocity * delta

	if not test_move(global_transform, full_motion):
		return

	for i in range(1, ledge_catch_pixels + 1):
		var test_transform := global_transform
		test_transform.origin.y -= i

		if not test_move(test_transform, full_motion):
			global_position.y -= i
			return


func _handle_animations(direction: float) -> void:
	if direction > 0:
		_facing_right = true
	elif direction < 0:
		_facing_right = false

	sprite.flip_h = not _facing_right

	if is_on_floor():
		_play_forward("idle" if direction == 0 else "run")
	else:
		_play_forward("jump")


func _handle_rewind_animation() -> void:
	var motion := global_position - _last_rewind_position
	var dx := motion.x
	var dy := motion.y

	if dx > rewind_move_threshold:
		sprite.flip_h = true
		_facing_right = false
	elif dx < -rewind_move_threshold:
		sprite.flip_h = false
		_facing_right = true

	if abs(dy) > rewind_vertical_threshold:
		_play_reversed("jump")
	elif abs(dx) > rewind_move_threshold:
		_play_reversed("run")
	else:
		_play_reversed("idle")


func _play_forward(anim_name: String) -> void:
	if sprite.animation != anim_name or sprite.speed_scale < 0.0:
		sprite.play(anim_name)
	sprite.speed_scale = 1.0


func _play_reversed(anim_name: String) -> void:
	if sprite.animation != anim_name or sprite.speed_scale >= 0.0:
		sprite.play(anim_name, -1.0, true)
	else:
		sprite.speed_scale = -1.0
