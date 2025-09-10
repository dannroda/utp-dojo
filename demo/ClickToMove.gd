extends CharacterBody3D

var connection

@onready var navigationAgent : NavigationAgent3D = $NavigationAgent3D
var Speed = 5
var player_id = ""

# Called when the node enters the scene tree for the first time.
func _ready():
	connection = get_node("/root/Connection")
	set_player_id("local player")
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if(navigationAgent.is_navigation_finished()):
		return
	
	moveToPoint(delta, Speed)
	pass

func set_player_id(p_id):
	player_id = p_id
	get_node("id_label").set_text(p_id)


func moveToPoint(delta, speed):
	var targetPos = navigationAgent.get_next_path_position()
	var direction = global_position.direction_to(targetPos)
	faceDirection(targetPos)
	velocity = direction * speed
	move_and_slide()

func faceDirection(direction):
	look_at(Vector3(direction.x, global_position.y, direction.z), Vector3.UP)

func move_local(pos):
	navigationAgent.target_position = pos
	connection.player_move(pos)
