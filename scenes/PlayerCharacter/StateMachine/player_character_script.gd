extends CharacterBody3D
class_name PlayerCharacter

@export_group("Multiplayer & Stats")
@export var world: Node
@export var bar_nickname: Label
@export var bar_health: ProgressBar
@export var mouse_sensitivity := 0.002
@export var camera_limit := 90
var pitch := 0.0

@export var nickname :String :
	set(v):
		nickname = v
		emit_signal("_sync_nick")
		if bar_nickname:
			bar_nickname.text = nickname
signal _sync_nick
signal hud_ready

@rpc("any_peer", "call_local", "reliable")
func sync(nick: String) -> void:
	self.nickname = nick

@rpc("any_peer", "call_local", "reliable")
func unlock_dash_skill() -> void:
	has_dash_skill = true
	# Fill the stocks up to maximum upon unlocking the skill
	nb_dashs_allowed = nb_dashs_allowed_ref

@rpc("any_peer", "call_local", "reliable")
func restock_dashes() -> void:
	# Call this method when picking up a dash refill item
	nb_dashs_allowed = nb_dashs_allowed_ref

@rpc("any_peer", "call_local", "reliable")
func add_rock_ammo(amount: int) -> void:
	rock_ammo += amount
	if rock_ammo_label:
		rock_ammo_label.text = "Ammo: " + str(rock_ammo)
	print(nickname, " picked up a rock! Total ammo: ", rock_ammo)

@export var health = 0:
	set(v):
		health = v
		if game_hud and "health" in game_hud:
			game_hud.health = v
		if bar_health:
			bar_health.value = health
			if bar_health.has_node("Label"):
				bar_health.get_node("Label").text = str(health) + "/" + str(health_max)
		
		# Death Check
		if health <= 0 and not is_dead and multiplayer.has_multiplayer_peer() and is_multiplayer_authority():
			rpc("sync_die")

@export var health_max = 0:
	set(v):
		health_max = v
		if game_hud and "health_max" in game_hud:
			game_hud.health_max = v
		if bar_health:
			bar_health.max_value = health_max
			if bar_health.has_node("Label"):
				bar_health.get_node("Label").text = str(health) + "/" + str(health_max)

@export_group("Death & Respawn")
@export var respawn_time: float = 5.0
@export var default_spawn_pos: Vector3 = Vector3(0, 5, 0)
var is_dead: bool = false
var current_respawn_timer: float = 0.0
var death_hud: CanvasLayer
var death_label: Label

@export_group("Movement variables")
@export var move_speed: float
@export var move_accel: float
@export var move_deccel: float
var input_direction: Vector2
var move_direction: Vector3
var desired_move_speed: float
@export var desired_move_speed_curve: Curve
@export var max_desired_move_speed: float = 30.0
@export var in_air_move_speed_curve: Curve
@export var hit_ground_cooldown: float = 0.1
var hit_ground_cooldown_ref: float
@export var bunny_hop_dms_incre: float = 3.0
@export var auto_bunny_hop: bool = false
var last_frame_position: Vector3
var last_frame_velocity: Vector3
var was_on_floor: bool
var walk_or_run: String = "WalkState"

@export var base_hitbox_height: float = 2.0
@export var base_model_height: float = 1.0
@export var height_change_duration: float = 0.15

@export_group("Crouch variables")
@export var crouch_speed: float = 6.0
@export var crouch_accel: float = 12.0
@export var crouch_deccel: float = 11.0
@export var continious_crouch: bool = false
@export var crouch_hitbox_height: float = 1.2
@export var crouch_model_height: float = 0.6

@export_group("Walk variables")
@export var walk_speed: float = 9.0
@export var walk_accel: float = 11.0
@export var walk_deccel: float = 10.0

@export_group("Run variables")
@export var run_speed: float = 12.0
@export var run_accel: float = 10.0
@export var run_deccel: float = 9.0
@export var continious_run: bool = false

@export_group("Jump variables")
@export var jump_height: float = 2.0
@export var jump_time_to_peak: float = 0.3
@export var jump_time_to_fall: float = 0.25
@onready var jump_velocity: float = (2.0 * jump_height) / jump_time_to_peak
@export var jump_cooldown: float = 0.25
var jump_cooldown_ref: float
@export var nb_jumps_in_air_allowed: int = 1
var nb_jumps_in_air_allowed_ref: int
var jump_buff_on: bool = false
var buffered_jump: bool = false
@export var coyote_jump_cooldown: float = 0.3
var coyote_jump_cooldown_ref: float
var coyote_jump_on: bool = false

