extends Node

signal rewind_started
signal rewind_stopped

# ----------------------------
# Backing fields
# ----------------------------
var _buffer_seconds: float = 5.0
var _rewind_speed: float = 2.5
var _recharge_rate: float = 1.0
var _drain_rate: float = 1.0

# ----------------------------
# Rewind tuning (ALL here)
# ----------------------------

# How much history to keep (seconds) AND max "energy" capacity (seconds)
@export var buffer_seconds: float = 5.0:
	set(value):
		_set_buffer_seconds(value)
	get:
		return _buffer_seconds

# Rewind speed multiplier
@export var rewind_speed: float = 2.5:
	set(value):
		_rewind_speed = maxf(0.0, value)
	get:
		return _rewind_speed

# Recharge rate (seconds of rewind energy gained per second)
@export var recharge_rate: float = 1.0:
	set(value):
		_recharge_rate = maxf(0.0, value)
	get:
		return _recharge_rate

# Drain rate while rewinding (seconds of energy spent per second)
@export var drain_rate: float = 1.0:
	set(value):
		_drain_rate = maxf(0.0, value)
	get:
		return _drain_rate

# ----------------------------
# Input handling
# ----------------------------
@export var handle_input: bool = true
@export var rewind_action: StringName = &"rewind"

# ----------------------------
# Runtime state
# ----------------------------
var is_rewinding: bool = false
var rewind_energy: float = 0.0   # 0..buffer_seconds

var _rewindables: Array[Node] = []

func _ready() -> void:
	# Make sure exported inspector values are applied to backing fields
	_set_buffer_seconds(buffer_seconds)
	rewind_speed = rewind_speed
	recharge_rate = recharge_rate
	drain_rate = drain_rate

	# Start full
	rewind_energy = _buffer_seconds

func _set_buffer_seconds(value: float) -> void:
	var v := maxf(0.0, value)

	# Preserve current percent when resizing
	var pct := 0.0
	if _buffer_seconds > 0.0:
		pct = clampf(rewind_energy / _buffer_seconds, 0.0, 1.0)

	_buffer_seconds = v
	rewind_energy = clampf(pct * _buffer_seconds, 0.0, _buffer_seconds)

func register(rewindable: Node) -> void:
	if rewindable == null:
		return
	if _rewindables.has(rewindable):
		return
	_rewindables.append(rewindable)

func unregister(rewindable: Node) -> void:
	_rewindables.erase(rewindable)

func can_rewind() -> bool:
	return rewind_energy > 0.0 and _buffer_seconds > 0.0

func start_rewind() -> void:
	if is_rewinding:
		return
	if not can_rewind():
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
	return int(_buffer_seconds * float(Engine.physics_ticks_per_second))

# UI helper (0..1)
func get_rewind_percent() -> float:
	if _buffer_seconds <= 0.0:
		return 0.0
	return clampf(rewind_energy / _buffer_seconds, 0.0, 1.0)

func get_rewind_state() -> String:
	if is_rewinding:
		return "rewinding"
	if rewind_energy >= _buffer_seconds - 0.0001:
		return "full"
	return "recharging"

func _physics_process(delta: float) -> void:
	# ---- Handle input here (optional) ----
	if handle_input:
		if Input.is_action_pressed(rewind_action):
			if not is_rewinding and can_rewind():
				start_rewind()
		else:
			if is_rewinding:
				stop_rewind()

	# ---- Drain / recharge energy ----
	if is_rewinding:
		rewind_energy -= delta * _drain_rate
		if rewind_energy <= 0.0:
			rewind_energy = 0.0
			stop_rewind()
	else:
		rewind_energy += delta * _recharge_rate
		rewind_energy = min(rewind_energy, _buffer_seconds)

	# ---- Drive recording or rewinding ----
	var max_frames: int = get_max_frames()

	for r in _rewindables:
		if not is_instance_valid(r):
			continue

		if is_rewinding:
			if r.has_method("rewind_step"):
				r.rewind_step(delta, _rewind_speed)
		else:
			if r.has_method("record_step"):
				r.record_step(max_frames)
