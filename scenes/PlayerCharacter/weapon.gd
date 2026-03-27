extends Node3D
class_name Weapon

@export_group("Weapon Settings")
@export var damage: int = 25
@export var fire_rate: float = 0.1 # Seconds between shots. 0.1 = 10 shots per second.
@export var automatic: bool = true # If true, holding the button fires continuously.

@export_group("Ammo & Reloading")
@export var max_ammo: int = 30
@export var reserve_ammo: int = 90
@export var infinite_reserve: bool = false
@export var reload_time: float = 1.5

@export_group("Recoil Settings")
@export var vertical_recoil: float = 1.5
@export var horizontal_recoil: float = 0.5

@export_group("Visuals")
@export var weapon_model: Node3D ## Assign your 3D gun mesh here!

@export_group("References")
@export var camera_object: CameraObject
## Optional: Assign an AudioStreamPlayer3D for the gunshot sound
@export var shoot_sound: AudioStreamPlayer3D 

var time_since_last_shot: float = 0.0
var current_ammo: int = 0
var is_reloading: bool = false

var original_model_pos: Vector3
var original_model_rot: Vector3

func _ready() -> void:
	current_ammo = max_ammo
	
	# Save the original position and rotation of the weapon model so we can snap back to it
	if weapon_model:
		original_model_pos = weapon_model.position
		original_model_rot = weapon_model.rotation

func _process(delta: float) -> void:
	# IMPORTANT: Only the local player who owns this character should be able to shoot
	if multiplayer.has_multiplayer_peer() and not is_multiplayer_authority(): 
		return
		
	# Smoothly return the weapon model to its original position after recoil kick
	if weapon_model and not is_reloading:
		weapon_model.position = weapon_model.position.lerp(original_model_pos, 10.0 * delta)
		weapon_model.rotation = weapon_model.rotation.lerp(original_model_rot, 10.0 * delta)
		
	# Prevent shooting if input is blocked (e.g., chat is open)
	if typeof(Global_self) != TYPE_NIL and "input_blocked" in Global_self and Global_self.input_blocked: 
		return

	# Check for manual reload
	if Input.is_action_just_pressed("reload") and current_ammo < max_ammo and not is_reloading:
		reload()
		
	# Stop processing shooting logic if we are currently reloading
	if is_reloading:
		return

	time_since_last_shot += delta
	
	# Check for shooting input based on whether the weapon is automatic or semi-automatic
	var wants_to_shoot = false
	if automatic:
		wants_to_shoot = Input.is_action_pressed("shoot")
	else:
		wants_to_shoot = Input.is_action_just_pressed("shoot")
		
	# If pressing shoot and the fire rate cooldown has passed
	if wants_to_shoot and time_since_last_shot >= fire_rate:
		if current_ammo > 0:
			fire_weapon()
		else:
			# Auto-reload if we try to shoot while empty
			reload()

func fire_weapon() -> void:
	# 1. Deduct ammo and reset the fire timer
	current_ammo -= 1
	time_since_last_shot = 0.0
	
	# Animate the gun model kicking back and up visually
	if weapon_model:
		weapon_model.position.z += 0.1 # Kick back towards camera
		weapon_model.rotation.x += 0.05 # Kick muzzle up slightly
	
	# 2. Play sound if assigned
	if shoot_sound:
		shoot_sound.play()
	
	# 3. Ask the camera exactly what we are aiming at
	if camera_object:
		var aim_data = camera_object.get_aim_target()
		
		# 4. Apply some recoil to make the gun feel powerful
		var random_yaw = randf_range(-horizontal_recoil, horizontal_recoil)
		camera_object.apply_recoil(vertical_recoil, random_yaw)
		
		# 5. Check if the camera's raycast actually hit something
		if aim_data["hit"]:
			var hit_position = aim_data["position"]
			var hit_normal = aim_data["normal"]
			var collider = aim_data["collider"]
			
			# Print for debugging so you can test if it works!
			print("Pew! Hit: ", collider.name, " at ", hit_position)
			
			# 6. Apply damage if the object has a hit/take_damage function
			if collider.has_method("take_damage"):
				# If you want multiplayer damage, you might need an RPC call here instead
				collider.take_damage(damage)
			elif collider.has_method("hit"):
				collider.hit(damage)

func reload() -> void:
	# Check if we even have reserve ammo left
	if not infinite_reserve and reserve_ammo <= 0:
		print("Out of reserve ammo!")
		return
		
	is_reloading = true
	
	# Animate the gun dipping down during reload
	if weapon_model:
		var reload_tween = create_tween()
		reload_tween.tween_property(weapon_model, "rotation:x", deg_to_rad(-45), 0.2)
	
	# Wait for the reload animation/timer to finish
	await get_tree().create_timer(reload_time).timeout
	
	# Calculate how much ammo we need to fill the magazine
	var ammo_needed = max_ammo - current_ammo
	
	if infinite_reserve:
		current_ammo = max_ammo
	else:
		# Take either the ammo needed or whatever is left in reserve, whichever is smaller
		var ammo_to_add = min(ammo_needed, reserve_ammo)
		current_ammo += ammo_to_add
		reserve_ammo -= ammo_to_add
		
	is_reloading = false
	
	# Return gun to normal position
	if weapon_model:
		var return_tween = create_tween()
		return_tween.tween_property(weapon_model, "rotation:x", original_model_rot.x, 0.2)
