extends CharacterBody2D
class_name PlayerClone

@export var SPEED: float = 150.0
@export var JUMP_VELOCITY: float = -300.0
@export var linger_after_replay: float = 2.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

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

	# All layer/mask logic has been removed. 
	# Please set Layer 3 and Masks 1 & 2 in the Inspector.

	if sprite:
		sprite.flip_h = initial_flip_h

func _physics_process(delta: float) -> void:
	if not alive: return
	
	if not is_on_floor():
		velocity.y += gravity * delta

	if not _replay_done:
		_step_replay_inputs()
	else:
		_linger_t += delta
		velocity.x = move_toward(velocity.x, 0.0, SPEED)
		if _linger_t >= linger_after_replay:
			queue_free()

	_update_animation()
	move_and_slide()

func _step_replay_inputs() -> void:
	if _i >= _inputs.size():
		_replay_done = true
		return
		
	var f: Dictionary = _inputs[_i]
	_i += 1
	
	var axis: float = float(f.get("axis", 0.0))
	if bool(f.get("jump", false)) and is_on_floor():
		velocity.y = JUMP_VELOCITY
		
	velocity.x = axis * SPEED if axis != 0.0 else move_toward(velocity.x, 0.0, SPEED)

func _update_animation() -> void:
	if velocity.x > 0.0: sprite.flip_h = false
	elif velocity.x < 0.0: sprite.flip_h = true
	
	if is_on_floor():
		sprite.play("idle" if abs(velocity.x) < 0.1 else "run")
	else:
		sprite.play("jump")

func kill_player() -> void:
	queue_free()
