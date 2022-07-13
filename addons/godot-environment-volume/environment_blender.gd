# Copyright © 2022 Josh Jones - MIT License
# See `LICENSE.md` included in the source distribution for details.
# Contains the central manager for handling the environment updates for all affected cameras.
tool
extends Node


# Information about cameras we are affecting so we can restore them later.
var affected_cameras := {};

# Set of EnvironmentVolumes that we are tracking.
var volumes := [];
var dynamic_default = null


func _process(delta: float) -> void:
	# For each camera we are tracking
	for _camera in _find_cameras():
		var camera: Camera = _camera;
		if !camera:
			continue;
		
		# Figure out which volumes the camera is within
		var intersecting_volumes := [];
		for _volume in volumes:
			var volume = _volume;
			var bounds: AABB = volume.global_transform.xform(volume.bounds);
			
			if bounds.has_point(camera.global_transform.origin):
				intersecting_volumes.append(volume);
		
		# If this camera isn't currently being affected, and it intersects a volume, save its existing settings.
		if !affected_cameras.has(camera) && !intersecting_volumes.empty():
			affected_cameras[camera] = camera.environment;
		
		# Update the environment for cameras that are currently being affected.
		for _volume in intersecting_volumes:
			var volume = _volume;
			
			# TODO: Sort volumes by priority if they overlap?
			# TODO: Blend between volumes that overlap?
			camera.environment = volume.environment;
		
		# Restore cameras that just left all of our volumes back to their original settings.
		if affected_cameras.has(camera) && intersecting_volumes.empty():
			var original_env: Environment = affected_cameras[camera];
			camera.environment = original_env;
			affected_cameras.erase(camera);


# Register a new environment volume for this manager to track.
func register_environment_volume(volume: Node) -> void:
	if not volume.has_method("is_volume_environment"):
		return;
	if volumes.has(volume):
		push_warning("EnvironmentVolume %s already registered." % volume);
		return;
	
	volumes.append(volume);


# Remove an environment volume that was previously being tracked.
func unregister_environment_volume(volume: Node) -> void:
	if not volume.has_method("is_volume_environment"):
		return;
	if !volumes.has(volume):
		push_warning("EnvironmentVolume %s is not registered, cannot remove." % volume);
		return;
	
	volumes.erase(volume);


func _find_cameras() -> Array:
	# Pull all cameras the user has marked to be affected
	var cameras := get_tree().get_nodes_in_group("EnvironmentVolumeCameras");
	
	# Fallback to grabbing the active camera in the root viewport.
	if cameras.empty():
		return [ get_viewport().get_camera() ];
	
	return cameras;

func register_main_env(env : WorldEnvironment) -> void:
	dynamic_default = env

func add_default_env(cam : Camera) -> void:
	dynamic_default.add_env_to_camera(cam)
