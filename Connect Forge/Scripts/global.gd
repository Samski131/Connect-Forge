@tool
extends Node
#Global script with useful variables as well as common helper functions.

enum TURN_PHASE {NONE,PLACEMENT, ACTION, RESOLUTION, GAME_OVER}
enum SLOT_TYPE {TOP_EDGE, BOTTOM_EDGE, LEFT_EDGE, RIGHT_EDGE, INTERIOR}
enum KEYWORD {
	ON_LAND,
	ON_IMPACT,
	ON_PASS_LEFT,
	ON_PASS_RIGHT,
	ON_PASS_ABOVE,
	ON_PASS_BELOW,
	ON_LINE_FULL
}

func get_keyword_display_name(keyword:KEYWORD)->String:
	match keyword:
		KEYWORD.ON_LAND:
			return "On Land"
		KEYWORD.ON_IMPACT:
			return "On Impact"
		KEYWORD.ON_PASS_LEFT:
			return "On Pass Left"
		KEYWORD.ON_PASS_RIGHT:
			return "On Pass Right"
		KEYWORD.ON_PASS_ABOVE:
			return "On Pass Above"
		KEYWORD.ON_PASS_BELOW:
			return "On Pass Below"
		KEYWORD.ON_LINE_FULL:
			return "On Line Full"
	return "Unknown"
