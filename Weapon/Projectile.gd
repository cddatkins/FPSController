class_name Projectile
extends Area3D

var proj_velocity : Vector3 
var proj_damage : int
var proj_collision_mask: int
	
func _physics_process(delta: float) -> void:
	var space_state = get_world_3d().direct_space_state
	var start_pos = global_position
	var end_pos = global_position + proj_velocity * delta
	var query = PhysicsRayQueryParameters3D.create(start_pos, end_pos)
	var result = space_state.intersect_ray(query)
	if result:
		global_position = result.position
		onBodyEntered(result.collider, result.position, result.normal)
		return
	global_position = end_pos

func setup(vel: Vector3, dmg: int, col_mask: int, duration: float = 0) -> void: 
	proj_velocity = vel
	proj_damage = dmg
	proj_collision_mask = col_mask
	collision_mask = col_mask
	if duration > 0 : 
		get_tree().create_timer(duration).timeout.connect(queue_free)
	global_basis = Basis.looking_at(proj_velocity, Vector3.UP)

func onBodyEntered(body: Node3D, hit_point: Vector3, hit_normal: Vector3) -> void: 
	spawnImpactMarker(hit_point)
	print("Hit: ", body.name, " at ", hit_point)
	queue_free()

func spawnImpactMarker(spwn_position: Vector3) -> void : 
	var marker = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3.ONE * 0.1
	marker.mesh = box
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.RED
	marker.set_surface_override_material(0, material)
	get_tree().current_scene.add_child(marker)
	marker.global_position = spwn_position
	get_tree().create_timer(2.0).timeout.connect(marker.queue_free)
