class_name BotChanceOutcome
extends RefCounted

var probability:float = 1.0
var action:BotAction = null
var description:String = ""


func setup(new_probability:float, new_action:BotAction, new_description:String = "") -> bool:
	if new_action == null:
		return false
	
	if new_probability <= 0.0:
		return false
	
	probability = new_probability
	action = new_action.duplicate_action()
	description = new_description
	
	return true


func is_valid() -> bool:
	if action == null:
		return false
	
	if action.is_well_formed() == false:
		return false
	
	if probability <= 0.0:
		return false
	
	return true


func duplicate_outcome() -> BotChanceOutcome:
	var result:BotChanceOutcome = BotChanceOutcome.new()
	
	if result.setup(probability, action, description) == false:
		return null
	
	return result
