class_name BoardSetting
#Stores various bits of board information

enum DIRECTION {UP, RIGHT, DOWN, LEFT}

var displacement_direction= {
	"UP": Vector2(0,-1),
	"RIGHT": Vector2(1,0),
	"DOWN": Vector2(0,1),
	"LEFT": Vector2(-1,0)
}
var gravity_direction = DIRECTION.DOWN
var height :int = 0
var width :int = 0
var rows:int =0
var collumns:int=0
