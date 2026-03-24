extends State

class_name DashState

var state_name : String = "Dash"

var play_char : CharacterBody3D

func enter(play_char_ref : CharacterBody3D):
	play_char = play_char_ref
	
	# --- LOOTABLE SKILL CHECK ---
	# If the dash skill is NOT unlocked for THIS specific player, cancel.
	if not play_char.has_dash_skill:
		if play_char.is_on_floor():
			transitioned.emit(self, play_char.walk_or_run)
		else:
			transitioned.emit(self, "InairState")
		return
	# ----------------------------
	
	verifications()
	
func verifications():
	# FIX: Ensure the dash timer is fully refreshed at the exact moment the dash begins.
	# If the reference timer is missing/zero, default it to 0.1 seconds.
	if play_char.dash_time_ref <= 0.0:
		play_char.dash_time_ref = 0.1
	play_char.dash_time = play_char.dash_time_ref
	
	play_char.velocity_pre_dash = play_char.velocity #get velocity before start dashing, to apply it later, after dash finished, to keep a smooth transitio between dash state and next state
	
	# Calculate 3D dash direction based on camera and player input
	var input_dir = Input.get_vector(play_char.move_left_action, play_char.move_right_action, play_char.move_forward_action, play_char.move_backward_action)
	var cam_basis = play_char.cam.global_transform.basis
	
	# Rotate the player's input by the camera's 3-dimensional facing direction
	var dash_dir = (cam_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# If no movement keys are pressed, just dash straight ahead where the camera is looking
	if dash_dir == Vector3.ZERO:
		dash_dir = -cam_basis.z
		
	play_char.dash_direction = dash_dir 
	
	play_char.hud.display_speed_lines(true)
	
	play_char.nb_dashs_allowed -= 1
	
	play_char.tween_hitbox_height(play_char.base_hitbox_height)
	play_char.tween_model_height(play_char.base_model_height)
	
func physics_update(delta : float):
	# We no longer call move() down here to prevent overwriting the exit velocity
	applies(delta)
	
func applies(delta : float):
	if play_char.dash_time > 0.0: 
		play_char.dash_time -= delta
		move() # FIX: Only move WHILE the timer is actively counting down
	else:
		if play_char.is_on_floor():
			transitioned.emit(self, play_char.walk_or_run)
		else:
			transitioned.emit(self, "InairState")
			
func move():
	#can't change direction while dashing
	if play_char.dash_direction != Vector3.ZERO:
		play_char.desired_move_speed = clamp(play_char.desired_move_speed, 0.0, play_char.max_desired_move_speed)
		
		# Apply dash speed to all 3 axes (X, Y, and Z) to enable vertical/diagonal dashing
		play_char.velocity.x = play_char.dash_direction.x * play_char.dash_speed
		play_char.velocity.y = play_char.dash_direction.y * play_char.dash_speed
		play_char.velocity.z = play_char.dash_direction.z * play_char.dash_speed

# FIX: Added the exit() function. 
# This runs automatically when leaving the state, guaranteeing a speed reset even if the timer was interrupted.
func exit():
	play_char.time_bef_can_dash_again = play_char.time_bef_can_dash_again_ref
	
	# Reset velocity on all axes completely to stop the player dead in the air 
	# so they don't carry the massive dash momentum into the fall/walk
	play_char.velocity = Vector3(play_char.velocity_pre_dash.x, 0.0, play_char.velocity_pre_dash.z)
	play_char.has_dashed = true
	play_char.hud.display_speed_lines(false)
