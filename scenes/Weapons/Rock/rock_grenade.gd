extends RigidBody3D
class_name ThrowableRock

@export_group("Rock Stats")
@export var impact_damage: int = 10
@export var time_until_lootable: float = 1.0

var is_lethal: bool = true

func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 1
	body_entered.connect(_on_body_entered)
	
	# Only the server needs to track the lootable timer to prevent desyncs
	if multiplayer.is_server():
		var lootable_timer = get_tree().create_timer(time_until_lootable)
		lootable_timer.timeout.connect(_make_lootable)

func _make_lootable() -> void:
	is_lethal = false
	# Tell all clients this rock is no longer dangerous
	rpc("sync_lootable_state")

@rpc("authority", "call_local", "reliable")
func sync_lootable_state():
	is_lethal = false

func _on_body_entered(body: Node) -> void:
	# ONLY the server should process damage and pickups to prevent double-hits and ghost rocks
	if not multiplayer.is_server():
		return 

	if body.is_in_group("PlayerCharacter") or body is PlayerCharacter:
		if is_lethal:
			# The rock is dangerous
			if "health" in body:
				body.health -= impact_damage
				print(body.name, " was hit by a rock for ", impact_damage, " damage!")
		else:
			# The rock is a pickup
			if body.has_method("add_rock_ammo"):
				# Give the specific player ammo. Assuming add_rock_ammo is an RPC on the player
				body.rpc("add_rock_ammo", 1)
				
			# Tell all peers to remove this rock from the world
			rpc("trigger_pickup")

@rpc("authority", "call_local", "reliable")
func trigger_pickup() -> void:
	# Safely destroy the rock across all clients
	queue_free()
