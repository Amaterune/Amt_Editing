
@tool
extends Node2D


var srt_rich_text: RichTextLabel
var is_animating_bgcolor: bool = false
var animated_bgcolor: Color = Color.BLACK
var bgcolor_tween: Tween = null


var subtitles: Array = []
var current_srt_line_index: int = -1
var currently_highlighted_word_index: int = -1
var current_line_word_count: int = 0

@export var srt_file_path = "res://Assets/tutorial_transparency_fullscreen/Subtitles/001.srt" 

var indian_red_transparent : Color = Color(0.803922, 0.360784, 0.360784, 0.2)

const ENLARGED_FONT_SIZE = 65
const NORMAL_FONT_SIZE = 48
const OUTLINE_SIZE = 20

var HIGHLIGHT_FONT_SIZE_TAG_START: String
var DEFAULT_FONT_SIZE_TAG_START: String


var HIGHLIGHT_COLOR_TAG_START: String = "[color=teal]"
var DEFAULT_COLOR_TAG_START: String = "[color=white]"
var OUTLINE_TAG_START = "[outline_color=black][outline_size=" + str(OUTLINE_SIZE) + "]"

const OUTLINE_TAG_END: String = "[/outline_size][/outline_color]"
const FONT_SIZE_TAG_END: String = "[/font_size]"
const COLOR_TAG_END: String = "[/color]"


@export var use_internal_timer_for_testing: bool = false
const WORD_ANIM_INTERVAL = 0.3 
var word_anim_timer: Timer

var BGCOLOR_TAG_START: String
const BGCOLOR_TAG_END: String = "[/bgcolor]"


@export var refresh_in_editor: bool = false:

	set(value):
		print("refresh")
		if value:

			print(value)
			_editor_update()

@export var editor_preview_line: int = 0:
	set(value):
		editor_preview_line = value
		_editor_update()

func _editor_update():

	if not Engine.is_editor_hint(): return

	if srt_rich_text == null:
		srt_rich_text = get_node_or_null("SrtRichText")
	if not is_instance_valid(srt_rich_text): return
	
	parse_srt_file(srt_file_path)
	if not subtitles.is_empty():
		load_and_display_subtitle_line(editor_preview_line)


func _ready() -> void:

	srt_rich_text = $SrtRichText
	srt_rich_text.bbcode_enabled = true 

	set_process(true)
	
	srt_rich_text.bbcode_enabled = true 
	HIGHLIGHT_FONT_SIZE_TAG_START = "[font_size=" + str(ENLARGED_FONT_SIZE) + "]"
	DEFAULT_FONT_SIZE_TAG_START = "[font_size=" + str(NORMAL_FONT_SIZE) + "]"


	BGCOLOR_TAG_START = "[bgcolor=darkred]"

	if not Engine.is_editor_hint():
		parse_srt_file(srt_file_path)
		if use_internal_timer_for_testing:
			word_anim_timer = Timer.new()
			word_anim_timer.wait_time = WORD_ANIM_INTERVAL
			word_anim_timer.one_shot = false
			word_anim_timer.timeout.connect(_on_word_anim_timer_timeout)
			add_child(word_anim_timer)

			if not subtitles.is_empty():
				load_and_display_subtitle_line(0)
				
		if subtitles.is_empty():
			srt_rich_text.text = "[center]No subtitles loaded...[/center]"
		else:
			srt_rich_text.text = ""
	
	if subtitles.is_empty():
		srt_rich_text.text = "[center]No subtitles loaded or SRT file empty/invalid.[/center]"
	elif not use_internal_timer_for_testing:
		srt_rich_text.text = ""


func _process(delta: float):

	if is_animating_bgcolor:
		_apply_highlight_to_current_line()


