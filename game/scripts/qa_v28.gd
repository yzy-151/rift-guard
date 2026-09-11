extends RefCounted

const SpriteAnchor = preload("res://scripts/sprite_anchor.gd")
const FurinaActor = preload("res://scripts/furina_frame_actor.gd")

var checks := 0
var failures := 0

func expect(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("V28 PASS: " + message)
	else:
		failures += 1
		push_error("V28 FAIL: " + message)

func world_foot(actor_origin: Vector2, depth: float, foot_offset: float, placement_data: Dictionary, source_size: Vector2, source_pivot: Vector2) -> Vector2:
	var outer := Transform2D(Vector2(depth, 0.0), Vector2(0.0, depth), actor_origin)
	var local := Transform2D(Vector2(float(placement_data.flip_x), 0.0), Vector2(0.0, 1.0), Vector2(0.0, foot_offset))
	return outer * local * SpriteAnchor.mapped_pivot(placement_data, source_size, source_pivot)

func run(game) -> void:
	game.mode_select_panel.close()
	game.hud.get_child(0).show()
	var source_size := Vector2(288, 288)
	var asymmetric_pivot := Vector2(111, 270)
	var display_size := Vector2(132, 132)
	var right := SpriteAnchor.placement(display_size, source_size, asymmetric_pivot, 1.0)
	var left := SpriteAnchor.placement(display_size, source_size, asymmetric_pivot, -1.0)
	expect(right.rect.size == display_size and left.rect.size == display_size, "both facings keep positive destination dimensions")
	expect(right.flip_x == 1.0 and left.flip_x == -1.0, "left-facing art flips through a local transform")
	expect(SpriteAnchor.mapped_pivot(right,source_size,asymmetric_pivot).is_equal_approx(Vector2.ZERO), "right-facing asymmetric frame maps its foot to local origin")
	expect(SpriteAnchor.mapped_pivot(left,source_size,asymmetric_pivot).is_equal_approx(Vector2.ZERO), "left-facing asymmetric frame maps its foot to local origin")

	var actor_origin := Vector2(417, 293)
	var depth := 0.83
	var hero_shadow := actor_origin + Vector2(0.0, game.battle.HERO_FOOT_OFFSET) * depth
	expect(world_foot(actor_origin,depth,game.battle.HERO_FOOT_OFFSET,right,source_size,asymmetric_pivot).is_equal_approx(hero_shadow), "right-facing character foot stays centered on its shadow")
	expect(world_foot(actor_origin,depth,game.battle.HERO_FOOT_OFFSET,left,source_size,asymmetric_pivot).is_equal_approx(hero_shadow), "left-facing character foot stays centered on its shadow")
	var enemy_shadow := actor_origin + Vector2(0.0, game.battle.ENEMY_FOOT_OFFSET) * depth
	expect(world_foot(actor_origin,depth,game.battle.ENEMY_FOOT_OFFSET,right,source_size,asymmetric_pivot).is_equal_approx(enemy_shadow), "right-facing monster foot stays centered on its shadow")
	expect(world_foot(actor_origin,depth,game.battle.ENEMY_FOOT_OFFSET,left,source_size,asymmetric_pivot).is_equal_approx(enemy_shadow), "left-facing monster foot stays centered on its shadow")

	var catalog := SpriteAnchor.load_catalog()
	var every_pivot_stable := true
	for profile_id: String in catalog:
		var profile: Dictionary = catalog[profile_id]
		var cell_array: Array = profile.get("cell", [1,1])
		var cell := Vector2(float(cell_array[0]),float(cell_array[1]))
		for value: Array in profile.get("pivots", []):
			var pivot := Vector2(float(value[0]),float(value[1]))
			for facing in [-1.0,1.0]:
				var placement_data := SpriteAnchor.placement(Vector2(128,128),cell,pivot,facing)
				every_pivot_stable = every_pivot_stable and placement_data.rect.size.x > 0.0 and SpriteAnchor.mapped_pivot(placement_data,cell,pivot).is_equal_approx(Vector2.ZERO)
	expect(every_pivot_stable, "every configured character and monster animation frame preserves its pivot in both directions")

	var actor = FurinaActor.new()
	game.add_child(actor)
	await game.get_tree().process_frame
	var hero := {"facing":-1.0,"hp":100.0,"flash":0.0,"moving":false}
	actor.sync(hero,actor_origin,depth,0.0,false,0.0)
	expect(actor.scale.x > 0.0 and actor.sprite.flip_h, "Furina uses Sprite2D flip without a negative parent scale")
	var furina_pivot := SpriteAnchor.pivot(actor.sprite_pivots,"furina_idle",actor.sprite.frame,Vector2(128,228))
	var visible_pivot := Vector2(256.0-furina_pivot.x,furina_pivot.y)
	var furina_foot: Vector2 = actor.sprite.position + (visible_pivot - Vector2(128,128)) * actor.sprite.scale
	expect(furina_foot.is_equal_approx(Vector2.ZERO), "left-facing Furina frame keeps its generated foot pivot at the node origin")
	hero.facing = 1.0
	actor.sync(hero,actor_origin,depth,0.0,false,0.0)
	furina_pivot = SpriteAnchor.pivot(actor.sprite_pivots,"furina_idle",actor.sprite.frame,Vector2(128,228))
	furina_foot = actor.sprite.position+(furina_pivot-Vector2(128,128))*actor.sprite.scale
	expect(not actor.sprite.flip_h and furina_foot.is_equal_approx(Vector2.ZERO), "right-facing Furina frame keeps the same foot anchor")
	actor.queue_free()

	expect(not FileAccess.get_file_as_string("res://scripts/battle_view.gd").contains("SpriteAnchor.destination"), "battle rendering no longer uses negative-width destination rectangles")
	print("V28 QA COMPLETE: %d checks, %d failures" % [checks, failures])
	game.get_tree().quit(failures)
