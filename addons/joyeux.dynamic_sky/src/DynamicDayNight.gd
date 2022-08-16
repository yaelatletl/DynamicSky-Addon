tool
extends WorldEnvironment

onready var image : TextureRect = $Sky/Sprite
onready var sky : Viewport = $Sky
onready var sun : DirectionalLight = $DirectionalLight
onready var sun_rays : Spatial = $DirectionalLight/GodRays
export(int) var initial_time_serialized : int = 0
export(bool) var cheap_shader = true
export(Color) var sky_dome_color = Color(0.5, 0.5, 0.5, 1) setget set_dome_color, get_dome_color
export(Color) var sky_horizon_color = Color(0.5, 0.5, 0.5, 1) setget set_horizon_color, get_horizon_color
export(Gradient) var skygradient = null
export(Gradient) var horizongradient = null
export(Gradient) var sungradient = null
export(Gradient) var absorbtiongradient = null
export(float, 0.0, 1.0, 0.001) var coverage = 0.5 setget set_coverage, get_coverage
export(float, 0.0, 1.0, 0.001) var thickness = 0.5 setget set_thickness, get_thickness
export(float, -10.0, 10.0) var wind_speed = 0.0 setget set_wind_speed, get_wind_speed
export(Vector3) var wind_direction = Vector3(0, 0, 1) setget set_wind_direction, get_wind_direction
export(int, 0, 100) var render_steps = 25 setget set_steps
export(Vector3) var sun_positon = Vector3(0, 0, 0) setget set_sun_position, get_sun_position
export(float) var time_update_tick = 1
export(float) var step_amount_per_tick = 1

var hour : float = 0.0 
var day : float = 1.0
var month : float = 11.0

const sky_cheap = preload("res://addons/joyeux.dynamic_sky/material/sky_coloured.tres")
const sky_expensive = preload("res://addons/joyeux.dynamic_sky/material/sky_raleigh.tres")

export(float) var precipitation_deviation : float = 1.0
#Edit values in this array for rain probablility
var precipitation_probability = [
	5, #January
	8, #February
	12, #March
	5, #April
	8, #May
	3, #June
	20, #July
	10, #August
	23, #September
	3, #October
	2, #November
	1, #December 
]

func make_it_rain():
	#Based on probablility, make it rain
	var will_rain = rand_range(0, 100) < precipitation_probability[month-1]
	if will_rain:
		#Call the rain function here
		pass
	else:
		#Call the stop rain function here
		pass


func set_wind_direction(v : Vector3) -> void :
	wind_direction = v.normalized()
	if not image:
		return
	else:
		image.material.set("shader_param/WIND_VEC", wind_direction)

func get_wind_direction() -> Vector3:
	return wind_direction

func set_cloud_exposure(ex : float) -> void :
	if not image:
		return
	else:
		image.material.set("shader_param/EXPOSURE", ex)


func set_serialized_time(serialized_time : int) -> void:
	hour = floor(serialized_time / 10000)
	day = floor((serialized_time - hour * 10000) /100)
	month = (serialized_time - hour * 10000 - day * 100) / 1
	print("Time set to: " + str(hour) + ":" + str(day) + ":" + str(month))

func set_sun_position(pos : Vector3) -> void:
	if not cheap_shader:
		pos = Vector3(pos.x, pos.y, 0)
		#pos = Vector3(deg2rad(pos.x), deg2rad(pos.y), 0)
	sun_positon = pos
	if not is_instance_valid(sun) or not is_inside_tree():
		return
	image.material.set("shader_param/direction",pos)
	sun.look_at(Vector3(pos.x, -pos.y, pos.z), Vector3.UP)
	if sun.rotation_degrees.x > -10:
		sun.visible = false
	else:
		sun.visible = true

func map(x, in_min, in_max, out_min, out_max):
	return (x - in_min) * (out_max - out_min) / (in_max - in_min) + out_min

func get_sun_position() -> Vector3:
	return sun_positon

func _ready() -> void:
	yield(get_tree().create_timer(0.1), "timeout")
	randomize()
	set_serialized_time(initial_time_serialized)
	get_tree().create_timer(time_update_tick).connect("timeout", self, "next_time_tick")
	if cheap_shader:
		image.material = sky_cheap
	else:
		image.material = sky_expensive
	retry_draw()
	image.material.set("shader_param/WIND_VEC", wind_direction)

func retry_draw() -> void:
	var Sky : ViewportTexture = ViewportTexture.new()
	Sky.resource_local_to_scene = true
	Sky.viewport_path = $Sky.get_path()
	Sky.flags = Texture.FLAG_FILTER
	environment.background_sky.panorama = Sky
	environment.background_sky.radiance_size = 3

