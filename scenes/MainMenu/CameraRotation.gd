extends Camera3D

@export_category("Orbit Settings")
## The Node3D (e.g., MeshInstance3D) the camera will orbit around.
@export var target: Node3D 

## The speed of the rotation in radians per second.
@export var rotation_speed: float = 1.0 

## How far the camera should be from the target.
@export var distance: float = 5.0 

## The height offset of the camera relative to the target's center.
@export var elevation: float = 2.0 

# Keeps track of the current orbital angle
var _current_angle: float = 0.0

func _process(delta: float) -> void:
	# Ensure we have a valid target assigned in the inspector before doing math
	if not is_instance_valid(target):
		return

	# Increment the angle over time based on our speed
	_current_angle += rotation_speed * delta
	
	# Keep the angle within 0 to 2*PI (TAU) to prevent the float from growing infinitely
	_current_angle = wrapf(_current_angle, 0.0, TAU)

	# Calculate the new orbital position using sine and cosine
	var offset := Vector3(
		cos(_current_angle) * distance,
		elevation,
		sin(_current_angle) * distance
	)

	# Apply the position relative to the target's world position
	global_position = target.global_position + offset
	
	# Lock the camera's rotation to always look exactly at the target
	look_at(target.global_position, Vector3.UP)
