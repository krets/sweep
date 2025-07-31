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
@export var adjacent_color_one: Color = Color(0, 1, 0)
@export var adjacent_color_two: Color = Color(0.5, 0.5, 0)  
@export var adjacent_color_thr: Color = Color(1, 1, 0)
@export var adjacent_color_fou: Color = Color(1, 0.5, 0)
@export var adjacent_color_fiv: Color = Color(1, 0, 0) 
@export var adjacent_color_six: Color = Color(1, .34, 0.99)  
@export var adjacent_color_sev: Color = Color(0.42, .30, 1)
@export var adjacent_color_eig: Color = Color(0, .7, .73)



var x: int
var y: int

@onready var button: Button = $Button
@onready var label: Label = $Label
@onready var adjacent_colors: Array[Color] = [
	adjacent_color_one,
	adjacent_color_two,
	adjacent_color_thr,
	adjacent_color_fou,
	adjacent_color_fiv,
	adjacent_color_six,
	adjacent_color_sev,
	adjacent_color_eig,
]

func _ready():
	button.gui_input.connect(_on_button_input)
	update_display()

func _on_button_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
			if button.get_rect().has_point(button.get_local_mouse_position()):
				if is_revealed and adjacent_mines > 0:
					chorded_right.emit(self)
				elif not is_revealed:
					print("Right click on unrevealed cell. Current flag state: ", is_flagged)
					is_flagged = !is_flagged
					print("New flag state: ", is_flagged)
					cell_flagged.emit(self)
					update_display()
		elif event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			if button.get_rect().has_point(button.get_local_mouse_position()):
				if is_revealed and adjacent_mines > 0:
					chorded_left.emit(self)
				if not is_revealed:
					cell_clicked.emit(self)

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
			label.modulate = adjacent_colors[adjacent_mines - 1]
		else:
			label.text = ""
			#modulate = Color(1, 0, 0, 1)
	else:
		button.disabled = false
		if is_flagged:
			label.text = "🚩"
		else:
			label.text = ""

func blink_red():
	var original = modulate
	modulate = Color(1,0,0,1)
	var tween = create_tween()
	tween.tween_property(self, "modulate", original, 0.3)
