extends CharacterBody2D

# =========================
# Core movement tuning
# =========================
@export var speed: float = 150.0
@export var jump_velocity: float = -300.0
@export var ground_stop_rate: float = 150.0

# =========================
# Variable jump height
# Tap jump = short hop
# Hold jump = full jump
# Lower value = harsher cut
# =========================
@export_range(0.0, 1.0, 0.01) var jump_cut_multiplier: float = 0.45

# =========================
# Jump buffering
# Press jump slightly early and it still jumps on landing
# =========================
@export var jump_buffer_time: float = 0.12

# =========================
# Coyote time
# Jump slightly after leaving a platform
# =========================
@export var coyote_time: float = 0.10

# =========================
# Apex modifiers
# Near the top of the jump:
# - lighter gravity
# - slight horizontal speed boost
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
# corner_correction_pixels:
#   helps avoid bonking a corner by 1-2 pixels while moving upward
#
# ledge_catch_pixels:
#   helps you barely catch the top of a platform while descending
# =========================
@export_range(0, 8, 1) var corner_correction_pixels: int = 4
@export_range(0, 8, 1) var ledge_catch_pixels: int = 4

# =========================
# Rewind animation tuning
# =========================
@export var rewind_move_threshold: float = 0.5
@export var rewind_vertical_threshold: float = 0.15

@onready var sprite = $AnimatedSprite2D

var alive := true
var gravity: float = float(ProjectSettings.get_setting("physics/2d/default_gravity"))

var _jump_buffer_timer: float = 0.0
var _coyote_timer: float = 0.0
var _was_on_floor: bool = false

# Track which direction the player was facing during forward-time gameplay.
# We keep this during rewind so the player appears to move backward through time.
var _facing_right: bool = true

# Track position between rendered frames so rewind animation can be chosen
# from actual rewound motion.
var _last_rewind_position: Vector2

func _ready() -> void:
	_last_rewind_position = global_position

	if not RewindManager.rewind_started.is_connected(_on_rewind_started):
		RewindManager.rewind_started.connect(_on_rewind_started)

func _process(_delta: float) -> void:
	if not alive:
		return

	if RewindManager.is_rewinding:
		_handle_rewind_animation()

	_last_rewind_position = global_position

func _on_rewind_started() -> void:
	# Reset the sampled rewind position right when rewind begins
	# so the first frame does not get a huge delta.
	_last_rewind_position = global_position

func kill_player() -> void:
	alive = false
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

	# Refresh coyote timer whenever grounded
	if on_floor_now:
		_coyote_timer = coyote_time
	else:
		_coyote_timer = max(_coyote_timer - delta, 0.0)

	# Jump buffer input
	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time
	else:
		_jump_buffer_timer = max(_jump_buffer_timer - delta, 0.0)

	# Gravity
	if not on_floor_now:
		velocity.y += _get_current_gravity() * delta

	# Clamp fall speed
	if velocity.y > max_fall_speed:
		velocity.y = max_fall_speed

	# Jump execution from floor, coyote time, or jump buffer
	if _jump_buffer_timer > 0.0 and (on_floor_now or _coyote_timer > 0.0):
		_do_jump()

	# Variable jump height
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_cut_multiplier

	var direction := Input.get_axis("move_left", "move_right")
	_handle_horizontal_movement(direction)

	# Edge forgiveness before movement
	_try_corner_correction(delta)
	_try_ledge_catch(delta)

	move_and_slide()

	_handle_animations(direction)
	_was_on_floor = is_on_floor()

func _do_jump() -> void:
	velocity.y = jump_velocity
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0

func _get_current_gravity() -> float:
	var g := gravity

	# Apex modifier: lighter gravity near the top of the jump
	if not is_on_floor() and abs(velocity.y) <= apex_velocity_threshold:
		g *= apex_gravity_multiplier

	return g

func _handle_horizontal_movement(direction: float) -> void:
	var current_speed := speed

	# Apex modifier: slight horizontal boost near jump apex
	if not is_on_floor() and abs(velocity.y) <= apex_velocity_threshold:
		current_speed *= apex_speed_multiplier

	if direction != 0.0:
		velocity.x = direction * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, ground_stop_rate)

func _try_corner_correction(delta: float) -> void:
	# Prevent tiny upward corner bonks by nudging sideways a few pixels.
	# Only applies while moving upward.
	if corner_correction_pixels <= 0:
		return
	if velocity.y >= 0.0:
		return

	var vertical_motion := Vector2(0.0, velocity.y * delta)

	# If we're not about to hit something above, do nothing.
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
	# Helps catch the top of a platform when descending and barely clipping the edge.
	if ledge_catch_pixels <= 0:
		return
	if is_on_floor():
		return
	if velocity.y < 0.0:
		return
	if abs(velocity.x) < 0.01:
		return

	var full_motion := velocity * delta

	# Only try this if our current motion would collide.
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

	# Face backward relative to current rewind movement.
	# Also update _facing_right so when rewind ends, normal gameplay
	# continues from the current visible facing direction.
	if dx > rewind_move_threshold:
		sprite.flip_h = true
		_facing_right = false
	elif dx < -rewind_move_threshold:
		sprite.flip_h = false
		_facing_right = true
	# If horizontal motion is tiny, keep the current facing.

	# Prioritize vertical motion first so airborne rewind segments play jump.
	if abs(dy) > rewind_vertical_threshold:
		_play_reversed("jump")
	elif abs(dx) > rewind_move_threshold:
		_play_reversed("run")
	else:
		_play_reversed("idle")

func _play_forward(name: String) -> void:
	if sprite.animation != name or sprite.speed_scale < 0.0:
		sprite.play(name)
	sprite.speed_scale = 1.0

func _play_reversed(name: String) -> void:
	if sprite.animation != name or sprite.speed_scale >= 0.0:
		sprite.play(name, -1.0, true)
	else:
		sprite.speed_scale = -1.0
