extends CharacterBody3D

@export var model : Node3D
@export var collision : CollisionShape3D
@export var collision_capsule_size : float = 2
@export var downward_stair_detector : RayCast3D
@export var upward_stair_detector : RayCast3D
@export var head_stand_origin : Vector3 = Vector3(0, 1.75, 0)
@export var head_crouch_origin : Vector3 = Vector3(0, 1.07, 0)
@export var head_crouch_smooth_speed : float = 7


@export_category("Camera Control")
@export var camera_head : Node3D
@export var camera_pivot : Node3D
@export var camera : Camera3D
@export var mouse_look_sensitivity : float = 0.06
@export var controller_look_sensitivity : float = 0.05
@export var controller_look_lerp_speed : float = 5
@export var camera_min_pitch:= -90
@export var camera_max_pitch:= 60
@export var camera_vert_invert:bool = false
@export var camera_hori_invert:bool = false


@export_category("Movement")
@export var walk_speed : float = 7.0
@export var run_speed : float = 8.5
@export var gravity : float = 12
@export var jump_force : float = 8
@export var ground_accel : float = 14.0
@export var ground_deccel: float = 10.0
@export var ground_friction: float = 6.0
@export var air_max_speed: float = 0.85
@export var air_accel: float = 800.0
@export var air_move_speed: float = 500.0

var _move_input:= Vector2.ZERO
var _run_pressed := false
var _crouch_pressed := false
var _camera_input_direction := Vector2.ZERO
var _controller_camera_input := Vector2.ZERO
var _current_controller_look := Vector2.ZERO
var _camera_max_pitch_rad = deg_to_rad(camera_max_pitch)
var _camera_min_pitch_rad = deg_to_rad(camera_min_pitch)
var _camera_look_direction := Vector3.ZERO
var _saved_camera_global_pos = null

const CROUCH_TRANSLATE : float = 0.7
var _is_crouched : bool = false
var _crouch_jump_add : float = CROUCH_TRANSLATE * 0.9

const MAX_STEP_HEIGHT := 0.5
var _snapped_to_stair_last_frame := false
var _last_frame_on_floor := -INF

const HEADBOB_FREQUENCY : float = 2.4
const HEADBOB_OFFSET : float = 0.06
var _headbob_time : float = 0

var _noclip_enabled : bool = false
const NOCLIP_SPEED_DEFAULT : float = 3
var _noclip_speed_multi : = NOCLIP_SPEED_DEFAULT

func _ready() -> void:
	setModelVisibility()
	collision.shape.height = collision_capsule_size

func _unhandled_input(event: InputEvent) -> void:
	unhandledCameraInput(event)
	handleNoClipSpeedInput(event)

func _process(delta: float) -> void:
	handleInput()

func _physics_process(delta: float) -> void:
	handleFloorFrameCheck()
	handleCameraMovement(delta)
	if handleNoClip(delta): return
	if is_on_floor() || _snapped_to_stair_last_frame:
		handleGroundMovement(delta)
	else :
		handleAirMovement(delta)
	if snapUpToStair(delta) : return
	move_and_slide()
	snapDownToStair()
	slideCameraSmoothBackToOrigin(delta)

func setModelVisibility() -> void:
	for child in model.find_children("*", "VisualInstance3D"):
		child.set_layer_mask_value(1, false)
		child.set_layer_mask_value(2, true)

func handleInput() -> void:
	_move_input = Input.get_vector("left", "right", "up", "down").normalized()
	_run_pressed = Input.is_action_pressed("run")
	_crouch_pressed = Input.is_action_pressed("crouch")
	_controller_camera_input = Input.get_vector("look_left", "look_right", "look_up", "look_down")

