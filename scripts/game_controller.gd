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
const SAFE = Color(0.65, 0.65, 0.65, 0.005) # Grey and transparent


@onready var mine_counter: Label = $CanvasLayer/Control/MineCounter
@onready var time_elapsed: Label = $CanvasLayer/Control/TimeElapsed
@onready var message: Label = $CanvasLayer/Control/Message
@onready var timer: Timer = $Timer
@onready var row_counter: Label = $CanvasLayer/Control/RowCounter
@onready var mine_counter_2: Label = $CanvasLayer/Control/MineCounter2
@onready var row_slider: HSlider = $CanvasLayer/Control/RowSlider
@onready var mine_slider: HSlider = $CanvasLayer/Control/MineSlider
@onready var camera: Camera3D = $cameraTwistPivot/cameraPitchPivot/Camera3D
@onready var grid_spacing_slider: HSlider = $CanvasLayer/Control/GridSpacingSlider


@export var GRID_SPACING: float:
	get:
		return grid_spacing_slider.value
	set(value):
		grid_spacing_slider.value = value


const TILE = preload("res://scenes/tile.tscn")
@onready var THREE_D_ENABLED: CheckButton = $"CanvasLayer/Control/3dToggle"


var model: GameModel
var camera_controller


func _ready() -> void:
	model = GameModel.new()
	SignalBus.tile_pressed.connect(_on_tile_pressed)

	camera_controller = load("res://scripts/camera_controller.gd").new()
	camera_controller.setup(
		$cameraTwistPivot,
		$cameraTwistPivot/cameraPitchPivot,
		camera,
		tile_container
	)

	row_slider.value = 11
	mine_slider.value = 20
	_update_row_custom_counter(row_slider.value)
	_update_mine_custom_counter(mine_slider.value)

	_on_easy_pressed()


func add_tile(pos: Vector3, grid_index: int, z: int, y: int, x: int):
	var tile_instance: Tile = TILE.instantiate()
	tile_container.add_child(tile_instance)
	tile_instance.position = pos
	
	tile_instance.grid_index = grid_index
	tile_instance.z = z
	tile_instance.y = y
	tile_instance.x = x

	tile_instance.state = GameModel.States.SAFE
	tile_instance.is_hidden = true # TBC - this seems weird -
	return tile_instance


func iterate_tiles_and_update_positions(gridDimensions: int, zDepth: int, generateNewGrid: bool = false) -> Array[Tile]:
	var new_grid: Array[Tile] = []
	
	var x_offset: float = (gridDimensions - 1) * GRID_SPACING / 2.0 # offset half-width from the center of the grid
	var y_offset: float = (gridDimensions - 1) * GRID_SPACING / 2.0 # offset half-height from the center of the grid
	
	var z_offset: float = 0
	if zDepth > 1:
		z_offset = (zDepth - 1) * GRID_SPACING / 2.0 # offset half-height from the center of the grid

	# print("🔪🔪[GameController] z_offset=%s" % z_offset)
	
	for z in range(zDepth): # columns
		for y in range(gridDimensions): # rows
			for x in range(gridDimensions): # columns
				# print("🔪🔪[GameController] x=%s y=%s z=%s z_offset=%s" % [x, y, z, z_offset])
				var tile_pos: Vector3 = Vector3(
					x * GRID_SPACING - x_offset,
					 z * GRID_SPACING - z_offset,
					 y * GRID_SPACING - y_offset
					  ) # position of the tile
				var grid_index: int = model.index_of_position(x, y, z)
				if generateNewGrid:
					var tile: Tile = add_tile(tile_pos, grid_index, z, y, x)
					new_grid.append(tile)
				else:
					var existing_tile: Tile = model.tile_at_position(x, y, z)
					if existing_tile:
						existing_tile.position = tile_pos
						new_grid.append(existing_tile)
	return new_grid


func generate_tiles(gridDimensions: int, mines: int) -> void:
	_reset_game()

	model.configure(gridDimensions, mines, THREE_D_ENABLED.button_pressed)
	

	# XXY - This touches the grid directly, we need to refactor this to use the grid array
	var new_grid: Array[Tile] = iterate_tiles_and_update_positions(gridDimensions, model.zdepth, true)


	model.set_grid(new_grid)
	model.prepare_new_game()
	for t: Tile in new_grid:
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

	model.free_tiles()


func _update_time() -> void:
	time_elapsed.text = "Time: %02d:%02d" % [model.minutes, model.seconds]


func _update_mine_guess_counter() -> void:
	if model.is_first_click:
		mine_counter.text = "Mines: ???"
	else:
		mine_counter.text = "Mines: %s" % model.mine_guesses


