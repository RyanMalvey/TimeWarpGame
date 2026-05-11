extends Node2D

@export var charge_time: float = 1.5
@export var drain_speed: float = 2.0
@export var max_charge_height: float = 48.0
@export var charge_width: float = 28.0
@export var beam_bottom_y: float = -8.0

@export var min_pitch: float = 0.75
@export var max_pitch: float = 1.85
@export var tone_volume_db: float = -10.0

@export var teleport_start_volume_db: float = -6.0
@export var teleport_wait_time: float = 1.0
@export var fade_time: float = 0.25

@onready var charge_rect: ColorRect = $ChargeRect
@onready var charge_tone: AudioStreamPlayer2D = $ChargeTone
@onready var teleport_start: AudioStreamPlayer2D = $TeleportStart

var player_inside := false
var charge_amount := 0.0
var teleporting := false
var body_to_teleport: Node2D = null


func _ready() -> void:
	charge_rect.color = Color(0.25, 0.75, 1.0, 0.28)
	charge_rect.size = Vector2(charge_width, 0)
	charge_rect.position = Vector2(-charge_width / 2.0, beam_bottom_y)
	charge_rect.visible = false

	charge_tone.volume_db = tone_volume_db
	charge_tone.pitch_scale = min_pitch
	charge_tone.stop()

	teleport_start.volume_db = teleport_start_volume_db


func _process(delta: float) -> void:
	if teleporting:
		return

	if player_inside:
		charge_amount += delta

		if not charge_tone.playing:
			charge_tone.play()
	else:
		charge_amount -= delta * drain_speed

		if charge_tone.playing:
			charge_tone.stop()

	charge_amount = clamp(charge_amount, 0.0, charge_time)

	var fill_percent := charge_amount / charge_time
	var current_height := max_charge_height * fill_percent

	update_charge_visual(current_height)
	update_charge_audio(fill_percent)

	if fill_percent >= 1.0:
		teleport_out()


func update_charge_visual(current_height: float) -> void:
	charge_rect.visible = current_height > 0.0
	charge_rect.size = Vector2(charge_width, current_height)

	# Grow upward from the pad
	charge_rect.position = Vector2(
		-charge_width / 2.0,
		beam_bottom_y - current_height
	)


func update_charge_audio(fill_percent: float) -> void:
	charge_tone.pitch_scale = lerp(min_pitch, max_pitch, fill_percent)
	charge_tone.volume_db = lerp(tone_volume_db - 8.0, tone_volume_db, fill_percent)


func teleport_out() -> void:
	teleporting = true
	player_inside = false

	if charge_tone.playing:
		charge_tone.stop()

	if body_to_teleport != null:
		body_to_teleport.visible = false
		body_to_teleport.set_physics_process(false)
		body_to_teleport.set_process(false)

	teleport_start.play()

	var tween := create_tween()
	tween.tween_property(charge_rect, "modulate:a", 0.0, fade_time)

	await get_tree().create_timer(teleport_wait_time).timeout

	switch_to_next_level()


func switch_to_next_level() -> void:
	var current_scene_file := get_tree().current_scene.scene_file_path
	var current_level_number := current_scene_file.get_file().get_basename().split("_")[-1].to_int()
	var next_level_number := current_level_number + 1
	var next_level_path := "res://levels/level_" + str(next_level_number) + ".tscn"

	get_tree().call_deferred("change_scene_to_file", next_level_path)


func _on_player_detector_body_entered(body: Node2D) -> void:
	if body.is_in_group("Players"):
		player_inside = true
		body_to_teleport = body


func _on_player_detector_body_exited(body: Node2D) -> void:
	if body.is_in_group("Players"):
		player_inside = false

		if body_to_teleport == body:
			body_to_teleport = null
