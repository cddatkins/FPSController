class_name Weapon
extends Node

var _manager : WeaponManager
var _resource : WeaponResource
var _current_ammo : int = 0
var _reserve_ammo : int = 999 
var _last_fire_time : float = -INF
var _trigger_down : bool = false 

func _process(delta: float) -> void:
	if _resource.auto_fire: onTriggerDown()

func onEquip(manager: WeaponManager) -> void:
	_manager = manager
	_resource = manager.current_weapon_resource
	_current_ammo = _resource.clip_size
	_reserve_ammo = _resource.max_reserve_ammo

func onUnequip() -> void:
	_manager = null

func triggerPressed(enabled: bool) -> void: 
	if _trigger_down != enabled:
		_trigger_down = enabled
		if _trigger_down:
			onTriggerDown()
		else:
			onTriggerUp()

func onTriggerDown() -> void: 
	if canFire():
		fire()
	elif _current_ammo == 0:
		reloadPressed()
	
func onTriggerUp() -> void:
	pass
	
func canFire() -> bool: 
	var rate_available = Time.get_ticks_msec() - _last_fire_time >= _resource.fire_rate_ms
	var ammo_available = _current_ammo > 0
	return rate_available && ammo_available
	
func getReloadAmount() -> int:
	var clip_amount = _resource.clip_size - _current_ammo
	var amount = min(clip_amount, _reserve_ammo)
	return amount

func fire():
	if _resource.is_hitscan: 
		performHitscan()
	else:
		spawnProjectile()
	_last_fire_time = Time.get_ticks_msec()
	_current_ammo -= 1

func performHitscan() -> void:
	var camera = _manager.camera
	if !camera : return
	var space_state = camera.get_world_3d().direct_space_state
	var from = camera.global_position
	var forward = -camera.global_basis.z
	var to = from + forward * _resource.hitscan_range
	var query = PhysicsRayQueryParameters3D.create(from, to, _manager.collision_layers)
	var result = space_state.intersect_ray(query)
	if result : 
		print("Hit: ", result.collider.name, " at ", result.position)
		spawnImpactMarker(result.position)

func spawnImpactMarker(position: Vector3) -> void : 
	var marker = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3.ONE * 0.1
	marker.mesh = box
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.RED
	marker.set_surface_override_material(0, material)
	get_tree().current_scene.add_child(marker)
	marker.global_position = position
	get_tree().create_timer(2.0).timeout.connect(marker.queue_free)
	

func spawnProjectile() -> void: 
	if !_resource.projectile: return
	if !_manager.camera : return 
	var camera = _manager.camera
	var projectile = _resource.projectile.instantiate() as Projectile
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = camera.global_position
	var forward = -camera.global_transform.basis.z
	var velocity = forward * _resource.projectile_speed
	#projectile.global_transform.basis = Basis.looking_at(forward, Vector3.UP)
	projectile.setup(velocity, _resource.damage, _manager.collision_layers, _resource.projectile_duration)

func reloadPressed() -> void: 
	#play reload animation & once finished call reload
	reload()

func reload() -> void:
	var reload_amount = getReloadAmount()
	var clip_size = _resource.clip_size
	if reload_amount < 0: return
	elif clip_size == INF || _current_ammo == INF:
		_current_ammo = clip_size
	else:
		_current_ammo += reload_amount
		_reserve_ammo -= reload_amount
