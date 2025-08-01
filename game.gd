extends Control

@export var grid_width: int = 10
@export var grid_height: int = 10
@export var mine_count: int = 10
@export var cell_size: int = 40
@export var misclick_max: int = 4
@export var misclick_clear: float = 2.0
@export var points_per_tile: int = 1
@export var points_color_bonus: Color = Color(1,.8, 0, 1)
@export var points_color_normal: Color = Color(1, 1, 1, 1)
@export var end_overlay_win: Color = Color(0,1,0)
@export var end_overlay_die: Color = Color(1,0,0)
@export var cell_normal: Color = Color(.3, .3, .4)
@export var cell_hover: Color = Color(.8, .2, .6)
@export var cell_exposed: Color = Color(.8, .2, .6)
@export var hard_mode: bool = false
@export var special_clear_base_cost: int = 25
@export var special_clear_percent_cost: float = 0.15
@export var special_clear_cursor = preload("res://special_clear_cursor.png") 



class Stage:
	var columns
	var rows
	var mines
	var points: int

	func _init(columns, rows, mines):
		self.columns = columns
		self.rows = rows
		self.mines = mines
		self.reset()

	func reset():
		self.points = 0

var stages = [
	Stage.new(10,10,10),
	Stage.new(12,11,19),
	Stage.new(15,13,32),
	Stage.new(18,14,47),
	Stage.new(20,16,66)
]

var current_stage_index: int = 0
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
var points_bonus: int = 0
var current_stage: Stage = null
var is_paused: bool = false
var was_paused_before_focus: bool = false
var special_clear_mode: bool = false
var points_spent: int = 0  # Track points spent in current stage
var default_cursor = null

@onready var grid_container: GridContainer = %MinefieldGrid
@onready var mine_counter: Label = %MineCounter
@onready var overlay: Control = %Overlay
@onready var overlay_label: Label = %OverlayLabel
@onready var overlay_restart_button: Button = %OverlayRestartButton
@onready var points_label: Label = %PointsLabel
@onready var points_breakdown: RichTextLabel = %PointsBreakdownLabel
@onready var overlay_panel_bg: Panel = %OverlayBackgroundPanel
@onready var stage_label: Label = %StageLabel
@onready var pause_overlay: Control = %PauseOverlay
@onready var pause_button: Button = %PauseButton
@onready var high_scores_list: VBoxContainer = %HighScoresList
@onready var score_breakdown_container: VBoxContainer = %ScoreBreakdownContainer
@onready var final_score_label: Label = %FinalScoreLabel
@onready var stage_scores_container: VBoxContainer = %StageScoresContainer
@onready var special_clear_button: Button = %SpecialClearButton
@onready var special_clear_cost_label: Label = %SpecialClearCostLabel

func _ready():
	HighScores.load_scores()
	overlay_restart_button.pressed.connect(new_game)
	pause_button.pressed.connect(toggle_pause)
	%UnpauseButton.pressed.connect(toggle_pause)

	special_clear_button.pressed.connect(_toggle_special_clear)
	default_cursor = Input.get_current_cursor_shape()
	
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
	
	# Show high scores on startup
	display_high_scores()
	
	# Connect window focus signals
	get_window().focus_entered.connect(_on_window_focus_entered)
	get_window().focus_exited.connect(_on_window_focus_exited)
	
	new_game()

func _toggle_special_clear():
	special_clear_mode = !special_clear_mode
	_update_special_clear_ui()
	
	if special_clear_mode:
		#Input.set_default_cursor_shape(Input.CURSOR_CROSS)  # Or use custom cursor
		Input.set_custom_mouse_cursor(special_clear_cursor)
	else:
		#Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		Input.set_custom_mouse_cursor(null)

