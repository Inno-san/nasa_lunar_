class_name FactCard
extends RefCounted
## Small cards that show saved NASA content. Every card says "Saved NASA data".


static func _make_saved_badge() -> PanelContainer:
	var holder := PanelContainer.new()
	var st := UiKit.panel_style(Color(0.7, 0.9, 0.78), Color(0.7, 0.9, 0.78), 8)
	st.set_corner_radius_all(6)
	holder.add_theme_stylebox_override("panel", st)
	holder.add_child(UiKit.label(NasaData.SAVED_LABEL, UiKit.FONT_SMALL, Color(0.1, 0.12, 0.18), false))
	return holder


static func _make_card_shell(bg: Color, border: Color, heading: String, heading_color: Color) -> Array:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiKit.panel_style(bg, border, 14))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	top.add_child(UiKit.label(heading, UiKit.FONT_BODY, heading_color, false))
	top.add_child(_make_saved_badge())
	box.add_child(top)
	return [card, box]


static func _make_link(text: String, uri: String) -> LinkButton:
	var link := LinkButton.new()
	link.text = text
	link.uri = uri
	link.add_theme_font_size_override("font_size", UiKit.FONT_SMALL)
	return link


## An OSDR fact card: short fact, study ID, date and source.
static func make_fact(fact: Dictionary, heading: String = "Did you know?") -> PanelContainer:
	var parts := _make_card_shell(Color(0.08, 0.2, 0.17, 1), Color(0.55, 0.92, 0.75, 1), heading, UiKit.COLOR_GOOD)
	var card: PanelContainer = parts[0]
	var box: VBoxContainer = parts[1]
	if fact.is_empty():
		box.add_child(UiKit.label("No fact card is available right now.", UiKit.FONT_BODY))
		return card
	box.add_child(UiKit.label(String(fact.get("text", "")), UiKit.FONT_BODY))
	box.add_child(UiKit.label(NasaData.fact_source_line(fact), UiKit.FONT_SMALL, UiKit.COLOR_MUTED))
	box.add_child(_make_link("Open the NASA study page (needs internet)", String(fact.get("link", ""))))
	return card


## The storm card: the linked DONKI record, shown before every storm.
static func make_storm(info: Dictionary) -> PanelContainer:
	var rec: Dictionary = info.get("record", {})
	var severity := int(info.get("severity", 1))
	var parts := _make_card_shell(Color(0.2, 0.12, 0.08, 1), Color(1.0, 0.75, 0.4, 1), "A real NASA record inspired this storm", UiKit.COLOR_WARN)
	var card: PanelContainer = parts[0]
	var box: VBoxContainer = parts[1]
	if rec.is_empty():
		box.add_child(UiKit.label("A solar storm is hitting the Moon base.", UiKit.FONT_BODY))
	else:
		box.add_child(UiKit.label("Event: %s" % NasaData.storm_title(rec), UiKit.FONT_BODY))
		box.add_child(UiKit.label("Date: %s" % NasaData.format_date(String(rec.get("peak_time", ""))), UiKit.FONT_BODY))
		box.add_child(UiKit.label(String(rec.get("kid_text", "")), UiKit.FONT_BODY))
		box.add_child(UiKit.label("NASA DONKI record: %s" % rec.get("donki_id", "?"), UiKit.FONT_SMALL, UiKit.COLOR_MUTED))
		box.add_child(_make_link("Open the NASA record (needs internet)", String(rec.get("link", ""))))
	box.add_child(UiKit.label("Based on a real NASA record. Damage in this game is simplified.", UiKit.FONT_BODY, UiKit.COLOR_GOOD))
	box.add_child(UiKit.label("Game storm size: %s (level %d of 3). The level is a game label, not a measured dose." % [
		GameState.storm_size_word(severity), severity], UiKit.FONT_SMALL, UiKit.COLOR_MUTED))
	return card

