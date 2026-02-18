### Controller: UI, user input, and applying visuals from the game model
extends Node

# Texture resources
const CAUTION_1 = preload("res://sprites/1.png")
const CAUTION_2 = preload("res://sprites/2.png")
const CAUTION_3 = preload("res://sprites/3.png")
const CAUTION_4 = preload("res://sprites/4.png")
const CAUTION_5 = preload("res://sprites/5.png")
const CAUTION_6 = preload("res://sprites/6.png")
const CAUTION_7 = preload("res://sprites/7.png")
const CAUTION_8 = preload("res://sprites/8.png")
const MINE = preload("res://sprites/mine.png")
const MINE_SELECTED = preload("res://sprites/mine_selected.png")
const FLAG = preload("res://sprites/flag.png")
const HIDDEN = preload("res://sprites/hidden.png")
const SAFE = preload("res://sprites/safe.png")

# Node references
@onready var mine_counter: Label = $Control/MineCounter
@onready var time_elapsed: Label = $Control/TimeElapsed
@onready var message: Label = $Control/Message
@onready var timer: Timer = $Timer
@onready var row_counter: Label = $Control/RowCounter
@onready var column_counter: Label = $Control/ColumnCounter
@onready var mine_counter_2: Label = $Control/MineCounter2
@onready var row_slider: HSlider = $Control/RowSlider
@onready var column_slider: HSlider = $Control/ColumnSlider
@onready var mine_slider: HSlider = $Control/MineSlider

const TILE = preload("res://scenes/tile.tscn")
const GRID_SIZE: int = 32

var model: GameModel


func _ready() -> void:
	model = GameModel.new()
	SignalBus.tile_pressed.connect(_on_tile_pressed)

	row_slider.value = 11
	column_slider.value = 12
	mine_slider.value = 20
	_update_row_custom_counter(row_slider.value)
	_update_column_custom_counter(column_slider.value)
	_update_mine_custom_counter(mine_slider.value)

	_on_easy_pressed()


func get_viewport_size() -> Vector2:
	return get_viewport().get_visible_rect().size


func add_tile(pos: Vector2, virtual_pos: int, row: int, column: int) -> Tile:
	var tile_instance: Tile = TILE.instantiate()
	add_child(tile_instance)
	tile_instance.position = pos
	tile_instance.virtual_pos = virtual_pos
	tile_instance.row = row
	tile_instance.column = column
	tile_instance.state = GameModel.States.SAFE
	tile_instance.texture_normal = HIDDEN
	return tile_instance


func generate_tiles(rows: int, columns: int, mines: int) -> void:
	_reset_game()

	model.configure(rows, columns, mines)
	var grid_width: int = GRID_SIZE * columns
	var grid_height: int = GRID_SIZE * rows
	var screen_width: int = int(get_viewport_size().x)
	var screen_height: int = int(get_viewport_size().y)
	var hor_offset: int = (screen_width - grid_width) / 2
	var ver_offset: int = (screen_height - grid_height) / 2

	var new_grid: Array[Tile] = []
	for y in range(rows):
		for x in range(columns):
			var tile_pos: Vector2 = Vector2((GRID_SIZE * x) + hor_offset, (GRID_SIZE * y) + ver_offset)
			var virtual_pos: int = x + (y * columns)
			var tile: Tile = add_tile(tile_pos, virtual_pos, y, x)
			new_grid.append(tile)

	model.set_grid(new_grid)
	model.prepare_new_game()
	_update_mine_guess_counter()
	_update_time()
	timer.start()


func _reset_game() -> void:
	model.prepare_new_game()
	_update_mine_guess_counter()
	message.hide()
	_update_time()
	timer.start()

	if model.grid.size() > 0:
		for tile in model.grid:
			tile.queue_free()
		model.grid.clear()


func _update_time() -> void:
	time_elapsed.text = "Time: %02d:%02d" % [model.minutes, model.seconds]


func _update_mine_guess_counter() -> void:
	if model.is_first_click:
		mine_counter.text = "Mines: ???"
	else:
		mine_counter.text = "Mines: %s" % model.mine_guesses


func _update_row_custom_counter(value: float) -> void:
	row_counter.text = "Rows: %s" % int(value)


func _update_column_custom_counter(value: float) -> void:
	column_counter.text = "Columns: %s" % int(value)


func _update_mine_custom_counter(value: float) -> void:
	mine_counter_2.text = "Mines: %s" % int(value)


func apply_tile_visual(tile: Tile) -> void:
	if tile.is_hidden:
		tile.texture_normal = FLAG if tile.is_flagged else HIDDEN
		return
	# Revealed
	match tile.state:
		GameModel.States.SAFE:
			tile.texture_normal = SAFE
		GameModel.States.MINE:
			tile.texture_normal = MINE
		GameModel.States.CAUTION:
			match tile.mines_nearby:
				1: tile.texture_normal = CAUTION_1
				2: tile.texture_normal = CAUTION_2
				3: tile.texture_normal = CAUTION_3
				4: tile.texture_normal = CAUTION_4
				5: tile.texture_normal = CAUTION_5
				6: tile.texture_normal = CAUTION_6
				7: tile.texture_normal = CAUTION_7
				8: tile.texture_normal = CAUTION_8
				_: tile.texture_normal = SAFE


func _on_tile_pressed(virtual_pos: int, mouse_button: int) -> void:
	var tile: Tile = model.grid[virtual_pos]

	if not model.can_click:
		return

	if mouse_button == MOUSE_BUTTON_RIGHT:
		if tile.texture_normal == HIDDEN:
			tile.texture_normal = FLAG
			tile.is_flagged = true
			model.mine_guesses -= 1
		else:
			tile.texture_normal = HIDDEN
			tile.is_flagged = false
			model.mine_guesses += 1
		_update_mine_guess_counter()
		return

	if mouse_button != MOUSE_BUTTON_LEFT or tile.is_flagged:
		return

	if model.is_first_click:
		model.assign_tiles(tile)
		model.is_first_click = false

	var was_mine: bool = model.reveal_tile(tile)
	apply_tile_visual(tile)

	if was_mine:
		model.reveal_mines()
		tile.texture_normal = MINE_SELECTED
		for t in model.grid:
			apply_tile_visual(t)
		timer.stop()
		message.text = "You Lost!"
		message.show()
		model.can_click = false
		return

	var flagged_revealed: int = model.reveal_nearby_tiles(tile)
	model.mine_guesses += flagged_revealed
	for t in model.grid:
		apply_tile_visual(t)
	_update_mine_guess_counter()

	if model.check_win():
		for t in model.grid:
			if t.is_hidden:
				t.texture_normal = FLAG
				t.is_flagged = true
		model.mine_guesses = 0
		message.text = "You Won!"
		message.show()
		timer.stop()
		model.can_click = false


func _on_timer_timeout() -> void:
	model.seconds += 1
	if model.seconds >= 60:
		model.minutes += 1
		model.seconds = 0
	_update_time()


func _on_easy_pressed() -> void:
	generate_tiles(10, 10, 12)


func _on_normal_pressed() -> void:
	generate_tiles(16, 12, 25)


func _on_hard_pressed() -> void:
	generate_tiles(18, 16, 40)


func _on_custom_game_pressed() -> void:
	generate_tiles(int(row_slider.value), int(column_slider.value), int(mine_slider.value))


func _on_row_slider_value_changed(value: float) -> void:
	_update_row_custom_counter(value * 3)


func _on_column_slider_value_changed(value: float) -> void:
	_update_column_custom_counter(value)


func _on_mine_slider_value_changed(value: float) -> void:
	_update_mine_custom_counter(value)
