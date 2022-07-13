# Copyright © 2022 Josh Jones and contributors - MIT License
# See `LICENSE.md` included in the source distribution for details.
tool
extends EditorPlugin


var EnvironmentVolumeGizmoPlugin = load("editor/environment_volume_gizmo_plugin.gd")


var undo_redo: UndoRedo;
var gizmo_plugin;


func _enter_tree() -> void:
	undo_redo = get_undo_redo();
	gizmo_plugin = EnvironmentVolumeGizmoPlugin.new(undo_redo);
	
	add_autoload_singleton("EnvironmentBlender", "res://addons/godot-environment-volume/environment_blender.gd");
	add_spatial_gizmo_plugin(gizmo_plugin);


func _exit_tree() -> void:
	remove_spatial_gizmo_plugin(gizmo_plugin);
	remove_autoload_singleton("EnvironmentBlender");
