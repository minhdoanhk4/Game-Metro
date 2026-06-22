extends CanvasLayer

@onready var money_label = $Panel/MoneyLabel
@onready var buy_button = $Panel/VBox/BuyButton
@onready var back_button = $Panel/VBox/BackButton
@onready var info_label = $Panel/InfoLabel

# Example of a new train to buy
var new_train_path = "res://Scenes/TrainFast.tscn"
var cost = 500

func _ready():
	GameManager.money_changed.connect(_on_money_changed)
	_on_money_changed(GameManager.money)
	
	buy_button.pressed.connect(_on_buy_pressed)
	back_button.pressed.connect(_on_back_pressed)
	
	_update_shop_ui()

func _on_money_changed(m):
	money_label.text = "Money: $" + str(m)
	_update_shop_ui()

func _update_shop_ui():
	if GameManager.owned_trains.has(new_train_path):
		buy_button.text = "Owned (Fast Train)"
		buy_button.disabled = true
	else:
		buy_button.text = "Buy Fast Train ($" + str(cost) + ")"
		buy_button.disabled = GameManager.money < cost

func _on_buy_pressed():
	if GameManager.buy_train(new_train_path, cost):
		info_label.text = "Purchase successful!"
		GameManager.select_train(GameManager.owned_trains.size() - 1)
	else:
		info_label.text = "Not enough money!"

func _on_back_pressed():
	hide()
