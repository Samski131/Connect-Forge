extends Node2D

var sprites:Array = []
enum PART{red, green, blue, cyan, yellow}

var game_manager:Node

func _ready():
	game_manager= get_tree().get_first_node_in_group("game manager")
	recolor(game_manager.current_player_id)
	
func recolor(player_id):
	gather_sprites()
	for sprite in sprites:
		if sprite.name.contains("red"):
			sprite.modulate = get_part_color(PART.red, player_id)
		elif sprite.name.contains("green"):
			sprite.modulate = get_part_color(PART.green, player_id)
		elif sprite.name.contains("blue"):
			sprite.modulate = get_part_color(PART.blue, player_id)
		elif sprite.name.contains("cyan"):
			sprite.modulate = get_part_color(PART.cyan, player_id)
		elif sprite.name.contains("yellow"):
			sprite.modulate = get_part_color(PART.yellow, player_id)

func darken(amount:float):
	gather_sprites()
	for sprite in sprites:
		sprite.modulate = sprite.modulate.darkened(amount)
		
func gather_sprites():
	sprites.clear()
	
	for child in get_children(true):
		if child is Sprite2D:
			sprites.append(child)
			

func get_part_color(part_id:int,player_id:int)->Color:
	return game_manager.player_colours[player_id].colors[part_id]
