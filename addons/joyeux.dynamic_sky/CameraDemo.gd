extends Camera

export(NodePath) var path_to_environment = ""
onready var dynamic_env = get_node(path_to_environment)

func _ready():
	dynamic_env.add_env_to_camera(self)

