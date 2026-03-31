extends Camera2D

@export var extra_tiles_margin: int = -1

func _ready() -> void:
	var tilemap := get_node("../../TileMap") as TileMap
	if tilemap == null:
		push_warning("Could not find ../../TileMap")
		return

	set_limits_from_tilemap(tilemap)


func set_limits_from_tilemap(tilemap: TileMap) -> void:
	var used: Rect2i = tilemap.get_used_rect()
	if used.size == Vector2i.ZERO:
		push_warning("TileMap has no used tiles.")
		return

	used.position -= Vector2i(extra_tiles_margin, extra_tiles_margin)
	used.size += Vector2i(extra_tiles_margin * 2, extra_tiles_margin * 2)

	var top_left_cell: Vector2i = used.position
	var bottom_right_cell: Vector2i = used.position + used.size - Vector2i.ONE

	var top_left_local: Vector2 = tilemap.map_to_local(top_left_cell)
	var bottom_right_local: Vector2 = tilemap.map_to_local(bottom_right_cell)

	var top_left_global: Vector2 = tilemap.to_global(top_left_local)
	var bottom_right_global: Vector2 = tilemap.to_global(bottom_right_local)

	var half_tile: Vector2 = tilemap.tile_set.tile_size / 2.0

	limit_left = int(top_left_global.x - half_tile.x)
	limit_top = int(top_left_global.y - half_tile.y)
	limit_right = int(bottom_right_global.x + half_tile.x)
	limit_bottom = int(bottom_right_global.y + half_tile.y)
