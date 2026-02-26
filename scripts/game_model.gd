### Game model: state, grid, and minesweeper logic (no UI)
class_name GameModel
extends RefCounted

# Tile states (shared with Tile and controller)
enum States {SAFE, CAUTION, MINE}

# Grid and dimensions
var grid: Array[Tile] = []
var grid_dimensions: int = 8
var total_mines: int = 20
var zdepth: int = 1

# Game state
var is_first_click: bool = true
var can_click: bool = true
var minutes: int = 0
var seconds: int = 0
var mine_guesses: int = 0


func configure(row_size: int, mines: int, three_d_enabled: bool) -> void:
	grid_dimensions = row_size
	total_mines = mines
	zdepth = grid_dimensions if three_d_enabled else 1


func prepare_new_game() -> void:
	is_first_click = true
	can_click = true
	minutes = 0
	seconds = 0
	mine_guesses = 0


func set_grid(new_grid: Array[Tile]) -> void:
	grid = new_grid

func index_of_position(x: int, y: int, z: int) -> int:
	return x + (y * grid_dimensions) + (z * grid_dimensions * grid_dimensions) # TBC if this works

func tile_at_position(x: int, y: int, z: int) -> Tile:
	var newIndex: int = index_of_position(x, y, z)
	if newIndex < 0 or newIndex >= grid.size():
		return null
	return grid[newIndex]

func assign_tiles(first_tile: Tile) -> void:
	var mines := total_mines

	var grid_copy = grid.duplicate(true)
	grid_copy.shuffle()

	first_tile.state = States.SAFE
	grid_copy.erase(first_tile)

	var nearby_before: Array[Tile] = get_nearby_tiles(first_tile)
	for t in nearby_before:
		grid_copy.erase(t)

	var mine_count: int = clamp(mines, 0, (grid_dimensions * grid_dimensions) - 9)
	mine_guesses += mine_count
	total_mines = mine_count

	for i in range(mine_count):
		var tile: Tile = grid_copy.pop_back()
		tile.state = States.MINE

	for z in range(zdepth):
		for y in range(grid_dimensions):
			for x in range(grid_dimensions):
				var tile: Tile = tile_at_position(x, y, z)
				if tile.state == States.MINE:
					continue
				var nearby_after: Array[Tile] = get_nearby_tiles(tile)
				for nearby_tile in nearby_after:
					if nearby_tile.state == States.MINE:
						tile.state = States.CAUTION
						tile.mines_nearby += 1


func get_nearby_tiles(tile: Tile) -> Array[Tile]:
	var tileX: int = tile.x
	var tileY: int = tile.y
	var tileZ: int = tile.z
	var nearby_tiles: Array[Tile] = []


	for z in range(-1, 2):
		if zdepth == 1 && z != 0: # if it's 2d then skip z apart from when 0
			continue
		for y in range(-1, 2): # -1 => 0 => 1
			for x in range(-1, 2): # -1 => 0 => 1
				print(">>> OFFSETS x:%s, y:%s, z:%s" % [x, y, z])
				if x == 0 && y == 0: # don't count self as neighbour!
					continue
				var neighbourX: int = tileX + x
				var neighbourY: int = tileY + y
				var neighbourZ: int = tileZ + z
				if neighbourX < 0 or neighbourX >= grid_dimensions or neighbourY < 0 or neighbourY >= grid_dimensions or neighbourZ < 0 or neighbourZ >= zdepth:
					continue
				nearby_tiles.append(grid[neighbourX + neighbourY * grid_dimensions + neighbourZ * grid_dimensions * grid_dimensions])

	print("\n\n")


	return nearby_tiles


## Reveal this tile (updates tile state only; controller applies visuals).
## Returns true if the revealed tile was a mine (game over).
func reveal_tile(tile: Tile) -> bool:
	tile.is_hidden = false
	return tile.state == States.MINE


## Recursively reveal safe tiles; call after reveal_tile(tile). Returns count of revealed tiles that were flagged (for mine_guesses).
func reveal_nearby_tiles(tile: Tile) -> int:
	if tile.state == States.CAUTION or tile.state == States.MINE:
		return 0
	return _reveal_nearby_recursive(tile)
	

func _reveal_nearby_recursive(tile: Tile) -> int:
	var flagged_revealed: int = 0
	var nearby_tiles: Array[Tile] = get_nearby_tiles(tile)
	for nearby_tile in nearby_tiles:
		if nearby_tile.is_hidden:
			if nearby_tile.is_flagged:
				flagged_revealed += 1
			nearby_tile.is_hidden = false
			# Only recurse into SAFE tiles; stop at CAUTION (number) or MINE
			if nearby_tile.state == States.SAFE:
				flagged_revealed += _reveal_nearby_recursive(nearby_tile)
	return flagged_revealed


# func iterate_tiles(callback: Callable) -> void:
# 	for row in grid:
# 		for column in row:
# 			for shelf in column:
# 				for tile in shelf:
# 					callback.call(tile)

func reveal_mines() -> void:
	for tile in grid:
		if tile.state == States.MINE:
			tile.is_hidden = false


func check_win() -> bool:
	var remaining: int = 0
	for tile in grid:
		if tile.is_hidden:
			remaining += 1
	return remaining == total_mines


func free_tiles() -> void:
	for tile in grid:
		tile.queue_free()
	grid.clear()
