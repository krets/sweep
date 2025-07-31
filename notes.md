## ToDo
 - New High Score should show the ranking if possible
 - High Score Message should differentiate leader-board versus Highest Score (gold star vs trophy and fix the language)
 - Also showing the high scores on the end screen would be fun
 - Feature: Special Clear: Sometimes it is not possible to safely progress without guessing
   As an alternative; the player can spend points to safely clear a cell
   - If the cell contains a mine; the bomb noise is played and the mine is removed; surrounding cell labels must be updated.
   - if cell is empty, it is exposed as normal and underlying label may be displayed
   - point cost must be 25 points or 15% of cummulative total; whatever is greater
   - When bonus points are consumed; if bonus_points > cost; bonus_points -= cost; else: cost -= bonus_points; bonus_points = 0
   - remainder of cost is tracked in new variable per stage (points_spent or something similar)
   - if cost is > current total points, then special clear is not available
   - Special clear is a button at the bottom right above pause
	 - the button can be toggled on and off; when on points get consumed when clearing. 
	 - mouse cursor should indicate the special state
	 - It should auto-toggle off after clearing a cell.
