extends Node2D


class PlayerButtonVisual:
	extends Node2D

	var radius: = 38.0
	var button_colour: = Color.BLACK
	var colour_fade_start: = Color.BLACK
	var target_button_colour: = Color.BLACK
	var colour_fade_elapsed: = 0.18
	var label: = ""
	var label_font: Font
	var label_colour: = Color.WHITE
	var lobby_state_label: = ""
	var outline_width: = 4.0
	const COLOUR_FADE_DURATION: = 0.18

	func _process(delta: float) -> void :
		if colour_fade_elapsed >= COLOUR_FADE_DURATION:
			return
		colour_fade_elapsed = minf(
			colour_fade_elapsed + delta, 
			COLOUR_FADE_DURATION
		)
		var progress: = colour_fade_elapsed / COLOUR_FADE_DURATION
		var eased_progress: = 0.5 - 0.5 * cos(PI * progress)
		button_colour = colour_fade_start.lerp(
			target_button_colour, 
			eased_progress
		)
		queue_redraw()

	func update_visual(
		new_position: Vector2, 
		new_rotation: float, 
		new_scale: float, 
		new_radius: float, 
		new_outline_width: float, 
		new_visible: bool, 
		new_colour: Color, 
		new_label: String, 
		new_font: Font, 
		new_label_colour: Color, 
		new_lobby_state_label: String
	) -> void :
		if position != new_position:
			position = new_position
		if not is_equal_approx(rotation, new_rotation):
			rotation = new_rotation
		var target_scale: = Vector2.ONE * new_scale
		if scale != target_scale:
			scale = target_scale
		if not is_equal_approx(radius, new_radius):
			radius = new_radius
			queue_redraw()
		if not is_equal_approx(outline_width, new_outline_width):
			outline_width = new_outline_width
			queue_redraw()
		if visible != new_visible:
			visible = new_visible
		var colour_changed: = target_button_colour != new_colour
		var content_changed: = (label != new_label
			or label_font != new_font
			or label_colour != new_label_colour
			or lobby_state_label != new_lobby_state_label)
		if not colour_changed and not content_changed:
			return
		if colour_changed:
			colour_fade_start = button_colour
			target_button_colour = new_colour
			colour_fade_elapsed = 0.0
		label = new_label
		label_font = new_font
		label_colour = new_label_colour
		lobby_state_label = new_lobby_state_label
		queue_redraw()

	func _draw() -> void :
		draw_circle(Vector2.ZERO, radius, button_colour)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color.WHITE, outline_width, true)
		if label_font == null:
			return
		var font_size: = maxi(24, int(radius))
		var text_size: = label_font.get_string_size(
			label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size
		)
		var maximum_text_width: = radius * 1.55
		if text_size.x > maximum_text_width:
			font_size = maxi(12, int(font_size * maximum_text_width / text_size.x))
			text_size = label_font.get_string_size(
				label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size
			)
		draw_string(
			label_font, 
			Vector2( - text_size.x * 0.5, text_size.y * 0.35), 
			label, 
			HORIZONTAL_ALIGNMENT_LEFT, 
			-1, 
			font_size, 
			label_colour
		)
		if not lobby_state_label.is_empty():
			var state_font_size: = maxi(13, int(radius * 0.43))
			var state_size: = label_font.get_string_size(
				lobby_state_label, 
				HORIZONTAL_ALIGNMENT_LEFT, 
				-1, 
				state_font_size
			)
			draw_string(
				label_font, 
				Vector2(
					- state_size.x * 0.5, 
					- radius - outline_width - state_size.y * 0.38
				), 
				lobby_state_label, 
				HORIZONTAL_ALIGNMENT_LEFT, 
				-1, 
				state_font_size, 
				Color.WHITE
			)


class BoardIndicatorVisual:
	extends Node2D

	var cells: Array[Dictionary] = []
	var state_signature: = ""
	var pulse_phase: = 0.52
	const PULSE_DURATION: = 1.04
	const PULSE_MIN_ALPHA: = 0.42
	const CELL_FADE_DURATION: = 0.22

	func _process(delta: float) -> void :


		pulse_phase = fmod(pulse_phase + delta, PULSE_DURATION)
		var fade_step: = delta / CELL_FADE_DURATION
		for index in range(cells.size() - 1, -1, -1):
			var cell: = cells[index]
			var target_alpha: float = cell.get("target_alpha", 1.0)
			var displayed_colour: Color = cell.get("display_colour", cell.colour)
			var target_colour: Color = cell.get("target_colour", cell.colour)
			cell.display_colour = displayed_colour.lerp(
				target_colour, 
				clampf(fade_step, 0.0, 1.0)
			)
			var next_alpha: = move_toward(
				float(cell.get("fade_alpha", target_alpha)), 
				target_alpha, 
				fade_step
			)
			cell.fade_alpha = next_alpha
			if target_alpha <= 0.0 and next_alpha <= 0.001:
				cells.remove_at(index)
			else:
				cells[index] = cell
		visible = not cells.is_empty()
		if visible:
			queue_redraw()

	func set_indicators(new_cells: Array[Dictionary], new_signature: String) -> void :
		if new_signature == state_signature:
			return
		state_signature = new_signature
		var new_by_key: Dictionary = {}
		for new_cell in new_cells:
			new_by_key[str(new_cell.key)] = new_cell



		for index in cells.size():
			var old_cell: = cells[index]
			var key: = str(old_cell.key)
			if new_by_key.has(key):
				var refreshed: Dictionary = new_by_key[key].duplicate()
				refreshed.fade_alpha = float(old_cell.get("fade_alpha", 1.0))
				refreshed.target_alpha = 1.0
				refreshed.display_colour = old_cell.get(
					"display_colour", old_cell.colour
				)
				refreshed.target_colour = refreshed.colour
				cells[index] = refreshed
				new_by_key.erase(key)
			else:
				old_cell.target_alpha = 0.0
				cells[index] = old_cell


		for new_cell in new_by_key.values():
			var added: Dictionary = new_cell.duplicate()
			added.fade_alpha = 0.0
			added.target_alpha = 1.0
			added.display_colour = added.colour
			added.target_colour = added.colour
			cells.append(added)
		visible = not cells.is_empty()
		queue_redraw()

	func _draw() -> void :
		_draw_cells(cells)

	func _draw_cells(items: Array[Dictionary]) -> void :
		var pulse_amount: = 0.5 - 0.5 * cos(TAU * pulse_phase / PULSE_DURATION)
		var pulse_alpha: = lerpf(PULSE_MIN_ALPHA, 1.0, pulse_amount)
		for cell in items:
			var rect: Rect2 = cell.rect
			var base_colour: Color = cell.get("display_colour", cell.colour)
			var colour: = base_colour
			var cell_alpha: = pulse_alpha * float(cell.get("fade_alpha", 1.0))
			colour.a *= cell_alpha
			var border: = colour.lightened(0.24)
			border.a = minf((base_colour.a + 0.18) * cell_alpha, 1.0)
			var style: = StyleBoxFlat.new()
			style.bg_color = colour
			style.border_color = border
			style.set_border_width_all(int(maxf(3.0, minf(rect.size.x, rect.size.y) * 0.055)))
			var radius: int = int(cell.get("corner_radius", 0.0))
			if cell.get("round_top", false):
				style.corner_radius_top_left = radius
				style.corner_radius_top_right = radius
			if cell.get("round_bottom", false):
				style.corner_radius_bottom_left = radius
				style.corner_radius_bottom_right = radius
			style.anti_aliasing = true
			draw_style_box(style, rect)


class LobbyPrivacyButton:
	extends Button

	const PURPLE: = Color(0.55, 0.28, 0.92, 0.96)
	const PURPLE_BORDER: = Color(0.84, 0.72, 1.0, 0.82)
	const LOCK_OUTLINE: = Color(0.34, 0.12, 0.62, 1.0)

	func _ready() -> void :
		flat = true
		text = ""
		tooltip_text = "Privacy choices"
		focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		queue_redraw()

	func _notification(what: int) -> void :
		if what == NOTIFICATION_RESIZED:
			queue_redraw()

	func _draw() -> void :
		var min_side = min(size.x, size.y)
		if min_side <= 1.0:
			return
		var centre: = size * 0.5
		var outer_radius = min_side * 0.48
		var inner_radius = min_side * 0.435
		draw_circle(centre, outer_radius, PURPLE_BORDER)
		draw_circle(centre, inner_radius, PURPLE)

		var body_width = min_side * 0.34
		var body_height = min_side * 0.24
		var body: = Rect2(
			centre.x - body_width * 0.5, 
			centre.y - body_height * 0.5 + min_side * 0.11, 
			body_width, 
			body_height
		)
		var outline_width = max(2.0, min_side * 0.05)
		draw_rect(body, LOCK_OUTLINE, true)
		var inner_body: = body.grow( - outline_width)
		if inner_body.size.x > 0.0 and inner_body.size.y > 0.0:
			draw_rect(inner_body, Color.WHITE, true)

		var arc_centre: = Vector2(centre.x, body.position.y + outline_width)
		var arc_radius = min_side * 0.16
		var arc_points: = PackedVector2Array()
		for point_index in 25:
			var angle = lerp(PI, TAU, float(point_index) / 24.0)
			arc_points.append(
				arc_centre + Vector2(cos(angle), sin(angle)) * arc_radius
			)
		draw_polyline(arc_points, LOCK_OUTLINE, outline_width, true)
		var leg_end_y = body.position.y + outline_width * 0.8
		draw_line(
			Vector2(arc_centre.x - arc_radius, arc_centre.y), 
			Vector2(arc_centre.x - arc_radius, leg_end_y), 
			LOCK_OUTLINE, 
			outline_width, 
			true
		)
		draw_line(
			Vector2(arc_centre.x + arc_radius, arc_centre.y), 
			Vector2(arc_centre.x + arc_radius, leg_end_y), 
			LOCK_OUTLINE, 
			outline_width, 
			true
		)


class DraggedSceneCardVisual:
	extends Node2D

	var card_size: = Vector2.ZERO
	var face_texture: Texture2D
	var back_texture: Texture2D
	var revealed: = false
	var card_number: = ""
	var card_font: Font

	func show_card(
		card: Dictionary, 
		size: Vector2, 
		new_back_texture: Texture2D, 
		new_font: Font
	) -> void :
		card_size = size
		face_texture = card.texture
		back_texture = new_back_texture
		revealed = card.revealed
		card_number = str(card.get("card_number", 0))
		card_font = new_font
		position = card.position
		rotation = card.rotation
		scale = Vector2(card.flip_scale, 1.0) * card.deal_scale
		visible = true
		queue_redraw()

	func move_card(new_position: Vector2) -> void :
		position = new_position

	func hide_card() -> void :
		visible = false

	func _draw() -> void :
		if card_size == Vector2.ZERO:
			return
		var rect: = Rect2( - card_size * 0.5, card_size)
		var texture: = face_texture if revealed else back_texture
		if texture != null:
			draw_texture_rect(texture, rect, false)
		if revealed or card_number == "0" or card_font == null:
			return
		var font_size = max(18, int(rect.size.x * 0.18))
		var text_size: = card_font.get_string_size(
			card_number, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size
		)
		var baseline: = Vector2(
			- text_size.x * 0.5, 
			rect.end.y - rect.size.y * 0.055
		)
		draw_string(
			card_font, 
			baseline + Vector2(2.0, 2.0), 
			card_number, 
			HORIZONTAL_ALIGNMENT_LEFT, 
			-1, 
			font_size, 
			Color(0.0, 0.0, 0.0, 0.75)
		)
		draw_string(
			card_font, 
			baseline, 
			card_number, 
			HORIZONTAL_ALIGNMENT_LEFT, 
			-1, 
			font_size, 
			Color.WHITE
		)


class StaticBoardVisual:
	extends Node2D

	var config: Dictionary = {}
	var star_texture: Texture2D

	func update_board(new_config: Dictionary, new_star_texture: Texture2D) -> void :
		if config == new_config and star_texture == new_star_texture:
			return
		config = new_config
		star_texture = new_star_texture
		queue_redraw()

	func _draw() -> void :
		if config.is_empty():
			return
		var visible_size: Vector2 = config.visible_size
		var centre: Vector2 = config.centre
		var columns: int = config.columns
		var rows: int = config.rows
		var board_size: = Vector2(
			visible_size.x * config.width_ratio, 
			visible_size.y * config.height_ratio
		)
		var board_position: = centre - board_size * 0.5
		var gap: float = visible_size.x * config.gap_ratio
		var column_width: = (board_size.x - gap * (columns - 1)) / columns
		var cell_height: = board_size.y / rows
		var corner_radius = min(column_width * 0.5, cell_height * 0.5)
		for column in columns:
			var column_rect: = Rect2(
				board_position + Vector2(column * (column_width + gap), 0.0), 
				Vector2(column_width, board_size.y)
			)
			_draw_gradient_column(column_rect, corner_radius)
			if column == columns - 1:
				_draw_winner_checkerboard(column_rect, cell_height, corner_radius)
			_draw_column_lines(column_rect, cell_height, corner_radius)
			if column == 0:
				_draw_starting_stars(column_rect, cell_height)

	func _draw_gradient_column(rect: Rect2, radius: float) -> void :
		var strip_height: = 2.0
		for strip in int(ceil(rect.size.y / strip_height)):
			var local_y = min(strip * strip_height, rect.size.y)
			var height = min(strip_height + 1.0, rect.size.y - local_y)
			if height <= 0.0:
				continue
			var centre_y = local_y + height * 0.5
			var inset: = _rounded_column_inset(centre_y, rect.size, radius)
			var colour: Color = config.top_colour.lerp(
				config.bottom_colour, centre_y / rect.size.y
			)
			draw_rect(
				Rect2(
					rect.position + Vector2(inset, local_y), 
					Vector2(rect.size.x - inset * 2.0, height)
				), 
				colour
			)

	func _draw_column_lines(rect: Rect2, cell_height: float, radius: float) -> void :
		for row in range(1, int(config.rows)):
			var y: = rect.position.y + row * cell_height
			draw_line(
				Vector2(rect.position.x, y), 
				Vector2(rect.end.x, y), 
				config.line_colour, 
				config.line_width, 
				true
			)
		var outer_border: = StyleBoxFlat.new()
		outer_border.bg_color = Color.TRANSPARENT
		outer_border.border_color = config.outline_colour
		outer_border.set_border_width_all(int(config.outline_width))
		outer_border.set_corner_radius_all(int(radius))
		outer_border.anti_aliasing = true
		draw_style_box(outer_border, rect)
		var border: = StyleBoxFlat.new()
		border.bg_color = Color.TRANSPARENT
		border.border_color = config.line_colour
		border.set_border_width_all(int(config.line_width))
		border.set_corner_radius_all(int(radius))
		border.anti_aliasing = true
		draw_style_box(border, rect)

	func _draw_starting_stars(rect: Rect2, cell_height: float) -> void :
		if star_texture == null:
			return
		var star_size = min(rect.size.x * 0.3, cell_height * 0.58)
		var first_centre: = rect.position + Vector2(rect.size.x * 0.5, cell_height * 0.5)
		var star_gap = star_size * 0.12
		_draw_star(first_centre + Vector2( - (star_size + star_gap) * 0.5, 0.0), star_size)
		_draw_star(first_centre + Vector2((star_size + star_gap) * 0.5, 0.0), star_size)
		_draw_star(first_centre + Vector2(0.0, cell_height), star_size)
		_draw_star(first_centre + Vector2(0.0, cell_height * 2.0), star_size)

	func _draw_star(centre: Vector2, size: float) -> void :
		draw_texture_rect(
			star_texture, 
			Rect2(centre - Vector2.ONE * size * 0.5, Vector2.ONE * size), 
			false
		)

	func _draw_winner_checkerboard(
		rect: Rect2, 
		cell_height: float, 
		radius: float
	) -> void :
		var checker_columns: int = config.checker_columns
		var checker_rows: int = config.checker_rows
		var square_width: = rect.size.x / checker_columns
		var square_height: = cell_height / checker_rows
		var cell_bottom: = rect.position.y + cell_height
		for checker_row in checker_rows:
			for checker_column in checker_columns:
				if (checker_row + checker_column) % 2 != 0:
					continue
				var square: = Rect2(
					rect.position + Vector2(
						checker_column * square_width, 
						checker_row * square_height
					), 
					Vector2(square_width, square_height)
				)
				for strip in int(ceil(square.size.y)):
					var y: = square.position.y + strip
					var height = min(1.0, square.end.y - y, cell_bottom - y)
					if height <= 0.0:
						continue
					var sample_y = y - rect.position.y + height * 0.5
					var inset: = _rounded_column_inset(sample_y, rect.size, radius)
					var left = max(square.position.x, rect.position.x + inset)
					var right = min(square.end.x, rect.end.x - inset)
					if right > left:
						draw_rect(
							Rect2(Vector2(left, y), Vector2(right - left, height)), 
							config.checker_colour
						)

	func _rounded_column_inset(y: float, size: Vector2, radius: float) -> float:
		var circle_y: = 0.0
		if y < radius:
			circle_y = radius - y
		elif y > size.y - radius:
			circle_y = y - (size.y - radius)
		else:
			return 0.0
		return radius - sqrt(max(radius * radius - circle_y * circle_y, 0.0))

@onready var flick: AudioStreamPlayer = $Flick
@onready var click: AudioStreamPlayer = $Click
@onready var star: AudioStreamPlayer = $Star
@onready var grab: AudioStreamPlayer = $Grab
@onready var place: AudioStreamPlayer = $Place
@onready var throw: AudioStreamPlayer = $Throw
@onready var die: AudioStreamPlayer = $Die
@onready var die_roll: AnimatedSprite2D = $DieRoll
@onready var start: AudioStreamPlayer = $Start
@onready var start_bfdi: AudioStreamPlayer = $StartBFDI
@onready var start_hybrid: AudioStreamPlayer = $StartHybrid
@onready var win: AudioStreamPlayer = $Win
@onready var buzz: AudioStreamPlayer = $Buzz
@onready var camera_2d: Camera2D = $Camera2D
@onready var sky: Sprite2D = $Sky
@onready var background: Sprite2D = $Background
@onready var grass: Sprite2D = $Grass
@onready var hybrid_background: Sprite2D = $HybridBackground

const COMIC_SANS = preload("uid://w4rvsaok267k")
const GAME_LOGO = preload("uid://ba3k6j5kgh5mk")
const GAME_LOGO_BFDI = preload("uid://bwbtygcef0prn")
const HYBRID_LOGO = preload("uid://b0o2mnl1f3g21")
const BALDI_LOGO = preload("res://Art/Others/Baldi Logo.png")
const SHAG_LOUNGE = preload("uid://0wxjvjeypfrt")
const SWIPE = preload("uid://dxfm3wumpt7h2")
const HELVETICA_BOLD = preload("uid://bpmk5b7c8ep0c")
const INDICATOR_OFF = preload("uid://cxucyfbupmj0i")
const INDICATOR_ON = preload("uid://b17ua6ehmqjtk")
const MUSIC_OFF = preload("uid://d4b3lfe011il")
const MUSIC_ON = preload("uid://c63nu02e414ot")
const CALL_TO_ADVENTURE = preload("uid://cbaoxqkd1kngx")
const ITTY_BITTY_8_BIT = preload("uid://blqu85r243gv6")
const SHINY_TECH = preload("uid://cyobwsaewvtlw")
const WINNER_WINNER = preload("uid://cb5svi5rpisqw")
const _1_GAME = preload("uid://bj56bvhh3dul8")
const ENERGY_0 = preload("uid://bkae17ygts1sv")
const ENERGY_1 = preload("uid://dfb55gjh0j8ne")
const ENERGY_2 = preload("uid://sn2kgyanyok1")
const ENERGY_3 = preload("uid://b0rh1447ue0tb")
const ENERGY_4 = preload("uid://b0gjtcvjgt4xe")
const ENERGY_5 = preload("uid://u1w00gsltkcg")
const ENERGY_6 = preload("uid://buljeb5e17i8j")
const ENERGY_7 = preload("uid://b4rcv0c4o8m7r")
const ENERGY_8 = preload("uid://d1jgqfw4e1jm")
const ENERGY_9 = preload("uid://c4swl42pkt636")
const ENERGY_TEXTURES: Array[Texture2D] = [
	ENERGY_0, ENERGY_1, ENERGY_2, ENERGY_3, ENERGY_4, 
	ENERGY_5, ENERGY_6, ENERGY_7, ENERGY_8, ENERGY_9, 
]
const MAX_ENERGY: = 9
const INITIAL_ENERGY: = 1
const ENERGY_SAVE_PATH: = "user://energy.cfg"
const ENERGY_SAVE_SECTION: = "energy"
const ENERGY_SAVE_KEY: = "points"
const ENERGY_RECHARGE_TIME_KEY: = "next_recharge_unix"
const ENERGY_LAST_CLOCK_KEY: = "last_seen_unix"
const FREE_ENERGY_CAP: = 2
const ENERGY_RECHARGE_SECONDS: = 60 * 60

const BACKGROUND = preload("uid://cpmrftvwpdr6g")
const GRASS = preload("uid://bvqt4i2s4y2rs")
const BFDI_BACKGROUND = preload("uid://cafrp1473qe46")
const BFDI_GRASS = preload("uid://ctvry6kxt7cqp")
const BFDI_SKY = preload("uid://c5y56sexlvf6u")
const BALDI_BG = preload("res://Art/Background/Baldi.png")

const CHARACTER_CARD_BACK = preload("uid://174xlvubxhit")
const BAUBLE_CARD = preload("uid://c4pj32ieeqowr")
const BUD_CARD = preload("uid://n02y7vfogh2c")
const CAPPY_CARD = preload("uid://byg0ii4rvkjb4")
const CUBEY_CARD = preload("uid://ltvqkmf8hccy")
const GUM_CARD = preload("uid://slqeb44dvibx")
const HIGHLIGHTY_CARD = preload("uid://erm018xkh26i")
const ICE_PACK_CARD = preload("uid://fj2qag77i7ld")
const LOAFY_CARD = preload("uid://ckxv4diixd8jp")
const MECHY_CARD = preload("uid://clg2eu7vk6e1u")
const POP_ROCK_CARD = preload("uid://bxljuyb4cygbm")
const RUBBER_BALL_CARD = preload("uid://ub0bm3rj6qyj")
const SOAPY_CARD = preload("uid://cuy86tnla77y0")
const SODEY_CARD = preload("uid://bjpnxjo30noho")
const SOFTBALL_CARD = preload("uid://2fiktaqnqpqa")
const SQUISHY_CUBE_CARD = preload("uid://crikhc254cl8h")
const STICKY_CARD = preload("uid://bsovud0nt1p7a")
const STRESS_BALL_CARD = preload("uid://bdevo75u7mmfo")
const TEE_CARD = preload("uid://blgr7pbjg48gq")
const TIN_CARD = preload("uid://ck6dn8r6bavaf")
const WINDY_CARD = preload("uid://bfhihddnp3a8i")

const CHALLENGE_CARD_BACK = preload("uid://n63ppj4topmg")
const CHALLENGE_CARD = preload("uid://cdcfl0egkv1j2")

const SCENE_CARD_BACK = preload("uid://b3kdpdilughe")
const BALDISCENE_CARD_BACK = preload("res://Art/BaldiCards/Scene Background Card.png")
const ACTIVE_DEVELOPMENT_CARD = preload("uid://11cow5tgd6lr")
const ACTIVE_SPECIAL_BOOST_CARD = preload("uid://c8bm46ggxhk7w")
const ANGER_DEVELOPMENT_CARD = preload("uid://c5445kvo5sp3r")
const ANGER_SPECIAL_BOOST_CARD = preload("uid://djluurumxl30y")
const BOOST_CARD = preload("uid://ddm7cguspomr2")
const NICE_DEVELOPMENT_CARD = preload("uid://cbo2vfmgxlrfb")
const NICE_SPECIAL_BOOST_CARD = preload("uid://swm7hytcqmnd")
const SELFISH_DEVELOPMENT_CARD = preload("uid://7c6f6gbek7xp")
const SELFISH_SPECIAL_BOOST_CARD = preload("uid://7lhqkib1rbd5")
const SMART_DEVELOPMENT_CARD = preload("uid://bexm5wl5bnsc2")
const SMART_SPECIAL_BOOST_CARD = preload("uid://cjxsft7magjg3")
const SWAP_CARD = preload("uid://2qgcjhv0n1au")
const WIN_TOKEN_CARD = preload("uid://cvlf2k1ajgbe5")

const BAUBLE_MINI = preload("uid://cl5qwdgqdxjc8")
const BUD_MINI = preload("uid://cbxrlow8ea02m")
const CAPPY_MINI = preload("uid://dv8m04rl6tvuu")
const CUBEY_MINI = preload("uid://cct4wbncascnb")
const GUM_MINI = preload("uid://bahmappsaii21")
const HIGHLIGHTY_MINI = preload("uid://ba65k57330hul")
const ICE_PACK_MINI = preload("uid://1ab6onckgo84")
const LOAFY_MINI = preload("uid://dya387y73e86a")
const MECHY_MINI = preload("uid://dy2i4nxnjsl7r")
const POP_ROCK_MINI = preload("uid://ccp6b8gmuig72")
const RUBBER_BALL_MINI = preload("uid://bll6k864u55a")
const SOAPY_MINI = preload("uid://bcxtv7t1h0ljl")
const SODEY_MINI = preload("uid://mobosy2vsq7x")
const SOFTBALL_MINI = preload("uid://bohgpfdnxigkk")
const SQUISHY_CUBE_MINI = preload("uid://c7sxrpmu70r8f")
const STICKY_MINI = preload("uid://bbu1nisbxvja3")
const STRESS_BALL_MINI = preload("uid://cp1tk5i0vytvv")
const TEE_MINI = preload("uid://dpyror3yp0hmw")
const TIN_MINI = preload("uid://b2n7suai2g7n6")
const WINDY_MINI = preload("uid://b5bfgh31b4yh5")

const ACTIVE_ATTRIBUTE = preload("uid://by81xxft1fbo4")
const ANGRY_ATTRIBUTE = preload("uid://ce7pj68o4t6b1")
const DIE_FACE_2 = preload("uid://d2npo3dp38xl7")
const DIE_FACE_3 = preload("uid://c1w3rw02hyahh")
const DIE_FACE = preload("uid://bursp0jgxx5vc")
const DIE = preload("uid://chc4dqr88qmx1")
const NICE_ATTRIBUTE = preload("uid://y6b028ejsdjt")
const SELFISH_ATTRIBUTE = preload("uid://ceskh584l6v8f")
const SMART_ATTRIBUTE = preload("uid://hfv3852ir2ra")
const STAR = preload("uid://c2i527rda52aj")
const YTP = preload("res://Art/Others/YTP.webp")
const WIN_TOKEN = preload("uid://bnbvsgwisrbpb")
const BFDI_DIE_FACE_2 = preload("uid://cfnjj6wjrps4e")
const BFDI_DIE_FACE_3 = preload("uid://dnxjmplfvdrcy")
const BFDI_DIE_FACE = preload("uid://75tpycfyits4")
const BFDI_DIE = preload("uid://dphjuc02cqak7")
const BFDI_WIN_TOKEN = preload("uid://427kcecet8q4")

const BLOCKY_CARD = preload("uid://doa6tjr4coapo")
const BUBBLE_CARD = preload("uid://dqlmnfumtat3k")
const COINY_CARD = preload("uid://c4gdu586fvum3")
const ERASER_CARD = preload("uid://8igy35ggb4di")
const FIREY_CARD = preload("uid://1ox3jxbyn1pw")
const FLOWER_CARD = preload("uid://c1vganm506l82")
const GOLF_BALL_CARD = preload("uid://dn80b1tyoi21d")
const ICE_CUBE_CARD = preload("uid://ccduoyg128682")
const LEAFY_CARD = preload("uid://bqkm2rd265gj5")
const MATCH_CARD = preload("uid://ceplmu30jud36")
const NEEDLE_CARD = preload("uid://d3vjyqubbfu1x")
const PEN_CARD = preload("uid://btg823vqcli7q")
const PENCIL_CARD = preload("uid://b1wutl1owb3e")
const PIN_CARD = preload("uid://djm0of4oxh0nr")
const ROCKY_CARD = preload("uid://diomc653iegye")
const SNOWBALL_CARD = preload("uid://wxql3l08yxrc")
const SPONGY_CARD = preload("uid://cms0uvki63rj1")
const TEARDROP_CARD = preload("uid://2xrl8afa80f2")
const TENNIS_BALL_CARD = preload("uid://2i5xshx7s24p")
const WOODY_CARD = preload("uid://crypimbj6glxx")

const BFDI_CHALLENGE_CARD = preload("uid://bnpcb3ut6faoa")
const BFDI_ACTIVE_DEVELOPMENT_CARD = preload("uid://dh7b2deq2wbtu")
const BFDI_ANGER_DEVELOPMENT_CARD = preload("uid://dt453eeo2c6b0")
const BFDI_BOOST_CARD = preload("uid://b5meia73rrjd4")
const BFDI_NICE_DEVELOPMENT_CARD = preload("uid://cffpagdvddus2")
const BFDI_SELFISH_DEVELOPMENT_CARD = preload("uid://cik548mwm6ax5")
const BFDI_SMART_DEVELOPMENT_CARD = preload("uid://dx3swxgvl7t4b")
const BFDI_WIN_TOKEN_CARD = preload("uid://dcsb3cpde3qaq")

const BLOCKY_MINI = preload("uid://c31hw2ekb3cfg")
const BUBBLE_MINI = preload("uid://bjppdvcredrp7")
const COINY_MINI = preload("uid://brogcpnkv20ud")
const ERASER_MINI = preload("uid://c04ai6bo81ig6")
const FIREY_MINI = preload("uid://cnkaab6iqwjpn")
const FLOWER_MINI = preload("uid://b35fkmc3s5nvk")
const GOLF_BALL_MINI = preload("uid://bomhx1p6sw60j")
const ICE_CUBE_MINI = preload("uid://djolefh7fupdg")
const LEAFY_MINI = preload("uid://dvh5qvhhsfqoj")
const MATCH_MINI = preload("uid://2s2gbji3ilh")
const NEEDLE_MINI = preload("uid://do37c7dnbn52n")
const PEN_MINI = preload("uid://dvsf7bnn53u74")
const PENCIL_MINI = preload("uid://bncx7100ltwut")
const PIN_MINI = preload("uid://7rvdvsvjwter")
const ROCKY_MINI = preload("uid://bloit3qc6o0r4")
const SNOWBALL_MINI = preload("uid://cmqvgyfmuktjt")
const SPONGY_MINI = preload("uid://c2cm3n3c2g35e")
const TEARDROP_MINI = preload("uid://gvbj427tw4yr")
const TENNIS_BALL_MINI = preload("uid://dh33p5uurr5ye")
const WOODY_MINI = preload("uid://cmwod8mjr5ylh")

const BALDI_CARD_BACK = preload("res://Art/BaldiCards/Background Card.png")
const BALDI_MINI = preload("res://Art/BaldiMinis/Baldi Mini.webp")
const BALDI_CARD = preload("res://Art/BaldiCards/Baldi Card.png")
const PLAYTIME_MINI = preload("res://Art/BaldiMinis/Playtime Mini.png")
const PLAYTIME_CARD = preload("res://Art/BaldiCards/Playtime Card.png")
const AC_MINI = preload("res://Art/BaldiMinis/Arts & Crafters Mini.png")
const AC_CARD = preload("res://Art/BaldiCards/Arts & Crafters Card.png")
const BULLY_MINI = preload("res://Art/BaldiMinis/It's a Bully Mini.png")
const BULLY_CARD = preload("res://Art/BaldiCards/It's a Bully Card.png")
const PRINCIPAL_MINI = preload("res://Art/BaldiMinis/Principal of the Thing Mini.webp")
const PRINCIPAL_CARD = preload("res://Art/BaldiCards/Principal of the Thing Card.png")
const SWEEPER_MINI = preload("res://Art/BaldiMinis/Gotta Sweep Mini.png")
const SWEEPER_CARD = preload("res://Art/BaldiCards/Gotta Sweep Card.png")
const PRIZE_MINI = preload("res://Art/BaldiMinis/FirstPrize Mini.png")
const PRIZE_CARD = preload("res://Art/BaldiCards/FirstPrize Card.png")
const CUMULO_MINI = preload("res://Art/BaldiMinis/CloudyCopter Mini.png")
const CUMULO_CARD = preload("res://Art/BaldiCards/CloudyCopter Card.png")
const CHALKFACE_MINI = preload("res://Art/BaldiMinis/Chalkles Mini.png")
const CHALKFACE_CARD = preload("res://Art/BaldiCards/Chalkles Card.png")
const POMP_MINI = preload("res://Art/BaldiMinis/MrsPomp Mini.png")
const POMP_CARD = preload("res://Art/BaldiCards/MrsPomp Card.png")
const TESTY_MINI = preload("res://Art/BaldiMinis/The Test Mini.png")
const TESTY_CARD = preload("res://Art/BaldiCards/The Test Card.png")
const THINKFAST_MINI = preload("res://Art/BaldiMinis/DrReflex Mini.png")
const THINKFAST_CARD = preload("res://Art/BaldiCards/DrReflex Card.png")

const FLICK_1 = preload("uid://uw1pxupc2bxf")
const FLICK_2 = preload("uid://b7sgudsvav5nx")
const FLICK_3 = preload("uid://bajcbc0qmf4rn")
const FLICK_4 = preload("uid://bbwt2e3j5qymy")
const DIE_1 = preload("uid://dlvkigrebnyp3")
const DIE_2 = preload("uid://cimvlq2ap7qpd")
const DIE_3 = preload("uid://ddarb4q10q4iu")


const BOARD_COLUMNS: = 4
const BOARD_ROWS: = 12
const BOARD_WIDTH_RATIO: = 0.62
const BOARD_HEIGHT_RATIO: = 0.7
const PHONE_BOARD_WIDTH_RATIO: = 0.62
const PHONE_BOARD_HEIGHT_RATIO: = 0.7
const PHONE_SHORTEST_SIDE_THRESHOLD: = 700.0
const PHONE_ASPECT_RATIO_THRESHOLD: = 1.72
const PHONE_TOUCH_SCALE: = 1.65
const PHONE_LOBBY_SCALE: = 1.2
const PHONE_DIE_SCALE: = 1.38
const MAX_VISIBLE_HAND_LAYERS: = 6
const COLUMN_GAP_RATIO: = 0.025
const BOARD_TOP_COLOUR: = Color("#ffd84a")
const BOARD_BOTTOM_COLOUR: = Color("#70401f")
const BOARD_LINE_COLOUR: = Color("#3e281b")
const BOARD_LINE_WIDTH: = 5.0
const BOARD_OUTLINE_COLOUR: = Color.WHITE
const BOARD_OUTLINE_WIDTH: = 9.0
const MOVE_INDICATOR_GREEN: = Color(0.12, 0.95, 0.28, 0.72)
const WAITING_INDICATOR_ORANGE: = Color(1.0, 0.45, 0.06, 0.8)
const SWAP_INDICATOR_PURPLE: = Color(0.66, 0.24, 0.96, 0.76)
const ALLIANCE_INDICATOR_BLUE: = Color(0.1, 0.52, 1.0, 0.76)
const ELIMINATION_DANGER_RED: = Color(0.96, 0.1, 0.12, 0.76)
const DANGER_INDICATOR_PRIORITY: = 0
const ACTION_INDICATOR_PRIORITY: = 10
const WINNER_CHECKER_ROWS: = 4
const WINNER_CHECKER_COLUMNS: = 4
const WINNER_CHECKER_COLOUR: = Color(0.0, 0.0, 0.0, 0.45)
const PLAYER_BUTTON_RADIUS: = 38.0
const ACTION_BUTTON_CARD_HEIGHT_RATIO: = 0.5
const ACTION_BUTTON_OUTLINE_RATIO: = 0.052
const ACTION_BUTTON_MIN_OUTLINE: = 4.0
const ACTION_BUTTON_EDGE_GAP: = 24.0
const ENERGY_ICON_LOGO_SIZE: = Vector2(0.42, 0.36)
const ADD_ENERGY_BUTTON_LOGO_SIZE: = Vector2(0.52, 0.44)
const ENERGY_ICON_LOGO_GAP: = 0.085
const ADD_ENERGY_BUTTON_LOGO_GAP: = 0.035
const PLAYER_ACTIVE_COLOUR: = Color("#ffd84a")
const PLAYER_BOT_COLOUR: = Color("#9b59d0")
const PLAYER_INACTIVE_COLOUR: = Color(0.12, 0.12, 0.12, 0.72)
const LOBBY_OVERLAY_COLOUR: = Color(0.0, 0.0, 0.0, 0.62)
const SCENE_CARD_HEIGHT_RATIO: = 0.27
const SCENE_CARD_DEAL_TIME: = 0.34
const MUSIC_VOLUME_DB: = -7.0

const SCENE_CARD_TYPES: Array[Texture2D] = [
	ACTIVE_DEVELOPMENT_CARD, 
	ACTIVE_SPECIAL_BOOST_CARD, 
	ANGER_DEVELOPMENT_CARD, 
	ANGER_SPECIAL_BOOST_CARD, 
	BOOST_CARD, 
	NICE_DEVELOPMENT_CARD, 
	NICE_SPECIAL_BOOST_CARD, 
	SELFISH_DEVELOPMENT_CARD, 
	SELFISH_SPECIAL_BOOST_CARD, 
	SMART_DEVELOPMENT_CARD, 
	SMART_SPECIAL_BOOST_CARD, 
	SWAP_CARD, 
	WIN_TOKEN_CARD, 
]