func unhandledCameraInput(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	elif Input.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var is_camera_motion := event is InputEventMouseMotion && Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
	if is_camera_motion: 
		_camera_input_direction = event.screen_relative * mouse_look_sensitivity

func handleGravity(delta: float) -> void:
	self.velocity.y += -gravity * delta

func handleFloorFrameCheck() -> void:
	if is_on_floor() : _last_frame_on_floor = Engine.get_physics_frames()

func handleAirMovement(delta: float) -> void:
	handleGravity(delta)
	handleAirControlMovement(delta)
	handleAirSurfMovement(delta)

func handleAirControlMovement(delta: float) -> void:
	var move_direction = self.basis * Vector3(_move_input.x, 0, _move_input.y)
	var speed_alignment = self.velocity.dot(move_direction)
	var capped_speed = min((move_direction * air_move_speed).length(), air_max_speed)
	var add_speed_till_cap = capped_speed - speed_alignment
	if add_speed_till_cap > 0:
		var accel_speed = air_accel * air_move_speed * delta
		accel_speed = min(accel_speed, add_speed_till_cap)
		self.velocity += accel_speed * move_direction

func handleAirSurfMovement(delta: float) -> void:
	var wall_normal = get_wall_normal()
	if is_on_wall():
		if isSurfaceTooSteep(wall_normal):
			self.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
		else:
			self.motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
		clipVelocity(wall_normal, 1)

func handleGroundMovement(delta: float) -> void:
	handleCrouch(delta)
	handleGroundControlMovement(delta)
	handleGroundFriction(delta)
	handleHeadBobEffect(delta)
	handleJump()

func handleGroundControlMovement(delta: float) -> void:
	var move_direction = self.basis * Vector3(_move_input.x, 0, _move_input.y)
	var move_speed = getMovementSpeed()
	var speed_alignment = self.velocity.dot(move_direction)
	var add_speed_till_cap = move_speed - speed_alignment
	if add_speed_till_cap > 0:
		var accel_speed = ground_accel * move_speed * delta
		accel_speed = min(accel_speed, add_speed_till_cap)
		self.velocity += accel_speed * move_direction

func handleGroundFriction(delta: float) -> void :
	var velocity_mag = self.velocity.length()
	var control = max(velocity_mag, ground_deccel)
	var drop = control * ground_friction * delta
	var new_speed = max(velocity_mag - drop, 0)
	if velocity_mag > 0:
		new_speed /= velocity_mag
	self.velocity *= new_speed

func handleCameraMovement(delta: float) -> void:
	handleMouseCameraMovement()
	handleControllerCameraMovement(delta)

func handleMouseCameraMovement() -> void:
	setMovementRotation(_camera_input_direction, mouse_look_sensitivity)
	_camera_input_direction = Vector2.ZERO

func handleControllerCameraMovement(delta: float) -> void :
	if _controller_camera_input.length() < _current_controller_look.length():
		_current_controller_look = _camera_input_direction
	else :
		_current_controller_look = _current_controller_look.lerp(_controller_camera_input, controller_look_lerp_speed * delta)
	setMovementRotation(_current_controller_look, controller_look_sensitivity)

func setMovementRotation(rotation_direction: Vector2, sensitivity: float) -> void :
	var camera_hori_multi = -1.0 if camera_hori_invert else 1.0
	rotate_y(-rotation_direction.x * sensitivity * camera_hori_multi)
	var camera_vert_multi = -1.0 if camera_vert_invert else 1.0
	camera.rotate_x(-rotation_direction.y * sensitivity * camera_vert_multi)
	camera.rotation.x = clamp(camera.rotation.x, _camera_min_pitch_rad, _camera_max_pitch_rad)

func handleJump() -> void: 
	if Input.is_action_just_pressed("jump"):
		self.velocity.y = jump_force

func handleCrouch(delta : float) -> void : 
	if _crouch_pressed : 
		_is_crouched = true
	elif _is_crouched && !self.test_move(self.transform, CROUCH_TRANSLATE * Vector3.UP):
		_is_crouched = false
	var head_position = head_crouch_origin if _is_crouched else head_stand_origin
	camera_head.position = camera_head.position.lerp(head_position, head_crouch_smooth_speed * delta)
	collision.shape.height = collision_capsule_size - CROUCH_TRANSLATE if _is_crouched else collision_capsule_size
	collision.position.y = collision.shape.height * 0.5

func handleNoClip(delta: float) -> bool: 
	var move_direction = Vector3(-_move_input.x, 0, _move_input.y)
	_camera_look_direction = camera.global_transform.basis * move_direction
	if Input.is_action_pressed("no_clip") and OS.has_feature("debug"):
		_noclip_enabled = !_noclip_enabled
		_noclip_speed_multi = NOCLIP_SPEED_DEFAULT
	collision.disabled = _noclip_enabled
	if !_noclip_enabled: return false
	var speed = getMovementSpeed() * _noclip_speed_multi
	if _run_pressed: speed *= 3.0
	self.velocity = _camera_look_direction * speed
	self.global_position += self.velocity * delta
	move_and_slide()
	return true

func handleNoClipSpeedInput(event: InputEvent) -> void:
	if event is InputEventMouseButton && event.is_pressed():
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_noclip_speed_multi = min(100.0, _noclip_speed_multi * 1.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_noclip_speed_multi = max(0.1, _noclip_speed_multi * 0.9)

func getMovementSpeed() -> float:
	if _is_crouched: return walk_speed * 0.75
	return run_speed if _run_pressed else walk_speed 

func handleHeadBobEffect(delta: float) -> void:
	_headbob_time += delta * self.velocity.length()
	var head_xpos = cos(_headbob_time * HEADBOB_FREQUENCY * 0.5) * HEADBOB_OFFSET
	var head_ypos = sin(_headbob_time * HEADBOB_FREQUENCY) * HEADBOB_OFFSET
	camera.transform.origin = Vector3(head_xpos, head_ypos, 0)

func clipVelocity(normal: Vector3, overbounce: float) -> void:
	var backoff := self.velocity.dot(normal) * overbounce
	if backoff >= 0: return
	var change = normal * backoff
	self.velocity -= change
	var adjust := self.velocity.dot(normal)
	if adjust < 0:
		self.velocity -= adjust * normal

func isSurfaceTooSteep(normal: Vector3) -> bool:
	return normal.angle_to(Vector3.UP) > self.floor_max_angle

func runBodyTestMotion(from: Transform3D, motion: Vector3, result = null) -> bool :
	if !result : result = PhysicsTestMotionResult3D.new()
	var params = PhysicsTestMotionParameters3D.new()
	params.from = from
	params.motion = motion
	return PhysicsServer3D.body_test_motion(self.get_rid(), params, result)

func snapDownToStair() -> void:
	var did_snap := false
	var was_on_floor_last_frame := Engine.get_physics_frames() - _last_frame_on_floor == 1
	var is_floor_below = downward_stair_detector.is_colliding() && !isSurfaceTooSteep(downward_stair_detector.get_collision_normal())
	var snapped_check = was_on_floor_last_frame || _snapped_to_stair_last_frame
	if !is_on_floor() && velocity.y <= 0 && snapped_check && is_floor_below: 
		var body_test_result := PhysicsTestMotionResult3D.new()
		if runBodyTestMotion(self.global_transform, Vector3(0, -MAX_STEP_HEIGHT, 0), body_test_result):
			saveCameraPosForSmoothing()
			var translate_y = body_test_result.get_travel().y
			self.position.y += translate_y
			apply_floor_snap()
			did_snap = false
	_snapped_to_stair_last_frame = did_snap

func snapUpToStair(delta : float) -> bool:
	if !is_on_floor() && !_snapped_to_stair_last_frame : return false
	if self.velocity.y > 0  || (self.velocity * Vector3(1, 0, 1)).length() == 0: return false
	var expoected_move_motion = self.velocity * Vector3(1, 0, 1) * delta
	var step_pos_with_clearance = self.global_transform.translated(expoected_move_motion + Vector3(0, MAX_STEP_HEIGHT * 2, 0))
	var down_check_result = PhysicsTestMotionResult3D.new()
	if runBodyTestMotion(step_pos_with_clearance, Vector3(0, -MAX_STEP_HEIGHT * 2, 0), down_check_result):
		if down_check_result.get_collider().is_class("StaticBody3D") || down_check_result.get_collider().is_class("CSGShape3D"):
			var step = step_pos_with_clearance.origin + down_check_result.get_travel()
			var step_height = (step - self.global_position).y
			var offset = down_check_result.get_collision_point() - self.global_position
			if step_height > MAX_STEP_HEIGHT || step_height <= 0.01 || offset.y > MAX_STEP_HEIGHT: return false
			var raycast_pos = downward_stair_detector.get_collision_point() + Vector3(0, MAX_STEP_HEIGHT, 0) + expoected_move_motion.normalized() * 0.1
			upward_stair_detector.global_position = raycast_pos
			upward_stair_detector.force_raycast_update()
			if upward_stair_detector.is_colliding() && !isSurfaceTooSteep(upward_stair_detector.get_collision_normal()):
				saveCameraPosForSmoothing()
				self.global_position = step_pos_with_clearance.origin + down_check_result.get_travel()
				apply_floor_snap()
				_snapped_to_stair_last_frame = true
				return true
	return false

func saveCameraPosForSmoothing():
	if _saved_camera_global_pos == null:
		_saved_camera_global_pos = camera_pivot.global_position

func slideCameraSmoothBackToOrigin(delta):
	if _saved_camera_global_pos == null: return
	camera_pivot.global_position.y = _saved_camera_global_pos.y
	camera_pivot.position.y = clampf(camera_pivot.position.y, -0.7, 0.7) # Clamp incase teleported
	var move_amount = max(self.velocity.length() * delta, walk_speed/2 * delta)
	camera_pivot.position.y = move_toward(camera_pivot.position.y, 0.0, move_amount)
	_saved_camera_global_pos = camera_pivot.global_position
	if camera_pivot.position.y == 0:
		_saved_camera_global_pos = null # Stop smoothing camera
