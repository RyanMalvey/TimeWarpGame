extends Node

signal rewind_started
signal rewind_stopped

@export var buffer_seconds: float = 3.0
@export var rewind_speed: float = 0.5  # 0.5 = half-speed rewind, 2.0 = double speed

var is_rewinding: bool = false

var _rewindables: Array[Node] = []

func register(rewindable: Node) -> void:
	if rewindable == null:
		return
	if _rewindables.has(rewindable):
		return
	_rewindables.append(rewindable)

func unregister(rewindable: Node) -> void:
	_rewindables.erase(rewindable)

func start_rewind() -> void:
	if is_rewinding:
		return
	is_rewinding = true
	emit_signal("rewind_started")
	for r in _rewindables:
		if is_instance_valid(r) and r.has_method("begin_rewind"):
			r.begin_rewind()

func stop_rewind() -> void:
	if not is_rewinding:
		return
	is_rewinding = false
	emit_signal("rewind_stopped")
	for r in _rewindables:
		if is_instance_valid(r) and r.has_method("end_rewind"):
			r.end_rewind()

func get_max_frames() -> int:
	return int(buffer_seconds * float(Engine.physics_ticks_per_second))

func _physics_process(delta: float) -> void:
	# Drive recording or rewinding for all registered objects.
	var max_frames: int = get_max_frames()
	for r in _rewindables:
		if not is_instance_valid(r):
			continue

		if is_rewinding:
			if r.has_method("rewind_step"):
				r.rewind_step(delta, rewind_speed)
		else:
			if r.has_method("record_step"):
				r.record_step(max_frames)
