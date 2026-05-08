extends AnimatedSprite2D

@export var idle_animation: String = "default"
@export var walking_animation: String = "person_walking"

@export var min_wait_time: float = 10.0
@export var max_wait_time: float = 30.0

func _ready() -> void:
	randomize()
	play(idle_animation)
	_loop_random_person()

func _loop_random_person() -> void:
	while true:
		await get_tree().create_timer(randf_range(min_wait_time, max_wait_time)).timeout

		if randi() % 2 == 0:
			play(walking_animation)
		else:
			play_backwards(walking_animation)

		await animation_finished

		play(idle_animation)