func _update_row_custom_counter(value: float) -> void:
	row_counter.text = "Rows: %s" % int(value)


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


func apply_tile_visual(tile: Tile) -> void:
	if tile.mesh_instance:
		tile.mesh_instance.material_override = _material_for_tile(tile)
	if tile.number_label:
		if tile.state == GameModel.States.CAUTION and not tile.is_hidden:
			tile.number_label.text = str(tile.mines_nearby)
			tile.number_label.visible = true
		else:
			tile.number_label.visible = false

	# For revealed SAFE tiles, make them non-interactive so they don't receive mouse input.
	if tile.state == GameModel.States.SAFE and not tile.is_hidden and tile.collision_shape:
		tile.collision_shape.disabled = true
		tile.input_ray_pickable = false

	elif tile.collision_shape:
		tile.collision_shape.disabled = false


func _on_tile_pressed(grid_index: int, mouse_button: int) -> void:
	print("[GameController] tile_pressed grid_index=%s mouse_button=%s" % [grid_index, mouse_button])
	var tile = model.grid[grid_index]

	if not model.can_click:
		return

	# Right mouse button toggles the flag on the tile (i.e the player thinks this is a mine)
	if mouse_button == MOUSE_BUTTON_RIGHT:
		# print("\n [GameController] tile_pressed right grid_index=%s" % grid_index)
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

	# If not a mouse button - ignore about it
	if mouse_button != MOUSE_BUTTON_LEFT or tile.is_flagged:
		return

	# If it's the first click, assign the tiles to the grid
	# they're all blank tiles before the first click 
	# to prevent the user from clicking a mine on the first click
	if model.is_first_click:
		model.assign_tiles(tile)
		model.is_first_click = false

	# Reveal the tile (i.e the player digs the tile)
	var was_mine: bool = model.reveal_tile(tile)
	apply_tile_visual(tile)

	# If the tile is a mine, reveal all the mines = Game Over
	if was_mine:
		model.reveal_mines()
		for t in model.grid:
			apply_tile_visual(t)
		timer.stop()
		message.text = "You Lost!"
		message.show()
		model.can_click = false
		return

	# If it was not a mine - reveal how many mines are nearby
	var flagged_revealed: int = model.reveal_nearby_tiles(tile)
	model.mine_guesses += flagged_revealed
	for t in model.grid:
		apply_tile_visual(t)
	_update_mine_guess_counter()


	# If the player has won, reveal all the tiles and set the message to "You Won!"
	if model.check_win():
		for t in model.grid:
			if t.is_hidden:
				t.is_flagged = true
		model.mine_guesses = 0
		message.text = "You Won!"
		message.show()
		timer.stop()
		model.can_click = false


func _on_timer_timeout() -> void: # This is called every second
	model.seconds += 1
	if model.seconds >= 60:
		model.minutes += 1
		model.seconds = 0
	_update_time()


func _on_easy_pressed() -> void:
	generate_tiles(10, 12)


func _on_normal_pressed() -> void:
	generate_tiles(14, 25)


func _on_hard_pressed() -> void:
	generate_tiles(18, 40)


func _on_custom_game_pressed() -> void:
	generate_tiles(int(row_slider.value), int(mine_slider.value))


func _on_row_slider_value_changed(value: float) -> void:
	_update_row_custom_counter(value)


func _on_mine_slider_value_changed(value: float) -> void:
	_update_mine_custom_counter(value)


func _on_grid_spacing_slider_value_changed(_value: float) -> void:
	# Regenerate the current game with the same dimensions and mine count,
	# but using the new GRID_SPACING value from the slider.
	if model:
		generate_tiles(model.grid_dimensions, model.zdepth)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if (motion.button_mask & MOUSE_BUTTON_MASK_MIDDLE) != 0:
			camera_controller.rotate_with_mouse(motion.relative)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				camera_controller.zoom_in()
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				camera_controller.zoom_out()

func _update_camera_rotation(horizontal, vertical) -> void:
	camera_controller._update_camera_rotation(horizontal, vertical)

func rotate_camera_up() -> void:
	camera_controller.rotate_camera_up()

func rotate_camera_down() -> void:
	camera_controller.rotate_camera_down()

func rotate_camera_left() -> void:
	camera_controller.rotate_camera_left()

func rotate_camera_right() -> void:
	camera_controller.rotate_camera_right()


func zoom_in() -> void:
	camera_controller.zoom_in()


func zoom_out() -> void:
	camera_controller.zoom_out()