const BFDI_SCENE_CARD_TYPES: Array[Texture2D] = [
	BFDI_ACTIVE_DEVELOPMENT_CARD, 
	BFDI_ANGER_DEVELOPMENT_CARD, 
	BFDI_BOOST_CARD, 
	BFDI_NICE_DEVELOPMENT_CARD, 
	BFDI_SELFISH_DEVELOPMENT_CARD, 
	BFDI_SMART_DEVELOPMENT_CARD, 
	BFDI_WIN_TOKEN_CARD, 
]

const CHARACTER_CARD_TYPES: Array[Texture2D] = [
	BAUBLE_CARD, BUD_CARD, CAPPY_CARD, CUBEY_CARD, GUM_CARD, 
	HIGHLIGHTY_CARD, ICE_PACK_CARD, LOAFY_CARD, MECHY_CARD, 
	POP_ROCK_CARD, RUBBER_BALL_CARD, SOAPY_CARD, SODEY_CARD, 
	SOFTBALL_CARD, SQUISHY_CUBE_CARD, STICKY_CARD, STRESS_BALL_CARD, 
	TEE_CARD, TIN_CARD, WINDY_CARD, 
]

const CHARACTER_MINI_TYPES: Array[Texture2D] = [
	BAUBLE_MINI, BUD_MINI, CAPPY_MINI, CUBEY_MINI, GUM_MINI, 
	HIGHLIGHTY_MINI, ICE_PACK_MINI, LOAFY_MINI, MECHY_MINI, 
	POP_ROCK_MINI, RUBBER_BALL_MINI, SOAPY_MINI, SODEY_MINI, 
	SOFTBALL_MINI, SQUISHY_CUBE_MINI, STICKY_MINI, STRESS_BALL_MINI, 
	TEE_MINI, TIN_MINI, WINDY_MINI, 
]

const CHARACTER_NAMES: Array[String] = [
	"Bauble", "Bud", "Cappy", "Cubey", "Gum", "Highlighty", 
	"Ice Pack", "Loafy", "Mechy", "Pop Rock", "Rubber Ball", "Soapy", 
	"Sodey", "Softball", "Squishy Cube", "Sticky", "Stress Ball", 
	"Tee", "Tin", "Windy", 
]

const BFDI_CHARACTER_CARD_TYPES: Array[Texture2D] = [
	BLOCKY_CARD, BUBBLE_CARD, COINY_CARD, ERASER_CARD, FIREY_CARD, 
	FLOWER_CARD, GOLF_BALL_CARD, ICE_CUBE_CARD, LEAFY_CARD, 
	MATCH_CARD, NEEDLE_CARD, PEN_CARD, PENCIL_CARD, 
	PIN_CARD, ROCKY_CARD, SNOWBALL_CARD, SPONGY_CARD, 
	TEARDROP_CARD, TENNIS_BALL_CARD, WOODY_CARD, 
]

const BFDI_CHARACTER_MINI_TYPES: Array[Texture2D] = [
	BLOCKY_MINI, BUBBLE_MINI, COINY_MINI, ERASER_MINI, FIREY_MINI, 
	FLOWER_MINI, GOLF_BALL_MINI, ICE_CUBE_MINI, LEAFY_MINI, 
	MATCH_MINI, NEEDLE_MINI, PEN_MINI, PENCIL_MINI, 
	PIN_MINI, ROCKY_MINI, SNOWBALL_MINI, SPONGY_MINI, 
	TEARDROP_MINI, TENNIS_BALL_MINI, WOODY_MINI, 
]

const BFDI_CHARACTER_NAMES: Array[String] = [
	"Blocky", "Bubble", "Coiny", "Eraser", "Firey", "Flower", 
	"Golf Ball", "Ice Cube", "Leafy", "Match", "Needle", "Pen", 
	"Pencil", "Pin", "Rocky", "Snowball", "Spongy", 
	"Teardrop", "Tennis Ball", "Woody", 
]

const BALDI_CHARACTER_CARD_TYPES: Array[Texture2D] = [
	BALDI_CARD, PLAYTIME_CARD, AC_CARD, BULLY_CARD, PRINCIPAL_CARD, 
	SWEEPER_CARD, PRIZE_CARD, CUMULO_CARD, CHALKFACE_CARD, POMP_CARD, 
	TESTY_CARD, THINKFAST_CARD
]

const BALDI_CHARACTER_MINI_TYPES: Array[Texture2D] = [
	BALDI_MINI, PLAYTIME_MINI, AC_MINI, BULLY_MINI, PRINCIPAL_MINI, 
	SWEEPER_MINI, PRIZE_MINI, CUMULO_MINI, CHALKFACE_MINI, POMP_MINI, 
	TESTY_MINI, THINKFAST_MINI
]

const BALDI_CHARACTER_NAMES: Array[String] = [
	"Baldi", "Playtime", "A&C", "It's a Bully", "Principal", 
	"Gotta Sweep", "1st Prize", "Cloudy Copter", "Chalkles", 
	"Mrs. Pomp", "The Test", "Dr. Reflex"
]

const CHARACTER_DRAFT_COUNT: = 12
const CHARACTER_DRAFT_COLUMNS: = 4
const HAND_CYCLE_BUTTON_RADIUS: = 28.0

enum GameContentMode{
	CFDI, 
	BFDI, 
	HYBRID, 
	BALDI, 
}

const GAME_MODE_NAMES: Array[String] = ["CFDI", "BFDI", "HYBRID", "BALDI"]
const LOGO_SWIPE_THRESHOLD_RATIO: = 0.055

const ATTRIBUTE_ACTIVE: = "active"
const ATTRIBUTE_ANGRY: = "angry"
const ATTRIBUTE_NICE: = "nice"
const ATTRIBUTE_SELFISH: = "selfish"
const ATTRIBUTE_SMART: = "smart"

const CHALLENGES: Array[Dictionary] = [
	{"name": "Puzzling Obstacle Cource", "attributes": [ATTRIBUTE_ACTIVE, ATTRIBUTE_SMART]}, 
	{"name": "The Best Burger", "attributes": [ATTRIBUTE_NICE, ATTRIBUTE_SMART]}, 
	{"name": "Last to Leave Circle", "attributes": [ATTRIBUTE_ACTIVE, ATTRIBUTE_SELFISH]}, 
	{"name": "Carry an Egg", "attributes": [ATTRIBUTE_ANGRY, ATTRIBUTE_ACTIVE]}, 
	{"name": "Clean Up CFDI", "attributes": [ATTRIBUTE_NICE, ATTRIBUTE_ACTIVE]}, 
	{"name": "First to Answer Quiz", "attributes": [ATTRIBUTE_SMART, ATTRIBUTE_SELFISH]}, 
	{"name": "DIY Laser Fight", "attributes": [ATTRIBUTE_ANGRY, ATTRIBUTE_SELFISH]}, 
	{"name": "Help Objects Find Home", "attributes": [ATTRIBUTE_NICE, ATTRIBUTE_SMART]}, 
	{"name": "Race to Nomiland", "attributes": [ATTRIBUTE_ACTIVE]}, 
	{"name": "Find the Impostor", "attributes": [ATTRIBUTE_NICE, ATTRIBUTE_SELFISH]}, 
	{"name": "Chess Match", "attributes": [ATTRIBUTE_SMART, ATTRIBUTE_SELFISH]}, 
	{"name": "Treasure Finding", "attributes": [ATTRIBUTE_ACTIVE, ATTRIBUTE_SMART]}, 
	{"name": "Steal an Item", "attributes": [ATTRIBUTE_SELFISH]}, 
	{"name": "Save Candyland", "attributes": [ATTRIBUTE_NICE]}, 
	{"name": "Pogo Stick Jumping", "attributes": [ATTRIBUTE_ANGRY]}, 
	{"name": "Build And Survive in an Indestrutible Building", "attributes": [ATTRIBUTE_SMART]}, 
	{"name": "Balance On Your Teammates", "attributes": [ATTRIBUTE_NICE, ATTRIBUTE_ACTIVE]}, 
	{"name": "Build And Drive a Small Car", "attributes": [ATTRIBUTE_ANGRY, ATTRIBUTE_SMART]}, 
	{"name": "Last to Live Somewhere", "attributes": [ATTRIBUTE_NICE, ATTRIBUTE_ANGRY]}, 
	{"name": "Catch the Ball", "attributes": [ATTRIBUTE_ACTIVE, ATTRIBUTE_SELFISH]}, 
	{"name": "Spicy Challenge", "attributes": [ATTRIBUTE_ANGRY]}, 
	{"name": "Tiddlywink Competition", "attributes": [ATTRIBUTE_ANGRY, ATTRIBUTE_SMART]}, 
	{"name": "Survive the Bugs", "attributes": [ATTRIBUTE_ACTIVE]}, 
	{"name": "Open the Best Supermarket", "attributes": [ATTRIBUTE_SMART, ATTRIBUTE_NICE]}, 
	{"name": "Fly the Longest Away", "attributes": [ATTRIBUTE_SMART, ATTRIBUTE_ACTIVE]}, 
	{"name": "Plant the Most Trees", "attributes": [ATTRIBUTE_NICE]}, 
	{"name": "Find Your Way Back", "attributes": [ATTRIBUTE_SMART, ATTRIBUTE_ACTIVE]}, 
]

const BFDI_CHALLENGES: Array[Dictionary] = [
	{"name": "Balance Beam", "attributes": [ATTRIBUTE_SELFISH, ATTRIBUTE_ANGRY]}, 
	{"name": "Cross the Goiky Canal", "attributes": [ATTRIBUTE_SMART, ATTRIBUTE_SELFISH]}, 
	{"name": "Obstacle Course", "attributes": [ATTRIBUTE_ACTIVE, ATTRIBUTE_ANGRY]}, 
	{"name": "20 Question Test", "attributes": [ATTRIBUTE_SMART]}, 
	{"name": "Bake a Cake", "attributes": [ATTRIBUTE_NICE]}, 
	{"name": "Eat 100 Chocolate Balls", "attributes": [ATTRIBUTE_SELFISH]}, 
	{"name": "Bridge Crossing", "attributes": [ATTRIBUTE_SELFISH, ATTRIBUTE_NICE]}, 
	{"name": "Travel Across 3 Islands", "attributes": [ATTRIBUTE_SMART, ATTRIBUTE_NICE]}, 
	{"name": "Jigsaw Puzzle", "attributes": [ATTRIBUTE_SMART]}, 
	{"name": "Relay Race", "attributes": [ATTRIBUTE_ACTIVE, ATTRIBUTE_NICE]}, 
	{"name": "Six-Legged Race", "attributes": [ATTRIBUTE_ACTIVE]}, 
	{"name": "Crying Contest", "attributes": [ATTRIBUTE_ANGRY, ATTRIBUTE_NICE]}, 
	{"name": "Balloon Float", "attributes": [ATTRIBUTE_ANGRY]}, 
	{"name": "Ladder Climbing", "attributes": [ATTRIBUTE_ACTIVE, ATTRIBUTE_SELFISH]}, 
	{"name": "Find a Red Ball", "attributes": [ATTRIBUTE_SMART, ATTRIBUTE_SELFISH]}, 
	{"name": "Collect Loaves of Bread", "attributes": [ATTRIBUTE_SELFISH]}, 
	{"name": "Retrieve Marbles", "attributes": [ATTRIBUTE_SMART, ATTRIBUTE_ANGRY]}, 
	{"name": "Jump Hurdles", "attributes": [ATTRIBUTE_ACTIVE]}, 
	{"name": "Stay in the Barf Bag", "attributes": [ATTRIBUTE_ANGRY]}, 
	{"name": "Taco Making", "attributes": [ATTRIBUTE_NICE, ATTRIBUTE_SMART]}, 
	{"name": "Bowling", "attributes": [ATTRIBUTE_ANGRY]}, 
	{"name": "Frisbee Catching", "attributes": [ATTRIBUTE_NICE]}, 
	{"name": "Staring Contest", "attributes": [ATTRIBUTE_ANGRY, ATTRIBUTE_SELFISH]}, 
	{"name": "Unicycle Race", "attributes": [ATTRIBUTE_ANGRY, ATTRIBUTE_ACTIVE]}, 
	{"name": "Survive in Space", "attributes": [ATTRIBUTE_NICE, ATTRIBUTE_SMART]}, 
	{"name": "Long Jump", "attributes": [ATTRIBUTE_ACTIVE]}, 
	{"name": "Escape the Volcano", "attributes": [ATTRIBUTE_SMART, ATTRIBUTE_SELFISH]}, 
]

const BALDI_CHALLENGES: Array[Dictionary] = [
	{"name": "Solve the 3rd Notebook", "attributes": [ATTRIBUTE_SMART, ATTRIBUTE_NICE]}, 
	{"name": "Find the 7th Notebook", "attributes": [ATTRIBUTE_SMART, ATTRIBUTE_SELFISH, ATTRIBUTE_ACTIVE]}, 
	{"name": "Get into a whirlpool", "attributes": [ATTRIBUTE_ACTIVE, ATTRIBUTE_SELFISH]}, 
	{"name": "99 Question Test", "attributes": [ATTRIBUTE_SMART, ATTRIBUTE_NICE, ATTRIBUTE_ACTIVE]}, 
	{"name": "Decompile Baldi's Basics Plus", "attributes": [ATTRIBUTE_SMART]}, 
	{"name": "Listen to Baldi's Basics the Musical 99 times", "attributes": [ATTRIBUTE_ACTIVE, ATTRIBUTE_ANGRY]}, 
	{"name": "Find a way out, before Baldi catches you! (Hahahaaaa!!)", "attributes": [ATTRIBUTE_SELFISH, ATTRIBUTE_ACTIVE, ATTRIBUTE_NICE]}, 
	{"name": "Jump rope 10 times in a row", "attributes": [ATTRIBUTE_SELFISH]}, 
	{"name": "Brake Baldi's Ruler", "attributes": [ATTRIBUTE_SMART, ATTRIBUTE_ANGRY, ATTRIBUTE_SELFISH, ATTRIBUTE_ACTIVE]}
]

const CHARACTER_ATTRIBUTES: Dictionary = {
	"Bauble": [ATTRIBUTE_SMART, ATTRIBUTE_NICE], 
	"Bud": [ATTRIBUTE_SMART, ATTRIBUTE_SELFISH], 
	"Cappy": [ATTRIBUTE_SELFISH, ATTRIBUTE_SELFISH], 
	"Cubey": [ATTRIBUTE_ACTIVE, ATTRIBUTE_SELFISH], 
	"Gum": [ATTRIBUTE_ACTIVE, ATTRIBUTE_SELFISH], 
	"Highlighty": [ATTRIBUTE_NICE, ATTRIBUTE_SELFISH], 
	"Ice Pack": [ATTRIBUTE_SMART, ATTRIBUTE_NICE], 
	"Loafy": [ATTRIBUTE_NICE, ATTRIBUTE_NICE], 
	"Mechy": [ATTRIBUTE_ACTIVE, ATTRIBUTE_SELFISH], 
	"Pop Rock": [ATTRIBUTE_SMART, ATTRIBUTE_ACTIVE], 
	"Rubber Ball": [ATTRIBUTE_SMART, ATTRIBUTE_SMART], 
	"Soapy": [ATTRIBUTE_NICE, ATTRIBUTE_ACTIVE], 
	"Sodey": [ATTRIBUTE_NICE, ATTRIBUTE_ACTIVE], 
	"Softball": [ATTRIBUTE_ANGRY, ATTRIBUTE_ACTIVE], 
	"Squishy Cube": [ATTRIBUTE_ANGRY, ATTRIBUTE_NICE], 
	"Sticky": [ATTRIBUTE_NICE, ATTRIBUTE_SELFISH], 
	"Stress Ball": [ATTRIBUTE_ANGRY, ATTRIBUTE_SMART], 
	"Tee": [ATTRIBUTE_ACTIVE, ATTRIBUTE_ACTIVE], 
	"Tin": [ATTRIBUTE_ANGRY, ATTRIBUTE_ACTIVE], 
	"Windy": [ATTRIBUTE_ANGRY, ATTRIBUTE_ANGRY], 
}

const BFDI_CHARACTER_ATTRIBUTES: Dictionary = {
	"Blocky": [ATTRIBUTE_ANGRY, ATTRIBUTE_SELFISH], 
	"Bubble": [ATTRIBUTE_NICE, ATTRIBUTE_NICE], 
	"Coiny": [ATTRIBUTE_ANGRY, ATTRIBUTE_SMART], 
	"Eraser": [ATTRIBUTE_SELFISH, ATTRIBUTE_SELFISH], 
	"Firey": [ATTRIBUTE_ACTIVE, ATTRIBUTE_SELFISH], 
	"Flower": [ATTRIBUTE_ANGRY, ATTRIBUTE_ANGRY], 
	"Golf Ball": [ATTRIBUTE_SMART, ATTRIBUTE_SMART], 
	"Ice Cube": [ATTRIBUTE_SMART, ATTRIBUTE_ANGRY], 
	"Leafy": [ATTRIBUTE_NICE, ATTRIBUTE_ACTIVE], 
	"Match": [ATTRIBUTE_SELFISH, ATTRIBUTE_SELFISH], 
	"Needle": [ATTRIBUTE_ACTIVE, ATTRIBUTE_ACTIVE], 
	"Pen": [ATTRIBUTE_ACTIVE, ATTRIBUTE_NICE], 
	"Pencil": [ATTRIBUTE_NICE, ATTRIBUTE_SELFISH], 
	"Pin": [ATTRIBUTE_SELFISH, ATTRIBUTE_SMART], 
	"Snowball": [ATTRIBUTE_ANGRY, ATTRIBUTE_SELFISH], 
	"Rocky": [ATTRIBUTE_ANGRY, ATTRIBUTE_ACTIVE], 
	"Spongy": [ATTRIBUTE_ANGRY, ATTRIBUTE_NICE], 
	"Teardrop": [ATTRIBUTE_SMART, ATTRIBUTE_ACTIVE], 
	"Tennis Ball": [ATTRIBUTE_NICE, ATTRIBUTE_SMART], 
	"Woody": [ATTRIBUTE_NICE, ATTRIBUTE_NICE], 
}

const BALDI_CHARACTER_ATTRIBUTES: Dictionary = {
	"Baldi": [ATTRIBUTE_SMART, ATTRIBUTE_ANGRY], 
	"Playtime": [ATTRIBUTE_SELFISH, ATTRIBUTE_SELFISH], 
	"A&C": [ATTRIBUTE_NICE, ATTRIBUTE_SMART], 
	"It's a Bully": [ATTRIBUTE_SELFISH, ATTRIBUTE_ACTIVE], 
	"Principal": [ATTRIBUTE_ACTIVE, ATTRIBUTE_SMART], 
	"Gotta Sweep": [ATTRIBUTE_ACTIVE, ATTRIBUTE_ACTIVE], 
	"1st Prize": [ATTRIBUTE_SMART, ATTRIBUTE_SELFISH], 
	"Cloudy Copter": [ATTRIBUTE_ACTIVE, ATTRIBUTE_NICE], 
	"Chalkles": [ATTRIBUTE_SELFISH, ATTRIBUTE_ANGRY], 
	"Mrs. Pomp": [ATTRIBUTE_ANGRY, ATTRIBUTE_SMART], 
	"The Test": [ATTRIBUTE_SMART, ATTRIBUTE_SMART], 
	"Dr. Reflex": [ATTRIBUTE_ACTIVE, ATTRIBUTE_ANGRY], 
}

const ATTRIBUTE_ICONS: Dictionary = {
	ATTRIBUTE_ACTIVE: ACTIVE_ATTRIBUTE, 
	ATTRIBUTE_ANGRY: ANGRY_ATTRIBUTE, 
	ATTRIBUTE_NICE: NICE_ATTRIBUTE, 
	ATTRIBUTE_SELFISH: SELFISH_ATTRIBUTE, 
	ATTRIBUTE_SMART: SMART_ATTRIBUTE, 
}

signal game_started(active_players: Array[int])
signal player_seats_selected(human_sides: Array[int], bot_sides: Array[int])
signal challenge_started(challenge_name: String, attributes: Array[String])
signal character_movement_finished
signal card_play_phase_finished



@export_enum("Never:1", "When Player Eliminated:2", "Always:3")
var elimination_scene_card_draw_rule: int = 1
@export var keep_win_token_after_elimination: = false
@export var give_all_players_star_after_elimination: = true
@export var ads_removed: bool = true

var _last_viewport_size: = Vector2.ZERO
var _last_camera_centre: = Vector2.ZERO
var _last_camera_zoom: = Vector2.ZERO
var _last_safe_viewport_rect: = Rect2()
var bot_controller
var bot_action_input_locked: = false
var effect_move_animation_busy: = false
var selected_players: Array[bool] = [true, false, true, false]
var player_is_bot: Array[bool] = [false, false, false, false]
var player_order: Array[int] = [0, 2]
var player_button_scales: Array[float] = [1.0, 1.0, 1.0, 1.0]
var energy_points: = INITIAL_ENERGY
var add_energy_button_scale: = 1.0
var add_energy_button_pulse_tween: Tween
var indicators_enabled: = true
var indicator_button_scale: = 1.0
var board_indicator_visual: BoardIndicatorVisual
var board_indicator_drop_in_progress: = false
var challenge_indicator_suppressed_mini_index: = -1
var next_energy_recharge_unix: = 0
var last_energy_clock_unix: = 0
var last_energy_timer_second: = -1
var ads
var rewarded_energy_request_pending: = false
var privacy_options_applicable: = false
var privacy_canvas_layer: CanvasLayer
var privacy_button: LobbyPrivacyButton
var game_has_started: = false
var selected_game_mode: int = GameContentMode.CFDI
var player_content_modes: Array[int] = [
	GameContentMode.CFDI, 
	GameContentMode.CFDI, 
	GameContentMode.CFDI, 
	GameContentMode.CFDI, 
]
var hybrid_player_limits: Array[int] = [0, 0]
var lobby_logo_swipe_active: = false
var lobby_logo_swipe_start: = Vector2.ZERO
var lobby_logo_offset: = Vector2.ZERO
var lobby_logo_alpha: = 1.0
var mode_swipe_animation_running: = false
var default_sky_texture: Texture2D
var logo_scale: = Vector2.ONE
var overlay_alpha: = 1.0
var player_number_slide: = 0.0
var _start_animation_running: = false
var scene_deal_active: = false
var scene_deck_visible: = false
var scene_deck_position: = Vector2.ZERO
var scene_deck_rotation: = 0.0
var scene_deck_busy: = false
var current_scene_player_order: = 0
var current_scene_cards_dealt: = 0
var dealt_scene_cards: Array[Dictionary] = []
var scene_card_draw_pile: Array[Texture2D] = []
var scene_card_next_numbers: Array[int] = [1, 1, 1, 1]
var character_draft_active: = false
var character_deck_visible: = false
var character_deck_busy: = false
var character_deck_position: = Vector2.ZERO
var character_deck_rotation: = 0.0
var character_deck_scale: = 1.0
var current_character_player_order: = 0
var draft_character_cards: Array[Dictionary] = []
var player_character_cards: Array[Dictionary] = []
var draft_cards_finished: = 0
var scene_cycle_indices: Array[int] = [0, 0, 0, 0]
var character_cycle_indices: Array[int] = [0, 0, 0, 0]
var scene_cycle_busy: Array[bool] = [false, false, false, false]
var character_cycle_busy: Array[bool] = [false, false, false, false]
var hand_swipe_active: = false
var hand_swipe_start: = Vector2.ZERO
var hand_swipe_side: = -1
var hand_swipe_scene_stack: = false
var star_draft_active: = false
var star_draft_busy: = false
var current_star_player_order: = 0
var draft_stars: Array[Dictionary] = []
var player_stars: Array[Dictionary] = []
var character_mini_placement_active: = false
var character_minis_on_board: Array[Dictionary] = []
var character_mini_placements_finished: = 0
var character_mini_target_count: = 0
var challenge_phase_active: = false
var challenge_card_visible: = false
var challenge_card_busy: = false
var challenge_card_face_up: = false
var challenge_card_position: = Vector2.ZERO
var challenge_card_rotation: = 0.0
var challenge_card_flip_scale: = 1.0
var current_challenge: Dictionary = {}
var discarded_challenge_keys: Dictionary = {}
var challenge_opener_side: = -1
var character_movement_phase_active: = false
var current_movement_player_order: = 0
var dragged_mini_index: = -1
var dragged_mini_offset: = Vector2.ZERO
var dragged_mini_original_position: = Vector2.ZERO
var dragged_mini_scale_tween: Tween
var last_touch_event_ms: = -10000
const EMULATED_MOUSE_BLOCK_MS: = 700
var card_play_phase_active: = false
var current_card_player_order: = 0
var card_turn_serial: = 0
var consecutive_passes: = 0
var turn_scene_offer_visible: = false
var card_turn_action_committed: = false
var dragged_scene_play_index: = -1
var dragged_scene_play_start: = Vector2.ZERO
var highlighted_character_card_index: = -1
var scene_card_drag_moved: = false
var card_effect_busy: = false
var swap_source_character_index: = -1
var die_roll_active: = false
var die_roll_busy: = false
var die_position: = Vector2.ZERO
var die_rotation: = 0.0
var die_base_rotation: = 0.0
var die_visual_scale: = 1.0
var die_visual_frame: = 0
var die_face: = 1
var die_roll_animation_active: = false
var pending_boost_character_index: = -1
var card_being_used_index: = -1
var pending_effect_mini_index: = -1
var pending_effect_target_column: = -1
var pending_effect_target_row: = -1
var pending_effect_move_active: = false
var swap_drag_active: = false
var highlighted_swap_mini_index: = -1
var swap_displaced_mini_index: = -1
var elimination_phase_active: = false
var elimination_die_ready: = false
var elimination_die_busy: = false
var elimination_leader_side: = -1
var elimination_candidates: Array[int] = []
var elimination_used_win_token_indices: Array[int] = []
var player_eliminated_this_round: = false
var eliminated_players: Array[bool] = [false, false, false, false]
var game_over: = false
var alliance_phase_active: = false
var alliance_target_character_index: = -1
var alliance_target_mini_index: = -1
var alliance_origin_column: = -1
var alliance_move_amount: = 0
var alliance_active_side: = -1
var alliance_offer_side: = -1
var alliance_offer_stars: = 0
var alliance_accepted_sides: Array[int] = []
var alliance_move_queue: Array[int] = []
var alliance_current_move_side: = -1
var alliance_main_move_done: = false
var alliance_moved_sides: Array[int] = []
var alliance_offered_star_items: Array[Dictionary] = []
var alliance_star_layout_tween: Tween
var alliance_movement_unlock_time: = 0
var alliance_star_transfer_busy: = false
var alliance_button_flash_on: = true
var card_turn_button_flash_on: = true
var next_alliance_button_flash_ms: = 0
var next_card_turn_button_flash_ms: = 0
var alliance_eligibility_cache: Array[bool] = [false, false, false, false]
var alliance_eligibility_dirty: = true
var player_button_visuals: Array[PlayerButtonVisual] = []
var static_board_visual: StaticBoardVisual
var dragged_scene_card_visual: DraggedSceneCardVisual
var scene_hand_reflow_tween: Tween
var character_hand_reflow_tween: Tween
var star_hand_reflow_tweens: Array = [null, null, null, null]
var music_player: AudioStreamPlayer
var music_standby_player: AudioStreamPlayer
var music_enabled: = true
var music_button_scale: = 1.0
var music_fade_tween: Tween
var ad_paused_music_players: Array[AudioStreamPlayer] = []
var gameplay_music_started: = false
var call_to_adventure_started: = false
var final_two_music_faded: = false


func _ready() -> void :
	randomize()
	music_player = AudioStreamPlayer.new()
	music_player.name = "Music"
	add_child(music_player)
	music_player.finished.connect(_restart_music_player.bind(music_player))
	music_standby_player = AudioStreamPlayer.new()
	music_standby_player.name = "MusicStandby"
	add_child(music_standby_player)
	music_standby_player.finished.connect(
		_restart_music_player.bind(music_standby_player)
	)
	win.finished.connect(_on_win_sound_finished)
	die_roll.visible = false
	die_roll.centered = true
	die_roll.z_index = 40
	die_roll.frame_changed.connect(_sync_die_roll_sprite)
	_load_energy_points()
	_create_privacy_button()
	_setup_ads()
	if ads == null or not ads.fullscreen_ad_showing:
		_play_music(ITTY_BITTY_8_BIT, 0.0)
	static_board_visual = StaticBoardVisual.new()
	static_board_visual.name = "StaticBoardVisual"
	static_board_visual.z_index = -5
	add_child(static_board_visual)
	board_indicator_visual = BoardIndicatorVisual.new()
	board_indicator_visual.name = "BoardIndicatorVisual"
	board_indicator_visual.z_index = -4
	board_indicator_visual.visible = false
	add_child(board_indicator_visual)
	for side in 4:
		var button_visual: = PlayerButtonVisual.new()
		button_visual.name = "PlayerButtonVisual%d" % side
		button_visual.z_index = 20
		add_child(button_visual)
		player_button_visuals.append(button_visual)
	dragged_scene_card_visual = DraggedSceneCardVisual.new()
	dragged_scene_card_visual.name = "DraggedSceneCardVisual"
	dragged_scene_card_visual.z_index = 30
	dragged_scene_card_visual.visible = false
	add_child(dragged_scene_card_visual)
	bot_controller = get_node_or_null("BotController")
	if bot_controller == null:
		var controller_path = get_script().resource_path.get_base_dir().path_join("BotController.gd")
		var controller_script = load(controller_path)
		if controller_script != null:
			bot_controller = controller_script.new()
			bot_controller.name = "BotController"
			add_child(bot_controller)
		else:
			push_error("BotController.gd could not be loaded from: " + controller_path)
	if bot_controller != null and bot_controller.has_method("setup"):
		bot_controller.setup(self)
	else:
		push_error("BotController is missing its setup() method.")


	default_sky_texture = sky.texture
	sky.z_index = -10
	background.z_index = -10
	grass.z_index = -10
	hybrid_background.z_index = -10
	_apply_selected_game_mode()

	_last_viewport_size = get_viewport_rect().size
	_last_camera_centre = camera_2d.get_screen_center_position()
	_last_camera_zoom = camera_2d.zoom
	_last_safe_viewport_rect = _get_safe_viewport_rect()
	_refresh_static_board_visual()
	_refresh_player_button_visuals()
	queue_redraw()


func _notification(what: int) -> void :
	if (what == NOTIFICATION_APPLICATION_PAUSED
		or what == NOTIFICATION_WM_CLOSE_REQUEST):
		if last_energy_clock_unix > 0:
			_save_energy_points()



func _process(delta: float) -> void :
	_update_energy_recharge_timer()
	if bot_controller != null and bot_controller.has_method("tick"):
		bot_controller.tick(delta)
	if _start_animation_running:
		queue_redraw()
	_update_player_button_flashes()
	_refresh_player_button_visuals()
	_refresh_board_indicators()

	var viewport_size: = get_viewport_rect().size
	var camera_centre: = camera_2d.get_screen_center_position()
	var camera_zoom: = camera_2d.zoom
	var safe_viewport_rect: = _get_safe_viewport_rect()
	if (viewport_size != _last_viewport_size
		or camera_centre != _last_camera_centre
		or camera_zoom != _last_camera_zoom
		or safe_viewport_rect != _last_safe_viewport_rect):
		_last_viewport_size = viewport_size
		_last_camera_centre = camera_centre
		_last_camera_zoom = camera_zoom
		_last_safe_viewport_rect = safe_viewport_rect
		_refresh_card_layouts(true)
		_refresh_static_board_visual()
		_refresh_player_button_visuals()
		_layout_privacy_button()
		queue_redraw()


func _update_player_button_flashes() -> void :
	var now: = Time.get_ticks_msec()
	var redraw_needed: = false
	if alliance_eligibility_dirty:
		_refresh_alliance_eligibility_cache()
		redraw_needed = true

	var alliance_flash_active: = (
		alliance_phase_active
		and alliance_eligibility_cache.has(true)
	)
	if alliance_flash_active:
		if next_alliance_button_flash_ms <= 0:
			alliance_button_flash_on = true
			next_alliance_button_flash_ms = now + 280
			redraw_needed = true
		elif now >= next_alliance_button_flash_ms:
			alliance_button_flash_on = not alliance_button_flash_on
			next_alliance_button_flash_ms = now + 280
			redraw_needed = true
	else:
		if not alliance_button_flash_on:
			alliance_button_flash_on = true
			redraw_needed = true
		next_alliance_button_flash_ms = 0

	var card_flash_active: = (
		card_play_phase_active
		and not card_turn_action_committed
	)
	if card_flash_active:
		if next_card_turn_button_flash_ms <= 0:
			card_turn_button_flash_on = true
			next_card_turn_button_flash_ms = now + 320
			redraw_needed = true
		elif now >= next_card_turn_button_flash_ms:
			card_turn_button_flash_on = not card_turn_button_flash_on
			next_card_turn_button_flash_ms = now + 320
			redraw_needed = true
	else:
		if not card_turn_button_flash_on:
			card_turn_button_flash_on = true
			redraw_needed = true
		next_card_turn_button_flash_ms = 0

	if redraw_needed:
		_refresh_player_button_visuals()


func _refresh_alliance_eligibility_cache() -> void :
	for side in 4:
		alliance_eligibility_cache[side] = _is_player_eligible_to_offer_alliance(side)
	alliance_eligibility_dirty = false


func _invalidate_alliance_eligibility() -> void :
	alliance_eligibility_dirty = true


func _refresh_static_board_visual() -> void :
	if static_board_visual == null:
		return
	static_board_visual.update_board({
		"visible_size": _get_visible_world_size(), 
		"centre": to_local(camera_2d.get_screen_center_position()), 
		"columns": BOARD_COLUMNS, 
		"rows": BOARD_ROWS, 
		"width_ratio": _get_board_width_ratio(_get_visible_world_size()), 
		"height_ratio": _get_board_height_ratio(_get_visible_world_size()), 
		"gap_ratio": COLUMN_GAP_RATIO, 
		"top_colour": BOARD_TOP_COLOUR, 
		"bottom_colour": BOARD_BOTTOM_COLOUR, 
		"line_colour": BOARD_LINE_COLOUR, 
		"line_width": BOARD_LINE_WIDTH, 
		"outline_colour": BOARD_OUTLINE_COLOUR, 
		"outline_width": BOARD_OUTLINE_WIDTH, 
		"checker_rows": WINNER_CHECKER_ROWS, 
		"checker_columns": WINNER_CHECKER_COLUMNS, 
		"checker_colour": WINNER_CHECKER_COLOUR, 
	}, (YTP)if(selected_game_mode==GameContentMode.BALDI)else(STAR))


func _refresh_player_button_visuals() -> void :
	if player_button_visuals.size() < 4:
		return
	var visible_size: = _get_visible_world_size()
	var centre: = to_local(camera_2d.get_screen_center_position())
	for player_index in 4:
		var active: = selected_players[player_index]
		var receiving_alliance_offer: = (
			game_has_started
			and alliance_phase_active
			and alliance_offer_side >= 0
			and player_index == alliance_active_side
		)
		var button_colour: = PLAYER_ACTIVE_COLOUR if active else PLAYER_INACTIVE_COLOUR
		if not game_has_started and active and player_is_bot[player_index]:
			button_colour = PLAYER_BOT_COLOUR
		if game_has_started and active:
			button_colour = (
				Color.GREEN if player_index == _get_current_turn_side() else Color.BLACK
			)
			if eliminated_players[player_index]:
				button_colour = Color.RED
			elif player_index in alliance_accepted_sides:
				button_colour = Color("#1e90ff")
			elif alliance_eligibility_cache[player_index]:
				button_colour = (
					Color("#1e90ff") if alliance_button_flash_on else Color.BLACK
				)
			elif (card_play_phase_active
				and player_index == _get_current_turn_side()
				and not card_turn_action_committed
				and not card_turn_button_flash_on):
				button_colour = Color.BLACK
		if receiving_alliance_offer:
			button_colour = Color.RED
		var order_index: = player_order.find(player_index)
		var label: = str(order_index + 1) if order_index >= 0 else "+"
		if receiving_alliance_offer:
			label = "X"
		elif alliance_eligibility_cache[player_index]:
			label = "OFFER"
		elif _player_is_waiting_for_alliance_move(player_index):
			label = "WAIT"
		elif (card_play_phase_active
			and active
			and not eliminated_players[player_index]
			and player_index == _get_current_turn_side()
			and not card_turn_action_committed):
			label = "PASS"
		var label_colour: = (
			Color("#3e281b")
			if active and not player_is_bot[player_index]
			else Color.WHITE
		)
		if game_has_started and active:
			label_colour = Color.WHITE
		var lobby_state_label: = ""
		if not game_has_started:
			if not active:
				lobby_state_label = "NONE"
			elif player_is_bot[player_index]:
				lobby_state_label = "COMPUTER"
			else:
				lobby_state_label = "HUMAN"
		var player_position: = _get_player_position(player_index, centre, visible_size)
		player_position += (
			_get_player_right_offset(player_index, visible_size) * player_number_slide
		)
		player_button_visuals[player_index].update_visual(
			player_position, 
			_get_player_rotation(player_index), 
			player_button_scales[player_index], 
			_get_player_button_radius(visible_size, player_index), 
			_get_action_button_outline_width(visible_size, player_index), 
			not game_has_started or selected_players[player_index], 
			button_colour, 
			label, 
			_get_player_font(player_index), 
			label_colour, 
			lobby_state_label
		)


