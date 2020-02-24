extends "res://objects/Object.gd"

var path
var waypoints
var waypoint :int = 0

onready var detector = {
	"Ahead":Vector2(1,0),
	"AheadLeft1":Vector2(1,-0.5).normalized(),
	"AheadRight1":Vector2(1,0.5).normalized(),
	"AheadLeft2":Vector2(1,-1).normalized(),
	"AheadRight2":Vector2(1,1).normalized(),
	"AheadLeft3":Vector2(0.5,-1).normalized(),
	"AheadRight3":Vector2(0.5,1).normalized(),
	"Left":Vector2(0,-1),
	"Right":Vector2(0,1),
	}
	
export (int) var detector_min_length = 50
export (int) var detector_max_length = 1000

enum R { ahead, left1, right1, left2, right2, left3, right3, left, right }

enum Acc { coast, speed_up, slow_down }
enum Turn { none, left, right }

var dirs = [
	Vector2(1,0),
	Vector2(1,-0.5).normalized(),
	Vector2(1,0.5).normalized(),
	Vector2(1,-1).normalized(),
	Vector2(1,1).normalized(),
	Vector2(0.5,-1).normalized(),
	Vector2(0.5,1).normalized(),
	Vector2(0,-1),
	Vector2(0,1),
	]
	
var past = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0 ]
var now = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0 ]
var cops = [Vector2(), Vector2(), Vector2(), Vector2(), Vector2(), Vector2(), Vector2(), Vector2(), Vector2() ]
var past_ang = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0 ]
var now_ang = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0 ]



var acc_action = Acc.coast
var prev_acc_action = Acc.coast
var turn_action = Turn.none
var prev_turn_action = Turn.none
var rotating :float = 0.0
var is_drifting = false

enum M { normal, centering, drifting, twisty }

var mode = M.normal

func _ready():
	path = get_parent().get_node ("Path2D")
	waypoints = path .curve.get_baked_points()
	$Info.text = str(waypoint)
	
	$Sensors/Ahead       .add_exception (self)
	$Sensors/AheadLeft1  .add_exception (self)
	$Sensors/AheadLeft2  .add_exception (self)
	$Sensors/AheadLeft3  .add_exception (self)
	$Sensors/AheadRight1 .add_exception (self)
	$Sensors/AheadRight2 .add_exception (self)
	$Sensors/AheadRight3 .add_exception (self)
	$Sensors/Left        .add_exception (self)
	$Sensors/Right       .add_exception (self)
	
#	for key in detector:
#		$Sensors.get_node(key).cast_to = detector[key] * detector_max_length

	for i in range(9):
		$Sensors.get_children()[i].cast_to = dirs[i] * detector_max_length
		now[i] = detector_max_length
	pass

func _draw():
	process()

#	for i in range(9):
#		draw_circle (cops [i], 16, Color.white)
#		var vec = Vector2 (cos(now_ang[i]), sin (now_ang[i]) * 500)
#		draw_line (cops [i], cops[i] + vec, Color.white)

func _process (delta):
	update()
	
func process():
	
	var total_cast_to = Vector2() 
	var rays = $Sensors.get_children()
	
	
	# sense the environment
	for i in range(9):
		var raycast = rays[i]
		var dir = dirs[i]
		past[i] = now[i]
		past_ang [i] = now_ang [i]

		var cp = raycast .get_collision_point ()
		var bkray = cp .direction_to (global_position)
		now_ang [i] = raycast.get_collision_normal().angle_to (bkray) * 2
		
#		print(i, ": ", rad2deg (bkray.angle()), " vs ", rad2deg(raycast.get_collision_normal ().angle()), " --> ", rad2deg (now_ang[i]))
		
		if raycast.is_colliding():
			cops [i] = to_local (cp)
			now [i] = cops [i].length ()
		else:
			now [i] = detector_max_length
			cops [i] = dir * detector_max_length
			
		raycast.cast_to = dir * detector_max_length
	
#	update()
			
