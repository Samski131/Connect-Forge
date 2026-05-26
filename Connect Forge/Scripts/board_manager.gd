extends Node2D
var board = []

#hold a 2d array of tokens.
#various return functions giving lists of tokens (all on X row, etc)
#check for tokens at (X,Y)


#gets a token from a given XY, error protection for numbers out of range
func getToken(x:int, y:int)->Token: 
	if (x <0 or x >= Global.board_settings.board_width-1):
		return
		
	if (y <0 or y > Global.board_settings.board_height):
		return
		
	var width = Global.board_settings.board_width
	print(board[x*width + y])
	return board[x*width + y]
