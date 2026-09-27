extends Node



const THINK_MIN: = 0.42
const THINK_MAX: = 0.92
const ALLIANCE_WAIT: = 3.0



@export var force_optimal_values: = false

var game
var _busy: = false
var _was_game_started: = false
var _poll_time: = 0.0
var _seen_card_turn: = -1
var _inspection_step: = 0
var _challenge_waited: = false
var _alliance_key: = ""
var _alliance_ready_at: = 0
var _bot_profiles: Dictionary = {}
var _alliance_offer_attempts: Dictionary = {}
var _pending_bot_offers: Dictionary = {}
var _last_rejected_offer: Dictionary = {}
var _planned_swap_target_mini: = -1
var _alliance_evaluation_key: = ""
var _alliance_evaluation_queue: Array[int] = []
var _alliance_evaluation_results: Dictionary = {}
var _alliance_outlook_key: = ""
var _alliance_outlook_jobs: Dictionary = {}
var _alliance_outlook_cache: Dictionary = {}
var _alliance_star_value_cache: Dictionary = {}
const ALLIANCE_THINK_FRAME_BUDGET_USEC: = 1200
var _card_eval_turn: = -1
var _card_eval_side: = -1
var _card_eval_cards: Array[int] = []
var _card_eval_card_slot: = 0
var _card_eval_character_index: = 0
var _card_eval_candidates: Array[Dictionary] = []
var _card_eval_choice: Dictionary = {}
var _card_eval_best_raw_score: = - INF
var _card_eval_finished: = false
const CARD_THINK_FRAME_BUDGET_USEC: = 1200


func setup(game_node) -> void :
	game = game_node
	set_process(false)


func tick(delta: float) -> void :
	if game == null:
		return
	if not game.game_has_started or game.game_over:
		_was_game_started = false
		return
	if not _was_game_started:
		_was_game_started = true
		_bot_profiles.clear()
	_poll_time -= delta
	if _busy or _poll_time > 0.0:
		return
	_busy = true
	_run_step()


func _run_step() -> void :
	await _dispatch_step()
	_busy = false




	_poll_time = (
		0.0
		if (game != null
			and (game.alliance_target_character_index >= 0
				or not _alliance_outlook_jobs.is_empty()
				or (_card_eval_turn >= 0 and not _card_eval_finished)))
		else randf_range(0.12, 0.26)
	)


func _dispatch_step() -> void :
	if game.scene_deal_active:
		await _scene_deal_step()
		return
	if game.character_draft_active:
		await _character_draft_step()
		return
	if game.star_draft_active:
		await _star_draft_step()
		return
	if game.challenge_phase_active:
		await _challenge_step()
		return
	_challenge_waited = false
	if game.character_movement_phase_active:
		await _challenge_movement_step()
		return
	if game.elimination_phase_active:
		await _elimination_step()
		return
	if game.card_play_phase_active:
		await _card_phase_step()
		return
	await get_tree().process_frame


func _scene_deal_step() -> void :
	var side: int = game._get_current_turn_side()
	if game.is_player_bot(side) and game.scene_deck_visible and not game.scene_deck_busy:
		await _think()
		if game.scene_deal_active and game._get_current_turn_side() == side:
			game._deal_scene_card()
	else:
		await get_tree().process_frame


func _character_draft_step() -> void :
	var side: int = game._get_current_turn_side()
	if not game.is_player_bot(side) or game.character_deck_busy:
		await get_tree().process_frame
		return
	await _think()
	if not game.character_draft_active or game._get_current_turn_side() != side:
		return
	if game.character_deck_visible:
		game._start_character_layout()
	elif not game.draft_character_cards.is_empty():
		game._choose_character_card(_choose_draft_character(side))


func _choose_draft_character(side: int) -> int:
	var profile: = _get_bot_profile(side)
	var covered: Dictionary = {}
	for card_index in game._get_owner_character_card_indices(side):
		var owned_name: String = game._get_character_name_from_card(card_index)
		for attribute in game._get_character_attributes(owned_name):
			covered[attribute] = true
	var best_index: = -1
	var best_score: = - INF
	for index in game.draft_character_cards.size():
		if not game._is_draft_character_allowed_for_side(index, side):
			continue
		var texture = game.draft_character_cards[index].texture
		var character_name: String = game._get_character_name_for_texture(texture)
		var attributes: Array = game._get_character_attributes(character_name)
		var new_attributes: = 0
		var candidate_attributes: Dictionary = {}
		for attribute in attributes:
			if not covered.has(attribute) and not candidate_attributes.has(attribute):
				new_attributes += 1
			candidate_attributes[attribute] = true
		var distinct_bonus: = 1.0 if attributes.size() >= 2 and attributes[0] != attributes[1] else 0.35
		var score: = float(new_attributes) * 12.0 * float(profile.draft_coverage)
		score += distinct_bonus * 3.0 * float(profile.draft_variety)
		score += randf_range(0.0, float(profile.draft_noise))
		if score > best_score:
			best_score = score
			best_index = index
	return best_index


func _star_draft_step() -> void :
	var side: int = game._get_current_turn_side()
	if game.is_player_bot(side) and not game.star_draft_busy and not game.draft_stars.is_empty():
		await _think()
		if game.star_draft_active and game._get_current_turn_side() == side:
			game._take_star(randi_range(0, game.draft_stars.size() - 1))
	else:
		await get_tree().process_frame


func _challenge_step() -> void :
	if (game.challenge_opener_side < 0
		or not game.is_player_bot(game.challenge_opener_side)
		or game.challenge_card_busy):
		await get_tree().process_frame
		return
	if not game.challenge_card_face_up:
		await _think()
		if game.challenge_phase_active and not game.challenge_card_busy:
			game._reveal_random_challenge()
		_challenge_waited = false
		return
	if not _challenge_waited:
		_challenge_waited = true
		await get_tree().create_timer(3.0).timeout
	if game.challenge_phase_active and game.challenge_card_face_up and not game.challenge_card_busy:
		game._start_selected_challenge()


func _challenge_movement_step() -> void :
	var side: int = game._get_current_turn_side()
	if not game.is_player_bot(side) or game.dragged_mini_index >= 0:
		await get_tree().process_frame
		return
	var choices: Array[int] = []
	for index in game.character_minis_on_board.size():
		var mini = game.character_minis_on_board[index]
		if (mini.owner_side == side and mini.matching_attributes > 0
			and mini.current_column != mini.target_column and not mini.moving):
			choices.append(index)
	if choices.is_empty():
		await get_tree().process_frame
		return
	var profile: = _get_bot_profile(side)
	var chosen_mini: int = choices.pick_random()
	if randf() < float(profile.prediction):
		var best_score: = - INF
		for mini_index in choices:
			var mini = game.character_minis_on_board[mini_index]
			var overrides: Dictionary = {}
			overrides[mini_index] = {"column": mini.target_column, "row": mini.row}
			var score: = _team_position_score(side, overrides)
			if score > best_score:
				best_score = score
				chosen_mini = mini_index
	await _look_at_character(chosen_mini)
	await _think()
	if game.character_movement_phase_active and game._get_current_turn_side() == side:
		await game.bot_animate_challenge_move(chosen_mini)


