extends Node

var scores: Array = []
var cfg_path = "user://high_scores.cfg"
var section_key = "scores"


func load_scores():
	var config = ConfigFile.new()
	var err = config.load(cfg_path)
	if err == OK:
		scores.clear()
		for key in config.get_section_keys(section_key):
			var score = config.get_value(section_key, key)
			scores.append(int(score))
		scores.sort()
		scores.reverse()
	else:
		scores = []

func save_score(points: int) -> bool:
	if scores.size() > 0 and points <= scores[-1]:
		print("No High score!")
		return false
	scores.append(points)
	scores.sort()
	scores.reverse()
	scores = scores.slice(0, 10)

	var config = ConfigFile.new()
	for i in range(scores.size()):
		config.set_value(section_key, str(i), scores[i])
	config.save(cfg_path)
	return true
