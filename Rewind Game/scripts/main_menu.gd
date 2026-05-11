extends Control

@export_file("*.tscn") var level_1_scene: String = "res://levels/level_1.tscn"
@export_file("*.tscn") var settings_scene: String = ""

func _on_start_pressed() -> void:
	if level_1_scene != "":
		get_tree().change_scene_to_file(level_1_scene)


func _on_settings_pressed() -> void:
	if settings_scene != "":
		get_tree().change_scene_to_file(settings_scene)


func _on_quit_pressed() -> void:
	get_tree().quit()
