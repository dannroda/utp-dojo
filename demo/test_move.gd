extends Node3D

var players = {}
var ships = {}

var player_local
var ship_local

func player_updated(id, status):
	if !(id in players):
		new_player(id)
		
	players[id].model_status = status

func new_player(id):
	if !(id in players):
		var node = preload("player_remote.tscn").instantiate()
		players[id] = node
	else:
		printt("new player already instanced? ", id)

	add_child(players[id])
	
func player_movement(id, src, dst):
	
	if !(id in players):
		new_player(id)
		printt("player move not instanced?", id)
	
	players[id].move_event(src, dst)

func _input(event):
	if !event.is_action("move") || !event.is_pressed():
		return
	var camera = get_tree().get_nodes_in_group("Camera")[0]
	var mousePos = get_viewport().get_mouse_position()
	var rayLength = 100
	var from = camera.project_ray_origin(mousePos)
	var to = from + camera.project_ray_normal(mousePos) * rayLength
	var space = get_world_3d().direct_space_state
	var rayQuery = PhysicsRayQueryParameters3D.new()
	rayQuery.from = from
	rayQuery.to = to
	rayQuery.collide_with_areas = true
	var result = space.intersect_ray(rayQuery)
	if !("position" in result):
		return

	player_local.move_local(result.position)

func _ready():
	get_node("/root/Connection").world = self
	player_local = get_node("player_local")
