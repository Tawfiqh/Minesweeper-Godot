extends Area3D
class_name Tile

# index of the object in the grid array
var virtual_pos: int = 0

# row and oclumn of this tile on the grid
var row: int = 0
var column: int = 0

# state of the tile (GameModel.States)
var state: int = GameModel.States.SAFE

# number of mines near this tile
var mines_nearby: int = 0

# used for checking whether the tile is clickable
var is_hidden: bool = true

# used to check if the tile is flagged
var is_flagged: bool = false

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D


func _input_event(_camera: Node, event: InputEvent, _event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if not event is InputEventMouseButton:
		return
	var mb: InputEventMouseButton = event
	if not mb.pressed or not is_hidden:
		return
	print("[Tile] input_event virtual_pos=%s button_index=%s" % [virtual_pos, mb.button_index])
	match mb.button_index:
		MOUSE_BUTTON_LEFT:
			SignalBus.tile_pressed.emit(virtual_pos, MOUSE_BUTTON_LEFT)
		MOUSE_BUTTON_RIGHT:
			SignalBus.tile_pressed.emit(virtual_pos, MOUSE_BUTTON_RIGHT)