func _card_phase_step() -> void :
	if game.card_turn_serial != _seen_card_turn:
		_seen_card_turn = game.card_turn_serial
		_inspection_step = 0
		_alliance_key = ""
		_alliance_offer_attempts.clear()
		_pending_bot_offers.clear()
		_last_rejected_offer.clear()
		_reset_alliance_evaluations()
		_reset_alliance_thinking_cache()
		_reset_card_play_evaluation()
		_planned_swap_target_mini = -1

	if game.die_roll_active:
		await _die_step()
		return
	if game.alliance_target_character_index >= 0:
		await _alliance_step()
		return
	if game.swap_drag_active:
		await _swap_step()
		return
	if game.pending_effect_move_active:
		await _effect_move_step()
		return
	if game.card_effect_busy:
		await get_tree().process_frame
		return

	var side: int = game._get_current_turn_side()
	if not game.is_player_bot(side):
		await get_tree().process_frame
		return
	var profile: = _get_bot_profile(side)


	var inspection_count: int = int(profile.inspection_count)
	if _inspection_step < inspection_count:
		await _inspect_hand(side)
		_inspection_step += 1
		return



	var outlook_sides: Array[int] = [side]
	_prepare_alliance_outlook_jobs(outlook_sides)
	if _advance_alliance_outlook_jobs():
		await get_tree().process_frame
		return

	if _advance_card_play_evaluation(side):
		await get_tree().process_frame
		return
	var play: Dictionary = _card_eval_choice
	var should_buy: = _should_buy_scene_card(side)
	if should_buy:
		await _think()
		if game.card_play_phase_active and game._get_current_turn_side() == side:
			await _buy_scene_card_and_stack_on_top(side)
			_reset_card_play_evaluation()
			_reset_alliance_thinking_cache()
		return
	var rejects_bad_action: = (randf() < float(profile.reject_bad_actions)
		and not play.is_empty()
		and float(play.get("score", - INF)) <= 0.0)
	var will_pass: = play.is_empty() or rejects_bad_action or randf() < float(profile.pass_chance)
	if not will_pass:
		_planned_swap_target_mini = int(play.get("swap_target", -1))
		await _prepare_scene_card_for_play(side, play.card)
	await _think()
	if not game.card_play_phase_active or game._get_current_turn_side() != side:
		return
	if will_pass:
		game._pass_card_turn()
	else:
		var card_index: int = int(play.card)
		var character_index: int = int(play.character)
		if (card_index < 0
			or card_index >= game.dealt_scene_cards.size()
			or game.dealt_scene_cards[card_index].owner_side != side
			or character_index < 0
			or character_index >= game.player_character_cards.size()
			or not game._is_scene_card_legal_for_character(card_index, character_index)):
			_reset_card_play_evaluation()
			return
		await game.bot_animate_scene_card_play(card_index, character_index)


func _prepare_scene_card_for_play(side: int, card_index: int) -> void :
	if card_index < 0 or card_index >= game.dealt_scene_cards.size():
		return
	await _cycle_to_scene_card(side, card_index)
	if (card_index < game.dealt_scene_cards.size()
		and not game.dealt_scene_cards[card_index].revealed
		and not game.dealt_scene_cards[card_index].flipping):
		game._flip_dealt_scene_card(card_index)
		await get_tree().create_timer(0.36).timeout


func _buy_scene_card_and_stack_on_top(side: int) -> void :
	var previous_numbers: Array[int] = []
	for card_index in game._get_owner_scene_card_indices(side):
		previous_numbers.append(int(game.dealt_scene_cards[card_index].get("card_number", 0)))
	await game._try_buy_scene_card(side)
	if not game.card_play_phase_active or game._get_current_turn_side() != side:
		return
	var purchased_index: = -1
	for card_index in game._get_owner_scene_card_indices(side):
		var number: = int(game.dealt_scene_cards[card_index].get("card_number", 0))
		if not previous_numbers.has(number):
			purchased_index = card_index
			break
	if purchased_index < 0:
		return


	await _cycle_to_scene_card(side, purchased_index)


func _cycle_to_scene_card(side: int, target_card: int) -> void :
	var indices: Array[int] = game._get_owner_scene_card_indices(side)
	var safety: = indices.size()
	while safety > 0 and not indices.is_empty():
		var selected: int = indices[game.scene_cycle_indices[side] %indices.size()]
		if selected == target_card:
			return
		if game.scene_cycle_busy[side]:
			await get_tree().create_timer(0.05).timeout
		else:
			game._animate_hand_cycle(side, true, indices.size())
			await get_tree().create_timer(0.3).timeout
		indices = game._get_owner_scene_card_indices(side)
		safety -= 1


func _inspect_hand(side: int) -> void :
	var scene_indices: Array[int] = game._get_owner_scene_card_indices(side)


	if scene_indices.size() > 1 and not game.scene_cycle_busy[side]:
		game._animate_hand_cycle(side, true, scene_indices.size())
		await get_tree().create_timer(0.3).timeout
	if randf() < 0.65:
		await _look_at_character_hand(side)


func _look_at_character_hand(side: int) -> void :
	var indices: Array[int] = game._get_owner_character_card_indices(side)
	if indices.size() > 1 and not game.character_cycle_busy[side]:
		game._animate_hand_cycle(side, false, indices.size())
		await get_tree().create_timer(0.3).timeout


func _look_at_character(mini_index: int) -> void :
	if mini_index < 0 or mini_index >= game.character_minis_on_board.size():
		return
	var mini = game.character_minis_on_board[mini_index]
	var side: int = mini.owner_side
	var target_card: = -1
	for card_index in game._get_owner_character_card_indices(side):
		if game._get_character_name_from_card(card_index) == mini.character_name:
			target_card = card_index
			break
	if target_card < 0:
		return
	var indices: Array[int] = game._get_owner_character_card_indices(side)
	var safety: = indices.size()
	while safety > 0 and not indices.is_empty():
		var selected: int = indices[game.character_cycle_indices[side] %indices.size()]
		if selected == target_card:
			break
		if game.character_cycle_busy[side]:
			await get_tree().create_timer(0.05).timeout
		else:
			game._animate_hand_cycle(side, false, indices.size())
			await get_tree().create_timer(0.3).timeout
		indices = game._get_owner_character_card_indices(side)
		safety -= 1
	await get_tree().create_timer(0.1).timeout


func _choose_scene_card_play(side: int) -> Dictionary:
	var profile: = _get_bot_profile(side)
	var candidates: Array[Dictionary] = []
	for card_index in game._get_owner_scene_card_indices(side):
		var kind: String = game._get_scene_card_kind(game.dealt_scene_cards[card_index].texture)
		for character_index in game.player_character_cards.size():
			if not game._is_scene_card_legal_for_character(card_index, character_index):
				continue
			var mini_index: int = game._find_mini_for_character_card(character_index)
			if mini_index < 0:
				continue
			var mini = game.character_minis_on_board[mini_index]
			var owns_character: bool = mini.owner_side == side
			var evaluation: = _evaluate_optimal_card(side, card_index, mini_index)
			var score: = float(evaluation.score) * float(profile.prediction)
			var swap_target: = int(evaluation.get("swap_target", -1)) if randf() < float(profile.prediction) else -1
			score += randf_range(0.0, float(profile.action_noise))
			score += float(profile.own_character_bias) if owns_character else float(profile.other_character_bias)
			if kind in ["boost", "special_boost"]:
				score += float(game.BOARD_COLUMNS - 1 - mini.current_column) * float(profile.boost_bias)
			elif kind == "win_token":
				score += float(profile.win_token_bias)
			elif kind == "development":
				var attribute: String = game._get_scene_card_attribute(game.dealt_scene_cards[card_index].texture)
				score += float(profile.development_bias)
				if game.current_challenge.get("attributes", []).has(attribute):
					score += float(profile.matching_development_bias)
			elif kind == "swap":
				score += float(profile.swap_bias)
			candidates.append({
				"card": card_index, 
				"character": character_index, 
				"score": score, 
				"swap_target": swap_target, 
			})
	if candidates.is_empty():
		return {}
	candidates.sort_custom( func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.score) > float(b.score)
	)
	var chosen: Dictionary = candidates[0] if randf() < float(profile.choose_best_chance) else candidates.pick_random()
	return {
		"card": chosen.card, 
		"character": chosen.character, 
		"swap_target": chosen.get("swap_target", -1), 
		"score": chosen.score, 
	}