func _update_special_clear_ui():
	var cost = _calculate_special_clear_cost()
	var can_afford = get_all_points() >= cost

	special_clear_button.disabled = !can_afford or game_over or is_paused
	special_clear_button.modulate = Color.GREEN if special_clear_mode else Color.WHITE

	if can_afford:
		special_clear_cost_label.text = "Cost: %d pts" % cost
		special_clear_cost_label.modulate = Color.WHITE
	else:
		special_clear_cost_label.text = "Need %d pts" % cost
		special_clear_cost_label.modulate = Color.RED

func _calculate_special_clear_cost() -> int:
	var total_points = get_all_points()
	var percent_cost = int(total_points * special_clear_percent_cost)
	return max(special_clear_base_cost, percent_cost)

func _consume_special_clear_cost(cost: int):
	if points_bonus >= cost:
		points_bonus -= cost
	else:
		var remaining = cost - points_bonus
		points_bonus = 0
		points_spent += remaining
	update_points()

func _input(event):
	if event.is_action_pressed("pause"):
		toggle_pause()

func _notification(what):
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if not is_paused and not overlay.visible:
			was_paused_before_focus = false
			set_paused(true)
		else:
			was_paused_before_focus = true
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		if not was_paused_before_focus:
			set_paused(false)

func _on_window_focus_entered():
	pass

func _on_window_focus_exited():
	pass

func toggle_pause():
	if game_over or overlay.visible:
		return
	set_paused(!is_paused)

func set_paused(paused: bool):
	is_paused = paused
	pause_overlay.visible = is_paused
	if is_paused:
		countdown_timer.paused = true
		misclick_timer.paused = true
	else:
		countdown_timer.paused = false
		misclick_timer.paused = false

func display_high_scores():
	# Clear existing scores
	for child in high_scores_list.get_children():
		child.queue_free()
	
	# Add high scores
	for i in range(min(10, HighScores.scores.size())):
		var score_label = Label.new()
		score_label.text = "%2d. %5d" % [i + 1, HighScores.scores[i]]
		score_label.add_theme_font_size_override("font_size", 16)
		high_scores_list.add_child(score_label)
	
	if HighScores.scores.size() == 0:
		var no_scores_label = Label.new()
		no_scores_label.text = "No high scores yet!"
		no_scores_label.add_theme_font_size_override("font_size", 16)
		high_scores_list.add_child(no_scores_label)

func new_game():
	current_stage = stages[current_stage_index]
	grid_width = current_stage.columns
	grid_height = current_stage.rows
	mine_count = current_stage.mines
	var max_mines = (grid_width * grid_height) - 1
	print("Maxmines: %s count: %s" % [max_mines, mine_count])
	mine_count = min(mine_count, max_mines)
	misclick_counter = 0
	cells_revealed = 0
	points_bonus = 0
	points_spent = 0
	special_clear_mode = false
	points_label.text = str(get_all_points())
	points_breakdown.text = ""
	misclick_locked = false
	misclick_timer.stop()
	
	# Update stage label
	stage_label.text = "Stage %d" % (current_stage_index + 1)
	
	# Clear existing grid
	overlay_panel_bg.modulate = Color(1, 1, 1, 1)
	overlay.visible = false
	score_breakdown_container.visible = false
	for row in grid:
		for cell in row:
			cell.queue_free()
	grid.clear()
	final_score_label.visible = false

	# Reset game state
	first_click = true
	game_over = false
	cells_revealed = 0
	flags_placed = 0
	is_paused = false
	pause_overlay.visible = false

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
			cell.center_particles(cell_size)
			row.append(cell)
		grid.append(row)

	update_mine_counter()

