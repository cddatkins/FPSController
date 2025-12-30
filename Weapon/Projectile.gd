class_name Projectile
extends Area3D

var proj_velocity : Vector3 
var proj_damage : int
var proj_collision_mask: int
var on_hit_action: Callable
	
func _physics_process(delta: float) -> void:
	var space_state = get_world_3d().direct_space_state
	var start_pos = global_position
	var end_pos = global_position + proj_velocity * delta
	var query = PhysicsRayQueryParameters3D.create(start_pos, end_pos)
	var result = space_state.intersect_ray(query)
	if result:
		global_position = result.position
		onCollision(result.collider, result.position, result.normal)
		return
	global_position = end_pos

func setup(vel: Vector3, col_mask: int, duration: float = 0) -> void: 
	proj_velocity = vel
	proj_collision_mask = col_mask
	collision_mask = col_mask
	if duration > 0 : 
		get_tree().create_timer(duration).timeout.connect(queue_free)
	global_basis = Basis.looking_at(proj_velocity, Vector3.UP)

func onCollision(body: Node3D, hit_point: Vector3, hit_normal: Vector3) -> void: 
	if on_hit_action.is_valid():
		on_hit_action.call(body, hit_point, hit_normal)
	queue_free()
