class_name EffectControl
extends Control

var ui_effect_runner:UIEffectRunner = null


func _ready() -> void:
	ui_effect_runner = get_tree().get_first_node_in_group("ui effect runner") as UIEffectRunner


func queue_ui_effect(effect:UIEffect, queued:bool = false) -> void:
	if effect == null:
		return
	
	if ui_effect_runner == null:
		ui_effect_runner = get_tree().get_first_node_in_group("ui effect runner") as UIEffectRunner
	
	if ui_effect_runner == null:
		return
	
	if queued:
		ui_effect_runner.queue_effect(effect)
	else:
		ui_effect_runner.play(effect)


func pulse(intensity:float = 1.12, duration:float = 0.18) -> void:
	queue_ui_effect(UIPulseEffect.new(self, intensity, duration))


func flash(flash_color:Color = Color.WHITE, intensity:float = 1.0, duration:float = 0.22) -> void:
	queue_ui_effect(UIFlashEffect.new(self, flash_color, intensity, duration))


func shake(intensity:float = 8.0, duration:float = 0.22, shakes:int = 4) -> void:
	queue_ui_effect(UIShakeEffect.new(self, intensity, duration, shakes))
