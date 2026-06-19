class_name BoardSetting
#Stores various bits of board information

enum DIRECTION {UP, RIGHT, DOWN, LEFT, UP_RIGHT,UP_LEFT,DOWN_RIGHT, DOWN_LEFT}

var displacement_direction= {
	"UP":    Vector2(0,-1),
	"RIGHT": Vector2(1,0),
	"DOWN":  Vector2(0,1),
	"LEFT":  Vector2(-1,0),
	"UP_RIGHT":  Vector2(1,-1),
	"UP_LEFT":  Vector2(-1,-1),
	"DOWN_RIGHT":  Vector2(1,1),
	"DOWN_LEFT":  Vector2(-1,1),
}
var gravity_direction = DIRECTION.DOWN
var height :int = 0
var width :int = 0
var rows:int =0
var collumns:int=0
var tokens_to_win:int = 4 #how many tokens must be adjacent to win.