func _draw() -> void :
	var viewport_size: = get_viewport_rect().size
	var camera_zoom: = camera_2d.zoom
	var visible_world_size: = Vector2(
		viewport_size.x / camera_zoom.x, 
		viewport_size.y / camera_zoom.y
	)
	var camera_centre: = to_local(camera_2d.get_screen_center_position())

	_draw_character_minis(visible_world_size)
	_draw_scene_cards(visible_world_size)
	_draw_character_cards(visible_world_size)
	_draw_stars(visible_world_size)
	_draw_alliance_offer(visible_world_size)
	_draw_scene_card_overlay()


	_draw_character_draft_overlay(visible_world_size)
	_draw_challenge_card(visible_world_size)
	_draw_die(visible_world_size)
	_draw_centre_stars_overlay(visible_world_size)


	_draw_lobby(camera_centre, visible_world_size)


func _unhandled_input(event: InputEvent) -> void :


	if bot_action_input_locked:
		get_viewport().set_input_as_handled()
		return
	if effect_move_animation_busy:
		get_viewport().set_input_as_handled()
		return
	if _start_animation_running or mode_swipe_animation_running:
		return



	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		last_touch_event_ms = Time.get_ticks_msec()
	elif ((event is InputEventMouseButton or event is InputEventMouseMotion)
		and Time.get_ticks_msec() - last_touch_event_ms < EMULATED_MOUSE_BLOCK_MS):
		return
	if card_play_phase_active and dragged_scene_play_index >= 0:
		var card_drag_screen: = Vector2.ZERO
		var card_drag_motion: = false
		if event is InputEventMouseMotion:
			card_drag_screen = event.position
			card_drag_motion = true
		elif event is InputEventScreenDrag:
			card_drag_screen = event.position
			card_drag_motion = true
		if card_drag_motion:
			var card_drag_world: = get_viewport().get_canvas_transform().affine_inverse() * card_drag_screen
			var card_drag_local: = to_local(card_drag_world)
			var card: = dealt_scene_cards[dragged_scene_play_index]
			card.position = card_drag_local
			dealt_scene_cards[dragged_scene_play_index] = card
			scene_card_drag_moved = true
			if dragged_scene_card_visual != null and dragged_scene_card_visual.visible:
				dragged_scene_card_visual.move_card(card_drag_local)
			var next_highlight: = _find_character_card_at_point(
				card_drag_local, _get_visible_world_size()
			)
			if next_highlight != highlighted_character_card_index:
				highlighted_character_card_index = next_highlight
				queue_redraw()
			get_viewport().set_input_as_handled()
			return

	if (character_movement_phase_active or pending_effect_move_active or swap_drag_active) and dragged_mini_index >= 0:
		var drag_screen_position: = Vector2.ZERO
		var is_drag_motion: = false
		if event is InputEventMouseMotion:
			drag_screen_position = event.position
			is_drag_motion = true
		elif event is InputEventScreenDrag:
			drag_screen_position = event.position
			is_drag_motion = true
		if is_drag_motion:
			var drag_world: = get_viewport().get_canvas_transform().affine_inverse() * drag_screen_position
			var item: = character_minis_on_board[dragged_mini_index]
			item.position = to_local(drag_world) + dragged_mini_offset
			character_minis_on_board[dragged_mini_index] = item
			if swap_drag_active:
				highlighted_swap_mini_index = _find_swap_target_at_point(
					to_local(drag_world), _get_visible_world_size()
				)
			queue_redraw()
			get_viewport().set_input_as_handled()
			return

	var screen_position: = Vector2.ZERO
	var is_pointer_event: = false
	var pressed: = false
	var released: = false
	if event is InputEventMouseButton:
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		is_pointer_event = true
		pressed = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
		released = not event.pressed
		screen_position = event.position
	elif event is InputEventScreenTouch:
		is_pointer_event = true
		pressed = event.pressed
		released = not event.pressed
		screen_position = event.position

	if not is_pointer_event:
		return

	var world_position: = get_viewport().get_canvas_transform().affine_inverse() * screen_position
	var local_position: = to_local(world_position)
	var viewport_size: = get_viewport_rect().size
	var visible_world_size: = Vector2(
		viewport_size.x / camera_2d.zoom.x, 
		viewport_size.y / camera_2d.zoom.y
	)
	var camera_centre: = to_local(camera_2d.get_screen_center_position())

	if game_has_started:
		if pressed and game_over:
			get_viewport().set_input_as_handled()
			_return_to_lobby_after_game()
			return
		if (pressed and elimination_phase_active and elimination_die_ready
			and not is_player_bot(elimination_leader_side)
			and _point_is_in_card(local_position, die_position, die_rotation, _get_die_size(visible_world_size))):
			_roll_elimination_die()
			get_viewport().set_input_as_handled()
			return
		if released and (pending_effect_move_active or swap_drag_active) and dragged_mini_index >= 0:
			_finish_card_effect_mini_drag(local_position, visible_world_size)
			get_viewport().set_input_as_handled()
			return
		if card_play_phase_active and released and dragged_scene_play_index >= 0:
			_finish_scene_card_play_drag(local_position, visible_world_size)
			get_viewport().set_input_as_handled()
			return
		if released and hand_swipe_active:
			_finish_hand_swipe(local_position, visible_world_size)
			get_viewport().set_input_as_handled()
			return
		if released and character_movement_phase_active:
			_handle_character_movement_pointer(local_position, false, true, visible_world_size)
			get_viewport().set_input_as_handled()
			return
		if not pressed:
			return
		if alliance_phase_active and _handle_alliance_press(local_position, visible_world_size, false):
			get_viewport().set_input_as_handled()
			return
		if pending_effect_move_active and alliance_target_character_index >= 0:
			var alliance_swipe_target: = _find_hand_swipe_target(local_position, visible_world_size)
			if not alliance_swipe_target.is_empty():
				hand_swipe_active = true
				hand_swipe_start = local_position
				hand_swipe_side = alliance_swipe_target.side
				hand_swipe_scene_stack = alliance_swipe_target.scene_stack
				get_viewport().set_input_as_handled()
				return
		if pending_effect_move_active or swap_drag_active:
			_handle_card_effect_mini_press(local_position, visible_world_size, false)
			get_viewport().set_input_as_handled()
			return
		if (card_play_phase_active
			and _handle_card_play_phase_press(local_position, visible_world_size)):
			get_viewport().set_input_as_handled()
			return
		var swipe_target: = _find_hand_swipe_target(local_position, visible_world_size)
		if not swipe_target.is_empty():
			hand_swipe_active = true
			hand_swipe_start = local_position
			hand_swipe_side = swipe_target.side
			hand_swipe_scene_stack = swipe_target.scene_stack
			if (card_play_phase_active
				and swipe_target.scene_stack
				and swipe_target.side == _get_current_turn_side()
				and not card_effect_busy):
				var scene_indices: = _get_owner_scene_card_indices(swipe_target.side)
				if not scene_indices.is_empty():
					dragged_scene_play_index = scene_indices[
						scene_cycle_indices[swipe_target.side] %scene_indices.size()
					]
					dragged_scene_play_start = dealt_scene_cards[dragged_scene_play_index].position
					scene_card_drag_moved = false
					_show_dragged_scene_card_visual(dragged_scene_play_index)
					queue_redraw()
			get_viewport().set_input_as_handled()
			return
		if character_movement_phase_active and not is_player_bot(_get_current_turn_side()):
			_handle_character_movement_pointer(local_position, pressed, released, visible_world_size)
			get_viewport().set_input_as_handled()
			return
		if challenge_phase_active and not is_player_bot(challenge_opener_side):
			_handle_challenge_card_input(local_position, visible_world_size)
		elif star_draft_active and not is_player_bot(_get_current_turn_side()):
			_handle_star_input(local_position, visible_world_size)
		elif character_draft_active and not is_player_bot(_get_current_turn_side()):
			_handle_character_card_input(local_position, visible_world_size)
		elif not scene_deal_active or not is_player_bot(_get_current_turn_side()):
			_handle_scene_card_input(local_position, visible_world_size)
		get_viewport().set_input_as_handled()
		return

	if released and lobby_logo_swipe_active:
		lobby_logo_swipe_active = false
		var logo_delta: = local_position - lobby_logo_swipe_start
		var swipe_threshold = min(visible_world_size.x, visible_world_size.y) * LOGO_SWIPE_THRESHOLD_RATIO
		if abs(logo_delta.x) >= swipe_threshold and abs(logo_delta.x) > abs(logo_delta.y):
			_change_game_mode(-1 if logo_delta.x > 0.0 else 1)
		elif (_get_logo_rect(camera_centre, visible_world_size).has_point(local_position)
			and _can_start_game()):
			_start_game()
		get_viewport().set_input_as_handled()
		return
	if not pressed:
		return

	if _get_music_toggle_rect(camera_centre, visible_world_size).grow(
		min(visible_world_size.x, visible_world_size.y) * 0.012
	).has_point(local_position):
		_toggle_music()
		get_viewport().set_input_as_handled()
		return

	if _get_indicator_toggle_rect(camera_centre, visible_world_size).grow(
		min(visible_world_size.x, visible_world_size.y) * 0.012
	).has_point(local_position):
		_toggle_indicators()
		get_viewport().set_input_as_handled()
		return

	if (energy_points < MAX_ENERGY
		and _get_add_energy_rect(camera_centre, visible_world_size).grow(
			min(visible_world_size.x, visible_world_size.y) * 0.012
		).has_point(local_position)):
		_request_rewarded_energy()
		get_viewport().set_input_as_handled()
		return

	for player_index in 4:
		if local_position.distance_to(_get_player_position(player_index, camera_centre, visible_world_size)) <= _get_player_button_radius(visible_world_size, player_index):
			_toggle_player(player_index)
			get_viewport().set_input_as_handled()
			return

	if _get_logo_rect(camera_centre, visible_world_size).has_point(local_position):
		lobby_logo_swipe_active = true
		lobby_logo_swipe_start = local_position
		get_viewport().set_input_as_handled()
		return


func _draw_lobby(centre: Vector2, visible_size: Vector2) -> void :
	if overlay_alpha > 0.0:
		var overlay_rect: = Rect2(centre - visible_size * 0.5, visible_size)
		var overlay_colour: = LOBBY_OVERLAY_COLOUR
		overlay_colour.a *= overlay_alpha
		draw_rect(overlay_rect, overlay_colour)

	if not game_has_started:
		var logo_rect: = _get_logo_rect(centre, visible_size)
		var scaled_logo_rect: = Rect2(
			logo_rect.get_center() + lobby_logo_offset - logo_rect.size * logo_scale * 0.5, 
			logo_rect.size * logo_scale
		)
		var logo_colour: = Color.WHITE
		if not _can_start_game():
			logo_colour = Color(0.55, 0.55, 0.55, 0.75)
		logo_colour.a *= lobby_logo_alpha
		var energy_rect: = _get_energy_rect(centre, visible_size)
		draw_texture_rect(
			ENERGY_TEXTURES[clampi(energy_points, 0, MAX_ENERGY)], 
			energy_rect, 
			false
		)
		if energy_points < FREE_ENERGY_CAP:
			_draw_energy_recharge_timer(energy_rect, visible_size)
		if energy_points < MAX_ENERGY:
			var add_energy_rect: = _get_add_energy_rect(centre, visible_size)
			var scaled_add_rect: = Rect2(
				add_energy_rect.get_center() - add_energy_rect.size * add_energy_button_scale * 0.5, 
				add_energy_rect.size * add_energy_button_scale
			)
			draw_texture_rect(_1_GAME, scaled_add_rect, false)
		var indicator_rect: = _get_indicator_toggle_rect(centre, visible_size)
		var scaled_indicator_rect: = Rect2(
			indicator_rect.get_center() - indicator_rect.size * indicator_button_scale * 0.5, 
			indicator_rect.size * indicator_button_scale
		)
		draw_texture_rect(
			INDICATOR_ON if indicators_enabled else INDICATOR_OFF, 
			scaled_indicator_rect, 
			false
		)
		var music_rect: = _get_music_toggle_rect(centre, visible_size)
		var scaled_music_rect: = Rect2(
			music_rect.get_center() - music_rect.size * music_button_scale * 0.5, 
			music_rect.size * music_button_scale
		)
		draw_texture_rect(
			MUSIC_ON if music_enabled else MUSIC_OFF, 
			scaled_music_rect, 
			false
		)
		var swipe_texture_size: = SWIPE.get_size()
		var lobby_ui_scale: = PHONE_LOBBY_SCALE if _is_phone_layout(visible_size) else 1.0
		var swipe_max_size: = Vector2(
			visible_size.x * 0.24 * lobby_ui_scale, 
			visible_size.y * 0.075 * lobby_ui_scale
		)
		var swipe_scale = min(
			swipe_max_size.x / swipe_texture_size.x, 
			swipe_max_size.y / swipe_texture_size.y
		)
		var swipe_size = swipe_texture_size * swipe_scale
		var swipe_centre: = Vector2(
			logo_rect.get_center().x, 
			logo_rect.end.y + swipe_size.y * 0.78
		)
		draw_texture_rect(
			SWIPE, 
			Rect2(swipe_centre - swipe_size * 0.5, swipe_size), 
			false
		)
		_draw_lobby_attribution(swipe_centre, swipe_size, visible_size)

		draw_texture_rect(_get_game_logo_texture(), scaled_logo_rect, false, logo_colour)

func _get_current_turn_side() -> int:
	if game_over:
		return elimination_leader_side
	if card_play_phase_active and current_card_player_order < player_order.size():
		return player_order[current_card_player_order]
	if character_movement_phase_active and current_movement_player_order < player_order.size():
		return player_order[current_movement_player_order]
	if elimination_phase_active:
		return elimination_leader_side
	if challenge_phase_active:
		return challenge_opener_side
	if star_draft_active and current_star_player_order < player_order.size():
		return player_order[current_star_player_order]
	if character_draft_active and current_character_player_order < player_order.size():
		return player_order[current_character_player_order]
	if scene_deal_active and current_scene_player_order < player_order.size():
		return player_order[current_scene_player_order]
	return -1


func _get_player_right_offset(player_index: int, visible_size: Vector2) -> Vector2:

	match player_index:
		0:
			return Vector2.LEFT * visible_size.x * 0.4
		1:
			return Vector2.UP * visible_size.y * 0.4
		2:
			return Vector2.RIGHT * visible_size.x * 0.4
		_:
			return Vector2.DOWN * visible_size.y * 0.4


func _get_player_position(player_index: int, centre: Vector2, visible_size: Vector2) -> Vector2:
	var safe_rect: = _get_safe_world_rect(visible_size)
	var radius: = _get_player_button_radius(visible_size, player_index)


	var margin: = radius + ACTION_BUTTON_EDGE_GAP
	match player_index:
		0:
			return Vector2(centre.x, safe_rect.position.y + margin)
		1:
			return Vector2(safe_rect.end.x - margin, centre.y)
		2:
			return Vector2(centre.x, safe_rect.end.y - margin)
		_:
			return Vector2(safe_rect.position.x + margin, centre.y)


func _is_phone_layout(_visible_size: Vector2) -> bool:


	var viewport_size: = get_viewport_rect().size
	var short_side = min(viewport_size.x, viewport_size.y)
	var long_side = max(viewport_size.x, viewport_size.y)
	var aspect_ratio = long_side / max(short_side, 1.0)
	var mobile_platform: = OS.get_name() == "Android" or OS.get_name() == "iOS"
	var phone_sized_display: = false
	if mobile_platform:
		var dpi: = float(DisplayServer.screen_get_dpi())
		var display_size: = Vector2(DisplayServer.screen_get_size())
		if dpi > 0.0:
			var diagonal_inches: = display_size.length() / dpi
			phone_sized_display = diagonal_inches < 7.5
	return (
		short_side < PHONE_SHORTEST_SIDE_THRESHOLD
		or aspect_ratio >= PHONE_ASPECT_RATIO_THRESHOLD
		or phone_sized_display
	)


func _get_board_width_ratio(visible_size: Vector2) -> float:
	return PHONE_BOARD_WIDTH_RATIO if _is_phone_layout(visible_size) else BOARD_WIDTH_RATIO


func _get_board_height_ratio(visible_size: Vector2) -> float:
	return PHONE_BOARD_HEIGHT_RATIO if _is_phone_layout(visible_size) else BOARD_HEIGHT_RATIO


func _get_player_button_radius(visible_size: Vector2, _side: int = -1) -> float:


	var card_height: = _get_unobstructed_short_edge_card_height(visible_size)

	var diameter: = card_height * ACTION_BUTTON_CARD_HEIGHT_RATIO
	return diameter * 0.5


func _get_unobstructed_short_edge_card_height(visible_size: Vector2) -> float:
	var texture_size: = (SCENE_CARD_BACK if selected_game_mode == GameContentMode.CFDI else BALDISCENE_CARD_BACK).get_size()
	var aspect_ratio: = texture_size.x / texture_size.y
	var portrait: = visible_size.x <= visible_size.y
	var edge_span: = visible_size.x if portrait else visible_size.y
	var hand_span_ratio: = 0.26 if _is_phone_layout(visible_size) else 0.22
	var hand_span: = edge_span * hand_span_ratio
	var card_width_fraction: = 0.72 if _is_phone_layout(visible_size) else 1.0
	var width_limited_height: = hand_span * card_width_fraction / aspect_ratio

	var board_size: = _get_board_rect(visible_size).size
	var available_depth: = (
		(visible_size.y - board_size.y) * 0.5
		if portrait
		else (visible_size.x - board_size.x) * 0.5
	)
	var depth_limited_height: = maxf(available_depth - 24.0, 4.0)
	return minf(depth_limited_height, width_limited_height)


func _get_context_button_scale(visible_size: Vector2, side: int = -1) -> float:
	return _get_player_button_radius(visible_size, side) / PLAYER_BUTTON_RADIUS


func _get_action_button_outline_width(visible_size: Vector2, side: int = -1) -> float:
	var diameter: = _get_player_button_radius(visible_size, side) * 2.0
	return maxf(ACTION_BUTTON_MIN_OUTLINE, diameter * ACTION_BUTTON_OUTLINE_RATIO)


func _get_safe_world_rect(visible_size: Vector2) -> Rect2:
	var centre: = to_local(camera_2d.get_screen_center_position())
	var full_world_rect: = Rect2(centre - visible_size * 0.5, visible_size)
	var viewport_size: = get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return full_world_rect

	var safe_pixels: = _get_safe_viewport_rect()
	if safe_pixels.size.x <= 0.0 or safe_pixels.size.y <= 0.0:
		return full_world_rect

	var world_per_pixel: = visible_size / viewport_size
	return Rect2(
		full_world_rect.position + safe_pixels.position * world_per_pixel, 
		safe_pixels.size * world_per_pixel
	)


func _get_safe_viewport_rect() -> Rect2:
	var viewport_size: = get_viewport_rect().size
	var viewport_pixels: = Rect2(Vector2.ZERO, viewport_size)
	if OS.get_name() != "Android" and OS.get_name() != "iOS":
		return viewport_pixels

	var display_size: = Vector2(DisplayServer.screen_get_size())
	if display_size.x <= 0.0 or display_size.y <= 0.0:
		return viewport_pixels
	var display_safe_area: = Rect2(DisplayServer.get_display_safe_area())
	var viewport_scale: = viewport_size / display_size
	var safe_pixels: = Rect2(
		display_safe_area.position * viewport_scale, 
		display_safe_area.size * viewport_scale
	)
	safe_pixels = safe_pixels.intersection(viewport_pixels)
	if safe_pixels.size.x <= 0.0 or safe_pixels.size.y <= 0.0:
		return viewport_pixels
	return safe_pixels


func _get_logo_rect(centre: Vector2, visible_size: Vector2) -> Rect2:
	var lobby_scale: = PHONE_LOBBY_SCALE if _is_phone_layout(visible_size) else 1.0
	var max_size: = Vector2(
		visible_size.x * 0.48 * lobby_scale, 
		visible_size.y * 0.3 * lobby_scale
	)
	var layout_centre: = centre
	var aspect_ratio = max(visible_size.x, visible_size.y) / maxf(
		min(visible_size.x, visible_size.y), 1.0
	)
	if aspect_ratio <= 1.28:


		var central_rect: = _get_square_lobby_central_rect(centre, visible_size)
		layout_centre = central_rect.get_center()
		max_size.x = minf(max_size.x, central_rect.size.x * 0.58)
		max_size.y = minf(max_size.y, central_rect.size.y * 0.3)
	var texture_size: = _get_game_logo_texture().get_size()
	var scale_factor = min(max_size.x / texture_size.x, max_size.y / texture_size.y)
	var size = texture_size * scale_factor
	return Rect2(layout_centre - size * 0.5, size)


func _get_square_lobby_central_rect(centre: Vector2, visible_size: Vector2) -> Rect2:
	var top_position: = _get_player_position(0, centre, visible_size)
	var right_position: = _get_player_position(1, centre, visible_size)
	var bottom_position: = _get_player_position(2, centre, visible_size)
	var left_position: = _get_player_position(3, centre, visible_size)
	var clearance: = maxf(min(visible_size.x, visible_size.y) * 0.018, 12.0)
	var left: = left_position.x + _get_player_button_radius(visible_size, 3) + clearance
	var right: = right_position.x - _get_player_button_radius(visible_size, 1) - clearance
	var top: = top_position.y + _get_player_button_radius(visible_size, 0) + clearance
	var bottom: = bottom_position.y - _get_player_button_radius(visible_size, 2) - clearance
	return Rect2(
		Vector2(left, top), 
		Vector2(maxf(right - left, 1.0), maxf(bottom - top, 1.0))
	)


func _get_energy_rect(centre: Vector2, visible_size: Vector2) -> Rect2:
	var logo_rect: = _get_logo_rect(centre, visible_size)
	var texture_size: = ENERGY_9.get_size()
	var available_size: = logo_rect.size * ENERGY_ICON_LOGO_SIZE
	var scale_factor = min(
		available_size.x / texture_size.x, 
		available_size.y / texture_size.y
	)
	var size = texture_size * scale_factor
	var gap: = logo_rect.size.y * ENERGY_ICON_LOGO_GAP
	var energy_centre: = Vector2(
		logo_rect.get_center().x, 
		logo_rect.position.y - gap - size.y * 0.5
	)
	return Rect2(energy_centre - size * 0.5, size)


func _draw_energy_recharge_timer(energy_rect: Rect2, visible_size: Vector2) -> void :
	var remaining: = _get_energy_recharge_seconds_remaining()
	var minutes: = remaining / 60
	var seconds: = remaining % 60
	var timer_text: = "%02d:%02d" % [minutes, seconds]
	var font: = _get_content_font(selected_game_mode)
	var logo_height: = _get_logo_rect(
		to_local(camera_2d.get_screen_center_position()), visible_size
	).size.y
	var font_size: = maxi(9, int(min(
		min(visible_size.x, visible_size.y) * 0.036, 
		logo_height * 0.16
	)))
	var text_size: = font.get_string_size(
		timer_text, 
		HORIZONTAL_ALIGNMENT_LEFT, 
		-1, 
		font_size
	)
	var baseline: = Vector2(
		energy_rect.get_center().x - text_size.x * 0.5, 
		energy_rect.end.y + font_size * 1.05
	)
	draw_string(
		font, 
		baseline + Vector2(2.0, 2.0), 
		timer_text, 
		HORIZONTAL_ALIGNMENT_LEFT, 
		-1, 
		font_size, 
		Color(0.0, 0.0, 0.0, 0.8)
	)
	draw_string(
		font, 
		baseline, 
		timer_text, 
		HORIZONTAL_ALIGNMENT_LEFT, 
		-1, 
		font_size, 
		Color.WHITE
	)


func _get_add_energy_rect(centre: Vector2, visible_size: Vector2) -> Rect2:
	var logo_rect: = _get_logo_rect(centre, visible_size)
	var energy_rect: = _get_energy_rect(centre, visible_size)
	var texture_size: = _1_GAME.get_size()
	var available_size: = logo_rect.size * ADD_ENERGY_BUTTON_LOGO_SIZE
	var scale_factor = min(
		available_size.x / texture_size.x, 
		available_size.y / texture_size.y
	)
	var size = texture_size * scale_factor
	var gap: = logo_rect.size.y * ADD_ENERGY_BUTTON_LOGO_GAP
	var horizontal_gap = size.x * 0.18
	var button_centre: = Vector2(
		logo_rect.get_center().x - (size.x + horizontal_gap) * 0.5, 
		energy_rect.position.y - gap - size.y * 0.5
	)
	return Rect2(button_centre - size * 0.5, size)


func _get_indicator_toggle_rect(centre: Vector2, visible_size: Vector2) -> Rect2:
	var add_energy_rect: = _get_add_energy_rect(centre, visible_size)
	var logo_centre_x: = _get_logo_rect(centre, visible_size).get_center().x
	var size: = add_energy_rect.size
	var horizontal_gap: = size.x * 0.18
	var button_centre: = Vector2(
		logo_centre_x if energy_points >= MAX_ENERGY else logo_centre_x + (size.x + horizontal_gap) * 0.5, 
		add_energy_rect.get_center().y
	)
	return Rect2(button_centre - size * 0.5, size)


func _get_music_toggle_rect(centre: Vector2, visible_size: Vector2) -> Rect2:
	var indicator_rect: = _get_indicator_toggle_rect(centre, visible_size)
	var texture_size: = MUSIC_ON.get_size()
	var target_height: = indicator_rect.size.y * 1.18
	var scale_factor: = target_height / maxf(texture_size.y, 1.0)
	var size: = texture_size * scale_factor
	var gap: = indicator_rect.size.y * 0.2
	var button_centre: = Vector2(
		_get_logo_rect(centre, visible_size).get_center().x, 
		indicator_rect.position.y - gap - size.y * 0.5
	)
	return Rect2(button_centre - size * 0.5, size)


