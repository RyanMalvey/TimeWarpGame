extends CharacterBody2D
class_name PlayerClone

@export var SPEED: float = 150.0
@export var JUMP_VELOCITY: float = -300.0

# How long the clone sticks around after it finishes replaying inputs
@export var linger_after_replay: float = 2.0

@onready var sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")

var alive: bool = true

var _inputs: Array[Dictionary] = []
var _i: int = 0
var _replay_done: bool = false
var _linger_t: float = 0.0

var gravity: float = float(ProjectSettings.get_setting("physics/2d/default_gravity"))

func setup_replay(inputs: Array[Dictionary], initial_velocity: Vector2, initial_flip_h: bool) -> void:
	_inputs = inputs
	_i = 0
	_replay_done = false
	_linger_t = 0.0
	velocity = initial_velocity

	if sprite != null:
		sprite.flip_h = initial_flip_h

func kill_player() -> void:
	alive = false
	queue_free()

func _physics_process(delta: float) -> void:
	if not alive:
		return

	# Gravity always applies (clone is real physics)
	if not is_on_floor():
		velocity.y += gravity * delta

	if not _replay_done:
		_step_replay_inputs()
	else:
		# After replay: just exist as a physical object for a bit (jumpable platform)
		_linger_t += delta
		# Slow horizontal drift to zero
		velocity.x = move_toward(velocity.x, 0.0, SPEED)

		if _linger_t >= linger_after_replay:
			queue_free()

	_update_animation()
	move_and_slide()

func _step_replay_inputs() -> void:
	if _i >= _inputs.size():
		_replay_done = true
		_linger_t = 0.0
		return

	var f: Dictionary = _inputs[_i]
	_i += 1

	var axis: float = float(f.get("axis", 0.0))
	var jump: bool = bool(f.get("jump", false))

	# Jump
	if jump and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Horizontal
	if axis != 0.0:
		velocity.x = axis * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED)

func _update_animation() -> void:
	if sprite == null:
		return

	if velocity.x > 0.0:
		sprite.flip_h = false
	elif velocity.x < 0.0:
		sprite.flip_h = true

	if is_on_floor():
		if abs(velocity.x) < 0.1:
			sprite.play("idle")
		else:
			sprite.play("run")
	else:
		sprite.play("jump")
