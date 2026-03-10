extends Area3D
class_name Tile

# index of the object in the grid array
var grid_index: int = 0

# row, column and shelf of this tile on the grid
var x: int = 0
var y: int = 0
var z: int = 0

# state of the tile (GameModel.States)
var state: int = GameModel.States.SAFE

# number of mines near this tile
var mines_nearby: int = 0

# used for checking whether the tile is clickable
var is_hidden: bool = true

# used to check if the tile is flagged
var is_flagged: bool = false

@onready var mesh_instance: CSGBox3D = $MainBox
@onready var number_label: Label3D = $NumberLabel
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

const DEBOUNCE_MS: int = 250
const LONG_PRESS_MS: int = 300
var _last_click_time: int = 0
var _is_pressing_left: bool = false
var _long_press_triggered: bool = false
var _long_press_timer: Timer


func _ready() -> void:
	_long_press_timer = Timer.new()
	_long_press_timer.one_shot = true
	add_child(_long_press_timer)
	_long_press_timer.timeout.connect(_on_long_press_timeout)


func _input_event(_camera: Node, event: InputEvent, _event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if not event is InputEventMouseButton or not is_hidden:
		return

	var mb: InputEventMouseButton = event
	var now: int = Time.get_ticks_msec()

	# Desktop right‑click still flags immediately.
	if mb.button_index == MOUSE_BUTTON_RIGHT:
		if not mb.pressed:
			return
		if now - _last_click_time < DEBOUNCE_MS: # Don't double trigger on click events
			return
		_last_click_time = now
		# print("🔪🔪[Tile] input_event grid_index=%s button_index=%s (right-click)" % [grid_index, mb.button_index])
		SignalBus.tile_pressed.emit(grid_index, MOUSE_BUTTON_RIGHT)
		return

	# Left button: short press = reveal, long-press = flag (mobile-friendly).
	if mb.button_index == MOUSE_BUTTON_LEFT:
		print("🔪🔪🔪🔪[Tile] input_event grid_index=%s button_index=%s (duration=%s ms)" % [grid_index, mb.button_index])
		if mb.pressed:
			_is_pressing_left = true
			_long_press_triggered = false
			_long_press_timer.start(float(LONG_PRESS_MS) / 1000.0)
			return

		# On release: stop tracking and either do nothing (if long‑press already fired)
		# or treat it as a normal left click (reveal).
		_is_pressing_left = false
		_long_press_timer.stop()

		if _long_press_triggered:
			return

		if now - _last_click_time < DEBOUNCE_MS:
			return
		_last_click_time = now
		SignalBus.tile_pressed.emit(grid_index, MOUSE_BUTTON_LEFT)


func _on_long_press_timeout() -> void:
	if not _is_pressing_left or not is_hidden:
		return

	var now: int = Time.get_ticks_msec()
	if now - _last_click_time < DEBOUNCE_MS:
		return

	_last_click_time = now
	_long_press_triggered = true
	SignalBus.tile_pressed.emit(grid_index, MOUSE_BUTTON_RIGHT)
