class_name Weapon
extends Node

@export var muzzle_location: Node3D
@export var muzzle_flash_effect: GPUParticles3D

var _manager : WeaponManager
var _resource : WeaponResource
var _current_ammo : int = 0
var _reserve_ammo : int = 999 
var _trigger_down : bool = false 
var _firerate_timer : float = 0

func _process(delta: float) -> void:
	handleAutoFire()
	handleFireRate(delta)

func handleFireRate(delta: float) -> void: 
	if _firerate_timer > 0:  
		_firerate_timer = max(0, _firerate_timer - delta)

func handleAutoFire() -> void: 
	if _trigger_down && _resource.auto_fire: onTriggerDown()

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
	var rate_available = _firerate_timer == 0
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
	showMuzzleFlash()
	_firerate_timer = 1.0 / _resource.firerate
	_current_ammo -= 1

func performHitscan() -> void:
	var camera = _manager.camera
	if !camera : return
	var space_state = camera.get_world_3d().direct_space_state
	var from = camera.global_position
	var forward = -camera.global_basis.z
	for i in _resource.pellet_count: 
		var direction = forward + getAccuracyOffset() * camera.global_basis
		if _resource.pellet_count > 1:
			var spread_angle = _resource.pellet_spread_angle
			var spread_x = randf_range(-spread_angle, spread_angle)
			var spread_y = randf_range(-spread_angle, spread_angle)
			direction += Vector3(spread_x, spread_y, 0) * camera.global_basis
		var to = from + direction * _resource.hitscan_range
		var query = PhysicsRayQueryParameters3D.create(from, to, _manager.collision_layers)
		var result = space_state.intersect_ray(query)
		if result : 
			onHitTarget(result.collider, result.position, result.normal)

func spawnProjectile() -> void: 
	if !_resource.projectile: return
	if !_manager.camera : return 
	var camera = _manager.camera
	var projectile = _resource.projectile.instantiate() as Projectile
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = camera.global_position
	var forward = -camera.global_transform.basis.z
	var direction = forward + getAccuracyOffset() * camera.global_basis
	var velocity = direction * _resource.projectile_speed
	projectile.setup(velocity, _manager.collision_layers, _resource.projectile_duration)
	projectile.on_hit_action = onHitTarget

func onHitTarget(target: Node3D, hit_position: Vector3, hit_normal: Vector3) -> void :
	print("Hit: ", target.name, " at ", hit_position)
	spawnImpactMarker(hit_position)

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

func getAccuracyOffset() -> Vector3:
	var accuracy_spread = (100 - _resource.accuracy) / 1000.0
	var accuracy_x = randf_range(-accuracy_spread, accuracy_spread)
	var accuracy_y = randf_range(-accuracy_spread, accuracy_spread)
	return Vector3(accuracy_x, accuracy_y, 0)

func showMuzzleFlash() -> void :
	if muzzle_flash_effect :
		muzzle_flash_effect.emitting = true
