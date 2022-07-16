extends Viewport

# Sky Script & Shader from Bastiaan Olij
# Cloud Script & Shader from Danil S
#Edited together by Leo Gallatin

signal sky_updated

# keeps track of elapsed delta time for clouds
var iTime=0.0

export var sun_position = Vector3(0.0, 1.0, 0.0) setget set_sun_position, get_sun_position
export (Texture) var night_sky = null setget set_night_sky, get_night_sky
export (Basis) var rotate_night_sky = Basis() setget set_rotate_night_sky, get_rotate_night_sky

onready var smat = $Skytexture.material

func set_sun_position(new_position):
	sun_position = new_position
	if smat:
		smat.set_shader_param("sun_pos", sun_position)

func get_sun_position():
	return sun_position

func set_night_sky(new_texture):
	night_sky = new_texture
	if smat:
		smat.set_shader_param("night_sky", night_sky)

func get_night_sky():
	return night_sky

func set_rotate_night_sky(new_basis):
	rotate_night_sky = new_basis
	if smat:
		# set the inverse of our rotation to get the right effect
		smat.set_shader_param("rotate_night_sky", rotate_night_sky.inverse())

func get_rotate_night_sky():
	return rotate_night_sky

#===================================================================================

func set_time_of_day(hours, day_length, directional_light, horizontal_angle = 0.0):
	var sun_position = Vector3(0.0, -100.0, 0.0)
	sun_position = sun_position.rotated(Vector3(1.0, 0.0, 0.0), hours * PI / 12.0)
	sun_position = sun_position.rotated(Vector3(0.0, 1.0, 0.0), horizontal_angle)
	
	if directional_light:
		var t = directional_light.transform
		t.origin = sun_position
		directional_light.transform = t.looking_at(Vector3(0.0, 0.0, 0.0), Vector3(0.0, 1.0, 0.0))
		# I have left old functions to determine the brightness of the world compared to the time of day
		# Sinusodial cubed seemed to me to match actual daylight patterns pretty well.
		var light_amount = 0
		#var light_amount = 1.0 - clamp(abs(hours - 12.0) / 6.0, 0.0, 1.0) #linear
		#var light_amount = clamp( - ((2 - (hours/6) ) * (2 - (hours/6) )) + 1 , 0.0, 1.0) #parabola
		#var light_amount = clamp( ( (.66) * sin( (hours/3.0) + 3.85 ) ) + (.33), 0.0, 1.0) #sinusodial
		#if (hours>=6.0 && hours <=18.0):
		#	light_amount = clamp( pow(sin((hours/4)+1.713),2.0) ,0.0,1.9) #sinusodial squared
		light_amount = clamp( pow( 2 * cos( PI/day_length * ( hours-12 ) ), 3.0), 0.0, 1.0) #clamped sinusodial cubed
		directional_light.light_energy = light_amount
		#If you would like the clouds to be brighter at night, add more to the light amount in this line
		smat.set_shader_param("EXPOSURE", light_amount+0.01)
	
	# and update our sky
	set_sun_position(sun_position)

func copy_to_environment(environment):
	#Feed the camera's sky back to it so it changes the environment colors properly
	environment.background_sky.set_panorama(get_texture())

func _ready():
	assert(smat!=null)
	# re-assign so our material gets updated, this will also trigger an update - Bastian Olij
	set_night_sky(night_sky)
	set_rotate_night_sky(rotate_night_sky)
	set_sun_position(sun_position)

func _process(delta):	
	iTime+=delta
	smat.set("shader_param/iTime",iTime)
