extends CharacterBody2D
class_name PlayerClone

signal cleared_player

@export var SPEED: float = 150.0
@export var JUMP_VELOCITY: float = -300.0
@export var linger_after_replay: float = 2.0

@onready var sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
@onready var clear_detector: Area2D = get_node_or_null("ClearDetector")

var alive: bool = true
var _inputs: Array[Dictionary] = []
var _i: int = 0
var _replay_done: bool = false
var _linger_t: float = 0.0
var _is_cleared: bool = false # Prevents double-triggering
var gravity: float = float(ProjectSettings.get_setting("physics/2d/default_gravity"))

func _ready() -> void:
	if clear_detector:
		clear_detector.body_exited.connect(_on_body_exited)
		# Wait for physics to sync before checking if we are already separate
		_check_initial_overlap.call_deferred()

func _check_initial_overlap() -> void:
	# Wait 2 physics frames to ensure Godot knows exactly where the player is
	await get_tree().physics_frame
	await get_tree().physics_frame
	
	if _is_cleared: return
	
	if clear_detector:
		var bodies = clear_detector.get_overlapping_bodies()
		var player_found = false
		for b in bodies:
			if b is CharacterBody2D and b.get_collision_layer_value(2):
				player_found = true
				break
		
		if not player_found:
			_handle_separation()

func _on_body_exited(body: Node2D) -> void:
	# Check if the exiting body is the Player (Layer 2)
	if body is CharacterBody2D and body.get_collision_layer_value(2):
		_handle_separation()

func _handle_separation() -> void:
	if _is_cleared: return
	_is_cleared = true
	
	# The 0.1s buffer you requested
	await get_tree().create_timer(0.1).timeout
	
	cleared_player.emit()
	
	if clear_detector:
		clear_detector.queue_free()

func setup_replay(inputs: Array[Dictionary], initial_velocity: Vector2, initial_flip_h: bool) -> void:
	_inputs = inputs
	_i = 0
	_replay_done = false
	_linger_t = 0.0
	velocity = initial_velocity

	set_collision_layer_value(1, false)
	set_collision_layer_value(2, false)
	set_collision_layer_value(3, true)
	
	set_collision_mask_value(1, true)
	set_collision_mask_value(2, false)
	set_collision_mask_value(3, false)

	if sprite != null:
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
	var jump: bool = bool(f.get("jump", false))
	if jump and is_on_floor():
		velocity.y = JUMP_VELOCITY
	if axis != 0.0:
		velocity.x = axis * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED)

func _update_animation() -> void:
	if sprite == null: return
	if velocity.x > 0.0: sprite.flip_h = false
	elif velocity.x < 0.0: sprite.flip_h = true
	if is_on_floor():
		if abs(velocity.x) < 0.1: sprite.play("idle")
		else: sprite.play("run")
	else: sprite.play("jump")

func kill_player() -> void:
	alive = false
	queue_free()