func place_mines(avoid_x: int, avoid_y: int):
	var mines_placed = 0
	while mines_placed < mine_count:
		var x = randi() % grid_width
		var y = randi() % grid_height

		# Skip if on first click or already a mine
		if grid[y][x].is_mine:
			continue

		# Skip if cell is first click or adjacent to first click
		if abs(x - avoid_x) <= 1 and abs(y - avoid_y) <= 1:
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
	if game_over or cell.is_flagged or is_paused:
		return

	if special_clear_mode and not cell.is_revealed:
		var cost = _calculate_special_clear_cost()
		if get_all_points() >= cost:
			_perform_special_clear(cell)
			special_clear_mode = false
			Input.set_custom_mouse_cursor(null)
			_update_special_clear_ui()
		return

	if first_click:
		first_click = false
		place_mines(cell.x, cell.y)

	if cell.is_mine:
		game_over = true
		reveal_all_mines()
		overlay_label.text = "💥 Game Over! 💥"
		overlay_panel_bg.modulate = end_overlay_die
		overlay_panel_bg.modulate.a = 0
		overlay.visible = true
		var tween = create_tween()
		$Sounds/FxEarthquake.play()
		tween.tween_property(overlay_panel_bg, "modulate:a", .7, .25)
		tween.finished.connect(show_score_breakdown.bind(true))
	else:
		reveal_cell(cell.x, cell.y)
		check_win()

func _perform_special_clear(cell: Cell):
	var cost = _calculate_special_clear_cost()
	_consume_special_clear_cost(cost)
	
	if first_click:
		first_click = false
		place_mines(cell.x, cell.y)
	
	if cell.is_mine:
		# Play bomb defuse sound
		$Sounds/FxEarthquake.play()

		# Remove the mine
		cell.is_mine = false
		
		# Recalculate the mine count for the cleared cell itself
		cell.adjacent_mines = count_adjacent_mines(cell.x, cell.y)

		# Update all adjacent cells' mine counts and track cells that become 0
		var cells_to_cascade = []
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if dx == 0 and dy == 0:
					continue
				var nx = cell.x + dx
				var ny = cell.y + dy
				if nx >= 0 and nx < grid_width and ny >= 0 and ny < grid_height:
					var adj_cell = grid[ny][nx]
					if not adj_cell.is_mine and adj_cell.adjacent_mines > 0:
						adj_cell.adjacent_mines -= 1
						if adj_cell.is_revealed:
							adj_cell.update_display()
							# If this revealed cell now has 0 mines, it should cascade
							if adj_cell.adjacent_mines == 0:
								cells_to_cascade.append(adj_cell)
		
		# Trigger cascade reveal for any cells that dropped to 0
		for cascade_cell in cells_to_cascade:
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if dx == 0 and dy == 0:
						continue
					reveal_cell(cascade_cell.x + dx, cascade_cell.y + dy)
		
		# Reduce total mine count
		mine_count -= 1
		update_mine_counter()
	
	# Reveal the cell normally
	reveal_cell(cell.x, cell.y)
	check_win()

func reveal_cell(x: int, y: int):
	if x < 0 or x >= grid_width or y < 0 or y >= grid_height:
		return

	var cell = grid[y][x]
	if cell.is_revealed or cell.is_flagged:
		return

	cell.reveal()
	$Sounds/ClearTiles.pitch_scale = randf_range(0.9, 1.1)
	$Sounds/ClearTiles.play()
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
	if game_over or is_paused:
		return

	if cell.is_flagged:
		flags_placed += 1
		$Sounds/PlantFlag.play()
	else:
		flags_placed -= 1
		$Sounds/UnPlantFlag.play()

	update_mine_counter()

func update_mine_counter():
	mine_counter.text = str(mine_count - flags_placed)

func check_win():
	var total_safe_cells = (grid_width * grid_height) - mine_count
	if cells_revealed == total_safe_cells:
		game_over = true

		for row in grid:
			for cell in row:
				if cell.is_mine and not cell.is_flagged:
					cell.is_flagged = true
					cell.update_display()
		
		current_stage.points = get_points()
		overlay_label.text = "Stage Cleared!"
		overlay_restart_button.text = "Continue"

		# Don't increment stage index yet - wait until after score breakdown
		var is_final_stage = (current_stage_index + 1) == stages.size()
		if is_final_stage:
			overlay_label.text = "You Win! Game over!"
			overlay_restart_button.text = "Play Again"

		overlay_panel_bg.modulate = end_overlay_win
		overlay_panel_bg.modulate.a = 0
		overlay.visible = true
		var tween = create_tween()
		tween.tween_property(overlay_panel_bg, "modulate:a", .7, 1)
		tween.finished.connect($Sounds/WinnerTune.play)
		tween.finished.connect(show_score_breakdown.bind(is_final_stage))


