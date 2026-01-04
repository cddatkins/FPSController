class_name  WeaponManager
extends Node3D

@export var player : PlayerController
@export_flags_3d_physics var collision_layers
@export var camera : Camera3D 
@export var allow_shoot : bool = true
@export var current_weapon_resource : WeaponResource

var _fire_pressed : bool = false
var _fire_held : bool = false
var _reload_pressed : bool = false

var _current_weapon : Weapon

func _ready() -> void:
	equipWeapon(current_weapon_resource)

func _process(delta: float) -> void:
	handleInput()
	handleCurrentWeapon()

func handleInput() -> void:
	_fire_pressed = Input.is_action_just_pressed("fire")
	_fire_held = Input.is_action_pressed("fire")
	_reload_pressed = Input.is_action_just_pressed("reload")

func handleCurrentWeapon() -> void:
	if _current_weapon && is_inside_tree() && Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if _fire_pressed && allow_shoot:
			_current_weapon.triggerPressed(true)
		elif !_fire_held:
			_current_weapon.triggerPressed(false)
		if _reload_pressed:
			_current_weapon.reloadPressed()

func equipWeapon(weapon : WeaponResource) -> void:
	if weapon == null: return
	current_weapon_resource = weapon
	createWeapon()
	_current_weapon.onEquip(self)

func createWeapon() -> void :
	if current_weapon_resource == null || current_weapon_resource.weapon_scn == null: return
	if _current_weapon: 
		_current_weapon.queue_free()
	_current_weapon = current_weapon_resource.weapon_scn.instantiate() as Weapon
	camera.add_child(_current_weapon)
	_current_weapon.position = current_weapon_resource.weapon_position
	_current_weapon.scale = current_weapon_resource.weapon_scale
	_current_weapon.rotation_degrees = current_weapon_resource.weapon_rotation
