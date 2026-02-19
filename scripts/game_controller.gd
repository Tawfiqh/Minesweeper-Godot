### Controller: UI, user input, and applying visuals from the game model (3D cubes)
extends Node3D

# Node references
@onready var tile_container: Node3D = $TileContainer

const baseColourSaturation: float = 0.4
const CAUTION_1 = Color(0, 0, baseColourSaturation)
const CAUTION_2 = Color(0, baseColourSaturation, 0)
const CAUTION_3 = Color(baseColourSaturation, 0, 0)
const CAUTION_4 = Color(baseColourSaturation, baseColourSaturation, 0)
const CAUTION_5 = Color(0, baseColourSaturation, baseColourSaturation)
const CAUTION_6 = Color(baseColourSaturation, 0, baseColourSaturation)
const CAUTION_7 = Color(baseColourSaturation, 0.1 * baseColourSaturation, baseColourSaturation)
const CAUTION_8 = Color(baseColourSaturation, 0.2 * baseColourSaturation, baseColourSaturation)
const SAFE = Color(0.65, 0.65, 0.65, 0.1) # Green and transparent


@onready var mine_counter: Label = $CanvasLayer/Control/MineCounter
@onready var time_elapsed: Label = $CanvasLayer/Control/TimeElapsed
@onready var message: Label = $CanvasLayer/Control/Message
@onready var timer: Timer = $Timer
@onready var row_counter: Label = $CanvasLayer/Control/RowCounter
@onready var column_counter: Label = $CanvasLayer/Control/ColumnCounter
@onready var mine_counter_2: Label = $CanvasLayer/Control/MineCounter2
@onready var row_slider: HSlider = $CanvasLayer/Control/RowSlider
@onready var column_slider: HSlider = $CanvasLayer/Control/ColumnSlider
@onready var mine_slider: HSlider = $CanvasLayer/Control/MineSlider

const TILE = preload("res://scenes/tile.tscn")
const GRID_SPACING: float = 1

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


func add_tile(pos: Vector3, virtual_pos: int, row: int, column: int):
	var tile_instance: Tile = TILE.instantiate()
	tile_container.add_child(tile_instance)
	tile_instance.position = pos
	tile_instance.virtual_pos = virtual_pos
	tile_instance.row = row
	tile_instance.column = column
	tile_instance.state = GameModel.States.SAFE
	tile_instance.is_hidden = true # TBC - this seems weird -
	return tile_instance


func generate_tiles(rows: int, columns: int, mines: int) -> void:
	_reset_game()

	model.configure(rows, columns, mines)
	var half_w: float = (columns - 1) * GRID_SPACING / 2.0
	var half_h: float = (rows - 1) * GRID_SPACING / 2.0

	var new_grid: Array[Tile] = []
	for y in range(rows):
		for x in range(columns):
			var tile_pos: Vector3 = Vector3(x * GRID_SPACING - half_w, 0.0, y * GRID_SPACING - half_h)
			var virtual_pos: int = x + (y * columns)
			var tile: Tile = add_tile(tile_pos, virtual_pos, y, x)
			new_grid.append(tile)

	model.set_grid(new_grid)
	model.prepare_new_game()
	for t in new_grid:
		apply_tile_visual(t)
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


func _material_for_tile(tile) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	if tile.is_hidden:
		mat.albedo_color = Color(0.5, 0.5, 0.55) if not tile.is_flagged else Color(0.85, 0.2, 0.2)
		return mat
	match tile.state:
		GameModel.States.SAFE:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color = SAFE
			
		GameModel.States.MINE:
			mat.albedo_color = Color(0.75, 0.15, 0.15) # RED
		GameModel.States.CAUTION:
			match tile.mines_nearby:
				1: mat.albedo_color = CAUTION_1
				2: mat.albedo_color = CAUTION_2
				3: mat.albedo_color = CAUTION_3
				4: mat.albedo_color = CAUTION_4
				5: mat.albedo_color = CAUTION_5
				6: mat.albedo_color = CAUTION_6
				7: mat.albedo_color = CAUTION_7
				8: mat.albedo_color = CAUTION_8
				_: mat.albedo_color = SAFE

			# var n: int = tile.mines_nearby
			# var t: float = (n - 1) / 7.0
			# mat.albedo_color = Color(1.0 - t * 0.5, 0.6 + t * 0.3, 0.2)
	return mat


func apply_tile_visual(tile) -> void:
	if tile.mesh_instance:
		tile.mesh_instance.material_override = _material_for_tile(tile)
	if tile.number_label:
		if tile.state == GameModel.States.CAUTION and not tile.is_hidden:
			tile.number_label.text = str(tile.mines_nearby)
			tile.number_label.visible = true
		else:
			tile.number_label.visible = false


func _on_tile_pressed(virtual_pos: int, mouse_button: int) -> void:
	print("[GameController] tile_pressed virtual_pos=%s mouse_button=%s" % [virtual_pos, mouse_button])
	var tile = model.grid[virtual_pos]

	if not model.can_click:
		return

	if mouse_button == MOUSE_BUTTON_RIGHT:
		# print("\n [GameController] tile_pressed right virtual_pos=%s" % virtual_pos)
		# print("tile.is_flagged=%s" % tile.is_flagged)
		if not tile.is_flagged:
			tile.is_flagged = true
			model.mine_guesses -= 1
		else:
			tile.is_flagged = false
			model.mine_guesses += 1
		apply_tile_visual(tile)
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
	_update_row_custom_counter(value)


func _on_column_slider_value_changed(value: float) -> void:
	_update_column_custom_counter(value)


func _on_mine_slider_value_changed(value: float) -> void:
	_update_mine_custom_counter(value)