#		if raycast.is_colliding():
#			raycast.cast_to = raycast.cast_to.linear_interpolate (dir * detector_min_length,0.1)
#
#		else:
#			raycast.cast_to = raycast.cast_to.linear_interpolate (dir * detector_max_length,0.1)
#
#		total_cast_to += raycast.cast_to
##		now[i] = raycast.cast_to.length()
#
#	if velocity != Vector2():
#		rotating = sin(total_cast_to.normalized().angle())

#	$Info.text = str (velocity.length())
#	$Info.text = str ((past[R.ahead] - now [R.ahead])*1000)
#	print ((past[R.right1] - now [R.right2]))
	
	# run behaviors
	prev_acc_action = acc_action
	prev_turn_action = turn_action
	
	coast ()
	speed ()
	braking ()
	turn ()
#	drift ()
	ahead ()
#	center ()
	
	# do what's left
	if acc_action == Acc.coast:
		release_accelerate()
		release_brakes()
	elif acc_action == Acc.speed_up:
		press_accelerate()
		release_brakes()
	elif acc_action == Acc.slow_down:
		press_brakes ()
		release_accelerate()
		

	if turn_action == Turn.none:
		release_turn ()
	elif turn_action == Turn.left:
		turn_left ()
	elif turn_action == Turn.right:
		turn_right()
	pass

func coast ():
	acc_action = Acc.coast
	
func speed ():
	acc_action = Acc.speed_up
	
func turn ():
	var vote = 0
	vote += turn0 ()
	vote += turn1 ()
	vote += turn2 ()
	vote += turn3 ()
	decide_turn (vote)
	
func decide_turn (vote):
	if   vote < 0: turn_action = Turn.left
	elif vote > 0: turn_action = Turn.right
	else:          turn_action = Turn.none
	

func turn0 ():
	if   now [R.left] > now [R.right]:    return -1
	elif now [R.left] < now [R.right]:    return 1
	else:                                 return 0

func turn1 ():
	if   now [R.left1] > now [R.right1]:  return -1
	elif now [R.left1] < now [R.right1]:  return 1
	else:                                 return 0

func turn2 ():
	if   now [R.left2] > now [R.right2]:  return -1
	elif now [R.left2] < now [R.right2]:  return 1
	else:                                 return 0

func turn3 ():
	if   now [R.left3] > now [R.right3]:  return -1
	elif now [R.left3] < now [R.right3]:  return 1
	else:                                 return 0


func ahead ():
	var vote = 0
	
	var longest = 0
	var index = 0
	for i in range (9):
		if now[i] > longest: 
			index = i
			longest = now[i]
	
	if now [R.ahead] >= longest:
		turn_action = Turn.none
		is_drifting = false

func center ():
	if now [R.ahead] > 800:
		if abs (now [R.left] - now [R.right]) > 16:
			decide_turn (turn0 ())

func drift ():
	
	var vote = 0
	if now [R.right1] - past [R.right1] > 5:
		vote -= now [R.right1]
		
	if now [R.left1] - past [R.left1] > 5:
		vote += now [R.left1]
		
	if vote != 0: decide_turn (vote)
	
#	if turn_action == Turn.none:
#		if   now [R.right1] - past [R.right1] > 1:  
#			turn_action = Turn.right
#			is_drifting = true
#		elif now[R.left1] - past [R.left1] > 1:
#			turn_action = Turn.left
#			is_drifting = true
#
#	elif turn_action == Turn.left:
#		if now [R.right1] - past[R.right1] > 1 and now [R.right1] - now [R.right2] > 20: 
#			turn_action = Turn.right
#			is_drifting = true
#
#	elif turn_action == Turn.right:
#		if now [R.left1]  - past[R.left1] > 1 and now [R.left1] - now [R.left2] > 20:
#			turn_action = Turn.left
#			is_drifting = true
#
#	elif is_drifting:
#		turn_action = prev_turn_action
		
	pass
	
func braking ():
	if velocity.length() > 700 and past [R.ahead] - now [R.ahead] > 10:
		acc_action = Acc.slow_down
	pass