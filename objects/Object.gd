extends KinematicBody2D

const MAX_ANGULAR_ACCELERATION = 0.06
const ANGULAR_ACCELERATION = 0.009
const STEERIN_TURNING = 0.1
export var AGILITY_RATIO = 0.9 # var AGILITY_RATIO = 0.5
const ACCELERATION = 0.175
const WOBBLE_RATE = 0.002 #WOBBLE_RATE = 0.005
const BREAKING = 4.5
const MAX_SPEED = 1200.0
const ANGULAR_DAMPENING = 0.85

var velocity = Vector2( 0.0, 0.0 )
var thrust = 0.0
var speed = 0.0
var reversing = false
var angular_friction = 0.0
var angular_velocity = 0.0
var orientation = 0.0
var turning = 0.0
var facing = Vector2 ( 0.0, 0.0 )
var wheel_facing = Vector2 ( 0.0, 0.0 )
var drag_vector = Vector2 ( 0.0, 0.0 )
var drag = 0.0
var skid_size_front = 0.0
var skid_size_back = 0.0
var collision_time = 0.0
var active = true

var turning_left  :bool = false
var turning_right :bool = false
var accelerating  :bool = false
var braking      :bool = false
var hand_breaking :bool = false

func reset_variables():
	velocity = Vector2( 0.0, 0.0 )
	thrust = 0.0
	speed = 0.0
	reversing = false
	angular_friction = 0.0
	angular_velocity = 0.0
	orientation = 0.0
	turning = 0.0
	facing = Vector2 ( 0.0, 0.0 )
	wheel_facing = Vector2 ( 0.0, 0.0 )
	drag_vector = Vector2 ( 0.0, 0.0 )
	drag = 0.0
	skid_size_back = 0.0
	collision_time = 0.0
	active = true

func _ready():
	#$Fumes.emitting = true
	reset_variables()
	$Pivot/body.rotation_degrees = 90

func set_texture(texture):
	$Pivot/body.texture = load(texture)


func _physics_process(delta):
	collision_time += delta
		
	if speed > 10:
		skid_size_back = round( ( 1 - abs( wheel_facing.dot(velocity.normalized()) ) ) * 8 )
	else:
		skid_size_back = 0.0
		
#	if skid_size_back > 1:
#		$Fumes.emitting = true
#	else:
#		$Fumes.emitting = false
		
	
	if active:
		process_input()
	
	thrust = min( thrust * 0.95, 0.9 )
	turning = clamp( turning * 0.94, -1, 1 )
	
	angular_velocity += turning * ANGULAR_ACCELERATION
	angular_velocity += wheel_facing.angle_to( velocity ) * WOBBLE_RATE
	angular_velocity = clamp( angular_velocity, -MAX_ANGULAR_ACCELERATION, MAX_ANGULAR_ACCELERATION )
	angular_velocity *= angular_friction
	orientation += angular_velocity * clamp ((facing * AGILITY_RATIO + wheel_facing * (1-AGILITY_RATIO) ).dot( velocity.normalized()), 0,1) * clamp( (speed*2 / MAX_SPEED) , 0, 1)
	
	wheel_facing = Vector2 ( cos( orientation + angular_velocity * 10 ), sin( orientation + angular_velocity * 10 ) )
	facing = Vector2 ( cos( orientation ), sin( orientation ) ) 

	drag = ( 1 - abs( wheel_facing.dot(velocity.normalized()) )) * 0.02 + 0.01
	
	drag_vector = -velocity.rotated(wheel_facing.angle_to(velocity) * 0.4) * drag

	velocity += drag_vector
	velocity *= 1 - 0.05 * (1-facing.dot(velocity.normalized())) * (1-thrust)
	
	
	if velocity.length() > MAX_SPEED:
		velocity = velocity.normalized() * MAX_SPEED
	
	speed = velocity.length()
	
	var collision = move_and_collide(velocity * delta, true, true, true)
	if collision and collision_time > 1.0:
		collision_time = 0.0
		var cam = get_node("Camera2D")
		if cam:
			cam.add_trauma( velocity.length() / MAX_SPEED )
		velocity *= 0.2
	velocity = move_and_slide(velocity)
	
	rotation = orientation
#	$Pivot/pivot_left.rotation  = angular_velocity * 10
#	$Pivot/pivot_right.rotation = angular_velocity * 10
	
#	var zoom_scale = (speed / MAX_SPEED)
#	$Camera2D.zoom = Vector2(2,2) + Vector2(zoom_scale, zoom_scale)


	
func process_input():
	# turning
	angular_friction = ANGULAR_DAMPENING
		
	if turning_left:
		if turning > 0:
			turning = 0
		turning -= STEERIN_TURNING
		angular_friction = 1

	if turning_right:
		if turning < 0:
			turning = 0
		turning += STEERIN_TURNING
		angular_friction = 1
		
	# break
	if braking:
		if reversing:
			thrust -= 0.06
			var thrust_limited = thrust * 60
			velocity += facing * ACCELERATION * thrust_limited * min( 1, abs( facing.dot( velocity.normalized() ) ) + 0.5 )
		
		else:
			if velocity.length() >= BREAKING:
				velocity -= velocity.normalized() * BREAKING
				skid_size_front = 2
			else:
				velocity *= 0.0
				reversing = true
	# handbrake
	if hand_breaking:
		if velocity.length() >= BREAKING / 4:
			velocity -= velocity.normalized() * BREAKING / 4
			orientation -= facing.angle_to( velocity ) * 0.02 * min( 2, speed )
			skid_size_back = 5
			
	# accelerate
	if accelerating:
		reversing = false
		thrust += 0.06
		
		var thrust_limited = thrust * 60
		
		velocity += facing * ACCELERATION * thrust_limited * min( 1, abs( facing.dot( velocity.normalized() ) ) + 0.5 )
		skid_size_back = floor( max( 5 - speed / 2 , skid_size_back ) )

func turn_right (): 
	turning_right = true
	turning_left = false
	
func turn_left ():
	turning_left = true
	turning_right = false

func release_turn ():
	turning_left = false
	turning_right = false
	
func press_accelerate ():
	accelerating = true

func release_accelerate ():
	accelerating = false
		
func press_brakes ():
	braking = true

func release_brakes ():
	braking = false
	
func hold_handbrake ():
	hand_breaking = true
	
func release_handbrake ():
	hand_breaking = false
	
func clear_vehicle_controls ():
	turning_left = false
	turning_right = false
	accelerating = false
	braking = false
	hand_breaking = false
