extends Node3D
class_name CameraObject 

@onready var aim_raycast: RayCast3D = $Camera/RayCast3D

#camera variables
@export_group("Camera variables")
@export_range(0.0, 0.5, 0.001) var x_axis_sensibility : float = 0.05
@export_range(0.0, 0.5, 0.001) var y_axis_sensibility : float = 0.05
@export_range(-360.0, 0.0, 0.01) var max_up_angle_view : float = -90.0 #in degrees
@export_range(0.0, 360.0, 0.01) var max_down_angle_view : float = 90.0 #in degrees
@export_range(5.0, 175.0, 0.01) var fov : float = 90.0

@export_group("fov variables")
@export_range(0.0, 180.0, 0.01) var min_fov_val : float = 10.0
@export_range(0.0, 180.0, 0.01) var max_fov_val : float = 170.0
@export var cam_fov_per_state : Dictionary[String, Vector2] = {
	"Default" : Vector2(90.0, 0.2),
	"Idle" : Vector2(90.0, 0.2),
	"Crouch" : Vector2(90.0, 0.2),
	"Walk" : Vector2(90.0, 0.2),
	"Run" : Vector2(100.0, 0.2),
	"Slide" : Vector2(100.0, 0.2),
	"Dash" : Vector2(110.0, 0.05),
	"Fly" : Vector2(100.0, 0.2)
}

@export_group("Zoom variables")
var zoom_on : bool = false
var zoom_has_occured : bool = false
@export_range(-180.0, 180.0, 1.0) var zoom_val : float = 40.0
@export_range(0.0, 3.0, 0.01) var zoom_duration : float = 0.2

@export_group("Tilt variables")
@export var enable_forward_tilt : bool = true
@export var enable_side_tilt : bool = true
@export_range(0.0, 400.0, 0.1) var forward_move_tilt_divider : float = 260.0 
@export_range(0.0, 7.0, 0.01) var forward_move_tilt_duration : float = 0.19
@export_range(0.0, 2.0, 0.001) var forward_move_max_tilt_val : float = 2.0
@export_range(0.0, 6.0, 0.1) var side_move_tilt_divider : float = 2.8
@export_range(0.0, 24.0, 0.01) var side_move_tilt_speed : float = 10.0
@export_range(0.0, 12.0, 0.001) var side_move_max_tilt_val : float = 7.0
var tilt_tween : Tween
var last_input_y : float
@export var tilt_props_per_state : Dictionary[String, Vector2] = {
	"Default" : Vector2(0.0, 7.5),
	"Slide" : Vector2(10.0, 7.5),
	"Wallrun" : Vector2(16.0, 4.0)
}

# Added to track base tilts independently to avoid destructive accumulation
var tilt_x : float = 0.0 
var tilt_z : float = 0.0 

@export_group("Bob variables")
@export var enable_headbob : bool = true
@export_range(0.0, 0.15, 0.001) var bob_pitch : float = 0.05 #in degrees
@export_range(0.0, 0.15, 0.001) var bob_roll : float = 0.025 #in degrees
@export_range(0.0, 1000.0, 1.0) var bob_height_divider : float = 550.0
@export_range(2.0, 10.0, 0.1) var bob_frequency : float = 7.0
@export_range(0.0, 1.0, 0.001) var cam_max_v_offset : float = 0.3
@export_range(0.0, 15.0, 0.1) var cam_v_offset_to_0_speed : float = 1.0
var step_timer : float = 0.0

@export_group("Mouse variables")
var mouse_free : bool = false

@export_group("Shooting & Aiming")
@export var recoil_recovery_speed : float = 10.0
var current_recoil : Vector2 = Vector2.ZERO
var target_recoil : Vector2 = Vector2.ZERO

@export_group("Keybind variables")
@export var zoom_action : StringName = "play_char_zoom_action"
@export var mouse_mode_action : StringName = "play_char_mouse_mode_action"
@onready var input_actions_list : Array[StringName] = [zoom_action, mouse_mode_action]
@export var check_on_ready_if_inputs_registered : bool = true
var default_input_actions : Dictionary

var state : String

#references variables
@onready var camera : Camera3D = $Camera
@onready var play_char : PlayerCharacter = $".."
@onready var hud : CanvasLayer = $"../HUD"

func _ready() -> void:
	if multiplayer.has_multiplayer_peer() and not play_char.is_multiplayer_authority():
		set_process(false)
		set_process_unhandled_input(false)
		return
		
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED) 
	
	camera.fov = fov
	
	build_default_keybinding()
	input_actions_check()

func build_default_keybinding() -> void:
	default_input_actions = {
		zoom_action : [Key.KEY_Z],
		mouse_mode_action : [Key.KEY_ESCAPE]
	}

