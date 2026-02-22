extends CharacterBody2D

const SPEED = 150.0
const JUMP_VELOCITY = -300.0

@onready var sprite = $AnimatedSprite2D

var alive := true
var gravity: float = float(ProjectSettings.get_setting("physics/2d/default_gravity"))

func _ready() -> void:
	# Connect to the rewind start signal so we can become a 'ghost' again
	if not RewindManager.rewind_started.is_connected(_on_rewind_started):
		RewindManager.rewind_started.connect(_on_rewind_started)

func _on_rewind_started() -> void:
	# Disable collision with clones (Layer 3) immediately when rewinding starts
	# This prevents the 'pushing' glitch when the new clone spawns
	set_collision_mask_value(3, false)

func kill_player() -> void:
	alive = false
	# Ensure collision is reset for next respawn
	set_collision_mask_value(3, false)
	
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
