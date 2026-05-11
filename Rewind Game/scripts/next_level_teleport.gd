extends Node2D

@export var charge_time: float = 1.5
@export var drain_speed: float = 2.0
@export var max_charge_height: float = 48.0
@export var charge_width: float = 28.0
@export var beam_bottom_y: float = -8.0

@onready var charge_rect: ColorRect = $ChargeRect

var player_inside := false
var charge_amount := 0.0
var teleporting := false


func _ready() -> void:
	charge_rect.color = Color(0.25, 0.75, 1.0, 0.28)
	charge_rect.size = Vector2(charge_width, 0)
	charge_rect.position = Vector2(-charge_width / 2.0, beam_bottom_y)
	charge_rect.visible = false


func _process(delta: float) -> void:
	if teleporting:
		return

	if player_inside:
		charge_amount += delta
	else:
		charge_amount -= delta * drain_speed

	charge_amount = clamp(charge_amount, 0.0, charge_time)

	var fill_percent := charge_amount / charge_time
	var current_height := max_charge_height * fill_percent

	charge_rect.visible = current_height > 0.0
	charge_rect.size = Vector2(charge_width, current_height)

	# This makes it grow upward from the pad
	charge_rect.position = Vector2(
		-charge_width / 2.0,
		beam_bottom_y - current_height
	)

	# Later, this fill_percent value can drive pitch:
	# pitch = lerp(low_pitch, high_pitch, fill_percent)

	if fill_percent >= 1.0:
		teleport_to_next_level()


func teleport_to_next_level() -> void:
	teleporting = true

	var current_scene_file := get_tree().current_scene.scene_file_path
	var current_level_number := current_scene_file.get_file().get_basename().split("_")[-1].to_int()
	var next_level_number := current_level_number + 1
	var next_level_path := "res://levels/level_" + str(next_level_number) + ".tscn"

	get_tree().call_deferred("change_scene_to_file", next_level_path)


func _on_player_detector_body_entered(body: Node2D) -> void:
	if body.is_in_group("Players"):
		player_inside = true


func _on_player_detector_body_exited(body: Node2D) -> void:
	if body.is_in_group("Players"):
		player_inside = false
