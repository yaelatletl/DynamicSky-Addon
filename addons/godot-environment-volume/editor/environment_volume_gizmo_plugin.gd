# Copyright © 2022 Josh Jones - MIT License
# See `LICENSE.md` included in the source distribution for details.
# Contains the editor gizmo for the environment region
tool
extends EditorSpatialGizmoPlugin

# Used to allow undo/redo of changes made via gizmo
var undo_redo: UndoRedo;


func _init(p_undo_redo: UndoRedo) -> void:
	undo_redo = p_undo_redo;
	
	var gizmo_color := Color(0.5, 0.6, 1.0);
	create_material("material", gizmo_color);
	
	gizmo_color.a = 0.1;
	create_material("material_internal", gizmo_color);
	
	# TODO: create_icon_material
	create_handle_material("handles");


func has_gizmo(spatial: Spatial) -> bool:
	return spatial is EnvironmentVolume;


func get_name() -> String:
	return "EnvironmentVolume";


func redraw(gizmo: EditorSpatialGizmo) -> void:
	var volume := gizmo.get_spatial_node() as EnvironmentVolume;
	var material := get_material("material", gizmo);
	var material_internal := get_material("material_internal", gizmo);
	var material_handles := get_material("handles", gizmo);
	
	gizmo.clear();
	
	var lines := PoolVector3Array();
	var aabb := volume.bounds;
	
	for i in range(0, 12):
		var pair := _aabb_get_edge(aabb, i);
		lines.append_array(pair);
	
	gizmo.add_lines(lines, material);
	
	var handles := PoolVector3Array();
	for i in range(0, 3):
		var handle_pos := Vector3();
		handle_pos[i] = aabb.position[i] + aabb.size[i];
		handles.append(handle_pos);
	
	gizmo.add_handles(handles, material_handles);


func get_handle_name(gizmo: EditorSpatialGizmo, index: int) -> String:
	match index:
		0:
			return "Extents X";
		1:
			return "Extents Y";
		2:
			return "Extents Z";
	
	return "";


func get_handle_value(gizmo: EditorSpatialGizmo, index: int):
	var volume := gizmo.get_spatial_node() as EnvironmentVolume;
	return volume.extents;


func set_handle(gizmo: EditorSpatialGizmo, index: int, camera: Camera, point: Vector2) -> void:
	var volume := gizmo.get_spatial_node() as EnvironmentVolume;
	
	var gt := volume.get_global_transform();
	var gi := gt.affine_inverse();
	
	var extents = volume.extents;
	
	var ray_from = camera.project_ray_origin(point);
	var ray_dir = camera.project_ray_normal(point);
	
	var sg = [ gi.xform(ray_from), gi.xform(ray_from + ray_dir * camera.far) ];
	
	var axis = Vector3();
	axis[index] = 1.0;
	
	var r := Geometry.get_closest_points_between_segments(Vector3(), axis * camera.far, sg[0], sg[1]);
	var d := r[0][index];
	
	if (d < 0.001):
		d = 0.001;
	
	extents[index] = d;
	volume.extents = extents;


func commit_handle(gizmo: EditorSpatialGizmo, index: int, restore, cancel: bool = false) -> void:
	var volume := gizmo.get_spatial_node() as EnvironmentVolume;
	
	if cancel:
		volume.extents = restore;
		return;
	
	undo_redo.create_action("Change Extents");
	undo_redo.add_do_property(volume, "extents", volume.extents);
	undo_redo.add_undo_property(volume, "extents", restore);
	undo_redo.commit_action();


# Taken from core/math/aabb.cpp
func _aabb_get_edge(aabb: AABB, var edge: int) -> Array:
	assert(edge >= 0);
	assert(edge < 12);
	
	var position := aabb.position;
	var size := aabb.size;
	
	match edge:
		0:
			return [
				Vector3(position.x + size.x, position.y, position.z),
				Vector3(position.x, position.y, position.z)
			];
		1:
			return [
				Vector3(position.x + size.x, position.y, position.z + size.z),
				Vector3(position.x + size.x, position.y, position.z)
			];
		2:
			return [
				Vector3(position.x, position.y, position.z + size.z),
				Vector3(position.x + size.x, position.y, position.z + size.z)
			];
		3:
			return [
				Vector3(position.x, position.y, position.z),
				Vector3(position.x, position.y, position.z + size.z)
			];
		4:
			return [
				Vector3(position.x, position.y + size.y, position.z),
				Vector3(position.x + size.x, position.y + size.y, position.z)
			];
		5:
			return [
				Vector3(position.x + size.x, position.y + size.y, position.z),
				Vector3(position.x + size.x, position.y + size.y, position.z + size.z)
			];
		6:
			return [
				Vector3(position.x + size.x, position.y + size.y, position.z + size.z),
				Vector3(position.x, position.y + size.y, position.z + size.z)
			];
		7:
			return [
				Vector3(position.x, position.y + size.y, position.z + size.z),
				Vector3(position.x, position.y + size.y, position.z)
			];
		8:
			return [
				Vector3(position.x, position.y, position.z + size.z),
				Vector3(position.x, position.y + size.y, position.z + size.z)
			];
		9:
			return [
				Vector3(position.x, position.y, position.z),
				Vector3(position.x, position.y + size.y, position.z)
			];
		10:
			return [
				Vector3(position.x + size.x, position.y, position.z),
				Vector3(position.x + size.x, position.y + size.y, position.z)
			];
		11:
			return [
				Vector3(position.x + size.x, position.y, position.z + size.z),
				Vector3(position.x + size.x, position.y + size.y, position.z + size.z)
			];
	
	return [];
