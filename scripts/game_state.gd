class_name GameState
extends RefCounted

signal money_changed(new_amount: int)

var money: int


func _init(initial_money: int = 10000) -> void:
	money = maxi(initial_money, 0)


func can_afford(amount: int) -> bool:
	return amount >= 0 and money >= amount


func try_spend(amount: int) -> bool:
	if not can_afford(amount):
		return false

	money -= amount
	money_changed.emit(money)
	return true
