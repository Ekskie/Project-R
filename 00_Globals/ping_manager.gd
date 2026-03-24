extends Node

## Stores the current ping in milliseconds. Read this variable from your UI.
var current_ping_ms: int = 0

var _last_request_time: int = 0

func _ready() -> void:
	# Create a timer to check the ping every 1 second
	var timer = Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_on_timer_timeout)
	add_child(timer)

func _on_timer_timeout() -> void:
	# Ensure multiplayer is active and connected before pinging
	if not multiplayer.has_multiplayer_peer() or multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		current_ping_ms = 0
		return

	if multiplayer.is_server():
		# The server has 0 ping to itself
		current_ping_ms = 0
	else:
		# Client: Send a ping request to the server (peer ID 1)
		_last_request_time = Time.get_ticks_msec()
		_receive_ping_request.rpc_id(1)

# SERVER FUNCTION: Receives the ping request and bounces it back
@rpc("any_peer", "call_remote", "unreliable")
func _receive_ping_request() -> void:
	var sender_id = multiplayer.get_remote_sender_id()
	# Send a response immediately back to the client
	_receive_ping_response.rpc_id(sender_id)

# CLIENT FUNCTION: Receives the response and calculates the time difference
@rpc("authority", "call_remote", "unreliable")
func _receive_ping_response() -> void:
	var current_time = Time.get_ticks_msec()
	current_ping_ms = current_time - _last_request_time
