extends Node


func _ready() -> void:
	print("")
	print("========== BOT PROFILE TEST ==========")
	
	test_profiles_exist()
	test_duncan_preferences()
	test_periwinkle_preferences()
	test_duncan_standard_loadout()
	test_periwinkle_standard_loadout()
	test_duncan_small_budget()
	test_duncan_large_budget()
	
	print("========== ALL BOT PROFILE TESTS PASSED ==========")
	print("")


func test_profiles_exist() -> void:
	var duncan:BotProfile = BotProfileLibrary.get_profile("duncan")
	var periwinkle:BotProfile = BotProfileLibrary.get_profile("periwinkle")
	
	assert(duncan != null, "Duncan profile was not found.")
	assert(periwinkle != null, "Periwinkle profile was not found.")
	assert(duncan.display_name == "Duncan", "Duncan has the wrong display name.")
	assert(periwinkle.display_name == "Periwinkle", "Periwinkle has the wrong display name.")
	assert(duncan.is_valid(), "Duncan profile is invalid.")
	assert(periwinkle.is_valid(), "Periwinkle profile is invalid.")
	
	print("PASS: Duncan and Periwinkle profiles loaded and validated.")


func test_duncan_preferences() -> void:
	var duncan:BotProfile = BotProfileLibrary.get_profile("duncan")
	assert(duncan != null, "Duncan profile was not found.")
	
	var anvil:BotTokenPreference = duncan.get_token_preference(TokenLibrary.TokenType.ANVIL)
	var bomb:BotTokenPreference = duncan.get_token_preference(TokenLibrary.TokenType.BOMB)
	var drill:BotTokenPreference = duncan.get_token_preference(TokenLibrary.TokenType.DRILL)
	
	assert(anvil != null, "Duncan is missing his Anvil preference.")
	assert(bomb != null, "Duncan is missing his Bomb preference.")
	assert(drill != null, "Duncan is missing his Drill preference.")
	assert(anvil.standard_count == 1, "Duncan's Anvil standard count should be 1.")
	assert(bomb.standard_count == 2, "Duncan's Bomb standard count should be 2.")
	assert(drill.standard_count == 1, "Duncan's Drill standard count should be 1.")
	assert(bomb.extra_purchase_weight == 2, "Duncan's Bomb extra purchase weight should be 2.")
	assert(bomb.fallback_priority == 1, "Bomb should be Duncan's first fallback purchase.")
	
	print("PASS: Duncan Inspector token preferences are correct.")


func test_periwinkle_preferences() -> void:
	var periwinkle:BotProfile = BotProfileLibrary.get_profile("periwinkle")
	assert(periwinkle != null, "Periwinkle profile was not found.")
	
	var chameleon:BotTokenPreference = periwinkle.get_token_preference(TokenLibrary.TokenType.CHAMELEON)
	var ramp:BotTokenPreference = periwinkle.get_token_preference(TokenLibrary.TokenType.RAMP)
	var fan:BotTokenPreference = periwinkle.get_token_preference(TokenLibrary.TokenType.FAN)
	var rotate_gravity:BotTokenPreference = periwinkle.get_token_preference(TokenLibrary.TokenType.ROTATE_GRAVITY)
	
	assert(chameleon != null, "Periwinkle is missing his Chameleon preference.")
	assert(ramp != null, "Periwinkle is missing his Ramp preference.")
	assert(fan != null, "Periwinkle is missing his Fan preference.")
	assert(rotate_gravity != null, "Periwinkle is missing his Rotate Gravity preference.")
	assert(chameleon.standard_count == 2, "Periwinkle's Chameleon standard count should be 2.")
	assert(ramp.standard_count == 1, "Periwinkle's Ramp standard count should be 1.")
	assert(fan.standard_count == 1, "Periwinkle's Fan standard count should be 1.")
	assert(rotate_gravity.standard_count == 1, "Periwinkle's Rotate Gravity standard count should be 1.")
	assert(chameleon.extra_purchase_weight == 2, "Periwinkle's Chameleon extra purchase weight should be 2.")
	assert(chameleon.fallback_priority == 1, "Chameleon should be Periwinkle's first fallback purchase.")
	
	print("PASS: Periwinkle Inspector token preferences are correct.")


