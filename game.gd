extends Control

@export var grid_width: int = 10
@export var grid_height: int = 10
@export var mine_count: int = 10
@export var cell_size: int = 40
@export var misclick_max: int = 4
@export var misclick_clear: float = 2.0
@export var points_per_tile: int = 1

var cell_scene = preload("res://Cell.tscn")
var grid: Array = []
var first_click: bool = true
var game_over: bool = false
var cells_revealed: int = 0
var flags_placed: int = 0
var misclick_counter: int = 0
var misclick_locked: bool = false
var misclick_timer: Timer = null
var countdown_timer: Timer = null

var points: int = 0
var points_bonus: int = 0


@onready var grid_container: GridContainer = %GridContainer
@onready var status_label: Label = %StatusLabel
@onready var mine_counter: Label = %MineCounter
@onready var restart_button: Button = %RestartButton
@onready var overlay_panel: Panel = %OverlayPanel
@onready var overlay_label: Label = %OverlayLabel
@onready var overlay_restart_button: Button = %OverlayRestartButton
@onready var points_label: Label = %PointsLabel

func _ready():
	overlay_restart_button.pressed.connect(new_game)
	restart_button.pressed.connect(new_game)
	# Setup misclick cooldown timer
	misclick_timer = Timer.new()
	misclick_timer.wait_time = misclick_clear
	misclick_timer.one_shot = false
	misclick_timer.autostart = false
	misclick_timer.timeout.connect(_on_misclick_timer_tick)
	
	countdown_timer = Timer.new()
	countdown_timer.wait_time = 1
	countdown_timer.one_shot = false
	countdown_timer.autostart = true
	countdown_timer.timeout.connect(_on_countdowntick)
	add_child(misclick_timer)
	add_child(countdown_timer)
	new_game()

func new_game():
	misclick_counter = 0
	points = 0
	points_bonus = 0
	points_label.text = "0"
	misclick_locked = false
	misclick_timer.stop()
	# Clear existing grid
	overlay_panel.visible = false
	for row in grid:
		for cell in row:
			cell.queue_free()
	grid.clear()
	
	# Reset game state
	first_click = true
	game_over = false
	cells_revealed = 0
	flags_placed = 0
	
	# Setup grid container
	grid_container.columns = grid_width
	
	# Create cells
	for y in range(grid_height):
		var row = []
		for x in range(grid_width):
			var cell = cell_scene.instantiate()
			cell.x = x
			cell.y = y
			cell.custom_minimum_size = Vector2(cell_size, cell_size)
			cell.cell_clicked.connect(_on_cell_clicked)
			cell.cell_flagged.connect(_on_cell_flagged)
			cell.chorded_left.connect(_on_cell_chorded_left)
			cell.chorded_right.connect(_on_cell_chorded_right)
			grid_container.add_child(cell)
			row.append(cell)
		grid.append(row)
	
	update_mine_counter()
	status_label.text = "Click any cell to start!"

func place_mines(avoid_x: int, avoid_y: int):
	var mines_placed = 0
	while mines_placed < mine_count:
		var x = randi() % grid_width
		var y = randi() % grid_height
		
		# Don't place mine on first click or if already has mine
		if (x == avoid_x and y == avoid_y) or grid[y][x].is_mine:
			continue
		
		grid[y][x].is_mine = true
		mines_placed += 1
	
	# Calculate adjacent mine counts
	for y in range(grid_height):
		for x in range(grid_width):
			if not grid[y][x].is_mine:
				grid[y][x].adjacent_mines = count_adjacent_mines(x, y)

func count_adjacent_mines(x: int, y: int) -> int:
	var count = 0
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var nx = x + dx
			var ny = y + dy
			if nx >= 0 and nx < grid_width and ny >= 0 and ny < grid_height:
				if grid[ny][nx].is_mine:
					count += 1
	return count

func _on_cell_clicked(cell: Cell):
	if game_over:
		return
	
	if first_click:
		first_click = false
		place_mines(cell.x, cell.y)
		status_label.text = "Game in progress"
	
	if cell.is_mine:
		game_over = true
		reveal_all_mines()
		status_label.text = "Game Over! You hit a mine!"
		overlay_label.text = status_label.text
		overlay_panel.visible = true
	else:
		reveal_cell(cell.x, cell.y)
		check_win()

