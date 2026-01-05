class_name PlayerHUD
extends Control

@export var player: PlayerController
@export var weapon_manager: WeaponManager

@onready var health_bar : Control = %HealthBar
@onready var ammo_bar : Control = %AmmoBar

const FILLED_PCT_PPROPERTY : String = "filled_percent"

func _process(delta: float) -> void:
	updateHealthBar()
	updateAmmoBar()
	
func updateHealthBar() -> void: 
	var health_pct = 1.0
	if player : 
		health_pct = player.health / (player.max_health as float)
	health_bar.material.set_shader_parameter(FILLED_PCT_PPROPERTY, health_pct)

func updateAmmoBar() -> void:
	var ammo_pct = 0.5
	if weapon_manager: 
		ammo_pct = weapon_manager.getWeaponAmmoPct()
	ammo_bar.material.set_shader_parameter(FILLED_PCT_PPROPERTY, ammo_pct)
