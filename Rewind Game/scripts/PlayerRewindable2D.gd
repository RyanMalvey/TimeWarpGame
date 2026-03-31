extends Rewindable2D
class_name PlayerRewindable2D

# Records the "intent" each physics tick so the clone can re-simulate under physics.
func capture_extra() -> Dictionary:
	return {
		"axis": Input.get_axis("move_left", "move_right"),
		"jump_pressed": Input.is_action_just_pressed("jump"),
		"jump_held": Input.is_action_pressed("jump"),
		"jump_released": Input.is_action_just_released("jump"),
	}

# --- clone replay buffer (only filled while rewinding) ---
var _capturing_rewind: bool = false
var _rewound_inputs: Array[Dictionary] = []

func begin_rewind() -> void:
	super()
	_capturing_rewind = true
	_rewound_inputs.clear()

func end_rewind() -> void:
	super()
	_capturing_rewind = false
	# NOTE: we don't clear here — CloneTrailController will consume it.

# Called by Rewindable2D every time a frame is popped during rewind.
func _on_rewind_frame_popped(frame: Dictionary) -> void:
	if not _capturing_rewind:
		return

	var extra: Dictionary = frame.get("extra", {})
	_rewound_inputs.append({
		"axis": float(extra.get("axis", 0.0)),
		"jump_pressed": bool(extra.get("jump_pressed", false)),
		"jump_held": bool(extra.get("jump_held", false)),
		"jump_released": bool(extra.get("jump_released", false)),
	})

# CloneTrailController calls this when rewind stops.
# Returns inputs in FORWARD order (oldest -> newest), and clears the buffer.
func consume_rewound_inputs() -> Array[Dictionary]:
	if _rewound_inputs.is_empty():
		return []

	var out: Array[Dictionary] = _rewound_inputs.duplicate(true)

	# Popped order is newest->oldest; we want oldest->newest for replay.
	out.reverse()

	_rewound_inputs.clear()
	return out
