class_name BotActionChoiceTestToken
extends Token


func get_placement_choice_variants(_context:Dictionary) -> Array[Dictionary]:
	var result:Array[Dictionary] = []
	
	result.append({
		"target_pos": Vector2i(1, 1)
	})
	
	result.append({
		"target_pos": Vector2i(2, 2)
	})
	
	result.append({
		"target_pos": Vector2i(3, 3)
	})
	
	return result