func _reset_card_play_evaluation() -> void :
	_card_eval_turn = -1
	_card_eval_side = -1
	_card_eval_cards.clear()
	_card_eval_card_slot = 0
	_card_eval_character_index = 0
	_card_eval_candidates.clear()
	_card_eval_choice.clear()
	_card_eval_best_raw_score = - INF
	_card_eval_finished = false


func _advance_card_play_evaluation(side: int) -> bool:
	if _card_eval_turn != game.card_turn_serial or _card_eval_side != side:
		_reset_card_play_evaluation()
		_card_eval_turn = game.card_turn_serial
		_card_eval_side = side
		_card_eval_cards = game._get_owner_scene_card_indices(side)
	if _card_eval_finished:
		return false
	var profile: = _get_bot_profile(side)
	var started_usec: = Time.get_ticks_usec()
	while _card_eval_card_slot < _card_eval_cards.size():
		var card_index: int = _card_eval_cards[_card_eval_card_slot]
		if card_index < 0 or card_index >= game.dealt_scene_cards.size():
			_card_eval_card_slot += 1
			_card_eval_character_index = 0
			continue
		if _card_eval_character_index >= game.player_character_cards.size():
			_card_eval_card_slot += 1
			_card_eval_character_index = 0
			continue
		var character_index: = _card_eval_character_index
		_card_eval_character_index += 1
		if game._is_scene_card_legal_for_character(card_index, character_index):
			var mini_index: int = game._find_mini_for_character_card(character_index)
			if mini_index >= 0:
				var mini = game.character_minis_on_board[mini_index]
				var texture = game.dealt_scene_cards[card_index].texture
				var kind: String = game._get_scene_card_kind(texture)
				var evaluation: = _evaluate_optimal_card(side, card_index, mini_index)
				_card_eval_best_raw_score = maxf(
					_card_eval_best_raw_score, 
					float(evaluation.score)
				)
				var score: = float(evaluation.score) * float(profile.prediction)
				var swap_target: = (
					int(evaluation.get("swap_target", -1))
					if randf() < float(profile.prediction) else -1
				)
				score += randf_range(0.0, float(profile.action_noise))
				score += (
					float(profile.own_character_bias)
					if mini.owner_side == side else float(profile.other_character_bias)
				)
				if kind in ["boost", "special_boost"]:
					score += float(game.BOARD_COLUMNS - 1 - mini.current_column) * float(profile.boost_bias)
				elif kind == "win_token":
					score += float(profile.win_token_bias)
				elif kind == "development":
					var attribute: String = game._get_scene_card_attribute(texture)
					score += float(profile.development_bias)
					if game.current_challenge.get("attributes", []).has(attribute):
						score += float(profile.matching_development_bias)
				elif kind == "swap":
					score += float(profile.swap_bias)
				_card_eval_candidates.append({
					"card": card_index, 
					"character": character_index, 
					"score": score, 
					"swap_target": swap_target, 
				})
		if Time.get_ticks_usec() - started_usec >= CARD_THINK_FRAME_BUDGET_USEC:
			return true

	_card_eval_finished = true
	if _card_eval_candidates.is_empty():
		_card_eval_choice = {}
		return false
	_card_eval_candidates.sort_custom( func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.score) > float(b.score)
	)
	var chosen: Dictionary = (
		_card_eval_candidates[0]
		if randf() < float(profile.choose_best_chance)
		else _card_eval_candidates.pick_random()
	)
	_card_eval_choice = {
		"card": chosen.card, 
		"character": chosen.character, 
		"swap_target": chosen.get("swap_target", -1), 
		"score": chosen.score, 
	}
	return false


func _evaluate_optimal_card(side: int, card_index: int, mini_index: int) -> Dictionary:
	return _evaluate_card_texture(side, game.dealt_scene_cards[card_index].texture, mini_index)


func _evaluate_card_texture(side: int, texture, mini_index: int) -> Dictionary:
	var mini = game.character_minis_on_board[mini_index]
	var kind: String = game._get_scene_card_kind(texture)
	var before: = _team_position_score(side)
	var overrides: Dictionary = {}
	var swap_target: = -1
	var score: = -900.0
	match kind:
		"boost":
			if mini.owner_side == side:



				score = 0.0
				for amount in range(1, 4):
					var weight: float = [0.0, 3.0, 2.0, 1.0][amount]
					overrides = {}
					overrides[mini_index] = {
						"column": min(mini.current_column + amount, game.BOARD_COLUMNS - 1), 
						"row": mini.row, 
					}
					score += (_team_position_score(side, overrides) - before) * weight / 6.0
		"special_boost":
			if mini.owner_side == side:
				overrides[mini_index] = {
					"column": min(mini.current_column + 3, game.BOARD_COLUMNS - 1), 
					"row": mini.row, 
				}
				score = _team_position_score(side, overrides) - before
		"development":
			if mini.owner_side == side:
				var attribute: String = game._get_scene_card_attribute(texture)
				score = _evaluate_development_target(side, mini_index, attribute)
		"win_token":
			if mini.owner_side == side:
				if _is_bottom_three(mini_index):
					var profile: = _get_bot_profile(side)
					var risk: = (float(profile.last_character_bottom_penalty)
						if _owned_mini_count(side) == 1 else float(profile.bottom_three_penalty))
					score = risk * (1.0 - float(profile.win_token_risk_multiplier))
				else:
					score = 35.0
		"swap":
			var best_swap: = _best_swap_for_source(side, mini_index)
			score = float(best_swap.score)
			swap_target = int(best_swap.get("target", -1))
	return {"score": score, "swap_target": swap_target}