@export_group("Slide variables")
var slide_direction: Vector3 = Vector3.ZERO
@export var use_desired_move_speed: bool = false
@export var slide_speed: float = 12.0
@export var slide_accel: float = 23.0
@export var slide_time: float = 1.2
var slide_time_ref: float
@export var time_bef_can_slide_again: float = 1.5
var time_bef_can_slide_again_ref: float
@export_range(0.0, 90.0, 0.1) var max_slope_angle: float = 75.0
@export_range(0.0, 0.1, 0.001) var uphill_tolerance : float = 0.05
@export var amount_velocity_lost_per_sec: float = 4.0
@export var slope_sliding_dms_incre: float = 2.0
@export var slope_sliding_ms_incre: float = 2.0
@export var priority_over_crouch: bool = true
@export var continious_slide: bool = true
var slide_buff_on: bool = false
@export var slide_hitbox_height: float = 1.0
@export var slide_model_height: float = 0.5

@export_group("Dash variables")
@export var has_dash_skill: bool = false
var dash_direction: Vector3 = Vector3.ZERO
@export var dash_speed: float = 100.0
@export var dash_time: float = 0.1
var dash_time_ref: float
@export var nb_dashs_allowed: int = 3
var nb_dashs_allowed_ref: int
@export var time_bef_can_dash_again: float = 0.8
var time_bef_can_dash_again_ref: float
var velocity_pre_dash : Vector3
var has_dashed : bool = false

@export_group("Wallrun variables")
var can_wallrun : bool = true
var side_check_raycast_collided : int = 0
var last_wallrunned_wall_out_of_time : int = 0
var wall_normal : Vector3 = Vector3.ZERO
var wall_forward_dir : Vector3 = Vector3.ZERO
@export var use_desired_move_speed_wallrun : bool = false
@export var wallrun_speed : float = 18.0
@export var wallrun_accel : float = 2.3
@export var wallrun_deccel : float = 7.0
@export_range(0.0, 1.0, 0.001) var wallrun_fall_gravity_multiplier : float = 0.006
@export var wallrun_time : float = 3.5
var wallrun_time_ref : float
@export var infinite_wallrun_time : bool = false
@export var time_bef_can_wallrun_again : float = 0.2
var time_bef_can_wallrun_again_ref : float
@export var wallrunning_dms_incre : float = 1.0

@export_group("Walljump variables")
var about_to_jump_vel : Vector3
@export var walljump_push_force : float = 14.0
@export var walljump_y_velocity : float = 9.0
@export var walljump_lock_in_air_movement_time : float = 0.15
var walljump_lock_in_air_movement_time_ref : float

@export_group("Fly variables")
@export var fly_speed: float = 20.0
@export var fly_accel: float = 15.0
@export var fly_deccel: float = 15.0
@export var fly_boost_multiplier: float = 3.0
var fly_boost_on: bool = false

@export_group("Gravity variables")
@onready var jump_gravity: float = (-2.0 * jump_height) / (jump_time_to_peak * jump_time_to_peak)
@onready var fall_gravity: float = (-2.0 * jump_height) / (jump_time_to_fall * jump_time_to_fall)

@export_group("Rock Grenade variables")
@export var rock_scene: PackedScene
@export var throw_force: float = 15.0
var rock_ammo: int = 1
@onready var rock_ammo_label: Label = $HUD/RockAmmo

@export_group("Keybind variables")
@export var move_forward_action: StringName = "play_char_move_forward_action"
@export var move_backward_action: StringName = "play_char_move_backward_action"
@export var move_left_action: StringName = "play_char_move_left_ation"
@export var move_right_action: StringName = "play_char_move_right_action"
@export var run_action: StringName = "play_char_run_action"
@export var crouch_action: StringName = "play_char_crouch_action"
@export var jump_action: StringName = "play_char_jump_action"
@export var slide_action: StringName = "play_char_slide_action"
@export var dash_action: StringName = "play_char_dash_action"
@export var fly_action: StringName = "play_char_fly_action"
@onready var input_actions_list : Array[StringName] = [move_forward_action, move_backward_action, move_left_action, move_right_action, 
run_action, crouch_action, jump_action, slide_action, dash_action, fly_action]
@export var check_on_ready_if_inputs_registered : bool = true
var default_input_actions : Dictionary

