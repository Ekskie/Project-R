extends Area3D

@export var rotation_speed: float = 2.0
@export var respawn_time: float = 10.0 # Time in seconds before the item respawns

func _process(delta: float) -> void:
	rotate_y(rotation_speed * delta)

func _on_body_entered(body: Node3D) -> void:
	# Check if the player character entered the zone
	if body is PlayerCharacter:
		# Only the player who actually controls this character can trigger the pickup.
		# This prevents the item from being picked up twice if there's a slight network delay.
		if body.is_multiplayer_authority():
			
			# Tell all peers that THIS specific player unlocked the dash
			body.rpc("unlock_dash_skill")
			
			# Tell all peers to trigger the pickup and respawn sequence
			rpc("trigger_pickup")

# Syncs the pickup and respawn logic across all clients simultaneously
@rpc("any_peer", "call_local", "reliable")
func trigger_pickup() -> void:
	# Hide the item visually
	hide()
	
	# Disable collisions safely so it can't be picked up while hidden
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	
	# Start the respawn timer
	await get_tree().create_timer(respawn_time).timeout
	
	# Respawn the item: show it and re-enable collisions
	show()
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)
