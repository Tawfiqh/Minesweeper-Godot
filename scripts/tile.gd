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
const LONG_PRESS_MS: int = 500
var _last_click_time: int = 0
var _press_start_time: int = 0


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
		print("🔪🔪🔪🔪[Tile] input_event grid_index=%s button_index=%s (duration=%s ms)" % [grid_index, mb.button_index, now - _press_start_time])
		if mb.pressed:
			_press_start_time = now
			return

		var duration: int = now - _press_start_time
		if now - _last_click_time < DEBOUNCE_MS:
			return
		_last_click_time = now

		var as_button: int = MOUSE_BUTTON_RIGHT if duration >= LONG_PRESS_MS else MOUSE_BUTTON_LEFT
		print("🔪🔪🔪🔪[Tile] input_event grid_index=%s button_index=%s (duration=%s ms -> %s)" % [grid_index, mb.button_index, duration, as_button])
		SignalBus.tile_pressed.emit(grid_index, as_button)