@onready var cam_holder: Node3D = $CameraHolder
@onready var cam: Camera3D = %Camera
@onready var model: MeshInstance3D = $Model
@onready var hitbox: CollisionShape3D = $Hitbox
@onready var state_machine: Node = $StateMachine

var game_hud: CanvasLayer

var hud: CanvasLayer:
	get:
		return get_node_or_null("HUD")
	set(value):
		game_hud = value

@onready var ceiling_check: RayCast3D = %CeilingCheck
@onready var floor_check: RayCast3D = %FloorCheck
@onready var wallrun_floor_check : RayCast3D = %WallrunFloorCheck
@onready var slide_floor_check: RayCast3D = %SlideFloorCheck
@onready var left_wall_check : RayCast3D = %LeftWallCheck
@onready var right_wall_check : RayCast3D = %RightWallCheck

func _enter_tree() -> void:
	set_multiplayer_authority(str(name).to_int())
	
	if multiplayer.has_multiplayer_peer() and is_multiplayer_authority():
		if typeof(Global_self) != TYPE_NIL and "nickname" in Global_self:
			self.nickname = Global_self.nickname 

func _ready() -> void:
	add_to_group("player") 
	
	hit_ground_cooldown_ref = hit_ground_cooldown
	jump_cooldown_ref = jump_cooldown
	jump_cooldown = -1.0
	nb_jumps_in_air_allowed_ref = nb_jumps_in_air_allowed
	coyote_jump_cooldown_ref = coyote_jump_cooldown
	slide_time_ref = slide_time
	time_bef_can_slide_again_ref = time_bef_can_slide_again
	time_bef_can_slide_again = -1.0
	time_bef_can_dash_again_ref = time_bef_can_dash_again
	time_bef_can_dash_again = -1.0
	nb_dashs_allowed_ref = nb_dashs_allowed
	wallrun_time_ref = wallrun_time
	time_bef_can_wallrun_again_ref = time_bef_can_wallrun_again
	walljump_lock_in_air_movement_time_ref = walljump_lock_in_air_movement_time
	walljump_lock_in_air_movement_time = -1.0
	
	build_default_keybinding()
	input_actions_check()
	
	if multiplayer.has_multiplayer_peer() and is_multiplayer_authority():
		add_to_group("local_player") 
		
		if cam: cam.current = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		self.health_max = 100 
		self.health = 100     
		
		if model:
			model.visible = false
		
		if nickname != "":
			rpc("sync", nickname)

	else:
		if cam: 
			cam.current = false
			
		var local_players = get_tree().get_nodes_in_group("local_player")
		if local_players.size() > 0 and local_players[0].cam:
			local_players[0].cam.current = true
		
		if hud: 
			hud.hide() 
			hud.process_mode = Node.PROCESS_MODE_DISABLED 
		
		if model:
			model.visible = true
			
		if state_machine:
			state_machine.process_mode = Node.PROCESS_MODE_DISABLED

