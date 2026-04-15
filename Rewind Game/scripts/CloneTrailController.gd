extends Node
class_name CloneTrailController

@export var clone_scene: PackedScene
@export var player_path: NodePath = NodePath("..")
@export var rewindable_path: NodePath = NodePath("../PlayerRewindable2D")
@export var clone_parent_path: NodePath = NodePath("")

func _ready() -> void:
	if not RewindManager.rewind_started.is_connected(_on_rewind_started):
		RewindManager.rewind_started.connect(_on_rewind_started)

	if not RewindManager.rewind_stopped.is_connected(_on_rewind_stopped):
		RewindManager.rewind_stopped.connect(_on_rewind_stopped)

func _on_rewind_started() -> void:
	_remove_existing_clones()

func _on_rewind_stopped() -> void:
	if clone_scene == null:
		return

	var player := get_node_or_null(player_path) as CharacterBody2D
	if player == null:
		return

	var rewindable := get_node_or_null(rewindable_path) as PlayerRewindable2D
	if rewindable == null:
		return

	var inputs: Array[Dictionary] = rewindable.consume_rewound_inputs()
	if inputs.is_empty():
		return

	var parent_node := _get_clone_parent(player)
	if parent_node == null:
		return

	var clone := clone_scene.instantiate()

	if clone is Node2D:
		clone.global_position = player.global_position

	parent_node.add_child(clone)

	var initial_vel: Vector2 = player.velocity
	var flip_h := false
	var sprite := player.get_node_or_null("AnimatedSprite2D")
	if sprite != null:
		flip_h = sprite.flip_h

	if clone.has_method("copy_tuning_from_player"):
		clone.copy_tuning_from_player(player)

	if clone.has_method("setup_replay"):
		clone.setup_replay(inputs, initial_vel, flip_h)

func _get_clone_parent(player: CharacterBody2D) -> Node:
	var parent_node: Node = null
	if clone_parent_path != NodePath(""):
		parent_node = get_node_or_null(clone_parent_path)
	if parent_node == null and player != null:
		parent_node = player.get_parent()
	return parent_node

func _remove_existing_clones() -> void:
	var player := get_node_or_null(player_path) as CharacterBody2D
	if player == null:
		return

	var parent_node := _get_clone_parent(player)
	if parent_node == null:
		return

	for child in parent_node.get_children():
		if child != null and child.is_in_group("Clones"):
			child.queue_free()