func test_duncan_standard_loadout() -> void:
	var player:MatchPlayerData = create_test_bot("duncan", 10)
	
	assert(player != null, "Could not create Duncan test player.")
	assert(player.get_token_count(TokenLibrary.TokenType.ANVIL) == 1, "Duncan should have 1 Anvil at 10 points.")
	assert(player.get_token_count(TokenLibrary.TokenType.BOMB) == 2, "Duncan should have 2 Bombs at 10 points.")
	assert(player.get_token_count(TokenLibrary.TokenType.DRILL) == 1, "Duncan should have 1 Drill at 10 points.")
	assert(player.token_points_remaining == 0, "Duncan should spend all 10 token points.")
	
	print("PASS: Duncan standard 10-point loadout is correct.")


func test_periwinkle_standard_loadout() -> void:
	var player:MatchPlayerData = create_test_bot("periwinkle", 10)
	
	assert(player != null, "Could not create Periwinkle test player.")
	assert(player.get_token_count(TokenLibrary.TokenType.CHAMELEON) == 2, "Periwinkle should have 2 Chameleons at 10 points.")
	assert(player.get_token_count(TokenLibrary.TokenType.RAMP) == 1, "Periwinkle should have 1 Ramp at 10 points.")
	assert(player.get_token_count(TokenLibrary.TokenType.FAN) == 1, "Periwinkle should have 1 Fan at 10 points.")
	assert(player.get_token_count(TokenLibrary.TokenType.ROTATE_GRAVITY) == 1, "Periwinkle should have 1 Rotate Gravity at 10 points.")
	assert(player.token_points_remaining == 0, "Periwinkle should spend all 10 token points.")
	
	print("PASS: Periwinkle standard 10-point loadout is correct.")


func test_duncan_small_budget() -> void:
	var player:MatchPlayerData = create_test_bot("duncan", 4)
	
	assert(player != null, "Could not create small-budget Duncan.")
	assert(player.get_token_count(TokenLibrary.TokenType.BOMB) == 1, "Small-budget Duncan should buy 1 Bomb.")
	assert(player.get_token_count(TokenLibrary.TokenType.DRILL) == 1, "Small-budget Duncan should buy 1 Drill.")
	assert(player.get_token_count(TokenLibrary.TokenType.ANVIL) == 0, "Small-budget Duncan should not buy an Anvil.")
	assert(player.token_points_remaining == 0, "Small-budget Duncan should spend all available points.")
	
	print("PASS: Duncan fallback priorities work with a 4-point budget.")


func test_duncan_large_budget() -> void:
	var player:MatchPlayerData = create_test_bot("duncan", 20)
	
	assert(player != null, "Could not create large-budget Duncan.")
	assert(player.get_token_count(TokenLibrary.TokenType.ANVIL) == 2, "Duncan should have 2 Anvils at 20 points.")
	assert(player.get_token_count(TokenLibrary.TokenType.BOMB) == 4, "Duncan should have 4 Bombs at 20 points.")
	assert(player.get_token_count(TokenLibrary.TokenType.DRILL) == 2, "Duncan should have 2 Drills at 20 points.")
	assert(player.token_points_remaining == 0, "Large-budget Duncan should spend all 20 points.")
	
	print("PASS: Duncan extra purchase weights work with a 20-point budget.")


func create_test_bot(profile_id:String, token_points:int) -> MatchPlayerData:
	var profile:BotProfile = BotProfileLibrary.get_profile(profile_id)
	
	if profile == null:
		return null
	
	var player:MatchPlayerData = MatchPlayerData.new()
	player.setup(profile.display_name, MatchData.YELLOW_PALETTE, token_points, MatchPlayerData.CONTROLLER_TYPE.BOT)
	
	if player.configure_as_bot(profile.profile_id, MatchPlayerData.BOT_DIFFICULTY.NORMAL) == false:
		return null
	
	if BotProfileLibrary.apply_profile_loadout(player, profile, token_points) == false:
		return null
	
	return player
