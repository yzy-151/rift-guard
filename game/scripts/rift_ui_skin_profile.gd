extends Resource
class_name RiftUISkinProfile

@export var schema_version := 3

@export_group("Common")
@export var common_button_normal: Texture2D
@export var common_button_hover: Texture2D
@export var common_button_pressed: Texture2D
@export var common_panel: Texture2D

@export_group("Dialogue")
@export var dialogue_background: Texture2D
@export var dialogue_box: Texture2D
@export var choice_frame_gray: Texture2D
@export var choice_frame_red: Texture2D

@export_group("Mode and Mission")
@export var mode_background: Texture2D
@export var mode_card_gray: Texture2D
@export var mode_card_red: Texture2D
@export var mission_background: Texture2D
@export var mission_card_gray: Texture2D
@export var mission_card_red: Texture2D
@export var mission_card_locked: Texture2D
@export var mission_endless: Texture2D

@export_group("Squad")
@export var squad_background: Texture2D

@export_group("Reward")
@export var reward_background: Texture2D
@export var reward_card_gray: Texture2D
@export var reward_card_red: Texture2D
@export var reward_card_cyan: Texture2D

@export_group("Settings")
@export var settings_background: Texture2D

@export_group("Battle HUD")
@export var battle_menu_background: Texture2D
@export var battle_topbar: Texture2D
@export var battle_logo: Texture2D
@export var hero_frame_gray: Texture2D
@export var hero_frame_red: Texture2D
@export var skill_frame_gray: Texture2D
@export var skill_frame_red: Texture2D
@export var ultimate_frame_gray: Texture2D
@export var ultimate_frame_red: Texture2D
