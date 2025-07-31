extends Node

var scores: Array = []
var cfg_path = "user://high_scores.cfg"
var section_key = "scores"
var top_score_count: int = 10

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
	scores.append(points)
	scores.sort()
	scores.reverse()
	scores = scores.slice(0, top_score_count)

	var config = ConfigFile.new()
	for i in range(scores.size()):
		config.set_value(section_key, str(i), scores[i])
	config.save(cfg_path)

	if scores.size() == 0:
		return true
	if scores.size() < top_score_count:
		return true
	return points > scores[-1]


func is_high_score(score: int) -> bool:
	if scores.size() < top_score_count:
		return true
	return score >= scores[-1] if scores.size() > 0 else true
