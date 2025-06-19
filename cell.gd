extends Control
class_name Cell

signal cell_clicked(cell)
signal cell_flagged(cell)

signal chorded_left(cell)
signal chorded_right(cell)

@export var is_mine: bool = false
@export var adjacent_mines: int = 0
@export var is_revealed: bool = false
@export var is_flagged: bool = false

var x: int
var y: int

@onready var button: Button = $Button
@onready var label: Label = $Label

func _ready():
	button.pressed.connect(_on_button_pressed)
	button.gui_input.connect(_on_button_input)
	update_display()

func _on_button_pressed():
	if not is_flagged:
		cell_clicked.emit(self)

func _on_button_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if is_revealed and adjacent_mines > 0:
				chorded_right.emit(self)
			elif not is_revealed:
				is_flagged = !is_flagged
				cell_flagged.emit(self)
				update_display()
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if is_revealed and adjacent_mines > 0:
				chorded_left.emit(self)

func reveal():
	is_revealed = true
	is_flagged = false
	update_display()

func update_display():
	if is_revealed:
		button.disabled = true
		if is_mine:
			label.text = "💣"
			modulate = Color.RED
		elif adjacent_mines > 0:
			label.text = str(adjacent_mines)
			# Color code numbers
			match adjacent_mines:
				1: label.modulate = Color.BLUE
				2: label.modulate = Color.GREEN
				3: label.modulate = Color.RED
				4: label.modulate = Color.DARK_BLUE
				5: label.modulate = Color.DARK_RED
				6: label.modulate = Color.CYAN
				7: label.modulate = Color.BLACK
				8: label.modulate = Color.GRAY
		else:
			label.text = ""
			modulate = Color(0.8, 0.8, 0.8)
	else:
		button.disabled = false
		if is_flagged:
			label.text = "🚩"
		else:
			label.text = ""