func _evaluate_development_target(side: int, mini_index: int, attribute: String) -> float:
	var mini = game.character_minis_on_board[mini_index]
	if mini.current_column >= game.BOARD_COLUMNS - 1:
		return -900.0
	var profile: = _get_bot_profile(side)
	var attributes: Array = game._get_character_attributes(mini.character_name)
	attributes.append_array(mini.get("development_attributes", []))
	var already_has_attribute: = attributes.has(attribute)
	var current_matches = game.current_challenge.get("attributes", []).has(attribute)
	var immediate_overrides: Dictionary = {}
	var immediate_column: int = mini.current_column
	if current_matches:
		immediate_column = min(mini.current_column + 1, game.BOARD_COLUMNS - 1)
		immediate_overrides[mini_index] = {"column": immediate_column, "row": mini.row}
	var immediate_value: = (_team_position_score(side, immediate_overrides)
		- _team_position_score(side))
	var remaining_columns: int = game.BOARD_COLUMNS - 1 - immediate_column




	var useful_challenges: = 0
	var coverage_challenges: = 0
	var challenge_pool: Array[Dictionary] = game._get_active_challenge_pool()
	for challenge in challenge_pool:
		var challenge_attributes: Array = challenge.get("attributes", [])
		if not challenge_attributes.has(attribute):
			continue
		var existing_matches: = 0
		for existing_attribute in attributes:
			if challenge_attributes.has(existing_attribute):
				existing_matches += 1
		if existing_matches < remaining_columns:
			useful_challenges += 1
		if existing_matches == 0:
			coverage_challenges += 1
	var challenge_count: int = max(challenge_pool.size(), 1)
	var marginal_move_chance: = float(useful_challenges) / float(challenge_count)
	var coverage_chance: = float(coverage_challenges) / float(challenge_count)
	var projected_survival: = _development_survival_probability(mini_index, immediate_overrides)
	projected_survival = lerpf(1.0, projected_survival, float(profile.development_survival_weight))
	var estimated_rounds: = (float(clampi(game.character_minis_on_board.size() - 1, 1, 8))
		* float(profile.development_horizon))
	var expected_future_steps = min(
		float(remaining_columns), 
		marginal_move_chance * estimated_rounds * projected_survival
	)
	var future_value = expected_future_steps * float(profile.column_value)
	if remaining_columns > 0:
		future_value += (expected_future_steps / float(remaining_columns)
			* float(profile.final_column_bonus) * 0.5)
	var coverage_value: = 0.0
	if not already_has_attribute:
		coverage_value = (coverage_chance * float(profile.development_coverage_bonus)
			* estimated_rounds * projected_survival)

	var development_count: int = mini.get("development_attributes", []).size()
	var least_developed: = development_count
	for other_mini in game.character_minis_on_board:
		if other_mini.owner_side == side:
			least_developed = min(
				least_developed, 
				other_mini.get("development_attributes", []).size()
			)
	var overinvestment = max(development_count - least_developed, 0)
	var overinvestment_penalty: = (float(overinvestment)
		* float(profile.development_overinvestment_penalty))
	return immediate_value + future_value + coverage_value - overinvestment_penalty


func _development_survival_probability(mini_index: int, overrides: Dictionary) -> float:
	var order: Array[int] = []
	for index in game.character_minis_on_board.size():
		order.append(index)
	order.sort_custom( func(a: int, b: int) -> bool:
		var a_state: = _projected_mini_state(a, overrides)
		var b_state: = _projected_mini_state(b, overrides)
		if int(a_state.column) != int(b_state.column):
			return int(a_state.column) > int(b_state.column)
		return int(a_state.row) < int(b_state.row)
	)
	var rank: int = order.find(mini_index)
	var distance_from_bottom: = order.size() - 1 - rank
	var survival: = 0.48 if distance_from_bottom < 3 else 0.76 if distance_from_bottom < 6 else 0.94
	if game.character_minis_on_board[mini_index].get("has_win_token", false):
		survival = min(survival + 0.18, 1.0)
	return survival


func _best_swap_for_source(side: int, source_index: int) -> Dictionary:
	var source = game.character_minis_on_board[source_index]
	var before: = _team_position_score(side)
	var best_score: = -900.0
	var best_target: = -1
	for target_index in game.character_minis_on_board.size():
		if target_index == source_index:
			continue
		var target = game.character_minis_on_board[target_index]
		if target.current_column != source.current_column:
			continue
		var overrides: Dictionary = {}
		overrides[source_index] = {"column": source.current_column, "row": target.row}
		overrides[target_index] = {"column": target.current_column, "row": source.row}
		var improvement: = _team_position_score(side, overrides) - before
		if improvement > best_score:
			best_score = improvement
			best_target = target_index
	return {"score": best_score, "target": best_target}


func _team_position_score(side: int, overrides: Dictionary = {}) -> float:
	var profile: = _get_bot_profile(side)
	var owned_count: = 0
	for mini in game.character_minis_on_board:
		if mini.owner_side == side:
			owned_count += 1
	var final_survivor: = owned_count == 1
	var order: Array[int] = []
	for index in game.character_minis_on_board.size():
		order.append(index)
	order.sort_custom( func(a: int, b: int) -> bool:
		var a_state: = _projected_mini_state(a, overrides)
		var b_state: = _projected_mini_state(b, overrides)
		if int(a_state.column) != int(b_state.column):
			return int(a_state.column) > int(b_state.column)
		return int(a_state.row) < int(b_state.row)
	)
	var bottom_start = max(order.size() - 3, 0)
	var score: = 0.0
	for rank in order.size():
		var mini_index: int = order[rank]
		var mini = game.character_minis_on_board[mini_index]
		if mini.owner_side != side:
			continue
		var state: = _projected_mini_state(mini_index, overrides)


		var position_value: = float(state.column) * float(profile.column_value)
		position_value -= float(state.row) * float(profile.row_value)
		if int(state.column) == game.BOARD_COLUMNS - 1:
			position_value += float(profile.final_column_bonus)
		if final_survivor:
			position_value *= float(profile.last_character_position_multiplier)
		score += position_value
		if rank >= bottom_start:
			var risk_penalty: = (float(profile.last_character_bottom_penalty)
				if final_survivor else float(profile.bottom_three_penalty))
			risk_penalty += float(rank - bottom_start) * float(profile.bottom_rank_penalty)
			if mini.get("has_win_token", false):
				risk_penalty *= float(profile.win_token_risk_multiplier)
			score -= risk_penalty
	return score


func _projected_mini_state(mini_index: int, overrides: Dictionary) -> Dictionary:
	if overrides.has(mini_index):
		var overridden: Dictionary = overrides[mini_index]
		return overridden
	var mini = game.character_minis_on_board[mini_index]
	return {"column": mini.current_column, "row": mini.row}


func _is_bottom_three(mini_index: int) -> bool:
	var order: Array[int] = []
	for index in game.character_minis_on_board.size():
		order.append(index)
	order.sort_custom( func(a: int, b: int) -> bool:
		var a_mini = game.character_minis_on_board[a]
		var b_mini = game.character_minis_on_board[b]
		if a_mini.current_column != b_mini.current_column:
			return a_mini.current_column > b_mini.current_column
		return a_mini.row < b_mini.row
	)
	return order.find(mini_index) >= max(order.size() - 3, 0)


func _owned_mini_count(side: int) -> int:
	var count: = 0
	for mini in game.character_minis_on_board:
		if mini.owner_side == side:
			count += 1
	return count


func _get_bot_profile(side: int) -> Dictionary:
	if force_optimal_values:
		return _make_optimal_profile()
	if not _bot_profiles.has(side):
		_bot_profiles[side] = _make_random_profile()
	return _bot_profiles[side]


func _make_optimal_profile() -> Dictionary:
	return {
		"prediction": 1.0, 
		"column_value": 220.0, 
		"row_value": 12.0, 
		"final_column_bonus": 350.0, 
		"bottom_three_penalty": 520.0, 
		"bottom_rank_penalty": 120.0, 
		"last_character_position_multiplier": 1.8, 
		"last_character_bottom_penalty": 1900.0, 
		"win_token_risk_multiplier": 0.35, 
		"endangered_resource_realization": 0.3, 
		"choose_best_chance": 1.0, 
		"reject_bad_actions": 1.0, 
		"action_noise": 0.0, 
		"own_character_bias": 0.0, 
		"other_character_bias": 0.0, 
		"boost_bias": 0.0, 
		"win_token_bias": 0.0, 
		"development_bias": 0.0, 
		"matching_development_bias": 0.0, 
		"development_horizon": 1.0, 
		"development_coverage_bonus": 24.0, 
		"development_overinvestment_penalty": 18.0, 
		"development_survival_weight": 1.0, 
		"swap_bias": 0.0, 
		"draft_coverage": 1.0, 
		"draft_variety": 1.0, 
		"draft_noise": 0.0, 
		"inspection_count": 3, 
		"buy_chance": 1.0, 
		"buy_improvement_ratio": 1.0, 
		"minimum_useful_draw_probability": 0.35, 
		"pass_chance": 0.0, 
		"offer_chance": 1.0, 
		"maximum_offers": 5, 
		"star_value": 1.0, 
		"star_liquidity": 6.0, 
		"partial_purchase_value": 0.25, 
		"draw_probability_weight": 1.0, 
		"future_card_realization": 0.72, 
		"hand_saturation": 0.12, 
		"card_need_threshold": 0.0, 
		"opponent_threat_weight": 1.0, 
		"opponent_progress_weight": 1.0, 
		"opponent_star_gain_weight": 1.0, 
		"offer_margin": 0.0, 
		"accept_margin": 0.0, 
		"rejection_increment": 1, 
		"alliance_evaluation_noise": 0.0, 
		"alliance_move_prediction": 1.0, 
	}


