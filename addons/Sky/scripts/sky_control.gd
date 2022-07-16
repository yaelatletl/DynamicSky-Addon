extends Node

var first_frame = 1

var base_night_sky_rotation = Basis(Vector3(1.0, 1.0, 1.0).normalized(), 1.2)
var horizontal_angle = 0.0 # Shifts where the sun rises and sets

#	How long to wait to update the environment (in frames) and iterator
export(float,1,120) var env_update_increment = 120
var eincrement = 0
#	How long to wait to update the sky (in frames) and iterator
export(float,1,120) var sky_update_increment = 30
var sincrement = 0
#	How long an ingame day should be (in minutes)
export(float,1,60) var day_speed = 24
#	Time of day (in hours)
export(float,0,24) var time_day = 6.0 setget set_time_day, get_time_day
#	Hours of daylight (This does not change how long the sun stays in the sky at the moment, just when the sky gets dark or light.)
export(float,9,15) var day_length = 14.0

# Delta iterator to make sure the day length is close to day_speed
var elapsed_time = 0.0;

signal time_changed

onready var skybox=get_node("./Skybox")
onready var sun=get_node("./Sun")

func set_time_day(time):
	time_day = time
	
func get_time_day():
	return time_day

func _set_sky_rotation():
	var rot = Basis(Vector3(0.0, 1.0, 0.0), deg2rad(horizontal_angle)) * Basis(Vector3(1.0, 0.0, 0.0), time_day * PI / 12.0)
	rot = rot * base_night_sky_rotation;
	skybox.set_rotate_night_sky(rot)

func _ready():
	
	# These will flash errors if the paths are incorrect
	assert(skybox!=null)
	assert(sun!=null)
	
	# init our time of day
	print("One ingame day will take ", day_speed, " realtime minutes. Time advances ", (env_update_increment/60)*(24/day_speed), " ingame minutes every ", env_update_increment/60, " realtime seconds, roughly.")
	skybox.set_time_of_day(time_day, day_length, sun, deg2rad(horizontal_angle))
	
	# rotate our night sky so our milkyway isn't on our horizon
	_set_sky_rotation()

#	This script updates the current ingame time and tells the skybox to update the environment incrementally
func _process(delta):
	
	#This isn't super elegant but the environment lighting takes a couple frames to be able to use the skybox properly
	if (first_frame > 0):
		first_frame -= 1
	elif (first_frame == 0):
		skybox.copy_to_environment(get_viewport().get_camera().environment)
		first_frame -= 1
	
	time_day += ((0.4*delta)/day_speed)
	# If it's 24:00 make it 0:00 instead
	if time_day>24.0:
		time_day -= 24.0
		# This is just a check to make sure that a day does indeed last day_speed minutes.
		print( str(floor(elapsed_time/60.0)) + ":" + str(fmod(elapsed_time, 60.0)))
		elapsed_time = 0
	
	elapsed_time += delta;
	
	# Every sincrement frames the sky and sun will be updated
	sincrement += 1
	if sincrement >= sky_update_increment:
		sincrement = 0
		skybox.set_time_of_day(time_day, day_length, sun, deg2rad(horizontal_angle))
		emit_signal("time_changed")
	
	# Every eincrement frames the environment will be updated
	# This is much more intensive than the sky update
	eincrement += 1
	if eincrement >= env_update_increment:
		eincrement = 0
		skybox.copy_to_environment(get_viewport().get_camera().environment)

# A GUI Spinbox to allow manual changing of time
func _on_Time_Of_Day_Box_value_changed(value):
	time_day = value
	skybox.set_time_of_day(value, day_length, sun, deg2rad(horizontal_angle))
	_set_sky_rotation()
