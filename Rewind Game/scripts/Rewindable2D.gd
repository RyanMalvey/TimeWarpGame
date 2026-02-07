extends Node

@export var target_path: NodePath = NodePath("..")
@export var record_velocity: bool = true

@export var disable_collisions_while_rewinding: bool = false
@export var collider_path: NodePath = NodePath("") # e.g. "../CollisionShape2D"

var _target: Node2D
var _collider: CollisionShape2D

# Frame buffer (newest at end)
var _frames: Array[Dictionary] = []

# Smooth segment state
var _accum: float = 0.0
var _has_segment: bool = false

var _from_pos: Vector2
var _to_pos: Vector2
var _from_rot: float
var _to_rot: float
var _from_vel: Vector2
var _to_vel: Vector2

func _ready() -> void:
	_target = get_node_or_null(target_path) as Node2D

	if disable_collisions_while_rewinding and collider_path != NodePath(""):
		_collider = get_node_or_null(collider_path) as CollisionShape2D

	RewindManager.register(self)

func _exit_tree() -> void:
	RewindManager.unregister(self)

# --- Optional override points (for enemies that need extra state) ---
func capture_extra() -> Dictionary:
	return {}

func apply_extra(_state: Dictionary) -> void:
	pass
# ------------------------------------------------------------------

func record_step(max_frames: int) -> void:
	if _target == null:
		return

	# Keep buffer at max_frames
	while _frames.size() >= max_frames:
		_frames.pop_front()

	var d: Dictionary = {
		"pos": _target.global_position,
		"rot": _target.rotation,
		"extra": capture_extra(),
	}

	if record_velocity:
		if _target is CharacterBody2D:
			d["vel"] = (_target as CharacterBody2D).velocity
		elif _target is RigidBody2D:
			d["vel"] = (_target as RigidBody2D).linear_velocity

	_frames.append(d)

func begin_rewind() -> void:
	_accum = 0.0
	_has_segment = false

	if _collider != null:
		_collider.set_deferred("disabled", true)

func end_rewind() -> void:
	_accum = 0.0
	_has_segment = false

	if _collider != null:
		_collider.set_deferred("disabled", false)

func rewind_step(delta: float, speed: float) -> void:
	if _target == null:
		return

	# Nothing to rewind
	if _frames.is_empty() and not _has_segment:
		return

	var step: float = 1.0 / float(Engine.physics_ticks_per_second)

	# Initialize segment if needed
	if not _has_segment:
		_begin_segment()

	# Advance "rewind time"
	_accum += delta * speed

	# Interpolate within the current segment every tick (smooth!)
	var t: float = clampf(_accum / step, 0.0, 1.0)

	_target.global_position = _from_pos.lerp(_to_pos, t)
	_target.rotation = lerp_angle(_from_rot, _to_rot, t)

	# Velocity interpolation (optional)
	if record_velocity:
		var v: Vector2 = _from_vel.lerp(_to_vel, t)
		if _target is CharacterBody2D:
			(_target as CharacterBody2D).velocity = v
		elif _target is RigidBody2D:
			(_target as RigidBody2D).linear_velocity = v

	# Apply any extra state (not interpolated; last popped frame is applied)
	apply_extra(_current_extra)

	# Consume next segment when step elapsed
	if _accum >= step:
		_accum -= step
		_from_pos = _to_pos
		_from_rot = _to_rot
		_from_vel = _to_vel

		if _frames.is_empty():
			_has_segment = false
			return

		_pop_next_to()

# ---- internal helpers ----
var _current_extra: Dictionary = {}

func _begin_segment() -> void:
	_from_pos = _target.global_position
	_from_rot = _target.rotation
	_from_vel = _get_current_velocity()

	_pop_next_to()
	_accum = 0.0
	_has_segment = true

func _pop_next_to() -> void:
	var frame: Dictionary = _frames.pop_back()

	_to_pos = frame.get("pos", _from_pos)
	_to_rot = frame.get("rot", _from_rot)
	_current_extra = frame.get("extra", {})

	var vel_val = frame.get("vel", _from_vel)
	if typeof(vel_val) == TYPE_VECTOR2:
		_to_vel = vel_val
	else:
		_to_vel = _from_vel

func _get_current_velocity() -> Vector2:
	if _target is CharacterBody2D:
		return (_target as CharacterBody2D).velocity
	if _target is RigidBody2D:
		return (_target as RigidBody2D).linear_velocity
	return Vector2.ZERO