func _make_random_profile() -> Dictionary:
	return {
		"prediction": randf_range(0.0, 1.0), 
		"column_value": randf_range(120.0, 250.0), 
		"row_value": randf_range(2.0, 16.0), 
		"final_column_bonus": randf_range(80.0, 390.0), 
		"bottom_three_penalty": randf_range(80.0, 560.0), 
		"bottom_rank_penalty": randf_range(10.0, 140.0), 
		"last_character_position_multiplier": randf_range(1.0, 2.2), 
		"last_character_bottom_penalty": randf_range(600.0, 2200.0), 
		"win_token_risk_multiplier": randf_range(0.2, 0.75), 
		"endangered_resource_realization": randf_range(0.18, 0.7), 
		"choose_best_chance": randf_range(0.15, 1.0), 
		"reject_bad_actions": randf_range(0.0, 1.0), 
		"action_noise": randf_range(0.0, 7.0), 
		"own_character_bias": randf_range(-1.0, 6.0), 
		"other_character_bias": randf_range(-2.0, 5.0), 
		"boost_bias": randf_range(-0.5, 2.0), 
		"win_token_bias": randf_range(-1.0, 6.0), 
		"development_bias": randf_range(-1.0, 6.0), 
		"matching_development_bias": randf_range(0.0, 5.0), 
		"development_horizon": randf_range(0.25, 1.35), 
		"development_coverage_bonus": randf_range(0.0, 45.0), 
		"development_overinvestment_penalty": randf_range(0.0, 35.0), 
		"development_survival_weight": randf_range(0.25, 1.25), 
		"swap_bias": randf_range(-1.0, 5.0), 
		"draft_coverage": randf_range(0.0, 1.0), 
		"draft_variety": randf_range(0.0, 1.0), 
		"draft_noise": randf_range(0.0, 8.0), 
		"inspection_count": randi_range(0, 4), 
		"buy_chance": randf_range(0.05, 0.75), 
		"buy_improvement_ratio": randf_range(0.35, 2.0), 
		"minimum_useful_draw_probability": randf_range(0.05, 0.85), 
		"pass_chance": randf_range(0.0, 0.35), 
		"offer_chance": randf_range(0.05, 0.85), 
		"maximum_offers": randi_range(1, 5), 
		"star_value": randf_range(0.55, 1.65), 
		"star_liquidity": randf_range(0.0, 28.0), 
		"partial_purchase_value": randf_range(0.05, 0.85), 
		"draw_probability_weight": randf_range(0.25, 1.75), 
		"future_card_realization": randf_range(0.3, 1.0), 
		"hand_saturation": randf_range(0.0, 0.35), 
		"card_need_threshold": randf_range(-60.0, 180.0), 
		"opponent_threat_weight": randf_range(0.35, 1.75), 
		"opponent_progress_weight": randf_range(0.0, 1.25), 
		"opponent_star_gain_weight": randf_range(0.0, 1.25), 
		"offer_margin": randf_range(-30.0, 90.0), 
		"accept_margin": randf_range(-30.0, 90.0), 
		"rejection_increment": randi_range(1, 3), 
		"alliance_evaluation_noise": randf_range(0.0, 180.0), 
		"alliance_move_prediction": randf_range(0.0, 1.0), 
	}


func _die_step() -> void :
	var roller = game.elimination_leader_side if game.elimination_phase_active else game._get_current_turn_side()
	if game.is_player_bot(roller) and not game.die_roll_busy:
		var turn_serial: int = game.card_turn_serial
		await _think()
		if game.elimination_phase_active and game.elimination_die_ready:
			game._roll_elimination_die()
		elif (game.card_play_phase_active
			and game.card_turn_serial == turn_serial
			and game._get_current_turn_side() == roller
			and game.die_roll_active
			and not game.die_roll_busy):
			game._roll_die()
	else:
		await get_tree().process_frame


func _alliance_step() -> void :


	if game.effect_move_animation_busy or game.dragged_mini_index >= 0:
		await get_tree().process_frame
		return
	_resolve_finished_bot_offers()


	var key: = "%s:%s:%s:%s" % [
		game.card_turn_serial, 
		game.alliance_target_character_index, 
		game.alliance_offer_side, 
		game.alliance_offer_stars, 
	]
	if key != _alliance_key:
		_alliance_key = key
		_alliance_ready_at = (
			Time.get_ticks_msec() + int(ALLIANCE_WAIT * 1000.0)
			if (game.alliance_offer_side >= 0
				or game._has_any_eligible_alliance_offerer())
			else Time.get_ticks_msec()
		)




	_prepare_alliance_outlook_jobs(game.player_order)
	if _advance_alliance_outlook_jobs():
		await get_tree().process_frame
		return

	if game.alliance_offer_side >= 0:
		if game.is_player_bot(game.alliance_active_side) and Time.get_ticks_msec() >= _alliance_ready_at:
			if _should_accept_alliance_offer(game.alliance_active_side):
				await game._accept_alliance_offer()
			else:
				await game._reject_alliance_offer()
			_resolve_finished_bot_offers()
		else:
			await get_tree().process_frame
		return


	var offering_bots: Array[int] = []
	for side in game.player_order:
		if (game.is_player_bot(side)
			and game._is_player_eligible_to_offer_alliance(side)
			and _bot_can_offer_again(side)):
			offering_bots.append(side)





	var evaluation_key: = _get_alliance_evaluation_key(offering_bots)
	if evaluation_key != _alliance_evaluation_key:
		_alliance_evaluation_key = evaluation_key
		_alliance_evaluation_queue = offering_bots.duplicate()
		_alliance_evaluation_results.clear()
	if not _alliance_evaluation_queue.is_empty():
		var candidate_side = _alliance_evaluation_queue.pop_front()
		var profile: = _get_bot_profile(candidate_side)
		if randf() <= float(profile.offer_chance):
			_alliance_evaluation_results[candidate_side] = _choose_alliance_offer(candidate_side)
		else:
			_alliance_evaluation_results[candidate_side] = {
				"amount": 0, 
				"utility": - INF, 
			}
		await get_tree().process_frame
		return

	var offerer: = -1
	var offer_amount: = 0
	var best_offer_utility: = - INF
	for candidate_side in offering_bots:
		if not _alliance_evaluation_results.has(candidate_side):
			continue
		var proposal: Dictionary = _alliance_evaluation_results[candidate_side]
		if int(proposal.amount) > 0 and float(proposal.utility) > best_offer_utility:
			offerer = candidate_side
			offer_amount = int(proposal.amount)
			best_offer_utility = float(proposal.utility)
	if offerer >= 0:


		if Time.get_ticks_msec() < _alliance_ready_at:
			await get_tree().process_frame
			return
		_reset_alliance_evaluations()
		_alliance_offer_attempts[offerer] = int(_alliance_offer_attempts.get(offerer, 0)) + 1
		_pending_bot_offers[offerer] = offer_amount
		for _star_index in offer_amount:
			if not game._is_player_eligible_to_offer_alliance(offerer):
				break
			game._add_star_to_alliance_offer(offerer)
			await get_tree().create_timer(0.24).timeout
		return



	if (Time.get_ticks_msec() < _alliance_ready_at
		or Time.get_ticks_msec() < game.alliance_movement_unlock_time):
		await get_tree().process_frame
		return


	for ally_side in game.alliance_accepted_sides:
		if game.is_player_bot(ally_side) and ally_side not in game.alliance_moved_sides:
			var ally_mini: = _find_alliance_mini(ally_side)
			if ally_mini >= 0:
				var alliance_character = game.alliance_target_character_index
				await _think()
				if (game.alliance_target_character_index != alliance_character
					or ally_side not in game.alliance_accepted_sides
					or ally_side in game.alliance_moved_sides
					or ally_mini < 0
					or ally_mini >= game.character_minis_on_board.size()
					or game.character_minis_on_board[ally_mini].owner_side != ally_side
					or game.character_minis_on_board[ally_mini].current_column != game.alliance_origin_column
					or game.effect_move_animation_busy
					or game.dragged_mini_index >= 0):
					return
				await game.bot_animate_effect_move(ally_mini)
				return

	if (game.is_player_bot(game.alliance_active_side) and not game.alliance_main_move_done
		and Time.get_ticks_msec() >= _alliance_ready_at):
		if game.effect_move_animation_busy or game.dragged_mini_index >= 0:
			return
		await game.bot_animate_effect_move(game.alliance_target_mini_index)
		return
	await get_tree().process_frame