func add_env_to_camera(camera: Camera) -> void:
	var image_texture = sky.get_viewport().get_texture()
	camera.environment = load("res://addons/joyeux.dynamic_sky/material/DynamicEnv.tres") as Environment
	camera.environment.background_sky.set_panorama(image_texture)
	yield(get_tree().create_timer(0.5), "timeout")
	camera.environment.background_sky.radiance_size = 3
	yield(get_tree().create_timer(0.5), "timeout")
	camera.environment.background_sky.radiance_size = 4

#func _process(delta):
#	sun_rays.set_clouds(sky.get_viewport().get_texture())

func set_wind_speed(speed : float) -> void:
	wind_speed = speed
	if not image:
		return
	image.material.set("shader_param/WIND_SPEED",speed)

func get_wind_speed() -> float:
	return wind_speed

func set_sun_color(color: Color) -> void:
	if not image:
		return
	sun.light_color = color
	image.material.set("shader_param/SunColor",color)

func set_dome_color(color : Color) -> void:
	sky_dome_color = color
	if not image:
		return
	image.material.set("shader_param/SkyDomeColor",color)

func get_dome_color() -> Color:
	return image.material.get("shader_param/SkyDomeColor")

func set_horizon_color(color : Color) -> void:
	sky_horizon_color = color
	if not image:
		return
	image.material.set("shader_param/SkyHorizonColor",color)

func get_horizon_color() -> Color:
	if not image:
		return Color(0,0,0,0)
	return image.material.get("shader_param/SkyHorizonColor")

func set_coverage(value : float) -> void:
	if not image:
		return
	image.material.set("shader_param/COVERAGE",float(value))

func get_coverage() -> float:
	if not image:
		return 0.0
	return image.material.get("shader_param/COVERAGE")

func set_absorption(value: float) -> void:
	if not image:
		return
	image.material.set("shader_param/ABSORPTION",float(value))

func set_thickness(value: float) -> void:
	if not image:
		return
	image.material.set("shader_param/THICKNESS",value)

func get_thickness() -> float:
	if not image:
		return 0.0
	return image.material.get("shader_param/THICKNESS")

func set_steps(value: int) -> void:
	if not image:
		return
	render_steps = value
	image.material.set("shader_param/STEPS",value)

#function that updates the sky dome texture with the current time of the day
func next_time_tick() -> void:
	hour += step_amount_per_tick/10
	if hour >= 24:
		hour = 0
		day += 1
		make_it_rain()
	if day > 30:
		day = 1
		month += 1
	if month > 12:
		month = 1
	var new_time = vector_from_time(hour-8, day, month)
	set_sun_position(new_time)
	update_day_night(new_time)
	get_tree().create_timer(time_update_tick).connect("timeout", self, "next_time_tick")
	
func vector_from_time(hour, day, month) -> Vector3:
	var offset = (sin(month/12 * 2 * PI) + cos(day/30 * PI))
	var xy = (hour / 24) * 2 * PI 
	var z = clamp(rad2deg(offset), -60, 60) 
	var vector = Vector3(rad2deg(cos(xy)), rad2deg(sin(xy)), z)
	return vector

func update_day_night(position : Vector3) -> void:
	var dome_increment = floor(57/(skygradient.get_point_count()))
	var dome_idx = floor(position.y/dome_increment)-1
	dome_idx = clamp(dome_idx, 0, skygradient.get_point_count()-1)

	var horizon_increment = floor(57/(horizongradient.get_point_count()))
	var horizon_idx = floor(position.y/horizon_increment)-1
	horizon_idx = clamp(horizon_idx, 0, horizongradient.get_point_count()-1)
	
	var sun_increment = floor(57/(sungradient.get_point_count()))
	var sun_idx = floor(position.y/sun_increment)
	sun_idx = clamp(sun_idx, 0, sungradient.get_point_count()-1)
	
	var absorbtion_increment = floor(57/(absorbtiongradient.get_point_count()))
	var absorbtion_idx = floor(position.y/absorbtion_increment)
	absorbtion_idx = clamp(absorbtion_idx, 0, absorbtiongradient.get_point_count()-1)
	
	
	set_cloud_exposure(clamp(1.0 -absorbtiongradient.get_color(absorbtion_idx).r, 0.12, 0.98))
	
	set_absorption(absorbtiongradient.get_color(absorbtion_idx).r*10)
	set_sun_color(sungradient.get_color(sun_idx))
	
	if cheap_shader:
		set_dome_color(skygradient.get_color(dome_idx))
		set_horizon_color(horizongradient.get_color(horizon_idx))
