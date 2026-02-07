extends CharacterBody2D

const SPEED = 150.0
const JUMP_VELOCITY = -300.0

@onready var sprite = $AnimatedSprite2D
@onready var cooldownTimer = $Timer

var alive := true

# Rewind gating
var rewind_ready := false
var rewinding := false

# How much history we keep (also what can be rewound)
var rewind_duration := 3.0

# Global rewind speed (shared via manager)
var rewind_speed := 0.5

# NEW: maximum time you can hold rewind in one use
var max_rewind_time := 10.0

# edge detection so we only start/stop once
var _was_rewinding := false

# Track how long the current rewind lasted (seconds)
var rewind_time_used: float = 0.0

# gravity
var gravity: float = float(ProjectSettings.get_setting("physics/2d/default_gravity"))

func kill_player() -> void:
	alive = false
	if RewindManager.is_rewinding:
		RewindManager.stop_rewind()

func _exit_tree() -> void:
	if RewindManager.is_rewinding:
		RewindManager.stop_rewind()

func _physics_process(delta: float) -> void:
	if not alive:
		return

	# Input -> rewinding state
	if Input.is_action_pressed("rewind") and rewind_ready:
		rewinding = true
	elif Input.is_action_pressed("rewind") and not rewind_ready:
		print("Can't rewind right now.")
		rewinding = false
	else:
		rewinding = false

	# Start rewind (edge)
	if rewinding and not _was_rewinding:
		rewind_time_used = 0.0
		RewindManager.buffer_seconds = rewind_duration
		RewindManager.rewind_speed = rewind_speed
		RewindManager.start_rewind()

	# Accumulate time while rewinding
	if rewinding:
		rewind_time_used += delta

		# Enforce maximum rewind duration
		if rewind_time_used >= max_rewind_time:
			rewinding = false

	# Stop rewind (edge) + start cooldown equal to time used
	if not rewinding and _was_rewinding:
		RewindManager.stop_rewind()
		rewind_ready = false

		# Cooldown equals the rewind duration just used
		var cd: float = max(0.05, min(rewind_time_used, max_rewind_time))
		cooldownTimer.stop()
		cooldownTimer.wait_time = cd
		cooldownTimer.start()

	_was_rewinding = rewinding

	# If rewinding, do NOT run forward movement
	if RewindManager.is_rewinding:
		return

	move_player(delta)

func _on_timer_timeout() -> void:
	rewind_ready = true

func move_player(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity.y += gravity * delta

	# Jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Horizontal
	var direction := Input.get_axis("move_left", "move_right")

	if direction > 0:
		sprite.flip_h = false
	elif direction < 0:
		sprite.flip_h = true

	if is_on_floor():
		if direction == 0:
			sprite.play("idle")
		else:
			sprite.play("run")
	else:
		sprite.play("jump")

	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED)

	move_and_slide()