func show_score_breakdown(show_final: bool):
	score_breakdown_container.visible = true

	# Clear previous breakdown
	for child in stage_scores_container.get_children():
		child.queue_free()

	var total_previous = 0

	# Show all previously completed stages
	for i in range(current_stage_index):
		if stages[i].points > 0:
			var stage_score_label = Label.new()
			stage_score_label.text = "Stage %d: %d points" % [i + 1, stages[i].points]
			stage_score_label.add_theme_font_size_override("font_size", 18)
			stage_scores_container.add_child(stage_score_label)
			total_previous += stages[i].points

	# Show current stage score with animation
	var stage_score_label = RichTextLabel.new()
	stage_score_label.bbcode_enabled = true
	stage_score_label.fit_content = true
	stage_score_label.scroll_active = false
	stage_score_label.add_theme_font_size_override("normal_font_size", 18)
	stage_scores_container.add_child(stage_score_label)

	var base_points = cells_revealed * points_per_tile
	var bonus_points = points_bonus
	var total_stage_points = base_points + bonus_points

	animate_stage_score_with_bonus(stage_score_label, base_points, bonus_points, points_spent, current_stage_index + 1, 0.0)
	total_previous += total_stage_points

	# Add separator
	await get_tree().create_timer(1.2).timeout
	var separator = HSeparator.new()
	stage_scores_container.add_child(separator)

	# Add current total line
	var current_total_label = Label.new()
	current_total_label.text = "Current Total: %d points" % total_previous
	current_total_label.add_theme_font_size_override("font_size", 20)
	current_total_label.add_theme_color_override("font_color", Color.YELLOW)
	stage_scores_container.add_child(current_total_label)

	if show_final:
		await get_tree().create_timer(0.4).timeout
		final_score_label.visible = true
		await animate_score_count(final_score_label, 0, total_previous, 0.1, 0, "Final Score: ")
		HighScores.save_score(total_previous)
		await get_tree().create_timer(0.3).timeout
		if HighScores.is_high_score(total_previous):
			var high_score_label = Label.new()
			high_score_label.text = "🏆 NEW HIGH SCORE! 🏆"
			high_score_label.add_theme_font_size_override("font_size", 24)
			high_score_label.modulate = Color.YELLOW
			stage_scores_container.add_child(high_score_label)

			# Animate the high score label
			high_score_label.modulate.a = 0
			var tween = create_tween()
			tween.tween_property(high_score_label, "modulate:a", 1.0, 0.5)
			tween.parallel().tween_property(high_score_label, "scale", Vector2(1.2, 1.2), 0.5)
			tween.tween_property(high_score_label, "scale", Vector2(1.0, 1.0), 0.3)

			$Sounds/WinnerTune.play()
		print("waiting...")
		await get_tree().create_timer(3).timeout
		# NOW increment the stage index before starting new game
		current_stage_index += 1
		end_game()
		print("game end called")
	else:
		# Increment stage for next game
		current_stage_index += 1
		final_score_label.visible = false


