extends Area2D

@onready var animation_player = $AnimationPlayer

func _on_body_entered(body):
	print("Coin collected!")
	animation_player.play("pickup")
