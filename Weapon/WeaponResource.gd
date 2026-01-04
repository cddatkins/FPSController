class_name WeaponResource
extends Resource
@export var weapon_name : String = "Weapon"
@export var weapon_scn : PackedScene 
@export var weapon_position : Vector3 
@export var weapon_rotation : Vector3
@export var weapon_scale : Vector3 = Vector3.ONE

@export_category("Weapon Logic")
@export var damage : int = 1
@export var auto_fire : bool = false
@export var firerate : float = 2
@export var clip_size : int =  8
@export var max_reserve_ammo : int = 999
@export_range(0, 100) var accuracy : float = 100
@export var is_hitscan : bool = true
@export var hitscan_range : float = 30.0
@export var projectile : PackedScene
@export var projectile_speed : float = 20.0
@export var projectile_duration: float = -1
@export var pellet_count : int = 1
@export var pellet_spread_angle : float = 0

@export_category("Weapon Audio")
@export var shoot_sound : AudioStream
@export var reload_sound : AudioStream
@export var equip_sound : AudioStream

@export_category("Weapon Animation")
@export var idle_anim: String
@export var shoot_anim : String
@export var reload_anim : String
@export var equip_anim : String
