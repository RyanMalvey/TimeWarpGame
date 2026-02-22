extends Node
class_name Rewindable2D

@export var target_path: NodePath = NodePath("..")
@export var record_velocity: bool = true
@export var disable_collisions_while_rewinding: bool = false
@export var collider_path: NodePath = NodePath("")

var _target: Node2D
var _collider: CollisionShape2D
var _frames: Array[Dictionary] = []
var _accum: float = 0.0
var _has_segment: bool = false

var _from_pos: Vector2
var _to_pos: Vector2
var _from_rot: float
var _to_rot: float
var _from_vel: Vector2
var _to_vel: Vector2
var _current_extra: Dictionary = {}

func _ready() -> void:
	_target = get_node_or_null(target_path) as Node2D
	if disable_collisions_while_rewinding and collider_path != NodePath(""):
		_collider = get_node_or_null(collider_path) as CollisionShape2D
	RewindManager.register(self)

func _exit_tree() -> void:
	RewindManager.unregister(self)

func capture_extra() -> Dictionary: return {}
func apply_extra(_state: Dictionary) -> void: pass
func _on_rewind_frame_popped(_frame: Dictionary) -> void: pass

func record_step(max_frames: int) -> void:
	if _target == null: return
	while _frames.size() >= max_frames:
		_frames.pop_front()

	var d: Dictionary = {
		"rot": _target.rotation,
		"extra": capture_extra(),
	}

	# Check if we are on a platform to record relative position
	var on_platform := false
	if _target is CharacterBody2D and _target.is_on_floor():
		var collision = _target.get_last_slide_collision()
		if collision:
			var collider = collision.get_collider()
			if collider is AnimatableBody2D:
				d["parent_path"] = _target.get_path_to(collider)
				d["local_pos"] = collider.to_local(_target.global_position)
				on_platform = true
	
	if not on_platform:
		d["pos"] = _target.global_position

	if record_velocity:
		if _target is CharacterBody2D: d["vel"] = _target.velocity
		elif _target is RigidBody2D: d["vel"] = _target.linear_velocity

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
	if _target == null or (_frames.is_empty() and not _has_segment): return
	var step: float = 1.0 / float(Engine.physics_ticks_per_second)
	
	if not _has_segment: 
		_begin_segment()

	_accum += delta * speed
	var t: float = clampf(_accum / step, 0.0, 1.0)

	_target.global_position = _from_pos.lerp(_to_pos, t)
	_target.rotation = lerp_angle(_from_rot, _to_rot, t)

	if record_velocity:
		var v: Vector2 = _from_vel.lerp(_to_vel, t)
		if _target is CharacterBody2D: _target.velocity = v

	apply_extra(_current_extra)

	if _accum >= step:
		_accum -= step
		_from_pos = _to_pos
		_from_rot = _to_rot
		_from_vel = _to_vel
		if _frames.is_empty():
			_has_segment = false
			return
		_pop_next_to()

func _begin_segment() -> void:
	if not _frames.is_empty():
		var frame = _frames.pop_back()
		_on_rewind_frame_popped(frame)
		_from_pos = _resolve_global_pos(frame)
		_from_rot = frame.get("rot", _target.rotation)
		_from_vel = frame.get("vel", Vector2.ZERO)
	else:
		_from_pos = _target.global_position
		_from_rot = _target.rotation
		_from_vel = _get_current_velocity()

	_pop_next_to()
	_accum = 0.0
	_has_segment = true

func _pop_next_to() -> void:
	var frame: Dictionary = _frames.pop_back()
	_on_rewind_frame_popped(frame)
	
	_to_pos = _resolve_global_pos(frame)
	_to_rot = frame.get("rot", _from_rot)
	_current_extra = frame.get("extra", {})
	
	var vel_val = frame.get("vel", _from_vel)
	_to_vel = vel_val if typeof(vel_val) == TYPE_VECTOR2 else _from_vel

func _resolve_global_pos(frame: Dictionary) -> Vector2:
	if frame.has("local_pos") and frame.has("parent_path"):
		var parent = _target.get_node_or_null(frame["parent_path"])
		if parent:
			return parent.to_global(frame["local_pos"])
	return frame.get("pos", _target.global_position)

func _get_current_velocity() -> Vector2:
	if _target is CharacterBody2D: return _target.velocity
	if _target is RigidBody2D: return _target.linear_velocity
	return Vector2.ZERO
