extends CharacterBody2D

const SPEED = 150.0
const JUMP_VELOCITY = -300.0

@onready var sprite = $AnimatedSprite2D

var alive := true
var gravity: float = float(ProjectSettings.get_setting("physics/2d/default_gravity"))

func kill_player() -> void:
	alive = false
	# Safety: if you die during rewind, stop it so things resume cleanly
	if RewindManager.is_rewinding:
		RewindManager.stop_rewind()

func _exit_tree() -> void:
	if RewindManager.is_rewinding:
		RewindManager.stop_rewind()

func _physics_process(delta: float) -> void:
	if not alive:
		return

	# While rewinding, the manager is driving your position via rewindables.
	# So we skip movement.
	if RewindManager.is_rewinding:
		return

	move_player(delta)

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
