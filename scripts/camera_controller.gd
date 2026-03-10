extends RefCounted

class_name CameraController


const ZOOM_STEP: float = 4.0
const MIN_ZOOM_DISTANCE: float = 6.0
const MAX_ZOOM_DISTANCE: float = 30.0
const ROTATION_STEP: float = deg_to_rad(30)


var twist_pivot: Node3D
var pitch_pivot: Node3D
var camera: Camera3D
var tile_container: Node3D


func setup(
	twist_pivot_node: Node3D,
	pitch_pivot_node: Node3D,
	camera_node: Camera3D,
	tile_container_node: Node3D
) -> void:
	twist_pivot = twist_pivot_node
	pitch_pivot = pitch_pivot_node
	camera = camera_node
	tile_container = tile_container_node


func _update_camera_rotation(horizontal: float, vertical: float) -> void:
	_update_twist_rotation(horizontal)
	_update_pitch_rotation(vertical)


# This is the horizontal rotation
func _update_twist_rotation(horizontalRotation: float) -> void:
	if twist_pivot:
		twist_pivot.rotate_y(horizontalRotation)


# This is the vertical rotation
func _update_pitch_rotation(verticalRotation: float) -> void:
	if pitch_pivot:
		pitch_pivot.rotate_x(verticalRotation) # Rotate about the X-axis
		print("🎥[CameraController] verticalRotation=%s" % rad_to_deg(pitch_pivot.rotation.x))
		pitch_pivot.rotation.x = clamp(
			pitch_pivot.rotation.x,
			deg_to_rad(-30),
			deg_to_rad(150)
		)


func rotate_camera_up() -> void:
	_update_camera_rotation(0.0, -ROTATION_STEP)


func rotate_camera_down() -> void:
	_update_camera_rotation(0.0, ROTATION_STEP)


func rotate_camera_left() -> void:
	_update_camera_rotation(-ROTATION_STEP, 0.0)


func rotate_camera_right() -> void:
	_update_camera_rotation(ROTATION_STEP, 0.0)


func zoom_in() -> void:
	if not camera or not tile_container:
		return
	var focus: Vector3 = tile_container.global_position
	var to_camera: Vector3 = camera.global_position - focus
	var distance: float = to_camera.length()
	if distance <= MIN_ZOOM_DISTANCE:
		return
	var new_distance: float = max(MIN_ZOOM_DISTANCE, distance - ZOOM_STEP)
	camera.global_position = focus + to_camera.normalized() * new_distance


func zoom_out() -> void:
	if not camera or not tile_container:
		return
	var focus: Vector3 = tile_container.global_position
	var to_camera: Vector3 = camera.global_position - focus
	var distance: float = to_camera.length()
	if distance >= MAX_ZOOM_DISTANCE:
		return
	var new_distance: float = min(MAX_ZOOM_DISTANCE, distance + ZOOM_STEP)
	camera.global_position = focus + to_camera.normalized() * new_distance
