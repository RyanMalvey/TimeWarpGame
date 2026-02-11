extends Node
class_name CloneTrailController

# Drag your PlayerClone.tscn here in the inspector
@export var clone_scene: PackedScene

# Where the player node is relative to this node
@export var player_path: NodePath = NodePath("..")

# Where the PlayerRewindable2D node is relative to this node (adjust if needed)
@export var rewindable_path: NodePath = NodePath("../PlayerRewindable2D")

# Optional: put clones under a specific parent (so they’re not children of the player)
# If blank, we spawn in the player's parent.
@export var clone_parent_path: NodePath = NodePath("")

func _ready() -> void:
	# Connect once. If you already autoload RewindManager, this works.
	if not RewindManager.rewind_stopped.is_connected(_on_rewind_stopped):
		RewindManager.rewind_stopped.connect(_on_rewind_stopped)

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

	# Decide parent for clone
	var parent_node: Node = null
	if clone_parent_path != NodePath(""):
		parent_node = get_node_or_null(clone_parent_path)
	if parent_node == null:
		parent_node = player.get_parent()

	if parent_node == null:
		return

	var clone := clone_scene.instantiate()
	parent_node.add_child(clone)

	# Spawn clone at the player's current position (post-rewind).
	if clone is Node2D:
		(clone as Node2D).global_position = player.global_position

	# Pass initial conditions if clone supports it.
	var initial_vel: Vector2 = player.velocity
	var flip_h := false
	var sprite := player.get_node_or_null("AnimatedSprite2D")
	if sprite != null and sprite.has_method("get"):
		flip_h = sprite.flip_h

	if clone.has_method("setup_replay"):
		clone.setup_replay(inputs, initial_vel, flip_h)