func parse_srt_file(file_path: String):

	subtitles.clear()
	var file = FileAccess.open(file_path, FileAccess.READ)

	if not FileAccess.file_exists(file_path) or file == null:
		printerr("Can't open the SRT file: ", file_path)
		return

	var content = file.get_as_text()
	file.close()
	var blocks = content.strip_edges().split("\n\n", false)
	for block in blocks:
		var lines = block.strip_edges().split("\n", false)
		if lines.size() < 3: continue
		var timestamp_line = lines[1]
		var times = timestamp_line.split(" --> ")
		if times.size() != 2: continue
		var start_time = srt_time_to_seconds(times[0].strip_edges())
		var end_time = srt_time_to_seconds(times[1].strip_edges())
		var text_lines = lines.slice(2)
		var subtitle_text = "\n".join(text_lines).strip_edges()
		if start_time != -1 and end_time != -1:
			subtitles.append({"start": start_time, "end": end_time, "text": subtitle_text})
		else:
			printerr("Failed to parse time for block: ", block)


func srt_time_to_seconds(time_str: String) -> float:

	var parts = time_str.split(":")
	if parts.size() != 3: return -1.0
	var hms = parts[2].split(",")
	if hms.size() != 2: return -1.0
	var hours = parts[0].to_int()
	var minutes = parts[1].to_int()
	var seconds = hms[0].to_int()
	var milliseconds = hms[1].to_int()
	return float(hours * 3600 + minutes * 60 + seconds) + float(milliseconds / 1000.0)


func load_and_display_subtitle_line(line_index_from_srt: int):
	if srt_rich_text == null: srt_rich_text = get_node_or_null("SrtRichText")
	if not is_instance_valid(srt_rich_text): return
	
	if line_index_from_srt < 0 or line_index_from_srt >= subtitles.size():
		printerr("Load_and_display_subtitle_line: Invalid index ", line_index_from_srt)
		if is_instance_valid(srt_rich_text): srt_rich_text.text = ""
		current_srt_line_index = -1
		current_line_word_count = 0
		currently_highlighted_word_index = -1
		if use_internal_timer_for_testing and is_instance_valid(word_anim_timer):
			word_anim_timer.stop()
		return

	current_srt_line_index = line_index_from_srt
	var subtitle_entry = subtitles[current_srt_line_index] 
	var original_text = subtitle_entry.text
	
	var split_words_for_count: PackedStringArray = original_text.split(" ", false)
	var temp_words_for_count: Array = []
	for word_str in split_words_for_count:
		if not word_str.is_empty():
			temp_words_for_count.append(word_str)
	current_line_word_count = temp_words_for_count.size()


	currently_highlighted_word_index = -1
	_apply_highlight_to_current_line()

	if use_internal_timer_for_testing and is_instance_valid(word_anim_timer):

		if current_line_word_count > 0:
			word_anim_timer.start()
			_on_word_anim_timer_timeout()

		else:
			word_anim_timer.stop()


func highlight_word_at_index(word_index_in_current_line: int):

	if srt_rich_text == null: srt_rich_text = get_node_or_null("SrtRichText")
	if not is_instance_valid(srt_rich_text): return
	if current_srt_line_index == -1 or current_line_word_count == 0:
		return


	if word_index_in_current_line >= current_line_word_count:
		currently_highlighted_word_index = current_line_word_count - 1
	elif word_index_in_current_line < 0:
		currently_highlighted_word_index = -1
	else:
		currently_highlighted_word_index = word_index_in_current_line

	if is_instance_valid(bgcolor_tween):
		bgcolor_tween.kill()

	bgcolor_tween = create_tween()


	animated_bgcolor = Color.INDIAN_RED
	bgcolor_tween.tween_property(self, "animated_bgcolor", Color.INDIGO , 0.55)

	is_animating_bgcolor = true
	bgcolor_tween.finished.connect(_on_bgcolor_tween_finished)
	_apply_highlight_to_current_line()


