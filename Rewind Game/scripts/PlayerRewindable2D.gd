extends Rewindable2D
class_name PlayerRewindable2D

# Records the "intent" each physics tick so the clone can re-simulate under physics.
func capture_extra() -> Dictionary:
	return {
		"axis": Input.get_axis("move_left", "move_right"),
		"jump": Input.is_action_just_pressed("jump"),
	}