func reveal_cell(x: int, y: int):
	if x < 0 or x >= grid_width or y < 0 or y >= grid_height:
		return
	
	var cell = grid[y][x]
	if cell.is_revealed or cell.is_flagged:
		return
	
	cell.reveal()
	cells_revealed += 1
	points_bonus += points_per_tile
	
	# If cell has no adjacent mines, reveal neighbors
	if cell.adjacent_mines == 0 and not cell.is_mine:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if dx == 0 and dy == 0:
					continue
				reveal_cell(x + dx, y + dy)

func reveal_all_mines():
	for row in grid:
		for cell in row:
			if cell.is_mine:
				cell.reveal()

func _on_cell_flagged(cell: Cell):
	if game_over:
		return
	
	if cell.is_flagged:
		flags_placed += 1
	else:
		flags_placed -= 1
	
	update_mine_counter()

func update_mine_counter():
	mine_counter.text = str(mine_count - flags_placed)

func check_win():
	var total_safe_cells = (grid_width * grid_height) - mine_count
	if cells_revealed == total_safe_cells:
		game_over = true
		overlay_label.text = "You Win! All safe cells revealed!"
		overlay_panel.visible = true
		status_label.text = overlay_label.text
		# Optionally reveal all mines
		for row in grid:
			for cell in row:
				if cell.is_mine and not cell.is_flagged:
					cell.is_flagged = true
					cell.update_display()
					

# Returns a Dictionary of arrays:
# {"flagged": [...], "unexposed": [...], "revealed": [...], "all": [...]}
func get_neighboring_cells_by_state(cell: Cell) -> Dictionary:
	var neighbors = {
		"flagged": [],
		"unexposed": [],
		"revealed": [],
		"all": []
	}
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var nx = cell.x + dx
			var ny = cell.y + dy
			if nx < 0 or nx >= grid_width or ny < 0 or ny >= grid_height:
				continue
			var neighbor = grid[ny][nx]
			neighbors["all"].append(neighbor)
			if neighbor.is_flagged:
				neighbors["flagged"].append(neighbor)
			elif not neighbor.is_revealed:
				neighbors["unexposed"].append(neighbor)
			elif neighbor.is_revealed:
				neighbors["revealed"].append(neighbor)
	return neighbors

func _on_cell_chorded_left(cell: Cell):
	if game_over:
		return
	if misclick_locked:
		print("locked")
		$Sounds/LockedSound.play()
		return
	var neighbors = get_neighboring_cells_by_state(cell)
	var flagged = neighbors["flagged"].size()
	# Only chord if flag count matches number
	if flagged == cell.adjacent_mines:
		for adj_cell in neighbors["unexposed"]:
			_on_cell_clicked(adj_cell)
	elif neighbors["unexposed"].size() > 0:
		_misclick()


func _on_cell_chorded_right(cell: Cell):
	if game_over:
		return
	if misclick_locked:
		print("locked")
		$Sounds/LockedSound.play()
		return
	var neighbors = get_neighboring_cells_by_state(cell)
	var unexposed = neighbors["unexposed"]
	var flagged = neighbors["flagged"].size()
	# Chord if unexposed count + flagged == cell.adjacent_mines
	if unexposed.size() > 0 and flagged + unexposed.size() == cell.adjacent_mines:
		for adj_cell in unexposed:
			if not adj_cell.is_flagged:
				adj_cell.is_flagged = true
				flags_placed += 1
				adj_cell.update_display()
		update_mine_counter()
	elif unexposed.size() > 0:
		_misclick()
		
func _misclick():
	misclick_counter += 1
	var base_pitch = 0.85
	var max_pitch = 1.05
	var pitch_range = max_pitch - base_pitch
	var pitch_scale = base_pitch + (pitch_range * (misclick_counter + 1 / misclick_max))
	
	if misclick_counter >= misclick_max and not misclick_locked:
		# Became locked
		misclick_locked = true
	# Start timer if not already
	if not misclick_timer.is_stopped():
		pass
	else:
		misclick_timer.start()

	#var rand_vol = randf_range(-4, -1)
	$Sounds/ErrorSound.pitch_scale = pitch_scale
	#$Sounds/ErrorSound.volume_db = rand_vol
	$Sounds/ErrorSound.play()

func _on_misclick_timer_tick():
	print("Misclick tick. Locked:" + str(misclick_locked))
	if misclick_counter > 0:
		misclick_counter -= 1
	if misclick_counter <= 0:
		misclick_locked = false
		misclick_timer.stop()

func _on_countdowntick():
	if game_over:
		return
	points_bonus = max(0, points_bonus - 1)
	points_label.text = str(cells_revealed * points_per_tile + points_bonus)
	pass
