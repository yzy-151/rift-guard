extends Node2D
## Layered Furina puppet driven by a real Skeleton2D/Bone2D hierarchy.

const BASE_SCALE := 0.105
const PART := "res://assets/characters/furina_q_rig/q-part-%02d.png"

var skeleton: Skeleton2D
var root_bone: Bone2D
var body_bone: Bone2D
var head_bone: Bone2D
var left_arm_bone: Bone2D
var right_arm_bone: Bone2D
var left_leg_bone: Bone2D
var right_leg_bone: Bone2D
var left_shoe_bone: Bone2D
var right_shoe_bone: Bone2D
var sprites: Array[Sprite2D] = []
var rest: Dictionary = {}

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	skeleton = Skeleton2D.new()
	skeleton.name = "Skeleton2D"
	add_child(skeleton)
	root_bone = make_bone("Root", skeleton, Vector2.ZERO)
	body_bone = make_bone("Body", root_bone, Vector2(0, -395))
	head_bone = make_bone("Head", body_bone, Vector2(0, -275))
	left_arm_bone = make_bone("LeftArm", body_bone, Vector2(-132, -42))
	right_arm_bone = make_bone("RightArm", body_bone, Vector2(132, -48))
	left_leg_bone = make_bone("LeftLeg", root_bone, Vector2(-56, -260))
	right_leg_bone = make_bone("RightLeg", root_bone, Vector2(56, -260))
	left_shoe_bone = make_bone("LeftShoe", left_leg_bone, Vector2(0, 225))
	right_shoe_bone = make_bone("RightShoe", right_leg_bone, Vector2(0, 225))
	add_part(4, body_bone, Vector2(0, 18), -4)
	add_part(6, left_leg_bone, Vector2(0, 112), -3)
	add_part(7, right_leg_bone, Vector2(0, 112), -3)
	add_part(11, left_shoe_bone, Vector2.ZERO, -2)
	add_part(12, right_shoe_bone, Vector2.ZERO, -2)
	add_part(2, head_bone, Vector2(0, 15), 0)
	add_part(3, body_bone, Vector2(0, -4), 1)
	add_part(8, left_arm_bone, Vector2(0, 102), 2)
	add_part(10, right_arm_bone, Vector2(5, 65), 2)
	add_part(1, head_bone, Vector2(0, -2), 3)
	add_part(5, head_bone, Vector2(82, -185), 4)
	for bone in [root_bone, body_bone, head_bone, left_arm_bone, right_arm_bone, left_leg_bone, right_leg_bone, left_shoe_bone, right_shoe_bone]:
		rest[bone] = {"position": bone.position, "rotation": bone.rotation, "scale": bone.scale}

func make_bone(label: String, parent: Node, point: Vector2) -> Bone2D:
	var bone := Bone2D.new()
	bone.name = label
	bone.position = point
	bone.set_autocalculate_length_and_angle(false)
	bone.set_length(100.0)
	bone.set_bone_angle(0.0)
	bone.set_rest(bone.transform)
	parent.add_child(bone)
	return bone

func add_part(index: int, bone: Bone2D, offset: Vector2, layer: int) -> void:
	var sprite := Sprite2D.new()
	sprite.name = "Part%02d" % index
	sprite.texture = load(PART % index)
	sprite.position = offset
	sprite.z_index = layer
	bone.add_child(sprite)
	sprites.append(sprite)

func sync(hero: Dictionary, screen_position: Vector2, depth: float, shot_life: float, clock: float, reduced: bool) -> void:
	visible = hero.hp > 0 or hero.get("visual", "") == "furina"
	position = screen_position + Vector2(0, 8)
	scale = Vector2.ONE * BASE_SCALE * depth
	rotation = 0.0
	modulate = Color("#f8a6a1") if hero.flash > 0.0 and not reduced else Color.WHITE
	reset_pose()
	if hero.hp <= 0:
		rotation = PI * 0.5
		position += Vector2(18, -2)
		return
	if reduced:
		return
	if hero.moving:
		var stride := sin(clock * 14.0)
		position.y += absf(cos(clock * 14.0)) * -3.0
		left_leg_bone.rotation = stride * 0.14
		right_leg_bone.rotation = -stride * 0.14
		left_arm_bone.rotation = -stride * 0.11
		right_arm_bone.rotation = stride * 0.10
		head_bone.rotation = -stride * 0.018
	else:
		var breath := sin(clock * 3.0)
		body_bone.position.y += breath * 4.0
		head_bone.rotation = breath * -0.018
		left_arm_bone.rotation = breath * 0.025
	if shot_life > 0.0:
		var attack := clampf(shot_life / 0.12, 0.0, 1.0)
		body_bone.rotation = -0.035 * attack
		right_arm_bone.rotation = -0.42 * attack
		head_bone.rotation += 0.04 * attack

func reset_pose() -> void:
	for bone in rest:
		var pose: Dictionary = rest[bone]
		bone.position = pose.position
		bone.rotation = pose.rotation
		bone.scale = pose.scale
