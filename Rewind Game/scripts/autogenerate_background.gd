@tool
extends Node

@export var tilemap: TileMap

@export var terrain_layer: int = 0
@export var background_layer: int = 1
@export var background_source_id: int = 1

@export var clear_background_first: bool = true
@export var inner_margin_cells: int = 0

# Atlas coordinates in the background atlas source.
# These are tile-grid coordinates, not pixel coordinates.
@export var tile_1x1: Vector2i = Vector2i(2, 2)
@export var tile_1x2: Vector2i = Vector2i(2, 0)
@export var tile_2x1: Vector2i = Vector2i(0, 2)
@export var tile_2x2: Vector2i = Vector2i(0, 0)

@export var generate_now: bool = false:
	set(value):
		generate_now = false
		if Engine.is_editor_hint():
			generate_background()


func generate_background() -> void:
	if tilemap == null:
		push_warning("Missing tilemap.")
		return

	if clear_background_first:
		tilemap.clear_layer(background_layer)

	var terrain_cells: Array[Vector2i] = tilemap.get_used_cells(terrain_layer)

	if terrain_cells.is_empty():
		push_warning("Terrain layer has no used cells.")
		return

	var bounds: Rect2i = get_bounds_from_cells(terrain_cells)

	bounds.position += Vector2i(inner_margin_cells, inner_margin_cells)
	bounds.size -= Vector2i(inner_margin_cells * 2, inner_margin_cells * 2)

	if bounds.size.x <= 0 or bounds.size.y <= 0:
		push_warning("Bounds are too small after applying margin.")
		return

	var blocked := {}

	# Mark terrain as blocked first.
	for terrain_cell in terrain_cells:
		blocked[terrain_cell] = true

	# Parse every cell inside the bounds, starting bottom-left.
	for y in range(bounds.position.y + bounds.size.y - 1, bounds.position.y - 1, -1):
		for x in range(bounds.position.x, bounds.position.x + bounds.size.x):
			var origin := Vector2i(x, y)

			if blocked.has(origin):
				continue

			var candidates := []

			if can_place(origin, get_2x2_offsets(), bounds, blocked):
				candidates.append({
					"atlas": tile_2x2,
					"offsets": get_2x2_offsets()
				})

			if can_place(origin, get_2x1_offsets(), bounds, blocked):
				candidates.append({
					"atlas": tile_2x1,
					"offsets": get_2x1_offsets()
				})

			if can_place(origin, get_1x2_offsets(), bounds, blocked):
				candidates.append({
					"atlas": tile_1x2,
					"offsets": get_1x2_offsets()
				})

			if can_place(origin, get_1x1_offsets(), bounds, blocked):
				candidates.append({
					"atlas": tile_1x1,
					"offsets": get_1x1_offsets()
				})

			if candidates.is_empty():
				continue

			var selected = candidates.pick_random()

			tilemap.set_cell(
				background_layer,
				origin,
				background_source_id,
				selected["atlas"]
			)

			mark_blocked(origin, selected["offsets"], blocked)

	tilemap.update_internals()


func can_place(
	origin: Vector2i,
	offsets: Array[Vector2i],
	bounds: Rect2i,
	blocked: Dictionary
) -> bool:
	for offset in offsets:
		var cell := origin + offset

		if not bounds.has_point(cell):
			return false

		if blocked.has(cell):
			return false

	return true


func mark_blocked(
	origin: Vector2i,
	offsets: Array[Vector2i],
	blocked: Dictionary
) -> void:
	for offset in offsets:
		blocked[origin + offset] = true


func get_1x1_offsets() -> Array[Vector2i]:
	return [
		Vector2i(0, 0)
	]


func get_1x2_offsets() -> Array[Vector2i]:
	return [
		Vector2i(0, 0),
		Vector2i(0, -1)
	]


func get_2x1_offsets() -> Array[Vector2i]:
	return [
		Vector2i(0, 0),
		Vector2i(1, 0)
	]


func get_2x2_offsets() -> Array[Vector2i]:
	return [
		Vector2i(0, 0),
		Vector2i(1, 0),
		Vector2i(0, -1),
		Vector2i(1, -1)
	]


func get_bounds_from_cells(cells: Array[Vector2i]) -> Rect2i:
	var min_x := cells[0].x
	var max_x := cells[0].x
	var min_y := cells[0].y
	var max_y := cells[0].y

	for cell in cells:
		min_x = min(min_x, cell.x)
		max_x = max(max_x, cell.x)
		min_y = min(min_y, cell.y)
		max_y = max(max_y, cell.y)

	return Rect2i(
		Vector2i(min_x, min_y),
		Vector2i(max_x - min_x + 1, max_y - min_y + 1)
	)
