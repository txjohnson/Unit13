extends "res://objects/Object.gd"

var mouse_position

func _ready():
	
	pass
	
func _input(event):
	if event is InputEventMouseMotion:
		mouse_position = event.position - get_viewport_rect().size/2

	if event.is_action_pressed ("ui_up"):  
		press_accelerate ()
	if event.is_action_released ("ui_up"): 
		release_accelerate ()

	if event.is_action_pressed ("ui_down"):  
		press_brakes ()
	if event.is_action_released ("ui_down"): 
		release_brakes ()

	if event.is_action_pressed ("ui_left"):  
		turn_left ()
	if event.is_action_released ("ui_left"): 
		release_turn ()
		
	if event.is_action_pressed ("ui_right"):  
		turn_right ()
	if event.is_action_released ("ui_right"): 
		release_turn ()

	pass

func process(delta):
	pass	
