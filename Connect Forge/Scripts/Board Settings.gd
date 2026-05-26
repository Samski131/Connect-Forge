class_name BoardSetting

enum DIRECTION {UP, RIGHT, DOWN, LEFT}
var displacement_direction= {
	"UP": Vector2(0,-1),
	"RIGHT": Vector2(1,0),
	"DOWN": Vector2(0,1),
	"LEFT": Vector2(-1,0)
}
var gravity_direction = DIRECTION.DOWN
var board_height :int = 0
var board_width :int = 0
var board_rows:int =0
var board_collumns:int=0
