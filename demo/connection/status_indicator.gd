@tool
class_name DojoStatusIndicator
extends PanelContainer

@export var stat_name: String

const COLOR_TRUE := Color.GREEN
const COLOR_FALSE := Color.RED

@onready var type: Label = $StatusIndicator/Type
@onready var status: ColorRect = $StatusIndicator/Status
var connection

@export var type_name : String :
	set(val):
		type_name = val
		if is_instance_valid(type):
			type.text = type_name

func set_status(value:bool) -> void:
	if value:
		status.color = COLOR_TRUE
	else:
		status.color = COLOR_FALSE

func status_updated():
	if stat_name == "":
		return
		
	set_status(connection.get_status(stat_name))

func _ready() -> void:
	if not type_name.is_empty() and type.text != type_name:
		type.text = type_name

	connection = get_node("/root/Connection")
	connection.status_updated.connect(self.status_updated)
	status_updated()