func _toggle_music() -> void :
	music_enabled = not music_enabled
	click.play()
	var tween: = create_tween()
	tween.tween_method(
		_set_music_button_scale, music_button_scale, 1.2, 0.08
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_method(
		_set_music_button_scale, 1.2, 1.0, 0.12
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if music_enabled:
		if game_over:
			_play_music(WINNER_WINNER, 0.35)
		elif not game_has_started:
			_play_music(ITTY_BITTY_8_BIT, 0.35)
		elif final_two_music_faded:
			_stop_music_immediately()
		elif call_to_adventure_started:
			_play_music(CALL_TO_ADVENTURE, 0.35)
		elif gameplay_music_started:
			_play_music(SHINY_TECH, 0.35)
	else:
		_fade_music_to_silence(0.35)
	queue_redraw()


func _set_music_button_scale(value: float) -> void :
	music_button_scale = value
	queue_redraw()


func _play_music(stream: AudioStream, _fade_in_duration: float = 0.45) -> void :
	if not music_enabled or stream == null:
		return
	if music_fade_tween != null and music_fade_tween.is_valid():
		music_fade_tween.kill()
	if music_standby_player != null:
		music_standby_player.stop()
	music_player.stream = stream
	music_player.stream_paused = false


	music_player.volume_db = MUSIC_VOLUME_DB
	music_player.play()


func _fade_music_to_silence(duration: float = 1.2) -> void :
	if (music_player == null
		or ( not music_player.playing and not music_standby_player.playing)):
		return
	if music_fade_tween != null and music_fade_tween.is_valid():
		music_fade_tween.kill()
	music_fade_tween = create_tween()
	music_fade_tween.set_parallel(true)
	if music_player.playing:
		music_fade_tween.tween_property(
			music_player, "volume_db", -40.0, duration
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if music_standby_player.playing:
		music_fade_tween.tween_property(
			music_standby_player, "volume_db", -40.0, duration
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	music_fade_tween.chain().tween_callback(_stop_both_music_players)


func _crossfade_to_music(stream: AudioStream, fade_out_duration: float = 0.8) -> void :
	if not music_enabled:
		return
	if music_player.playing:
		if music_fade_tween != null and music_fade_tween.is_valid():
			music_fade_tween.kill()
		music_standby_player.stop()
		music_standby_player.stream = stream


		music_standby_player.volume_db = -22.0
		music_standby_player.play()
		music_fade_tween = create_tween()
		music_fade_tween.set_parallel(true)
		music_fade_tween.tween_property(
			music_player, "volume_db", -40.0, fade_out_duration
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		music_fade_tween.tween_property(
			music_standby_player, "volume_db", MUSIC_VOLUME_DB, fade_out_duration
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		music_fade_tween.chain().tween_callback(
			_finish_music_crossfade.bind(music_player, music_standby_player)
		)
	else:
		_play_music(stream, 0.55)


func _finish_music_crossfade(
	old_player: AudioStreamPlayer, 
	new_player: AudioStreamPlayer
) -> void :
	old_player.stop()
	old_player.volume_db = MUSIC_VOLUME_DB
	music_player = new_player
	music_standby_player = old_player
	music_fade_tween = null


func _stop_music_immediately() -> void :
	if music_fade_tween != null and music_fade_tween.is_valid():
		music_fade_tween.kill()
	_stop_both_music_players()


func _stop_both_music_players() -> void :
	music_player.stream_paused = false
	music_player.stop()
	music_player.volume_db = MUSIC_VOLUME_DB
	music_standby_player.stream_paused = false
	music_standby_player.stop()
	music_standby_player.volume_db = MUSIC_VOLUME_DB


func _restart_music_player(player: AudioStreamPlayer) -> void :
	if (music_enabled
		and player.stream != null
		and (player == music_player
			or (player == music_standby_player
				and music_fade_tween != null
				and music_fade_tween.is_valid()))):
		player.play()


func _draw_lobby_attribution(
	swipe_centre: Vector2, 
	swipe_size: Vector2, 
	visible_size: Vector2
) -> void :
	var lines: Array[String] = [
		"\"Call to Adventure\" \"Itty Bitty 8 Bit\", \"Shiny Tech\", \"Winner Winner!\"", 
		"Kevin MacLeod (incompetech.com)", 
		"Licensed under Creative Commons: By Attribution 4.0", 
		"http://creativecommons.org/licenses/by/4.0/", 
		"BFDI Parallels by Beefydle", 
		"BFDI by Jacknjellify", 
	]
	var attribution_font: = _get_content_font(selected_game_mode)
	var logo_height: = _get_logo_rect(
		to_local(camera_2d.get_screen_center_position()), visible_size
	).size.y
	var font_size: = maxi(9, int(min(
		min(visible_size.x, visible_size.y) * 0.018, 
		logo_height * 0.085
	)))
	var line_height: = attribution_font.get_height(font_size) * 1.08
	var y: = swipe_centre.y + swipe_size.y * 0.72 + line_height
	for line in lines:
		var line_font_size: = font_size
		var text_size: = attribution_font.get_string_size(
			line, HORIZONTAL_ALIGNMENT_LEFT, -1, line_font_size
		)
		var maximum_width: = visible_size.x * 0.88
		if text_size.x > maximum_width:
			line_font_size = maxi(9, int(line_font_size * maximum_width / text_size.x))
			text_size = attribution_font.get_string_size(
				line, HORIZONTAL_ALIGNMENT_LEFT, -1, line_font_size
			)
		draw_string(
			attribution_font, 
			Vector2(swipe_centre.x - text_size.x * 0.5, y), 
			line, 
			HORIZONTAL_ALIGNMENT_LEFT, 
			-1, 
			line_font_size, 
			Color.WHITE
		)
		y += line_height


func _toggle_indicators() -> void :
	indicators_enabled = not indicators_enabled
	click.play()
	var tween: = create_tween()
	tween.tween_method(
		_set_indicator_button_scale, 
		indicator_button_scale, 
		1.18, 
		0.08
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_method(
		_set_indicator_button_scale, 
		1.18, 
		1.0, 
		0.12
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_refresh_board_indicators()
	queue_redraw()


func _set_indicator_button_scale(value: float) -> void :
	indicator_button_scale = value
	queue_redraw()


func _can_start_game() -> bool:
	return _selected_player_count() >= 2 and energy_points > 0


func _setup_ads() -> void :
	if not ads_removed: ads = get_node_or_null("/root/Ads")
	if ads == null:
		push_warning("Global Ads scene was not found at /root/Ads.")
		return
	_connect_ad_signal(
		"rewarded_keep_score_granted", 
		_on_rewarded_energy_granted
	)
	_connect_ad_signal(
		"rewarded_closed_without_reward", 
		_on_rewarded_closed_without_reward
	)
	_connect_ad_signal("rewarded_failed", _on_rewarded_closed_without_reward)
	_connect_ad_signal("fullscreen_ad_started", _on_fullscreen_ad_started)
	_connect_ad_signal("fullscreen_ad_closed", _on_fullscreen_ad_closed)
	_connect_ad_signal("consent_status_known", _on_consent_status_known)
	_on_consent_status_known(bool(ads.is_privacy_options_available()))
	_preload_fullscreen_ads()


func _create_privacy_button() -> void :
	privacy_canvas_layer = CanvasLayer.new()
	privacy_canvas_layer.name = "PrivacyCanvasLayer"
	privacy_canvas_layer.layer = 100
	add_child(privacy_canvas_layer)

	privacy_button = LobbyPrivacyButton.new()
	privacy_button.name = "PrivacyButton"
	privacy_button.visible = false
	privacy_canvas_layer.add_child(privacy_button)
	privacy_button.pressed.connect(_on_privacy_button_pressed)
	get_viewport().size_changed.connect(_layout_privacy_button)
	_layout_privacy_button()


func _layout_privacy_button() -> void :
	if privacy_button == null:
		return
	var viewport_size: = get_viewport_rect().size
	var safe_rect: = _get_safe_viewport_rect()
	var short_side = min(viewport_size.x, viewport_size.y)
	var button_side = clamp(short_side * 0.075, 72.0, 112.0)
	var margin = clamp(short_side * 0.025, 16.0, 32.0)
	privacy_button.size = Vector2.ONE * button_side
	privacy_button.position = Vector2(
		safe_rect.end.x - button_side - margin, 
		safe_rect.position.y + margin
	)


func _on_consent_status_known(is_applicable: bool) -> void :
	privacy_options_applicable = is_applicable
	_refresh_privacy_button_visibility()


func _refresh_privacy_button_visibility() -> void :
	if privacy_button != null:
		privacy_button.visible = (
			privacy_options_applicable
			and not game_has_started
			and not _start_animation_running
		)


func _on_privacy_button_pressed() -> void :
	if ads == null or not privacy_options_applicable:
		return
	click.play()
	ads.show_privacy_options()


func _connect_ad_signal(signal_name: StringName, callback: Callable) -> void :
	if not ads.has_signal(signal_name):
		push_warning("Ads is missing signal: %s" % signal_name)
		return
	if not ads.is_connected(signal_name, callback):
		ads.connect(signal_name, callback)


func _preload_fullscreen_ads() -> void :
	if ads == null:
		return
	ads.load_rewarded()
	ads.load_interstitial()


func _request_rewarded_energy() -> void :
	if energy_points >= MAX_ENERGY or rewarded_energy_request_pending:
		return
	click.play()
	_pulse_add_energy_button()
	if ads == null:
		_add_energy_point()
		return
	var ad_was_shown: = bool(ads.show_rewarded_if_ready())
	rewarded_energy_request_pending = ad_was_shown
	if ad_was_shown:
		return


	ads.load_rewarded()
	ads.load_interstitial()


func _on_rewarded_energy_granted() -> void :
	if not rewarded_energy_request_pending:
		return
	rewarded_energy_request_pending = false
	_add_energy_point()


func _on_rewarded_closed_without_reward() -> void :
	rewarded_energy_request_pending = false


func _show_or_load_end_interstitial() -> void :
	if ads == null:
		return
	if not bool(ads.show_interstitial_if_ready()):


		ads.load_interstitial()


func _load_end_interstitial_if_needed() -> void :
	if ads != null:
		ads.load_interstitial()


func _on_fullscreen_ad_started() -> void :
	if not music_enabled:
		return
	ad_paused_music_players.clear()
	if music_player.playing:
		ad_paused_music_players.append(music_player)
	if music_standby_player.playing:
		ad_paused_music_players.append(music_standby_player)
	if ad_paused_music_players.is_empty():
		return
	if music_fade_tween != null and music_fade_tween.is_valid():
		music_fade_tween.kill()
	music_fade_tween = create_tween()
	music_fade_tween.set_parallel(true)
	for player in ad_paused_music_players:
		music_fade_tween.tween_property(
			player, "volume_db", -40.0, 0.35
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	music_fade_tween.chain().tween_callback(_pause_music_after_ad_fade)


func _pause_music_after_ad_fade() -> void :
	for player in ad_paused_music_players:
		if is_instance_valid(player) and player.playing:
			player.stream_paused = true
	music_fade_tween = null


func _on_fullscreen_ad_closed() -> void :
	if not ad_paused_music_players.is_empty():
		_resume_music_after_ad()
	elif not game_has_started:
		_fade_in_lobby_music()


func _resume_music_after_ad(duration: float = 0.75) -> void :
	if not music_enabled:
		ad_paused_music_players.clear()
		return
	if music_fade_tween != null and music_fade_tween.is_valid():
		music_fade_tween.kill()
	music_fade_tween = create_tween()
	music_fade_tween.set_parallel(true)
	for player in ad_paused_music_players:
		if not is_instance_valid(player):
			continue
		player.stream_paused = false
		music_fade_tween.tween_property(
			player, "volume_db", MUSIC_VOLUME_DB, duration
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	music_fade_tween.chain().tween_callback(_finish_ad_music_resume)


func _finish_ad_music_resume() -> void :
	ad_paused_music_players.clear()
	music_fade_tween = null


func _fade_in_lobby_music(duration: float = 0.75) -> void :
	if not music_enabled:
		return
	if music_fade_tween != null and music_fade_tween.is_valid():
		music_fade_tween.kill()
	music_standby_player.stop()
	if music_player.stream != ITTY_BITTY_8_BIT or not music_player.playing:
		music_player.stream = ITTY_BITTY_8_BIT
		music_player.play()
	music_player.volume_db = -40.0
	music_fade_tween = create_tween()
	music_fade_tween.tween_property(
		music_player, 
		"volume_db", 
		MUSIC_VOLUME_DB, 
		duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _add_energy_point() -> void :
	if energy_points >= MAX_ENERGY:
		return
	energy_points += 1
	_update_energy_recharge_schedule()
	_save_energy_points()
	queue_redraw()


func _pulse_add_energy_button() -> void :
	if add_energy_button_pulse_tween != null and add_energy_button_pulse_tween.is_valid():
		add_energy_button_pulse_tween.kill()
	add_energy_button_pulse_tween = create_tween()
	add_energy_button_pulse_tween.tween_method(
		_set_add_energy_button_scale, 
		add_energy_button_scale, 
		1.18, 
		0.08
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	add_energy_button_pulse_tween.tween_method(
		_set_add_energy_button_scale, 
		1.18, 
		1.0, 
		0.12
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _set_add_energy_button_scale(value: float) -> void :
	add_energy_button_scale = value
	queue_redraw()


func _load_energy_points() -> void :
	var config: = ConfigFile.new()
	var load_error: = config.load(ENERGY_SAVE_PATH)
	if load_error == OK:
		energy_points = clampi(
			int(config.get_value(
				ENERGY_SAVE_SECTION, 
				ENERGY_SAVE_KEY, 
				INITIAL_ENERGY
			)), 
			0, 
			MAX_ENERGY
		)
		next_energy_recharge_unix = int(config.get_value(
			ENERGY_SAVE_SECTION, 
			ENERGY_RECHARGE_TIME_KEY, 
			0
		))
		last_energy_clock_unix = int(config.get_value(
			ENERGY_SAVE_SECTION, 
			ENERGY_LAST_CLOCK_KEY, 
			0
		))
	else:
		energy_points = INITIAL_ENERGY
		next_energy_recharge_unix = 0
		last_energy_clock_unix = 0
	_reconcile_energy_recharge_on_load()
	_save_energy_points()


func _save_energy_points() -> void :
	var config: = ConfigFile.new()
	config.set_value(
		ENERGY_SAVE_SECTION, 
		ENERGY_SAVE_KEY, 
		clampi(energy_points, 0, MAX_ENERGY)
	)
	config.set_value(
		ENERGY_SAVE_SECTION, 
		ENERGY_RECHARGE_TIME_KEY, 
		next_energy_recharge_unix
	)
	config.set_value(
		ENERGY_SAVE_SECTION, 
		ENERGY_LAST_CLOCK_KEY, 
		last_energy_clock_unix
	)
	var save_error: = config.save(ENERGY_SAVE_PATH)
	if save_error != OK:
		push_warning("Could not save energy points: error %s" % save_error)


func _reconcile_energy_recharge_on_load() -> void :
	var now: = int(Time.get_unix_time_from_system())
	if last_energy_clock_unix > 0 and now < last_energy_clock_unix:

		if energy_points < FREE_ENERGY_CAP:
			next_energy_recharge_unix = now + ENERGY_RECHARGE_SECONDS
		else:
			next_energy_recharge_unix = 0
		last_energy_clock_unix = now
		return

	if energy_points >= FREE_ENERGY_CAP:
		next_energy_recharge_unix = 0
	elif next_energy_recharge_unix <= 0:
		next_energy_recharge_unix = now + ENERGY_RECHARGE_SECONDS
	else:
		while (energy_points < FREE_ENERGY_CAP
			and now >= next_energy_recharge_unix):
			energy_points += 1
			next_energy_recharge_unix += ENERGY_RECHARGE_SECONDS
		if energy_points >= FREE_ENERGY_CAP:
			next_energy_recharge_unix = 0
	last_energy_clock_unix = now


func _update_energy_recharge_schedule() -> void :
	var now: = int(Time.get_unix_time_from_system())
	if energy_points >= FREE_ENERGY_CAP:
		next_energy_recharge_unix = 0
	elif next_energy_recharge_unix <= 0:
		next_energy_recharge_unix = now + ENERGY_RECHARGE_SECONDS
	last_energy_clock_unix = maxi(last_energy_clock_unix, now)
	last_energy_timer_second = -1


func _update_energy_recharge_timer() -> void :
	if energy_points >= FREE_ENERGY_CAP:
		if next_energy_recharge_unix != 0:
			next_energy_recharge_unix = 0
			_save_energy_points()
			queue_redraw()
		return

	var now: = int(Time.get_unix_time_from_system())
	if last_energy_clock_unix > 0 and now < last_energy_clock_unix:
		return
	last_energy_clock_unix = now

	if next_energy_recharge_unix <= 0:
		next_energy_recharge_unix = now + ENERGY_RECHARGE_SECONDS
		_save_energy_points()

	if now >= next_energy_recharge_unix:
		while (energy_points < FREE_ENERGY_CAP
			and now >= next_energy_recharge_unix):
			energy_points += 1
			next_energy_recharge_unix += ENERGY_RECHARGE_SECONDS
		if energy_points >= FREE_ENERGY_CAP:
			next_energy_recharge_unix = 0
		_save_energy_points()
		last_energy_timer_second = -1
		queue_redraw()
		return

	var remaining: = _get_energy_recharge_seconds_remaining()
	if remaining != last_energy_timer_second:
		last_energy_timer_second = remaining
		queue_redraw()


func _get_energy_recharge_seconds_remaining() -> int:
	if energy_points >= FREE_ENERGY_CAP or next_energy_recharge_unix <= 0:
		return 0
	var now: = int(Time.get_unix_time_from_system())
	return maxi(0, next_energy_recharge_unix - now)


func _change_game_mode(direction: int) -> void :
	if mode_swipe_animation_running:
		return
	mode_swipe_animation_running = true
	var travel_direction: = -1.0 if direction > 0 else 1.0
	var distance: = _get_visible_world_size().x * 0.34
	var tween: = create_tween()
	tween.tween_method(
		_set_logo_swipe_out.bind(travel_direction, distance), 
		0.0, 
		1.0, 
		0.18
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(
		_swap_game_mode_mid_animation.bind(direction, travel_direction, distance)
	)
	tween.tween_method(
		_set_logo_swipe_in.bind(travel_direction, distance), 
		0.0, 
		1.0, 
		0.24
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.finished.connect(_finish_game_mode_swipe)


func _set_logo_swipe_out(progress: float, travel_direction: float, distance: float) -> void :
	lobby_logo_offset = Vector2.RIGHT * travel_direction * distance * progress
	lobby_logo_alpha = 1.0 - progress
	queue_redraw()


func _swap_game_mode_mid_animation(
	direction: int, 
	travel_direction: float, 
	distance: float
) -> void :
	selected_game_mode = posmod(selected_game_mode + direction, GAME_MODE_NAMES.size())
	for side in player_content_modes.size():
		player_content_modes[side] = (
			-1 if selected_game_mode == GameContentMode.HYBRID else int(selected_game_mode)
		)
	_apply_selected_game_mode()
	lobby_logo_offset = Vector2.RIGHT * - travel_direction * distance
	lobby_logo_alpha = 0.0
	click.play()
	queue_redraw()


func _set_logo_swipe_in(progress: float, travel_direction: float, distance: float) -> void :
	lobby_logo_offset = Vector2.RIGHT * - travel_direction * distance * (1.0 - progress)
	lobby_logo_alpha = progress
	queue_redraw()


func _finish_game_mode_swipe() -> void :
	lobby_logo_offset = Vector2.ZERO
	lobby_logo_alpha = 1.0
	mode_swipe_animation_running = false
	queue_redraw()


func _apply_selected_game_mode() -> void :
	sky.visible = selected_game_mode != GameContentMode.HYBRID || selected_game_mode != GameContentMode.BALDI
	background.visible = selected_game_mode != GameContentMode.HYBRID || selected_game_mode != GameContentMode.BALDI
	grass.visible = selected_game_mode != GameContentMode.HYBRID
	hybrid_background.visible = selected_game_mode == GameContentMode.HYBRID
	if selected_game_mode == GameContentMode.BFDI:
		sky.texture = BFDI_SKY
		background.texture = BFDI_BACKGROUND
		grass.texture = BFDI_GRASS
	if selected_game_mode == GameContentMode.BALDI:
		grass.texture = BALDI_BG
	else:
		sky.texture = BFDI_SKY
		background.texture = BFDI_BACKGROUND
		grass.texture = BFDI_GRASS


func _get_game_logo_texture() -> Texture2D:
	match selected_game_mode:
		GameContentMode.BFDI:
			return GAME_LOGO_BFDI
		GameContentMode.HYBRID:
			return HYBRID_LOGO
		GameContentMode.BALDI:
			return BALDI_LOGO
		_:
			return GAME_LOGO


func _get_content_font(content_mode: int) -> Font:
	if content_mode == GameContentMode.BFDI:
		return SHAG_LOUNGE
	if content_mode == GameContentMode.CFDI || content_mode == GameContentMode.BALDI:
		return COMIC_SANS
	return HELVETICA_BOLD


func _get_player_content_mode(side: int) -> int:
	if selected_game_mode != GameContentMode.HYBRID:
		return selected_game_mode
	if side >= 0 and side < player_content_modes.size() and player_content_modes[side] >= 0:
		return player_content_modes[side]
	return GameContentMode.CFDI


func _get_player_font(side: int) -> Font:
	if (selected_game_mode == GameContentMode.HYBRID
		and (side < 0
			or side >= player_content_modes.size()
			or player_content_modes[side] < 0)):
		return HELVETICA_BOLD
	return _get_content_font(_get_player_content_mode(side))


func _get_character_card_types_for_mode(content_mode: int) -> Array[Texture2D]:
	if content_mode == GameContentMode.BFDI:
		return BFDI_CHARACTER_CARD_TYPES
	elif content_mode == GameContentMode.BALDI:
		return BALDI_CHARACTER_CARD_TYPES
	else:
		return CHARACTER_CARD_TYPES


func _get_character_mini_types_for_mode(content_mode: int) -> Array[Texture2D]:
	if content_mode == GameContentMode.BFDI:
		return BFDI_CHARACTER_MINI_TYPES
	elif content_mode == GameContentMode.BALDI:
		return BALDI_CHARACTER_MINI_TYPES
	else:
		return CHARACTER_MINI_TYPES


func _get_character_names_for_mode(content_mode: int) -> Array[String]:
	if content_mode == GameContentMode.BFDI:
		return BFDI_CHARACTER_NAMES
	elif content_mode == GameContentMode.BALDI:
		return BALDI_CHARACTER_NAMES
	else:
		return CHARACTER_NAMES


func _get_character_attributes(character_name: String) -> Array:
	if BFDI_CHARACTER_ATTRIBUTES.has(character_name):
		return BFDI_CHARACTER_ATTRIBUTES[character_name].duplicate()
	if BALDI_CHARACTER_ATTRIBUTES.has(character_name):
		return BALDI_CHARACTER_ATTRIBUTES[character_name].duplicate()
	return CHARACTER_ATTRIBUTES.get(character_name, []).duplicate()


func _get_character_content_mode(texture: Texture2D) -> int:
	if texture in BFDI_CHARACTER_CARD_TYPES: return GameContentMode.BFDI
	if texture in BALDI_CHARACTER_CARD_TYPES: return GameContentMode.BALDI
	return GameContentMode.CFDI


func _get_scene_card_types_for_side(side: int) -> Array[Texture2D]:
	var canonical_cards: = scene_card_draw_pile.duplicate()
	if canonical_cards.is_empty():
		canonical_cards = _build_scene_card_deck()
	var visible_cards: Array[Texture2D] = []
	var target_mode: = _get_player_content_mode(side)
	for texture in canonical_cards:
		visible_cards.append(_get_scene_card_counterpart(texture, target_mode))
	return visible_cards


func _build_scene_card_deck() -> Array[Texture2D]:
	var deck: Array[Texture2D] = []
	for _copy in 8:
		deck.append(SWAP_CARD)
	for _copy in 12:
		deck.append(BOOST_CARD)
	for development_card in [
		ACTIVE_DEVELOPMENT_CARD, 
		ANGER_DEVELOPMENT_CARD, 
		NICE_DEVELOPMENT_CARD, 
		SELFISH_DEVELOPMENT_CARD, 
		SMART_DEVELOPMENT_CARD, 
	]:
		for _copy in 3:
			deck.append(development_card)
	for _copy in 5:
		deck.append(WIN_TOKEN_CARD)
	deck.append_array([
		ACTIVE_SPECIAL_BOOST_CARD, 
		ANGER_SPECIAL_BOOST_CARD, 
		NICE_SPECIAL_BOOST_CARD, 
		SELFISH_SPECIAL_BOOST_CARD, 
		SMART_SPECIAL_BOOST_CARD, 
	])
	return deck


func _refill_scene_card_draw_pile() -> void :
	scene_card_draw_pile = _build_scene_card_deck()
	scene_card_draw_pile.shuffle()


func _draw_scene_card_for_side(side: int) -> Texture2D:
	if scene_card_draw_pile.is_empty():
		_refill_scene_card_draw_pile()
	var canonical_texture: Texture2D = scene_card_draw_pile.pop_back()
	return _get_scene_card_counterpart(canonical_texture, _get_player_content_mode(side))


func _get_active_challenge_pool() -> Array[Dictionary]:
	if selected_game_mode == GameContentMode.BFDI:
		return BFDI_CHALLENGES
	if selected_game_mode == GameContentMode.HYBRID:
		var combined: = CHALLENGES.duplicate(true)
		combined.append_array(BFDI_CHALLENGES.duplicate(true))
		return combined
	return CHALLENGES


func _get_scene_card_counterpart(texture: Texture2D, target_mode: int) -> Texture2D:
	if target_mode == GameContentMode.BFDI:
		if texture == ACTIVE_DEVELOPMENT_CARD:
			return BFDI_ACTIVE_DEVELOPMENT_CARD
		if texture == ANGER_DEVELOPMENT_CARD:
			return BFDI_ANGER_DEVELOPMENT_CARD
		if texture == BOOST_CARD:
			return BFDI_BOOST_CARD
		if texture == NICE_DEVELOPMENT_CARD:
			return BFDI_NICE_DEVELOPMENT_CARD
		if texture == SELFISH_DEVELOPMENT_CARD:
			return BFDI_SELFISH_DEVELOPMENT_CARD
		if texture == SMART_DEVELOPMENT_CARD:
			return BFDI_SMART_DEVELOPMENT_CARD
		if texture == WIN_TOKEN_CARD:
			return BFDI_WIN_TOKEN_CARD
	else:
		if texture == BFDI_ACTIVE_DEVELOPMENT_CARD:
			return ACTIVE_DEVELOPMENT_CARD
		if texture == BFDI_ANGER_DEVELOPMENT_CARD:
			return ANGER_DEVELOPMENT_CARD
		if texture == BFDI_BOOST_CARD:
			return BOOST_CARD
		if texture == BFDI_NICE_DEVELOPMENT_CARD:
			return NICE_DEVELOPMENT_CARD
		if texture == BFDI_SELFISH_DEVELOPMENT_CARD:
			return SELFISH_DEVELOPMENT_CARD
		if texture == BFDI_SMART_DEVELOPMENT_CARD:
			return SMART_DEVELOPMENT_CARD
		if texture == BFDI_WIN_TOKEN_CARD:
			return WIN_TOKEN_CARD
	return texture


func _convert_player_scene_cards_to_mode(side: int) -> void :
	var target_mode: = _get_player_content_mode(side)
	for card_index in _get_owner_scene_card_indices(side):
		if card_index >= dealt_scene_cards.size():
			continue
		var card: = dealt_scene_cards[card_index]
		var counterpart: = _get_scene_card_counterpart(card.texture, target_mode)
		if counterpart == card.texture:
			continue
		card.texture = counterpart
		dealt_scene_cards[card_index] = card
	queue_redraw()


func _get_character_name_for_texture(texture: Texture2D) -> String:
	var content_mode: = _get_character_content_mode(texture)
	var types: = _get_character_card_types_for_mode(content_mode)
	var names: = _get_character_names_for_mode(content_mode)
	var type_index: = types.find(texture)
	return names[type_index] if type_index >= 0 else ""


func _get_character_mini_for_texture(texture: Texture2D) -> Texture2D:
	var content_mode: = _get_character_content_mode(texture)
	var types: = _get_character_card_types_for_mode(content_mode)
	var minis: = _get_character_mini_types_for_mode(content_mode)
	var type_index: = types.find(texture)
	return minis[type_index] if type_index >= 0 else null


func _is_draft_character_allowed_for_side(card_index: int, side: int) -> bool:
	if card_index < 0 or card_index >= draft_character_cards.size():
		return false
	if selected_game_mode != GameContentMode.HYBRID:
		return true
	var locked_mode: = player_content_modes[side]
	var candidate_mode: = _get_character_content_mode(
		draft_character_cards[card_index].texture
	)
	if locked_mode >= 0:
		return candidate_mode == locked_mode




	var locked_player_count: = 0
	for player_side in player_order:
		if player_content_modes[player_side] == candidate_mode:
			locked_player_count += 1
	return locked_player_count < hybrid_player_limits[candidate_mode]


func _selected_player_count() -> int:
	return player_order.size()


func is_player_bot(player_index: int) -> bool:
	return (player_index >= 0
		and player_index < player_is_bot.size()
		and selected_players[player_index]
		and player_is_bot[player_index])


func bot_animate_scene_card_play(card_index: int, character_index: int) -> void :
	if (card_index < 0 or card_index >= dealt_scene_cards.size()
		or character_index < 0 or character_index >= player_character_cards.size()
		or not _is_scene_card_legal_for_character(card_index, character_index)):
		return
	bot_action_input_locked = true
	var card: = dealt_scene_cards[card_index]
	var start: Vector2 = card.position
	var target: Vector2 = player_character_cards[character_index].position
	dragged_scene_play_index = card_index
	highlighted_character_card_index = character_index
	var tween: = create_tween()
	tween.tween_method(
		_set_dealt_card_position_direct.bind(card_index, start, target), 0.0, 1.0, 0.32
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	dragged_scene_play_index = -1
	highlighted_character_card_index = -1
	await _play_scene_card(card_index, character_index)
	bot_action_input_locked = false


func bot_animate_challenge_move(mini_index: int) -> void :
	if mini_index < 0 or mini_index >= character_minis_on_board.size():
		return
	bot_action_input_locked = true
	var visible_size: = _get_visible_world_size()
	var mini: = character_minis_on_board[mini_index]
	_handle_character_movement_pointer(mini.position, true, false, visible_size, true)
	if dragged_mini_index != mini_index:
		bot_action_input_locked = false
		return
	var target: = _get_board_cell_centre(mini.target_column, mini.row, visible_size)
	var tween: = create_tween()
	tween.tween_method(
		_set_character_mini_position.bind(mini_index, mini.position, target), 0.0, 1.0, 0.34
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	_finish_character_mini_drag(target, visible_size)
	await _wait_for_bot_mini_landing(mini_index)
	bot_action_input_locked = false


func bot_animate_effect_move(mini_index: int) -> void :
	if mini_index < 0 or mini_index >= character_minis_on_board.size():
		return


	if alliance_target_character_index >= 0 and _alliance_movement_is_locked():
		return
	bot_action_input_locked = true
	var visible_size: = _get_visible_world_size()
	var mini: = character_minis_on_board[mini_index]
	if alliance_target_character_index >= 0:
		if pending_effect_mini_index < 0:
			_start_alliance_move(mini_index, mini.position, visible_size, true)
		elif pending_effect_mini_index != mini_index:

			bot_action_input_locked = false
			return
		else:
			_handle_card_effect_mini_press(mini.position, visible_size, true)
	else:
		if pending_effect_mini_index != mini_index:
			bot_action_input_locked = false
			return
		_handle_card_effect_mini_press(mini.position, visible_size, true)
	if dragged_mini_index != mini_index:
		bot_action_input_locked = false
		return
	var target_row: int = pending_effect_target_row if pending_effect_target_row >= 0 else mini.row
	var target: = _get_board_cell_centre(pending_effect_target_column, target_row, visible_size)
	var tween: = create_tween()
	tween.tween_method(
		_set_character_mini_position.bind(mini_index, mini.position, target), 0.0, 1.0, 0.34
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	await _finish_card_effect_mini_drag(target, visible_size)
	bot_action_input_locked = false


func bot_animate_swap(source_index: int, target_index: int) -> void :
	if (source_index < 0 or source_index >= character_minis_on_board.size()
		or target_index < 0 or target_index >= character_minis_on_board.size()):
		return
	bot_action_input_locked = true
	var visible_size: = _get_visible_world_size()
	var source: = character_minis_on_board[source_index]
	var target: Vector2 = character_minis_on_board[target_index].position
	pending_effect_mini_index = source_index
	_handle_card_effect_mini_press(source.position, visible_size, true)
	if dragged_mini_index != source_index:
		bot_action_input_locked = false
		return
	var tween: = create_tween()
	tween.tween_method(
		_set_character_mini_position.bind(source_index, source.position, target), 0.0, 1.0, 0.34
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	await _finish_card_effect_mini_drag(target, visible_size)
	bot_action_input_locked = false


func _wait_for_bot_mini_landing(mini_index: int) -> void :


	for _frame in 120:
		if (mini_index < 0
			or mini_index >= character_minis_on_board.size()
			or not character_minis_on_board[mini_index].get("moving", false)):
			return
		await get_tree().process_frame


func _toggle_player(player_index: int) -> void :
	click.play()


	if selected_players[player_index] and not player_is_bot[player_index]:
		player_is_bot[player_index] = true
	elif selected_players[player_index]:
		selected_players[player_index] = false
		player_is_bot[player_index] = false
		player_order.erase(player_index)
	else:
		selected_players[player_index] = true
		player_is_bot[player_index] = false
		player_order.append(player_index)

	_animate_player_button(player_index)
	queue_redraw()


func _animate_player_button(player_index: int) -> void :
	var tween: = create_tween()
	tween.tween_method(
		_set_player_button_scale.bind(player_index), 
		player_button_scales[player_index], 
		1.22, 
		0.1
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_method(
		_set_player_button_scale.bind(player_index), 
		1.22, 
		1.0, 
		0.14
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _set_player_button_scale(value: float, player_index: int) -> void :
	player_button_scales[player_index] = value
	_refresh_player_button_visuals()


func _start_game() -> void :
	if not _can_start_game() or _start_animation_running:
		return
	discarded_challenge_keys.clear()
	_refill_scene_card_draw_pile()
	challenge_opener_side = player_order[0] if not player_order.is_empty() else -1
	energy_points -= 1
	_update_energy_recharge_schedule()
	_save_energy_points()
	_start_animation_running = true
	_refresh_privacy_button_visibility()
	match selected_game_mode:
		GameContentMode.BFDI:
			start_bfdi.play()
		GameContentMode.HYBRID:
			start_hybrid.play()
		_:
			start.play()
	var tween: = create_tween()
	tween.tween_method(_set_logo_animation_progress, 0.0, 1.0, 0.36)
	tween.finished.connect(_finish_starting_game)


func _set_logo_animation_progress(progress: float) -> void :

	var peak_progress: = 0.42
	var peak_scale: = 1.35
	var scale_value: = 1.0
	if progress < peak_progress:
		var grow_progress: = progress / peak_progress
		var eased_out_grow: = 1.0 - pow(1.0 - grow_progress, 3.0)
		scale_value = lerp(1.0, peak_scale, eased_out_grow)
	else:
		var shrink_progress: = (progress - peak_progress) / (1.0 - peak_progress)
		var eased_in_shrink: = pow(shrink_progress, 3.0)
		scale_value = lerp(peak_scale, 0.0, eased_in_shrink)

	logo_scale = Vector2.ONE * scale_value
	queue_redraw()


func _finish_starting_game() -> void :
	game_has_started = true


	_fade_music_to_silence(2.8)
	queue_redraw()

	var active_players: Array[int] = []
	var human_sides: Array[int] = []
	var bot_sides: Array[int] = []
	for player_index in player_order:
		active_players.append(player_index + 1)
		if player_is_bot[player_index]:
			bot_sides.append(player_index)
		else:
			human_sides.append(player_index)
	game_started.emit(active_players)
	player_seats_selected.emit(human_sides, bot_sides)

	var overlay_tween: = create_tween()
	overlay_tween.set_parallel(true)
	overlay_tween.tween_property(self, "overlay_alpha", 0.0, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	overlay_tween.tween_method(_set_player_number_slide, 0.0, 1.0, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	overlay_tween.finished.connect(_finish_overlay_fade)


func _set_player_number_slide(value: float) -> void :
	player_number_slide = value
	queue_redraw()


func _finish_overlay_fade() -> void :
	_start_animation_running = false
	overlay_alpha = 0.0
	queue_redraw()
	_begin_scene_card_deal()


func _begin_scene_card_deal() -> void :
	if player_order.is_empty():
		return

	scene_deal_active = true
	scene_deck_visible = true
	scene_deck_busy = true
	current_scene_player_order = 0
	current_scene_cards_dealt = 0

	var centre: = to_local(camera_2d.get_screen_center_position())
	var visible_size: = _get_visible_world_size()
	var first_side: = player_order[0]
	for side in player_order:
		if not eliminated_players[side]:
			first_side = side
			break
	scene_deck_rotation = _get_player_rotation(first_side)
	scene_deck_position = _get_scene_deck_offscreen_position(first_side, centre, visible_size)

	var tween: = create_tween()
	tween.tween_method(
		_set_scene_deck_position.bind(scene_deck_position, centre), 
		0.0, 
		1.0, 
		0.48
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.finished.connect(_scene_deck_arrived)


func _scene_deck_arrived() -> void :
	scene_deck_busy = false
	queue_redraw()


func _handle_scene_card_input(local_position: Vector2, visible_size: Vector2) -> void :

	for card_index in range(dealt_scene_cards.size() - 1, -1, -1):
		var card: = dealt_scene_cards[card_index]
		if (card.get("moving", false)
			or card.get("flipping", false)
			or is_player_bot(card.owner_side)
			or not _is_scene_card_selected(card_index)):
			continue
		if _point_is_in_scene_card(local_position, card.position, card.rotation, visible_size, card.deal_scale):
			_flip_dealt_scene_card(card_index)
			return

	if ( not scene_deal_active
		or not scene_deck_visible
		or scene_deck_busy):
		return

	if _point_is_in_scene_card(local_position, scene_deck_position, scene_deck_rotation, visible_size):
		_deal_scene_card()


func _deal_scene_card() -> void :
	scene_deck_busy = true
	_play_random_flick()

	var owner_side: = player_order[current_scene_player_order]
	var card_index: = dealt_scene_cards.size()
	var owner_card_indices: = _get_owner_scene_card_indices(owner_side)
	var owner_card_count: = owner_card_indices.size() + 1
	var target_scale: = _get_dealt_scene_card_scale(
		_get_visible_world_size(), 
		owner_side, 
		owner_card_count
	)
	var target_position: = _get_dealt_scene_card_position(
		owner_side, 
		owner_card_count - 1, 
		owner_card_count, 
		_get_visible_world_size()
	)
	dealt_scene_cards.append({
		"owner_side": owner_side, 
		"owner_slot": owner_card_count - 1, 
		"card_number": _take_next_scene_card_number(owner_side), 
		"texture": _draw_scene_card_for_side(owner_side), 
		"revealed": false, 
		"position": scene_deck_position, 
		"rotation": scene_deck_rotation, 
		"flip_scale": 1.0, 
		"deal_scale": 1.0, 
		"moving": true, 
		"flipping": false, 
	})

	var tween: = create_tween()
	tween.set_parallel(true)
	tween.tween_method(
		_set_dealt_card_move.bind(card_index, scene_deck_position, target_position, target_scale), 
		0.0, 
		1.0, 
		SCENE_CARD_DEAL_TIME
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	for existing_slot in owner_card_indices.size():
		var existing_index: = owner_card_indices[existing_slot]
		var existing_start: Vector2 = dealt_scene_cards[existing_index].position
		var existing_start_scale: float = dealt_scene_cards[existing_index].deal_scale
		var existing_target: = _get_dealt_scene_card_position(
			owner_side, 
			existing_slot, 
			owner_card_count, 
			_get_visible_world_size()
		)
		tween.tween_method(
			_set_existing_card_layout.bind(
				existing_index, 
				existing_start, 
				existing_target, 
				existing_start_scale, 
				target_scale
			), 
			0.0, 
			1.0, 
			SCENE_CARD_DEAL_TIME
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.finished.connect(_dealt_scene_card_arrived.bind(card_index))


func _dealt_scene_card_arrived(card_index: int) -> void :
	var card: = dealt_scene_cards[card_index]
	card.moving = false
	dealt_scene_cards[card_index] = card
	var owner_indices: = _get_owner_scene_card_indices(card.owner_side)
	scene_cycle_indices[card.owner_side] = max(owner_indices.size() - 1, 0)
	_refresh_scene_hands_preserving_order()
	current_scene_cards_dealt += 1

	if current_scene_cards_dealt < 2:
		scene_deck_busy = false
		queue_redraw()
		return

	if current_scene_player_order + 1 < player_order.size():
		_rotate_scene_deck_to_next_player()
	else:
		_slide_scene_deck_offscreen()


func _rotate_scene_deck_to_next_player() -> void :
	var next_order: = current_scene_player_order + 1
	var next_side: = player_order[next_order]
	var target_rotation: = _get_player_rotation(next_side)
	var rotation_change: = wrapf(target_rotation - scene_deck_rotation, - PI, PI)
	var start_rotation: = scene_deck_rotation

	var tween: = create_tween()
	tween.tween_method(
		_set_scene_deck_rotation.bind(start_rotation, rotation_change), 
		0.0, 
		1.0, 
		0.3
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.finished.connect(_scene_deck_rotation_finished.bind(next_order))


func _scene_deck_rotation_finished(next_order: int) -> void :
	current_scene_player_order = next_order
	current_scene_cards_dealt = 0
	scene_deck_rotation = _get_player_rotation(player_order[next_order])
	scene_deck_busy = false
	queue_redraw()


func _slide_scene_deck_offscreen() -> void :
	var centre: = scene_deck_position
	var side: = player_order[current_scene_player_order]
	var target: = _get_scene_deck_offscreen_position(side, centre, _get_visible_world_size())
	var tween: = create_tween()
	tween.tween_method(
		_set_scene_deck_position.bind(centre, target), 
		0.0, 
		1.0, 
		0.42
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.finished.connect(_finish_scene_card_deal)


func _finish_scene_card_deal() -> void :
	scene_deck_visible = false
	scene_deal_active = false
	scene_deck_busy = false
	queue_redraw()
	_begin_character_card_draft()


func _flip_dealt_scene_card(card_index: int) -> void :
	_play_random_flick()
	var card: = dealt_scene_cards[card_index]
	card.flipping = true
	dealt_scene_cards[card_index] = card

	var tween: = create_tween()
	tween.tween_method(_set_dealt_card_flip_scale.bind(card_index), 1.0, 0.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(_toggle_dealt_scene_card_face.bind(card_index))
	tween.tween_method(_set_dealt_card_flip_scale.bind(card_index), 0.0, 1.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.finished.connect(_finish_dealt_scene_card_flip.bind(card_index))


func _toggle_dealt_scene_card_face(card_index: int) -> void :
	var card: = dealt_scene_cards[card_index]
	card.revealed = not card.revealed
	dealt_scene_cards[card_index] = card
	queue_redraw()


func _finish_dealt_scene_card_flip(card_index: int) -> void :
	var card: = dealt_scene_cards[card_index]
	card.flipping = false
	card.flip_scale = 1.0
	dealt_scene_cards[card_index] = card
	queue_redraw()


func _draw_scene_cards(visible_size: Vector2) -> void :
	var card_size: = _get_scene_card_size(visible_size)
	var card_rect: = Rect2( - card_size * 0.5, card_size)


	for side in player_order:
		_draw_scene_card_stack(side, card_rect)

	if scene_deck_visible:
		draw_set_transform(scene_deck_position, scene_deck_rotation, Vector2.ONE)
		draw_texture_rect((SCENE_CARD_BACK if selected_game_mode == GameContentMode.CFDI else BALDISCENE_CARD_BACK), card_rect, false)


	for card in dealt_scene_cards:
		if card.moving and not card.get("incoming_purchase", false):
			_draw_dealt_scene_card(card, card_rect)

	_draw_scene_card_offer(visible_size)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_scene_card_offer(visible_size: Vector2) -> void :
	if not card_play_phase_active:
		return
	var side: = _get_current_turn_side()
	if not _should_show_scene_card_offer(side):
		return
	var position: = _get_scene_offer_position(side, visible_size)
	var context_scale: = _get_context_button_scale(visible_size, side)
	var radius: = _get_player_button_radius(visible_size, side)
	draw_set_transform(position, _get_player_rotation(side), Vector2.ONE)
	draw_circle(Vector2.ZERO, radius, Color(0.08, 0.08, 0.08, 0.9))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color.WHITE, _get_action_button_outline_width(visible_size, side), true)
	var plus: = "+"
	var font_size: = int(42.0 * context_scale)
	var offer_font: = _get_player_font(side)
	var text_size: = offer_font.get_string_size(plus, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(offer_font, Vector2( - text_size.x * 0.5, text_size.y * 0.15), plus, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
	var star_size: = 15.0 * context_scale
	for index in 3:
		var centre: = Vector2((index - 1) * 17.0, 20.0) * context_scale
		if selected_game_mode == GameContentMode.BALDI: draw_texture_rect(YTP, Rect2(centre - Vector2.ONE * star_size * 0.5, Vector2.ONE * star_size), false)
		else: draw_texture_rect(STAR, Rect2(centre - Vector2.ONE * star_size * 0.5, Vector2.ONE * star_size), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _get_scene_offer_position(side: int, visible_size: Vector2) -> Vector2:
	var centre: = to_local(camera_2d.get_screen_center_position())
	var edge_position: = _get_player_position(side, centre, visible_size)
	var rotation: = _get_player_rotation(side)
	var player_button_position: = edge_position + _get_player_right_offset(side, visible_size) * player_number_slide
	var offer_radius: = _get_player_button_radius(visible_size, side)
	var required_clearance: = _get_player_button_radius(visible_size, side) + offer_radius + 18.0

	var position: = player_button_position + Vector2(0.0, - required_clearance).rotated(rotation)
	var margin: = offer_radius + 5.0
	return Vector2(
		clamp(position.x, centre.x - visible_size.x * 0.5 + margin, centre.x + visible_size.x * 0.5 - margin), 
		clamp(position.y, centre.y - visible_size.y * 0.5 + margin, centre.y + visible_size.y * 0.5 - margin)
	)


func _draw_dealt_scene_card(card: Dictionary, card_rect: Rect2) -> void :
	var use_scale: float = card.get("use_scale", 1.0)
	var use_alpha: float = card.get("use_alpha", 1.0)
	draw_set_transform(
		card.position + Vector2(card.get("use_offset", Vector2.ZERO)), 
		card.rotation + float(card.get("use_rotation", 0.0)), 
		Vector2(card.flip_scale, 1.0) * card.deal_scale * use_scale
	)
	var texture: Texture2D = card.texture if card.revealed else (SCENE_CARD_BACK if selected_game_mode == GameContentMode.CFDI else BALDISCENE_CARD_BACK)
	draw_texture_rect(texture, card_rect, false, Color(1.0, 1.0, 1.0, use_alpha))
	if not card.revealed:
		_draw_scene_card_back_number(card, card_rect, use_alpha)


func _draw_scene_card_back_number(card: Dictionary, card_rect: Rect2, alpha: float) -> void :
	var number: = str(card.get("card_number", 0))
	if number == "0":
		return
	var font_size = max(18, int(card_rect.size.x * 0.18))
	var card_font: = _get_player_font(card.owner_side)
	var text_size: = card_font.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var baseline: = Vector2( - text_size.x * 0.5, card_rect.end.y - card_rect.size.y * 0.055)
	draw_string(card_font, baseline + Vector2(2.0, 2.0), number, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.0, 0.0, 0.0, 0.75 * alpha))
	draw_string(card_font, baseline, number, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1.0, 1.0, 1.0, alpha))


func _take_next_scene_card_number(side: int) -> int:
	var number: = scene_card_next_numbers[side]
	scene_card_next_numbers[side] += 1
	return number


func _show_dragged_scene_card_visual(card_index: int) -> void :
	if (dragged_scene_card_visual == null
		or card_index < 0
		or card_index >= dealt_scene_cards.size()):
		return
	var card: = dealt_scene_cards[card_index]
	dragged_scene_card_visual.show_card(
		card, 
		_get_scene_card_size(_get_visible_world_size()), 
		(SCENE_CARD_BACK if selected_game_mode == GameContentMode.CFDI else BALDISCENE_CARD_BACK), 
		_get_player_font(card.owner_side)
	)


func _draw_scene_card_overlay() -> void :
	var index: = dragged_scene_play_index if dragged_scene_play_index >= 0 else card_being_used_index
	var size: = _get_scene_card_size(_get_visible_world_size())
	var card_rect: = Rect2( - size * 0.5, size)
	if (index >= 0
		and index < dealt_scene_cards.size()
		and not (index == dragged_scene_play_index
			and dragged_scene_card_visual != null
			and dragged_scene_card_visual.visible)):
		_draw_dealt_scene_card(dealt_scene_cards[index], card_rect)
	for incoming_card in dealt_scene_cards:
		if incoming_card.get("incoming_purchase", false):
			_draw_dealt_scene_card(incoming_card, card_rect)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_scene_card_stack(side: int, card_rect: Rect2) -> void :
	var indices: Array[int] = []
	for index in _get_owner_scene_card_indices(side):
		if ( not dealt_scene_cards[index].moving
			and index != dragged_scene_play_index
			and index != card_being_used_index):
			indices.append(index)
	if indices.is_empty():
		return
	indices.sort_custom( func(a: int, b: int) -> bool:
		var rotation: = _get_player_rotation(side)
		var a_x: float = dealt_scene_cards[a].position.rotated( - rotation).x
		var b_x: float = dealt_scene_cards[b].position.rotated( - rotation).x
		return a_x < b_x
	)
	for card_index in indices:
		var card: = dealt_scene_cards[card_index].duplicate()
		_draw_dealt_scene_card(card, card_rect)


func _get_scene_card_size(visible_size: Vector2) -> Vector2:
	var texture_size: = (SCENE_CARD_BACK if selected_game_mode == GameContentMode.CFDI else BALDISCENE_CARD_BACK).get_size()
	var height: = visible_size.y * SCENE_CARD_HEIGHT_RATIO
	return Vector2(height * texture_size.x / texture_size.y, height)


func _get_dealt_scene_card_size(visible_size: Vector2, side: int, _card_count: int) -> Vector2:
	var texture_size: = (SCENE_CARD_BACK if selected_game_mode == GameContentMode.CFDI else BALDISCENE_CARD_BACK).get_size()
	var aspect_ratio: = texture_size.x / texture_size.y
	var edge_span: = _get_hand_edge_span(side, visible_size)
	var hand_span_ratio: = 0.26 if _is_phone_layout(visible_size) else 0.22
	var hand_span: = edge_span * hand_span_ratio



	var available_depth: = _get_hand_available_depth(side, visible_size)
	var depth_limited_height = max(available_depth - 24.0, 4.0)




	var card_width_fraction: = 0.72 if _is_phone_layout(visible_size) else 1.0
	var width_limited_height: = hand_span * card_width_fraction / aspect_ratio
	var height = min(depth_limited_height, width_limited_height)
	return Vector2(height * texture_size.x / texture_size.y, height)


func _get_dealt_scene_card_scale(visible_size: Vector2, side: int, card_count: int) -> float:
	return _get_dealt_scene_card_size(visible_size, side, card_count).y / _get_scene_card_size(visible_size).y


func _get_visible_world_size() -> Vector2:
	var viewport_size: = get_viewport_rect().size
	return Vector2(viewport_size.x / camera_2d.zoom.x, viewport_size.y / camera_2d.zoom.y)


func _get_player_rotation(player_index: int) -> float:
	return [PI, - PI * 0.5, 0.0, PI * 0.5][player_index]


func _get_scene_deck_offscreen_position(side: int, centre: Vector2, visible_size: Vector2) -> Vector2:
	var outward_directions: = [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]
	return centre + outward_directions[side] * max(visible_size.x, visible_size.y) * 0.62


func _get_dealt_scene_card_position(side: int, slot: int, card_count: int, visible_size: Vector2) -> Vector2:
	var hand_anchor: = _get_hand_band_centre(side, visible_size)
	var card_size: = _get_dealt_scene_card_size(visible_size, side, card_count)
	var content_bounds: = _get_hand_content_bounds(side, visible_size)
	var star_width: = _get_player_star_size(visible_size).x
	var gap = max(_get_hand_edge_span(side, visible_size) * 0.012, 8.0)
	var cards_width = max(content_bounds.y - content_bounds.x - star_width - gap * 2.0, 0.0)
	var character_count: = _get_owner_character_card_indices(side).size()
	var character_size: = (
		_get_character_draft_card_size(visible_size)
		* _get_character_hand_scale(side, character_count, visible_size)
	)
	var character_lane_span = max(cards_width * 0.5, character_size.x)
	var character_stack_width: = _get_hand_stack_width(
		character_size.x, character_count, character_lane_span
	)
	var star_left: = content_bounds.y - star_width
	var character_centre = star_left - gap - character_stack_width * 0.5
	if _should_center_character_hand(side, character_count, visible_size):
		character_centre = 0.0
	var scene_right = character_centre - character_stack_width * 0.5 - gap
	var lane_span = max(scene_right - content_bounds.x, card_size.x)
	var usable_span = max(lane_span - card_size.x, 0.0)
	var step: = card_size.x * 0.78
	var visible_layers: = mini(card_count, MAX_VISIBLE_HAND_LAYERS)
	if visible_layers > 1:
		step = min(step, usable_span / float(visible_layers - 1))
	var hidden_layer_count: = maxi(card_count - visible_layers, 0)
	var visible_slot: = maxi(slot - hidden_layer_count, 0)
	var horizontal_position: = content_bounds.x + card_size.x * 0.5 + visible_slot * step
	var local_offset: = Vector2(
		horizontal_position, 
		0.0
	)
	var rotation: = _get_player_rotation(side)
	var target: = hand_anchor + local_offset.rotated(rotation)
	target = _clamp_scene_card_position(target, rotation, card_size, visible_size)
	return _keep_hand_item_clear_of_player_button(target, side, rotation, card_size, visible_size)


func _get_hand_stack_width(card_width: float, count: int, lane_span: float) -> float:
	if count <= 0:
		return 0.0
	var visible_layers: = mini(count, MAX_VISIBLE_HAND_LAYERS)
	var usable_span = max(lane_span - card_width, 0.0)
	var step: = card_width * 0.78
	if visible_layers > 1:
		step = min(step, usable_span / float(visible_layers - 1))
	return card_width + step * float(visible_layers - 1)


func _get_owner_scene_card_indices(owner_side: int) -> Array[int]:
	var indices: Array[int] = []
	for card_index in dealt_scene_cards.size():
		if dealt_scene_cards[card_index].owner_side == owner_side:
			indices.append(card_index)
	return indices


func _clamp_scene_card_position(position: Vector2, rotation: float, card_size: Vector2, visible_size: Vector2) -> Vector2:
	var safe_rect: = _get_safe_world_rect(visible_size)
	var quarter_turn = abs(sin(rotation)) > 0.5
	var visible_card_size: = Vector2(card_size.y, card_size.x) if quarter_turn else card_size
	var half_card: = visible_card_size * 0.5
	var margin: = 8.0
	return Vector2(
		clamp(position.x, safe_rect.position.x + half_card.x + margin, safe_rect.end.x - half_card.x - margin), 
		clamp(position.y, safe_rect.position.y + half_card.y + margin, safe_rect.end.y - half_card.y - margin)
	)


func _point_is_in_scene_card(point: Vector2, card_position: Vector2, card_rotation: float, visible_size: Vector2, size_scale: float = 1.0) -> bool:
	var local_point: = (point - card_position).rotated( - card_rotation)
	var half_size: = _get_scene_card_size(visible_size) * size_scale * 0.5
	return abs(local_point.x) <= half_size.x and abs(local_point.y) <= half_size.y


func _set_scene_deck_position(progress: float, start: Vector2, target: Vector2) -> void :
	scene_deck_position = start.lerp(target, progress)
	queue_redraw()


func _set_scene_deck_rotation(progress: float, start: float, change: float) -> void :
	scene_deck_rotation = start + change * progress
	queue_redraw()


func _set_dealt_card_move(progress: float, card_index: int, start: Vector2, target: Vector2, target_scale: float) -> void :
	var card: = dealt_scene_cards[card_index]
	card.position = start.lerp(target, progress)
	card.deal_scale = lerp(1.0, target_scale, progress)
	dealt_scene_cards[card_index] = card
	queue_redraw()


func _set_existing_card_layout(
	progress: float, 
	card_index: int, 
	start: Vector2, 
	target: Vector2, 
	start_scale: float, 
	target_scale: float
) -> void :
	var card: = dealt_scene_cards[card_index]
	card.position = start.lerp(target, progress)
	card.deal_scale = lerp(start_scale, target_scale, progress)
	dealt_scene_cards[card_index] = card
	queue_redraw()


func _set_dealt_card_flip_scale(value: float, card_index: int) -> void :
	var card: = dealt_scene_cards[card_index]
	card.flip_scale = value
	dealt_scene_cards[card_index] = card
	queue_redraw()


func _play_random_flick() -> void :
	flick.stream = [FLICK_1, FLICK_2, FLICK_3, FLICK_4].pick_random()
	flick.play()


func _begin_character_card_draft() -> void :
	character_draft_active = true
	character_deck_visible = true
	character_deck_busy = true
	character_deck_scale = 1.0
	current_character_player_order = 0
	draft_character_cards.clear()

	var centre: = to_local(camera_2d.get_screen_center_position())
	var visible_size: = _get_visible_world_size()
	var first_side: = player_order[0]
	character_deck_rotation = _get_player_rotation(first_side)
	character_deck_position = _get_scene_deck_offscreen_position(first_side, centre, visible_size)
	var start: = character_deck_position

	var tween: = create_tween()
	tween.tween_method(
		_set_character_deck_position.bind(start, centre), 0.0, 1.0, 0.48
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.finished.connect(_character_deck_arrived)


func _character_deck_arrived() -> void :
	character_deck_busy = false
	queue_redraw()


func _handle_character_card_input(point: Vector2, visible_size: Vector2) -> void :
	if character_deck_visible:
		if ( not character_deck_busy
			and _point_is_in_card(point, character_deck_position, character_deck_rotation, _get_scene_card_size(visible_size))):
			_start_character_layout()
		return

	if character_deck_busy:
		return

	for card_index in range(draft_character_cards.size() - 1, -1, -1):
		var card: = draft_character_cards[card_index]
		if _point_is_in_card(point, card.position, card.rotation, _get_character_draft_card_size(visible_size) * card.scale):
			_choose_character_card(card_index)
			return


func _start_character_layout() -> void :
	character_deck_busy = true
	draft_cards_finished = 0
	var choices: Array = []
	if selected_game_mode == GameContentMode.HYBRID:
		var cfdi_choices: = CHARACTER_CARD_TYPES.duplicate()
		var bfdi_choices: = BFDI_CHARACTER_CARD_TYPES.duplicate()
		cfdi_choices.shuffle()
		bfdi_choices.shuffle()
		var cards_per_player: = int(CHARACTER_DRAFT_COUNT / player_order.size())
		var cfdi_player_limit: = int(player_order.size() / 2)
		if player_order.size() % 2 == 0:
			hybrid_player_limits = [cfdi_player_limit, cfdi_player_limit]
		else:
			var majority_mode = [
				GameContentMode.CFDI, 
				GameContentMode.BFDI, 
			].pick_random()
			hybrid_player_limits = [1, 1]
			hybrid_player_limits[majority_mode] += 1
		var cfdi_card_count: = hybrid_player_limits[GameContentMode.CFDI] * cards_per_player
		var bfdi_card_count: = hybrid_player_limits[GameContentMode.BFDI] * cards_per_player
		choices.append_array(cfdi_choices.slice(0, cfdi_card_count))
		choices.append_array(bfdi_choices.slice(0, bfdi_card_count))
	else:
		choices = _get_character_card_types_for_mode(selected_game_mode).duplicate()
	choices.shuffle()
	var target_deck_scale: = _get_character_draft_card_size(_get_visible_world_size()).y / _get_scene_card_size(_get_visible_world_size()).y
	var deck_tween: = create_tween()
	deck_tween.tween_method(_set_character_deck_scale, character_deck_scale, target_deck_scale, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await deck_tween.finished
	_lay_out_character_cards(choices.slice(0, CHARACTER_DRAFT_COUNT))


func _lay_out_character_cards(choices: Array) -> void :
	var centre: = to_local(camera_2d.get_screen_center_position())
	var visible_size: = _get_visible_world_size()
	var rotation: = _get_player_rotation(player_order[current_character_player_order])

	for choice_index in choices.size():
		var card_index: = draft_character_cards.size()
		var is_last_card: = choice_index == choices.size() - 1
		var target: = _get_character_grid_position(choice_index, rotation, visible_size)
		var start_position: = centre
		if is_last_card:



			character_deck_visible = false
			start_position = centre.lerp(target, 0.16)
			queue_redraw()

			await get_tree().process_frame
		draft_character_cards.append({
			"texture": choices[choice_index], 
			"position": start_position, 
			"rotation": rotation, 
			"flip_scale": 1.0, 
			"scale": 1.0, 
			"revealed": false, 
		})
		_play_random_flick()
		var move_tween: = create_tween()
		move_tween.tween_method(
			_set_draft_character_position.bind(card_index, start_position, target), 0.0, 1.0, 0.045
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		move_tween.tween_method(_set_draft_character_flip.bind(card_index), 1.0, 0.0, 0.025)
		move_tween.tween_callback(_reveal_draft_character.bind(card_index))
		move_tween.tween_method(_set_draft_character_flip.bind(card_index), 0.0, 1.0, 0.025)
		move_tween.finished.connect(_draft_character_animation_finished)
		await get_tree().create_timer(0.018).timeout


func _choose_character_card(card_index: int) -> void :
	var side: = player_order[current_character_player_order]
	if not _is_draft_character_allowed_for_side(card_index, side):
		buzz.play()
		_animate_player_button(side)
		return
	character_deck_busy = true
	_play_random_flick()
	var selected: = draft_character_cards[card_index]
	draft_character_cards.remove_at(card_index)
	if selected_game_mode == GameContentMode.HYBRID and player_content_modes[side] < 0:
		player_content_modes[side] = _get_character_content_mode(selected.texture)
		_convert_player_scene_cards_to_mode(side)
	var owner_indices: = _get_owner_character_card_indices(side)
	var owner_count: = owner_indices.size() + 1
	var visible_size: = _get_visible_world_size()
	var target: = _get_character_hand_position(side, owner_count - 1, owner_count, visible_size)
	var target_scale: = _get_character_hand_scale(side, owner_count, visible_size)
	selected.owner_side = side
	selected.owner_slot = owner_count - 1
	selected.revealed = true
	player_character_cards.append(selected)
	var selected_index: = player_character_cards.size() - 1
	character_cycle_indices[side] = owner_count - 1

	var tween: = create_tween()
	tween.set_parallel(true)
	tween.tween_method(
		_set_player_character_layout.bind(selected_index, selected.position, target, selected.scale, target_scale), 
		0.0, 1.0, 0.34
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	for owner_slot in owner_indices.size():
		var existing_index: = owner_indices[owner_slot]
		var existing: = player_character_cards[existing_index]
		var existing_target: = _get_character_hand_position(side, owner_slot, owner_count, visible_size)
		tween.tween_method(
			_set_player_character_layout.bind(existing_index, existing.position, existing_target, existing.scale, target_scale), 
			0.0, 1.0, 0.34
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_refresh_scene_hands_preserving_order(true, true, false)
	await tween.finished
	_advance_character_draft_turn()


func _advance_character_draft_turn() -> void :
	if draft_character_cards.is_empty():
		character_draft_active = false
		character_deck_busy = false
		queue_redraw()
		_begin_star_draft()
		return

	current_character_player_order = (current_character_player_order + 1) % player_order.size()
	var next_rotation: = _get_player_rotation(player_order[current_character_player_order])
	var visible_size: = _get_visible_world_size()
	var tween: = create_tween()
	tween.set_parallel(true)
	for card_index in draft_character_cards.size():
		var card: = draft_character_cards[card_index]
		var target: = _get_character_grid_position(card_index, next_rotation, visible_size)
		var rotation_change: = wrapf(next_rotation - card.rotation, - PI, PI)
		tween.tween_method(
			_set_draft_character_layout.bind(card_index, card.position, target, card.rotation, rotation_change), 
			0.0, 1.0, 0.3
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	character_deck_busy = false
	queue_redraw()


func _draw_character_cards(visible_size: Vector2) -> void :
	var draft_size: = _get_character_draft_card_size(visible_size)
	var draft_rect: = Rect2( - draft_size * 0.5, draft_size)
	var deck_size: = _get_scene_card_size(visible_size)
	var deck_rect: = Rect2( - deck_size * 0.5, deck_size)


	if character_deck_visible:
		draw_set_transform(character_deck_position, character_deck_rotation, Vector2.ONE * character_deck_scale)
		draw_texture_rect((CHARACTER_CARD_BACK if selected_game_mode == GameContentMode.CFDI else BALDI_CARD_BACK), deck_rect, false)

	for side in player_order:
		_draw_character_card_stack(side, draft_rect)
	_draw_character_target_highlight(draft_rect)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_character_draft_overlay(visible_size: Vector2) -> void :
	if draft_character_cards.is_empty():
		return
	var draft_size: = _get_character_draft_card_size(visible_size)
	var draft_rect: = Rect2( - draft_size * 0.5, draft_size)
	for card in draft_character_cards:
		draw_set_transform(
			card.position, 
			card.rotation, 
			Vector2(card.flip_scale, 1.0) * card.scale
		)
		var texture: Texture2D = card.texture if card.revealed else (CHARACTER_CARD_BACK if selected_game_mode == GameContentMode.CFDI else BALDI_CARD_BACK)
		draw_texture_rect(texture, draft_rect, false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_character_target_highlight(card_rect: Rect2) -> void :
	if highlighted_character_card_index < 0 or highlighted_character_card_index >= player_character_cards.size():
		return
	var card: = player_character_cards[highlighted_character_card_index]
	var legal: = true
	if dragged_scene_play_index >= 0:
		legal = _is_scene_card_legal_for_character(
			dragged_scene_play_index, highlighted_character_card_index
		)
	draw_set_transform(card.position, card.rotation, Vector2.ONE * card.scale)
	draw_rect(card_rect.grow(8.0), Color.GREEN if legal else Color.RED, false, 11.0, true)


func _draw_character_card_stack(side: int, card_rect: Rect2) -> void :
	var indices: = _get_owner_character_card_indices(side)
	if indices.is_empty():
		return
	indices.sort_custom( func(a: int, b: int) -> bool:
		var rotation: = _get_player_rotation(side)
		var a_x: float = player_character_cards[a].position.rotated( - rotation).x
		var b_x: float = player_character_cards[b].position.rotated( - rotation).x
		return a_x < b_x
	)
	for card_index in indices:
		var card: = player_character_cards[card_index]
		draw_set_transform(card.position, card.rotation, Vector2.ONE * card.scale)
		draw_texture_rect(card.texture, card_rect, false)
		_draw_character_development_icons(card_index, card_rect)


func _draw_character_development_icons(card_index: int, card_rect: Rect2) -> void :
	var card: = player_character_cards[card_index]
	var attributes: Array = card.get("development_attributes", [])
	var mini_index: = _find_mini_for_character_card(card_index)
	if mini_index >= 0:
		attributes = character_minis_on_board[mini_index].get("development_attributes", attributes)
	if attributes.is_empty():
		return
	var icon_size: = card_rect.size.x * 0.2
	var padding_x: = icon_size * 0.76
	var padding_y: = icon_size * 0.84
	var columns: = 4
	for index in attributes.size():
		var column: = index % columns
		var row: = index / columns
		var centre: = Vector2(
			card_rect.position.x + padding_x + column * icon_size * 1.08, 
			card_rect.position.y + padding_y + row * icon_size * 1.08
		)
		var icon: Texture2D = ATTRIBUTE_ICONS[attributes[index]]
		draw_texture_rect(icon, Rect2(centre - Vector2.ONE * icon_size * 0.5, Vector2.ONE * icon_size), false)


func _get_character_draft_card_size(visible_size: Vector2) -> Vector2:
	var texture_size: = (CHARACTER_CARD_BACK if selected_game_mode == GameContentMode.CFDI else BALDI_CARD_BACK).get_size()
	var aspect: = texture_size.x / texture_size.y
	var area_size: = Vector2(
		visible_size.x * 0.9, 
		visible_size.y * 0.76
	)
	var height = min(area_size.y / 3.35, area_size.x / (CHARACTER_DRAFT_COLUMNS + 0.45) / aspect)
	return Vector2(height * aspect, height)


func _get_character_grid_position(index: int, rotation: float, visible_size: Vector2) -> Vector2:
	var card_size: = _get_character_draft_card_size(visible_size)
	var spacing: = card_size * Vector2(1.04, 1.04)
	var column: = index % CHARACTER_DRAFT_COLUMNS
	var row: = index / CHARACTER_DRAFT_COLUMNS
	var local_position: = Vector2(
		(column - (CHARACTER_DRAFT_COLUMNS - 1) * 0.5) * spacing.x, 
		(row - 1.0) * spacing.y
	)
	return to_local(camera_2d.get_screen_center_position()) + local_position.rotated(rotation)


func _get_character_hand_scale(side: int, _count: int, visible_size: Vector2) -> float:
	var draft_size: = _get_character_draft_card_size(visible_size)


	var scene_hand_size: = _get_dealt_scene_card_size(visible_size, side, 1)
	return scene_hand_size.y / draft_size.y


func _get_character_hand_position(side: int, slot: int, count: int, visible_size: Vector2) -> Vector2:
	var hand_anchor: = _get_hand_band_centre(side, visible_size)
	var card_size: = _get_character_draft_card_size(visible_size) * _get_character_hand_scale(side, count, visible_size)
	var content_bounds: = _get_hand_content_bounds(side, visible_size)
	var star_width: = _get_player_star_size(visible_size).x
	var gap = max(_get_hand_edge_span(side, visible_size) * 0.012, 8.0)
	var lane_span = max((content_bounds.y - content_bounds.x - star_width - gap * 2.0) * 0.5, card_size.x)
	var usable_span = max(lane_span - card_size.x, 0.0)
	var step: = card_size.x * 0.78
	var visible_layers: = mini(count, MAX_VISIBLE_HAND_LAYERS)
	if visible_layers > 1:
		step = min(step, usable_span / float(visible_layers - 1))
	var hidden_layer_count: = maxi(count - visible_layers, 0)
	var visible_slot: = maxi(slot - hidden_layer_count, 0)
	var used_span: = step * float(maxi(visible_layers - 1, 0))
	var stack_width: = card_size.x + used_span
	var star_left: = content_bounds.y - star_width
	var lane_centre = star_left - gap - stack_width * 0.5
	if _should_center_character_hand(side, count, visible_size):
		lane_centre = 0.0
	var local_x = lane_centre - used_span * 0.5 + visible_slot * step
	var rotation: = _get_player_rotation(side)
	var target: = _clamp_scene_card_position(
		hand_anchor + Vector2(local_x, 0.0).rotated(rotation), 
		rotation, 
		card_size, 
		visible_size
	)
	return _keep_hand_item_clear_of_player_button(target, side, rotation, card_size, visible_size)


func _should_center_character_hand(
	side: int, character_count: int, visible_size: Vector2
) -> bool:
	var on_long_edge: = (
		(side == 0 or side == 2)
		if visible_size.x >= visible_size.y
		else (side == 1 or side == 3)
	)
	if on_long_edge:
		return true

	var content_bounds: = _get_hand_content_bounds(side, visible_size)
	var edge_span: = _get_hand_edge_span(side, visible_size)
	var gap = max(edge_span * 0.012, 8.0)
	var star_width: = _get_player_star_size(visible_size).x
	var star_left: = content_bounds.y - star_width
	var cards_width = max(
		content_bounds.y - content_bounds.x - star_width - gap * 2.0, 
		0.0
	)

	var character_size: = (
		_get_character_draft_card_size(visible_size)
		* _get_character_hand_scale(side, character_count, visible_size)
	)
	var character_width: = _get_hand_stack_width(
		character_size.x, 
		character_count, 
		max(cards_width * 0.5, character_size.x)
	)

	var scene_count: = _get_owner_scene_card_indices(side).size()
	var scene_size: = _get_dealt_scene_card_size(
		visible_size, side, scene_count
	)
	var scene_width: = _get_hand_stack_width(
		scene_size.x, 
		scene_count, 
		max(cards_width * 0.5, scene_size.x)
	)

	var centred_character_left: = - character_width * 0.5
	var centred_character_right: = character_width * 0.5
	var scene_fits = (
		content_bounds.x + scene_width + gap <= centred_character_left
	)
	var stars_fit = centred_character_right + gap <= star_left
	return scene_fits and stars_fit


func _get_owner_character_card_indices(side: int) -> Array[int]:
	var indices: Array[int] = []
	for index in player_character_cards.size():
		if player_character_cards[index].owner_side == side:
			indices.append(index)
	return indices


func _point_is_in_card(point: Vector2, position: Vector2, rotation: float, size: Vector2) -> bool:
	var local_point: = (point - position).rotated( - rotation)
	return abs(local_point.x) <= size.x * 0.5 and abs(local_point.y) <= size.y * 0.5


func _set_character_deck_position(progress: float, start: Vector2, target: Vector2) -> void :
	character_deck_position = start.lerp(target, progress)
	queue_redraw()


func _set_draft_character_position(progress: float, index: int, start: Vector2, target: Vector2) -> void :
	var card: = draft_character_cards[index]
	card.position = start.lerp(target, progress)
	draft_character_cards[index] = card
	queue_redraw()


func _set_draft_character_flip(value: float, index: int) -> void :
	var card: = draft_character_cards[index]
	card.flip_scale = value
	draft_character_cards[index] = card
	queue_redraw()


func _reveal_draft_character(index: int) -> void :
	var card: = draft_character_cards[index]
	card.revealed = true
	draft_character_cards[index] = card
	queue_redraw()


func _draft_character_animation_finished() -> void :
	draft_cards_finished += 1
	if draft_cards_finished >= CHARACTER_DRAFT_COUNT:
		character_deck_busy = false
		queue_redraw()


func _set_character_deck_scale(value: float) -> void :
	character_deck_scale = value
	queue_redraw()


func _set_draft_character_layout(progress: float, index: int, start: Vector2, target: Vector2, start_rotation: float, rotation_change: float) -> void :
	var card: = draft_character_cards[index]
	card.position = start.lerp(target, progress)
	card.rotation = start_rotation + rotation_change * progress
	draft_character_cards[index] = card
	queue_redraw()


func _set_player_character_layout(progress: float, index: int, start: Vector2, target: Vector2, start_scale: float, target_scale: float) -> void :
	var card: = player_character_cards[index]
	card.position = start.lerp(target, progress)
	card.scale = lerp(start_scale, target_scale, progress)
	player_character_cards[index] = card
	queue_redraw()


func _begin_star_draft() -> void :
	star_draft_active = true
	star_draft_busy = true
	current_star_player_order = 0
	draft_stars.clear()
	_lay_out_stars()


func _lay_out_stars() -> void :
	var visible_size: = _get_visible_world_size()
	var centre: = to_local(camera_2d.get_screen_center_position())
	var first_side: = player_order[0]
	var start: = _get_scene_deck_offscreen_position(first_side, centre, visible_size)

	for star_index in player_order.size():
		var index: = draft_stars.size()
		draft_stars.append({
			"position": start, 
			"moving": true, 
			"scale": 1.0, 
		})
		star.play()
		var target: = _get_centre_star_position(star_index, player_order.size(), visible_size)
		var tween: = create_tween()
		tween.tween_method(
			_set_draft_star_position.bind(index, start, target), 0.0, 1.0, 0.26
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.finished.connect(_draft_star_arrived.bind(index))
		await get_tree().create_timer(0.07).timeout


func _draft_star_arrived(index: int) -> void :
	if index >= draft_stars.size():
		return
	var item: = draft_stars[index]
	item.moving = false
	draft_stars[index] = item
	for remaining in draft_stars:
		if remaining.moving:
			return
	if draft_stars.size() >= player_order.size():
		star_draft_busy = false
	queue_redraw()


func _handle_star_input(point: Vector2, visible_size: Vector2) -> void :
	if star_draft_busy:
		return
	var size: = _get_centre_star_size(visible_size)
	for index in range(draft_stars.size() - 1, -1, -1):
		if Rect2(draft_stars[index].position - size * 0.5, size).has_point(point):
			_take_star(index)
			return


func _take_star(draft_index: int) -> void :
	star_draft_busy = true
	star.play()
	var side: = player_order[current_star_player_order]
	var item: = draft_stars[draft_index]
	draft_stars.remove_at(draft_index)
	item.owner_side = side
	item.moving = true
	var visible_size: = _get_visible_world_size()
	item.travel_scale = (
		_get_centre_star_size(visible_size).x
		/ max(_get_player_star_size(visible_size).x, 1.0)
	)
	item.travel_rotation = 0.0
	player_stars.append(item)
	var player_star_index: = player_stars.size() - 1
	_refresh_player_star_stack(side)
	var start: Vector2 = item.position
	var owner_star_count: = _get_owner_star_count(side)
	var target: = _get_player_star_position(side, _get_visible_world_size(), owner_star_count - 1, owner_star_count)

	var tween: = create_tween()
	tween.tween_method(
		_set_player_star_position.bind(player_star_index, start, target), 0.0, 1.0, 0.34
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.finished.connect(_player_star_arrived.bind(player_star_index))


func _player_star_arrived(index: int) -> void :
	if index < 0 or index >= player_stars.size():
		return
	var item: = player_stars[index]
	item.moving = false
	item.travel_scale = 1.0
	item.travel_rotation = _get_player_rotation(item.owner_side)
	player_stars[index] = item
	if draft_stars.is_empty():
		star_draft_active = false
		star_draft_busy = false
		_begin_character_mini_placement()
	else:
		current_star_player_order = (current_star_player_order + 1) % player_order.size()
		star_draft_busy = false
	queue_redraw()


func _draw_stars(visible_size: Vector2) -> void :
	var player_size: = _get_player_star_size(visible_size)
	for item in player_stars:
		if item.get("moving", false):
			continue
		var visual_scale: float = item.get("visual_scale", 1.0)
		var alpha: float = item.get("alpha", 1.0)
		draw_set_transform(item.position, _get_player_rotation(item.owner_side), Vector2.ONE * visual_scale)
		if selected_game_mode == GameContentMode.BALDI: draw_texture_rect(YTP, Rect2( - player_size * 0.5, player_size), false, Color(1.0, 1.0, 1.0, alpha))
		else: draw_texture_rect(STAR, Rect2( - player_size * 0.5, player_size), false, Color(1.0, 1.0, 1.0, alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_centre_stars_overlay(visible_size: Vector2) -> void :
	var centre_size: = _get_centre_star_size(visible_size)
	for item in draft_stars:
		draw_set_transform(item.position, 0.0, Vector2.ONE)
		if selected_game_mode == GameContentMode.BALDI: draw_texture_rect(YTP, Rect2( - centre_size * 0.5, centre_size), false)
		else: draw_texture_rect(STAR, Rect2( - centre_size * 0.5, centre_size), false)
	for item in alliance_offered_star_items:
		var offer_scale: float = item.get("travel_scale", 1.0)
		var offer_size: = _get_player_star_size(visible_size) * offer_scale
		var offer_rotation: float = item.get("travel_rotation", 0.0)
		draw_set_transform(item.position, offer_rotation, Vector2.ONE)
		if selected_game_mode == GameContentMode.BALDI: draw_texture_rect(YTP, Rect2( - offer_size * 0.5, offer_size), false)
		else: draw_texture_rect(STAR, Rect2( - offer_size * 0.5, offer_size), false)
	for item in player_stars:
		if not item.get("moving", false):
			continue
		var visual_scale: float = item.get("visual_scale", 1.0)
		var alpha: float = item.get("alpha", 1.0)
		var travel_scale: float = item.get("travel_scale", 1.0)
		var travel_size: = _get_player_star_size(visible_size) * travel_scale
		var travel_rotation: float = item.get(
			"travel_rotation", _get_player_rotation(item.owner_side)
		)
		draw_set_transform(item.position, travel_rotation, Vector2.ONE * visual_scale)
		
		if selected_game_mode == GameContentMode.BALDI: 
			draw_texture_rect(
				YTP, 
				Rect2( - travel_size * 0.5, travel_size), 
				false
			)
		else:
			draw_texture_rect(
				STAR, 
				Rect2( - travel_size * 0.5, travel_size), 
				false
			)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _get_centre_star_size(visible_size: Vector2) -> Vector2:
	var side = min(visible_size.x, visible_size.y) * 0.145
	return Vector2.ONE * side


func _get_player_star_size(visible_size: Vector2) -> Vector2:
	var side = min(visible_size.x, visible_size.y) * 0.075
	return Vector2.ONE * side


func _get_centre_star_position(index: int, count: int, visible_size: Vector2) -> Vector2:
	var size: = _get_centre_star_size(visible_size)
	var spacing: = size.x * 1.18
	var centre: = to_local(camera_2d.get_screen_center_position())
	return centre + Vector2((index - (count - 1) * 0.5) * spacing, 0.0)


func _get_player_star_position(side: int, visible_size: Vector2, slot: int = 0, count: int = 1) -> Vector2:
	var hand_anchor: = _get_hand_band_centre(side, visible_size)
	var size: = _get_player_star_size(visible_size)



	var content_bounds: = _get_hand_content_bounds(side, visible_size)
	var lane_x: = content_bounds.y - size.x * 0.5
	var card_height: = _get_dealt_scene_card_size(visible_size, side, 1).y
	var usable_height = max(card_height - size.y, 0.0)
	var step: = 0.0
	if count > 1:
		step = min(size.y * 0.34, usable_height / float(count - 1))
	var used_height: = step * float(maxi(count - 1, 0))
	var local_y: = used_height * 0.5 - float(max(slot, 0)) * step
	var rotation: = _get_player_rotation(side)
	var target: = _clamp_scene_card_position(
		hand_anchor + Vector2(lane_x, local_y).rotated(rotation), 
		rotation, 
		size, 
		visible_size
	)
	return _keep_hand_item_clear_of_player_button(target, side, rotation, size, visible_size)


func _get_hand_content_bounds(side: int, visible_size: Vector2) -> Vector2:
	var edge_span: = _get_hand_edge_span(side, visible_size)
	var outer_gap = max(edge_span * 0.012, 8.0)



	var half_span: = edge_span * 0.35
	var centre: = to_local(camera_2d.get_screen_center_position())
	var hand_anchor: = _get_hand_band_centre(side, visible_size)
	var button_position: = _get_player_position(side, centre, visible_size)
	button_position += _get_player_right_offset(side, visible_size) * player_number_slide
	var rotation: = _get_player_rotation(side)
	var button_local_x: = (button_position - hand_anchor).rotated( - rotation).x
	var button_clearance = _get_player_button_radius(visible_size, side) + outer_gap
	if abs(button_local_x) > button_clearance:
		half_span = min(half_span, abs(button_local_x) - button_clearance)
	half_span = max(half_span, edge_span * 0.22)
	return Vector2( - half_span, half_span)


func _keep_hand_item_clear_of_player_button(
	position: Vector2, 
	side: int, 
	rotation: float, 
	item_size: Vector2, 
	visible_size: Vector2
) -> Vector2:
	var centre: = to_local(camera_2d.get_screen_center_position())
	var button_position: = _get_player_position(side, centre, visible_size)
	button_position += _get_player_right_offset(side, visible_size) * player_number_slide
	var clearance: = _get_player_button_radius(visible_size, side) + 8.0
	var local_delta: = (position - button_position).rotated( - rotation)
	var required_x: = item_size.x * 0.5 + clearance
	var required_y: = item_size.y * 0.5 + clearance
	if abs(local_delta.x) >= required_x or abs(local_delta.y) >= required_y:
		return position
	var direction: = -1.0 if local_delta.x <= 0.0 else 1.0
	local_delta.x = direction * required_x
	var corrected: = button_position + local_delta.rotated(rotation)
	return _clamp_scene_card_position(corrected, rotation, item_size, visible_size)


func _get_owner_star_count(side: int) -> int:
	var count: = 0
	for item in player_stars:
		if item.owner_side == side:
			count += 1
	return count


func _refresh_player_star_stack(side: int, animate: bool = true) -> void :
	var count: = _get_owner_star_count(side)
	if animate:
		var previous: Tween = star_hand_reflow_tweens[side]
		if previous != null and previous.is_valid():
			previous.kill()
		star_hand_reflow_tweens[side] = null
	var slot: = 0
	for index in player_stars.size():
		var item: = player_stars[index]
		if item.owner_side != side:
			continue
		if not item.moving:
			var target: = _get_player_star_position(
				side, _get_visible_world_size(), slot, count
			)
			if animate and not item.position.is_equal_approx(target):
				if star_hand_reflow_tweens[side] == null:
					star_hand_reflow_tweens[side] = create_tween()
					star_hand_reflow_tweens[side].set_parallel(true)
				star_hand_reflow_tweens[side].tween_method(
					_set_player_star_layout_position.bind(index, item.position, target), 
					0.0, 
					1.0, 
					0.2
				).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			else:
				item.position = target
				player_stars[index] = item
		slot += 1


func _set_player_star_layout_position(
	progress: float, index: int, start: Vector2, target: Vector2
) -> void :
	if index < 0 or index >= player_stars.size():
		return
	var item: = player_stars[index]
	item.position = start.lerp(target, progress)
	player_stars[index] = item
	queue_redraw()


func _set_draft_star_position(progress: float, index: int, start: Vector2, target: Vector2) -> void :
	if index >= draft_stars.size():
		return
	var item: = draft_stars[index]
	item.position = start.lerp(target, progress)
	draft_stars[index] = item
	queue_redraw()


func _set_player_star_position(progress: float, index: int, start: Vector2, target: Vector2) -> void :
	if index < 0 or index >= player_stars.size():
		return
	var item: = player_stars[index]
	item.position = start.lerp(target, progress)
	var visible_size: = _get_visible_world_size()
	var centre_ratio = (
		_get_centre_star_size(visible_size).x
		/ max(_get_player_star_size(visible_size).x, 1.0)
	)
	item.travel_scale = lerp(centre_ratio, 1.0, progress)
	item.travel_rotation = lerp_angle(
		0.0, _get_player_rotation(item.owner_side), progress
	)
	player_stars[index] = item
	queue_redraw()


func _set_alliance_star_layout(
	progress: float, 
	index: int, 
	start: Vector2, 
	target: Vector2, 
	start_scale: float, 
	target_scale: float, 
	start_rotation: float, 
	target_rotation: float
) -> void :
	if index < 0 or index >= alliance_offered_star_items.size():
		return
	var item: = alliance_offered_star_items[index]
	item.position = start.lerp(target, progress)
	item.travel_scale = lerp(start_scale, target_scale, progress)
	item.travel_rotation = lerp_angle(start_rotation, target_rotation, progress)
	alliance_offered_star_items[index] = item
	queue_redraw()


func _stop_alliance_star_layout() -> void :
	if alliance_star_layout_tween != null and alliance_star_layout_tween.is_valid():
		alliance_star_layout_tween.kill()
	alliance_star_layout_tween = null


func _begin_character_mini_placement() -> void :
	character_mini_placement_active = true
	character_minis_on_board.clear()
	character_mini_placements_finished = 0
	_place_character_minis_in_turn_order()


func _place_character_minis_in_turn_order() -> void :
	var ordered_cards: Array[Dictionary] = []
	var cards_by_side: Dictionary = {}
	var largest_hand: = 0
	for side in player_order:
		var cards: Array[Dictionary] = []
		for card in player_character_cards:
			if card.owner_side == side:
				cards.append(card)
		cards_by_side[side] = cards
		largest_hand = max(largest_hand, cards.size())

	for choice_number in largest_hand:
		for side in player_order:
			var cards: Array = cards_by_side[side]
			if choice_number < cards.size():
				ordered_cards.append(cards[choice_number])
	character_mini_target_count = min(ordered_cards.size(), BOARD_ROWS)

	var visible_size: = _get_visible_world_size()
	var centre: = to_local(camera_2d.get_screen_center_position())
	for row in character_mini_target_count:
		var card_texture: Texture2D = ordered_cards[row].texture
		var mini_texture: = _get_character_mini_for_texture(card_texture)
		var character_name: = _get_character_name_for_texture(card_texture)
		if mini_texture == null or character_name.is_empty():
			continue
		var target: = _get_board_cell_centre(0, row, visible_size)
		var start: = Vector2(centre.x + visible_size.x * 0.62, target.y)
		var mini_index: = character_minis_on_board.size()
		character_minis_on_board.append({
			"texture": mini_texture, 
			"character_name": character_name, 
			"content_mode": _get_character_content_mode(card_texture), 
			"owner_side": ordered_cards[row].owner_side, 
			"position": start, 
			"row": row, 
			"current_column": 0, 
			"target_column": 0, 
			"matching_attributes": 0, 
			"moving": true, 
			"visual_scale": 1.6, 
		})
		grab.play()
		_animate_character_mini_placement(mini_index, start, target)
		await get_tree().create_timer(0.045).timeout


func _animate_character_mini_placement(mini_index: int, start: Vector2, target: Vector2) -> void :
	var tween: = create_tween()
	tween.tween_method(
		_set_character_mini_position.bind(mini_index, start, target), 0.0, 1.0, 0.14
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished
	place.play()
	var placement_tween: = create_tween()
	placement_tween.tween_method(
		_set_character_mini_scale.bind(mini_index), 1.6, 0.86, 0.06
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	placement_tween.tween_method(
		_set_character_mini_scale.bind(mini_index), 0.86, 1.0, 0.08
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await placement_tween.finished
	var item: = character_minis_on_board[mini_index]
	item.moving = false
	item.visual_scale = 1.0
	character_minis_on_board[mini_index] = item
	character_mini_placements_finished += 1
	if character_mini_placements_finished >= character_mini_target_count:
		character_mini_placement_active = false
		_begin_challenge_card_phase()
	queue_redraw()


func _draw_character_minis(visible_size: Vector2) -> void :
	var cell_size: = _get_board_cell_size(visible_size)
	var shared_scale: = _get_character_mini_shared_scale(cell_size)
	for index in character_minis_on_board.size():
		if index != dragged_mini_index and index != swap_displaced_mini_index:
			_draw_character_mini(character_minis_on_board[index], shared_scale)
	if highlighted_swap_mini_index >= 0 and highlighted_swap_mini_index < character_minis_on_board.size():
		var target: = character_minis_on_board[highlighted_swap_mini_index]
		var target_size: = _get_character_mini_size(target, visible_size) + Vector2.ONE * 14.0
		draw_rect(Rect2(target.position - target_size * 0.5, target_size), Color(0.25, 1.0, 0.35, 0.95), false, 5.0)
	if swap_displaced_mini_index >= 0 and swap_displaced_mini_index < character_minis_on_board.size():
		_draw_character_mini(character_minis_on_board[swap_displaced_mini_index], shared_scale)

	if dragged_mini_index >= 0:
		_draw_character_mini(character_minis_on_board[dragged_mini_index], shared_scale)


func _draw_character_mini(item: Dictionary, shared_scale: float) -> void :
	var texture: Texture2D = item.texture
	var size = texture.get_size() * shared_scale * item.visual_scale
	if item.get("has_win_token", false):
		var token_size = min(size.x, size.y) * 0.46
		var token_centre = item.position + Vector2(0.0, size.y * 0.38)
		draw_texture_rect(
			BFDI_WIN_TOKEN if item.get("content_mode", GameContentMode.CFDI) == GameContentMode.BFDI else WIN_TOKEN, 
			Rect2(token_centre - Vector2.ONE * token_size * 0.5, Vector2.ONE * token_size), 
			false
		)
	draw_texture_rect(texture, Rect2(item.position - size * 0.5, size), false)


func _get_character_mini_shared_scale(cell_size: Vector2) -> float:
	var largest_texture_size: = Vector2.ZERO
	var all_mini_textures: Array[Texture2D] = CHARACTER_MINI_TYPES + BFDI_CHARACTER_MINI_TYPES
	for texture in all_mini_textures:
		var texture_size: = texture.get_size()
		largest_texture_size.x = max(largest_texture_size.x, texture_size.x)
		largest_texture_size.y = max(largest_texture_size.y, texture_size.y)


	return min(
		cell_size.x * 1.05 / largest_texture_size.x, 
		cell_size.y * 1.2 / largest_texture_size.y
	)


func _get_board_rect(visible_size: Vector2) -> Rect2:
	var centre: = to_local(camera_2d.get_screen_center_position())
	var board_size: = Vector2(
		visible_size.x * _get_board_width_ratio(visible_size), 
		visible_size.y * _get_board_height_ratio(visible_size)
	)
	return Rect2(centre - board_size * 0.5, board_size)


func _get_hand_available_depth(side: int, visible_size: Vector2) -> float:
	var board_rect: = _get_board_rect(visible_size)
	var safe_rect: = _get_safe_world_rect(visible_size)
	match side:
		0:
			return max(board_rect.position.y - safe_rect.position.y, 0.0)
		1:
			return max(safe_rect.end.x - board_rect.end.x, 0.0)
		2:
			return max(safe_rect.end.y - board_rect.end.y, 0.0)
		_:
			return max(board_rect.position.x - safe_rect.position.x, 0.0)


func _get_hand_edge_span(side: int, visible_size: Vector2) -> float:
	var safe_size: = _get_safe_world_rect(visible_size).size
	return safe_size.x if side == 0 or side == 2 else safe_size.y


func _get_hand_band_centre(side: int, visible_size: Vector2) -> Vector2:
	var board_rect: = _get_board_rect(visible_size)
	var safe_rect: = _get_safe_world_rect(visible_size)
	match side:
		0:
			return Vector2(
				safe_rect.get_center().x, 
				(safe_rect.position.y + board_rect.position.y) * 0.5
			)
		1:
			return Vector2(
				(safe_rect.end.x + board_rect.end.x) * 0.5, 
				safe_rect.get_center().y
			)
		2:
			return Vector2(
				safe_rect.get_center().x, 
				(safe_rect.end.y + board_rect.end.y) * 0.5
			)
		_:
			return Vector2(
				(safe_rect.position.x + board_rect.position.x) * 0.5, 
				safe_rect.get_center().y
			)


func _get_board_cell_size(visible_size: Vector2) -> Vector2:
	var board_size: = _get_board_rect(visible_size).size
	var gap: = visible_size.x * COLUMN_GAP_RATIO
	var column_width: = (board_size.x - gap * (BOARD_COLUMNS - 1)) / BOARD_COLUMNS
	return Vector2(column_width, board_size.y / BOARD_ROWS)


func _get_board_cell_centre(column: int, row: int, visible_size: Vector2) -> Vector2:
	var board_rect: = _get_board_rect(visible_size)
	var board_size: = board_rect.size
	var board_position: = board_rect.position
	var gap: = visible_size.x * COLUMN_GAP_RATIO
	var cell_size: = _get_board_cell_size(visible_size)
	return board_position + Vector2(
		column * (cell_size.x + gap) + cell_size.x * 0.5, 
		row * cell_size.y + cell_size.y * 0.5
	)


func _set_character_mini_position(progress: float, index: int, start: Vector2, target: Vector2) -> void :
	var item: = character_minis_on_board[index]
	item.position = start.lerp(target, progress)
	character_minis_on_board[index] = item
	queue_redraw()


func _set_character_mini_scale(value: float, index: int) -> void :
	var item: = character_minis_on_board[index]
	item.visual_scale = value
	character_minis_on_board[index] = item
	queue_redraw()


func _begin_challenge_card_phase() -> void :
	_sync_development_attributes_to_cards()
	_ensure_valid_challenge_opener()
	challenge_phase_active = true
	challenge_card_visible = true
	challenge_card_busy = true
	challenge_card_face_up = false
	challenge_card_flip_scale = 1.0
	current_challenge = {}
	var centre: = to_local(camera_2d.get_screen_center_position())
	var visible_size: = _get_visible_world_size()
	var first_side: = challenge_opener_side
	challenge_card_rotation = _get_player_rotation(first_side)
	challenge_card_position = _get_scene_deck_offscreen_position(first_side, centre, visible_size)
	var start: = challenge_card_position
	var tween: = create_tween()
	tween.tween_method(
		_set_challenge_card_position.bind(start, centre), 0.0, 1.0, 0.46
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.finished.connect(_challenge_card_arrived)


func _sync_development_attributes_to_cards() -> void :
	for card_index in player_character_cards.size():
		var mini_index: = _find_mini_for_character_card(card_index)
		if mini_index < 0:
			continue
		var mini_attributes: Array = character_minis_on_board[mini_index].get(
			"development_attributes", []
		).duplicate()
		var card: = player_character_cards[card_index]
		card.development_attributes = mini_attributes
		player_character_cards[card_index] = card


func _challenge_card_arrived() -> void :
	challenge_card_busy = false
	queue_redraw()


func _handle_challenge_card_input(point: Vector2, visible_size: Vector2) -> void :
	if challenge_card_busy or not challenge_card_visible:
		return
	if not _point_is_in_card(
		point, 
		challenge_card_position, 
		challenge_card_rotation, 
		_get_challenge_card_size(visible_size)
	):
		return

	if not challenge_card_face_up:
		_reveal_random_challenge()
	else:
		_start_selected_challenge()


func _reveal_random_challenge() -> void :
	challenge_card_busy = true
	_play_random_flick()
	var tween: = create_tween()
	tween.tween_method(_set_challenge_flip_scale, 1.0, 0.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(_select_random_challenge)
	tween.tween_method(_set_challenge_flip_scale, 0.0, 1.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.finished.connect(_challenge_reveal_finished)


func _select_random_challenge() -> void :
	var challenge_mode: = selected_game_mode
	if selected_game_mode == GameContentMode.HYBRID:
		challenge_mode = [GameContentMode.CFDI, GameContentMode.BFDI].pick_random()
	var challenge_pool
	if challenge_mode == GameContentMode.BFDI: challenge_pool = BFDI_CHALLENGES
	if challenge_mode == GameContentMode.CFDI: challenge_pool = CHALLENGES
	if challenge_mode == GameContentMode.BALDI: challenge_pool = BALDI_CHALLENGES
	var available_challenges: Array[Dictionary] = []
	for challenge in challenge_pool:
		var discard_key: = _get_challenge_discard_key(challenge_mode, challenge)
		if not discarded_challenge_keys.has(discard_key):
			available_challenges.append(challenge)
	if available_challenges.is_empty():
		push_error("No unused challenges remain for %s." % GAME_MODE_NAMES[challenge_mode])
		challenge_card_busy = false
		return
	current_challenge = available_challenges.pick_random().duplicate(true)
	current_challenge.content_mode = challenge_mode
	var unique_attributes: Array[String] = []
	for attribute in current_challenge.get("attributes", []):
		if not unique_attributes.has(attribute):
			unique_attributes.append(attribute)
	current_challenge.attributes = unique_attributes
	challenge_card_face_up = true
	queue_redraw()


func _challenge_reveal_finished() -> void :
	challenge_card_busy = false
	challenge_card_flip_scale = 1.0
	queue_redraw()


func _start_selected_challenge() -> void :
	challenge_card_busy = true
	_play_random_flick()
	var start: = challenge_card_position
	var centre: = to_local(camera_2d.get_screen_center_position())
	var target: = _get_scene_deck_offscreen_position(
		challenge_opener_side, centre, _get_visible_world_size()
	)
	var tween: = create_tween()
	tween.tween_method(
		_set_challenge_card_position.bind(start, target), 0.0, 1.0, 0.42
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.finished.connect(_finish_challenge_card_phase)


func _finish_challenge_card_phase() -> void :
	challenge_card_visible = false
	challenge_card_busy = false
	challenge_phase_active = false
	if not current_challenge.is_empty():
		var challenge_mode: int = current_challenge.get("content_mode", selected_game_mode)
		discarded_challenge_keys[
			_get_challenge_discard_key(challenge_mode, current_challenge)
		] = true
	var saved_attributes: Array[String] = []
	for attribute in current_challenge.get("attributes", []):
		saved_attributes.append(attribute)
	challenge_started.emit(current_challenge.get("name", ""), saved_attributes)
	if not gameplay_music_started:
		gameplay_music_started = true
		_play_music(SHINY_TECH, 0.75)
	_begin_character_movement_phase()
	queue_redraw()


func _get_challenge_discard_key(content_mode: int, challenge: Dictionary) -> String:
	return "%d:%s" % [content_mode, challenge.get("name", "")]


func _draw_challenge_card(visible_size: Vector2) -> void :
	if not challenge_card_visible:
		return
	var card_size: = _get_challenge_card_size(visible_size)
	var card_rect: = Rect2( - card_size * 0.5, card_size)
	draw_set_transform(
		challenge_card_position, 
		challenge_card_rotation, 
		Vector2(challenge_card_flip_scale, 1.0)
	)
	var challenge_mode: int = current_challenge.get("content_mode", selected_game_mode)
	var face_texture: = (
		BFDI_CHALLENGE_CARD
		if challenge_mode == GameContentMode.BFDI
		else CHALLENGE_CARD
	)
	var texture: = face_texture if challenge_card_face_up else CHALLENGE_CARD_BACK
	draw_texture_rect(texture, card_rect, false)

	if challenge_card_face_up and not current_challenge.is_empty():
		_draw_challenge_card_content(card_size)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_challenge_card_content(card_size: Vector2) -> void :
	var challenge_name: String = current_challenge.get("name", "")
	var challenge_font: = _get_content_font(
		current_challenge.get("content_mode", selected_game_mode)
	)
	var font_size: = maxi(18, int(card_size.y * 0.15))
	var text_size: = challenge_font.get_string_size(
		challenge_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size
	)
	var available_text_width: = card_size.x * 0.72
	if text_size.x > available_text_width and text_size.x > 0.0:
		font_size = maxi(
			18, 
			int(float(font_size) * available_text_width / text_size.x)
		)
		text_size = challenge_font.get_string_size(
			challenge_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size
		)
	draw_string(
		challenge_font, 
		Vector2( - text_size.x * 0.5, text_size.y * 0.35), 
		challenge_name, 
		HORIZONTAL_ALIGNMENT_LEFT, 
		-1, 
		font_size, 
		Color.BLACK
	)

	var attributes: Array = current_challenge.get("attributes", [])
	var icon_size: = card_size.y * 0.19
	var icon_gap: = icon_size * 0.12
	var right: = card_size.x * 0.5 - icon_size * 0.75
	var top: = - card_size.y * 0.5 + icon_size * 0.75
	for index in attributes.size():
		var icon: Texture2D = ATTRIBUTE_ICONS[attributes[index]]
		var centre: = Vector2(right - index * (icon_size + icon_gap), top)
		draw_texture_rect(
			icon, 
			Rect2(centre - Vector2.ONE * icon_size * 0.5, Vector2.ONE * icon_size), 
			false
		)


func _get_challenge_card_size(visible_size: Vector2) -> Vector2:
	var texture_size: = CHALLENGE_CARD_BACK.get_size()
	var safe_size: = _get_safe_world_rect(visible_size).size
	var visible_bounds: = Vector2(safe_size.x * 0.9, safe_size.y * 0.86)



	var landscape: = safe_size.x >= safe_size.y
	var short_edge_local_bounds: = (
		Vector2(visible_bounds.y, visible_bounds.x)
		if landscape
		else visible_bounds
	)
	var scale_factor = min(
		short_edge_local_bounds.x / texture_size.x, 
		short_edge_local_bounds.y / texture_size.y
	)
	return texture_size * scale_factor


func _set_challenge_card_position(progress: float, start: Vector2, target: Vector2) -> void :
	challenge_card_position = start.lerp(target, progress)
	queue_redraw()


func _set_challenge_flip_scale(value: float) -> void :
	challenge_card_flip_scale = value
	queue_redraw()


func _begin_character_movement_phase() -> void :
	character_movement_phase_active = true
	current_movement_player_order = 0
	var challenge_attributes: Array = current_challenge.get("attributes", [])
	for index in character_minis_on_board.size():
		var item: = character_minis_on_board[index]
		var character_attributes: Array = _get_character_attributes(item.character_name)
		character_attributes.append_array(item.get("development_attributes", []))
		var match_count: = _count_matching_attributes(character_attributes, challenge_attributes)
		item.matching_attributes = match_count
		item.target_column = min(match_count, BOARD_COLUMNS - 1)
		item.reachable_columns = range(1, item.target_column + 1)
		character_minis_on_board[index] = item
	_advance_to_next_eligible_movement_player()
	queue_redraw()


func _count_matching_attributes(character_attributes: Array, challenge_attributes: Array) -> int:
	var matches: = 0



	for attribute in character_attributes:
		if challenge_attributes.has(attribute):
			matches += 1
	return matches


func _advance_to_next_eligible_movement_player() -> void :
	while current_movement_player_order < player_order.size():
		var side: = player_order[current_movement_player_order]
		if _player_has_unmoved_matching_character(side):
			return
		current_movement_player_order += 1

	character_movement_phase_active = false
	character_movement_finished.emit()
	_begin_card_play_phase()
	queue_redraw()


func _player_has_unmoved_matching_character(side: int) -> bool:
	for item in character_minis_on_board:
		if (item.owner_side == side
			and item.matching_attributes > 0
			and item.current_column != item.target_column):
			return true
	return false


func _handle_character_movement_pointer(
	point: Vector2, 
	pressed: bool, 
	released: bool, 
	visible_size: Vector2, 
	bot_input: bool = false
) -> void :
	if pressed and dragged_mini_index < 0:
		if is_player_bot(_get_current_turn_side()) and not bot_input:
			return
		for index in range(character_minis_on_board.size() - 1, -1, -1):
			var item: = character_minis_on_board[index]
			if item.moving:
				continue
			if _get_character_mini_hit_rect(item, visible_size).has_point(point):
				dragged_mini_index = index
				dragged_mini_original_position = item.position
				dragged_mini_offset = Vector2.ZERO
				item.position = point
				character_minis_on_board[index] = item
				grab.play()
				if dragged_mini_scale_tween != null and dragged_mini_scale_tween.is_valid():
					dragged_mini_scale_tween.kill()
				dragged_mini_scale_tween = create_tween()
				dragged_mini_scale_tween.tween_method(
					_set_character_mini_scale.bind(index), item.visual_scale, 1.28, 0.1
				).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				queue_redraw()
				return

	if released and dragged_mini_index >= 0:
		_finish_character_mini_drag(point, visible_size)


func _finish_character_mini_drag(point: Vector2, visible_size: Vector2) -> void :
	var index: = dragged_mini_index
	var item: = character_minis_on_board[index]
	var current_side: = player_order[current_movement_player_order]
	var valid_drop: = false
	if (item.owner_side == current_side
		and item.matching_attributes > 0
		and item.target_column > 0):
		valid_drop = _get_board_cell_rect(
			item.target_column, item.row, visible_size
		).has_point(point)

	var target: = dragged_mini_original_position
	if valid_drop:
		target = _get_board_cell_centre(item.target_column, item.row, visible_size)



		challenge_indicator_suppressed_mini_index = index
		board_indicator_drop_in_progress = true
	item.moving = true
	character_minis_on_board[index] = item
	dragged_mini_index = -1
	if dragged_mini_scale_tween != null and dragged_mini_scale_tween.is_valid():
		dragged_mini_scale_tween.kill()

	var tween: = create_tween()
	tween.set_parallel(true)
	tween.tween_method(
		_set_character_mini_position.bind(index, item.position, target), 0.0, 1.0, 0.18
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_method(
		_set_character_mini_scale.bind(index), item.visual_scale, 0.86 if valid_drop else 1.0, 0.18
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.finished.connect(_character_mini_drop_impact.bind(index, valid_drop))


func _character_mini_drop_impact(index: int, valid_drop: bool) -> void :
	if not valid_drop:
		_character_mini_drop_finished(index, false)
		return
	place.play()
	var settle_tween: = create_tween()
	settle_tween.tween_method(
		_set_character_mini_scale.bind(index), 0.86, 1.0, 0.09
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	settle_tween.finished.connect(_character_mini_drop_finished.bind(index, true))


func _character_mini_drop_finished(index: int, valid_drop: bool) -> void :
	var item: = character_minis_on_board[index]
	item.moving = false
	item.visual_scale = 1.0
	if valid_drop:
		item.current_column = item.target_column
	character_minis_on_board[index] = item
	if valid_drop:
		challenge_indicator_suppressed_mini_index = -1
		var side: = player_order[current_movement_player_order]
		if not _player_has_unmoved_matching_character(side):
			current_movement_player_order += 1
			_advance_to_next_eligible_movement_player()
		board_indicator_drop_in_progress = false
		_refresh_board_indicators()
	queue_redraw()


func _get_board_cell_rect(column: int, row: int, visible_size: Vector2) -> Rect2:
	var cell_size: = _get_board_cell_size(visible_size)
	return Rect2(_get_board_cell_centre(column, row, visible_size) - cell_size * 0.5, cell_size)


func _refresh_board_indicators() -> void :
	if board_indicator_visual == null:
		return



	if board_indicator_drop_in_progress:
		return
	var visible_size: = _get_visible_world_size()
	var cells: Array[Dictionary] = []
	var seen: Dictionary = {}
	if indicators_enabled and game_has_started and not game_over:
		if character_movement_phase_active or card_play_phase_active:
			_append_bottom_three_danger_indicators(cells, seen, visible_size)
		if character_movement_phase_active:
			_append_challenge_movement_indicators(cells, seen, visible_size)
		elif card_play_phase_active:
			_append_card_play_indicators(cells, seen, visible_size)
	var signature_parts: Array[String] = [
		"%.2f" % visible_size.x, 
		"%.2f" % visible_size.y, 
		"%.2f" % to_local(camera_2d.get_screen_center_position()).x, 
		"%.2f" % to_local(camera_2d.get_screen_center_position()).y, 
	]
	for cell in cells:
		signature_parts.append("%s:%s" % [cell.key, cell.colour.to_html(true)])
	board_indicator_visual.set_indicators(cells, "|".join(signature_parts))


func _append_bottom_three_danger_indicators(
	cells: Array[Dictionary], 
	seen: Dictionary, 
	visible_size: Vector2
) -> void :
	if character_minis_on_board.is_empty():
		return
	var ranked_indices: Array[int] = []
	for mini_index in character_minis_on_board.size():
		ranked_indices.append(mini_index)


	ranked_indices.sort_custom( func(a: int, b: int) -> bool:
		var a_mini: = character_minis_on_board[a]
		var b_mini: = character_minis_on_board[b]
		if a_mini.current_column != b_mini.current_column:
			return a_mini.current_column > b_mini.current_column
		return a_mini.row < b_mini.row
	)
	var danger_count: = mini(3, ranked_indices.size())
	for rank_index in range(ranked_indices.size() - danger_count, ranked_indices.size()):
		var danger_mini: = character_minis_on_board[ranked_indices[rank_index]]
		_append_indicator_cell(
			cells, seen, 
			danger_mini.current_column, 
			danger_mini.row, 
			ELIMINATION_DANGER_RED, 
			"danger", 
			visible_size, 
			DANGER_INDICATOR_PRIORITY
		)


func _append_challenge_movement_indicators(
	cells: Array[Dictionary], 
	seen: Dictionary, 
	visible_size: Vector2
) -> void :
	if current_movement_player_order < 0 or current_movement_player_order >= player_order.size():
		return
	var side: = player_order[current_movement_player_order]
	for mini_index in character_minis_on_board.size():
		var mini: = character_minis_on_board[mini_index]
		if (mini.owner_side != side
			or mini_index == challenge_indicator_suppressed_mini_index
			or mini.get("matching_attributes", 0) <= 0
			or mini.current_column >= mini.get("target_column", mini.current_column)):
			continue
		_append_indicator_path(
			cells, 
			seen, 
			mini.current_column, 
			mini.row, 
			mini.target_column - mini.current_column, 
			MOVE_INDICATOR_GREEN, 
			"move", 
			visible_size
		)


func _append_card_play_indicators(
	cells: Array[Dictionary], 
	seen: Dictionary, 
	visible_size: Vector2
) -> void :


	if (pending_effect_move_active
		and alliance_target_character_index < 0
		and not swap_drag_active
		and pending_effect_mini_index >= 0
		and pending_effect_mini_index < character_minis_on_board.size()):
		var development_mini: = character_minis_on_board[pending_effect_mini_index]
		var development_steps: = maxi(
			pending_effect_target_column - development_mini.current_column, 
			0
		)
		_append_indicator_path(
			cells, seen, 
			development_mini.current_column, 
			development_mini.row, 
			development_steps, 
			MOVE_INDICATOR_GREEN, 
			"development_move", 
			visible_size
		)
		return



	if swap_drag_active and pending_effect_mini_index >= 0:
		if pending_effect_mini_index >= character_minis_on_board.size():
			return
		var swap_source: = character_minis_on_board[pending_effect_mini_index]
		_append_indicator_cell(
			cells, seen, swap_source.current_column, swap_source.row, 
			MOVE_INDICATOR_GREEN, "swap_source", visible_size
		)
		for index in character_minis_on_board.size():
			if index == pending_effect_mini_index:
				continue
			var candidate: = character_minis_on_board[index]
			if candidate.current_column == swap_source.current_column:
				_append_indicator_cell(
					cells, seen, candidate.current_column, candidate.row, 
					SWAP_INDICATOR_PURPLE, "swap_target", visible_size
				)
		return



	if die_roll_active and pending_boost_character_index >= 0:
		var rolling_mini_index: = _find_mini_for_character_card(pending_boost_character_index)
		if rolling_mini_index >= 0 and rolling_mini_index < character_minis_on_board.size():
			var rolling_mini: = character_minis_on_board[rolling_mini_index]
			_append_indicator_cell(
				cells, seen, rolling_mini.current_column, rolling_mini.row, 
				MOVE_INDICATOR_GREEN, "boost_source", visible_size
			)

	if alliance_target_mini_index < 0 or alliance_target_mini_index >= character_minis_on_board.size():
		return



	if not alliance_main_move_done:
		var main_mini: = character_minis_on_board[alliance_target_mini_index]
		var main_path_colour: = (
			WAITING_INDICATOR_ORANGE
			if _alliance_movement_is_locked()
			else MOVE_INDICATOR_GREEN
		)
		_append_indicator_path(
			cells, seen, main_mini.current_column, main_mini.row, 
			alliance_move_amount, main_path_colour, "boost", visible_size
		)





	var ally_path_colour: = (
		WAITING_INDICATOR_ORANGE
		if _alliance_movement_is_locked()
		else ALLIANCE_INDICATOR_BLUE
	)
	var selected_ally_side: = -1
	if (pending_effect_mini_index >= 0
		and pending_effect_mini_index < character_minis_on_board.size()):
		var selected_mini: = character_minis_on_board[pending_effect_mini_index]
		if (selected_mini.owner_side in alliance_accepted_sides
			and selected_mini.owner_side != alliance_active_side):
			selected_ally_side = selected_mini.owner_side
			_append_indicator_path(
				cells, seen, selected_mini.current_column, selected_mini.row, 
				alliance_move_amount, ally_path_colour, 
				"alliance_path", visible_size
			)

	for ally_side in alliance_accepted_sides:
		if ally_side in alliance_moved_sides or ally_side == selected_ally_side:
			continue
		for mini in character_minis_on_board:
			if (mini.owner_side == ally_side
				and mini.current_column == alliance_origin_column
				and mini.current_column < BOARD_COLUMNS - 1):
				_append_indicator_path(
					cells, seen, mini.current_column, mini.row, 
					alliance_move_amount, ally_path_colour, 
					"alliance_choice", visible_size
				)


func _append_indicator_path(
	cells: Array[Dictionary], 
	seen: Dictionary, 
	start_column: int, 
	row: int, 
	amount: int, 
	colour: Color, 
	key_prefix: String, 
	visible_size: Vector2
) -> void :
	var end_column: = mini(start_column + maxi(amount, 0), BOARD_COLUMNS - 1)
	for column in range(start_column, end_column + 1):
		_append_indicator_cell(
			cells, seen, column, row, colour, key_prefix, visible_size
		)


func _append_indicator_cell(
	cells: Array[Dictionary], 
	seen: Dictionary, 
	column: int, 
	row: int, 
	colour: Color, 
	key_prefix: String, 
	visible_size: Vector2, 
	priority: int = ACTION_INDICATOR_PRIORITY
) -> void :
	if column < 0 or column >= BOARD_COLUMNS or row < 0 or row >= BOARD_ROWS:
		return


	var key: = "cell:%d:%d" % [column, row]
	if seen.has(key):
		var existing: Dictionary = seen[key]
		if priority < int(existing.priority):
			return
		cells.remove_at(int(existing.index))

		for seen_key in seen.keys():
			var stored: Dictionary = seen[seen_key]
			if int(stored.index) > int(existing.index):
				stored.index = int(stored.index) - 1
				seen[seen_key] = stored
	var cell_index: = cells.size()
	seen[key] = {"index": cell_index, "priority": priority}
	var rect: = _get_board_cell_rect(column, row, visible_size)
	var corner_radius: = minf(rect.size.x * 0.5, rect.size.y * 0.5)
	cells.append({
		"key": key, 
		"source": key_prefix, 
		"rect": rect, 
		"colour": colour, 
		"round_top": row == 0, 
		"round_bottom": row == BOARD_ROWS - 1, 
		"corner_radius": corner_radius, 
	})


func _get_character_mini_size(item: Dictionary, visible_size: Vector2) -> Vector2:
	var texture: Texture2D = item.texture
	var shared_scale: = _get_character_mini_shared_scale(_get_board_cell_size(visible_size))
	return texture.get_size() * shared_scale * item.visual_scale


func _get_character_mini_hit_rect(item: Dictionary, visible_size: Vector2) -> Rect2:
	var cell_size: = _get_board_cell_size(visible_size)
	return Rect2(item.position - cell_size * 0.5, cell_size)


func _begin_card_play_phase() -> void :
	card_play_phase_active = true
	card_turn_serial += 1
	current_card_player_order = 0
	while (current_card_player_order < player_order.size()
		and eliminated_players[player_order[current_card_player_order]]):
		current_card_player_order += 1
	if current_card_player_order >= player_order.size():
		current_card_player_order = 0
	consecutive_passes = 0
	card_effect_busy = false
	card_turn_action_committed = false
	swap_source_character_index = -1
	_check_scene_offer_for_current_turn()
	queue_redraw()


func _handle_card_play_phase_press(point: Vector2, visible_size: Vector2) -> bool:
	if is_player_bot(_get_current_turn_side()):
		return false
	if die_roll_active:
		if ( not die_roll_busy
			and _point_is_in_card(point, die_position, die_rotation, _get_die_size(visible_size))):
			_roll_die()
		return true

	var current_side: = _get_current_turn_side()
	var centre: = to_local(camera_2d.get_screen_center_position())
	var button_position: = _get_player_position(current_side, centre, visible_size)
	button_position += _get_player_right_offset(current_side, visible_size) * player_number_slide
	if point.distance_to(button_position) <= _get_player_button_radius(visible_size, current_side):
		_pass_card_turn()
		return true

	if _should_show_scene_card_offer(current_side):
		var offer_position: = _get_scene_offer_position(current_side, visible_size)
		if point.distance_to(offer_position) <= _get_player_button_radius(visible_size, current_side) + 4.0:
			_try_buy_scene_card(current_side)
			return true
	return false


func _finish_scene_card_play_drag(point: Vector2, visible_size: Vector2) -> void :
	var card_index: = dragged_scene_play_index
	var side: = _get_current_turn_side()
	var player_delta: = (point - hand_swipe_start).rotated( - _get_player_rotation(side))
	var swipe_threshold_ratio: = 0.035 if _is_phone_layout(visible_size) else 0.055
	var swipe_threshold = min(visible_size.x, visible_size.y) * swipe_threshold_ratio
	var target_character: = highlighted_character_card_index
	var valid_play: = (target_character >= 0
		and _is_scene_card_legal_for_character(card_index, target_character))

	if dragged_scene_card_visual != null:
		dragged_scene_card_visual.hide_card()
	dragged_scene_play_index = -1
	highlighted_character_card_index = -1
	hand_swipe_active = false
	if valid_play:
		_play_scene_card(card_index, target_character)
		return

	var card: = dealt_scene_cards[card_index]
	var current_position: Vector2 = card.position
	card.position = dragged_scene_play_start
	dealt_scene_cards[card_index] = card
	if player_delta.x <= - swipe_threshold:
		var indices: = _get_owner_scene_card_indices(side)
		if indices.size() > 1 and not scene_cycle_busy[side]:
			_animate_hand_cycle(side, true, indices.size())
	elif not scene_card_drag_moved:
		_flip_dealt_scene_card(card_index)
	else:
		var tween: = create_tween()
		tween.tween_method(
			_set_dealt_card_position_direct.bind(card_index, current_position, dragged_scene_play_start), 
			0.0, 1.0, 0.18
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	queue_redraw()


func _set_dealt_card_position_direct(progress: float, index: int, start: Vector2, target: Vector2) -> void :
	if index >= dealt_scene_cards.size():
		return
	var card: = dealt_scene_cards[index]
	card.position = start.lerp(target, progress)
	dealt_scene_cards[index] = card
	queue_redraw()


func _find_character_card_at_point(point: Vector2, visible_size: Vector2) -> int:
	var best_index: = -1
	var best_depth: = - INF
	for index in player_character_cards.size():
		var card: = player_character_cards[index]
		var size = _get_character_draft_card_size(visible_size) * card.scale
		if _point_is_in_card(point, card.position, card.rotation, size):
			var local_x: float = card.position.rotated( - card.rotation).x
			if local_x > best_depth:
				best_depth = local_x
				best_index = index
	return best_index


func _get_character_name_from_card(index: int) -> String:
	var texture: Texture2D = player_character_cards[index].texture
	return _get_character_name_for_texture(texture)


func _find_mini_for_character_card(index: int) -> int:
	var name: = _get_character_name_from_card(index)
	for mini_index in character_minis_on_board.size():
		if character_minis_on_board[mini_index].character_name == name:
			return mini_index
	return -1


func _get_scene_card_kind(texture: Texture2D) -> String:
	if texture in [BOOST_CARD, BFDI_BOOST_CARD]:
		return "boost"
	if texture == SWAP_CARD:
		return "swap"
	if texture in [WIN_TOKEN_CARD, BFDI_WIN_TOKEN_CARD]:
		return "win_token"
	if texture in [ACTIVE_SPECIAL_BOOST_CARD, ANGER_SPECIAL_BOOST_CARD, NICE_SPECIAL_BOOST_CARD, SELFISH_SPECIAL_BOOST_CARD, SMART_SPECIAL_BOOST_CARD]:
		return "special_boost"
	if texture in [
		ACTIVE_DEVELOPMENT_CARD, 
		ANGER_DEVELOPMENT_CARD, 
		NICE_DEVELOPMENT_CARD, 
		SELFISH_DEVELOPMENT_CARD, 
		SMART_DEVELOPMENT_CARD, 
		BFDI_ACTIVE_DEVELOPMENT_CARD, 
		BFDI_ANGER_DEVELOPMENT_CARD, 
		BFDI_NICE_DEVELOPMENT_CARD, 
		BFDI_SELFISH_DEVELOPMENT_CARD, 
		BFDI_SMART_DEVELOPMENT_CARD, 
	]:
		return "development"
	return "unknown"


func _get_scene_card_attribute(texture: Texture2D) -> String:
	if texture in [ACTIVE_SPECIAL_BOOST_CARD, ACTIVE_DEVELOPMENT_CARD, BFDI_ACTIVE_DEVELOPMENT_CARD]:
		return ATTRIBUTE_ACTIVE
	if texture in [ANGER_SPECIAL_BOOST_CARD, ANGER_DEVELOPMENT_CARD, BFDI_ANGER_DEVELOPMENT_CARD]:
		return ATTRIBUTE_ANGRY
	if texture in [NICE_SPECIAL_BOOST_CARD, NICE_DEVELOPMENT_CARD, BFDI_NICE_DEVELOPMENT_CARD]:
		return ATTRIBUTE_NICE
	if texture in [SELFISH_SPECIAL_BOOST_CARD, SELFISH_DEVELOPMENT_CARD, BFDI_SELFISH_DEVELOPMENT_CARD]:
		return ATTRIBUTE_SELFISH
	if texture in [SMART_SPECIAL_BOOST_CARD, SMART_DEVELOPMENT_CARD, BFDI_SMART_DEVELOPMENT_CARD]:
		return ATTRIBUTE_SMART
	return ""


func _is_scene_card_legal_for_character(card_index: int, character_index: int) -> bool:
	if card_index < 0 or card_index >= dealt_scene_cards.size():
		return false
	var mini_index: = _find_mini_for_character_card(character_index)
	if mini_index < 0:
		return false
	var mini: = character_minis_on_board[mini_index]
	var texture: Texture2D = dealt_scene_cards[card_index].texture
	match _get_scene_card_kind(texture):
		"boost":
			return mini.current_column < BOARD_COLUMNS - 1
		"special_boost":
			return (mini.current_column < BOARD_COLUMNS - 1
				and current_challenge.get("attributes", []).has(_get_scene_card_attribute(texture)))
		"development":
			return true
		"swap":
			return _count_minis_in_column(mini.current_column) > 1
		"win_token":
			return not mini.get("has_win_token", false)
	return false


func _count_minis_in_column(column: int) -> int:
	var count: = 0
	for mini in character_minis_on_board:
		if mini.current_column == column:
			count += 1
	return count


func _player_has_legal_scene_card(side: int) -> bool:
	for card_index in _get_owner_scene_card_indices(side):
		for character_index in player_character_cards.size():
			if _is_scene_card_legal_for_character(card_index, character_index):
				return true
	return false


func _should_show_scene_card_offer(side: int) -> bool:
	return (card_play_phase_active
		and side == _get_current_turn_side()
		and not card_effect_busy
		and _get_owner_star_count(side) >= 3)


func _check_scene_offer_for_current_turn() -> void :
	turn_scene_offer_visible = false
	if card_play_phase_active and current_card_player_order < player_order.size():
		turn_scene_offer_visible = not _player_has_legal_scene_card(_get_current_turn_side())


func _try_buy_scene_card(side: int) -> void :
	if card_effect_busy:
		return
	var owned_star_indices: Array[int] = []
	for index in player_stars.size():
		if player_stars[index].owner_side == side:
			owned_star_indices.append(index)
	if owned_star_indices.size() < 3:
		return
	card_effect_busy = true
	turn_scene_offer_visible = false
	var spent: Array[int] = [owned_star_indices[0], owned_star_indices[1], owned_star_indices[2]]
	star.play()
	var spend_tween: = create_tween()
	spend_tween.tween_method(_set_spent_stars_visual.bind(spent), 0.0, 1.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await spend_tween.finished
	for offset in range(2, -1, -1):
		player_stars.remove_at(owned_star_indices[offset])
	for index in player_stars.size():
		if player_stars[index].owner_side == side:
			var remaining: = player_stars[index]
			remaining.visual_scale = 1.0
			remaining.alpha = 1.0
			player_stars[index] = remaining
	_refresh_player_star_stack(side, true)
	var owner_indices: = _get_owner_scene_card_indices(side)
	var position: = _get_scene_offer_position(side, _get_visible_world_size())
	dealt_scene_cards.append({
		"owner_side": side, 
		"owner_slot": owner_indices.size(), 
		"card_number": _take_next_scene_card_number(side), 
		"texture": _draw_scene_card_for_side(side), 
		"revealed": false, 
		"position": position, 
		"rotation": _get_player_rotation(side), 
		"flip_scale": 1.0, 
		"deal_scale": _get_dealt_scene_card_scale(_get_visible_world_size(), side, owner_indices.size() + 1), 
		"moving": true, 
		"incoming_purchase": true, 
		"flipping": false, 
	})
	var purchased_index: = dealt_scene_cards.size() - 1
	scene_cycle_indices[side] = owner_indices.size()
	_refresh_scene_hands_preserving_order()
	var purchase_reflow: = scene_hand_reflow_tween
	if purchase_reflow != null and purchase_reflow.is_valid():
		await purchase_reflow.finished
	if purchased_index >= 0 and purchased_index < dealt_scene_cards.size():
		var purchased: = dealt_scene_cards[purchased_index]
		purchased.moving = false
		purchased.incoming_purchase = false
		dealt_scene_cards[purchased_index] = purchased
	card_effect_busy = false
	queue_redraw()


func _set_spent_stars_visual(progress: float, indices: Array[int]) -> void :
	for index in indices:
		if index < 0 or index >= player_stars.size():
			continue
		var item: = player_stars[index]
		item.visual_scale = lerp(1.0, 0.0, progress)
		item.alpha = 1.0 - progress
		player_stars[index] = item
	queue_redraw()


func _play_scene_card(card_index: int, character_index: int) -> void :
	card_effect_busy = true
	card_turn_action_committed = true
	consecutive_passes = 0
	var card: = dealt_scene_cards[card_index]
	var texture: Texture2D = card.texture
	card_being_used_index = card_index
	card.use_scale = 1.0
	card.use_alpha = 1.0
	card.use_rotation = 0.0
	card.use_offset = Vector2.ZERO
	dealt_scene_cards[card_index] = card
	_play_random_flick()
	var tween: = create_tween()
	tween.tween_method(
		_set_used_scene_card_expand_fade.bind(card_index), 0.0, 1.0, 0.2
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tween.finished
	dealt_scene_cards.remove_at(card_index)
	card_being_used_index = -1
	_refresh_scene_hands_preserving_order(true)
	match _get_scene_card_kind(texture):
		"boost":
			_begin_die_roll(character_index)
		"special_boost":
			_begin_boost_alliance(character_index, 3)
		"development":
			var attribute: = _get_scene_card_attribute(texture)
			_apply_development_card(character_index, attribute)
			var mini_index: = _find_mini_for_character_card(character_index)
			if (current_challenge.get("attributes", []).has(attribute)
				and mini_index >= 0
				and character_minis_on_board[mini_index].current_column < BOARD_COLUMNS - 1):
				_begin_effect_mini_move(character_index, 1)
			else:
				_finish_played_card_effect()
		"swap":
			swap_source_character_index = character_index
			_begin_swap_drag(character_index)
		"win_token":
			_apply_win_token(character_index)
			_finish_played_card_effect()


func _set_used_scene_card_expand_fade(progress: float, index: int) -> void :
	if index < 0 or index >= dealt_scene_cards.size():
		return
	var card: = dealt_scene_cards[index]
	card.use_scale = lerp(1.0, 1.35, progress)
	card.use_alpha = clampf(1.0 - progress, 0.0, 1.0)
	dealt_scene_cards[index] = card
	queue_redraw()


func _refresh_scene_hands_preserving_order(
	preserve_existing_scale: bool = false, 
	animate: bool = true, 
	refresh_character_layout: bool = true
) -> void :
	var visible_size: = _get_visible_world_size()
	if scene_hand_reflow_tween != null and scene_hand_reflow_tween.is_valid():
		scene_hand_reflow_tween.kill()
	scene_hand_reflow_tween = null
	for side in 4:
		var indices: = _get_owner_scene_card_indices(side)
		if indices.is_empty():
			scene_cycle_indices[side] = 0
			continue
		var rotation: = _get_player_rotation(side)
		indices.sort_custom( func(a: int, b: int) -> bool:
			var a_x: float = dealt_scene_cards[a].position.rotated( - rotation).x
			var b_x: float = dealt_scene_cards[b].position.rotated( - rotation).x
			return a_x < b_x
		)
		var scale: = _get_dealt_scene_card_scale(visible_size, side, indices.size())
		for slot in indices.size():
			var index: = indices[slot]
			var card: = dealt_scene_cards[index]
			var target: = _get_dealt_scene_card_position(
				side, slot, indices.size(), visible_size
			)
			var target_scale: float = card.deal_scale if preserve_existing_scale else scale
			card.rotation = rotation
			dealt_scene_cards[index] = card
			if (animate
				and ( not card.position.is_equal_approx(target)
				or not is_equal_approx(card.deal_scale, target_scale))):
				if scene_hand_reflow_tween == null:
					scene_hand_reflow_tween = create_tween()
					scene_hand_reflow_tween.set_parallel(true)
				scene_hand_reflow_tween.tween_method(
					_set_existing_card_layout.bind(
						index, 
						card.position, 
						target, 
						card.deal_scale, 
						target_scale
					), 
					0.0, 
					1.0, 
					0.22
				).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			else:
				card.position = target
				card.deal_scale = target_scale
				dealt_scene_cards[index] = card
		var owner_indices: = _get_owner_scene_card_indices(side)
		scene_cycle_indices[side] = owner_indices.find(indices.back())
	queue_redraw()
	if refresh_character_layout:
		_refresh_character_hands_preserving_order(animate)


func _apply_development_card(character_index: int, attribute: String) -> void :
	var card: = player_character_cards[character_index]
	var developments: Array = card.get("development_attributes", [])
	developments.append(attribute)
	card.development_attributes = developments
	player_character_cards[character_index] = card
	var mini_index: = _find_mini_for_character_card(character_index)
	if mini_index >= 0:
		var mini: = character_minis_on_board[mini_index]
		var extras: Array = mini.get("development_attributes", [])
		extras.append(attribute)
		mini.development_attributes = extras
		character_minis_on_board[mini_index] = mini


func _apply_win_token(character_index: int) -> void :
	var mini_index: = _find_mini_for_character_card(character_index)
	if mini_index >= 0:
		var mini: = character_minis_on_board[mini_index]
		mini.has_win_token = true
		character_minis_on_board[mini_index] = mini


func _move_character_by_columns(character_index: int, amount: int, finish_turn: bool) -> void :
	var mini_index: = _find_mini_for_character_card(character_index)
	if mini_index < 0:
		if finish_turn:
			_finish_played_card_effect()
		return
	var mini: = character_minis_on_board[mini_index]
	var target_column = min(mini.current_column + amount, BOARD_COLUMNS - 1)
	var start: Vector2 = mini.position
	var target: = _get_board_cell_centre(target_column, mini.row, _get_visible_world_size())
	mini.moving = true
	character_minis_on_board[mini_index] = mini
	var tween: = create_tween()
	tween.tween_method(
		_set_character_mini_position.bind(mini_index, start, target), 0.0, 1.0, 0.3
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished
	mini = character_minis_on_board[mini_index]
	mini.current_column = target_column
	mini.moving = false
	character_minis_on_board[mini_index] = mini
	place.play()
	if finish_turn:
		_finish_played_card_effect()


func _begin_effect_mini_move(character_index: int, amount: int) -> void :
	pending_effect_mini_index = _find_mini_for_character_card(character_index)
	if pending_effect_mini_index < 0:
		_finish_played_card_effect()
		return
	var mini: = character_minis_on_board[pending_effect_mini_index]
	pending_effect_target_column = min(mini.current_column + amount, BOARD_COLUMNS - 1)
	pending_effect_target_row = mini.row
	pending_effect_move_active = true
	queue_redraw()


func _begin_boost_alliance(character_index: int, amount: int) -> void :

	pending_effect_move_active = false
	pending_effect_mini_index = -1
	pending_effect_target_column = -1
	pending_effect_target_row = -1
	alliance_target_character_index = character_index
	alliance_target_mini_index = _find_mini_for_character_card(character_index)
	if alliance_target_mini_index < 0:
		_finish_played_card_effect()
		return
	var mini: = character_minis_on_board[alliance_target_mini_index]
	alliance_origin_column = mini.current_column
	alliance_move_amount = amount
	alliance_active_side = _get_current_turn_side()
	alliance_offer_side = -1
	alliance_offer_stars = 0
	alliance_accepted_sides.clear()
	alliance_move_queue.clear()
	alliance_moved_sides.clear()
	_stop_alliance_star_layout()
	alliance_offered_star_items.clear()
	alliance_current_move_side = alliance_active_side
	alliance_main_move_done = false
	alliance_phase_active = true
	_invalidate_alliance_eligibility()
	alliance_movement_unlock_time = (
		Time.get_ticks_msec() + 3000
		if _has_any_eligible_alliance_offerer()
		else Time.get_ticks_msec()
	)
	queue_redraw()


func _is_player_eligible_to_offer_alliance(side: int) -> bool:
	if ( not alliance_phase_active
		or alliance_star_transfer_busy
		or side == alliance_active_side
		or eliminated_players[side]
		or side in alliance_accepted_sides
		or (alliance_offer_side >= 0 and alliance_offer_side != side)
		or _get_owner_star_count(side) <= 0
		or alliance_target_mini_index < 0
		or alliance_target_mini_index >= character_minis_on_board.size()):
		return false
	var target: = character_minis_on_board[alliance_target_mini_index]
	if target.owner_side == side:
		return false
	for mini in character_minis_on_board:
		if mini.owner_side == side and mini.current_column == alliance_origin_column:
			return true
	return false


func _has_any_eligible_alliance_offerer() -> bool:
	for side in player_order:
		if _is_player_eligible_to_offer_alliance(side):
			return true
	return false


func _alliance_movement_is_locked() -> bool:



	return (alliance_star_transfer_busy
		or alliance_offer_side >= 0
		or Time.get_ticks_msec() < alliance_movement_unlock_time)


func _player_is_waiting_for_alliance_move(side: int) -> bool:
	if ( not alliance_phase_active
		or alliance_offer_side >= 0
		or Time.get_ticks_msec() >= alliance_movement_unlock_time):
		return false
	if side == alliance_active_side and not alliance_main_move_done:
		return true
	return (side in alliance_accepted_sides
		and side not in alliance_moved_sides)


func _get_alliance_accept_position(visible_size: Vector2) -> Vector2:
	var centre: = to_local(camera_2d.get_screen_center_position())
	var edge: = _get_player_position(alliance_active_side, centre, visible_size)
	edge += _get_player_right_offset(alliance_active_side, visible_size) * player_number_slide
	var accept_radius: = _get_player_button_radius(visible_size, alliance_active_side)
	var clearance: = (
		_get_player_button_radius(visible_size, alliance_active_side)
		+ accept_radius
		+ 18.0
	)
	return edge + Vector2(0.0, - clearance).rotated(_get_player_rotation(alliance_active_side))


func _draw_alliance_offer(visible_size: Vector2) -> void :
	if not alliance_phase_active or alliance_offer_side < 0:
		return
	var position: = _get_alliance_accept_position(visible_size)
	var radius: = _get_player_button_radius(visible_size, alliance_active_side)
	var context_scale: = radius / PLAYER_BUTTON_RADIUS
	var font_size: = int(40.0 * context_scale)
	draw_set_transform(position, _get_player_rotation(alliance_active_side), Vector2.ONE)
	draw_circle(Vector2.ZERO, radius, Color("#1e90ff"))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color.WHITE, _get_action_button_outline_width(visible_size, alliance_active_side), true)
	var alliance_font: = _get_player_font(alliance_active_side)
	var text_size: = alliance_font.get_string_size("+", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(alliance_font, Vector2( - text_size.x * 0.5, text_size.y * 0.15), "+", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _point_hits_player_stars(point: Vector2, side: int, visible_size: Vector2) -> bool:
	if _get_owner_star_count(side) <= 0:
		return false
	var count: = _get_owner_star_count(side)
	var size: = _get_player_star_size(visible_size)
	for slot in count:
		var position: = _get_player_star_position(side, visible_size, slot, count)
		if Rect2(position - size * 0.5, size).has_point(point):
			return true
	return false


func _point_hits_player_button(point: Vector2, side: int, visible_size: Vector2) -> bool:
	var centre: = to_local(camera_2d.get_screen_center_position())
	var button_position: = _get_player_position(side, centre, visible_size)
	button_position += _get_player_right_offset(side, visible_size) * player_number_slide
	return point.distance_to(button_position) <= _get_player_button_radius(visible_size, side)


func _handle_alliance_press(point: Vector2, visible_size: Vector2, bot_input: bool = false) -> bool:
	if alliance_offer_side >= 0:
		if (point.distance_to(_get_alliance_accept_position(visible_size))
			<= _get_player_button_radius(visible_size, alliance_active_side)
			and (bot_input or not is_player_bot(alliance_active_side))):
			_accept_alliance_offer()
			return true
		var centre: = to_local(camera_2d.get_screen_center_position())
		var player_position: = _get_player_position(alliance_active_side, centre, visible_size)
		player_position += _get_player_right_offset(alliance_active_side, visible_size) * player_number_slide
		if (point.distance_to(player_position) <= _get_player_button_radius(visible_size, alliance_active_side)
			and (bot_input or not is_player_bot(alliance_active_side))):
			_reject_alliance_offer()
			return true
		var offerer_pressed_button: = _point_hits_player_button(
			point, alliance_offer_side, visible_size
		)
		if (_is_player_eligible_to_offer_alliance(alliance_offer_side)
			and (bot_input or not is_player_bot(alliance_offer_side))
			and (_point_hits_player_stars(point, alliance_offer_side, visible_size)
				or offerer_pressed_button)):
			if offerer_pressed_button:
				_animate_player_button(alliance_offer_side)
			_add_star_to_alliance_offer(alliance_offer_side)
			return true
		return true
	for side in player_order:
		var pressed_offer_button: = _point_hits_player_button(point, side, visible_size)
		if (_is_player_eligible_to_offer_alliance(side)
			and (bot_input or not is_player_bot(side))
			and (_point_hits_player_stars(point, side, visible_size)
				or pressed_offer_button)):
			if pressed_offer_button:
				_animate_player_button(side)
			_add_star_to_alliance_offer(side)
			return true
	var movable_index: = _find_alliance_movable_mini_at_point(point, visible_size)
	if movable_index >= 0:



		var controller_side: = _get_effect_move_controller_side(movable_index)
		if is_player_bot(controller_side) and not bot_input:
			return true
		if not is_player_bot(controller_side) and bot_input:
			return true
		_start_alliance_move(movable_index, point, visible_size, bot_input)
		return true
	return false


func _add_star_to_alliance_offer(side: int) -> void :
	for index in range(player_stars.size() - 1, -1, -1):
		if player_stars[index].owner_side == side:
			var start: Vector2 = player_stars[index].position
			player_stars.remove_at(index)
			alliance_offer_side = side
			alliance_offer_stars += 1



			alliance_movement_unlock_time = Time.get_ticks_msec() + 3000
			_invalidate_alliance_eligibility()
			alliance_offered_star_items.append({
				"position": start, 
				"owner_side": side, 
				"travel_scale": 1.0, 
				"travel_rotation": _get_player_rotation(side), 
			})
			var offered_count: = alliance_offered_star_items.size()
			var centre: = to_local(camera_2d.get_screen_center_position())
			var visible_size: = _get_visible_world_size()
			var centre_ratio = (
				_get_centre_star_size(visible_size).x
				/ max(_get_player_star_size(visible_size).x, 1.0)
			)
			var spacing: = _get_player_star_size(visible_size).x * 0.42
			if alliance_star_layout_tween != null and alliance_star_layout_tween.is_valid():
				alliance_star_layout_tween.kill()
			alliance_star_layout_tween = create_tween()
			alliance_star_layout_tween.set_parallel(true)
			for layout_index in offered_count:
				var layout_item: = alliance_offered_star_items[layout_index]
				var layout_start: Vector2 = layout_item.position
				var layout_target: = centre + Vector2(
					(layout_index - (offered_count - 1) * 0.5) * spacing, 
					0.0
				)
				var start_scale: float = layout_item.get("travel_scale", 1.0)
				var start_rotation: float = layout_item.get(
					"travel_rotation", _get_player_rotation(layout_item.owner_side)
				)
				alliance_star_layout_tween.tween_method(
					_set_alliance_star_layout.bind(
						layout_index, 
						layout_start, 
						layout_target, 
						start_scale, 
						centre_ratio, 
						start_rotation, 
						0.0
					), 
					0.0, 
					1.0, 
					0.28
				).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			star.play()
			_refresh_player_star_stack(side)
			queue_redraw()
			return


func _reject_alliance_offer() -> void :
	if alliance_star_transfer_busy:
		return

	if alliance_active_side >= 0 and alliance_active_side < player_button_scales.size():
		_animate_player_button(alliance_active_side)
	alliance_star_transfer_busy = true
	alliance_phase_active = false
	_invalidate_alliance_eligibility()
	var side: = alliance_offer_side
	var amount: = alliance_offer_stars
	alliance_offer_side = -1
	alliance_offer_stars = 0
	_stop_alliance_star_layout()
	alliance_offered_star_items.clear()
	if side >= 0 and amount > 0:
		await _award_stars(side, amount)
	alliance_star_transfer_busy = false
	_reopen_alliance_offers()


func _accept_alliance_offer() -> void :
	if alliance_star_transfer_busy:
		return
	alliance_star_transfer_busy = true
	alliance_phase_active = false
	_invalidate_alliance_eligibility()
	var side: = alliance_offer_side
	var amount: = alliance_offer_stars
	alliance_offer_side = -1
	alliance_offer_stars = 0
	_stop_alliance_star_layout()
	alliance_offered_star_items.clear()
	if side >= 0:
		alliance_accepted_sides.append(side)
	if amount > 0:
		await _award_stars(alliance_active_side, amount)
	alliance_star_transfer_busy = false
	_reopen_alliance_offers()


func _reopen_alliance_offers() -> void :
	alliance_offer_side = -1
	alliance_offer_stars = 0
	_stop_alliance_star_layout()
	alliance_offered_star_items.clear()
	if (alliance_target_mini_index >= 0
		and alliance_target_mini_index < character_minis_on_board.size()
		and not pending_effect_move_active):
		alliance_phase_active = true
	_invalidate_alliance_eligibility()
	alliance_movement_unlock_time = (
		Time.get_ticks_msec() + 3000
		if _has_any_eligible_alliance_offerer()
		else Time.get_ticks_msec()
	)
	queue_redraw()


func _find_alliance_movable_mini_at_point(point: Vector2, visible_size: Vector2) -> int:
	if _alliance_movement_is_locked():
		return -1
	for index in range(character_minis_on_board.size() - 1, -1, -1):
		var mini: = character_minis_on_board[index]
		var allowed: = (index == alliance_target_mini_index and not alliance_main_move_done)
		if (mini.owner_side in alliance_accepted_sides
			and mini.owner_side not in alliance_moved_sides
			and mini.current_column == alliance_origin_column):
			allowed = true
		if not allowed or mini.current_column >= BOARD_COLUMNS - 1:
			continue
		if _get_character_mini_hit_rect(mini, visible_size).has_point(point):
			return index
	return -1


func _start_alliance_move(mini_index: int, point: Vector2, visible_size: Vector2, bot_input: bool = false) -> void :
	if effect_move_animation_busy or _alliance_movement_is_locked():
		return
	alliance_phase_active = false
	_invalidate_alliance_eligibility()
	pending_effect_mini_index = mini_index
	var mini: = character_minis_on_board[pending_effect_mini_index]
	alliance_current_move_side = alliance_active_side if mini_index == alliance_target_mini_index else mini.owner_side
	pending_effect_target_column = min(mini.current_column + alliance_move_amount, BOARD_COLUMNS - 1)
	pending_effect_target_row = mini.row
	pending_effect_move_active = true
	_handle_card_effect_mini_press(point, visible_size, bot_input)


func _begin_swap_drag(character_index: int) -> void :
	pending_effect_mini_index = _find_mini_for_character_card(character_index)
	if pending_effect_mini_index < 0:
		swap_source_character_index = -1
		_finish_played_card_effect()
		return
	swap_drag_active = true
	queue_redraw()


func _handle_card_effect_mini_press(point: Vector2, visible_size: Vector2, bot_input: bool = false) -> void :
	if effect_move_animation_busy or dragged_mini_index >= 0:
		return
	if pending_effect_mini_index < 0 and alliance_target_character_index >= 0:
		var movable_index: = _find_alliance_movable_mini_at_point(point, visible_size)
		if movable_index >= 0:
			pending_effect_mini_index = movable_index
			var candidate: = character_minis_on_board[movable_index]
			alliance_current_move_side = alliance_active_side if movable_index == alliance_target_mini_index else candidate.owner_side
			pending_effect_target_column = min(candidate.current_column + alliance_move_amount, BOARD_COLUMNS - 1)
			pending_effect_target_row = candidate.row
	if pending_effect_mini_index < 0:
		return
	var item: = character_minis_on_board[pending_effect_mini_index]
	var controller_side: = _get_effect_move_controller_side(pending_effect_mini_index)



	if is_player_bot(controller_side) and not bot_input:
		return
	if not is_player_bot(controller_side) and bot_input:
		return
	if not _get_character_mini_hit_rect(item, visible_size).has_point(point):
		return
	dragged_mini_index = pending_effect_mini_index
	dragged_mini_original_position = item.position
	dragged_mini_offset = Vector2.ZERO
	item.position = point
	character_minis_on_board[pending_effect_mini_index] = item
	grab.play()
	if dragged_mini_scale_tween != null and dragged_mini_scale_tween.is_valid():
		dragged_mini_scale_tween.kill()
	dragged_mini_scale_tween = create_tween()
	dragged_mini_scale_tween.tween_method(
		_set_character_mini_scale.bind(dragged_mini_index), item.visual_scale, 1.28, 0.1
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _get_effect_move_controller_side(mini_index: int) -> int:
	if mini_index < 0 or mini_index >= character_minis_on_board.size():
		return _get_current_turn_side()
	if alliance_target_character_index >= 0:
		if mini_index == alliance_target_mini_index:
			return alliance_active_side
		return int(character_minis_on_board[mini_index].owner_side)
	return _get_current_turn_side()


func _find_swap_target_at_point(point: Vector2, visible_size: Vector2) -> int:
	if pending_effect_mini_index < 0:
		return -1
	var source: = character_minis_on_board[pending_effect_mini_index]
	for index in range(character_minis_on_board.size() - 1, -1, -1):
		if index == pending_effect_mini_index:
			continue
		var item: = character_minis_on_board[index]
		if item.current_column != source.current_column:
			continue
		if _get_character_mini_hit_rect(item, visible_size).has_point(point):
			return index
	return -1


func _finish_card_effect_mini_drag(point: Vector2, visible_size: Vector2) -> void :
	if effect_move_animation_busy:
		return
	effect_move_animation_busy = true
	var source_index: = dragged_mini_index
	var source: = character_minis_on_board[source_index]
	var valid: = false
	var target_position: = dragged_mini_original_position
	var swap_target: = -1
	if swap_drag_active:
		swap_target = _find_swap_target_at_point(point, visible_size)
		valid = swap_target >= 0
		if valid:
			target_position = character_minis_on_board[swap_target].position
	else:
		var locked_row: int = pending_effect_target_row if pending_effect_target_row >= 0 else source.row
		valid = _get_board_cell_rect(pending_effect_target_column, locked_row, visible_size).has_point(point)
		if valid:
			target_position = _get_board_cell_centre(pending_effect_target_column, locked_row, visible_size)
	if valid:



		board_indicator_drop_in_progress = true
		_refresh_board_indicators()
	dragged_mini_index = -1
	highlighted_swap_mini_index = -1
	if dragged_mini_scale_tween != null and dragged_mini_scale_tween.is_valid():
		dragged_mini_scale_tween.kill()
	var tween: = create_tween()
	tween.set_parallel(true)
	tween.tween_method(_set_character_mini_position.bind(source_index, source.position, target_position), 0.0, 1.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_character_mini_scale.bind(source_index), source.visual_scale, 0.86 if valid else 1.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
	if not valid:
		var reset: = character_minis_on_board[source_index]
		reset.visual_scale = 1.0
		character_minis_on_board[source_index] = reset
		if alliance_target_character_index >= 0:


			pending_effect_mini_index = -1
			pending_effect_target_column = -1
			pending_effect_target_row = -1
			alliance_current_move_side = -1
			pending_effect_move_active = true
		queue_redraw()
		effect_move_animation_busy = false
		return
	if swap_drag_active:
		source = character_minis_on_board[source_index]
		var target: = character_minis_on_board[swap_target]
		var old_source_row: int = source.row
		source.row = target.row
		target.row = old_source_row
		source.position = _get_board_cell_centre(source.current_column, source.row, visible_size)
		character_minis_on_board[source_index] = source
		character_minis_on_board[swap_target] = target
		var target_start: Vector2 = target.position
		var target_end: = _get_board_cell_centre(target.current_column, target.row, visible_size)
		swap_displaced_mini_index = swap_target
		place.play()
		grab.play()
		var swap_tween: = create_tween()
		swap_tween.set_parallel(true)
		swap_tween.tween_method(_set_character_mini_position.bind(swap_target, target_start, target_end), 0.0, 1.0, 0.18)
		swap_tween.tween_method(_set_character_mini_scale.bind(swap_target), target.visual_scale, 1.28, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await swap_tween.finished
		swap_drag_active = false
		swap_source_character_index = -1
	else:
		source = character_minis_on_board[source_index]
		source.current_column = pending_effect_target_column
		if pending_effect_target_row >= 0:
			source.row = pending_effect_target_row
		source.position = _get_board_cell_centre(source.current_column, source.row, visible_size)
		character_minis_on_board[source_index] = source
		pending_effect_move_active = false
	pending_effect_mini_index = -1
	pending_effect_target_column = -1
	pending_effect_target_row = -1
	place.play()
	var settle: = create_tween()
	settle.set_parallel(true)
	settle.tween_method(_set_character_mini_scale.bind(source_index), 0.86, 1.0, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if swap_target >= 0:
		settle.tween_method(_set_character_mini_scale.bind(swap_target), 1.28, 0.86, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await settle.finished
	if swap_target >= 0:
		var target_settle: = create_tween()
		target_settle.tween_method(_set_character_mini_scale.bind(swap_target), 0.86, 1.0, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await target_settle.finished
	swap_displaced_mini_index = -1
	if alliance_target_character_index >= 0 and not swap_drag_active:
		_advance_alliance_after_move()
	else:
		_finish_played_card_effect()
	board_indicator_drop_in_progress = false
	_refresh_board_indicators()
	effect_move_animation_busy = false


func _advance_alliance_after_move() -> void :
	if alliance_current_move_side == alliance_active_side:
		alliance_main_move_done = true
	else:
		alliance_moved_sides.append(alliance_current_move_side)
		alliance_accepted_sides.erase(alliance_current_move_side)
		_invalidate_alliance_eligibility()
	var all_allies_moved: = true
	for side in alliance_accepted_sides:
		if side not in alliance_moved_sides:
			all_allies_moved = false
			break
	if alliance_main_move_done and all_allies_moved:
		_clear_alliance_state()
		_finish_played_card_effect()
		return
	alliance_current_move_side = -1
	pending_effect_mini_index = -1
	pending_effect_target_column = -1
	pending_effect_target_row = -1
	pending_effect_move_active = true
	queue_redraw()


func _clear_alliance_state() -> void :
	alliance_phase_active = false
	alliance_target_character_index = -1
	alliance_target_mini_index = -1
	alliance_origin_column = -1
	alliance_move_amount = 0
	alliance_active_side = -1
	alliance_offer_side = -1
	alliance_offer_stars = 0
	alliance_accepted_sides.clear()
	alliance_move_queue.clear()
	alliance_moved_sides.clear()
	_stop_alliance_star_layout()
	alliance_offered_star_items.clear()
	alliance_current_move_side = -1
	alliance_main_move_done = false
	alliance_movement_unlock_time = 0
	alliance_star_transfer_busy = false
	pending_effect_target_row = -1
	_invalidate_alliance_eligibility()


func _pass_card_turn() -> void :
	if card_effect_busy or die_roll_active or swap_source_character_index >= 0:
		return
	_pulse_player_button(_get_current_turn_side())
	consecutive_passes += 1
	if consecutive_passes >= _remaining_player_count():
		card_play_phase_active = false
		turn_scene_offer_visible = false
		card_play_phase_finished.emit()
		_begin_elimination_phase()
		return
	_advance_card_turn()


func _pulse_player_button(side: int) -> void :
	if side < 0 or side >= player_button_scales.size():
		return
	_animate_player_button(side)


func _finish_played_card_effect() -> void :
	card_effect_busy = false
	_advance_card_turn()


func _advance_card_turn() -> void :
	card_turn_serial += 1
	for _step in player_order.size():
		current_card_player_order = (current_card_player_order + 1) % player_order.size()
		if not eliminated_players[player_order[current_card_player_order]]:
			break
	card_turn_action_committed = false
	_check_scene_offer_for_current_turn()
	queue_redraw()


func _remaining_player_count() -> int:
	var count: = 0
	for side in player_order:
		if not eliminated_players[side]:
			count += 1
	return max(count, 1)


func _begin_elimination_phase() -> void :
	elimination_phase_active = true
	elimination_die_ready = false
	elimination_die_busy = true
	elimination_used_win_token_indices.clear()
	player_eliminated_this_round = false
	await _arrange_minis_for_elimination()
	if character_minis_on_board.size() <= 1:
		_finish_game()
		return
	if character_minis_on_board.size() == 2 and not final_two_music_faded:
		final_two_music_faded = true
		_fade_music_to_silence(1.15)
	elimination_leader_side = character_minis_on_board[0].owner_side
	var candidate_count = min(3, character_minis_on_board.size())
	elimination_candidates.clear()
	for index in range(character_minis_on_board.size() - candidate_count, character_minis_on_board.size()):
		elimination_candidates.append(index)
	await _slide_elimination_die_in()
	elimination_die_busy = false
	elimination_die_ready = true
	queue_redraw()


func _arrange_minis_for_elimination() -> void :
	var order: Array[int] = []
	for index in character_minis_on_board.size():
		order.append(index)
	order.sort_custom( func(a: int, b: int) -> bool:
		var a_mini: = character_minis_on_board[a]
		var b_mini: = character_minis_on_board[b]
		if a_mini.current_column != b_mini.current_column:
			return a_mini.current_column > b_mini.current_column
		return a_mini.row < b_mini.row
	)
	var visible_size: = _get_visible_world_size()
	for rank in order.size():
		var index: = order[rank]
		var mini: = character_minis_on_board[index]
		mini.moving = true
		character_minis_on_board[index] = mini
		var target: = _get_board_cell_centre(BOARD_COLUMNS - 1, rank, visible_size)
		_animate_resolution_mini(index, target, rank * 0.045)
	await get_tree().create_timer(0.31 + max(order.size() - 1, 0) * 0.045).timeout
	var ranked: Array[Dictionary] = []
	for rank in order.size():
		var mini: = character_minis_on_board[order[rank]]
		mini.current_column = BOARD_COLUMNS - 1
		mini.row = rank
		mini.moving = false
		mini.position = _get_board_cell_centre(BOARD_COLUMNS - 1, rank, visible_size)
		ranked.append(mini)
	character_minis_on_board = ranked
	queue_redraw()


func _animate_resolution_mini(
	index: int, 
	target: Vector2, 
	delay: float, 
	remove_win_token_on_arrival: bool = false
) -> void :
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	if index < 0 or index >= character_minis_on_board.size():
		return
	var mini: = character_minis_on_board[index]
	var start: Vector2 = mini.position
	mini.visual_scale = 1.6
	character_minis_on_board[index] = mini
	grab.play()
	var travel: = create_tween()
	travel.tween_method(_set_character_mini_position.bind(index, start, target), 0.0, 1.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await travel.finished
	if (remove_win_token_on_arrival
		and not keep_win_token_after_elimination
		and index < character_minis_on_board.size()):
		mini = character_minis_on_board[index]
		mini.has_win_token = false
		character_minis_on_board[index] = mini
		queue_redraw()
	place.play()
	var landing: = create_tween()
	landing.tween_method(_set_character_mini_scale.bind(index), 1.6, 0.86, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	landing.tween_method(_set_character_mini_scale.bind(index), 0.86, 1.0, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await landing.finished


func _slide_elimination_die_in() -> void :
	die_roll_active = true
	die_roll_animation_active = false
	die_roll.visible = false
	die_visual_frame = 1
	die_visual_scale = 0.72
	die_face = 1
	var visible_size: = _get_visible_world_size()
	var centre: = to_local(camera_2d.get_screen_center_position())
	die_base_rotation = _get_player_rotation(elimination_leader_side)
	die_rotation = die_base_rotation

	var die_half: = _get_die_size(visible_size) * 0.5
	var edge_midpoint: = centre
	match elimination_leader_side:
		0:
			edge_midpoint += Vector2(0.0, - visible_size.y * 0.5 - die_half.y)
		1:
			edge_midpoint += Vector2(visible_size.x * 0.5 + die_half.x, 0.0)
		2:
			edge_midpoint += Vector2(0.0, visible_size.y * 0.5 + die_half.y)
		_:
			edge_midpoint += Vector2( - visible_size.x * 0.5 - die_half.x, 0.0)
	die_position = edge_midpoint
	var tween: = create_tween()
	tween.set_parallel(true)
	tween.tween_method(_set_die_position.bind(edge_midpoint, centre), 0.0, 1.0, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_die_scale, 0.72, 1.0, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tween.finished


func _roll_elimination_die() -> void :
	if elimination_die_busy or not elimination_die_ready:
		return
	elimination_die_busy = true
	elimination_die_ready = false
	die.stream = [DIE_1, DIE_2, DIE_3].pick_random()
	die.play()
	await _play_animated_die_roll()
	die_face = _roll_weighted_die_face()
	die_visual_frame = die_face
	die_visual_scale = 1.0
	die_rotation = die_base_rotation
	queue_redraw()
	await _play_die_result_bounces()
	if die_face > elimination_candidates.size():
		elimination_die_busy = false
		elimination_die_ready = true
		await get_tree().create_timer(0.16).timeout
		_roll_elimination_die()
		return



	var candidate_slot: = elimination_candidates.size() - die_face
	var mini_index: = elimination_candidates[candidate_slot]
	if mini_index < 0 or mini_index >= character_minis_on_board.size():
		elimination_die_busy = false
		elimination_die_ready = true
		return
	var mini: = character_minis_on_board[mini_index]
	if (mini.get("has_win_token", false)
		and mini_index not in elimination_used_win_token_indices):
		elimination_used_win_token_indices.append(mini_index)
		if not keep_win_token_after_elimination:
			mini.has_win_token = false
			character_minis_on_board[mini_index] = mini
		await _award_stars(mini.owner_side, 2)
		elimination_die_busy = false
		elimination_die_ready = true
		queue_redraw()
		return
	await _eliminate_character(mini_index)
	await _finish_elimination_round()


func _eliminate_character(mini_index: int) -> void :
	var eliminated: = character_minis_on_board[mini_index]
	var tween: = create_tween()
	tween.tween_method(_set_character_mini_scale.bind(mini_index), eliminated.visual_scale, 0.0, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await tween.finished
	throw.play()
	for card_index in range(player_character_cards.size() - 1, -1, -1):
		var card: = player_character_cards[card_index]
		if card.owner_side == eliminated.owner_side and _get_character_name_from_card(card_index) == eliminated.character_name:
			_play_random_flick()
			player_character_cards.remove_at(card_index)
			break
	_refresh_scene_hands_preserving_order(true, true)
	character_minis_on_board.remove_at(mini_index)
	var owner_has_character: = false
	for remaining in character_minis_on_board:
		if remaining.owner_side == eliminated.owner_side:
			owner_has_character = true
			break
	if not owner_has_character:
		player_eliminated_this_round = true
		eliminated_players[eliminated.owner_side] = true
		if eliminated.owner_side == challenge_opener_side:
			challenge_opener_side = _get_next_surviving_player(eliminated.owner_side)
		_remove_eliminated_player_items(eliminated.owner_side)
	queue_redraw()


func _ensure_valid_challenge_opener() -> void :
	if (challenge_opener_side < 0
		or challenge_opener_side >= eliminated_players.size()
		or eliminated_players[challenge_opener_side]):
		challenge_opener_side = _get_next_surviving_player(challenge_opener_side)


func _get_next_surviving_player(after_side: int) -> int:
	if player_order.is_empty():
		return -1
	var start_index: = player_order.find(after_side)
	if start_index < 0:
		start_index = -1
	for offset in range(1, player_order.size() + 1):
		var side: = player_order[(start_index + offset) % player_order.size()]
		if not eliminated_players[side]:
			return side
	return -1


func _remove_eliminated_player_items(side: int) -> void :
	for index in range(dealt_scene_cards.size() - 1, -1, -1):
		if dealt_scene_cards[index].owner_side == side:
			dealt_scene_cards.remove_at(index)
	for index in range(player_character_cards.size() - 1, -1, -1):
		if player_character_cards[index].owner_side == side:
			player_character_cards.remove_at(index)
	for index in range(player_stars.size() - 1, -1, -1):
		if player_stars[index].owner_side == side:
			player_stars.remove_at(index)
	scene_cycle_indices[side] = 0
	character_cycle_indices[side] = 0
	_refresh_scene_hands_preserving_order(true, true, false)
	_refresh_character_hands_preserving_order()
	queue_redraw()


func _refresh_character_hands_preserving_order(animate: bool = true) -> void :
	var visible_size: = _get_visible_world_size()
	if character_hand_reflow_tween != null and character_hand_reflow_tween.is_valid():
		character_hand_reflow_tween.kill()
	character_hand_reflow_tween = null
	for side in 4:
		var indices: = _get_owner_character_card_indices(side)
		if indices.is_empty():
			character_cycle_indices[side] = 0
			continue
		var rotation: = _get_player_rotation(side)
		indices.sort_custom( func(a: int, b: int) -> bool:
			var a_x: float = player_character_cards[a].position.rotated( - rotation).x
			var b_x: float = player_character_cards[b].position.rotated( - rotation).x
			return a_x < b_x
		)
		var scale: = _get_character_hand_scale(side, indices.size(), visible_size)
		for slot in indices.size():
			var index: = indices[slot]
			var card: = player_character_cards[index]
			var target: = _get_character_hand_position(
				side, slot, indices.size(), visible_size
			)
			card.rotation = rotation
			player_character_cards[index] = card
			if (animate
				and ( not card.position.is_equal_approx(target)
				or not is_equal_approx(card.scale, scale))):
				if character_hand_reflow_tween == null:
					character_hand_reflow_tween = create_tween()
					character_hand_reflow_tween.set_parallel(true)
				character_hand_reflow_tween.tween_method(
					_set_player_character_layout.bind(
						index, 
						card.position, 
						target, 
						card.scale, 
						scale
					), 
					0.0, 
					1.0, 
					0.22
				).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			else:
				card.position = target
				card.scale = scale
				player_character_cards[index] = card
		var owner_indices: = _get_owner_character_card_indices(side)
		character_cycle_indices[side] = owner_indices.find(indices.back())
	queue_redraw()


func _finish_elimination_round() -> void :
	elimination_die_busy = true
	if character_minis_on_board.size() <= 1:
		await _slide_elimination_die_out()
		_finish_game()
		return
	await _slide_elimination_die_out()
	var visible_size: = _get_visible_world_size()
	for index in character_minis_on_board.size():
		var mini: = character_minis_on_board[index]
		var target: = _get_board_cell_centre(0, mini.row, visible_size)
		_animate_resolution_mini(index, target, index * 0.045, true)
	await get_tree().create_timer(0.31 + max(character_minis_on_board.size() - 1, 0) * 0.045).timeout


	for index in character_minis_on_board.size():
		var mini: = character_minis_on_board[index]
		mini.current_column = 0
		mini.position = _get_board_cell_centre(0, mini.row, visible_size)
		character_minis_on_board[index] = mini
	if character_minis_on_board.size() == 4 and not call_to_adventure_started:
		call_to_adventure_started = true
		_crossfade_to_music(CALL_TO_ADVENTURE, 1.8)
	for index in character_minis_on_board.size():
		var mini: = character_minis_on_board[index]
		if mini.row == 0:
			await _award_stars(mini.owner_side, 2)
		elif mini.row <= 2:
			await _award_stars(mini.owner_side, 1)
	if give_all_players_star_after_elimination:
		await _award_all_players_elimination_star()
	if _should_award_round_scene_cards():
		await _award_round_scene_cards()
	elimination_phase_active = false
	elimination_die_ready = false
	elimination_leader_side = -1
	current_challenge = {}
	_begin_challenge_card_phase()
	queue_redraw()


func _slide_elimination_die_out() -> void :
	var visible_size: = _get_visible_world_size()
	var centre: = to_local(camera_2d.get_screen_center_position())
	var die_half: = _get_die_size(visible_size) * 0.5
	var target: = centre
	match elimination_leader_side:
		0:
			target += Vector2(0.0, - visible_size.y * 0.5 - die_half.y)
		1:
			target += Vector2(visible_size.x * 0.5 + die_half.x, 0.0)
		2:
			target += Vector2(0.0, visible_size.y * 0.5 + die_half.y)
		_:
			target += Vector2( - visible_size.x * 0.5 - die_half.x, 0.0)
	var start: = die_position
	var tween: = create_tween()
	tween.set_parallel(true)
	tween.tween_method(_set_die_position.bind(start, target), 0.0, 1.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_method(_set_die_scale, die_visual_scale, 0.72, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
	die_roll_active = false
	die_roll_animation_active = false
	die_roll.visible = false
	queue_redraw()


func _should_award_round_scene_cards() -> bool:
	match elimination_scene_card_draw_rule:
		2:
			return player_eliminated_this_round
		3:
			return true
		_:
			return false


func _award_all_players_elimination_star() -> void :
	for side in player_order:
		if eliminated_players[side]:
			continue
		await _award_stars(side, 1)


func _award_round_scene_cards() -> void :
	var visible_size: = _get_visible_world_size()
	var centre: = to_local(camera_2d.get_screen_center_position())
	var awarded_indices: Array[int] = []
	for side in player_order:
		if eliminated_players[side]:
			continue
		var owner_count: = _get_owner_scene_card_indices(side).size() + 1
		var target: = _get_dealt_scene_card_position(side, owner_count - 1, owner_count, visible_size)
		var target_scale: = _get_dealt_scene_card_scale(visible_size, side, owner_count)
		dealt_scene_cards.append({
			"owner_side": side, 
			"owner_slot": owner_count - 1, 
			"card_number": _take_next_scene_card_number(side), 
			"texture": _draw_scene_card_for_side(side), 
			"revealed": false, 
			"position": centre, 
			"rotation": _get_player_rotation(side), 
			"flip_scale": 1.0, 
			"deal_scale": 1.0, 
			"moving": true, 
			"flipping": false, 
		})
		var index: = dealt_scene_cards.size() - 1
		awarded_indices.append(index)
		_play_random_flick()
		var tween: = create_tween()
		tween.tween_method(
			_set_dealt_card_move.bind(index, centre, target, target_scale), 0.0, 1.0, 0.3
		).set_delay(awarded_indices.size() * 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(0.38 + awarded_indices.size() * 0.05).timeout
	for index in awarded_indices:
		if index < dealt_scene_cards.size():
			var card: = dealt_scene_cards[index]
			card.moving = false
			dealt_scene_cards[index] = card
	_refresh_scene_hands_preserving_order()


func _award_stars(side: int, amount: int) -> void :
	var visible_size: = _get_visible_world_size()
	var start: = to_local(camera_2d.get_screen_center_position())
	var centre_ratio = (
		_get_centre_star_size(visible_size).x
		/ max(_get_player_star_size(visible_size).x, 1.0)
	)
	var first_slot: = _get_owner_star_count(side)
	for offset in amount:
		player_stars.append({
			"owner_side": side, 
			"position": start, 
			"moving": true, 
			"travel_scale": centre_ratio, 
			"travel_rotation": 0.0, 
		})
		var star_index: = player_stars.size() - 1
		var target: = _get_player_star_position(side, visible_size, first_slot + offset, first_slot + amount)
		var tween: = create_tween()
		tween.tween_method(
			_set_player_star_position.bind(star_index, start, target), 0.0, 1.0, 0.34
		).set_delay(offset * 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.finished.connect(_awarded_star_arrived.bind(star_index))
		star.play()
	_refresh_player_star_stack(side)
	queue_redraw()
	await get_tree().create_timer(0.36 + max(amount - 1, 0) * 0.06).timeout


func _awarded_star_arrived(index: int) -> void :
	if index < 0 or index >= player_stars.size():
		return
	var item: = player_stars[index]
	item.moving = false
	item.travel_scale = 1.0
	item.travel_rotation = _get_player_rotation(item.owner_side)
	player_stars[index] = item
	queue_redraw()


func _finish_game() -> void :
	if game_over:
		return
	game_over = true
	win.play()
	elimination_phase_active = false
	elimination_die_ready = false
	elimination_die_busy = false
	die_roll_active = false
	die_roll_animation_active = false
	die_roll.visible = false
	if not character_minis_on_board.is_empty():
		elimination_leader_side = character_minis_on_board[0].owner_side
	queue_redraw()
	_load_end_interstitial_if_needed()


func _on_win_sound_finished() -> void :
	if game_over:
		_play_music(WINNER_WINNER, 0.7)


func _return_to_lobby_after_game() -> void :


	_stop_music_immediately()
	_show_or_load_end_interstitial()
	get_tree().reload_current_scene()


func _begin_die_roll(character_index: int) -> void :
	die_roll_active = true
	die_roll_busy = true
	pending_boost_character_index = character_index
	die_face = 1
	var visible_size: = _get_visible_world_size()
	var centre: = to_local(camera_2d.get_screen_center_position())
	var side: = _get_current_turn_side()
	die_base_rotation = _get_player_rotation(side)
	die_rotation = die_base_rotation
	die_visual_scale = 0.72
	die_visual_frame = 1
	die_roll_animation_active = false
	die_roll.visible = false
	die_position = _get_scene_deck_offscreen_position(side, centre, visible_size)
	var start: = die_position
	var tween: = create_tween()
	tween.set_parallel(true)
	tween.tween_method(
		_set_die_position.bind(start, centre), 0.0, 1.0, 0.38
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_die_scale, 0.72, 1.0, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.finished.connect(_die_arrived)


func _die_arrived() -> void :
	die_roll_busy = false
	queue_redraw()


func _roll_die() -> void :
	die_roll_busy = true
	die.stream = [DIE_1, DIE_2, DIE_3].pick_random()
	die.play()
	await _play_animated_die_roll()
	die_face = _roll_weighted_die_face()
	die_visual_frame = die_face
	die_visual_scale = 1.0
	die_rotation = die_base_rotation
	queue_redraw()
	await _play_die_result_bounces()
	var start: = die_position
	var centre: = to_local(camera_2d.get_screen_center_position())
	var target: = _get_scene_deck_offscreen_position(_get_current_turn_side(), centre, _get_visible_world_size())
	var exit_tween: = create_tween()
	exit_tween.tween_method(
		_set_die_position.bind(start, target), 0.0, 1.0, 0.34
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await exit_tween.finished
	die_roll_active = false
	die_roll_busy = false
	die_roll_animation_active = false
	die_roll.visible = false
	var boosted_character: = pending_boost_character_index
	pending_boost_character_index = -1
	_begin_boost_alliance(boosted_character, die_face)


func _draw_die(visible_size: Vector2) -> void :
	if not die_roll_active or die_roll_animation_active:
		return
	var die_side: = elimination_leader_side if elimination_phase_active else _get_current_turn_side()
	var use_bfdi_die: = _get_player_content_mode(die_side) == GameContentMode.BFDI
	var texture: Texture2D = BFDI_DIE_FACE if use_bfdi_die else DIE_FACE
	if die_visual_frame == 2:
		texture = BFDI_DIE_FACE_2 if use_bfdi_die else DIE_FACE_2
	elif die_visual_frame == 3:
		texture = BFDI_DIE_FACE_3 if use_bfdi_die else DIE_FACE_3
	var texture_size: = texture.get_size()
	var fit_scale: = _get_die_texture_scale(texture, visible_size)
	var draw_size = texture_size * fit_scale
	draw_set_transform(die_position, die_rotation, Vector2.ONE * die_visual_scale)
	draw_texture_rect(texture, Rect2( - draw_size * 0.5, draw_size), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _get_die_size(visible_size: Vector2) -> Vector2:
	var phone_scale: = PHONE_DIE_SCALE if _is_phone_layout(visible_size) else 1.0
	var side = min(visible_size.x, visible_size.y) * 0.18 * phone_scale
	return Vector2.ONE * side


func _roll_weighted_die_face() -> int:

	var side: = randi_range(1, 6)
	if side <= 3:
		return 1
	if side <= 5:
		return 2
	return 3


func _set_die_position(progress: float, start: Vector2, target: Vector2) -> void :
	die_position = start.lerp(target, progress)
	_sync_die_roll_sprite()
	queue_redraw()


func _set_die_scale(value: float) -> void :
	die_visual_scale = value
	_sync_die_roll_sprite()
	queue_redraw()


func _play_animated_die_roll() -> void :
	var animation_name: = _get_die_roll_animation_name()
	if die_roll.sprite_frames == null or not die_roll.sprite_frames.has_animation(animation_name):
		push_warning("DieRoll is missing the '%s' animation." % animation_name)
		await get_tree().create_timer(0.6).timeout
		return
	var normal_scale: = die_visual_scale
	var rolling_scale: = normal_scale * 1.5
	die_visual_scale = rolling_scale
	die_roll_animation_active = true
	die_roll.visible = true
	die_roll.animation = animation_name
	die_roll.frame = 0
	die_roll.frame_progress = 0.0
	die_roll.play()
	_sync_die_roll_sprite()
	queue_redraw()
	var bounce: = create_tween()
	bounce.tween_method(
		_set_die_scale, rolling_scale, normal_scale * 3.0, 0.28
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	bounce.tween_method(
		_set_die_scale, normal_scale * 3.0, rolling_scale, 0.28
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await bounce.finished
	die_roll.stop()
	die_roll.visible = false
	die_roll_animation_active = false
	die_visual_scale = normal_scale
	queue_redraw()


func _play_die_result_bounces() -> void :
	var base_scale: = die_visual_scale
	for bounce_index in 2:
		var bounce_scale: = 1.14 if bounce_index == 0 else 1.07
		var bounce_duration: = 0.1 if bounce_index == 0 else 0.08
		var bounce: = create_tween()
		bounce.set_trans(Tween.TRANS_QUAD)
		bounce.set_ease(Tween.EASE_OUT)
		bounce.tween_method(
			_set_die_scale, base_scale, base_scale * bounce_scale, bounce_duration
		)
		bounce.set_ease(Tween.EASE_IN)
		bounce.tween_method(
			_set_die_scale, base_scale * bounce_scale, base_scale, bounce_duration
		)
		await bounce.finished
	die_visual_scale = base_scale
	queue_redraw()


func _get_die_roll_animation_name() -> StringName:
	var die_side: = elimination_leader_side if elimination_phase_active else _get_current_turn_side()
	return &"BFDI" if _get_player_content_mode(die_side) == GameContentMode.BFDI else &"CFDI"


func _sync_die_roll_sprite() -> void :
	if not die_roll_animation_active or die_roll.sprite_frames == null:
		return
	var animation_name: = die_roll.animation
	var frame_count: = die_roll.sprite_frames.get_frame_count(animation_name)
	if frame_count <= 0:
		return
	var texture: = die_roll.sprite_frames.get_frame_texture(
		animation_name, clampi(die_roll.frame, 0, frame_count - 1)
	)
	if texture == null:
		return
	var fit_scale: = _get_die_texture_scale(texture, _get_visible_world_size())
	die_roll.position = die_position
	die_roll.rotation = die_rotation
	die_roll.scale = Vector2.ONE * fit_scale * die_visual_scale
	queue_redraw()


func _get_die_texture_scale(texture: Texture2D, visible_size: Vector2) -> float:
	if texture == null:
		return 1.0
	var target_size: = _get_die_size(visible_size)
	var texture_size: = texture.get_size()
	return min(
		target_size.x / max(texture_size.x, 1.0), 
		target_size.y / max(texture_size.y, 1.0)
	)


func _is_scene_card_selected(card_index: int) -> bool:
	var side: int = dealt_scene_cards[card_index].owner_side
	var indices: = _get_owner_scene_card_indices(side)
	if indices.is_empty():
		return false
	return indices[scene_cycle_indices[side] %indices.size()] == card_index


func _is_character_card_selected(card_index: int) -> bool:
	var side: int = player_character_cards[card_index].owner_side
	var indices: = _get_owner_character_card_indices(side)
	if indices.is_empty():
		return false
	return indices[character_cycle_indices[side] %indices.size()] == card_index


func _find_hand_swipe_target(point: Vector2, visible_size: Vector2) -> Dictionary:
	var touch_multiplier: = 1.12 if _is_phone_layout(visible_size) else 1.0
	var best_target: Dictionary = {}
	var best_distance: = INF
	for side in player_order:
		if is_player_bot(side):
			continue
		var scene_indices: = _get_owner_scene_card_indices(side)
		if not scene_indices.is_empty():
			var selected_scene: = scene_indices[scene_cycle_indices[side] %scene_indices.size()]
			var scene_card: = dealt_scene_cards[selected_scene]
			var scene_size = (
				_get_scene_card_size(visible_size)
				* scene_card.deal_scale
				* touch_multiplier
			)
			if _point_is_in_card(point, scene_card.position, scene_card.rotation, scene_size):
				var scene_local_point = (
					(point - scene_card.position).rotated( - scene_card.rotation)
				)
				var scene_distance_score: = (
					pow(scene_local_point.x / max(scene_size.x, 1.0), 2.0)
					+ pow(scene_local_point.y / max(scene_size.y, 1.0), 2.0)
				)
				if scene_distance_score < best_distance:
					best_distance = scene_distance_score
					best_target = {"side": side, "scene_stack": true}

		var character_indices: = _get_owner_character_card_indices(side)
		if not character_indices.is_empty():
			var selected_character: = character_indices[character_cycle_indices[side] %character_indices.size()]
			var character_card: = player_character_cards[selected_character]
			var character_size = (
				_get_character_draft_card_size(visible_size)
				* character_card.scale
				* touch_multiplier
			)
			if _point_is_in_card(point, character_card.position, character_card.rotation, character_size):
				var character_local_point = (
					(point - character_card.position).rotated( - character_card.rotation)
				)
				var character_distance_score: = (
					pow(character_local_point.x / max(character_size.x, 1.0), 2.0)
					+ pow(character_local_point.y / max(character_size.y, 1.0), 2.0)
				)
				if character_distance_score < best_distance:
					best_distance = character_distance_score
					best_target = {"side": side, "scene_stack": false}
	return best_target


func _finish_hand_swipe(end_position: Vector2, visible_size: Vector2) -> void :
	var side: = hand_swipe_side
	var scene_stack: = hand_swipe_scene_stack
	var player_delta: = (end_position - hand_swipe_start).rotated( - _get_player_rotation(side))
	var swipe_threshold_ratio: = 0.035 if _is_phone_layout(visible_size) else 0.055
	var swipe_threshold = min(visible_size.x, visible_size.y) * swipe_threshold_ratio
	hand_swipe_active = false
	hand_swipe_side = -1

	if player_delta.x <= - swipe_threshold:
		var indices: = _get_owner_scene_card_indices(side) if scene_stack else _get_owner_character_card_indices(side)
		var busy: = scene_cycle_busy[side] if scene_stack else character_cycle_busy[side]
		if indices.size() > 1 and not busy:
			_animate_hand_cycle(side, scene_stack, indices.size())
		return


	if scene_stack:
		var scene_indices: = _get_owner_scene_card_indices(side)
		if not scene_indices.is_empty():
			var selected: = scene_indices[scene_cycle_indices[side] %scene_indices.size()]
			if not dealt_scene_cards[selected].flipping:
				_flip_dealt_scene_card(selected)


func _handle_hand_cycle_input(point: Vector2, visible_size: Vector2) -> bool:
	for side in player_order:
		var scene_indices: = _get_owner_scene_card_indices(side)
		if (scene_indices.size() > 1
			and not scene_cycle_busy[side]
			and point.distance_to(_get_hand_cycle_button_position(side, true, visible_size)) <= HAND_CYCLE_BUTTON_RADIUS):
			_animate_hand_cycle(side, true, scene_indices.size())
			return true

		var character_indices: = _get_owner_character_card_indices(side)
		if (character_indices.size() > 1
			and not character_cycle_busy[side]
			and point.distance_to(_get_hand_cycle_button_position(side, false, visible_size)) <= HAND_CYCLE_BUTTON_RADIUS):
			_animate_hand_cycle(side, false, character_indices.size())
			return true
	return false


func _animate_hand_cycle(side: int, scene_stack: bool, card_count: int) -> void :
	_play_random_flick()
	var indices: = _get_owner_scene_card_indices(side) if scene_stack else _get_owner_character_card_indices(side)
	var rotation: = _get_player_rotation(side)
	indices.sort_custom( func(a: int, b: int) -> bool:
		var a_position: Vector2 = dealt_scene_cards[a].position if scene_stack else player_character_cards[a].position
		var b_position: Vector2 = dealt_scene_cards[b].position if scene_stack else player_character_cards[b].position
		return a_position.rotated( - rotation).x < b_position.rotated( - rotation).x
	)
	if scene_stack:
		scene_cycle_busy[side] = true
	else:
		character_cycle_busy[side] = true



	var new_order: Array[int] = []
	new_order.append(indices[card_count - 1])
	for index in range(card_count - 1):
		new_order.append(indices[index])

	var owner_indices: = (
		_get_owner_scene_card_indices(side)
		if scene_stack
		else _get_owner_character_card_indices(side)
	)
	var new_top_owner_slot: = owner_indices.find(new_order[card_count - 1])
	if scene_stack:
		scene_cycle_indices[side] = maxi(new_top_owner_slot, 0)
	else:
		character_cycle_indices[side] = maxi(new_top_owner_slot, 0)

	var visible_size: = _get_visible_world_size()
	var tween: = create_tween()
	tween.set_parallel(true)
	for slot in new_order.size():
		var card_index: = new_order[slot]
		var start: Vector2 = dealt_scene_cards[card_index].position if scene_stack else player_character_cards[card_index].position
		var target: = _get_dealt_scene_card_position(side, slot, card_count, visible_size) if scene_stack else _get_character_hand_position(side, slot, card_count, visible_size)
		tween.tween_method(
			_set_cycle_card_position.bind(card_index, start, target, scene_stack), 
			0.0, 1.0, 0.24
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.finished.connect(_finish_hand_cycle.bind(side, scene_stack))


func _set_cycle_card_position(progress: float, card_index: int, start: Vector2, target: Vector2, scene_stack: bool) -> void :
	if scene_stack:
		var card: = dealt_scene_cards[card_index]
		card.position = start.lerp(target, progress)
		dealt_scene_cards[card_index] = card
	else:
		var card: = player_character_cards[card_index]
		card.position = start.lerp(target, progress)
		player_character_cards[card_index] = card
	queue_redraw()


func _finish_hand_cycle(side: int, scene_stack: bool) -> void :
	if scene_stack:
		scene_cycle_busy[side] = false
	else:
		character_cycle_busy[side] = false
	queue_redraw()


func _draw_hand_cycle_buttons(visible_size: Vector2) -> void :
	for side in player_order:
		if _get_owner_scene_card_indices(side).size() > 1:
			_draw_hand_cycle_button(_get_hand_cycle_button_position(side, true, visible_size), side)
		if _get_owner_character_card_indices(side).size() > 1:
			_draw_hand_cycle_button(_get_hand_cycle_button_position(side, false, visible_size), side)


func _draw_hand_cycle_button(position: Vector2, side: int) -> void :
	var rotation: = _get_player_rotation(side)
	draw_set_transform(position, rotation, Vector2.ONE)
	draw_circle(Vector2.ZERO, HAND_CYCLE_BUTTON_RADIUS, Color(0.12, 0.12, 0.12, 0.88))
	draw_arc(Vector2.ZERO, HAND_CYCLE_BUTTON_RADIUS, 0.0, TAU, 32, Color.WHITE, 3.0, true)
	var label: = ">"
	var font_size: = 24
	var button_font: = _get_player_font(side)
	var size: = button_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(button_font, Vector2( - size.x * 0.5, size.y * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _get_hand_cycle_button_position(side: int, scene_stack: bool, visible_size: Vector2) -> Vector2:
	var centre: = to_local(camera_2d.get_screen_center_position())
	var edge_position: = _get_player_position(side, centre, visible_size)
	var edge_span: = visible_size.x if side == 0 or side == 2 else visible_size.y

	var local_x: = 0.0
	if scene_stack:
		local_x = - edge_span * 0.35 + edge_span * 0.22 + HAND_CYCLE_BUTTON_RADIUS + 6.0
	else:
		local_x = edge_span * 0.12 + HAND_CYCLE_BUTTON_RADIUS + 6.0
	var desired: = edge_position + Vector2(local_x, 0.0).rotated(_get_player_rotation(side))
	var margin: = HAND_CYCLE_BUTTON_RADIUS + 5.0
	return Vector2(
		clamp(desired.x, centre.x - visible_size.x * 0.5 + margin, centre.x + visible_size.x * 0.5 - margin), 
		clamp(desired.y, centre.y - visible_size.y * 0.5 + margin, centre.y + visible_size.y * 0.5 - margin)
	)


func _refresh_card_layouts(refresh_draft: bool = true) -> void :
	if not is_node_ready():
		return
	var visible_size: = _get_visible_world_size()
	for side in 4:
		var scene_indices: = _get_owner_scene_card_indices(side)
		var scene_scale: = _get_dealt_scene_card_scale(visible_size, side, scene_indices.size())
		for slot in scene_indices.size():
			var index: = scene_indices[slot]
			var card: = dealt_scene_cards[index]
			if not card.moving:
				card.position = _get_dealt_scene_card_position(side, slot, scene_indices.size(), visible_size)
				card.rotation = _get_player_rotation(side)
				card.deal_scale = scene_scale
				dealt_scene_cards[index] = card

		var character_indices: = _get_owner_character_card_indices(side)
		var character_scale: = _get_character_hand_scale(side, character_indices.size(), visible_size)
		for slot in character_indices.size():
			var index: = character_indices[slot]
			var card: = player_character_cards[index]
			card.position = _get_character_hand_position(side, slot, character_indices.size(), visible_size)
			card.rotation = _get_player_rotation(side)
			card.scale = character_scale
			player_character_cards[index] = card

	if refresh_draft and character_draft_active and not draft_character_cards.is_empty():
		var rotation: = _get_player_rotation(player_order[current_character_player_order])
		for index in draft_character_cards.size():
			var card: = draft_character_cards[index]
			card.position = _get_character_grid_position(index, rotation, visible_size)
			card.rotation = rotation
			draft_character_cards[index] = card

	if star_draft_active:
		for index in draft_stars.size():
			var item: = draft_stars[index]
			if not item.moving:
				item.position = _get_centre_star_position(index, draft_stars.size(), visible_size)
				draft_stars[index] = item

	var star_slots: = [0, 0, 0, 0]
	var star_counts: = [0, 0, 0, 0]
	for star_item in player_stars:
		star_counts[star_item.owner_side] += 1
	for index in player_stars.size():
		var item: = player_stars[index]
		if not item.moving:
			item.position = _get_player_star_position(
				item.owner_side, 
				visible_size, 
				star_slots[item.owner_side], 
				star_counts[item.owner_side]
			)
			player_stars[index] = item
		star_slots[item.owner_side] += 1

	for index in character_minis_on_board.size():
		var item: = character_minis_on_board[index]
		if not item.moving:
			item.position = _get_board_cell_centre(item.get("current_column", 0), item.row, visible_size)
			character_minis_on_board[index] = item

	if challenge_card_visible and not challenge_card_busy:
		challenge_card_position = to_local(camera_2d.get_screen_center_position())


func _draw_gradient_column(rect: Rect2, radius: float) -> void :


	var strip_height: = 2.0
	var strip_count: = int(ceil(rect.size.y / strip_height))

	for strip in strip_count:
		var local_y = min(strip * strip_height, rect.size.y)
		var height = min(strip_height + 1.0, rect.size.y - local_y)
		if height <= 0.0:
			continue

		var centre_y = local_y + height * 0.5
		var inset: = _rounded_column_inset(centre_y, rect.size, radius)
		var colour: = BOARD_TOP_COLOUR.lerp(
			BOARD_BOTTOM_COLOUR, 
			centre_y / rect.size.y
		)
		draw_rect(
			Rect2(rect.position + Vector2(inset, local_y), Vector2(rect.size.x - inset * 2.0, height)), 
			colour
		)


func _draw_column_lines(rect: Rect2, cell_height: float, radius: float) -> void :

	for row in range(1, BOARD_ROWS):
		var y: = rect.position.y + row * cell_height
		draw_line(
			Vector2(rect.position.x, y), 
			Vector2(rect.end.x, y), 
			BOARD_LINE_COLOUR, 
			BOARD_LINE_WIDTH, 
			true
		)


	var outer_border: = StyleBoxFlat.new()
	outer_border.bg_color = Color.TRANSPARENT
	outer_border.border_color = BOARD_OUTLINE_COLOUR
	outer_border.set_border_width_all(int(BOARD_OUTLINE_WIDTH))
	outer_border.set_corner_radius_all(int(radius))
	outer_border.anti_aliasing = true
	draw_style_box(outer_border, rect)

	var border: = StyleBoxFlat.new()
	border.bg_color = Color.TRANSPARENT
	border.border_color = BOARD_LINE_COLOUR
	border.set_border_width_all(int(BOARD_LINE_WIDTH))
	border.set_corner_radius_all(int(radius))
	border.anti_aliasing = true
	draw_style_box(border, rect)


func _draw_starting_stars(rect: Rect2, cell_height: float) -> void :
	var star_size = min(rect.size.x * 0.3, cell_height * 0.58)
	var first_cell_centre: = rect.position + Vector2(rect.size.x * 0.5, cell_height * 0.5)
	var star_gap = star_size * 0.12


	_draw_star(first_cell_centre + Vector2( - (star_size + star_gap) * 0.5, 0.0), star_size)
	_draw_star(first_cell_centre + Vector2((star_size + star_gap) * 0.5, 0.0), star_size)


	_draw_star(first_cell_centre + Vector2(0.0, cell_height), star_size)
	_draw_star(first_cell_centre + Vector2(0.0, cell_height * 2.0), star_size)


func _draw_star(centre: Vector2, size: float) -> void :
	if selected_game_mode == GameContentMode.BALDI: 
		draw_texture_rect(
			YTP, 
			Rect2(centre - Vector2.ONE * size * 0.5, Vector2.ONE * size), 
			false
		)
	else:
		draw_texture_rect(
			STAR, 
			Rect2(centre - Vector2.ONE * size * 0.5, Vector2.ONE * size), 
			false
		)


func _draw_winner_checkerboard(rect: Rect2, cell_height: float, radius: float) -> void :
	var square_width: = rect.size.x / WINNER_CHECKER_COLUMNS
	var square_height: = cell_height / WINNER_CHECKER_ROWS
	var cell_bottom: = rect.position.y + cell_height
	var strip_height: = 1.0

	for checker_row in WINNER_CHECKER_ROWS:
		for checker_column in WINNER_CHECKER_COLUMNS:

			if (checker_row + checker_column) % 2 != 0:
				continue

			var square: = Rect2(
				rect.position + Vector2(
					checker_column * square_width, 
					checker_row * square_height
				), 
				Vector2(square_width, square_height)
			)



			var strip_count: = int(ceil(square.size.y / strip_height))
			for strip in strip_count:
				var y: = square.position.y + strip * strip_height
				var height = min(strip_height, square.end.y - y, cell_bottom - y)
				if height <= 0.0:
					continue

				var sample_y = y - rect.position.y + height * 0.5
				var inset: = _rounded_column_inset(sample_y, rect.size, radius)
				var left = max(square.position.x, rect.position.x + inset)
				var right = min(square.end.x, rect.end.x - inset)
				if right > left:
					draw_rect(
						Rect2(Vector2(left, y), Vector2(right - left, height)), 
						WINNER_CHECKER_COLOUR
					)


func _rounded_column_inset(y: float, size: Vector2, radius: float) -> float:
	var circle_y: = 0.0
	if y < radius:
		circle_y = radius - y
	elif y > size.y - radius:
		circle_y = y - (size.y - radius)
	else:
		return 0.0

	return radius - sqrt(max(radius * radius - circle_y * circle_y, 0.0))