# In the stage score animation, show points spent if any
func animate_stage_score_with_bonus(label: RichTextLabel, base: int, bonus: int, spent: int, stage_num: int, delay: float):
	await get_tree().create_timer(delay).timeout
	
	var duration = 1.0
	var elapsed = 0.0
	var total = base + bonus - spent
	
	while elapsed < duration:
		elapsed += get_process_delta_time()
		var progress = min(elapsed / duration, 1.0)
		var current_value = int(lerp(0.0, float(total), progress))
		
		var text_parts = ["Stage %d: %d" % [stage_num, base]]
		
		if bonus > 0:
			text_parts.append("[color=#FFCC00]+%d[/color]" % bonus)
		
		if spent > 0:
			text_parts.append("[color=#FF0000]-%d[/color]" % spent)
		
		if bonus > 0 or spent > 0:
			text_parts.append("= %d points" % current_value)
		else:
			text_parts[0] = "Stage %d: %d points" % [stage_num, current_value]
		
		label.text = " ".join(text_parts)
		await get_tree().process_frame
	
	# Set final text
	var final_parts = ["Stage %d: %d" % [stage_num, base]]
	if bonus > 0:
		final_parts.append("[color=#FFCC00]+%d[/color]" % bonus)
	if spent > 0:
		final_parts.append("[color=#FF0000]-%d[/color]" % spent)
	if bonus > 0 or spent > 0:
		final_parts.append("= %d points" % total)
	else:
		final_parts[0] = "Stage %d: %d points" % [stage_num, total]
	
	label.text = " ".join(final_parts)

func animate_score_count(label: Label, from: int, to: int, delay: float, stage_num: int, prefix: String = ""):
	await get_tree().create_timer(delay).timeout
	
	var duration = 1.0
	var elapsed = 0.0
	print("animate score: %s -> %s" % [from, to])
	while elapsed < duration:
		elapsed += get_process_delta_time()
		var progress = min(elapsed / duration, 1.0)
		var current_value = int(lerp(float(from), float(to), progress))
		
		if stage_num > 0:
			label.text = "Stage %d: %d" % [stage_num, current_value]
		else:
			label.text = prefix + str(current_value) + " points"
		
		await get_tree().process_frame
	
	# Ensure final value is set
	if stage_num > 0:
		label.text = "Stage %d: %d points" % [stage_num, to]
	else:
		label.text = prefix + str(to) + " points"

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
	if game_over or is_paused:
		return
	if misclick_locked:
		print("locked")
		$Sounds/LockedSound.play()
		return
	var neighbors = get_neighboring_cells_by_state(cell)
	if hard_mode or cell.adjacent_mines == neighbors["flagged"].size():
		for adj_cell in neighbors["unexposed"]:
			_on_cell_clicked(adj_cell)
	else:
		_blink_cells(neighbors["unexposed"])
		_misclick()

func _blink_cells(cells: Array):
	for cell in cells:
		cell.blink_red()

func _on_cell_chorded_right(cell: Cell):
	if game_over or is_paused:
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
				$Sounds/PlantFlag.play()
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

func get_points():
	return max(0, cells_revealed * points_per_tile + points_bonus - points_spent)

func get_all_points():
	var total_points = 0
	for stage in stages:
		if stage == current_stage:
			continue
		total_points += stage.points
	return total_points + get_points()

func _on_countdowntick():
	if not game_over and not is_paused:
		points_bonus = max(0, points_bonus - 1)
	update_points()
	_update_special_clear_ui()

func update_points():
	points_label.text = str(get_all_points())
	var breakdown_parts = []

	if points_spent > 0:
		breakdown_parts.append("[color=#FF0000]-%d[/color]" % points_spent)

	if points_bonus > 0:
		breakdown_parts.append("[color=#FFCC00]+%d[/color]" % points_bonus)

	if breakdown_parts.size() > 0:
		var base = cells_revealed * points_per_tile
		points_breakdown.text = "(%d %s)" % [base, " ".join(breakdown_parts)]
		points_label.modulate = points_color_bonus if points_bonus > 0 else points_color_normal
	else:
		points_breakdown.text = ""
		points_label.modulate = points_color_normal

func end_game():
	var total_score = get_all_points()

	# Reset for new game only after handling score!
	var is_high_score = HighScores.save_score(total_score)
	if is_high_score:
		print("New high score achieved: ", total_score)

	display_high_scores()
	for stage in stages:
		stage.reset()
	current_stage_index = 0
