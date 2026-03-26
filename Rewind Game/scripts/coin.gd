extends Area2D

@onready var animation_player = $AnimationPlayer

func _on_body_entered(body):
	if not body.is_in_group("Players"):
		return
	animation_player.play("pickup")