func _apply_highlight_to_current_line():
	if srt_rich_text == null: srt_rich_text = get_node_or_null("SrtRichText")
	if not is_instance_valid(srt_rich_text): return

	if current_srt_line_index < 0 or current_srt_line_index >= subtitles.size():
		if is_instance_valid(srt_rich_text): srt_rich_text.text = ""
		return

	var subtitle_entry = subtitles[current_srt_line_index]
	var original_text = subtitle_entry.text
	var split_words_from_original: PackedStringArray = original_text.split(" ", false) 
	var words: Array = []
	for word_str in split_words_from_original:
		if not word_str.is_empty():
			words.append(word_str)

	if words.is_empty(): 
		if is_instance_valid(srt_rich_text):
			if not original_text.is_empty():
				srt_rich_text.text = "[center]" + OUTLINE_TAG_START + \
									DEFAULT_COLOR_TAG_START + DEFAULT_FONT_SIZE_TAG_START + \
									original_text + \
									FONT_SIZE_TAG_END + COLOR_TAG_END + \
									OUTLINE_TAG_END + "[/center]"
			else:
				srt_rich_text.text = ""
		return

	var reconstructed_words: Array = [] 
	for i in range(words.size()):
		var current_word = words[i]
		var processed_word_bbcode: String
		if i == currently_highlighted_word_index:
			var current_bgcolor_hex = animated_bgcolor.to_html(false)
			var dynamic_bgcolor_tag = "[bgcolor=" + current_bgcolor_hex + "]"
			
			processed_word_bbcode = dynamic_bgcolor_tag + \
			OUTLINE_TAG_START + \
			HIGHLIGHT_COLOR_TAG_START + \
			HIGHLIGHT_FONT_SIZE_TAG_START + \
			current_word + \
			FONT_SIZE_TAG_END + COLOR_TAG_END + \
			OUTLINE_TAG_END + \
			BGCOLOR_TAG_END

		else:
			if currently_highlighted_word_index == -1 and i == 0 and words.size() > 0:
				processed_word_bbcode = OUTLINE_TAG_START + \
				DEFAULT_COLOR_TAG_START + \
				HIGHLIGHT_FONT_SIZE_TAG_START + \
				current_word + \
				FONT_SIZE_TAG_END + COLOR_TAG_END + \
				OUTLINE_TAG_END
			else:
				processed_word_bbcode = OUTLINE_TAG_START + \
				DEFAULT_COLOR_TAG_START + \
				DEFAULT_FONT_SIZE_TAG_START + \
				current_word + \
				FONT_SIZE_TAG_END + COLOR_TAG_END + \
				OUTLINE_TAG_END

		reconstructed_words.append(processed_word_bbcode)
			
	var bbcode_formatted_text = "   ".join(reconstructed_words)
	if is_instance_valid(srt_rich_text):
		srt_rich_text.text = "[center]" + bbcode_formatted_text + "[/center]"


func _on_word_anim_timer_timeout():
	if not use_internal_timer_for_testing or current_srt_line_index == -1 or current_line_word_count == 0:
		if is_instance_valid(word_anim_timer): word_anim_timer.stop()
		return

	var next_highlight_idx = currently_highlighted_word_index + 1
	
	if next_highlight_idx >= current_line_word_count:

		highlight_word_at_index(current_line_word_count - 1)
		if is_instance_valid(word_anim_timer): word_anim_timer.stop()
	else:
		highlight_word_at_index(next_highlight_idx)


var test_srt_line_display_index = -1
func _on_next_subtitle_button_pressed():
	if not use_internal_timer_for_testing:
		print("Button disabled: 'use_internal_timer_for_testing' is false.")
		return
		
	if subtitles.is_empty():
		print("Subtitles array is empty for testing.")
		return

	test_srt_line_display_index = (test_srt_line_display_index + 1) % subtitles.size()
	load_and_display_subtitle_line(test_srt_line_display_index)


func _on_bgcolor_tween_finished():

	is_animating_bgcolor = false


func _on_render_complete():
	print("Done rendering.")
	get_tree().quit()


"""

		if i == currently_highlighted_word_index:
		
			processed_word_bbcode = "[pulse]" + \
			OUTLINE_TAG_START + \
			HIGHLIGHT_COLOR_TAG_START + \
			HIGHLIGHT_FONT_SIZE_TAG_START + \
			current_word + \
			FONT_SIZE_TAG_END + COLOR_TAG_END + \
			OUTLINE_TAG_END + \
			"[/pulse]"
"""
