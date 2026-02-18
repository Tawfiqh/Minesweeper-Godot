### Game model: state, grid, and minesweeper logic (no UI)
class_name GameModel
extends RefCounted

# Tile states (shared with Tile and controller)
enum States {SAFE, CAUTION, MINE}

# Grid and dimensions
var grid: Array[Tile] = []
var total_rows: int = 12
var total_columns: int = 8
var total_mines: int = 20

# Game state
var is_first_click: bool = true
var can_click: bool = true
var minutes: int = 0
var seconds: int = 0
var mine_guesses: int = 0


func configure(rows: int, columns: int, mines: int) -> void:
	total_rows = rows
	total_columns = columns
	total_mines = mines


func prepare_new_game() -> void:
	is_first_click = true
	can_click = true
	minutes = 0
	seconds = 0
	mine_guesses = 0


func set_grid(new_grid: Array[Tile]) -> void:
	grid = new_grid


func assign_tiles(first_tile: Tile) -> void:
	var rows := total_rows
	var columns := total_columns
	var mines := total_mines

	var grid_copy = grid.duplicate(true)
	grid_copy.shuffle()

	first_tile.state = States.SAFE
	grid_copy.erase(first_tile)

	var nearby_before: Array[Tile] = get_nearby_tiles(first_tile)
	for t in nearby_before:
		grid_copy.erase(t)

	var mine_count: int = clamp(mines, 0, (rows * columns) - 9)
	mine_guesses += mine_count
	total_mines = mine_count

	for i in range(mine_count):
		var tile: Tile = grid_copy.pop_back()
		tile.state = States.MINE

	for y in range(rows):
		for x in range(columns):
			var tile: Tile = grid[x + (y * columns)]
			if tile.state == States.MINE:
				continue
			var nearby_after: Array[Tile] = get_nearby_tiles(tile)
			for nearby_tile in nearby_after:
				if nearby_tile.state == States.MINE:
					tile.state = States.CAUTION
					tile.mines_nearby += 1


func get_nearby_tiles(tile: Tile) -> Array[Tile]:
	var row: int = tile.row
	var column: int = tile.column
	var nearby_tiles: Array[Tile] = []

	var top_left: int = (column - 1) + ((row - 1) * total_columns)
	var top: int = column + ((row - 1) * total_columns)
	var top_right: int = (column + 1) + ((row - 1) * total_columns)
	var left: int = (column - 1) + (row * total_columns)
	var right: int = (column + 1) + (row * total_columns)
	var bottom_left: int = (column - 1) + ((row + 1) * total_columns)
	var bottom: int = column + ((row + 1) * total_columns)
	var bottom_right: int = (column + 1) + ((row + 1) * total_columns)

	var left_bound: int = row * total_columns
	var right_bound: int = (row * total_columns) + total_columns - 1
	var top_left_bound: int = (row - 1) * total_columns
	var top_right_bound: int = ((row - 1) * total_columns) + total_columns - 1
	var bottom_left_bound: int = (row + 1) * total_columns
	var bottom_right_bound: int = ((row + 1) * total_columns) + total_columns - 1

	if top_left >= 0 and top_left >= top_left_bound:
		nearby_tiles.append(grid[top_left])
	if top >= 0:
		nearby_tiles.append(grid[top])
	if top_right >= 0 and top_right <= top_right_bound:
		nearby_tiles.append(grid[top_right])
	if left >= 0 and left >= left_bound:
		nearby_tiles.append(grid[left])
	if right < (total_rows * total_columns) and right <= right_bound:
		nearby_tiles.append(grid[right])
	if bottom_left < (total_rows * total_columns) and bottom_left >= bottom_left_bound:
		nearby_tiles.append(grid[bottom_left])
	if bottom < (total_rows * total_columns):
		nearby_tiles.append(grid[bottom])
	if bottom_right < (total_rows * total_columns) and bottom_right <= bottom_right_bound:
		nearby_tiles.append(grid[bottom_right])

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