func _get_alliance_evaluation_key(offering_bots: Array[int]) -> String:
	var star_counts: Array[int] = []
	for side in game.player_order:
		star_counts.append(game._get_owner_star_count(side))
	return str([
		game.card_turn_serial, 
		game.alliance_target_character_index, 
		game.alliance_active_side, 
		game.alliance_origin_column, 
		game.alliance_move_amount, 
		offering_bots, 
		star_counts, 
		game.alliance_accepted_sides, 
		game.alliance_moved_sides, 
		_alliance_offer_attempts, 
		_last_rejected_offer, 
	])


func _reset_alliance_evaluations() -> void :
	_alliance_evaluation_key = ""
	_alliance_evaluation_queue.clear()
	_alliance_evaluation_results.clear()


func _reset_alliance_thinking_cache() -> void :
	_alliance_outlook_key = ""
	_alliance_outlook_jobs.clear()
	_alliance_outlook_cache.clear()
	_alliance_star_value_cache.clear()


func _prepare_alliance_outlook_jobs(sides: Array[int]) -> void :
	var state_key: = "%s:%s:%s:%s" % [
		game.card_turn_serial, 
		game.alliance_target_character_index, 
		game.alliance_origin_column, 
		game.alliance_move_amount, 
	]
	if state_key != _alliance_outlook_key:
		_reset_alliance_thinking_cache()
		_alliance_outlook_key = state_key
	for side in sides:
		if _alliance_outlook_cache.has(side) or _alliance_outlook_jobs.has(side):
			continue
		var scene_pool: Array[Texture2D] = game._get_scene_card_types_for_side(side)
		var texture_counts: Dictionary = {}
		for texture in scene_pool:
			texture_counts[texture] = int(texture_counts.get(texture, 0)) + 1
		_alliance_outlook_jobs[side] = {
			"side": side, 
			"textures": texture_counts.keys(), 
			"counts": texture_counts, 
			"card_count": scene_pool.size(), 
			"texture_index": 0, 
			"mini_index": 0, 
			"best_score": - INF, 
			"useful_cards": 0, 
			"total_positive_points": 0.0, 
		}


func _advance_alliance_outlook_jobs() -> bool:
	if _alliance_outlook_jobs.is_empty():
		return false
	var started_usec: = Time.get_ticks_usec()
	while not _alliance_outlook_jobs.is_empty():
		var side: int = int(_alliance_outlook_jobs.keys()[0])
		var job: Dictionary = _alliance_outlook_jobs[side]
		var textures: Array = job.textures
		if int(job.texture_index) >= textures.size():
			var useful_cards: int = int(job.useful_cards)
			var card_count: int = int(job.card_count)
			var probability: = (
				float(useful_cards) / float(card_count) if card_count > 0 else 0.0
			)
			var average_value: = (
				float(job.total_positive_points) / float(useful_cards)
				if useful_cards > 0 else 0.0
			)
			_alliance_outlook_cache[side] = {
				"probability": probability, 
				"expected_value": average_value * probability, 
			}
			_alliance_outlook_jobs.erase(side)
			continue

		var texture = textures[int(job.texture_index)]
		var mini_index: int = int(job.mini_index)
		if mini_index < game.character_minis_on_board.size():
			if _is_virtual_scene_card_legal(texture, mini_index):
				var evaluation: = _evaluate_card_texture(side, texture, mini_index)
				job.best_score = maxf(float(job.best_score), float(evaluation.score))
			job.mini_index = mini_index + 1
		else:
			var profile: = _get_bot_profile(side)
			if float(job.best_score) > float(profile.card_need_threshold):
				var copies: int = int(job.counts[texture])
				job.useful_cards = int(job.useful_cards) + copies
				job.total_positive_points = (
					float(job.total_positive_points)
					+ maxf(float(job.best_score), 0.0) * float(copies)
				)
			job.texture_index = int(job.texture_index) + 1
			job.mini_index = 0
			job.best_score = - INF
		_alliance_outlook_jobs[side] = job
		if Time.get_ticks_usec() - started_usec >= ALLIANCE_THINK_FRAME_BUDGET_USEC:
			return true
	return false


func _resolve_finished_bot_offers() -> void :
	if game.alliance_offer_side >= 0 or _pending_bot_offers.is_empty():
		return
	for offerer_value in _pending_bot_offers.keys().duplicate():
		var offerer: int = int(offerer_value)
		var amount: int = int(_pending_bot_offers[offerer])
		if offerer not in game.alliance_accepted_sides:


			_last_rejected_offer[offerer] = max(int(_last_rejected_offer.get(offerer, 0)), amount)
		_pending_bot_offers.erase(offerer)
	_reset_alliance_evaluations()


func _star_inventory_value(side: int, star_count: int) -> float:
	if star_count <= 0:
		return 0.0
	var cache_key: = "%d:%d" % [side, star_count]
	if game.alliance_target_character_index >= 0 and _alliance_star_value_cache.has(cache_key):
		return float(_alliance_star_value_cache[cache_key])
	var profile: = _get_bot_profile(side)
	var outlook: = _scene_card_draw_outlook(side)
	var completed_buys: = int(star_count / 3)
	var remainder: = star_count % 3
	var purchase_value: = (float(outlook.expected_value)
		* float(profile.draw_probability_weight)
		* float(profile.future_card_realization))
	var hand_size: int = game._get_owner_scene_card_indices(side).size()
	var completed_purchase_value: = 0.0
	for purchase_index in completed_buys:
		completed_purchase_value += (purchase_value
			/ (1.0 + float(profile.hand_saturation) * float(hand_size + purchase_index)))
	var next_purchase_value: = (purchase_value
		/ (1.0 + float(profile.hand_saturation) * float(hand_size + completed_buys)))
	var partial_progress: = (float(remainder) / 3.0
		* next_purchase_value * float(profile.partial_purchase_value))
	var liquidity: = float(star_count) * float(profile.star_liquidity)
	var result: = ((completed_purchase_value + partial_progress + liquidity)
		* float(profile.star_value) * _resource_realization_multiplier(side))
	if game.alliance_target_character_index >= 0:
		_alliance_star_value_cache[cache_key] = result
	return result


