extends CharacterBody2D
class_name PlayerClone

# =========================
# Core movement tuning
# These should match the player
# =========================
@export var speed: float = 150.0
@export var jump_velocity: float = -300.0
@export var ground_stop_rate: float = 150.0
@export var linger_after_replay: float = 2.0

# =========================
# Variable jump height
# =========================
@export_range(0.0, 1.0, 0.01) var jump_cut_multiplier: float = 0.45

# =========================
# Jump buffering
# =========================
@export var jump_buffer_time: float = 0.12

# =========================
# Coyote time
# =========================
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

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var alive: bool = true
var gravity: float = float(ProjectSettings.get_setting("physics/2d/default_gravity"))

var _inputs: Array[Dictionary] = []
var _i: int = 0
var _replay_done: bool = false
var _linger_t: float = 0.0

# current replayed horizontal input, used by lever pushing
var _current_axis: float = 0.0

# replayed jump state for this frame
var _jump_pressed: bool = false
var _jump_held: bool = false
var _jump_released: bool = false

# jump system state
var _jump_buffer_timer: float = 0.0
var _coyote_timer: float = 0.0

func copy_tuning_from_player(player: Node) -> void:
	if player == null:
		return

	_copy_property_if_present(player, "speed")
	_copy_property_if_present(player, "jump_velocity")
	_copy_property_if_present(player, "ground_stop_rate")
	_copy_property_if_present(player, "jump_cut_multiplier")
	_copy_property_if_present(player, "jump_buffer_time")
	_copy_property_if_present(player, "coyote_time")
	_copy_property_if_present(player, "apex_velocity_threshold")
	_copy_property_if_present(player, "apex_gravity_multiplier")
	_copy_property_if_present(player, "apex_speed_multiplier")
	_copy_property_if_present(player, "max_fall_speed")
	_copy_property_if_present(player, "corner_correction_pixels")
	_copy_property_if_present(player, "ledge_catch_pixels")

func _copy_property_if_present(source: Object, property_name: String) -> void:
	var value = source.get(property_name)
	if value == null:
		return
	set(property_name, value)

func setup_replay(inputs: Array[Dictionary], initial_velocity: Vector2, initial_flip_h: bool) -> void:
	_inputs = inputs
	_i = 0
	_replay_done = false
	_linger_t = 0.0
	_current_axis = 0.0

	_jump_pressed = false
	_jump_held = false
	_jump_released = false

	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0

	velocity = initial_velocity

	if sprite:
		sprite.flip_h = initial_flip_h

func get_lever_push_direction() -> float:
	if not alive or _replay_done:
		return 0.0
	return _current_axis

func _physics_process(delta: float) -> void:
	if not alive:
		return

	var on_floor_now := is_on_floor()

	if not _replay_done:
		_step_replay_inputs()
	else:
		_linger_t += delta
		_current_axis = 0.0
		_jump_pressed = false
		_jump_held = false
		_jump_released = false
		if _linger_t >= linger_after_replay:
			queue_free()

	if on_floor_now:
		_coyote_timer = coyote_time
	else:
		_coyote_timer = max(_coyote_timer - delta, 0.0)

	if _jump_pressed:
		_jump_buffer_timer = jump_buffer_time
	else:
		_jump_buffer_timer = max(_jump_buffer_timer - delta, 0.0)

	if not on_floor_now:
		velocity.y += _get_current_gravity() * delta

	if velocity.y > max_fall_speed:
		velocity.y = max_fall_speed

	if _jump_buffer_timer > 0.0 and (on_floor_now or _coyote_timer > 0.0):
		_do_jump()

	if _jump_released and velocity.y < 0.0:
		velocity.y *= jump_cut_multiplier

	_handle_horizontal_movement(_current_axis)

	_try_corner_correction(delta)
	_try_ledge_catch(delta)

	move_and_slide()
	_update_animation()

func _step_replay_inputs() -> void:
	if _i >= _inputs.size():
		_replay_done = true
		_current_axis = 0.0
		_jump_pressed = false
		_jump_held = false
		_jump_released = false
		return

	var f: Dictionary = _inputs[_i]
	_i += 1

	_current_axis = float(f.get("axis", 0.0))
	_jump_pressed = bool(f.get("jump_pressed", false))
	_jump_held = bool(f.get("jump_held", false))
	_jump_released = bool(f.get("jump_released", false))

func _do_jump() -> void:
	velocity.y = jump_velocity
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0

func _get_current_gravity() -> float:
	var g := gravity

	if not is_on_floor() and abs(velocity.y) <= apex_velocity_threshold:
		g *= apex_gravity_multiplier

	return g

func _handle_horizontal_movement(axis: float) -> void:
	var current_speed := speed

	if not is_on_floor() and abs(velocity.y) <= apex_velocity_threshold:
		current_speed *= apex_speed_multiplier

	if _replay_done:
		velocity.x = move_toward(velocity.x, 0.0, ground_stop_rate)
	elif axis != 0.0:
		velocity.x = axis * current_speed
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

func _update_animation() -> void:
	if velocity.x > 0.0:
		sprite.flip_h = false
	elif velocity.x < 0.0:
		sprite.flip_h = true

	if is_on_floor():
		sprite.play("idle" if abs(velocity.x) < 0.1 else "run")
	else:
		sprite.play("jump")

func kill_player() -> void:
	queue_free()
