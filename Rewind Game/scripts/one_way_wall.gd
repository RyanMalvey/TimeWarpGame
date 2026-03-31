@tool
extends StaticBody2D
class_name OneWayWall

@export_enum("Player Passes", "Clone Passes") var pass_mode: int = 0:
	set(value):
		pass_mode = value
		_apply_collision_mode()

@export var tile_size: int = 16:
	set(value):
		tile_size = max(1, value)
		_rebuild_size()

@export_range(1, 100, 1) var width_tiles: int = 1:
	set(value):
		width_tiles = max(1, value)
		_rebuild_size()

@export_range(1, 100, 1) var height_tiles: int = 1:
	set(value):
		height_tiles = max(1, value)
		_rebuild_size()

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var polygon: Polygon2D = $Polygon2D

func _ready() -> void:
	_ensure_unique_shape()
	_rebuild_size()
	_apply_collision_mode()

func _ensure_unique_shape() -> void:
	if not is_node_ready():
		return

	if collision_shape.shape == null:
		collision_shape.shape = RectangleShape2D.new()
	else:
		# Important: this prevents all instances from sharing one shape resource
		collision_shape.shape = collision_shape.shape.duplicate(true)

func _rebuild_size() -> void:
	if not is_node_ready():
		return

	_ensure_unique_shape()

	var w := width_tiles * tile_size
	var h := height_tiles * tile_size

	var rect := collision_shape.shape as RectangleShape2D
	if rect == null:
		rect = RectangleShape2D.new()
		collision_shape.shape = rect

	rect.size = Vector2(w, h)

	var half_w := w / 2.0
	var half_h := h / 2.0

	polygon.polygon = PackedVector2Array([
		Vector2(-half_w, -half_h),
		Vector2( half_w, -half_h),
		Vector2( half_w,  half_h),
		Vector2(-half_w,  half_h),
	])

func _apply_collision_mode() -> void:
	if not is_node_ready():
		return

	# Clear only the bits you care about first
	set_collision_layer_value(2, false)
	set_collision_layer_value(3, false)
	set_collision_mask_value(2, false)
	set_collision_mask_value(3, false)

	match pass_mode:
		0: # Player Passes
			set_collision_layer_value(2, true)
			set_collision_mask_value(3, true)
		1: # Clone Passes
			set_collision_layer_value(3, true)
			set_collision_mask_value(2, true)