func _resource_realization_multiplier(side: int) -> float:
	var owned_indices: Array[int] = []
	for mini_index in game.character_minis_on_board.size():
		if game.character_minis_on_board[mini_index].owner_side == side:
			owned_indices.append(mini_index)
	if owned_indices.size() != 1 or not _is_bottom_three(owned_indices[0]):
		return 1.0
	var profile: = _get_bot_profile(side)
	var realization: = float(profile.endangered_resource_realization)
	if game.character_minis_on_board[owned_indices[0]].get("has_win_token", false):
		realization = lerpf(realization, 1.0, 0.45)
	return realization


func _should_buy_scene_card(side: int) -> bool:
	if game._get_owner_star_count(side) < 3:
		return false
	var profile: = _get_bot_profile(side)
	var outlook: = _scene_card_draw_outlook(side)
	if float(outlook.probability) < float(profile.minimum_useful_draw_probability):
		return false
	var best_owned_score: = (
		_card_eval_best_raw_score
		if (_card_eval_finished and _card_eval_side == side)
		else _best_owned_scene_card_score(side)
	)
	if best_owned_score <= 0.0:
		return true
	var expected_draw_points: = (float(outlook.expected_value)
		* float(profile.draw_probability_weight)
		* float(profile.future_card_realization)
		/ (1.0 + float(profile.hand_saturation)
			* float(game._get_owner_scene_card_indices(side).size())))
	var draw_is_upgrade: = expected_draw_points > best_owned_score * float(profile.buy_improvement_ratio)
	return draw_is_upgrade and (force_optimal_values or randf() < float(profile.buy_chance))


func _best_owned_scene_card_score(side: int) -> float:
	var best_score: = - INF
	for card_index in game._get_owner_scene_card_indices(side):
		var texture = game.dealt_scene_cards[card_index].texture
		for mini_index in game.character_minis_on_board.size():
			if not _is_virtual_scene_card_legal(texture, mini_index):
				continue
			best_score = max(
				best_score, 
				float(_evaluate_card_texture(side, texture, mini_index).score)
			)
	return best_score


func _scene_card_draw_outlook(side: int) -> Dictionary:
	if _alliance_outlook_cache.has(side):
		return _alliance_outlook_cache[side]
	var profile: = _get_bot_profile(side)
	var useful_cards: = 0
	var total_positive_points: = 0.0
	var scene_pool: Array[Texture2D] = game._get_scene_card_types_for_side(side)
	var card_count: int = scene_pool.size()
	if card_count <= 0:
		return {"probability": 0.0, "expected_value": 0.0}




	var texture_counts: Dictionary = {}
	for texture in scene_pool:
		texture_counts[texture] = int(texture_counts.get(texture, 0)) + 1
	for texture in texture_counts:
		var copies: int = int(texture_counts[texture])
		var best_score: = - INF
		for mini_index in game.character_minis_on_board.size():
			if not _is_virtual_scene_card_legal(texture, mini_index):
				continue
			var evaluation: = _evaluate_card_texture(side, texture, mini_index)
			best_score = max(best_score, float(evaluation.score))
		if best_score > float(profile.card_need_threshold):
			useful_cards += copies
			total_positive_points += max(best_score, 0.0) * float(copies)
	var useful_probability: = float(useful_cards) / float(card_count)
	var average_useful_points: = (total_positive_points / float(useful_cards)
		if useful_cards > 0 else 0.0)
	return {
		"probability": useful_probability, 


		"expected_value": average_useful_points * useful_probability, 
	}


func _is_virtual_scene_card_legal(texture, mini_index: int) -> bool:
	if mini_index < 0 or mini_index >= game.character_minis_on_board.size():
		return false
	var mini = game.character_minis_on_board[mini_index]
	match game._get_scene_card_kind(texture):
		"boost":
			return mini.current_column < game.BOARD_COLUMNS - 1
		"special_boost":
			return (mini.current_column < game.BOARD_COLUMNS - 1
				and game.current_challenge.get("attributes", []).has(game._get_scene_card_attribute(texture)))
		"development":
			return true
		"swap":
			return game._count_minis_in_column(mini.current_column) > 1
		"win_token":
			return not mini.get("has_win_token", false)
	return false


func _choose_alliance_offer(side: int) -> Dictionary:
	var available_stars: int = game._get_owner_star_count(side)
	if available_stars <= 0:
		return {"amount": 0, "utility": - INF}
	var profile: = _get_bot_profile(side)
	var move: = _best_alliance_move(side, _accepted_alliance_overrides(side))
	if int(move.mini) < 0 or float(move.gain) <= 0.0:
		return {"amount": 0, "utility": - INF}

	var movement_value: = float(move.gain)
	var maximum_worthwhile: = 0
	for amount in range(1, available_stars + 1):
		var star_cost: = (_star_inventory_value(side, available_stars)
			- _star_inventory_value(side, available_stars - amount))
		if movement_value - star_cost - float(profile.offer_margin) >= 0.0:
			maximum_worthwhile = amount
	if maximum_worthwhile <= 0:
		return {"amount": 0, "utility": - INF}

	var receiver_side: int = game.alliance_active_side
	var receiver_profile: = _get_bot_profile(receiver_side)
	var threat_cost: = _alliance_threat_value(receiver_side, side, receiver_profile)
	var receiver_stars: int = game._get_owner_star_count(receiver_side)
	var predicted_minimum: = available_stars + 1
	for amount in range(1, available_stars + 1):
		var receiver_gain: = (_star_inventory_value(receiver_side, receiver_stars + amount)
			- _star_inventory_value(receiver_side, receiver_stars))
		if receiver_gain >= threat_cost + float(receiver_profile.accept_margin):
			predicted_minimum = amount
			break
	if not force_optimal_values:
		var uncertain_minimum: = randi_range(1, available_stars)
		predicted_minimum = int(round(lerpf(
			float(uncertain_minimum), 
			float(predicted_minimum), 
			float(profile.prediction)
		)))
	if predicted_minimum > available_stars:
		return {"amount": 0, "utility": - INF}


	var rejected_amount: = int(_last_rejected_offer.get(side, 0))
	if rejected_amount > 0:
		predicted_minimum = max(
			predicted_minimum, 
			rejected_amount + int(profile.rejection_increment)
		)
	var amount: = clampi(predicted_minimum, 1, available_stars)
	if amount > maximum_worthwhile:
		return {"amount": 0, "utility": - INF}
	var offered_star_cost: = (_star_inventory_value(side, available_stars)
		- _star_inventory_value(side, available_stars - amount))
	var receiver_star_gain: = (_star_inventory_value(receiver_side, receiver_stars + amount)
		- _star_inventory_value(receiver_side, receiver_stars))
	var receiver_rival_weight: = _competitive_rival_weight(side, receiver_side)
	var utility: = (movement_value
		- offered_star_cost
		- receiver_star_gain * float(profile.opponent_star_gain_weight) * receiver_rival_weight
		- float(profile.offer_margin))
	if utility <= 0.0:
		return {"amount": 0, "utility": utility}
	return {"amount": amount, "utility": utility}


