extends Node

signal rewind_started
signal rewind_stopped

@export var buffer_seconds: float = 3.0
@export var rewind_speed: float = 0.5  # 0.5 = half-speed rewind, 2.0 = double speed

# NEW: how fast rewind energy recharges (seconds of rewind per second)
@export var recharge_rate: float = 1.0

var is_rewinding: bool = false

# NEW: current rewind energy in seconds (0..buffer_seconds)
var rewind_energy: float = 0.0

var _rewindables: Array[Node] = []

func _ready() -> void:
	# NEW: start full
	rewind_energy = buffer_seconds

func get_rewind_state() -> String:
	# "rewinding" takes priority
	if is_rewinding:
		return "rewinding"

	# Not rewinding: either full or recharging
	if rewind_energy >= buffer_seconds - 0.0001:
		return "full"

	return "recharging"


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
	# NEW: don't allow rewind if empty
	if rewind_energy <= 0.0:
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

# NEW: UI helper (0..1)
func get_rewind_percent() -> float:
	if buffer_seconds <= 0.0:
		return 0.0
	return clamp(rewind_energy / buffer_seconds, 0.0, 1.0)

func _physics_process(delta: float) -> void:
	# NEW: drain/recharge the rewind "energy"
	if is_rewinding:
		rewind_energy -= delta
		if rewind_energy <= 0.0:
			rewind_energy = 0.0
			# Auto-stop when empty
			stop_rewind()
	else:
		rewind_energy += delta * recharge_rate
		rewind_energy = min(rewind_energy, buffer_seconds)

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
