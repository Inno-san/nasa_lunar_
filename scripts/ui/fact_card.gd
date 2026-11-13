class_name FactCard
extends RefCounted
## Small cards that show saved NASA content. Every card says "Saved NASA data".


static func _tag() -> Label:
	var tag := UiKit.label(NasaData.SAVED_LABEL, UiKit.FONT_SMALL, Color(0.1, 0.12, 0.18), false)
	var holder := PanelContainer.new()
	var st := UiKit.panel_style(Color(0.7, 0.9, 0.78), Color(0.7, 0.9, 0.78), 8)
	st.set_corner_radius_all(6)
	holder.add_theme_stylebox_override("panel", st)
	holder.add_child(tag)
	return tag


static func _tag_holder() -> Control:
	var tag := _tag()
	var holder: Control = tag.get_parent()
	return holder


## An OSDR fact card: short fact, study ID, date and source.
static func make_fact(fact: Dictionary, heading: String = "Did you know?") -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiKit.panel_style(Color(0.08, 0.2, 0.17, 1), Color(0.55, 0.92, 0.75, 1), 14))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	top.add_child(UiKit.label(heading, UiKit.FONT_BODY, UiKit.COLOR_GOOD, false))
	top.add_child(_tag_holder())
	box.add_child(top)
	if fact.is_empty():
		box.add_child(UiKit.label("No fact card is available right now.", UiKit.FONT_BODY))
		return card
	box.add_child(UiKit.label(String(fact.get("text", "")), UiKit.FONT_BODY))
	box.add_child(UiKit.label(NasaData.fact_source_line(fact), UiKit.FONT_SMALL, UiKit.COLOR_MUTED))
	var link := LinkButton.new()
	link.text = "Open the NASA study page (needs internet)"
	link.uri = String(fact.get("link", ""))
	link.add_theme_font_size_override("font_size", UiKit.FONT_SMALL)
	box.add_child(link)
	return card


## The storm card: the linked DONKI record, shown before every storm.
static func make_storm(info: Dictionary) -> PanelContainer:
	var rec: Dictionary = info.get("record", {})
	var severity := int(info.get("severity", 1))
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiKit.panel_style(Color(0.2, 0.12, 0.08, 1), Color(1.0, 0.75, 0.4, 1), 14))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	top.add_child(UiKit.label("A real NASA record inspired this storm", UiKit.FONT_BODY, UiKit.COLOR_WARN, false))
	top.add_child(_tag_holder())
	box.add_child(top)
	if rec.is_empty():
		box.add_child(UiKit.label("A solar storm is hitting the Moon base.", UiKit.FONT_BODY))
	else:
		box.add_child(UiKit.label("Event: %s" % NasaData.storm_title(rec), UiKit.FONT_BODY))
		box.add_child(UiKit.label("Date: %s" % NasaData.format_date(String(rec.get("peak_time", ""))), UiKit.FONT_BODY))
		box.add_child(UiKit.label(String(rec.get("kid_text", "")), UiKit.FONT_BODY))
		box.add_child(UiKit.label("NASA DONKI record: %s" % rec.get("donki_id", "?"), UiKit.FONT_SMALL, UiKit.COLOR_MUTED))
		var link := LinkButton.new()
		link.text = "Open the NASA record (needs internet)"
		link.uri = String(rec.get("link", ""))
		link.add_theme_font_size_override("font_size", UiKit.FONT_SMALL)
		box.add_child(link)
	box.add_child(UiKit.label("Based on a real NASA record. Damage in this game is simplified.", UiKit.FONT_BODY, UiKit.COLOR_GOOD))
	box.add_child(UiKit.label("Game storm size: %s (level %d of 3). The level is a game label, not a measured dose." % [
		GameState.storm_size_word(severity), severity], UiKit.FONT_SMALL, UiKit.COLOR_MUTED))
	return card