func _should_accept_alliance_offer(receiver_side: int) -> bool:
	var offerer_side: int = game.alliance_offer_side
	if offerer_side < 0:
		return false
	var profile: = _get_bot_profile(receiver_side)
	var current_stars: int = game._get_owner_star_count(receiver_side)
	var stars_value: = (_star_inventory_value(receiver_side, current_stars + game.alliance_offer_stars)
		- _star_inventory_value(receiver_side, current_stars))
	var threat_cost: = _alliance_threat_value(receiver_side, offerer_side, profile)
	var utility: = stars_value - threat_cost - float(profile.accept_margin)
	if force_optimal_values:
		return utility >= 0.0


	utility += randf_range(
		- float(profile.alliance_evaluation_noise), 
		float(profile.alliance_evaluation_noise)
	) * (1.0 - float(profile.prediction))
	return utility >= 0.0


func _alliance_threat_value(receiver_side: int, offerer_side: int, receiver_profile: Dictionary) -> float:
	var move: = _best_alliance_move(offerer_side)
	if int(move.mini) < 0:
		return 0.0
	var mini_index: int = int(move.mini)
	var mini = game.character_minis_on_board[mini_index]
	var overrides: = _accepted_alliance_overrides(offerer_side)
	var receiver_before: = _team_position_score(receiver_side, overrides)
	overrides[mini_index] = {
		"column": min(mini.current_column + game.alliance_move_amount, game.BOARD_COLUMNS - 1), 
		"row": mini.row, 
	}
	var receiver_after: = _team_position_score(receiver_side, overrides)
	var direct_receiver_harm = max(receiver_before - receiver_after, 0.0)
	var rival_progress = max(float(move.gain), 0.0)
	var rival_weight: = _competitive_rival_weight(receiver_side, offerer_side)


	return (direct_receiver_harm * float(receiver_profile.opponent_threat_weight)
		+ rival_progress * float(receiver_profile.opponent_progress_weight) * rival_weight)


func _competitive_rival_weight(observer_side: int, rival_side: int) -> float:
	if observer_side == rival_side:
		return 0.0
	var living_opponents: = 0
	for side in game.player_order:
		if side != observer_side and not game.eliminated_players[side]:
			living_opponents += 1
	var shared_risk: = 1.0 / float(max(living_opponents, 1))
	var observer_score: = _team_position_score(observer_side)
	var rival_score: = _team_position_score(rival_side)
	var relative_threat = clamp((rival_score - observer_score) / 1000.0, -0.22, 0.48)
	return clamp(shared_risk + relative_threat, 0.08, 0.9)


func _accepted_alliance_overrides(excluded_side: int = -1) -> Dictionary:
	var overrides: Dictionary = {}
	for ally_side in game.alliance_accepted_sides:
		if ally_side == excluded_side or ally_side in game.alliance_moved_sides:
			continue
		var move: = _best_alliance_move(ally_side)
		var mini_index: int = int(move.mini)
		if mini_index < 0:
			continue
		var mini = game.character_minis_on_board[mini_index]
		overrides[mini_index] = {
			"column": min(mini.current_column + game.alliance_move_amount, game.BOARD_COLUMNS - 1), 
			"row": mini.row, 
		}
	return overrides


func _best_alliance_move(side: int, base_overrides: Dictionary = {}) -> Dictionary:
	var best_mini: = -1
	var best_gain: = - INF
	var before: = _team_position_score(side, base_overrides)
	for mini_index in game.character_minis_on_board.size():
		var mini = game.character_minis_on_board[mini_index]
		if mini.owner_side != side or mini.current_column != game.alliance_origin_column:
			continue
		var overrides: Dictionary = base_overrides.duplicate()
		overrides[mini_index] = {
			"column": min(mini.current_column + game.alliance_move_amount, game.BOARD_COLUMNS - 1), 
			"row": mini.row, 
		}
		var gain: = _team_position_score(side, overrides) - before
		if gain > best_gain:
			best_gain = gain
			best_mini = mini_index
	return {"mini": best_mini, "gain": best_gain}


func _bot_can_offer_again(side: int) -> bool:
	var maximum_attempts: int = int(_get_bot_profile(side).maximum_offers)
	return int(_alliance_offer_attempts.get(side, 0)) < maximum_attempts


func _find_alliance_mini(side: int) -> int:
	var choices: Array[int] = []
	for index in game.character_minis_on_board.size():
		var mini = game.character_minis_on_board[index]
		if mini.owner_side == side and mini.current_column == game.alliance_origin_column:
			choices.append(index)
	var profile: = _get_bot_profile(side)
	if not choices.is_empty() and randf() < float(profile.alliance_move_prediction):
		return int(_best_alliance_move(side).mini)
	return choices.pick_random() if not choices.is_empty() else -1


func _effect_move_step() -> void :
	var side: int = game._get_current_turn_side()
	if game.effect_move_animation_busy or game.dragged_mini_index >= 0:
		await get_tree().process_frame
		return
	if game.is_player_bot(side) and game.pending_effect_mini_index >= 0:
		var turn_serial: int = game.card_turn_serial
		var mini_index: int = game.pending_effect_mini_index
		await _think()
		if ( not game.card_play_phase_active
			or game.card_turn_serial != turn_serial
			or game._get_current_turn_side() != side
			or game.pending_effect_mini_index != mini_index
			or game.effect_move_animation_busy
			or game.dragged_mini_index >= 0):
			return
		await game.bot_animate_effect_move(mini_index)
	else:
		await get_tree().process_frame


func _swap_step() -> void :
	var side: int = game._get_current_turn_side()
	if game.effect_move_animation_busy or game.dragged_mini_index >= 0:
		await get_tree().process_frame
		return
	if not game.is_player_bot(side) or game.pending_effect_mini_index < 0:
		await get_tree().process_frame
		return
	var source_index: int = game.pending_effect_mini_index
	var source = game.character_minis_on_board[source_index]
	var targets: Array[int] = []
	if (_planned_swap_target_mini >= 0
		and _planned_swap_target_mini < game.character_minis_on_board.size()
		and _planned_swap_target_mini != source_index
		and game.character_minis_on_board[_planned_swap_target_mini].current_column == source.current_column):
		targets.append(_planned_swap_target_mini)
	for index in game.character_minis_on_board.size():
		if (index != source_index
			and index not in targets
			and game.character_minis_on_board[index].current_column == source.current_column):
			targets.append(index)
	if targets.is_empty():
		_planned_swap_target_mini = -1
		game._finish_played_card_effect()
		return
	if _planned_swap_target_mini < 0:

		targets.sort_custom( func(a: int, b: int) -> bool:
			return game.character_minis_on_board[a].row < game.character_minis_on_board[b].row
		)
	var target_index: int = targets[0]
	var turn_serial: int = game.card_turn_serial
	await _think()
	if ( not game.card_play_phase_active
		or game.card_turn_serial != turn_serial
		or not game.swap_drag_active
		or game.pending_effect_mini_index != source_index
		or source_index < 0
		or source_index >= game.character_minis_on_board.size()
		or target_index < 0
		or target_index >= game.character_minis_on_board.size()
		or game.character_minis_on_board[target_index].current_column
			!= game.character_minis_on_board[source_index].current_column
		or game.effect_move_animation_busy
		or game.dragged_mini_index >= 0):
		_planned_swap_target_mini = -1
		return
	await game.bot_animate_swap(source_index, target_index)
	_planned_swap_target_mini = -1


func _elimination_step() -> void :
	if (game.elimination_die_ready and not game.elimination_die_busy
		and game.is_player_bot(game.elimination_leader_side)):
		await _think()
		if game.elimination_die_ready:
			game._roll_elimination_die()
	else:
		await get_tree().process_frame


func _think() -> void :
	await get_tree().create_timer(randf_range(THINK_MIN, THINK_MAX)).timeout
