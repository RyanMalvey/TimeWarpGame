extends Node2D

@export var min_seconds_between_glitches: float = 15.0
@export var max_seconds_between_glitches: float = 40.0

@export var idle_animation: StringName = "idle"
@export var glitch_animation: StringName = "glitching"

@onready var anim: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	randomize()
	anim.play(idle_animation)
	_glitch_loop()


func _glitch_loop() -> void:
	while is_inside_tree():
		var wait_time := randf_range(
			min_seconds_between_glitches,
			max_seconds_between_glitches
		)

		await get_tree().create_timer(wait_time).timeout

		if not is_inside_tree():
			return

		anim.play(glitch_animation)
		await anim.animation_finished

		if not is_inside_tree():
			return

		anim.play(idle_animation)
