extends AnimatableBody2D

@onready var anim: AnimationPlayer = $AnimationPlayer

@export var anim_name: StringName = "move"
@export var forward_speed: float = 1.0
@export var rewind_speed_multiplier: float = 1.0

var _was_rewinding := false

func _ready() -> void:
	anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	anim.play(anim_name)
	anim.speed_scale = forward_speed

func _physics_process(_delta: float) -> void:
	var rw := RewindManager.is_rewinding

	if rw != _was_rewinding:
		if rw:
			# Use the ANIMATION-specific rewind speed (not the buffered-history scrub speed)
			anim.speed_scale = -absf(forward_speed) * RewindManager.anim_rewind_speed * rewind_speed_multiplier
			if not anim.is_playing():
				anim.play()
		else:
			anim.speed_scale = forward_speed
			if not anim.is_playing():
				anim.play()

		_was_rewinding = rw