func build_default_keybinding() -> void:
	default_input_actions = {
		move_forward_action : [Key.KEY_W, Key.KEY_UP],
		move_backward_action : [Key.KEY_S, Key.KEY_DOWN],
		move_left_action : [Key.KEY_A, Key.KEY_LEFT],
		move_right_action : [Key.KEY_D, Key.KEY_RIGHT],
		run_action : [Key.KEY_SHIFT],
		crouch_action : [Key.KEY_C],
		jump_action : [Key.KEY_SPACE],
		slide_action : [Key.KEY_C],
		dash_action : [Key.KEY_CTRL],
		fly_action : [Key.KEY_F]
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
				
				push_warning("'{input}' missing in InputMap, or input action wrongly named in the editor.\nAdding the '{input}' to runtime InputMap temporarily with the key/s: {keys}"
				.format({"input": input_action, "keys": String(", ").join(key_names)}))
				
				InputMap.add_action(input_action)
				for keycode in default_input_actions[input_action]:
					var input_event_key = InputEventKey.new()
					input_event_key.physical_keycode = keycode
					InputMap.action_add_event(input_action, input_event_key)

func _unhandled_input(event) -> void:
	if not multiplayer.has_multiplayer_peer() or not is_multiplayer_authority(): return
	if is_dead: return # Block input while dead
	
	if typeof(Global_self) != TYPE_NIL and "input_blocked" in Global_self and Global_self.input_blocked: 
		return
	
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		pitch -= event.relative.y * mouse_sensitivity
		pitch = clamp(pitch, deg_to_rad(-camera_limit), deg_to_rad(camera_limit))
		if cam_holder:
			cam_holder.rotation.x = pitch
<<<<<<< Updated upstream
	if event.is_action_pressed("fire"):
		throw_rock()
=======
	#if event.is_action_pressed("fire"):
		#throw_rock()
>>>>>>> Stashed changes
		
func _process(delta: float) -> void:
	if not multiplayer.has_multiplayer_peer() or not is_multiplayer_authority(): return
	
	if is_dead:
		current_respawn_timer -= delta
		if death_label:
			death_label.text = "YOU DIED\nRespawning in: " + str(ceil(current_respawn_timer))
		
		if current_respawn_timer <= 0.0:
			rpc("sync_respawn", default_spawn_pos)
		return # Stop processing ability timers while dead
	
	wallrun_timer(delta)
	slide_timer(delta)
	dash_timer(delta)
	
func _physics_process(delta: float) -> void:
	if not multiplayer.has_multiplayer_peer() or not is_multiplayer_authority(): return
	
	if is_dead: 
		velocity = Vector3.ZERO
		return # Prevent all physics movement while dead
	
	modify_physics_properties()
	
	# FIX: Hard-stop horizontal velocity and disable the State Machine entirely so 
	# it doesn't try to re-apply the movement speed or trigger jumping inputs.
	if typeof(Global_self) != TYPE_NIL and "input_blocked" in Global_self and Global_self.input_blocked:
		velocity.x = 0.0
		velocity.z = 0.0
		input_direction = Vector2.ZERO
		gravity_apply(delta) # Manually apply gravity so the player doesn't float
		
		if state_machine:
			state_machine.process_mode = Node.PROCESS_MODE_DISABLED
	else:
		# Turn the state machine back on once chat is closed
		if state_machine and state_machine.process_mode == Node.PROCESS_MODE_DISABLED:
			state_machine.process_mode = Node.PROCESS_MODE_INHERIT
		
	move_and_slide()

# --- DEATH AND RESPAWN SYSTEM ---

@rpc("any_peer", "call_local", "reliable")
func sync_die() -> void:
	is_dead = true
	current_respawn_timer = respawn_time
	
	# Disable player collision so they can't be interacted with or shot
	hitbox.set_deferred("disabled", true)
	
	# Hide the 3D model (mostly for the remote clients looking at this player)
	if model: 
		model.visible = false
	
	# Handle specific things for the local client that just died
	if is_multiplayer_authority():
		create_death_hud()
		velocity = Vector3.ZERO
		input_direction = Vector2.ZERO
		if state_machine:
			state_machine.process_mode = Node.PROCESS_MODE_DISABLED

@rpc("any_peer", "call_local", "reliable")
func sync_respawn(spawn_pos: Vector3) -> void:
	is_dead = false
	health = health_max
	
	global_position = spawn_pos
	velocity = Vector3.ZERO
	
	# Re-enable collision
	hitbox.set_deferred("disabled", false)
	
	# Show the 3D model again (ONLY for remote clients; authority stays hidden if FPP)
	if not is_multiplayer_authority():
		if model: 
			model.visible = true
			
	# Cleanup UI and states for the local client
	if is_multiplayer_authority():
		remove_death_hud()
		if state_machine:
			state_machine.process_mode = Node.PROCESS_MODE_INHERIT

func create_death_hud() -> void:
	if death_hud != null: return
	
	death_hud = CanvasLayer.new()
	death_hud.layer = 100 # Ensure it draws on top of everything
	
	var control = Control.new()
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
	death_hud.add_child(control)
	
	var bg = ColorRect.new()
	bg.color = Color(0.3, 0.0, 0.0, 0.6) # Dark semi-transparent red
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	control.add_child(bg)
	
	death_label = Label.new()
	death_label.text = "YOU DIED\nRespawning in: " + str(int(current_respawn_timer))
	death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	death_label.add_theme_font_size_override("font_size", 42)
	death_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	control.add_child(death_label)
	
	add_child(death_hud)

func remove_death_hud() -> void:
	if death_hud != null:
		death_hud.queue_free()
		death_hud = null
		death_label = null

# --- END DEATH AND RESPAWN SYSTEM ---

func wallrun_timer(delta : float) -> void:
	if !can_wallrun:
		if time_bef_can_wallrun_again > 0.0: time_bef_can_wallrun_again -= delta
		else:
			if state_machine.curr_state_name != "Wallrun":
				wallrun_time = wallrun_time_ref
				can_wallrun = true
	
func slide_timer(delta: float) -> void:
	if time_bef_can_slide_again > 0.0: time_bef_can_slide_again -= delta
	else:
		if state_machine.curr_state_name != "Slide":
			slide_time = slide_time_ref
			
func dash_timer(delta: float) -> void:
	# Removed automated dash restock timer
	if time_bef_can_dash_again > 0.0: time_bef_can_dash_again -= delta
	else:
		if state_machine.curr_state_name != "Dash":
			dash_time = dash_time_ref
			
func modify_physics_properties() -> void:
	last_frame_position = global_position 
	last_frame_velocity = velocity 
	was_on_floor = is_on_floor() 
	
func gravity_apply(delta: float) -> void:
	if velocity.y >= 0.0: velocity.y += jump_gravity * delta
	elif velocity.y < 0.0: velocity.y += fall_gravity * delta
	
func tween_hitbox_height(state_hitbox_height : float) -> void:
	var hitbox_tween: Tween = create_tween()
	if hitbox != null:
		hitbox_tween.tween_method(func(v): set_hitbox_height(v), hitbox.shape.height, 
		state_hitbox_height, height_change_duration)
	else:
		hitbox_tween.tween_interval(0.1)
	hitbox_tween.finished.connect(Callable(hitbox_tween, "kill"))

func set_hitbox_height(value: float) -> void:
	if hitbox.shape is CapsuleShape3D:
		hitbox.shape.height = value
		
func tween_model_height(state_model_height : float) -> void:
	var model_tween: Tween = create_tween()
	if model != null:
		model_tween.tween_property(model, "scale:y", 
		state_model_height, height_change_duration)
	else:
		model_tween.tween_interval(0.1)
	model_tween.finished.connect(Callable(model_tween, "kill"))

# --- FIXED ROCK THROWING SYSTEM ---

func throw_rock() -> void:
	if not multiplayer.has_multiplayer_peer() or not is_multiplayer_authority(): return
	if rock_scene == null: return
	
	# Check if we have ammo before throwing!
	if rock_ammo <= 0:
		print("No rocks to throw!")
		return
	
	# Calculate the origin and direction LOCALLY
	var spawn_pos = cam.global_transform.origin - cam.global_transform.basis.z * 1.5
	var throw_dir = (-cam.global_transform.basis.z + Vector3(0, 0.3, 0)).normalized()
	
	# CREATE A UNIQUE NAME based on the player ID and the current time.
	# This guarantees the rock gets the EXACT SAME NodePath on all connected clients.
	var unique_rock_name = "Rock_" + str(multiplayer.get_unique_id()) + "_" + str(Time.get_ticks_msec())
	
	# Pass the generated name into the RPC so everyone builds it identically
	rpc("sync_throw_rock", unique_rock_name, spawn_pos, throw_dir)

@rpc("any_peer", "call_local", "reliable")
func sync_throw_rock(rock_name: String, spawn_pos: Vector3, throw_dir: Vector3) -> void:
	if rock_scene == null: return
	
	# Deduct 1 ammo from the player who threw it
	rock_ammo -= 1 
	if rock_ammo_label:
		rock_ammo_label.text = "Ammo: " + str(rock_ammo)
	
	# Create the rock
	var rock = rock_scene.instantiate()
	
	# CRITICAL FIX: Set the name so it matches perfectly across Host and Clients
	rock.name = rock_name
	
	# Add it to the tree
	get_tree().current_scene.add_child(rock)
	
	# Position the rock using the synced position
	rock.global_position = spawn_pos
	
	# --- PHYSICS DESYNC FIX ---
	# ONLY the Server should calculate physics. Clients will follow the Server's simulation.
	if multiplayer.is_server():
		rock.apply_central_impulse(throw_dir * throw_force)
	else:
		# Freeze the rock on clients so the local physics engine doesn't fight the server updates
		rock.freeze = true
