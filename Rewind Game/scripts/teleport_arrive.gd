extends Node2D

@export var fade_time: float = 0.35
@export var sound_volume_db: float = -6.0
@export var play_on_ready: bool = true

@onready var arrival_rect: ColorRect = $ArrivalRect
@onready var teleport_end_sound: AudioStreamPlayer2D = $TeleportEndSound


func _ready() -> void:
	if arrival_rect == null:
		push_error("ArrivalRect node not found. Make sure the child ColorRect is named ArrivalRect.")
		return

	if teleport_end_sound == null:
		push_error("TeleportEndSound node not found. Make sure the child AudioStreamPlayer2D is named TeleportEndSound.")
		return

	arrival_rect.visible = true
	arrival_rect.modulate.a = 1.0

	teleport_end_sound.volume_db = sound_volume_db

	if play_on_ready:
		play_effect()


func play_effect() -> void:
	arrival_rect.visible = true
	arrival_rect.modulate.a = 1.0

	teleport_end_sound.play()

	var tween := create_tween()
	tween.tween_property(arrival_rect, "modulate:a", 0.0, fade_time)

	await tween.finished

	arrival_rect.visible = false
