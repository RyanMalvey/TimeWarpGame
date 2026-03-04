extends CharacterBody2D

const SPEED = 150.0
const JUMP_VELOCITY = -300.0

@onready var sprite = $AnimatedSprite2D

var alive := true
var gravity: float = float(ProjectSettings.get_setting("physics/2d/default_gravity"))

func _ready() -> void:
	if not RewindManager.rewind_started.is_connected(_on_rewind_started):
		RewindManager.rewind_started.connect(_on_rewind_started)

func _on_rewind_started() -> void:
	# Removed the line that was disabling collision with Layer 3.
	# One-Way collision handles the "jitter" spawning naturally now.
	pass

func kill_player() -> void:
	alive = false
	if RewindManager.is_rewinding:
		RewindManager.stop_rewind()

func _physics_process(delta: float) -> void:
	if not alive or RewindManager.is_rewinding:
		return

	if not is_on_floor():
		velocity.y += gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var direction := Input.get_axis("move_left", "move_right")
	_handle_animations(direction)

	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED)

	move_and_slide()

func _handle_animations(direction: float) -> void:
	if direction > 0: sprite.flip_h = false
	elif direction < 0: sprite.flip_h = true

	if is_on_floor():
		sprite.play("idle" if direction == 0 else "run")
	else:
		sprite.play("jump")
