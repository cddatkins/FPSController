class_name  WeaponController
extends Node3D

@export var player : PlayerController
@export var camera : Camera3D 

@export var current_weapon : Weapon

var fire_pressed : bool = false
var fire_held : bool = false
var reload_pressed : bool = false


var _current_weapon_model : Node3D 
var _current_ammo : int = 0

var _last_fire_time : float = -INF

func _ready() -> void:
	equipWeapon(current_weapon)

func _process(delta: float) -> void:
	handleInput()

func _physics_process(delta: float) -> void:
	pass	

func handleInput() -> void :
	fire_pressed = Input.is_action_just_pressed("fire")
	fire_held = Input.is_action_pressed("fire")
	reload_pressed = Input.is_action_just_pressed("reload")
func equipWeapon(weapon : Weapon) -> void :
	if weapon == null || current_weapon == weapon: return
	current_weapon = weapon
	createWeaponModel()
	_current_ammo = current_weapon.max_ammo

func createWeaponModel() -> void :
	if current_weapon == null || current_weapon.weapon_model == null: return
	if _current_weapon_model: 
		_current_weapon_model.queue_free()
	_current_weapon_model = current_weapon.weapon_model.instantiate()
	camera.add_child(_current_weapon_model)
	_current_weapon_model.position = current_weapon.weapon_position
	_current_weapon_model.scale = current_weapon.weapon_scale
	_current_weapon_model.rotation_degrees = current_weapon.weapon_rotation

func canFire() -> bool : 
	return _current_ammo > 0
