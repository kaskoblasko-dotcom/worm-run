extends RefCounted
# Shared look for every menu and HUD element: colors, buttons, panels, fields.
# Use:  control.theme = UITheme.build()
# Then pick a style with control.theme_type_variation = "PrimaryButton" etc.

const PANEL := Color(0.10, 0.13, 0.20, 0.95)
const PANEL_LIGHT := Color(0.17, 0.21, 0.31)
const FIELD := Color(0.05, 0.07, 0.11)
const ACCENT := Color(0.36, 0.78, 0.38)
const ACCENT_DARK := Color(0.25, 0.60, 0.29)
const TEXT := Color(0.93, 0.95, 1.0)
const TEXT_DIM := Color(0.66, 0.72, 0.84)
const WARN := Color(1.0, 0.85, 0.4)
const DANGER := Color(0.80, 0.30, 0.33)


static func box(color: Color, radius: int = 12, border: int = 0, border_color: Color = Color.TRANSPARENT, pad_x: int = 18, pad_y: int = 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.set_border_width_all(border)
	s.border_color = border_color
	s.content_margin_left = pad_x
	s.content_margin_right = pad_x
	s.content_margin_top = pad_y
	s.content_margin_bottom = pad_y
	return s


static func _button_set(th: Theme, type_name: String, normal: Color, text_color: Color, border: Color = Color.TRANSPARENT) -> void:
	var bw := 2 if border.a > 0.0 else 0
	th.set_stylebox("normal", type_name, box(normal, 12, bw, border, 20, 12))
	th.set_stylebox("hover", type_name, box(normal.lightened(0.12), 12, bw, border, 20, 12))
	th.set_stylebox("pressed", type_name, box(normal.darkened(0.18), 12, bw, border, 20, 12))
	th.set_stylebox("hover_pressed", type_name, box(normal.lightened(0.05), 12, bw, border, 20, 12))
	th.set_stylebox("disabled", type_name, box(normal.darkened(0.35), 12, bw, border, 20, 12))
	th.set_stylebox("focus", type_name, box(Color(0, 0, 0, 0), 12, 2, Color(1, 1, 1, 0.55), 20, 12))
	th.set_color("font_color", type_name, text_color)
	th.set_color("font_hover_color", type_name, text_color)
	th.set_color("font_pressed_color", type_name, text_color)
	th.set_color("font_hover_pressed_color", type_name, text_color)
	th.set_color("font_focus_color", type_name, text_color)
	th.set_color("font_disabled_color", type_name, text_color.darkened(0.4))
	th.set_font_size("font_size", type_name, 22)


static func build() -> Theme:
	var th := Theme.new()
	th.default_font_size = 20

	# ---- Labels ----
	th.set_color("font_color", "Label", TEXT)

	th.set_type_variation("TitleLabel", "Label")
	th.set_font_size("font_size", "TitleLabel", 62)
	th.set_color("font_color", "TitleLabel", Color.WHITE)
	th.set_color("font_outline_color", "TitleLabel", Color(0.12, 0.34, 0.17))
	th.set_constant("outline_size", "TitleLabel", 12)

	th.set_type_variation("HeadingLabel", "Label")
	th.set_font_size("font_size", "HeadingLabel", 30)
	th.set_color("font_color", "HeadingLabel", Color.WHITE)

	th.set_type_variation("DimLabel", "Label")
	th.set_font_size("font_size", "DimLabel", 17)
	th.set_color("font_color", "DimLabel", TEXT_DIM)

	th.set_type_variation("WarnLabel", "Label")
	th.set_color("font_color", "WarnLabel", WARN)

	# ---- Buttons ----
	_button_set(th, "Button", PANEL_LIGHT, TEXT)

	th.set_type_variation("PrimaryButton", "Button")
	_button_set(th, "PrimaryButton", ACCENT_DARK, Color(1, 1, 1))
	th.set_font_size("font_size", "PrimaryButton", 26)

	th.set_type_variation("DangerButton", "Button")
	_button_set(th, "DangerButton", DANGER, Color(1, 1, 1))

	th.set_type_variation("GhostButton", "Button")
	_button_set(th, "GhostButton", Color(1, 1, 1, 0.06), TEXT_DIM)

	# Segmented (toggle) buttons: tabs, option rows.
	th.set_type_variation("SegButton", "Button")
	_button_set(th, "SegButton", Color(0.12, 0.15, 0.23), TEXT_DIM, Color(0.24, 0.30, 0.42))
	th.set_stylebox("pressed", "SegButton", box(ACCENT_DARK, 12, 2, ACCENT, 20, 12))
	th.set_stylebox("hover_pressed", "SegButton", box(ACCENT_DARK.lightened(0.08), 12, 2, ACCENT, 20, 12))
	th.set_color("font_pressed_color", "SegButton", Color.WHITE)
	th.set_color("font_hover_pressed_color", "SegButton", Color.WHITE)

	# ---- Text fields ----
	th.set_stylebox("normal", "LineEdit", box(FIELD, 10, 2, Color(0.24, 0.30, 0.42), 16, 12))
	th.set_stylebox("focus", "LineEdit", box(FIELD, 10, 2, ACCENT, 16, 12))
	th.set_stylebox("read_only", "LineEdit", box(FIELD.lightened(0.05), 10, 2, Color(0.24, 0.30, 0.42), 16, 12))
	th.set_color("font_color", "LineEdit", TEXT)
	th.set_color("font_placeholder_color", "LineEdit", Color(0.45, 0.51, 0.63))
	th.set_color("caret_color", "LineEdit", ACCENT)
	th.set_color("selection_color", "LineEdit", Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.4))
	th.set_font_size("font_size", "LineEdit", 22)

	th.set_color("font_color", "CheckBox", TEXT_DIM)
	th.set_color("font_hover_color", "CheckBox", TEXT)
	th.set_color("font_pressed_color", "CheckBox", TEXT)
	th.set_color("font_hover_pressed_color", "CheckBox", TEXT)
	th.set_font_size("font_size", "CheckBox", 18)

	# ---- Panels ----
	var card := box(PANEL, 22, 2, Color(0.28, 0.36, 0.50, 0.7), 30, 26)
	card.shadow_size = 18
	card.shadow_color = Color(0, 0, 0, 0.35)
	card.shadow_offset = Vector2(0, 8)
	th.set_type_variation("CardPanel", "PanelContainer")
	th.set_stylebox("panel", "CardPanel", card)

	th.set_type_variation("HudPanel", "PanelContainer")
	th.set_stylebox("panel", "HudPanel", box(Color(0.04, 0.06, 0.10, 0.62), 10, 0, Color.TRANSPARENT, 12, 8))

	return th
