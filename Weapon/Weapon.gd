class_name Weapon
extends Resource

@export var weapon_name : String = "Weapon"
@export var weapon_model : PackedScene 
@export var weapon_position : Vector3 
@export var weapon_rotation : Vector3
@export var weapon_scale : Vector3 = Vector3.ONE
@export var damage : int = 1
@export var auto_fire : bool = false
@export var fire_rate : float = 0.2
@export var max_ammo : int = 100
@export var clip_size : int =  8
@export var is_hitscan : bool = true
@export var hitscan_range : float = 30.0
@export var projectile : PackedScene
@export var projectile_speed : float = 20.0
