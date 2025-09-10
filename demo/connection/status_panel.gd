extends CanvasLayer

var connection
var button

func connect_pressed():
	connection.connect_client()

func status_updated():
	if connection.get_status("controller"):
		button.hide()
	else:
		button.show()
		

func _ready():
	connection = get_node("/root/Connection")
	connection.status_updated.connect(self.status_updated)
	
	button = get_node("PanelStatus/HBoxContainer/Button")
	button.pressed.connect(self.connect_pressed)