func input_actions_check() -> void:
	if check_on_ready_if_inputs_registered:
		var registered_input_actions: Array[StringName] = []
		for input_action in InputMap.get_actions():
			if input_action.begins_with(&"play_char_"):
				registered_input_actions.append(input_action)
				
		for input_action in input_actions_list:
			if input_action == &"":
				assert(false, "There's an undefined input action")
				
			if not registered_input_actions.has(input_action):
				var key_names = default_input_actions[input_action].map(func(key):
					return OS.get_keycode_string(key)
				)
				
				push_warning("'{input}' missing in InputMap, or input action wrongly named in the editor.\nAdding the '{input}' to runtime InputMap temporarily with the key/s: {keys}".format({"input": input_action, "keys": String(", ").join(key_names)}))
				
				InputMap.add_action(input_action)
				for keycode in default_input_actions[input_action]:
					var input_event_key = InputEventKey.new()
					input_event_key.physical_keycode = keycode
					InputMap.action_add_event(input_action, input_event_key)
				
func _process(delta : float) -> void:
	if not play_char.is_multiplayer_authority(): return
	
	state = play_char.state_machine.curr_state_name
	tilt(delta)
	bob(delta)
	zoom()
	mouse_mode()
	
	handle_recoil(delta)
	
func tilt(delta : float) -> void:
	# --- Forward/Backward Tilt (Tweened) ---
	if state != "Fly" and state != "Slide" and state != "Wallrun":
		if enable_forward_tilt:
			var has_started_moving_forward = sign(play_char.input_direction.y) == 1 and sign(last_input_y) != 1
			var has_started_moving_backward = sign(play_char.input_direction.y) == -1 and sign(last_input_y) != -1
			
			if has_started_moving_forward or has_started_moving_backward:
				reset_tween()
				var tilt_offset : float = clamp((-play_char.input_direction.y * play_char.move_speed) / forward_move_tilt_divider, -forward_move_max_tilt_val, forward_move_max_tilt_val)
				var tilt_target : float = clamp(tilt_x - tilt_offset, max_up_angle_view, max_down_angle_view)
				
				# Animate our logical tracking property, NOT the actual raw node rotation yet
				tilt_tween.tween_property(self, "tilt_x", tilt_target, forward_move_tilt_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				tilt_tween.tween_property(self, "tilt_x", 0.0, forward_move_tilt_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
				
				tilt_tween.finished.connect(Callable(tilt_tween, "kill"))
		
			last_input_y = play_char.input_direction.y

	# --- Side Tilt (Lerped) ---
	var target_tilt_z : float = 0.0
	var lerp_speed : float = tilt_props_per_state["Default"][1]

	# Structure reorganized to prevent A/D lean and state lean fighting each other
	if state in tilt_props_per_state.keys():
		if state == "Wallrun" and play_char.side_check_raycast_collided != 0: 
			target_tilt_z = tilt_props_per_state[state][0] * -play_char.side_check_raycast_collided
		else:
			target_tilt_z = tilt_props_per_state[state][0]
		lerp_speed = tilt_props_per_state[state][1]
	else:
		if enable_side_tilt and state != "Fly" and state != "Slide" and state != "Wallrun":
			target_tilt_z = clamp((-play_char.input_direction.x * play_char.move_speed) / side_move_tilt_divider, -side_move_max_tilt_val, side_move_max_tilt_val)
			lerp_speed = side_move_tilt_speed
		else:
			target_tilt_z = tilt_props_per_state["Default"][0]

	tilt_z = lerp(tilt_z, target_tilt_z, lerp_speed * delta)
			
func reset_tween():
	if tilt_tween and tilt_tween.is_running():
		tilt_tween.kill()
	tilt_tween = create_tween()
	
func bob(delta : float) -> void:
	var bob_speed : float = Vector2(play_char.velocity.x, play_char.velocity.z).length()
	if bob_speed > 0.1:
		step_timer += delta * (bob_speed / bob_frequency)
		step_timer = fmod(step_timer, 1.0)
	else:
		step_timer = 0.0
	
	var bob_sinus : float = sin(step_timer * 2.0 * PI) * 0.5
	
	# Fix: Read the player's true mouse pitch so we don't overwrite mouse movements looking up/down
	var base_pitch_deg : float = rad_to_deg(play_char.pitch)
	
	# Base rotations from tilt AND player pitch
	var final_rot_x : float = base_pitch_deg + tilt_x
	var final_rot_z : float = tilt_z
	var final_v_offset : float = 0.0
	
	if enable_headbob and state != "Idle" and state != "Jump" and state != "Slide" and state != "Dash" and state != "Fly" and state != "Wallrun" and !play_char.ceiling_check.is_colliding():
		
		var pitch_delta : float = bob_sinus * deg_to_rad(bob_pitch) * bob_speed
		final_rot_x = clamp(base_pitch_deg + tilt_x - pitch_delta, max_up_angle_view, max_down_angle_view)
		
		var roll_delta : float = bob_sinus * deg_to_rad(bob_roll) * bob_speed
		final_rot_z = clamp(tilt_z - roll_delta, max_up_angle_view, max_down_angle_view)
		
		# Assign exact absolute height
		var bob_height : float = (bob_sinus * bob_speed) / bob_height_divider
		final_v_offset = clamp(abs(bob_height), 0.0, cam_max_v_offset)
		
	# Apply final offset (smooth return to 0 if stopped)
	if final_v_offset == 0.0 and camera.v_offset != 0.0:
		camera.v_offset = move_toward(camera.v_offset, 0.0, cam_v_offset_to_0_speed * delta)
	elif final_v_offset != 0.0:
		camera.v_offset = final_v_offset

	# Safely apply final compiled rotations
	rotation_degrees.x = final_rot_x
	rotation_degrees.z = final_rot_z
		
func zoom() -> void:
	if Input.is_action_just_pressed(zoom_action):
		zoom_on = !zoom_on
		if !zoom_on: zoom_has_occured = false
		
		change_fov()
		
func change_fov() -> void:
	if zoom_has_occured:
		return
	
	state = play_char.state_machine.curr_state_name
	camera.fov = clamp(camera.fov, min_fov_val, max_fov_val)
	
	var fov_change_tween : Tween = get_tree().create_tween()
	
	if !zoom_on and !zoom_has_occured:
		if state != null and state != "Jump" and state != "Inair" and state != "Wallrun":
			fov_change_tween.tween_property(camera, "fov", cam_fov_per_state[state][0], cam_fov_per_state[state][1])
			fov_change_tween.finished.connect(Callable(fov_change_tween, "kill"))
		else:
			if state != "Jump" and state != "Inair" and state != "Wallrun":
				fov_change_tween.tween_property(camera, "fov", cam_fov_per_state["Default"][0], cam_fov_per_state["Default"][1])
				fov_change_tween.finished.connect(Callable(fov_change_tween, "kill"))
			else:
				var walk_or_run_state : String
				if play_char.walk_or_run == "WalkState":
					walk_or_run_state = "Walk"
				if play_char.walk_or_run == "RunState":
					if (play_char.velocity.x < 1.0 and play_char.velocity.x > -1.0 and play_char.velocity.z < 1.0 and play_char.velocity.z > -1.0):
						walk_or_run_state = "Walk"
					else:
						walk_or_run_state = "Run"
						
				fov_change_tween.tween_property(camera, "fov", cam_fov_per_state[walk_or_run_state][0], cam_fov_per_state[walk_or_run_state][1])
				fov_change_tween.finished.connect(Callable(fov_change_tween, "kill"))
				
	if zoom_on and !zoom_has_occured:
		zoom_has_occured = true
		fov_change_tween.tween_property(camera, "fov", camera.fov - zoom_val, zoom_duration)
		fov_change_tween.finished.connect(Callable(fov_change_tween, "kill"))
		
func mouse_mode() -> void:
	if Input.is_action_just_pressed(mouse_mode_action): mouse_free = !mouse_free
	if !mouse_free: Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else: Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

# --- NEW SHOOTING & RECOIL LOGIC ---

func handle_recoil(delta: float) -> void:
	# Smoothly interpolate target recoil back to zero
	target_recoil = target_recoil.lerp(Vector2.ZERO, recoil_recovery_speed * delta)
	var recoil_diff = target_recoil - current_recoil
	current_recoil += recoil_diff
	
	# Apply pitch (x) to the Camera3D and yaw (y) to the base Node3D
	camera.rotation.x = clamp(camera.rotation.x + deg_to_rad(recoil_diff.x), deg_to_rad(max_up_angle_view), deg_to_rad(max_down_angle_view))
	rotate_y(deg_to_rad(recoil_diff.y))

func apply_recoil(recoil_pitch: float, recoil_yaw: float) -> void:
	# Call this from your Weapon/Player script when firing!
	# Example: camera_object.apply_recoil(1.5, randf_range(-0.5, 0.5))
	target_recoil.x += recoil_pitch
	target_recoil.y += recoil_yaw

func get_aim_target() -> Dictionary:
	# Used for Hitscan weapons. Returns data about what the player is looking at.
	if aim_raycast and aim_raycast.is_colliding():
		return {
			"hit": true,
			"position": aim_raycast.get_collision_point(),
			"normal": aim_raycast.get_collision_normal(),
			"collider": aim_raycast.get_collider()
		}
	
	# If no hit, return a point far off in the distance
	var fallback_pos = camera.global_position - camera.global_transform.basis.z * 1000.0
	return {
		"hit": false,
		"position": fallback_pos
	}
